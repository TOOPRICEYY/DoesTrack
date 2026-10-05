import CloudKit
import Foundation

// MARK: - iCloud sync

extension DoseStore {
    static let iCloudAutoSyncThrottle: TimeInterval = 60

    func setICloudSync(enabled: Bool) {
        let wasEnabled = iCloudSyncSettings.isEnabled
        var settings = iCloudSyncSettings
        settings.isEnabled = enabled
        if enabled, !wasEnabled || settings.lastSyncedAt == nil {
            settings.lastLocalChangeAt = Date()
        }
        iCloudSyncSettings = settings
        if !enabled {
            lastICloudSyncError = nil
        }
    }

    /// Pulls the newest private CloudKit backup, merges it into the local
    /// database, and writes the merged result back with optimistic locking.
    func performICloudSync() async throws {
        guard iCloudSyncSettings.isEnabled else {
            throw ICloudSyncError.syncDisabled
        }
        guard !isICloudSyncInFlight else { return }

        isICloudSyncInFlight = true
        defer { isICloudSyncInFlight = false }

        let client = ICloudSyncClient()
        let remote = try await client.pull()

        if let remote,
           remote.backup.exportedAt > (iCloudSyncSettings.lastSyncedAt ?? .distantPast) {
            let localChangeAt = iCloudSyncSettings.lastLocalChangeAt ?? .distantPast
            isApplyingICloudData = true
            mergeBackup(remote.backup, preferRemote: remote.backup.exportedAt >= localChangeAt)
            isApplyingICloudData = false
        }

        var uploadedBackup = exportBackup()
        do {
            try await client.push(uploadedBackup, replacing: remote?.record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Another device saved after our pull. Re-read its record, prefer
            // that newer version for matching IDs, then retry once.
            let latest = try await client.pull()
            if let latest {
                let localChangeAt = iCloudSyncSettings.lastLocalChangeAt ?? .distantPast
                isApplyingICloudData = true
                mergeBackup(latest.backup, preferRemote: latest.backup.exportedAt >= localChangeAt)
                isApplyingICloudData = false
            }
            uploadedBackup = exportBackup()
            try await client.push(uploadedBackup, replacing: latest?.record)
        }

        var settings = iCloudSyncSettings
        settings.lastSyncedAt = uploadedBackup.exportedAt
        if let localChangeAt = settings.lastLocalChangeAt,
           localChangeAt <= uploadedBackup.exportedAt {
            settings.lastLocalChangeAt = nil
        }
        iCloudSyncSettings = settings
        lastICloudSyncError = nil
        persistNow()
    }

    func performICloudAutoSyncIfEnabled() async {
        guard iCloudSyncSettings.isEnabled else { return }

        let lastSynced = iCloudSyncSettings.lastSyncedAt ?? .distantPast
        guard Date().timeIntervalSince(lastSynced) > Self.iCloudAutoSyncThrottle else { return }

        do {
            try await performICloudSync()
        } catch {
            lastICloudSyncError = error.localizedDescription
        }
    }
}

extension ICloudSyncError {
    static var syncDisabled: ICloudSyncError { .configuration("Turn on iCloud Sync before syncing.") }
}
