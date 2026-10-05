import SwiftUI

@main
struct DoesTrackApp: App {
    @StateObject private var store: DoseStore

    init() {
        let store = DoseStore()
        _store = StateObject(wrappedValue: store)
        // Set before launch finishes so reminder actions tapped while the
        // app was closed are delivered.
        NotificationResponder.shared.install(store: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
