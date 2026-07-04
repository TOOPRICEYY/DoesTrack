import Foundation
import UserNotifications

struct NotificationScheduler {
    /// iOS silently drops pending requests beyond 64 per app; stay under it
    /// and keep the soonest reminders.
    static let pendingRequestLimit = 60

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.doseTrackCalendar

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func schedule(medications: [Medication], daysAhead: Int = 28) async throws {
        center.removeAllPendingNotificationRequests()

        let activeMedications = medications.filter(\.isActive)
        let today = Date().startOfDay
        var datedRequests: [(date: Date, request: UNNotificationRequest)] = []

        for offset in 0..<daysAhead {
            let date = today.addingDays(offset)
            for medication in activeMedications {
                for schedule in medication.schedules where schedule.reminderEnabled && schedule.occurs(on: date, calendar: calendar) {
                    guard let scheduledAt = calendar.dateBySettingTime(hour: schedule.hour, minute: schedule.minute, on: date),
                          scheduledAt > Date()
                    else {
                        continue
                    }

                    let content = UNMutableNotificationContent()
                    content.title = "Dose due: \(medication.name)"
                    content.body = notificationBody(for: medication, schedule: schedule)
                    content.sound = .default

                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledAt)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = "dose-\(medication.id.uuidString)-\(schedule.id.uuidString)-\(Int(scheduledAt.timeIntervalSince1970))"
                    datedRequests.append((scheduledAt, UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
                }
            }
        }

        let requests = datedRequests
            .sorted { $0.date < $1.date }
            .prefix(Self.pendingRequestLimit)
            .map(\.request)

        for request in requests {
            try await add(request)
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func notificationBody(for medication: Medication, schedule: DoseSchedule) -> String {
        var parts = [medication.displayDose]
        if !schedule.label.isEmpty {
            parts.append(schedule.label)
        }
        if !medication.instructions.isEmpty {
            parts.append(medication.instructions)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " - ")
    }
}
