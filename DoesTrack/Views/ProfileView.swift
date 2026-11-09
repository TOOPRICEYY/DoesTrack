import SwiftUI
import UserNotifications

// MARK: - Profile storage

enum ProfileStorage {
    static let nameKey = "doseTrackProfileName"
    static let appearanceKey = "doseTrackAppearance"
    static let unlockedAchievementsKey = "doseTrackUnlockedAchievements"
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Applies the choice to every window so sheets follow it too.
    @MainActor
    static func apply(rawValue: String) {
        let style = (AppAppearance(rawValue: rawValue) ?? .system).interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

// MARK: - Level and achievements

struct ProfileLevel: Equatable {
    var number: Int
    var name: String
    var emoji: String
    /// Doses needed to reach this level.
    var threshold: Int

    static let all: [ProfileLevel] = [
        ProfileLevel(number: 0, name: "Beginner", emoji: "🌱", threshold: 0),
        ProfileLevel(number: 1, name: "Starter", emoji: "🌿", threshold: 1),
        ProfileLevel(number: 2, name: "Steady", emoji: "💪", threshold: 10),
        ProfileLevel(number: 3, name: "Committed", emoji: "⚡️", threshold: 30),
        ProfileLevel(number: 4, name: "Dedicated", emoji: "🏅", threshold: 75),
        ProfileLevel(number: 5, name: "Veteran", emoji: "🏆", threshold: 150)
    ]

    static func current(forDoses doses: Int) -> ProfileLevel {
        all.last { doses >= $0.threshold } ?? all[0]
    }

    var next: ProfileLevel? {
        Self.all.first { $0.number == number + 1 }
    }

    func progress(forDoses doses: Int) -> Double {
        guard let next else { return 1 }
        let span = Double(next.threshold - threshold)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(doses - threshold) / span))
    }
}

struct ProfileAchievement: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var systemImage: String

    static let all: [ProfileAchievement] = [
        ProfileAchievement(id: "first-protocol", title: "Protocol Set", detail: "Add your first protocol", systemImage: "square.stack.3d.up.fill"),
        ProfileAchievement(id: "first-dose", title: "First Dose", detail: "Log your first dose", systemImage: "syringe.fill"),
        ProfileAchievement(id: "streak-7", title: "One Week Strong", detail: "Reach a 7 day streak", systemImage: "flame.fill"),
        ProfileAchievement(id: "streak-30", title: "Monthly Habit", detail: "Reach a 30 day streak", systemImage: "calendar"),
        ProfileAchievement(id: "doses-25", title: "25 Doses", detail: "Log 25 doses", systemImage: "pills.fill"),
        ProfileAchievement(id: "doses-100", title: "Century", detail: "Log 100 doses", systemImage: "rosette"),
        ProfileAchievement(id: "check-in", title: "Checked In", detail: "Complete a weekly check-in", systemImage: "heart.text.square.fill"),
        ProfileAchievement(id: "labs", title: "Lab Tracker", detail: "Add a lab result", systemImage: "testtube.2"),
        ProfileAchievement(id: "hydrated", title: "Hydrated", detail: "Hit your daily hydration goal", systemImage: "drop.fill")
    ]

    /// Achievements whose condition holds right now.
    @MainActor
    static func earnedIDs(in store: DoseStore) -> Set<String> {
        let taken = store.logs.filter { $0.status == .taken }.count
        let streak = store.currentStreak()
        var earned: Set<String> = []
        if !store.medications.isEmpty { earned.insert("first-protocol") }
        if taken >= 1 { earned.insert("first-dose") }
        if streak >= 7 { earned.insert("streak-7") }
        if streak >= 30 { earned.insert("streak-30") }
        if taken >= 25 { earned.insert("doses-25") }
        if taken >= 100 { earned.insert("doses-100") }
        if !store.symptomCheckIns.isEmpty { earned.insert("check-in") }
        if !store.labResults.isEmpty { earned.insert("labs") }
        if store.hydrationGoalOunces > 0, store.hydrationOunces(on: Date()) >= store.hydrationGoalOunces {
            earned.insert("hydrated")
        }
        return earned
    }
}

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject private var store: DoseStore
    @AppStorage(ProfileStorage.nameKey) private var profileName = ""
    @AppStorage(ProfileStorage.appearanceKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(ProfileStorage.unlockedAchievementsKey) private var unlockedRaw = ""
    @State private var showsSettings = false
    @State private var showsAchievements = false
    @State private var showsNameEditor = false
    @State private var draftName = ""

    private var trimmedName: String {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var takenCount: Int {
        store.logs.filter { $0.status == .taken }.count
    }

    private var level: ProfileLevel {
        ProfileLevel.current(forDoses: takenCount)
    }

    private var unlockedIDs: Set<String> {
        Set(unlockedRaw.split(separator: "|").map(String.init))
    }

    private var unlockedCount: Int {
        ProfileAchievement.all.filter { unlockedIDs.contains($0.id) }.count
    }

    private var initials: String {
        trimmedName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile")
                            .font(.largeTitle.bold())
                        Text("Your progress and preferences")
                            .foregroundStyle(.secondary)
                    }

                    profileCard

                    Button {
                        showsAchievements = true
                    } label: {
                        ProfileRowContent(
                            icon: "trophy.fill",
                            title: "Achievements",
                            subtitle: "\(unlockedCount) of \(ProfileAchievement.all.count) unlocked",
                            tint: .yellow
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Achievements")

                    SectionHeader(title: "PERSONALIZATION")

                    ModelCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 18) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .font(.title2)
                                    .foregroundStyle(Color.appBlue)
                                    .frame(width: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Appearance")
                                        .font(.headline)
                                    Text("Match the system or pick a look")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Picker("Appearance", selection: $appearanceRaw) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Text(appearance.label).tag(appearance.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

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
            .sheet(isPresented: $showsAchievements) {
                AchievementsView(unlockedIDs: unlockedIDs)
            }
            .alert("Your name", isPresented: $showsNameEditor) {
                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    profileName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Shown on your profile and in your home greeting. Stored on this device only.")
            }
            .onAppear(perform: recordAchievements)
            .onChange(of: store.logs.count) { _, _ in recordAchievements() }
        }
    }

    private var profileCard: some View {
        ModelCard {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.appBlue.opacity(0.12))
                        if initials.isEmpty {
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Color.appBlue.opacity(0.6))
                        } else {
                            Text(initials)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appBlue)
                        }
                    }
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle().stroke(Color.appBlue, lineWidth: 2.5)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            draftName = trimmedName
                            showsNameEditor = true
                        } label: {
                            HStack(spacing: 8) {
                                Text(trimmedName.isEmpty ? "Add your name" : trimmedName)
                                    .font(.title2.bold())
                                    .foregroundStyle(trimmedName.isEmpty ? Color.appBlue : .primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Image(systemName: "pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(trimmedName.isEmpty ? "Add your name" : "Edit name, \(trimmedName)")

                        HStack(spacing: 8) {
                            Text("\(level.emoji) \(level.name) · Lvl \(level.number)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Label("\(store.currentStreak())", systemImage: "flame.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.orange.opacity(0.14), in: Capsule())
                                .accessibilityLabel("Streak \(store.streakText)")
                        }

                        ProgressView(value: level.progress(forDoses: takenCount))
                            .tint(Color.appBlue)
                            .accessibilityHidden(true)

                        Text(levelCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack(alignment: .top) {
                    ProfileStat(value: "\(takenCount)", label: "Doses logged")
                    ProfileStat(value: "\(store.protocolStacks(includeInactive: false).count)", label: "Active protocols")
                    ProfileStat(
                        value: store.healthMetrics.weightValueText == "-" ? "–" : store.healthMetrics.weightValueText,
                        label: "Weight"
                    )
                }
            }
        }
    }

    private var levelCaption: String {
        guard let next = level.next else { return "Top level reached" }
        let remaining = max(0, next.threshold - takenCount)
        return "\(remaining) more dose\(remaining == 1 ? "" : "s") to Lvl \(next.number) · \(next.name)"
    }

    /// Achievements stay unlocked once earned, even if a streak later resets.
    private func recordAchievements() {
        let merged = unlockedIDs.union(ProfileAchievement.earnedIDs(in: store))
        guard merged != unlockedIDs else { return }
        unlockedRaw = merged.sorted().joined(separator: "|")
    }
}

private struct ProfileStat: View {
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(value == "–" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.appBlue))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    var unlockedIDs: Set<String>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ProfileAchievement.all) { achievement in
                        let unlocked = unlockedIDs.contains(achievement.id)
                        HStack(spacing: 14) {
                            Image(systemName: achievement.systemImage)
                                .font(.title3)
                                .foregroundStyle(unlocked ? Color.yellow : Color.secondary.opacity(0.6))
                                .frame(width: 48, height: 48)
                                .background((unlocked ? Color.yellow : Color.secondary).opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(achievement.title)
                                    .font(.headline)
                                Text(achievement.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                                .foregroundStyle(unlocked ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tertiary))
                        }
                        .padding()
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.08))
                        }
                        .opacity(unlocked ? 1 : 0.75)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(unlocked ? "Unlocked" : "Locked")
                    }
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
                        SettingsRow(icon: "server.rack", title: "Data Management", subtitle: "iCloud and GitHub sync", trailing: nil)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if let trailing {
                    trailing
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
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
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.10))
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
