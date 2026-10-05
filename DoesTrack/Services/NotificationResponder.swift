import Foundation
import UserNotifications

/// Handles reminder actions (Mark Taken / Snooze) and foreground delivery.
/// Installed as the notification center delegate at launch so actions
/// tapped while the app wasn't running still reach the store.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationResponder()

    @MainActor weak var store: DoseStore?

    func install(store: DoseStore) {
        MainActor.assumeIsolated {
            self.store = store
        }
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let delivery = await MainActor.run { store?.notificationPreferences.delivery ?? .standard }
        switch delivery {
        case .standard: return [.banner, .list, .sound]
        case .silent: return [.banner, .list]
        case .passive: return [.list]
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let content = response.notification.request.content
        let keyString = content.userInfo[NotificationScheduler.doseKeyUserInfo] as? String

        switch action {
        case NotificationScheduler.takenAction:
            guard let keyString, let key = DoseReminderKey(string: keyString) else { return }
            await MainActor.run {
                guard let store, let dose = store.scheduledDose(for: key), dose.log == nil else { return }
                store.quickRecord(dose, status: .taken)
            }
        case NotificationScheduler.snoozeAction:
            await store?.snoozeNotification(content)
        default:
            break
        }
    }
}
