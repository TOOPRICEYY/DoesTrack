import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var store: DoseStore

    @State private var settings = GitHubSyncSettings()
    @State private var token = ""
    @State private var statusMessage = ""
    @State private var isWorking = false
    @State private var showsToken = false

    private var canSync: Bool {
        settings.isRepositoryConfigured &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Repository") {
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
                }

                Section("Access Token") {
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
                        saveSettings()
                    } label: {
                        Label("Save settings", systemImage: "key.fill")
                    }
                }

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

                Section("Status") {
                    if isWorking {
                        HStack {
                            ProgressView()
                            Text("Syncing")
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
                }
            }
            .navigationTitle("Sync")
            .onAppear {
                settings = store.syncSettings
                token = KeychainTokenStore.loadToken()
            }
        }
    }

    private func saveSettings() {
        do {
            try KeychainTokenStore.saveToken(token)
            store.syncSettings = settings
            statusMessage = "Settings saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func pushBackup() {
        runSync {
            try saveSettingsForSync()
            let client = GitHubSyncClient()
            let sha = try await client.push(
                backup: store.exportBackup(),
                settings: settings,
                token: token,
                knownSHA: settings.lastRemoteSHA
            )
            settings.lastRemoteSHA = sha
            settings.lastSyncedAt = Date()
            store.syncSettings = settings
            return "Backup pushed to GitHub."
        }
    }

    private func pullAndMerge() {
        runSync {
            try saveSettingsForSync()
            let client = GitHubSyncClient()
            let remote = try await client.pull(settings: settings, token: token)
            store.mergeBackup(remote.backup)
            settings.lastRemoteSHA = remote.sha
            settings.lastSyncedAt = Date()
            store.syncSettings = settings
            return "Remote backup merged."
        }
    }

    private func syncNow() {
        runSync {
            try saveSettingsForSync()
            let client = GitHubSyncClient()

            do {
                let remote = try await client.pull(settings: settings, token: token)
                store.mergeBackup(remote.backup)
                settings.lastRemoteSHA = remote.sha
            } catch GitHubSyncError.notFound {
                settings.lastRemoteSHA = nil
            }

            let sha = try await client.push(
                backup: store.exportBackup(),
                settings: settings,
                token: token,
                knownSHA: settings.lastRemoteSHA
            )
            settings.lastRemoteSHA = sha
            settings.lastSyncedAt = Date()
            store.syncSettings = settings
            return "Sync complete."
        }
    }

    private func runSync(_ operation: @escaping () async throws -> String) {
        isWorking = true
        statusMessage = ""

        Task {
            do {
                statusMessage = try await operation()
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func saveSettingsForSync() throws {
        try KeychainTokenStore.saveToken(token)
        store.syncSettings = settings
    }
}
