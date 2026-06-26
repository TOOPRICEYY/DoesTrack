import Foundation

struct GitHubSyncClient {
    private let apiBaseURL = URL(string: "https://api.github.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
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
            message: "Sync DoseTrack backup",
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

        var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)
        components?.path = "/repos/\(settings.owner)/\(settings.repository)/contents/\(encodedPath)"
        components?.queryItems = [URLQueryItem(name: "ref", value: settings.branch)]

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
