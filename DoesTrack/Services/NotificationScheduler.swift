import Foundation
import UserNotifications

/// Identifies one scheduled dose occurrence inside notification payloads.
struct DoseReminderKey: Hashable {
    var medicationID: UUID
    var scheduleID: UUID
    var scheduledAt: Date

    init(medicationID: UUID, scheduleID: UUID, scheduledAt: Date) {
        self.medicationID = medicationID
        self.scheduleID = scheduleID
        // Whole seconds, so keys survive a round trip through userInfo.
        self.scheduledAt = Date(timeIntervalSince1970: scheduledAt.timeIntervalSince1970.rounded(.down))
    }

    init(dose: ScheduledDose) {
        self.init(medicationID: dose.medication.id, scheduleID: dose.schedule.id, scheduledAt: dose.scheduledAt)
    }

    init?(string: String) {
        let parts = string.split(separator: "|")
        guard parts.count == 3,
              let medicationID = UUID(uuidString: String(parts[0])),
              let scheduleID = UUID(uuidString: String(parts[1])),
              let seconds = TimeInterval(String(parts[2]))
        else {
            return nil
        }
        self.init(medicationID: medicationID, scheduleID: scheduleID, scheduledAt: Date(timeIntervalSince1970: seconds))
    }

    var string: String {
        "\(medicationID.uuidString)|\(scheduleID.uuidString)|\(Int(scheduledAt.timeIntervalSince1970))"
    }
}

struct NotificationScheduler {
    /// iOS silently drops pending requests beyond 64 per app; stay under it
    /// and keep the soonest reminders.
    static let pendingRequestLimit = 60
    static let daysAhead = 28

    static let doseCategory = "doestrack.dose"
    static let generalCategory = "doestrack.general"
    static let takenAction = "doestrack.taken"
    static let snoozeAction = "doestrack.snooze"
    static let doseKeyUserInfo = "doseKey"
    static let kindUserInfo = "kind"
    static let snoozePrefix = "snooze-"
    static let threadIdentifier = "doestrack"
    /// Local time the weekly check-in reminder fires.
    static let checkInHour = 10

    enum Kind: String {
        case dose
        case followUp
        case summary
        case checkIn
        case test
    }

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.doseTrackCalendar

    func requestAuthorization() async throws -> Bool {
        // No badge: an app icon count is one more thing someone could notice.
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Registers action buttons and lock-screen behavior. Action titles stay
    /// neutral in generic mode so they don't hint at what the reminder is for.
    func registerCategories(preferences: NotificationPreferences) {
        let isGeneric = preferences.contentStyle == .generic
        let taken = UNNotificationAction(
            identifier: Self.takenAction,
            title: isGeneric ? "Done" : "Mark Taken",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: isGeneric ? "Later" : "Snooze \(preferences.snoozeMinutes) min",
            options: []
        )

        center.setNotificationCategories([
            makeCategory(identifier: Self.doseCategory, actions: [taken, snooze], preferences: preferences),
            makeCategory(identifier: Self.generalCategory, actions: [], preferences: preferences)
        ])
    }

    private func makeCategory(identifier: String, actions: [UNNotificationAction], preferences: NotificationPreferences) -> UNNotificationCategory {
        if preferences.hideOnLockScreen {
            // With previews hidden, iOS shows only the app name and this text.
            return UNNotificationCategory(
                identifier: identifier,
                actions: actions,
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: preferences.resolvedGenericBody,
                options: []
            )
        }
        return UNNotificationCategory(
            identifier: identifier,
            actions: actions,
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )
    }

    /// Builds every reminder for the window, soonest first, capped at the
    /// pending-request limit. Pure: does not touch the notification center.
    func makeRequests(
        doses: [ScheduledDose],
        preferences: NotificationPreferences,
        lastCheckIn: Date?,
        now: Date = Date()
    ) -> [UNNotificationRequest] {
        var dated: [(date: Date, request: UNNotificationRequest)] = []

        if preferences.doseRemindersEnabled {
            let due = doses.filter { $0.log == nil && $0.schedule.reminderEnabled && $0.medication.isActive }
            switch preferences.frequency {
            case .everyDose:
                dated.append(contentsOf: doseRequests(for: due, preferences: preferences, now: now))
            case .dailySummary:
                dated.append(contentsOf: summaryRequests(for: due, preferences: preferences, now: now))
            }
        }

        if preferences.checkInRemindersEnabled, let checkIn = checkInRequest(lastCheckIn: lastCheckIn, preferences: preferences, now: now) {
            dated.append(checkIn)
        }

        return dated
            .sorted { $0.date < $1.date }
            .prefix(Self.pendingRequestLimit)
            .map(\.request)
    }

    /// Replaces scheduled reminders with `requests`. Snoozes the user asked
    /// for survive unless their dose has since been logged; delivered
    /// reminders for logged doses are cleared from Notification Center.
    func apply(_ requests: [UNNotificationRequest], loggedKeys: Set<String>) async {
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending
            .filter { request in
                guard request.identifier.hasPrefix(Self.snoozePrefix) else { return true }
                let key = request.content.userInfo[Self.doseKeyUserInfo] as? String
                return key.map(loggedKeys.contains) ?? false
            }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)

        let delivered = await center.deliveredNotifications()
        let loggedDeliveredIDs = delivered
            .filter { notification in
                guard let key = notification.request.content.userInfo[Self.doseKeyUserInfo] as? String else { return false }
                return loggedKeys.contains(key)
            }
            .map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: loggedDeliveredIDs)

        for request in requests {
            try? await center.add(request)
        }
    }

    func removeAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Re-delivers a notification's content after the snooze interval.
    func snooze(_ content: UNNotificationContent, minutes: Int) async {
        guard let copy = content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, minutes) * 60), repeats: false)
        let identifier = "\(Self.snoozePrefix)\(UUID().uuidString)"
        try? await center.add(UNNotificationRequest(identifier: identifier, content: copy, trigger: trigger))
    }

    /// Fires a sample in a few seconds so the user can see exactly what
    /// their settings look like.
    func sendTest(preferences: NotificationPreferences, sampleMedication: Medication?) async throws {
        let content: UNMutableNotificationContent
        if let sampleMedication {
            let schedule = sampleMedication.schedules.first ?? DoseSchedule()
            content = doseContent(
                medication: sampleMedication,
                schedule: schedule,
                scheduledAt: Date().addingTimeInterval(TimeInterval(preferences.leadMinutes * 60)),
                kind: .dose,
                preferences: preferences
            )
        } else {
            content = baseContent(preferences: preferences, kind: .test, category: Self.generalCategory)
            content.title = preferences.contentStyle == .generic ? preferences.resolvedGenericTitle : "Test reminder"
            content.body = preferences.contentStyle == .generic ? preferences.resolvedGenericBody : "This is how DoesTrack reminders will look."
        }
        content.userInfo[Self.kindUserInfo] = Kind.test.rawValue
        content.userInfo.removeValue(forKey: Self.doseKeyUserInfo)
        content.categoryIdentifier = Self.generalCategory

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try await center.add(UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger))
    }

    // MARK: Request builders

    private func doseRequests(for doses: [ScheduledDose], preferences: NotificationPreferences, now: Date) -> [(date: Date, request: UNNotificationRequest)] {
        var output: [(date: Date, request: UNNotificationRequest)] = []

        for dose in doses {
            let key = DoseReminderKey(dose: dose).string
            let leadDate = dose.scheduledAt.addingTimeInterval(-TimeInterval(preferences.leadMinutes * 60))
            let fireAt = preferences.adjustedForQuietHours(leadDate, calendar: calendar)
            if fireAt > now {
                let content = doseContent(medication: dose.medication, schedule: dose.schedule, scheduledAt: dose.scheduledAt, kind: .dose, preferences: preferences)
                output.append((fireAt, request(identifier: "dose-\(key)", content: content, fireAt: fireAt)))
            }

            if preferences.followUpMinutes > 0 {
                let followUpAt = dose.scheduledAt.addingTimeInterval(TimeInterval(preferences.followUpMinutes * 60))
                // A nudge held until morning would be stale; drop it instead.
                let isQuiet = preferences.adjustedForQuietHours(followUpAt, calendar: calendar) != followUpAt
                if followUpAt > now, followUpAt > fireAt, !isQuiet {
                    let content = doseContent(medication: dose.medication, schedule: dose.schedule, scheduledAt: dose.scheduledAt, kind: .followUp, preferences: preferences)
                    output.append((followUpAt, request(identifier: "followup-\(key)", content: content, fireAt: followUpAt)))
                }
            }
        }

        return output
    }

    private func summaryRequests(for doses: [ScheduledDose], preferences: NotificationPreferences, now: Date) -> [(date: Date, request: UNNotificationRequest)] {
        let byDay = Dictionary(grouping: doses) { calendar.startOfDay(for: $0.scheduledAt) }

        return byDay.compactMap { day, dayDoses -> (date: Date, request: UNNotificationRequest)? in
            let sorted = dayDoses.sorted { $0.scheduledAt < $1.scheduledAt }
            guard let first = sorted.first else { return nil }
            let leadDate = first.scheduledAt.addingTimeInterval(-TimeInterval(preferences.leadMinutes * 60))
            let fireAt = preferences.adjustedForQuietHours(leadDate, calendar: calendar)
            guard fireAt > now else { return nil }

            let content = baseContent(preferences: preferences, kind: .summary, category: Self.generalCategory)
            let count = sorted.count
            let countText = "\(count) dose\(count == 1 ? "" : "s") scheduled today"
            switch preferences.contentStyle {
            case .detailed:
                content.title = countText
                content.body = sorted
                    .map { "\($0.medication.name) \($0.medication.displayDose) at \($0.scheduledAt.formatted(date: .omitted, time: .shortened))" }
                    .joined(separator: "\n")
            case .nameOnly:
                content.title = countText
                content.body = sorted.map { Self.discreetName(for: $0.medication) }.joined(separator: ", ")
            case .generic:
                content.title = preferences.resolvedGenericTitle
                content.body = preferences.resolvedGenericBody
            }

            let dayStamp = Int(day.timeIntervalSince1970)
            return (fireAt, request(identifier: "summary-\(dayStamp)", content: content, fireAt: fireAt))
        }
    }

    private func checkInRequest(lastCheckIn: Date?, preferences: NotificationPreferences, now: Date) -> (date: Date, request: UNNotificationRequest)? {
        let dueDay = max(now, (lastCheckIn ?? now).addingTimeInterval(7 * 86_400))
        guard var fireAt = calendar.dateBySettingTime(hour: Self.checkInHour, minute: 0, on: dueDay) else { return nil }
        if fireAt <= now {
            fireAt = calendar.dateBySettingTime(hour: Self.checkInHour, minute: 0, on: dueDay.addingDays(1)) ?? fireAt
        }
        fireAt = preferences.adjustedForQuietHours(fireAt, calendar: calendar)

        let content = baseContent(preferences: preferences, kind: .checkIn, category: Self.generalCategory)
        if preferences.contentStyle == .generic {
            content.title = preferences.resolvedGenericTitle
            content.body = preferences.resolvedGenericBody
        } else {
            content.title = "Weekly check-in"
            content.body = "Take a minute to note how you're feeling."
        }
        return (fireAt, request(identifier: "checkin", content: content, fireAt: fireAt))
    }

    // MARK: Content

    private func doseContent(medication: Medication, schedule: DoseSchedule, scheduledAt: Date, kind: Kind, preferences: NotificationPreferences) -> UNMutableNotificationContent {
        let content = baseContent(preferences: preferences, kind: kind, category: Self.doseCategory)
        content.userInfo[Self.doseKeyUserInfo] = DoseReminderKey(medicationID: medication.id, scheduleID: schedule.id, scheduledAt: scheduledAt).string

        let time = scheduledAt.formatted(date: .omitted, time: .shortened)
        let isEarly = kind == .dose && preferences.leadMinutes > 0

        switch preferences.contentStyle {
        case .detailed:
            switch kind {
            case .followUp: content.title = "Not logged yet: \(medication.name)"
            default: content.title = isEarly ? "Coming up at \(time): \(medication.name)" : "Dose due: \(medication.name)"
            }
            content.body = detailedBody(for: medication, schedule: schedule)
        case .nameOnly:
            let name = Self.discreetName(for: medication)
            switch kind {
            case .followUp: content.title = "Not logged yet: \(name)"
            default: content.title = isEarly ? "Coming up: \(name)" : "Reminder: \(name)"
            }
            content.body = "Scheduled for \(time)."
        case .generic:
            content.title = preferences.resolvedGenericTitle
            content.body = preferences.resolvedGenericBody
        }

        return content
    }

    private func baseContent(preferences: NotificationPreferences, kind: Kind, category: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = category
        content.threadIdentifier = Self.threadIdentifier
        content.userInfo = [Self.kindUserInfo: kind.rawValue]

        switch preferences.delivery {
        case .standard:
            content.sound = .default
            content.interruptionLevel = .active
        case .silent:
            content.sound = nil
            content.interruptionLevel = .active
        case .passive:
            content.sound = nil
            content.interruptionLevel = .passive
        }
        return content
    }

    private func request(identifier: String, content: UNNotificationContent, fireAt: Date) -> UNNotificationRequest {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func detailedBody(for medication: Medication, schedule: DoseSchedule) -> String {
        var parts = [medication.displayDose]
        if !schedule.label.isEmpty {
            parts.append(schedule.label)
        }
        if !medication.instructions.isEmpty {
            parts.append(medication.instructions)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " - ")
    }

    /// The medication's nickname when one is set, so "name only" reminders
    /// can avoid the real name entirely.
    static func discreetName(for medication: Medication) -> String {
        let nickname = medication.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nickname.isEmpty ? medication.name : nickname
    }
}
