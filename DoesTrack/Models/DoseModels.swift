import Foundation
import SwiftUI

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct MedicationInventory: Codable, Equatable {
    var currentQuantity: Double
    var lowQuantityThreshold: Double
    var refillQuantity: Double
    var unitLabel: String
    var nextRefillDate: Date?

    static let empty = MedicationInventory(
        currentQuantity: 0,
        lowQuantityThreshold: 5,
        refillQuantity: 30,
        unitLabel: "pills",
        nextRefillDate: nil
    )

    var isTracked: Bool {
        currentQuantity > 0 || lowQuantityThreshold > 0 || nextRefillDate != nil
    }

    var needsRefill: Bool {
        currentQuantity <= lowQuantityThreshold || Date.doseTrackCalendar.isDateInToday(nextRefillDate ?? .distantFuture)
    }
}

struct DoseSchedule: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var amount: Double
    var daysOfWeek: Set<Weekday>
    var intervalDays: Int?
    var startDate: Date
    var endDate: Date?
    var reminderEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case hour
        case minute
        case amount
        case daysOfWeek
        case intervalDays
        case startDate
        case endDate
        case reminderEnabled
    }

    init(
        id: UUID = UUID(),
        label: String = "Dose",
        hour: Int = 9,
        minute: Int = 0,
        amount: Double = 1,
        daysOfWeek: Set<Weekday> = Set(Weekday.allCases),
        intervalDays: Int? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        reminderEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.amount = amount
        self.daysOfWeek = daysOfWeek
        self.intervalDays = intervalDays.map { max(1, $0) }
        self.startDate = startDate
        self.endDate = endDate
        self.reminderEnabled = reminderEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        hour = try container.decode(Int.self, forKey: .hour)
        minute = try container.decode(Int.self, forKey: .minute)
        amount = try container.decode(Double.self, forKey: .amount)
        daysOfWeek = try container.decodeIfPresent(Set<Weekday>.self, forKey: .daysOfWeek) ?? Set(Weekday.allCases)
        intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays).map { max(1, $0) }
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? true
    }

    var timeLabel: String {
        let date = Date.doseTrackCalendar.dateBySettingTime(hour: hour, minute: minute, on: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var frequencyLabel: String {
        if let intervalDays, intervalDays > 1 {
            return intervalDays == 2 ? "Every 2 Days" : "Every \(intervalDays) Days"
        }

        switch daysOfWeek.count {
        case 7: return "Daily"
        case 1: return "Weekly"
        case 2: return "Twice Weekly"
        default: return "\(daysOfWeek.count)x Weekly"
        }
    }

    func occurs(on date: Date, calendar: Calendar = .doseTrackCalendar) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let scheduleStart = calendar.startOfDay(for: startDate)

        guard dayStart >= scheduleStart else { return false }
        if let endDate, dayStart > calendar.startOfDay(for: endDate) {
            return false
        }

        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: dayStart)) else {
            return false
        }

        if let intervalDays, intervalDays > 1 {
            let elapsedDays = calendar.dateComponents([.day], from: scheduleStart, to: dayStart).day ?? 0
            return elapsedDays >= 0 && elapsedDays.isMultiple(of: intervalDays)
        }

        return daysOfWeek.contains(weekday)
    }
}

struct Medication: Identifiable, Codable, Equatable {
    var id: UUID
    var protocolName: String?
    var name: String
    var displayName: String?
    var dose: String
    var unit: String
    var instructions: String
    var notes: String
    var colorHex: String
    var inventory: MedicationInventory
    var schedules: [DoseSchedule]
    var isActive: Bool
    var pausedUntil: Date?
    var costPerDose: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        protocolName: String? = nil,
        name: String,
        displayName: String? = nil,
        dose: String,
        unit: String,
        instructions: String = "",
        notes: String = "",
        colorHex: String = "#176B87",
        inventory: MedicationInventory = .empty,
        schedules: [DoseSchedule] = [DoseSchedule()],
        isActive: Bool = true,
        pausedUntil: Date? = nil,
        costPerDose: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.protocolName = protocolName
        self.name = name
        self.displayName = displayName
        self.dose = dose
        self.unit = unit
        self.instructions = instructions
        self.notes = notes
        self.colorHex = colorHex
        self.inventory = inventory
        self.schedules = schedules
        self.isActive = isActive
        self.pausedUntil = pausedUntil
        self.costPerDose = costPerDose
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayDose: String {
        [dose, unit].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var stackName: String {
        let trimmed = protocolName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? name : trimmed
    }

    var frequencyLabel: String {
        guard !schedules.isEmpty else { return "" }

        let groupedByTime = Dictionary(grouping: schedules) { schedule in
            "\(schedule.hour):\(schedule.minute)"
        }

        if schedules.count == 2,
           groupedByTime.count == 2,
           schedules.allSatisfy({ $0.intervalDays == nil && $0.daysOfWeek == Set(Weekday.allCases) }) {
            return "Twice Daily"
        }

        if schedules.count == 1 {
            return schedules[0].frequencyLabel
        }

        let uniqueFrequencies = Set(schedules.map(\.frequencyLabel))
        if uniqueFrequencies.count == 1, let first = uniqueFrequencies.first {
            return "\(schedules.count)x \(first)"
        }

        return "\(schedules.count) schedules"
    }
}

enum DoseLogStatus: String, Codable, CaseIterable, Identifiable {
    case taken
    case skipped
    case missed
    case wasted

    var id: String { rawValue }

    var label: String {
        switch self {
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        case .wasted: return "Wasted"
        }
    }

    var systemImage: String {
        switch self {
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .wasted: return "trash.fill"
        }
    }

    var tint: Color {
        switch self {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        case .wasted: return .orange
        }
    }

    var deductsInventory: Bool {
        self == .taken || self == .wasted
    }
}

struct DoseLog: Identifiable, Codable, Equatable {
    var id: UUID
    var medicationID: UUID
    var scheduleID: UUID?
    var scheduledAt: Date
    var takenAt: Date?
    var status: DoseLogStatus
    var amount: Double
    var notes: String
    var method: String?
    var site: String?
    var painLevel: Int?
    var siteReaction: String?
    var skipReason: String?

    init(
        id: UUID = UUID(),
        medicationID: UUID,
        scheduleID: UUID?,
        scheduledAt: Date,
        takenAt: Date? = Date(),
        status: DoseLogStatus,
        amount: Double,
        notes: String = "",
        method: String? = nil,
        site: String? = nil,
        painLevel: Int? = nil,
        siteReaction: String? = nil,
        skipReason: String? = nil
    ) {
        self.id = id
        self.medicationID = medicationID
        self.scheduleID = scheduleID
        self.scheduledAt = scheduledAt
        self.takenAt = takenAt
        self.status = status
        self.amount = amount
        self.notes = notes
        self.method = method
        self.site = site
        self.painLevel = painLevel
        self.siteReaction = siteReaction
        self.skipReason = skipReason
    }
}

struct ScheduledDose: Identifiable, Equatable {
    var id: String
    var medication: Medication
    var schedule: DoseSchedule
    var scheduledAt: Date
    var log: DoseLog?

    var effectiveStatus: DoseLogStatus? {
        if let status = log?.status {
            return status
        }

        return scheduledAt < Date() ? .missed : nil
    }

    var isActionable: Bool {
        effectiveStatus == nil || effectiveStatus == .missed || effectiveStatus == .wasted
    }
}

struct GitHubSyncSettings: Codable, Equatable {
    var owner: String
    var repository: String
    var branch: String
    var filePath: String
    var lastRemoteSHA: String?
    var lastSyncedAt: Date?

    init(
        owner: String = "",
        repository: String = "",
        branch: String = "main",
        filePath: String = "DoesTrack/doestrack-sync.json",
        lastRemoteSHA: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.owner = owner
        self.repository = repository
        self.branch = branch
        self.filePath = filePath
        self.lastRemoteSHA = lastRemoteSHA
        self.lastSyncedAt = lastSyncedAt
    }

    var isRepositoryConfigured: Bool {
        !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !repository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct HealthMetricSample: Codable, Equatable {
    var value: Double
    var unit: String
    var startDate: Date
    var endDate: Date
}

struct HealthMetricsSnapshot: Codable, Equatable {
    var isHealthKitEnabled: Bool
    var lastAuthorizationRequestedAt: Date?
    var lastSyncedAt: Date?
    var lastSyncError: String?
    var bodyMassPounds: HealthMetricSample?
    var previousBodyMassPounds: HealthMetricSample?
    var restingHeartRateBPM: HealthMetricSample?
    var bloodPressureSystolicMMHg: HealthMetricSample?
    var bloodPressureDiastolicMMHg: HealthMetricSample?
    var sleepHours: HealthMetricSample?
    var stepCount: HealthMetricSample?
    var activeEnergyKilocalories: HealthMetricSample?

    static let empty = HealthMetricsSnapshot(
        isHealthKitEnabled: false,
        lastAuthorizationRequestedAt: nil,
        lastSyncedAt: nil,
        lastSyncError: nil,
        bodyMassPounds: nil,
        previousBodyMassPounds: nil,
        restingHeartRateBPM: nil,
        bloodPressureSystolicMMHg: nil,
        bloodPressureDiastolicMMHg: nil,
        sleepHours: nil,
        stepCount: nil,
        activeEnergyKilocalories: nil
    )

    var hasAnyData: Bool {
        bodyMassPounds != nil ||
        restingHeartRateBPM != nil ||
        bloodPressureSystolicMMHg != nil ||
        bloodPressureDiastolicMMHg != nil ||
        sleepHours != nil ||
        stepCount != nil ||
        activeEnergyKilocalories != nil
    }

    var weightValueText: String {
        guard let bodyMassPounds else { return "-" }
        return "\(bodyMassPounds.value.formatted(.number.precision(.fractionLength(1)))) lb"
    }

    var weightSubtitleText: String {
        guard let bodyMassPounds else { return "Connect Apple Health" }
        return "Updated \(bodyMassPounds.endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var weightTrendText: String {
        guard let latest = bodyMassPounds,
              let previous = previousBodyMassPounds
        else { return "-" }

        let delta = latest.value - previous.value
        guard abs(delta) >= 0.05 else { return "Stable" }
        let sign = delta > 0 ? "+" : "-"
        return "\(sign)\(abs(delta).formatted(.number.precision(.fractionLength(1)))) lb"
    }

    var weightTrendSubtitleText: String {
        guard let previousBodyMassPounds else { return "Needs 2 Health weight samples" }
        return "since \(previousBodyMassPounds.endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var restingHeartRateText: String {
        guard let restingHeartRateBPM else { return "-" }
        return "\(restingHeartRateBPM.value.formatted(.number.precision(.fractionLength(0)))) bpm"
    }

    var restingHeartRateSubtitleText: String {
        guard let restingHeartRateBPM else { return "Connect Apple Health" }
        return "Updated \(restingHeartRateBPM.endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var bloodPressureText: String {
        guard let systolic = bloodPressureSystolicMMHg,
              let diastolic = bloodPressureDiastolicMMHg
        else { return "-" }

        let systolicText = systolic.value.formatted(.number.precision(.fractionLength(0)))
        let diastolicText = diastolic.value.formatted(.number.precision(.fractionLength(0)))
        return "\(systolicText)/\(diastolicText)"
    }

    var bloodPressureSubtitleText: String {
        guard let latest = [bloodPressureSystolicMMHg, bloodPressureDiastolicMMHg].compactMap({ $0 }).map(\.endDate).max() else {
            return "Connect Apple Health"
        }
        return "Updated \(latest.formatted(date: .abbreviated, time: .omitted))"
    }

    var sleepText: String {
        guard let sleepHours else { return "-" }
        let totalMinutes = Int((sleepHours.value * 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    var sleepSubtitleText: String {
        guard let sleepHours else { return "Connect Apple Health" }
        return "Ended \(sleepHours.endDate.formatted(date: .abbreviated, time: .shortened))"
    }

    var stepCountText: String {
        guard let stepCount else { return "-" }
        return stepCount.value.formatted(.number.precision(.fractionLength(0)))
    }

    var activeEnergyText: String {
        guard let activeEnergyKilocalories else { return "-" }
        return "\(activeEnergyKilocalories.value.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    var statusText: String {
        if let lastSyncError, !lastSyncError.isEmpty {
            return lastSyncError
        }
        if let lastSyncedAt {
            return "Last synced \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return isHealthKitEnabled ? "Connected. Sync to load metrics." : "Not connected"
    }
}

enum SymptomCheckInArea: String, Codable, CaseIterable, Identifiable {
    case mental
    case physical
    case sexual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mental: return "Mental"
        case .physical: return "Physical"
        case .sexual: return "Sexual"
        }
    }

    var sectionTitle: String {
        switch self {
        case .mental: return "Symptom management"
        case .physical: return "Body"
        case .sexual: return "Sexual health"
        }
    }

    var symptomNames: [String] {
        switch self {
        case .mental:
            return ["Mood", "Focus", "Anxiety", "Motivation", "Irritability"]
        case .physical:
            return ["Energy", "Sleep quality", "Joint pain", "Recovery", "Appetite"]
        case .sexual:
            return ["Libido", "Performance", "Morning response", "Satisfaction", "Confidence"]
        }
    }
}

struct SymptomCheckIn: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var ratings: [String: Int]
    var notes: String
    var weightPounds: Double?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        ratings: [String: Int],
        notes: String = "",
        weightPounds: Double? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.ratings = ratings
        self.notes = notes
        self.weightPounds = weightPounds
    }

    var averageRating: Double? {
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.values.reduce(0, +)) / Double(ratings.count)
    }
}

struct DoseDatabase: Codable, Equatable {
    var medications: [Medication]
    var logs: [DoseLog]
    var syncSettings: GitHubSyncSettings
    var healthMetrics: HealthMetricsSnapshot
    var symptomCheckIns: [SymptomCheckIn]
    var supplements: [Supplement]
    var supplementLogs: [SupplementLog]
    var labResults: [LabResult]
    var hydrationDays: [HydrationDay]
    var cycles: [ProtocolCycle]
    var reconPlans: [ReconPlan]
    var chatMessages: [ChatMessage]

    init(
        medications: [Medication],
        logs: [DoseLog],
        syncSettings: GitHubSyncSettings,
        healthMetrics: HealthMetricsSnapshot = .empty,
        symptomCheckIns: [SymptomCheckIn] = [],
        supplements: [Supplement] = [],
        supplementLogs: [SupplementLog] = [],
        labResults: [LabResult] = [],
        hydrationDays: [HydrationDay] = [],
        cycles: [ProtocolCycle] = [],
        reconPlans: [ReconPlan] = [],
        chatMessages: [ChatMessage] = []
    ) {
        self.medications = medications
        self.logs = logs
        self.syncSettings = syncSettings
        self.healthMetrics = healthMetrics
        self.symptomCheckIns = symptomCheckIns
        self.supplements = supplements
        self.supplementLogs = supplementLogs
        self.labResults = labResults
        self.hydrationDays = hydrationDays
        self.cycles = cycles
        self.reconPlans = reconPlans
        self.chatMessages = chatMessages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        medications = try container.decode([Medication].self, forKey: .medications)
        logs = try container.decode([DoseLog].self, forKey: .logs)
        syncSettings = try container.decodeIfPresent(GitHubSyncSettings.self, forKey: .syncSettings) ?? GitHubSyncSettings()
        healthMetrics = try container.decodeIfPresent(HealthMetricsSnapshot.self, forKey: .healthMetrics) ?? .empty
        symptomCheckIns = try container.decodeIfPresent([SymptomCheckIn].self, forKey: .symptomCheckIns) ?? []
        supplements = try container.decodeIfPresent([Supplement].self, forKey: .supplements) ?? []
        supplementLogs = try container.decodeIfPresent([SupplementLog].self, forKey: .supplementLogs) ?? []
        labResults = try container.decodeIfPresent([LabResult].self, forKey: .labResults) ?? []
        hydrationDays = try container.decodeIfPresent([HydrationDay].self, forKey: .hydrationDays) ?? []
        cycles = try container.decodeIfPresent([ProtocolCycle].self, forKey: .cycles) ?? []
        reconPlans = try container.decodeIfPresent([ReconPlan].self, forKey: .reconPlans) ?? []
        chatMessages = try container.decodeIfPresent([ChatMessage].self, forKey: .chatMessages) ?? []
    }
}

struct DoseBackup: Codable, Equatable {
    var schemaVersion: Int
    var exportedAt: Date
    var medications: [Medication]
    var logs: [DoseLog]
    var symptomCheckIns: [SymptomCheckIn]
    var supplements: [Supplement]
    var supplementLogs: [SupplementLog]
    var labResults: [LabResult]
    var hydrationDays: [HydrationDay]
    var cycles: [ProtocolCycle]
    var reconPlans: [ReconPlan]

    // Chat messages are deliberately excluded: the Pulse chat promises
    // "stored on device only".
    static let currentSchemaVersion = 3

    init(
        schemaVersion: Int,
        exportedAt: Date,
        medications: [Medication],
        logs: [DoseLog],
        symptomCheckIns: [SymptomCheckIn] = [],
        supplements: [Supplement] = [],
        supplementLogs: [SupplementLog] = [],
        labResults: [LabResult] = [],
        hydrationDays: [HydrationDay] = [],
        cycles: [ProtocolCycle] = [],
        reconPlans: [ReconPlan] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.medications = medications
        self.logs = logs
        self.symptomCheckIns = symptomCheckIns
        self.supplements = supplements
        self.supplementLogs = supplementLogs
        self.labResults = labResults
        self.hydrationDays = hydrationDays
        self.cycles = cycles
        self.reconPlans = reconPlans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        medications = try container.decode([Medication].self, forKey: .medications)
        logs = try container.decode([DoseLog].self, forKey: .logs)
        symptomCheckIns = try container.decodeIfPresent([SymptomCheckIn].self, forKey: .symptomCheckIns) ?? []
        supplements = try container.decodeIfPresent([Supplement].self, forKey: .supplements) ?? []
        supplementLogs = try container.decodeIfPresent([SupplementLog].self, forKey: .supplementLogs) ?? []
        labResults = try container.decodeIfPresent([LabResult].self, forKey: .labResults) ?? []
        hydrationDays = try container.decodeIfPresent([HydrationDay].self, forKey: .hydrationDays) ?? []
        cycles = try container.decodeIfPresent([ProtocolCycle].self, forKey: .cycles) ?? []
        reconPlans = try container.decodeIfPresent([ReconPlan].self, forKey: .reconPlans) ?? []
    }
}

struct ProtocolStack: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var medications: [Medication]

    var isActive: Bool {
        medications.contains(where: \.isActive)
    }

    var startedAt: Date? {
        medications.map(\.createdAt).min()
    }

    var medicationCount: Int {
        medications.count
    }

    var inventoryCount: Int {
        medications.filter { $0.inventory.isTracked }.count
    }

    var subtitle: String {
        medications.prefix(2).map(\.name).joined(separator: " + ")
    }
}

struct ProtocolTemplate: Identifiable {
    var id: String { name }
    var name: String
    var subtitle: String
    var medications: [Medication]

    static let suggested: [ProtocolTemplate] = [
        ProtocolTemplate(
            name: "Immune Modulation Stack",
            subtitle: "Thymic peptides + antimicrobial",
            medications: [
                Medication(
                    protocolName: "Immune Modulation Stack",
                    name: "Thymosin Alpha-1",
                    dose: "1.5",
                    unit: "mg",
                    instructions: "SubQ",
                    colorHex: "#1687F3",
                    schedules: [DoseSchedule(label: "Evening", hour: 20, minute: 0, amount: 1, daysOfWeek: [.monday, .wednesday, .friday])]
                ),
                Medication(
                    protocolName: "Immune Modulation Stack",
                    name: "BPC-157",
                    dose: "250",
                    unit: "mcg",
                    instructions: "SubQ",
                    colorHex: "#56C7F5",
                    schedules: [DoseSchedule(label: "Morning", hour: 8, minute: 0, amount: 1)]
                )
            ]
        ),
        ProtocolTemplate(
            name: "Longevity Stack",
            subtitle: "Telomere + antioxidant defense",
            medications: [
                Medication(
                    protocolName: "Longevity Stack",
                    name: "NAD+",
                    dose: "100",
                    unit: "mg",
                    instructions: "Injection",
                    colorHex: "#1687F3",
                    schedules: [DoseSchedule(label: "Morning", hour: 8, minute: 30, amount: 1, daysOfWeek: [.monday, .thursday])]
                ),
                Medication(
                    protocolName: "Longevity Stack",
                    name: "Glutathione",
                    dose: "200",
                    unit: "mg",
                    instructions: "Injection",
                    colorHex: "#34C759",
                    schedules: [DoseSchedule(label: "Afternoon", hour: 14, minute: 0, amount: 1, daysOfWeek: [.tuesday, .friday])]
                )
            ]
        ),
        ProtocolTemplate(
            name: "TRT+",
            subtitle: "Hormone optimization baseline",
            medications: [
                Medication(
                    protocolName: "TRT+",
                    name: "Testosterone Cypionate",
                    dose: "25",
                    unit: "mg",
                    instructions: "SubQ",
                    colorHex: "#19C7D3",
                    schedules: [DoseSchedule(label: "Injection", hour: 9, minute: 0, amount: 1, daysOfWeek: [.monday, .thursday])]
                ),
                Medication(
                    protocolName: "TRT+",
                    name: "hCG (Human Chorionic Gonadotropin)",
                    dose: "300",
                    unit: "IU",
                    instructions: "SubQ",
                    colorHex: "#B75CFF",
                    schedules: [DoseSchedule(label: "Injection", hour: 9, minute: 0, amount: 1, daysOfWeek: [.monday, .thursday])]
                )
            ]
        )
    ]
}
