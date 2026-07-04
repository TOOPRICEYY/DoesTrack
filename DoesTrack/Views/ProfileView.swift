import SwiftUI
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Profile")
                        .font(.largeTitle.bold())
                    Text("Your personal information and goals")
                        .font(.title3)

                    ModelCard {
                        VStack(spacing: 18) {
                            HStack(spacing: 18) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(Color.appBlue.opacity(0.45))
                                    .frame(width: 88, height: 88)
                                    .overlay {
                                        Circle().stroke(Color.appBlue, lineWidth: 3)
                                    }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Set your name")
                                        .font(.title.bold())
                                    HStack {
                                        Text("🌱 Beginner · Lvl 0")
                                            .foregroundStyle(.secondary)
                                        ProgressView(value: 0.35)
                                            .frame(width: 70)
                                        Text("🔥 0")
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(.orange.opacity(0.16), in: Capsule())
                                    }
                                }
                            }
                            Divider()
                            VStack {
                                Text(store.healthMetrics.weightValueText)
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.appBlue)
                                Text("Weight")
                            }
                        }
                    }

                    ProfileRow(icon: "trophy.fill", title: "Achievements", subtitle: "0 unlocked", tint: .yellow, trailing: AnyView(EmptyView()))

                    SectionHeader(title: "PERSONALIZATION")
                    ProfileRow(icon: "paintpalette.fill", title: "Theme", subtitle: "Color, intensity, status, appearance", tint: Color.appBlue, trailing: AnyView(Circle().fill(Color.appBlue).frame(width: 28, height: 28)))

                    Button {
                        showsSettings = true
                    } label: {
                        ProfileRowContent(icon: "gearshape.fill", title: "App Settings", subtitle: "Notifications, preferences, injection sites, and more", tint: Color.appBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("App Settings")
                }
                .padding()
                .padding(.bottom, 110)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: SettingsTopic?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title.bold())
                        }
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Close settings")

                        VStack(alignment: .leading) {
                            Text("Settings")
                                .font(.largeTitle.bold())
                            Text("Customize your experience")
                                .font(.title3)
                        }
                    }

                    SectionHeader(title: "APP SETTINGS")
                    SettingsGroup {
                        settingsButton(.notifications, subtitle: nil, trailing: notificationStatusText)
                        settingsButton(.healthData, subtitle: healthDataSubtitle, trailing: store.healthMetrics.isHealthKitEnabled ? "Connected" : nil)
                        settingsButton(.preferences, subtitle: "Unit system, lab units, defaults", trailing: nil)
                        settingsButton(.timeZone, subtitle: "Device time zone", trailing: nil)
                    }

                    SectionHeader(title: "DATA & PRIVACY")
                    NavigationLink {
                        SyncView()
                    } label: {
                        SettingsRow(icon: "server.rack", title: "Data Management", subtitle: "GitHub repo sync and backup", trailing: nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Data Management")

                    SectionHeader(title: "SUPPORT")
                    SettingsGroup {
                        settingsButton(.citations, subtitle: nil, trailing: nil)
                        settingsButton(.about, subtitle: nil, trailing: nil)
                        settingsButton(.faq, subtitle: nil, trailing: nil)
                    }

                    SectionHeader(title: "ADVANCED")
                    SettingsGroup {
                        settingsButton(.appUserID, subtitle: "Tap to view for support", trailing: nil)
                    }
                    Text("DOSE TRACK 1.0")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(item: $selectedTopic) { topic in
                SettingsDetailView(topic: topic)
            }
            .task {
                await store.refreshNotificationAuthorization()
            }
        }
    }

    private var notificationStatusText: String {
        switch store.notificationAuthorization {
        case .authorized, .provisional, .ephemeral:
            return "On"
        case .denied:
            return "Off"
        default:
            return "Set up"
        }
    }

    private func settingsButton(_ topic: SettingsTopic, subtitle: String?, trailing: String?) -> some View {
        Button {
            selectedTopic = topic
        } label: {
            SettingsRow(icon: topic.systemImage, title: topic.title, subtitle: subtitle, trailing: trailing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(topic.title)
    }

    private var healthDataSubtitle: String {
        if let lastSyncedAt = store.healthMetrics.lastSyncedAt {
            return "Synced \(lastSyncedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Apple Health metrics, local only"
    }
}

struct ProfileRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var tint: Color
    var trailing: AnyView? = nil

    var body: some View {
        ProfileRowContent(icon: icon, title: title, subtitle: subtitle, tint: tint, trailing: trailing)
    }
}

struct ProfileRowContent: View {
    var icon: String
    var title: String
    var subtitle: String
    var tint: Color
    var trailing: AnyView? = nil

    var body: some View {
        ModelCard {
            HStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title2)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let trailing {
                    trailing
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, 6)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.10))
        }
    }
}

struct SettingsRow: View {
    var icon: String
    var title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.appBlue)
                .frame(width: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
