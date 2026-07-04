import Foundation

struct GitHubSyncClient {
    private let apiBaseURL = URL(string: "https://api.github.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func currentUser(token: String) async throws -> GitHubAccount {
        var request = try makeAuthenticatedRequest(path: "/user", token: token)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(GitHubAccount.self, from: data)
    }

    func repositories(token: String) async throws -> [GitHubRepository] {
        var output: [GitHubRepository] = []
        var page = 1

        while true {
            var request = try makeAuthenticatedRequest(
                path: "/user/repos",
                queryItems: [
                    URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
                    URLQueryItem(name: "sort", value: "updated"),
                    URLQueryItem(name: "per_page", value: "100"),
                    URLQueryItem(name: "page", value: "\(page)")
                ],
                token: token
            )
            request.httpMethod = "GET"

            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)

            let repositories = try JSONDecoder().decode([GitHubRepository].self, from: data)
            output.append(contentsOf: repositories)

            guard repositories.count == 100 else { break }
            page += 1
        }

        return output.sorted { lhs, rhs in
            lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
    }

    func branches(owner: String, repository: String, token: String) async throws -> [GitHubBranch] {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        let encodedRepository = repository.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repository
        var request = try makeAuthenticatedRequest(
            path: "/repos/\(encodedOwner)/\(encodedRepository)/branches",
            queryItems: [URLQueryItem(name: "per_page", value: "100")],
            token: token
        )
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode([GitHubBranch].self, from: data)
    }

    func pull(settings: GitHubSyncSettings, token: String) async throws -> GitHubRemoteBackup {
        let response = try await fetchContents(settings: settings, token: token)
        guard response.encoding == "base64", let content = response.content else {
            throw GitHubSyncError.invalidRemoteContent
        }

        let cleaned = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleaned) else {
            throw GitHubSyncError.invalidRemoteContent
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DoseBackup.self, from: data)
        return GitHubRemoteBackup(backup: backup, sha: response.sha)
    }

    func push(backup: DoseBackup, settings: GitHubSyncSettings, token: String, knownSHA: String?) async throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let backupData = try encoder.encode(backup)
        let encodedContent = backupData.base64EncodedString()

        let sha = try await remoteSHA(settings: settings, token: token, knownSHA: knownSHA)
        let requestBody = GitHubUpdateRequest(
            message: "Sync DoesTrack backup",
            content: encodedContent,
            branch: settings.branch,
            sha: sha
        )

        var request = try makeRequest(settings: settings, token: token)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let updateResponse = try JSONDecoder().decode(GitHubUpdateResponse.self, from: data)
        guard let newSHA = updateResponse.content?.sha else {
            throw GitHubSyncError.invalidRemoteContent
        }

        return newSHA
    }

    private func remoteSHA(settings: GitHubSyncSettings, token: String, knownSHA: String?) async throws -> String? {
        if let knownSHA, !knownSHA.isEmpty {
            return knownSHA
        }

        do {
            return try await fetchContents(settings: settings, token: token).sha
        } catch GitHubSyncError.notFound {
            return nil
        }
    }

    private func fetchContents(settings: GitHubSyncSettings, token: String) async throws -> GitHubContentsResponse {
        var request = try makeRequest(settings: settings, token: token)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(GitHubContentsResponse.self, from: data)
    }

    private func makeRequest(settings: GitHubSyncSettings, token: String) throws -> URLRequest {
        guard settings.isRepositoryConfigured else {
            throw GitHubSyncError.missingRepositorySettings
        }

        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitHubSyncError.missingToken
        }

        let encodedPath = settings.filePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        return try makeAuthenticatedRequest(
            path: "/repos/\(settings.owner)/\(settings.repository)/contents/\(encodedPath)",
            queryItems: [URLQueryItem(name: "ref", value: settings.branch)],
            token: token
        )
    }

    private func makeAuthenticatedRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        token: String
    ) throws -> URLRequest {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitHubSyncError.missingToken
        }

        var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw GitHubSyncError.invalidRepositoryPath
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitHubSyncError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw GitHubSyncError.unauthorized
        case 404:
            throw GitHubSyncError.notFound
        case 409:
            throw GitHubSyncError.conflict
        default:
            if let apiError = try? JSONDecoder().decode(GitHubAPIError.self, from: data) {
                throw GitHubSyncError.api(apiError.message)
            }
            throw GitHubSyncError.api("GitHub returned HTTP \(http.statusCode).")
        }
    }
}

struct GitHubAccount: Identifiable, Decodable, Equatable {
    var id: Int
    var login: String
    var name: String?

    var displayName: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "@\(login)" : "\(trimmedName) (@\(login))"
    }
}

struct GitHubRepository: Identifiable, Decodable, Equatable {
    var id: Int
    var name: String
    var fullName: String
    var owner: GitHubRepositoryOwner
    var isPrivate: Bool
    var defaultBranch: String
    var permissions: GitHubRepositoryPermissions?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case permissions
    }

    var canPush: Bool {
        permissions?.push ?? true
    }

    var privacyLabel: String {
        isPrivate ? "Private" : "Public"
    }
}

struct GitHubRepositoryOwner: Decodable, Equatable {
    var login: String
}

struct GitHubRepositoryPermissions: Decodable, Equatable {
    var push: Bool?
}

struct GitHubBranch: Identifiable, Decodable, Equatable {
    var id: String { name }
    var name: String
    var protected: Bool?
}

struct GitHubRemoteBackup {
    var backup: DoseBackup
    var sha: String
}

private struct GitHubContentsResponse: Decodable {
    var sha: String
    var content: String?
    var encoding: String?
}

private struct GitHubUpdateRequest: Encodable {
    var message: String
    var content: String
    var branch: String
    var sha: String?
}

private struct GitHubUpdateResponse: Decodable {
    var content: GitHubUpdatedContent?
}

private struct GitHubUpdatedContent: Decodable {
    var sha: String
}

private struct GitHubAPIError: Decodable {
    var message: String
}

enum GitHubSyncError: LocalizedError, Equatable {
    case missingRepositorySettings
    case missingToken
    case invalidRepositoryPath
    case invalidResponse
    case invalidRemoteContent
    case unauthorized
    case notFound
    case conflict
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingRepositorySettings:
            return "Enter a repository owner, repository name, branch, and sync file path."
        case .missingToken:
            return "Enter a GitHub token with contents read/write access."
        case .invalidRepositoryPath:
            return "The repository path is not valid."
        case .invalidResponse:
            return "GitHub returned an invalid response."
        case .invalidRemoteContent:
            return "The remote sync file could not be decoded."
        case .unauthorized:
            return "GitHub rejected the token or repository access."
        case .notFound:
            return "The sync file was not found in the repository."
        case .conflict:
            return "GitHub reported a file conflict. Pull and merge, then push again."
        case .api(let message):
            return message
        }
    }
}
