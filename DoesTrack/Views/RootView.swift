import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ProfileStorage.appearanceKey) private var appearanceRaw = AppAppearance.system.rawValue
    @State private var showsStacks = false

    private var takenDoseCount: Int {
        store.logs.filter { $0.status == .taken }.count
    }

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
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 54, height: 54)
                    .background(Color.appBlue.opacity(0.16), in: Circle())
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle().stroke(.primary.opacity(0.10), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 64)
            .accessibilityLabel("Open optimization stacks")
        }
        .sheet(isPresented: $showsStacks) {
            ProtocolStacksView()
        }
        // A logged dose gets a success tap wherever it was logged from.
        .sensoryFeedback(trigger: takenDoseCount) { old, new in
            new > old ? .success : nil
        }
        .onAppear {
            AppAppearance.apply(rawValue: appearanceRaw)
        }
        .onChange(of: appearanceRaw) { _, newValue in
            AppAppearance.apply(rawValue: newValue)
        }
        .task {
            store.resumeExpiredPauses()
            await store.syncNotificationsIfAuthorized()
            await store.performICloudAutoSyncIfEnabled()
            await store.performAutoSyncIfEnabled()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.resumeExpiredPauses()
                Task {
                    // Rolls the reminder window forward and picks up
                    // permission changes made in Settings.
                    await store.syncNotificationsIfAuthorized()
                    await store.performICloudAutoSyncIfEnabled()
                }
            case .background:
                Task {
                    await store.performICloudAutoSyncIfEnabled()
                    await store.performAutoSyncIfEnabled()
                }
            default:
                break
            }
        }
    }
}
