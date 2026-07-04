import Foundation

// MARK: - GitHub auto sync

extension DoseStore {
    static let syncWarningDismissedKey = "doseTrackSyncWarningDismissedAt"
    /// A week without a sync makes the backup stale enough to warn about.
    static let syncStaleInterval: TimeInterval = 7 * 86_400
    /// Auto sync at most this often, so foreground/background flips don't
    /// hammer the GitHub API.
    static let autoSyncThrottle: TimeInterval = 10 * 60

    var isSyncConfigured: Bool {
        syncSettings.isRepositoryConfigured && !KeychainTokenStore.loadToken().isEmpty
    }

    /// True when sync is set up but hasn't run for over a week, and the user
    /// hasn't dismissed the warning within the last week.
    var showsSyncStaleWarning: Bool {
        guard isSyncConfigured else { return false }

        let lastSynced = syncSettings.lastSyncedAt ?? .distantPast
        guard Date().timeIntervalSince(lastSynced) > Self.syncStaleInterval else { return false }

        if let dismissed = UserDefaults.standard.object(forKey: Self.syncWarningDismissedKey) as? Date,
           Date().timeIntervalSince(dismissed) < Self.syncStaleInterval {
            return false
        }
        return true
    }

    func dismissSyncStaleWarning() {
        objectWillChange.send()
        UserDefaults.standard.set(Date(), forKey: Self.syncWarningDismissedKey)
    }

    func setAutoSync(enabled: Bool) {
        var settings = syncSettings
        settings.autoSyncEnabled = enabled
        syncSettings = settings
    }

    /// Pull → merge → push, the same flow as the manual "Sync Now" button.
    func performSync() async throws {
        let token = KeychainTokenStore.loadToken()
        guard syncSettings.isRepositoryConfigured, !token.isEmpty else {
            throw GitHubSyncError.missingRepositorySettings
        }

        let client = GitHubSyncClient()
        var settings = syncSettings

        do {
            let remote = try await client.pull(settings: settings, token: token)
            mergeBackup(remote.backup)
            settings.lastRemoteSHA = remote.sha
        } catch GitHubSyncError.notFound {
            settings.lastRemoteSHA = nil
        }

        let sha = try await client.push(
            backup: exportBackup(),
            settings: settings,
            token: token,
            knownSHA: settings.lastRemoteSHA
        )

        settings.lastRemoteSHA = sha
        settings.lastSyncedAt = Date()
        syncSettings = settings
    }

    /// Runs on launch and when the app backgrounds. Silent, throttled, and
    /// only when the user turned Auto Sync on.
    func performAutoSyncIfEnabled() async {
        guard syncSettings.autoSyncEnabled, isSyncConfigured else { return }

        let lastSynced = syncSettings.lastSyncedAt ?? .distantPast
        guard Date().timeIntervalSince(lastSynced) > Self.autoSyncThrottle else { return }

        do {
            try await performSync()
            lastAutoSyncError = nil
        } catch {
            lastAutoSyncError = error.localizedDescription
        }
    }
}
