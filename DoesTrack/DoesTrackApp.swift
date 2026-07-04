import SwiftUI

@main
struct DoesTrackApp: App {
    @StateObject private var store = DoseStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
