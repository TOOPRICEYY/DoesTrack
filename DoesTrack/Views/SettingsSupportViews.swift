import SwiftUI
import UserNotifications

private let settingsBackground = Color.appBackground
private let settingsBlue = Color.appBlue

enum SettingsTopic: String, Identifiable {
    case notifications
    case healthData
    case preferences
    case timeZone
    case citations
    case about
    case faq
    case appUserID

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .healthData: return "Health Data"
        case .preferences: return "Preferences"
        case .timeZone: return "Time Zone"
        case .citations: return "Medical Citations"
        case .about: return "About This App"
        case .faq: return "FAQ"
        case .appUserID: return "App User ID"
        }
    }

    var systemImage: String {
        switch self {
        case .notifications: return "bell.fill"
        case .healthData: return "heart.fill"
        case .preferences: return "slider.horizontal.3"
        case .timeZone: return "globe.americas.fill"
        case .citations: return "doc.text.fill"
        case .about: return "info.circle.fill"
        case .faq: return "questionmark.circle.fill"
        case .appUserID: return "person.crop.circle.badge.questionmark"
        }
    }
}

struct SettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("doseTrackAppUserID") private var appUserID = ""
    var topic: SettingsTopic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsDetailCard {
                        Label(topic.title, systemImage: topic.systemImage)
                            .font(.title2.bold())
                            .foregroundStyle(settingsBlue)
                        Text(primaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    if topic == .healthData {
                        HealthDataSettingsView()
                    } else if topic == .notifications {
                        NotificationSettingsView()
                        ForEach(detailRows, id: \.self) { row in
                            SettingsDetailCard {
                                Label(row, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    } else {
                        ForEach(detailRows, id: \.self) { row in
                            SettingsDetailCard {
                                Label(row, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(settingsBackground.ignoresSafeArea())
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if appUserID.isEmpty {
                    appUserID = UUID().uuidString
                }
            }
        }
    }

    private var primaryText: String {
        switch topic {
        case .notifications:
            return "Local dose reminders are scheduled from active medication schedules."
        case .healthData:
            return "Connect Apple Health to read weight, sleep, heart, blood pressure, step, and energy metrics for local DoesTrack cards."
        case .preferences:
            return "DoesTrack currently uses medication-level units, route, schedule, inventory, and reminder preferences."
        case .timeZone:
            return "Schedules use the device time zone through the app calendar."
        case .citations:
            return "PK citations are attached inside Pulse > PK Model and summarized below."
        case .about:
            return "DoesTrack is a local-first SwiftUI protocol and medication tracker with optional GitHub repository backup."
        case .faq:
            return "Frequently asked operational questions are covered by the Pulse protocol question cards."
        case .appUserID:
            return appUserID.isEmpty ? "Generating..." : appUserID
        }
    }

    private var detailRows: [String] {
        switch topic {
        case .notifications:
            return ["Active schedules create local notifications.", "Paused medications are excluded.", "Reminder state follows each saved schedule."]
        case .healthData:
            return ["Read-only HealthKit access.", "Health metrics stay local in this app data store.", "GitHub backup sync excludes HealthKit raw history."]
        case .preferences:
            return ["Per-medication dose units are saved.", "Routes are saved as protocol preferences.", "Inventory thresholds are stored per medication."]
        case .timeZone:
            return ["Schedule times are interpreted using the current device calendar.", "Travel-specific timezone overrides are not persisted yet."]
        case .citations:
            return ["DailyMed Mounjaro label for tirzepatide.", "Mannaerts 1998 and Saal 1991 for hCG.", "Nankin 1987 and DailyMed Depo-Testosterone for testosterone cypionate context.", "Wu et al. 2022 Frontiers in Pharmacology preclinical ADME study for BPC-157."]
        case .about:
            return ["Local JSON storage.", "Optional GitHub Contents API sync.", "No clinical dosing recommendations."]
        case .faq:
            return ["Add protocols from the stack button.", "Log doses from calendar/history surfaces.", "Review model limitations in Pulse > PK Model."]
        case .appUserID:
            return ["Use this ID only for support correlation.", "It is generated locally and stored in app preferences."]
        }
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var isWorking = false
    @State private var statusMessage = ""

    var body: some View {
        SettingsDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isEnabled ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.title2)
                        .foregroundStyle(isEnabled ? settingsBlue : .orange)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(isEnabled ? "Reminders On" : "Reminders Off")
                            .font(.headline)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Button {
                    enable()
                } label: {
                    if isWorking {
                        Label("Working", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label(isEnabled ? "Refresh Reminders" : "Enable Reminders", systemImage: "bell.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(settingsBlue)
                .disabled(isWorking)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await store.refreshNotificationAuthorization()
        }
    }

    private var isEnabled: Bool {
        store.notificationAuthorization == .authorized || store.notificationAuthorization == .provisional
    }

    private var statusText: String {
        switch store.notificationAuthorization {
        case .authorized, .provisional, .ephemeral:
            return "Dose reminders are scheduled from your active medication schedules."
        case .denied:
            return "Permission was denied. Enable notifications for DoesTrack in iOS Settings."
        default:
            return "Enable reminders to get notified when a dose is due."
        }
    }

    private func enable() {
        isWorking = true
        statusMessage = ""

        Task {
            do {
                let granted = try await store.enableNotifications()
                statusMessage = granted
                    ? "Reminders scheduled for your upcoming doses."
                    : "Notification permission was not granted."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

private struct HealthDataSettingsView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var isSyncing = false
    @State private var statusMessage = ""

    private let healthKit = HealthKitService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: healthKit.isAvailable ? "heart.text.square.fill" : "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(healthKit.isAvailable ? settingsBlue : .orange)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.healthMetrics.isHealthKitEnabled ? "Apple Health Connected" : "Connect Apple Health")
                                .font(.headline)
                            Text(store.healthMetrics.statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Button {
                        syncHealthData()
                    } label: {
                        if isSyncing {
                            Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label(store.healthMetrics.isHealthKitEnabled ? "Sync Health Data" : "Connect & Sync", systemImage: "heart.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settingsBlue)
                    .disabled(isSyncing || !healthKit.isAvailable)

                    if !healthKit.isAvailable {
                        Text("Apple Health is available on iPhone and supported Apple devices. It is not available in every simulator or device family.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("SYNCED METRICS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            SettingsDetailCard {
                VStack(spacing: 14) {
                    HealthMetricRow(title: "Latest Weight", value: store.healthMetrics.weightValueText, subtitle: store.healthMetrics.weightSubtitleText, systemImage: "scalemass.fill")
                    Divider()
                    HealthMetricRow(title: "Weight Trend", value: store.healthMetrics.weightTrendText, subtitle: store.healthMetrics.weightTrendSubtitleText, systemImage: "chart.line.uptrend.xyaxis")
                    Divider()
                    HealthMetricRow(title: "Sleep", value: store.healthMetrics.sleepText, subtitle: store.healthMetrics.sleepSubtitleText, systemImage: "bed.double.fill")
                    Divider()
                    HealthMetricRow(title: "Resting Heart Rate", value: store.healthMetrics.restingHeartRateText, subtitle: store.healthMetrics.restingHeartRateSubtitleText, systemImage: "heart.fill")
                    Divider()
                    HealthMetricRow(title: "Blood Pressure", value: store.healthMetrics.bloodPressureText, subtitle: store.healthMetrics.bloodPressureSubtitleText, systemImage: "waveform.path.ecg")
                    Divider()
                    HealthMetricRow(title: "Steps Today", value: store.healthMetrics.stepCountText, subtitle: "from Apple Health", systemImage: "figure.walk")
                    Divider()
                    HealthMetricRow(title: "Active Energy", value: store.healthMetrics.activeEnergyText, subtitle: "today", systemImage: "flame.fill")
                }
            }

            SettingsDetailCard {
                Label("DoesTrack reads HealthKit data only after you grant permission. Dose logs and medication protocols are not written to Apple Health.", systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func syncHealthData() {
        isSyncing = true
        statusMessage = ""

        Task {
            do {
                let snapshot = try await healthKit.requestAuthorizationAndFetch()
                await MainActor.run {
                    store.updateHealthMetrics(snapshot)
                    statusMessage = snapshot.hasAnyData ? "Health data synced." : "Connected. No matching Health samples were found."
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    var snapshot = store.healthMetrics
                    snapshot.lastAuthorizationRequestedAt = Date()
                    snapshot.lastSyncError = error.localizedDescription
                    snapshot.isHealthKitEnabled = false
                    store.updateHealthMetrics(snapshot)
                    statusMessage = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }
}

private struct HealthMetricRow: View {
    var title: String
    var value: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(settingsBlue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.headline)
                .foregroundStyle(value == "-" ? .secondary : .primary)
        }
    }
}

private struct SettingsDetailCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.black.opacity(0.08))
            }
    }
}
