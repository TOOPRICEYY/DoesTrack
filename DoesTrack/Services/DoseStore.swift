import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class DoseStore: ObservableObject {
    @Published var medications: [Medication] = [] {
        didSet {
            save()
            scheduleNotificationRefresh()
        }
    }

    @Published var logs: [DoseLog] = [] {
        didSet { save() }
    }

    @Published var syncSettings = GitHubSyncSettings() {
        didSet { save() }
    }

    @Published var healthMetrics = HealthMetricsSnapshot.empty {
        didSet { save() }
    }

    @Published var symptomCheckIns: [SymptomCheckIn] = [] {
        didSet { save() }
    }

    @Published var supplements: [Supplement] = [] {
        didSet { save() }
    }

    @Published var supplementLogs: [SupplementLog] = [] {
        didSet { save() }
    }

    @Published var labResults: [LabResult] = [] {
        didSet { save() }
    }

    @Published var hydrationDays: [HydrationDay] = [] {
        didSet { save() }
    }

    @Published var cycles: [ProtocolCycle] = [] {
        didSet { save() }
    }

    @Published var reconPlans: [ReconPlan] = [] {
        didSet { save() }
    }

    @Published var chatMessages: [ChatMessage] = [] {
        didSet { save() }
    }

    @Published var batches: [MedicationBatch] = [] {
        didSet { save() }
    }

    @Published var storageError: String?
    @Published var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @Published var lastAutoSyncError: String?

    private let fileURL: URL
    private let calendar = Calendar.doseTrackCalendar
    private var isLoading = false
    private var hasPendingSave = false
    private var hasPendingNotificationRefresh = false
    private let notificationScheduler = NotificationScheduler()
    private static let markedAllReadKey = "doseTrackNotificationsMarkedAllAt"

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.fileURL = fileURL ?? documents?.appendingPathComponent("doestrack-data.json") ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("doestrack-data.json")

        if ProcessInfo.processInfo.arguments.contains("-reset-for-ui-testing") {
            try? FileManager.default.removeItem(at: self.fileURL)
            UserDefaults.standard.removeObject(forKey: "doseTrackPinnedHomeCards")
            UserDefaults.standard.removeObject(forKey: HomeCardLayoutStore.storageKey)
            UserDefaults.standard.removeObject(forKey: Self.markedAllReadKey)
            UserDefaults.standard.removeObject(forKey: Self.hydrationGoalKey)
        }

        load()
        resumeExpiredPauses()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
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
            healthMetrics = database.healthMetrics
            symptomCheckIns = database.symptomCheckIns.sorted { $0.createdAt > $1.createdAt }
            supplements = database.supplements.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            supplementLogs = database.supplementLogs
            labResults = database.labResults.sorted { $0.sampledAt > $1.sampledAt }
            hydrationDays = database.hydrationDays
            cycles = database.cycles
            reconPlans = database.reconPlans.sorted { $0.createdAt > $1.createdAt }
            chatMessages = database.chatMessages.sorted { $0.createdAt < $1.createdAt }
            batches = database.batches.sorted { $0.purchaseDate > $1.purchaseDate }
            storageError = nil
        } catch {
            storageError = "Unable to load DoesTrack data: \(error.localizedDescription)"
        }
    }

    /// Coalesces bursts of property mutations (e.g. one dose log touching
    /// logs + medications) into a single file write on the next runloop turn.
    func save() {
        guard !isLoading, !hasPendingSave else { return }

        hasPendingSave = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasPendingSave = false
            self.persistNow()
        }
    }

    func persistNow() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let database = DoseDatabase(
                medications: medications,
                logs: logs,
                syncSettings: syncSettings,
                healthMetrics: healthMetrics,
                symptomCheckIns: symptomCheckIns,
                supplements: supplements,
                supplementLogs: supplementLogs,
                labResults: labResults,
                hydrationDays: hydrationDays,
                cycles: cycles,
                reconPlans: reconPlans,
                chatMessages: chatMessages,
                batches: batches
            )
            let data = try encoder.encode(database)
            try data.write(to: fileURL, options: [.atomic])
            storageError = nil
        } catch {
            storageError = "Unable to save DoesTrack data: \(error.localizedDescription)"
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
        updated.pausedUntil = nil
        updateMedication(updated)
    }

    func pauseMedication(_ medication: Medication, until resumeDate: Date?) {
        var updated = medication
        updated.isActive = false
        updated.pausedUntil = resumeDate
        updateMedication(updated)
    }

    /// Reactivates any medication whose "Pause for X days" window has elapsed.
    func resumeExpiredPauses(reference: Date = Date()) {
        let expired = medications.contains { !$0.isActive && ($0.pausedUntil.map { $0 <= reference } ?? false) }
        guard expired else { return }

        medications = medications.map { medication in
            guard !medication.isActive, let until = medication.pausedUntil, until <= reference else {
                return medication
            }
            var updated = medication
            updated.isActive = true
            updated.pausedUntil = nil
            updated.updatedAt = Date()
            return updated
        }
    }

    func setStack(named stackName: String, isActive: Bool) {
        medications = medications.map { medication in
            guard medication.stackName == stackName else { return medication }
            var updated = medication
            updated.isActive = isActive
            updated.pausedUntil = nil
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

    func record(
        _ scheduledDose: ScheduledDose,
        status: DoseLogStatus,
        amount: Double? = nil,
        takenAt: Date = Date(),
        notes: String = "",
        method: String? = nil,
        site: String? = nil,
        painLevel: Int? = nil,
        siteReaction: String? = nil,
        skipReason: String? = nil,
        batchID: UUID? = nil,
        volumeMl: Double? = nil
    ) {
        let previousLog = logForDose(
            medicationID: scheduledDose.medication.id,
            scheduleID: scheduledDose.schedule.id,
            scheduledAt: scheduledDose.scheduledAt
        )

        let loggedAmount = amount ?? scheduledDose.schedule.amount
        let administered = status == .taken || status == .wasted
        let log = DoseLog(
            id: previousLog?.id ?? UUID(),
            medicationID: scheduledDose.medication.id,
            scheduleID: scheduledDose.schedule.id,
            scheduledAt: scheduledDose.scheduledAt,
            takenAt: administered ? takenAt : nil,
            status: status,
            amount: loggedAmount,
            notes: notes,
            method: administered ? method : nil,
            site: administered ? site : nil,
            painLevel: administered ? painLevel : nil,
            siteReaction: administered ? siteReaction : nil,
            skipReason: status == .skipped ? skipReason : nil,
            batchID: administered ? batchID : nil,
            volumeMl: administered ? volumeMl : nil
        )

        upsertLog(log)
        reconcileBatch(
            previousLog: previousLog,
            newBatchID: administered ? batchID : nil,
            newAmount: loggedAmount,
            newStatus: status
        )

        // Legacy inventory counters only apply when no batch is involved.
        if batchID == nil && previousLog?.batchID == nil {
            reconcileInventory(
                medicationID: scheduledDose.medication.id,
                oldAmount: previousLog?.amount,
                newAmount: loggedAmount,
                oldStatus: previousLog?.status,
                newStatus: status
            )
        }
    }

    func recordManualDose(
        medicationID: UUID,
        amount: Double,
        notes: String,
        scheduledAt: Date = Date(),
        takenAt: Date = Date(),
        method: String? = nil,
        site: String? = nil,
        painLevel: Int? = nil,
        siteReaction: String? = nil,
        batchID: UUID? = nil,
        volumeMl: Double? = nil
    ) {
        let log = DoseLog(
            medicationID: medicationID,
            scheduleID: nil,
            scheduledAt: scheduledAt,
            takenAt: takenAt,
            status: .taken,
            amount: amount,
            notes: notes,
            method: method,
            site: site,
            painLevel: painLevel,
            siteReaction: siteReaction,
            batchID: batchID,
            volumeMl: volumeMl
        )
        upsertLog(log)
        reconcileBatch(previousLog: nil, newBatchID: batchID, newAmount: amount, newStatus: .taken)
        if batchID == nil {
            reconcileInventory(medicationID: medicationID, oldAmount: nil, newAmount: amount, oldStatus: nil, newStatus: .taken)
        }
    }

    func recordWastedDose(medicationID: UUID, amount: Double, occurredAt: Date = Date(), notes: String = "", batchID: UUID? = nil, volumeMl: Double? = nil) {
        let log = DoseLog(
            medicationID: medicationID,
            scheduleID: nil,
            scheduledAt: occurredAt,
            takenAt: occurredAt,
            status: .wasted,
            amount: amount,
            notes: notes,
            batchID: batchID,
            volumeMl: volumeMl
        )
        upsertLog(log)
        reconcileBatch(previousLog: nil, newBatchID: batchID, newAmount: amount, newStatus: .wasted)
        if batchID == nil {
            reconcileInventory(medicationID: medicationID, oldAmount: nil, newAmount: amount, oldStatus: nil, newStatus: .wasted)
        }
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
            logs: logs,
            symptomCheckIns: symptomCheckIns,
            supplements: supplements,
            supplementLogs: supplementLogs,
            labResults: labResults,
            hydrationDays: hydrationDays,
            cycles: cycles,
            reconPlans: reconPlans,
            batches: batches
        )
    }

    func replaceData(with backup: DoseBackup) {
        medications = backup.medications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        logs = backup.logs.sorted { $0.scheduledAt > $1.scheduledAt }
        symptomCheckIns = backup.symptomCheckIns.sorted { $0.createdAt > $1.createdAt }
        supplements = backup.supplements.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        supplementLogs = backup.supplementLogs
        labResults = backup.labResults.sorted { $0.sampledAt > $1.sampledAt }
        hydrationDays = backup.hydrationDays
        cycles = backup.cycles
        reconPlans = backup.reconPlans.sorted { $0.createdAt > $1.createdAt }
        batches = backup.batches.sorted { $0.purchaseDate > $1.purchaseDate }
    }

    func updateHealthMetrics(_ snapshot: HealthMetricsSnapshot) {
        healthMetrics = snapshot
    }

    func recordSymptomCheckIn(_ checkIn: SymptomCheckIn) {
        if let index = symptomCheckIns.firstIndex(where: { $0.id == checkIn.id }) {
            symptomCheckIns[index] = checkIn
        } else {
            symptomCheckIns.append(checkIn)
        }
        symptomCheckIns.sort { $0.createdAt > $1.createdAt }
    }

    var latestSymptomCheckIn: SymptomCheckIn? {
        symptomCheckIns.max { $0.createdAt < $1.createdAt }
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

        var checkInByID = Dictionary(uniqueKeysWithValues: symptomCheckIns.map { ($0.id, $0) })
        for remoteCheckIn in backup.symptomCheckIns {
            if let local = checkInByID[remoteCheckIn.id] {
                checkInByID[remoteCheckIn.id] = remoteCheckIn.createdAt > local.createdAt ? remoteCheckIn : local
            } else {
                checkInByID[remoteCheckIn.id] = remoteCheckIn
            }
        }

        medications = medicationByID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        logs = logByID.values.sorted { $0.scheduledAt > $1.scheduledAt }
        symptomCheckIns = checkInByID.values.sorted { $0.createdAt > $1.createdAt }
        supplements = Self.mergeByID(local: supplements, remote: backup.supplements, newer: { $0.createdAt })
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        supplementLogs = Self.mergeByID(local: supplementLogs, remote: backup.supplementLogs, newer: { $0.takenAt })
        labResults = Self.mergeByID(local: labResults, remote: backup.labResults, newer: { $0.sampledAt })
            .sorted { $0.sampledAt > $1.sampledAt }
        cycles = Self.mergeByID(local: cycles, remote: backup.cycles, newer: { $0.startDate })
        reconPlans = Self.mergeByID(local: reconPlans, remote: backup.reconPlans, newer: { $0.createdAt })
            .sorted { $0.createdAt > $1.createdAt }
        hydrationDays = mergeHydration(remote: backup.hydrationDays)
        batches = Self.mergeByID(local: batches, remote: backup.batches, newer: { $0.updatedAt })
            .sorted { $0.purchaseDate > $1.purchaseDate }
    }

    private static func mergeByID<T: Identifiable>(local: [T], remote: [T], newer: (T) -> Date) -> [T] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote {
            if let existing = byID[item.id] {
                byID[item.id] = newer(item) > newer(existing) ? item : existing
            } else {
                byID[item.id] = item
            }
        }
        return Array(byID.values)
    }

    private func mergeHydration(remote: [HydrationDay]) -> [HydrationDay] {
        var byDay = Dictionary(uniqueKeysWithValues: hydrationDays.map { ($0.day, $0) })
        for entry in remote {
            let existing = byDay[entry.day]?.ounces ?? 0
            byDay[entry.day] = HydrationDay(day: entry.day, ounces: max(existing, entry.ounces))
        }
        return byDay.values.sorted { $0.day > $1.day }
    }

    func adherenceRate(days: Int, endingAt end: Date = Date()) -> Double {
        let start = end.addingDays(-(days - 1)).startOfDay
        let scheduled = scheduledDoses(from: start, through: end).filter { $0.scheduledAt <= end }
        guard !scheduled.isEmpty else { return 0 }
        let takenCount = scheduled.filter { $0.log?.status == .taken }.count
        return Double(takenCount) / Double(scheduled.count)
    }

    /// Week-over-week compliance change, e.g. +0.12 when this week is 12
    /// points ahead of last week.
    func weeklyComplianceDelta() -> Double {
        adherenceRate(days: 7) - adherenceRate(days: 7, endingAt: Date().addingDays(-7))
    }

    /// Name and age (in whole weeks, minimum 1) of the longest-running active
    /// protocol, mirroring the model app's "N Weeks on Protocol" card.
    func activeProtocolTenure(reference: Date = Date()) -> (stackName: String, weeks: Int)? {
        let candidates = protocolStacks(includeInactive: false)
            .compactMap { stack in stack.startedAt.map { (stack.name, $0) } }
        guard let earliest = candidates.min(by: { $0.1 < $1.1 }) else { return nil }

        let days = calendar.dateComponents([.day], from: earliest.1, to: reference).day ?? 0
        return (earliest.0, max(1, days / 7))
    }

    var isWeeklyCheckInDue: Bool {
        guard let latest = latestSymptomCheckIn?.createdAt else { return true }
        return Date().timeIntervalSince(latest) >= 7 * 86_400
    }

    /// Single source of truth for the bell badge and the notification center
    /// header. Returns 0 for the rest of the day after "Mark all".
    func notificationAttentionCount(reference: Date = Date()) -> Int {
        if let marked = notificationsMarkedAllReadAt, marked.isSameDay(as: reference) {
            return 0
        }

        let today = scheduledDoses(on: reference)
        let todayOpen = today.filter { $0.log?.status != .taken && $0.log?.status != .skipped }.count
        let upcoming = upcomingDoses(limit: 20).filter { !$0.scheduledAt.isSameDay(as: reference) }.count
        return todayOpen + upcoming + (isWeeklyCheckInDue ? 1 : 0)
    }

    var notificationsMarkedAllReadAt: Date? {
        UserDefaults.standard.object(forKey: Self.markedAllReadKey) as? Date
    }

    func markAllNotificationsRead() {
        objectWillChange.send()
        UserDefaults.standard.set(Date(), forKey: Self.markedAllReadKey)
    }

    /// Most recent administered dose at a given injection site.
    func lastUse(ofSite site: String) -> Date? {
        logs
            .filter { $0.site == site && $0.status == .taken }
            .compactMap { $0.takenAt ?? $0.scheduledAt }
            .max()
    }

    /// Least recently used site from the given options; never-used sites win.
    func suggestedInjectionSite(from options: [String]) -> String? {
        options.min { lhs, rhs in
            (lastUse(ofSite: lhs) ?? .distantPast) < (lastUse(ofSite: rhs) ?? .distantPast)
        }
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

    private func reconcileInventory(medicationID: UUID, oldAmount: Double?, newAmount: Double, oldStatus: DoseLogStatus?, newStatus: DoseLogStatus) {
        guard let index = medications.firstIndex(where: { $0.id == medicationID }) else { return }

        let previouslyDeducted = (oldStatus?.deductsInventory ?? false) ? (oldAmount ?? newAmount) : 0
        let nowDeducted = newStatus.deductsInventory ? newAmount : 0
        let delta = nowDeducted - previouslyDeducted
        guard delta != 0 else { return }

        var medication = medications[index]
        medication.inventory.currentQuantity = max(0, medication.inventory.currentQuantity - delta)
        medication.updatedAt = Date()
        medications[index] = medication
        sortMedications()
    }

    private func sortMedications() {
        medications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Local notifications

    func refreshNotificationAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthorization = settings.authorizationStatus
    }

    /// Prompts for permission if needed, then schedules reminders.
    /// Returns false when the user declined.
    func enableNotifications() async throws -> Bool {
        let granted = try await notificationScheduler.requestAuthorization()
        await refreshNotificationAuthorization()
        guard granted else { return false }
        try await notificationScheduler.schedule(medications: medications)
        return true
    }

    /// Re-schedules pending reminders if permission is already granted.
    /// Never prompts; safe to call on launch and after any medication change.
    func syncNotificationsIfAuthorized() async {
        await refreshNotificationAuthorization()
        guard notificationAuthorization == .authorized || notificationAuthorization == .provisional else { return }
        try? await notificationScheduler.schedule(medications: medications)
    }

    private func scheduleNotificationRefresh() {
        guard !isLoading, !hasPendingNotificationRefresh else { return }

        hasPendingNotificationRefresh = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasPendingNotificationRefresh = false
            await self.syncNotificationsIfAuthorized()
        }
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
