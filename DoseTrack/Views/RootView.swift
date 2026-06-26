import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }

            MedicationListView()
                .tabItem {
                    Label("Meds", systemImage: "pills.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.xaxis")
                }

            SyncView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
        }
    }
}
