import Foundation

// MARK: - Supplements

enum SupplementBenefit: String, Codable, CaseIterable, Identifiable {
    case sleep = "Sleep"
    case recovery = "Recovery"
    case immunity = "Immunity"
    case energy = "Energy"
    case cognition = "Cognition"
    case heart = "Heart"
    case joints = "Joints"
    case gut = "Gut"

    var id: String { rawValue }
}

struct Supplement: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var dose: String
    var unit: String
    var benefits: [SupplementBenefit]
    var daysOfWeek: Set<Weekday>
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        dose: String = "",
        unit: String = "",
        benefits: [SupplementBenefit] = [],
        daysOfWeek: Set<Weekday> = Set(Weekday.allCases),
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dose = dose
        self.unit = unit
        self.benefits = benefits
        self.daysOfWeek = daysOfWeek
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var displayDose: String {
        [dose, unit].filter { !$0.isEmpty }.joined(separator: " ")
    }

    func isScheduled(on date: Date, calendar: Calendar = .doseTrackCalendar) -> Bool {
        guard isActive,
              let weekday = Weekday(rawValue: calendar.component(.weekday, from: date))
        else { return false }
        return daysOfWeek.contains(weekday)
    }
}

struct SupplementLog: Identifiable, Codable, Equatable {
    var id: UUID
    var supplementID: UUID
    var day: Date
    var takenAt: Date

    init(id: UUID = UUID(), supplementID: UUID, day: Date, takenAt: Date = Date()) {
        self.id = id
        self.supplementID = supplementID
        self.day = day.startOfDay
        self.takenAt = takenAt
    }
}

// MARK: - Labs

struct LabResult: Identifiable, Codable, Equatable {
    var id: UUID
    var marker: String
    var value: Double
    var unit: String
    var rangeLow: Double?
    var rangeHigh: Double?
    var sampledAt: Date

    init(
        id: UUID = UUID(),
        marker: String,
        value: Double,
        unit: String = "",
        rangeLow: Double? = nil,
        rangeHigh: Double? = nil,
        sampledAt: Date = Date()
    ) {
        self.id = id
        self.marker = marker
        self.value = value
        self.unit = unit
        self.rangeLow = rangeLow
        self.rangeHigh = rangeHigh
        self.sampledAt = sampledAt
    }

    var isOutOfRange: Bool {
        if let rangeLow, value < rangeLow { return true }
        if let rangeHigh, value > rangeHigh { return true }
        return false
    }

    var valueText: String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

// MARK: - Hydration

struct HydrationDay: Identifiable, Codable, Equatable {
    var id: Date { day }
    var day: Date
    var ounces: Double

    init(day: Date, ounces: Double) {
        self.day = day.startOfDay
        self.ounces = ounces
    }
}

// MARK: - Cycling

struct ProtocolCycle: Identifiable, Codable, Equatable {
    var id: UUID
    var stackName: String
    var weeksOn: Int
    var weeksOff: Int
    var startDate: Date

    init(id: UUID = UUID(), stackName: String, weeksOn: Int, weeksOff: Int, startDate: Date = Date()) {
        self.id = id
        self.stackName = stackName
        self.weeksOn = max(1, weeksOn)
        self.weeksOff = max(0, weeksOff)
        self.startDate = startDate.startOfDay
    }

    struct Phase: Equatable {
        var isOn: Bool
        var weekInPhase: Int
        var phaseLengthWeeks: Int
    }

    /// Phase for a date, cycling weeksOn then weeksOff from startDate.
    /// weeksOff == 0 means always on.
    func phase(on date: Date, calendar: Calendar = .doseTrackCalendar) -> Phase? {
        let days = calendar.dateComponents([.day], from: startDate, to: date.startOfDay).day ?? 0
        guard days >= 0 else { return nil }

        let week = days / 7
        guard weeksOff > 0 else {
            return Phase(isOn: true, weekInPhase: week + 1, phaseLengthWeeks: weeksOn)
        }

        let position = week % (weeksOn + weeksOff)
        if position < weeksOn {
            return Phase(isOn: true, weekInPhase: position + 1, phaseLengthWeeks: weeksOn)
        }
        return Phase(isOn: false, weekInPhase: position - weeksOn + 1, phaseLengthWeeks: weeksOff)
    }
}

// MARK: - Reconstitution

struct ReconPlan: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var vialMg: Double
    var waterMl: Double
    var doseMcg: Double
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        vialMg: Double,
        waterMl: Double,
        doseMcg: Double,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.vialMg = vialMg
        self.waterMl = waterMl
        self.doseMcg = doseMcg
        self.isActive = isActive
        self.createdAt = createdAt
    }

    /// mg per mL after reconstitution.
    var concentrationMgPerMl: Double? {
        guard vialMg > 0, waterMl > 0 else { return nil }
        return vialMg / waterMl
    }

    /// Volume to draw for one dose, in mL.
    var doseVolumeMl: Double? {
        guard let concentrationMgPerMl, concentrationMgPerMl > 0, doseMcg > 0 else { return nil }
        return (doseMcg / 1_000) / concentrationMgPerMl
    }

    /// Draw on a U-100 insulin syringe (100 units = 1 mL).
    var doseUnitsU100: Double? {
        doseVolumeMl.map { $0 * 100 }
    }

    var dosesPerVial: Double? {
        guard doseMcg > 0, vialMg > 0 else { return nil }
        return (vialMg * 1_000) / doseMcg
    }
}

// MARK: - Pulse chat

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID
    var role: Role
    var title: String?
    var text: String
    var bullets: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        title: String? = nil,
        text: String,
        bullets: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.text = text
        self.bullets = bullets
        self.createdAt = createdAt
    }
}

