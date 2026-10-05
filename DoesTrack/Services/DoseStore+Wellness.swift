import Foundation

// MARK: - Supplements, hydration, labs, cycling, recon, and chat

extension DoseStore {
    // MARK: Supplements

    func supplements(on date: Date) -> [Supplement] {
        supplements.filter { $0.isScheduled(on: date) }
    }

    func supplementLog(for supplement: Supplement, on date: Date) -> SupplementLog? {
        let day = date.startOfDay
        return supplementLogs.first { $0.supplementID == supplement.id && $0.day == day }
    }

    func isSupplementTaken(_ supplement: Supplement, on date: Date) -> Bool {
        supplementLog(for: supplement, on: date) != nil
    }

    func toggleSupplement(_ supplement: Supplement, on date: Date) {
        if let existing = supplementLog(for: supplement, on: date) {
            recordSyncTombstone(recordType: "supplementLog", recordID: existing.id)
            supplementLogs.removeAll { $0.id == existing.id }
        } else {
            supplementLogs.append(SupplementLog(supplementID: supplement.id, day: date))
        }
    }

    func upsertSupplement(_ supplement: Supplement) {
        if let index = supplements.firstIndex(where: { $0.id == supplement.id }) {
            supplements[index] = supplement
        } else {
            supplements.append(supplement)
        }
        supplements.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func deleteSupplement(_ supplement: Supplement) {
        recordSyncTombstone(recordType: "supplement", recordID: supplement.id)
        recordSyncTombstones(recordType: "supplementLog", recordIDs: supplementLogs.filter { $0.supplementID == supplement.id }.map(\.id))
        supplements.removeAll { $0.id == supplement.id }
        supplementLogs.removeAll { $0.supplementID == supplement.id }
    }

    /// Benefits covered by active supplements, out of the full benefit catalog.
    var coveredBenefits: Set<SupplementBenefit> {
        Set(supplements.filter(\.isActive).flatMap(\.benefits))
    }

    var benefitCoverageRate: Double {
        Double(coveredBenefits.count) / Double(SupplementBenefit.allCases.count)
    }

    // MARK: Hydration

    static let hydrationGoalKey = "doseTrackHydrationGoalOunces"
    nonisolated static let hydrationSipOunces = 8.0

    var hydrationGoalOunces: Double {
        let stored = UserDefaults.standard.double(forKey: Self.hydrationGoalKey)
        return stored > 0 ? stored : 100
    }

    func setHydrationGoal(_ ounces: Double) {
        objectWillChange.send()
        UserDefaults.standard.set(max(8, ounces), forKey: Self.hydrationGoalKey)
    }

    func hydrationOunces(on date: Date) -> Double {
        let day = date.startOfDay
        return hydrationDays.first { $0.day == day }?.ounces ?? 0
    }

    func addHydration(_ ounces: Double = DoseStore.hydrationSipOunces, on date: Date = Date()) {
        let day = date.startOfDay
        if let index = hydrationDays.firstIndex(where: { $0.day == day }) {
            hydrationDays[index].ounces = max(0, hydrationDays[index].ounces + ounces)
        } else if ounces > 0 {
            hydrationDays.append(HydrationDay(day: day, ounces: ounces))
        }
    }

    func resetHydration(on date: Date = Date()) {
        let day = date.startOfDay
        hydrationDays.removeAll { $0.day == day }
    }

    // MARK: Labs

    func addLabResult(_ result: LabResult) {
        labResults.append(result)
        labResults.sort { $0.sampledAt > $1.sampledAt }
    }

    func deleteLabResult(_ result: LabResult) {
        recordSyncTombstone(recordType: "labResult", recordID: result.id)
        labResults.removeAll { $0.id == result.id }
    }

    var latestLabDate: Date? {
        labResults.map(\.sampledAt).max()
    }

    /// Markers whose most recent value is out of its reference range.
    var outOfRangeMarkers: [LabResult] {
        let grouped = Dictionary(grouping: labResults, by: \.marker)
        return grouped.compactMap { _, results in
            results.max { $0.sampledAt < $1.sampledAt }
        }
        .filter(\.isOutOfRange)
        .sorted { $0.marker.localizedCaseInsensitiveCompare($1.marker) == .orderedAscending }
    }

    /// The marker with the most data points, for the trend card.
    var trendMarkerName: String? {
        Dictionary(grouping: labResults, by: \.marker)
            .max { lhs, rhs in
                lhs.value.count == rhs.value.count
                    ? lhs.key > rhs.key
                    : lhs.value.count < rhs.value.count
            }?
            .key
    }

    func labSeries(for marker: String) -> [LabResult] {
        labResults
            .filter { $0.marker.localizedCaseInsensitiveCompare(marker) == .orderedSame }
            .sorted { $0.sampledAt < $1.sampledAt }
    }

    // MARK: Cycling

    func cycle(forStack stackName: String) -> ProtocolCycle? {
        cycles.first { $0.stackName == stackName }
    }

    /// The cycle to feature on the home card: prefer one attached to an
    /// active stack, otherwise the most recently started.
    var featuredCycle: ProtocolCycle? {
        let activeNames = Set(protocolStacks(includeInactive: false).map(\.name))
        return cycles.first { activeNames.contains($0.stackName) }
            ?? cycles.max { $0.startDate < $1.startDate }
    }

    func upsertCycle(_ cycle: ProtocolCycle) {
        if let index = cycles.firstIndex(where: { $0.id == cycle.id }) {
            cycles[index] = cycle
        } else {
            // One cycle per stack keeps the card unambiguous.
            cycles.removeAll { $0.stackName == cycle.stackName }
            cycles.append(cycle)
        }
    }

    func deleteCycle(_ cycle: ProtocolCycle) {
        recordSyncTombstone(recordType: "protocolCycle", recordID: cycle.id)
        cycles.removeAll { $0.id == cycle.id }
    }

    // MARK: Reconstitution

    var activeReconPlan: ReconPlan? {
        reconPlans.first(where: \.isActive)
    }

    func upsertReconPlan(_ plan: ReconPlan) {
        var updated = reconPlans
        if plan.isActive {
            updated = updated.map { existing in
                var copy = existing
                copy.isActive = false
                return copy
            }
        }

        if let index = updated.firstIndex(where: { $0.id == plan.id }) {
            updated[index] = plan
        } else {
            updated.append(plan)
        }
        reconPlans = updated.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteReconPlan(_ plan: ReconPlan) {
        recordSyncTombstone(recordType: "reconPlan", recordID: plan.id)
        reconPlans.removeAll { $0.id == plan.id }
    }

    // MARK: Batches

    func batch(for id: UUID) -> MedicationBatch? {
        batches.first { $0.id == id }
    }

    func batches(for medicationID: UUID, includeFinished: Bool = false) -> [MedicationBatch] {
        batches
            .filter { $0.medicationID == medicationID && (includeFinished || !$0.isFinished) }
            .sorted { $0.purchaseDate > $1.purchaseDate }
    }

    /// Batch a new dose should draw from: the most recently purchased,
    /// unfinished batch with anything left in it.
    func defaultBatch(for medicationID: UUID) -> MedicationBatch? {
        batches(for: medicationID).first { !$0.isDepleted }
            ?? batches(for: medicationID).first
    }

    func upsertBatch(_ batch: MedicationBatch) {
        var updated = batch
        updated.updatedAt = Date()

        if let index = batches.firstIndex(where: { $0.id == batch.id }) {
            batches[index] = updated
        } else {
            batches.append(updated)
        }
        batches.sort { $0.purchaseDate > $1.purchaseDate }
    }

    func deleteBatch(_ batch: MedicationBatch) {
        recordSyncTombstone(recordType: "batch", recordID: batch.id)
        batches.removeAll { $0.id == batch.id }
    }

    /// Applies a remaining-quantity delta (negative = draw) in active units.
    func adjustBatch(id: UUID, delta: Double) {
        guard let index = batches.firstIndex(where: { $0.id == id }) else { return }
        let current = batches[index].remainingQuantity
        // Refunds never push a batch past what it held (draws clamp at 0, so
        // refunding a clamped draw in full would otherwise invent stock).
        let ceiling = max(batches[index].totalQuantity, current)
        batches[index].remainingQuantity = min(ceiling, max(0, current + delta))
        batches[index].updatedAt = Date()
    }

    /// Refunds the previous log's batch draw and applies the new one.
    func reconcileBatch(previousLog: DoseLog?, newBatchID: UUID?, newAmount: Double, newStatus: DoseLogStatus) {
        if let previousLog, let oldBatchID = previousLog.batchID, previousLog.status.deductsInventory {
            adjustBatch(id: oldBatchID, delta: previousLog.amount)
        }

        if let newBatchID, newStatus.deductsInventory {
            adjustBatch(id: newBatchID, delta: -newAmount)
        }
    }

    // MARK: Regimen shifting

    /// True when the medication has a schedule that is still running on the
    /// given date, so an unscheduled dose can re-anchor future doses.
    func hasShiftableRegimenSchedule(medicationID: UUID, on date: Date) -> Bool {
        guard let medication = medication(for: medicationID) else { return false }
        return medication.schedules.contains { schedule in
            schedule.isShiftable(on: date.startOfDay)
        }
    }

    func regimenShiftPreview(medicationID: UUID, anchoredAt anchor: Date) -> String? {
        guard let medication = medication(for: medicationID) else { return nil }
        let anchorDay = anchor.startOfDay
        let shiftedSchedules = medication.schedules
            .filter { $0.isShiftable(on: anchorDay) }
            .map { shiftedRegimenSchedule(from: $0, anchoredAt: anchorDay) }

        guard !shiftedSchedules.isEmpty else { return nil }

        let nextDate = nextOccurrence(after: anchorDay, schedules: shiftedSchedules)
        let nextText = nextDate.map { " Next scheduled dose: \($0.formatted(date: .abbreviated, time: .omitted))." } ?? ""
        if shiftedSchedules.contains(where: { ($0.intervalDays ?? 0) > 1 }) {
            return "The every-N-days schedule restarts from this dose.\(nextText)"
        }
        if shiftedSchedules.allSatisfy({ $0.daysOfWeek == Set(Weekday.allCases) }) {
            return "The daily schedule resumes after this dose.\(nextText)"
        }
        if shiftedSchedules.allSatisfy({ $0.daysOfWeek.count == 1 }) {
            let weekday = shiftedSchedules.first?.daysOfWeek.first?.fullName ?? "the logged day"
            return "The weekly schedule moves to \(weekday).\(nextText)"
        }
        if shiftedSchedules.allSatisfy({ $0.daysOfWeek.count == 2 }) {
            return "The twice-weekly schedule shifts around this dose.\(nextText)"
        }
        return "Future interval doses continue after this dose.\(nextText)"
    }

    /// Re-anchors interval-style schedules so an unscheduled taken dose becomes
    /// the anchor and future scheduled doses continue after it. History is
    /// preserved by ending the running schedule the day before the anchor and
    /// creating a new schedule segment for the shifted future.
    func shiftRegimenSchedules(for medicationID: UUID, anchoredAt anchor: Date) {
        guard var medication = medication(for: medicationID) else { return }

        let anchorDay = anchor.startOfDay
        var changed = false

        medication.schedules = medication.schedules.flatMap { schedule -> [DoseSchedule] in
            guard schedule.isShiftable(on: anchorDay) else {
                return [schedule]
            }

            changed = true

            var shifted = shiftedRegimenSchedule(from: schedule, anchoredAt: anchorDay)

            // Series not started yet: just move its start.
            if schedule.startDate.startOfDay >= anchorDay {
                return [shifted]
            }

            var ended = schedule
            ended.endDate = anchorDay.addingDays(-1)

            shifted.id = UUID()
            return [ended, shifted]
        }

        guard changed else { return }
        medication.updatedAt = Date()
        updateMedication(medication)
    }

    /// Backward-compatible wrappers for older call sites.
    func hasShiftableIntervalSchedule(medicationID: UUID, on date: Date) -> Bool {
        hasShiftableRegimenSchedule(medicationID: medicationID, on: date)
    }

    func shiftIntervalSchedules(for medicationID: UUID, anchoredAt anchor: Date) {
        shiftRegimenSchedules(for: medicationID, anchoredAt: anchor)
    }

    private func shiftedRegimenSchedule(from schedule: DoseSchedule, anchoredAt anchorDay: Date) -> DoseSchedule {
        var shifted = schedule
        shifted.endDate = nil

        if let intervalDays = schedule.intervalDays, intervalDays > 1 {
            shifted.startDate = anchorDay.addingDays(intervalDays)
            return shifted
        }

        if schedule.daysOfWeek.count == 1 || schedule.daysOfWeek.count == 2 {
            shifted.daysOfWeek = shiftedWeekdays(schedule.daysOfWeek, anchoredAt: anchorDay)
        }
        shifted.startDate = anchorDay.addingDays(1)
        return shifted
    }

    private func shiftedWeekdays(_ days: Set<Weekday>, anchoredAt anchorDay: Date) -> Set<Weekday> {
        guard let anchorWeekday = Weekday(rawValue: Calendar.doseTrackCalendar.component(.weekday, from: anchorDay)) else {
            return days
        }

        guard !days.isEmpty, days.count <= 2 else {
            return days
        }

        let nearest = days
            .map { day in (day: day, offset: signedOffset(from: day, to: anchorWeekday)) }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.offset)
                let rhsDistance = abs(rhs.offset)
                if lhsDistance == rhsDistance {
                    return lhs.offset > rhs.offset
                }
                return lhsDistance < rhsDistance
            }
            .first

        guard let offset = nearest?.offset else { return days }
        return Set(days.compactMap { weekday($0, shiftedBy: offset) })
    }

    private func signedOffset(from source: Weekday, to target: Weekday) -> Int {
        let forward = (target.rawValue - source.rawValue + 7) % 7
        return forward <= 3 ? forward : forward - 7
    }

    private func weekday(_ weekday: Weekday, shiftedBy offset: Int) -> Weekday? {
        let zeroBased = (weekday.rawValue - 1 + offset + 700) % 7
        return Weekday(rawValue: zeroBased + 1)
    }

    private func nextOccurrence(after anchorDay: Date, schedules: [DoseSchedule]) -> Date? {
        let calendar = Calendar.doseTrackCalendar
        for offset in 1...90 {
            let day = anchorDay.addingDays(offset)
            let candidates = schedules.compactMap { schedule -> Date? in
                guard schedule.occurs(on: day, calendar: calendar) else { return nil }
                return calendar.dateBySettingTime(hour: schedule.hour, minute: schedule.minute, on: day)
            }

            if let next = candidates.min() {
                return next
            }
        }

        return nil
    }

    // MARK: Injection sites

    static let defaultInjectionSites = [
        "Stomach - Upper Right",
        "Stomach - Upper Left",
        "Thigh - Right",
        "Thigh - Left",
        "Glute - Right",
        "Glute - Left"
    ]

    /// Site of the most recent administered dose that recorded one.
    var mostRecentInjectionSite: String? {
        logs
            .filter { $0.status == .taken && $0.site != nil }
            .max { ($0.takenAt ?? $0.scheduledAt) < ($1.takenAt ?? $1.scheduledAt) }?
            .site
    }

    // MARK: Cost

    /// Scheduled doses for a medication over the next 30 days.
    func monthlyDoseCount(for medication: Medication) -> Int {
        var count = 0
        var date = Date().startOfDay
        let end = date.addingDays(30)

        while date <= end {
            count += scheduledDoses(on: date).filter { $0.medication.id == medication.id }.count
            date = date.addingDays(1)
        }

        return count
    }

    func estimatedMonthlyCost(for medication: Medication) -> Double {
        Double(monthlyDoseCount(for: medication)) * (medication.costPerDose ?? 0)
    }

    var estimatedMonthlyCost: Double {
        medications
            .filter { $0.isActive && $0.costPerDose != nil }
            .reduce(0) { $0 + estimatedMonthlyCost(for: $1) }
    }

    // MARK: Pulse chat

    func appendChatMessage(_ message: ChatMessage) {
        chatMessages.append(message)
    }

    func clearChat() {
        chatMessages = []
    }
}
