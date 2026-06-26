import Foundation
import SwiftUI

@MainActor
final class DoseStore: ObservableObject {
    @Published var medications: [Medication] = [] {
        didSet { save() }
    }

    @Published var logs: [DoseLog] = [] {
        didSet { save() }
    }

    @Published var syncSettings = GitHubSyncSettings() {
        didSet { save() }
    }

    @Published var storageError: String?

    private let fileURL: URL
    private let calendar = Calendar.doseTrackCalendar
    private var isLoading = false

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.fileURL = fileURL ?? documents?.appendingPathComponent("dosetrack-data.json") ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dosetrack-data.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            medications = []
            logs = []
            syncSettings = GitHubSyncSettings()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let database = try decoder.decode(DoseDatabase.self, from: data)
            medications = database.medications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            logs = database.logs.sorted { $0.scheduledAt > $1.scheduledAt }
            syncSettings = database.syncSettings
            storageError = nil
        } catch {
            storageError = "Unable to load DoseTrack data: \(error.localizedDescription)"
        }
    }

    func save() {
        guard !isLoading else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let database = DoseDatabase(medications: medications, logs: logs, syncSettings: syncSettings)
            let data = try encoder.encode(database)
            try data.write(to: fileURL, options: [.atomic])
            storageError = nil
        } catch {
            storageError = "Unable to save DoseTrack data: \(error.localizedDescription)"
        }
    }

    func addMedication(_ medication: Medication) {
        medications.append(medication)
        sortMedications()
    }

    func addProtocolTemplate(_ template: ProtocolTemplate) {
        medications.append(contentsOf: template.medications.map { medication in
            var copy = medication
            copy.id = UUID()
            copy.createdAt = Date()
            copy.updatedAt = Date()
            copy.schedules = copy.schedules.map { schedule in
                var updated = schedule
                updated.id = UUID()
                updated.startDate = Date()
                return updated
            }
            return copy
        })
        sortMedications()
    }

    func updateMedication(_ medication: Medication) {
        guard let index = medications.firstIndex(where: { $0.id == medication.id }) else {
            addMedication(medication)
            return
        }

        var updated = medication
        updated.updatedAt = Date()
        medications[index] = updated
        sortMedications()
    }

    func deleteMedications(at offsets: IndexSet) {
        let visible = medications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let ids = offsets.map { visible[$0].id }
        medications.removeAll { ids.contains($0.id) }
        logs.removeAll { ids.contains($0.medicationID) }
    }

    func deleteMedication(_ medication: Medication) {
        medications.removeAll { $0.id == medication.id }
        logs.removeAll { $0.medicationID == medication.id }
    }

    func deleteStack(named stackName: String) {
        let ids = medications.filter { $0.stackName == stackName }.map(\.id)
        medications.removeAll { ids.contains($0.id) }
        logs.removeAll { ids.contains($0.medicationID) }
    }

    func setMedicationActive(_ medication: Medication, isActive: Bool) {
        var updated = medication
        updated.isActive = isActive
        updateMedication(updated)
    }

    func setStack(named stackName: String, isActive: Bool) {
        medications = medications.map { medication in
            guard medication.stackName == stackName else { return medication }
            var updated = medication
            updated.isActive = isActive
            updated.updatedAt = Date()
            return updated
        }
        sortMedications()
    }

    func protocolStacks(includeInactive: Bool = true) -> [ProtocolStack] {
        let visibleMedications = includeInactive ? medications : medications.filter(\.isActive)
        let grouped = Dictionary(grouping: visibleMedications, by: \.stackName)
        return grouped.map { name, medications in
            ProtocolStack(
                name: name,
                medications: medications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }
        .sorted { lhs, rhs in
            if lhs.isActive == rhs.isActive {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.isActive && !rhs.isActive
        }
    }

    func upsertProtocol(named stackName: String, medications draftMedications: [Medication], replacing oldStackName: String? = nil) {
        if let oldStackName {
            let oldIDs = medications.filter { $0.stackName == oldStackName }.map(\.id)
            let newIDs = Set(draftMedications.map(\.id))
            medications.removeAll { oldIDs.contains($0.id) }
            logs.removeAll { oldIDs.contains($0.medicationID) && !newIDs.contains($0.medicationID) }
        }

        let normalized = draftMedications.map { medication in
            var updated = medication
            updated.protocolName = stackName
            updated.updatedAt = Date()
            return updated
        }

        for medication in normalized {
            if let index = medications.firstIndex(where: { $0.id == medication.id }) {
                medications[index] = medication
            } else {
                medications.append(medication)
            }
        }

        sortMedications()
    }

    func scheduledDoses(on date: Date) -> [ScheduledDose] {
        medications
            .filter(\.isActive)
            .flatMap { medication in
                medication.schedules.compactMap { schedule -> ScheduledDose? in
                    guard schedule.occurs(on: date, calendar: calendar),
                          let scheduledAt = calendar.dateBySettingTime(hour: schedule.hour, minute: schedule.minute, on: date)
                    else {
                        return nil
                    }

                    let log = logForDose(medicationID: medication.id, scheduleID: schedule.id, scheduledAt: scheduledAt)
                    return ScheduledDose(
                        id: "\(medication.id.uuidString)-\(schedule.id.uuidString)-\(Int(scheduledAt.timeIntervalSince1970))",
                        medication: medication,
                        schedule: schedule,
                        scheduledAt: scheduledAt,
                        log: log
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.scheduledAt == rhs.scheduledAt {
                    return lhs.medication.name.localizedCaseInsensitiveCompare(rhs.medication.name) == .orderedAscending
                }
                return lhs.scheduledAt < rhs.scheduledAt
            }
    }

    func nextScheduledDose(after date: Date = Date()) -> ScheduledDose? {
        upcomingDoses(after: date, daysAhead: 60, limit: 1).first
    }

    func upcomingDoses(after date: Date = Date(), daysAhead: Int = 60, limit: Int = 20) -> [ScheduledDose] {
        let start = date.startOfDay
        let end = start.addingDays(daysAhead)
        return scheduledDoses(from: start, through: end)
            .filter { $0.scheduledAt >= date }
            .prefix(limit)
            .map { $0 }
    }

    func scheduledDoseDates(inMonthContaining date: Date) -> Set<Int> {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        return Set(range.compactMap { day -> Int? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            return scheduledDoses(on: date).isEmpty ? nil : day
        })
    }

    func record(_ scheduledDose: ScheduledDose, status: DoseLogStatus, notes: String = "") {
        let previousLog = logForDose(
            medicationID: scheduledDose.medication.id,
            scheduleID: scheduledDose.schedule.id,
            scheduledAt: scheduledDose.scheduledAt
        )

        let log = DoseLog(
            id: previousLog?.id ?? UUID(),
            medicationID: scheduledDose.medication.id,
            scheduleID: scheduledDose.schedule.id,
            scheduledAt: scheduledDose.scheduledAt,
            takenAt: status == .missed ? nil : Date(),
            status: status,
            amount: scheduledDose.schedule.amount,
            notes: notes
        )

        upsertLog(log)
        reconcileInventory(
            medicationID: scheduledDose.medication.id,
            amount: scheduledDose.schedule.amount,
            oldStatus: previousLog?.status,
            newStatus: status
        )
    }

    func recordManualDose(medicationID: UUID, amount: Double, notes: String) {
        let log = DoseLog(
            medicationID: medicationID,
            scheduleID: nil,
            scheduledAt: Date(),
            takenAt: Date(),
            status: .taken,
            amount: amount,
            notes: notes
        )
        upsertLog(log)
        reconcileInventory(medicationID: medicationID, amount: amount, oldStatus: nil, newStatus: .taken)
    }

    func logs(on date: Date) -> [DoseLog] {
        logs
            .filter { $0.scheduledAt.isSameDay(as: date) }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    func medication(for id: UUID) -> Medication? {
        medications.first { $0.id == id }
    }

    func exportBackup() -> DoseBackup {
        DoseBackup(
            schemaVersion: DoseBackup.currentSchemaVersion,
            exportedAt: Date(),
            medications: medications,
            logs: logs
        )
    }

    func replaceData(with backup: DoseBackup) {
        medications = backup.medications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        logs = backup.logs.sorted { $0.scheduledAt > $1.scheduledAt }
    }

    func mergeBackup(_ backup: DoseBackup) {
        var medicationByID = Dictionary(uniqueKeysWithValues: medications.map { ($0.id, $0) })
        for remoteMedication in backup.medications {
            if let local = medicationByID[remoteMedication.id] {
                medicationByID[remoteMedication.id] = remoteMedication.updatedAt > local.updatedAt ? remoteMedication : local
            } else {
                medicationByID[remoteMedication.id] = remoteMedication
            }
        }

        var logByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0) })
        for remoteLog in backup.logs {
            if let local = logByID[remoteLog.id] {
                let localDate = local.takenAt ?? local.scheduledAt
                let remoteDate = remoteLog.takenAt ?? remoteLog.scheduledAt
                logByID[remoteLog.id] = remoteDate > localDate ? remoteLog : local
            } else {
                logByID[remoteLog.id] = remoteLog
            }
        }

        medications = medicationByID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        logs = logByID.values.sorted { $0.scheduledAt > $1.scheduledAt }
    }

    func adherenceRate(days: Int) -> Double {
        let end = Date()
        let start = end.addingDays(-(days - 1)).startOfDay
        let scheduled = scheduledDoses(from: start, through: end).filter { $0.scheduledAt <= end }
        guard !scheduled.isEmpty else { return 0 }
        let takenCount = scheduled.filter { $0.log?.status == .taken }.count
        return Double(takenCount) / Double(scheduled.count)
    }

    func currentStreak() -> Int {
        var streak = 0
        var day = Date().startOfDay

        for _ in 0..<365 {
            let doses = scheduledDoses(on: day).filter { $0.scheduledAt <= Date() }
            if doses.isEmpty {
                day = day.addingDays(-1)
                continue
            }

            let allTaken = doses.allSatisfy { $0.log?.status == .taken }
            guard allTaken else { break }
            streak += 1
            day = day.addingDays(-1)
        }

        return streak
    }

    func adherenceRows(days: Int) -> [AdherenceRow] {
        let today = Date().startOfDay
        return (0..<days).reversed().map { offset in
            let day = today.addingDays(-offset)
            let doses = scheduledDoses(on: day).filter { $0.scheduledAt <= Date() || day < today }
            let taken = doses.filter { $0.log?.status == .taken }.count
            let rate = doses.isEmpty ? 0 : Double(taken) / Double(doses.count)
            return AdherenceRow(date: day, taken: taken, scheduled: doses.count, rate: rate)
        }
    }

    func protocolScore() -> Int {
        let adherence = adherenceRate(days: 7)
        let activeRatio = medications.isEmpty ? 0 : Double(medications.filter(\.isActive).count) / Double(medications.count)
        let inventoryHealth = inventoryWarnings().isEmpty ? 1.0 : 0.55
        let score = (adherence * 55) + (activeRatio * 30) + (inventoryHealth * 15)
        return min(100, max(0, Int(score.rounded())))
    }

    func inventoryWarnings() -> [Medication] {
        medications
            .filter { $0.isActive && $0.inventory.isTracked && $0.inventory.needsRefill }
            .sorted { $0.inventory.currentQuantity < $1.inventory.currentQuantity }
    }

    private func scheduledDoses(from start: Date, through end: Date) -> [ScheduledDose] {
        var output: [ScheduledDose] = []
        var date = start.startOfDay
        let final = end.startOfDay

        while date <= final {
            output.append(contentsOf: scheduledDoses(on: date))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return output
    }

    private func upsertLog(_ log: DoseLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
        logs.sort { $0.scheduledAt > $1.scheduledAt }
    }

    private func logForDose(medicationID: UUID, scheduleID: UUID, scheduledAt: Date) -> DoseLog? {
        logs.first { log in
            log.medicationID == medicationID &&
            log.scheduleID == scheduleID &&
            abs(log.scheduledAt.timeIntervalSince(scheduledAt)) < 60
        }
    }

    private func reconcileInventory(medicationID: UUID, amount: Double, oldStatus: DoseLogStatus?, newStatus: DoseLogStatus) {
        guard let index = medications.firstIndex(where: { $0.id == medicationID }) else { return }

        var medication = medications[index]
        if oldStatus != .taken && newStatus == .taken {
            medication.inventory.currentQuantity = max(0, medication.inventory.currentQuantity - amount)
        } else if oldStatus == .taken && newStatus != .taken {
            medication.inventory.currentQuantity += amount
        }
        medication.updatedAt = Date()
        medications[index] = medication
        sortMedications()
    }

    private func sortMedications() {
        medications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct AdherenceRow: Identifiable {
    var id: Date { date }
    var date: Date
    var taken: Int
    var scheduled: Int
    var rate: Double

    var label: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}
