import CloudKit
import Foundation

struct ICloudRemoteBackup {
    let backup: DoseBackup
    let record: CKRecord
}

struct ICloudSyncClient {
    static let containerIdentifier = "iCloud.com.gp.doestrack"

    private static let recordType = "DoesTrackBackup"
    private static let recordName = "primary-backup"
    private static let assetField = "backup"

    private let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer = CKContainer(identifier: ICloudSyncClient.containerIdentifier)) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    func pull() async throws -> ICloudRemoteBackup? {
        try await requireAvailableAccount()

        let recordID = CKRecord.ID(recordName: Self.recordName)
        let record: CKRecord

        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }

        guard let asset = record[Self.assetField] as? CKAsset,
              let fileURL = asset.fileURL
        else {
            throw ICloudSyncError.missingBackupData
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DoseBackup.self, from: data)
        return ICloudRemoteBackup(backup: backup, record: record)
    }

    @discardableResult
    func push(_ backup: DoseBackup, replacing existingRecord: CKRecord?) async throws -> CKRecord {
        try await requireAvailableAccount()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("doestrack-icloud-\(UUID().uuidString)")
            .appendingPathExtension("json")
        try data.write(to: temporaryURL, options: [.atomic])
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let record = existingRecord ?? CKRecord(
            recordType: Self.recordType,
            recordID: CKRecord.ID(recordName: Self.recordName)
        )
        record[Self.assetField] = CKAsset(fileURL: temporaryURL)
        record["schemaVersion"] = backup.schemaVersion as CKRecordValue
        record["exportedAt"] = backup.exportedAt as CKRecordValue
        return try await database.save(record)
    }

    private func requireAvailableAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw ICloudSyncError.accountUnavailable(status)
        }
    }
}

enum ICloudSyncError: LocalizedError {
    case accountUnavailable(CKAccountStatus)
    case missingBackupData
    case configuration(String)

    var errorDescription: String? {
        switch self {
        case .accountUnavailable(let status):
            switch status {
            case .noAccount:
                return "Sign in to iCloud in System Settings before enabling sync."
            case .restricted:
                return "iCloud access is restricted on this device."
            case .temporarilyUnavailable:
                return "iCloud is temporarily unavailable. Try again shortly."
            case .couldNotDetermine:
                return "DoesTrack could not determine the iCloud account status."
            case .available:
                return "iCloud is available."
            @unknown default:
                return "iCloud is not available on this device."
            }
        case .missingBackupData:
            return "The iCloud backup record does not contain readable DoesTrack data."
        case .configuration(let message):
            return message
        }
    }
}
