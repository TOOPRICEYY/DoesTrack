import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var store: DoseStore

    @State private var settings = GitHubSyncSettings()
    @State private var token = ""
    @State private var account: GitHubAccount?
    @State private var repositories: [GitHubRepository] = []
    @State private var branches: [GitHubBranch] = []
    @State private var statusMessage = ""
    @State private var isWorking = false
    @State private var workingLabel = ""
    @State private var showsToken = false
    @State private var showsRepositoryPicker = false
    @State private var showsManualSettings = false

    private var canSignIn: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
    }

    private var canChooseRepository: Bool {
        account != nil && !repositories.isEmpty && !isWorking
    }

    private var canSync: Bool {
        settings.isRepositoryConfigured &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                repositorySection
                actionsSection
                statusSection
            }
            .navigationTitle("Sync")
            .sheet(isPresented: $showsRepositoryPicker) {
                GitHubRepositorySelectionView(
                    repositories: repositories,
                    selectedFullName: selectedRepositoryFullName
                ) { repository in
                    selectRepository(repository)
                }
            }
            .onAppear {
                settings = store.syncSettings
                token = KeychainTokenStore.loadToken()
            }
        }
    }

    private var accountSection: some View {
        Section("GitHub Account") {
            if let account {
                Label(account.displayName, systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(.primary)

                Button {
                    refreshRepositories()
                } label: {
                    Label("Refresh Repositories", systemImage: "arrow.clockwise")
                }
                .disabled(isWorking)

                Button(role: .destructive) {
                    signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(isWorking)
            } else {
                Text("Sign in with a GitHub personal access token that has repository contents read/write access for the repo you want to sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    if showsToken {
                        TextField("GitHub token", text: $token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("GitHub token", text: $token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button {
                        showsToken.toggle()
                    } label: {
                        Image(systemName: showsToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsToken ? "Hide token" : "Show token")
                }

                Button {
                    signIn()
                } label: {
                    Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(!canSignIn)
            }
        }
    }

    private var repositorySection: some View {
        Section("Repository") {
            if let selectedRepositoryFullName {
                LabeledContent("Selected", value: selectedRepositoryFullName)
            } else {
                Text("Choose a repository after signing in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                showsRepositoryPicker = true
            } label: {
                Label("Choose Repository", systemImage: "folder.badge.gearshape")
            }
            .disabled(!canChooseRepository)

            if account != nil && repositories.isEmpty {
                Text("No repositories loaded yet. Refresh after signing in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !branches.isEmpty {
                Picker("Branch", selection: $settings.branch) {
                    ForEach(branches) { branch in
                        Text(branch.name).tag(branch.name)
                    }
                }
                .onChange(of: settings.branch) { _, _ in
                    saveRepositorySettings()
                }
            } else {
                TextField("Branch", text: $settings.branch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            TextField("Sync file path", text: $settings.filePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                saveRepositorySettings()
            } label: {
                Label("Save Repository Settings", systemImage: "externaldrive.fill")
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                pushBackup()
            } label: {
                Label("Push Backup", systemImage: "arrow.up.doc.fill")
            }
            .disabled(!canSync)

            Button {
                pullAndMerge()
            } label: {
                Label("Pull & Merge", systemImage: "arrow.down.doc.fill")
            }
            .disabled(!canSync)

            Button {
                syncNow()
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!canSync)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            if isWorking {
                HStack {
                    ProgressView()
                    Text(workingLabel.isEmpty ? "Working" : workingLabel)
                }
            }

            if let lastSyncedAt = settings.lastSyncedAt {
                LabeledContent("Last sync", value: lastSyncedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let sha = settings.lastRemoteSHA, !sha.isEmpty {
                LabeledContent("Remote SHA", value: String(sha.prefix(12)))
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsManualSettings.toggle()
                }
            } label: {
                HStack {
                    Label("Manual repository settings", systemImage: "slider.horizontal.3")
                    Spacer()
                    Image(systemName: showsManualSettings ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Manual repository settings")

            if showsManualSettings {
                TextField("Owner", text: $settings.owner)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Repository", text: $settings.repository)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Branch", text: $settings.branch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("File path", text: $settings.filePath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    saveRepositorySettings()
                } label: {
                    Label("Save manual settings", systemImage: "key.fill")
                }
            }
        }
    }

    private var selectedRepositoryFullName: String? {
        guard settings.isRepositoryConfigured else { return nil }
        return "\(settings.owner)/\(settings.repository)"
    }

    private func signIn() {
        runWork(label: "Signing in") {
            try KeychainTokenStore.saveToken(token)
            let client = GitHubSyncClient()
            let account = try await client.currentUser(token: token)
            let repositories = try await client.repositories(token: token)

            await MainActor.run {
                self.account = account
                self.repositories = repositories
                self.statusMessage = repositories.isEmpty ? "Signed in, but no repositories are available to this token." : "Signed in as \(account.displayName). Choose a repository to continue."
            }

            if settings.isRepositoryConfigured {
                try await loadBranches(owner: settings.owner, repository: settings.repository)
            }
        }
    }

    private func refreshRepositories() {
        runWork(label: "Loading repositories") {
            let client = GitHubSyncClient()
            let repositories = try await client.repositories(token: token)
            await MainActor.run {
                self.repositories = repositories
                self.statusMessage = repositories.isEmpty ? "No repositories are available to this token." : "Loaded \(repositories.count) repositories."
            }
        }
    }

    private func selectRepository(_ repository: GitHubRepository) {
        settings.owner = repository.owner.login
        settings.repository = repository.name
        settings.branch = repository.defaultBranch
        settings.lastRemoteSHA = nil
        saveRepositorySettings()

        Task {
            do {
                try await loadBranches(owner: repository.owner.login, repository: repository.name)
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadBranches(owner: String, repository: String) async throws {
        let client = GitHubSyncClient()
        let branches = try await client.branches(owner: owner, repository: repository, token: token)
        await MainActor.run {
            self.branches = branches
            if !branches.contains(where: { $0.name == settings.branch }),
               let firstBranch = branches.first {
                settings.branch = firstBranch.name
                saveRepositorySettings()
            }
        }
    }

    private func signOut() {
        do {
            try KeychainTokenStore.deleteToken()
            token = ""
            account = nil
            repositories = []
            branches = []
            statusMessage = "Signed out of GitHub."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveRepositorySettings() {
        do {
            try KeychainTokenStore.saveToken(token)
            store.syncSettings = settings
            statusMessage = settings.isRepositoryConfigured ? "Repository settings saved." : "Repository settings saved. Choose a repository before syncing."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func pushBackup() {
        runWork(label: "Pushing backup") {
            try saveSettingsForSync()
            let client = GitHubSyncClient()
            let sha = try await client.push(
                backup: store.exportBackup(),
                settings: settings,
                token: token,
                knownSHA: settings.lastRemoteSHA
            )
            await MainActor.run {
                settings.lastRemoteSHA = sha
                settings.lastSyncedAt = Date()
                store.syncSettings = settings
                statusMessage = "Backup pushed to GitHub."
            }
        }
    }

    private func pullAndMerge() {
        runWork(label: "Pulling backup") {
            try saveSettingsForSync()
            let client = GitHubSyncClient()
            let remote = try await client.pull(settings: settings, token: token)
            await MainActor.run {
                store.mergeBackup(remote.backup)
                settings.lastRemoteSHA = remote.sha
                settings.lastSyncedAt = Date()
                store.syncSettings = settings
                statusMessage = "Remote backup merged."
            }
        }
    }

    private func syncNow() {
        runWork(label: "Syncing") {
            try saveSettingsForSync()
            let client = GitHubSyncClient()

            do {
                let remote = try await client.pull(settings: settings, token: token)
                await MainActor.run {
                    store.mergeBackup(remote.backup)
                    settings.lastRemoteSHA = remote.sha
                }
            } catch GitHubSyncError.notFound {
                await MainActor.run {
                    settings.lastRemoteSHA = nil
                }
            }

            let sha = try await client.push(
                backup: store.exportBackup(),
                settings: settings,
                token: token,
                knownSHA: settings.lastRemoteSHA
            )
            await MainActor.run {
                settings.lastRemoteSHA = sha
                settings.lastSyncedAt = Date()
                store.syncSettings = settings
                statusMessage = "Sync complete."
            }
        }
    }

    private func runWork(label: String, _ operation: @escaping () async throws -> Void) {
        isWorking = true
        workingLabel = label
        statusMessage = ""

        Task {
            do {
                try await operation()
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isWorking = false
                workingLabel = ""
            }
        }
    }

    private func saveSettingsForSync() throws {
        try KeychainTokenStore.saveToken(token)
        store.syncSettings = settings
    }
}

private struct GitHubRepositorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var repositories: [GitHubRepository]
    var selectedFullName: String?
    var onSelect: (GitHubRepository) -> Void

    private var filteredRepositories: [GitHubRepository] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return repositories }
        return repositories.filter { repository in
            repository.fullName.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredRepositories.isEmpty {
                    ContentUnavailableView("No Repositories", systemImage: "folder.badge.questionmark", description: Text("No accessible repositories match this search."))
                } else {
                    ForEach(filteredRepositories) { repository in
                        Button {
                            onSelect(repository)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: repository.isPrivate ? "lock.fill" : "globe")
                                    .foregroundStyle(repository.isPrivate ? .orange : .blue)
                                    .frame(width: 26)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(repository.fullName)
                                        .font(.headline)
                                    Text("\(repository.privacyLabel) · default branch \(repository.defaultBranch)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedFullName == repository.fullName {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if !repository.canPush {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .accessibilityLabel("May not have write access")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose Repository")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search repositories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
