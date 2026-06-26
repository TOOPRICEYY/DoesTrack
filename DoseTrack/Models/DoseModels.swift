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
    var startDate: Date
    var endDate: Date?
    var reminderEnabled: Bool

    init(
        id: UUID = UUID(),
        label: String = "Dose",
        hour: Int = 9,
        minute: Int = 0,
        amount: Double = 1,
        daysOfWeek: Set<Weekday> = Set(Weekday.allCases),
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
        self.startDate = startDate
        self.endDate = endDate
        self.reminderEnabled = reminderEnabled
    }

    var timeLabel: String {
        let date = Date.doseTrackCalendar.dateBySettingTime(hour: hour, minute: minute, on: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
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

        return daysOfWeek.contains(weekday)
    }
}

struct Medication: Identifiable, Codable, Equatable {
    var id: UUID
    var protocolName: String?
    var name: String
    var dose: String
    var unit: String
    var instructions: String
    var notes: String
    var colorHex: String
    var inventory: MedicationInventory
    var schedules: [DoseSchedule]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        protocolName: String? = nil,
        name: String,
        dose: String,
        unit: String,
        instructions: String = "",
        notes: String = "",
        colorHex: String = "#176B87",
        inventory: MedicationInventory = .empty,
        schedules: [DoseSchedule] = [DoseSchedule()],
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.protocolName = protocolName
        self.name = name
        self.dose = dose
        self.unit = unit
        self.instructions = instructions
        self.notes = notes
        self.colorHex = colorHex
        self.inventory = inventory
        self.schedules = schedules
        self.isActive = isActive
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
}

enum DoseLogStatus: String, Codable, CaseIterable, Identifiable {
    case taken
    case skipped
    case missed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        }
    }

    var systemImage: String {
        switch self {
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        }
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

    init(
        id: UUID = UUID(),
        medicationID: UUID,
        scheduleID: UUID?,
        scheduledAt: Date,
        takenAt: Date? = Date(),
        status: DoseLogStatus,
        amount: Double,
        notes: String = ""
    ) {
        self.id = id
        self.medicationID = medicationID
        self.scheduleID = scheduleID
        self.scheduledAt = scheduledAt
        self.takenAt = takenAt
        self.status = status
        self.amount = amount
        self.notes = notes
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
        effectiveStatus == nil || effectiveStatus == .missed
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
        filePath: String = "DoseTrack/dosetrack-sync.json",
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

struct DoseDatabase: Codable, Equatable {
    var medications: [Medication]
    var logs: [DoseLog]
    var syncSettings: GitHubSyncSettings
}

struct DoseBackup: Codable, Equatable {
    var schemaVersion: Int
    var exportedAt: Date
    var medications: [Medication]
    var logs: [DoseLog]

    static let currentSchemaVersion = 1
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
