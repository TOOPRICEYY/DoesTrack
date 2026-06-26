import SwiftUI

@main
struct DoseTrackApp: App {
    @StateObject private var store = DoseStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
