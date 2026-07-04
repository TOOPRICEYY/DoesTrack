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
    static let hydrationSipOunces = 8.0

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
        reconPlans.removeAll { $0.id == plan.id }
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
