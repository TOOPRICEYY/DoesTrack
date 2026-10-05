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
            return ["Reminders stop once a dose is logged.", "Paused medications are excluded.", "Notification settings stay on this device and are not synced."]
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
    @Environment(\.openURL) private var openURL
    @State private var isWorking = false
    @State private var statusMessage = ""
    @State private var genericTitle = ""
    @State private var genericBody = ""

    private static let leadOptions = [0, 5, 10, 15, 30, 60]
    private static let followUpOptions = [0, 15, 30, 60, 120]
    private static let snoozeOptions = [5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusCard

            sectionHeader("REMINDERS")
            SettingsDetailCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Dose reminders", isOn: $store.notificationPreferences.doseRemindersEnabled)
                        .font(.headline)

                    if store.notificationPreferences.doseRemindersEnabled {
                        Picker("Frequency", selection: $store.notificationPreferences.frequency) {
                            ForEach(NotificationPreferences.Frequency.allCases) { frequency in
                                Text(frequency.label).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(store.notificationPreferences.frequency == .everyDose
                             ? "One reminder for each scheduled dose."
                             : "A single reminder each day at your first dose time.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Divider()

                        menuRow("Remind me", selection: $store.notificationPreferences.leadMinutes, options: Self.leadOptions) { minutes in
                            minutes == 0 ? "At dose time" : "\(minutes) min before"
                        }

                        if store.notificationPreferences.frequency == .everyDose {
                            menuRow("Follow up if not logged", selection: $store.notificationPreferences.followUpMinutes, options: Self.followUpOptions) { minutes in
                                minutes == 0 ? "Off" : minutes >= 60 ? "After \(minutes / 60) hr" : "After \(minutes) min"
                            }

                            menuRow("Snooze length", selection: $store.notificationPreferences.snoozeMinutes, options: Self.snoozeOptions) { minutes in
                                "\(minutes) min"
                            }
                        }
                    }

                    Divider()

                    Toggle("Weekly check-in reminder", isOn: $store.notificationPreferences.checkInRemindersEnabled)
                }
            }

            sectionHeader("PRIVACY")
            SettingsDetailCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Reminder content")
                        .font(.headline)
                    Picker("Reminder content", selection: $store.notificationPreferences.contentStyle) {
                        ForEach(NotificationPreferences.ContentStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.notificationPreferences.contentStyle.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if store.notificationPreferences.contentStyle == .generic {
                        TextField("Title", text: $genericTitle, prompt: Text(NotificationPreferences.defaultGenericTitle))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commitGenericText)
                            .accessibilityLabel("Generic reminder title")
                        TextField("Message", text: $genericBody, prompt: Text(NotificationPreferences.defaultGenericBody))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commitGenericText)
                            .accessibilityLabel("Generic reminder message")
                    }

                    Divider()

                    Toggle("Hide details on lock screen", isOn: $store.notificationPreferences.hideOnLockScreen)
                    Text("When iOS hides previews, reminders show only \"DoesTrack\" and \"\(store.notificationPreferences.resolvedGenericBody)\". Otherwise the title stays visible.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if store.notificationPreferences.hideOnLockScreen && store.notificationPreviewSetting == .always {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Previews are set to Always, so details still show when locked. Set Show Previews to When Unlocked.", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                            Button("Open Notification Settings", action: openSystemNotificationSettings)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }

            sectionHeader("DELIVERY")
            SettingsDetailCard {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Delivery", selection: $store.notificationPreferences.delivery) {
                        ForEach(NotificationPreferences.Delivery.allCases) { delivery in
                            Text(delivery.label).tag(delivery)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.notificationPreferences.delivery.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    Toggle("Quiet hours", isOn: $store.notificationPreferences.quietHoursEnabled)
                    if store.notificationPreferences.quietHoursEnabled {
                        DatePicker("From", selection: timeBinding(\.quietHoursStart), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: timeBinding(\.quietHoursEnd), displayedComponents: .hourAndMinute)
                        Text("Reminders that fall in quiet hours arrive when they end. Follow-ups during quiet hours are skipped.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            sectionHeader("PREVIEW")
            NotificationPreviewCard(preferences: store.notificationPreferences, sample: sampleMedication)
        }
        .task {
            genericTitle = store.notificationPreferences.genericTitle
            genericBody = store.notificationPreferences.genericBody
            await store.refreshNotificationAuthorization()
        }
        .onDisappear(perform: commitGenericText)
    }

    private var statusCard: some View {
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

                HStack {
                    if store.notificationAuthorization == .denied {
                        Button {
                            openSystemNotificationSettings()
                        } label: {
                            Label("Open Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settingsBlue)
                    } else {
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
                    }

                    if isEnabled {
                        Button {
                            sendTest()
                        } label: {
                            Label("Send Test", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isWorking)
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private func menuRow(_ title: String, selection: Binding<Int>, options: [Int], label: @escaping (Int) -> String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    /// Bridges a minutes-after-midnight preference to a DatePicker.
    private func timeBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Int>) -> Binding<Date> {
        let calendar = Calendar.doseTrackCalendar
        return Binding {
            let minutes = store.notificationPreferences[keyPath: keyPath]
            return calendar.dateBySettingTime(hour: minutes / 60, minute: minutes % 60, on: Date()) ?? Date()
        } set: { date in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            store.notificationPreferences[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    private var sampleMedication: Medication? {
        store.medications.first { $0.isActive && !$0.schedules.isEmpty }
    }

    private var isEnabled: Bool {
        store.notificationsAuthorized
    }

    private var statusText: String {
        switch store.notificationAuthorization {
        case .authorized, .provisional, .ephemeral:
            return "Dose reminders are scheduled from your active medication schedules."
        case .denied:
#if targetEnvironment(macCatalyst)
            return "Permission was denied. Enable notifications for DoesTrack in System Settings."
#else
            return "Permission was denied. Enable notifications for DoesTrack in iOS Settings."
#endif
        default:
            return "Enable reminders to get notified when a dose is due."
        }
    }

    private func commitGenericText() {
        if store.notificationPreferences.genericTitle != genericTitle {
            store.notificationPreferences.genericTitle = genericTitle
        }
        if store.notificationPreferences.genericBody != genericBody {
            store.notificationPreferences.genericBody = genericBody
        }
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
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

    private func sendTest() {
        commitGenericText()
        Task {
            do {
                try await store.sendTestNotification()
                statusMessage = "A test reminder will arrive in about 5 seconds."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}

/// Mock lock-screen banner showing what a reminder will say.
private struct NotificationPreviewCard: View {
    var preferences: NotificationPreferences
    var sample: Medication?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            preview(locked: false)
            if preferences.hideOnLockScreen {
                preview(locked: true)
            }
        }
    }

    private func preview(locked: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(settingsBlue)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("DoesTrack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(locked ? "Locked" : "now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if locked {
                    Text(preferences.resolvedGenericBody)
                        .font(.subheadline)
                } else {
                    Text(previewTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(previewBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.08))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(locked ? "Locked preview" : "Notification preview")
    }

    private var sampleName: String { sample?.name ?? "Medication" }

    private var previewTitle: String {
        if preferences.frequency == .dailySummary && preferences.doseRemindersEnabled {
            return preferences.contentStyle == .generic ? preferences.resolvedGenericTitle : "2 doses scheduled today"
        }
        switch preferences.contentStyle {
        case .detailed: return "Dose due: \(sampleName)"
        case .nameOnly: return "Reminder: \(sample.map(NotificationScheduler.discreetName(for:)) ?? sampleName)"
        case .generic: return preferences.resolvedGenericTitle
        }
    }

    private var previewBody: String {
        if preferences.contentStyle == .generic {
            return preferences.resolvedGenericBody
        }
        if preferences.frequency == .dailySummary && preferences.doseRemindersEnabled {
            return preferences.contentStyle == .detailed ? "\(sampleName) \(sample?.displayDose ?? "") at 9:00 AM" : sample.map(NotificationScheduler.discreetName(for:)) ?? sampleName
        }
        switch preferences.contentStyle {
        case .detailed: return [sample?.displayDose ?? "1 dose", sample?.instructions ?? ""].filter { !$0.isEmpty }.joined(separator: " - ")
        default: return "Scheduled for 9:00 AM."
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
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.08))
            }
    }
}
