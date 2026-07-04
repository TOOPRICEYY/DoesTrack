import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsStacks = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                ModelHomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                ModelTrackerView()
                    .tabItem {
                        Label("Tracker", systemImage: "chart.bar.fill")
                    }

                PulseView()
                    .tabItem {
                        Label("Pulse", systemImage: "brain.head.profile")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }

            Button {
                showsStacks = true
            } label: {
                Image(systemName: "square.grid.2x2.fill.badge.plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 76, height: 76)
                    .background(Color.blue.opacity(0.28), in: Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.8), lineWidth: 1)
                    }
            }
            .padding(.trailing, 24)
            .padding(.bottom, 64)
            .accessibilityLabel("Open optimization stacks")
        }
        .sheet(isPresented: $showsStacks) {
            ProtocolStacksView()
        }
        .task {
            store.resumeExpiredPauses()
            await store.syncNotificationsIfAuthorized()
            await store.performAutoSyncIfEnabled()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.resumeExpiredPauses()
            case .background:
                Task {
                    await store.performAutoSyncIfEnabled()
                }
            default:
                break
            }
        }
    }
}
