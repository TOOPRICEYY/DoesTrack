import Foundation

/// Device-local reminder settings. Stored in UserDefaults rather than the
/// synced database so each device can be as discreet as its owner wants.
struct NotificationPreferences: Codable, Equatable {
    /// How much a reminder says about what is due.
    enum ContentStyle: String, Codable, CaseIterable, Identifiable {
        /// Medication name, dose, and route.
        case detailed
        /// Medication nickname (or name) only, no dose.
        case nameOnly
        /// The custom generic title and message; nothing medication-specific.
        case generic

        var id: String { rawValue }

        var label: String {
            switch self {
            case .detailed: return "Full details"
            case .nameOnly: return "Name only"
            case .generic: return "Generic"
            }
        }

        var explanation: String {
            switch self {
            case .detailed: return "Shows the medication name, dose, and route."
            case .nameOnly: return "Shows the medication nickname (or name if none is set), without dose or route."
            case .generic: return "Shows only your generic title and message. Nothing about medications appears."
            }
        }
    }

    /// How noticeable a reminder is when it arrives.
    enum Delivery: String, Codable, CaseIterable, Identifiable {
        /// Sound and banner.
        case standard
        /// Banner without sound.
        case silent
        /// Goes straight to Notification Center without sound or lighting the screen.
        case passive

        var id: String { rawValue }

        var label: String {
            switch self {
            case .standard: return "Sound"
            case .silent: return "Silent"
            case .passive: return "Quiet"
            }
        }

        var explanation: String {
            switch self {
            case .standard: return "Banner with the default sound."
            case .silent: return "Banner with no sound or vibration."
            case .passive: return "No sound, no banner, and the screen stays dark. Reminders wait in Notification Center."
            }
        }
    }

    /// How often dose reminders fire.
    enum Frequency: String, Codable, CaseIterable, Identifiable {
        /// One reminder for every scheduled dose.
        case everyDose
        /// One summary reminder per day, at the first dose time.
        case dailySummary

        var id: String { rawValue }

        var label: String {
            switch self {
            case .everyDose: return "Every dose"
            case .dailySummary: return "Once a day"
            }
        }
    }

    static let defaultGenericTitle = "Reminder"
    static let defaultGenericBody = "You have something scheduled."

    var doseRemindersEnabled = true
    var frequency = Frequency.everyDose
    var contentStyle = ContentStyle.detailed
    var genericTitle = Self.defaultGenericTitle
    var genericBody = Self.defaultGenericBody
    /// Keeps the title hidden too when iOS hides previews on the lock screen.
    var hideOnLockScreen = false
    var delivery = Delivery.standard
    /// Minutes before the dose time to remind. 0 = at the dose time.
    var leadMinutes = 0
    /// Minutes after the dose time to nudge again if nothing was logged. 0 = off.
    var followUpMinutes = 0
    var snoozeMinutes = 10
    var quietHoursEnabled = false
    /// Minutes after midnight.
    var quietHoursStart = 22 * 60
    var quietHoursEnd = 7 * 60
    var checkInRemindersEnabled = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case doseRemindersEnabled, frequency, contentStyle, genericTitle, genericBody
        case hideOnLockScreen, delivery, leadMinutes, followUpMinutes, snoozeMinutes
        case quietHoursEnabled, quietHoursStart, quietHoursEnd, checkInRemindersEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = NotificationPreferences()
        doseRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .doseRemindersEnabled) ?? defaults.doseRemindersEnabled
        frequency = (try? container.decodeIfPresent(Frequency.self, forKey: .frequency)) ?? defaults.frequency
        contentStyle = (try? container.decodeIfPresent(ContentStyle.self, forKey: .contentStyle)) ?? defaults.contentStyle
        genericTitle = try container.decodeIfPresent(String.self, forKey: .genericTitle) ?? defaults.genericTitle
        genericBody = try container.decodeIfPresent(String.self, forKey: .genericBody) ?? defaults.genericBody
        hideOnLockScreen = try container.decodeIfPresent(Bool.self, forKey: .hideOnLockScreen) ?? defaults.hideOnLockScreen
        delivery = (try? container.decodeIfPresent(Delivery.self, forKey: .delivery)) ?? defaults.delivery
        leadMinutes = try container.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? defaults.leadMinutes
        followUpMinutes = try container.decodeIfPresent(Int.self, forKey: .followUpMinutes) ?? defaults.followUpMinutes
        snoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? defaults.snoozeMinutes
        quietHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? defaults.quietHoursEnabled
        quietHoursStart = try container.decodeIfPresent(Int.self, forKey: .quietHoursStart) ?? defaults.quietHoursStart
        quietHoursEnd = try container.decodeIfPresent(Int.self, forKey: .quietHoursEnd) ?? defaults.quietHoursEnd
        checkInRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .checkInRemindersEnabled) ?? defaults.checkInRemindersEnabled
    }

    /// Title to show when content must stay generic; never empty.
    var resolvedGenericTitle: String {
        let trimmed = genericTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultGenericTitle : trimmed
    }

    var resolvedGenericBody: String {
        let trimmed = genericBody.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultGenericBody : trimmed
    }

    /// True when `minuteOfDay` falls inside quiet hours. Handles windows
    /// that wrap past midnight (e.g. 22:00–07:00).
    func isQuiet(minuteOfDay: Int) -> Bool {
        guard quietHoursEnabled, quietHoursStart != quietHoursEnd else { return false }
        if quietHoursStart < quietHoursEnd {
            return minuteOfDay >= quietHoursStart && minuteOfDay < quietHoursEnd
        }
        return minuteOfDay >= quietHoursStart || minuteOfDay < quietHoursEnd
    }

    /// Moves a fire date out of quiet hours to the moment they end.
    func adjustedForQuietHours(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        guard isQuiet(minuteOfDay: minuteOfDay) else { return date }

        let endHour = quietHoursEnd / 60
        let endMinute = quietHoursEnd % 60
        // Before the end time on the same day (the early-morning part of a
        // wrapping window, or a same-day window), quiet hours end today.
        // Otherwise they end tomorrow.
        let endsToday = minuteOfDay < quietHoursEnd
        let day = endsToday ? date : calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return calendar.dateBySettingTime(hour: endHour, minute: endMinute, on: day) ?? date
    }

    static func timeLabel(minuteOfDay: Int) -> String {
        let date = Calendar.doseTrackCalendar.dateBySettingTime(hour: minuteOfDay / 60, minute: minuteOfDay % 60, on: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
