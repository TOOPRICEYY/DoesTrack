import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ProfileStorage.appearanceKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(OnboardingStorage.completedKey) private var onboardingCompleted = false
    @State private var showsStacks = false
    @State private var showsOnboarding = false
    @State private var showsFirstProtocolEditor = false
    @State private var opensEditorAfterOnboarding = false

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
        .sheet(isPresented: $showsFirstProtocolEditor) {
            ProtocolEditorView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showsOnboarding, onDismiss: {
            if opensEditorAfterOnboarding {
                opensEditorAfterOnboarding = false
                showsFirstProtocolEditor = true
            }
        }) {
            OnboardingView { outcome in
                onboardingCompleted = true
                opensEditorAfterOnboarding = outcome == .addProtocol
                showsOnboarding = false
            }
        }
        // A logged dose gets a success tap wherever it was logged from.
        .sensoryFeedback(trigger: takenDoseCount) { old, new in
            new > old ? .success : nil
        }
        .onAppear {
            AppAppearance.apply(rawValue: appearanceRaw)
            presentOnboardingIfNeeded()
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

    /// The welcome flow is for a genuinely new install. Anyone who already
    /// has data (an existing user updating, or a restored backup) skips it.
    private func presentOnboardingIfNeeded() {
        guard !onboardingCompleted else { return }
        let isFreshInstall = store.medications.isEmpty && store.logs.isEmpty
        if isFreshInstall && !OnboardingStorage.isSuppressedForTesting {
            showsOnboarding = true
        } else if !isFreshInstall {
            onboardingCompleted = true
        }
    }
}
