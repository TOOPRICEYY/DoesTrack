import SwiftUI
import UIKit

enum OnboardingStorage {
    static let completedKey = "doseTrackOnboardingCompleted"
    static let checklistDismissedKey = "doseTrackSetupChecklistDismissed"

    /// UI tests start from a wiped store; they skip the welcome flow unless
    /// they ask for it, so every other test lands straight on Home.
    static var isSuppressedForTesting: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-reset-for-ui-testing") && !arguments.contains("-show-onboarding")
    }
}

// MARK: - Welcome flow

/// Two short pages shown once, on a first launch with no data: what the app
/// does, then an optional name and a choice of where to start.
struct OnboardingView: View {
    enum Outcome {
        case addProtocol
        case explore
    }

    var onFinish: (Outcome) -> Void

    @AppStorage(ProfileStorage.nameKey) private var profileName = ""
    @State private var page = 0
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { index in
                        Capsule()
                            .fill(index <= page ? Color.appBlue : Color.primary.opacity(0.12))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(page + 1) of 2")

                Group {
                    if page == 0 {
                        welcomePage
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)).combined(with: .opacity))
                    } else {
                        startPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.snappy, value: page)
    }

    // MARK: Page 1

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            Image(systemName: "syringe.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.appBlue)
                .frame(width: 84, height: 84)
                .background(Color.appBlue.opacity(0.16), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)

            Text("Welcome to DoesTrack")
                .font(.largeTitle.bold())
                .padding(.top, 24)

            Text("Keep every dose on schedule and see how your protocol is going.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 22) {
                OnboardingPoint(
                    systemImage: "calendar.badge.clock",
                    tint: .appBlue,
                    title: "Plan your protocol",
                    detail: "Add medications, doses and a schedule once. Each day shows what is due."
                )
                OnboardingPoint(
                    systemImage: "checkmark.circle.fill",
                    tint: .green,
                    title: "Log in one tap",
                    detail: "Streaks, adherence and inventory update as you go."
                )
                OnboardingPoint(
                    systemImage: "lock.fill",
                    tint: .orange,
                    title: "Private by default",
                    detail: "Your data stays on this device unless you turn on a backup."
                )
            }
            .padding(.top, 36)

            Spacer(minLength: 24)

            Button {
                page = 1
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appBlue)
            .controlSize(.large)

            Text("DoesTrack is a tracking tool, not medical advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: Page 2

    private var startPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                nameFocused = false
                page = 0
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.appBlue)
            .padding(.top, 18)

            Text("What should we call you?")
                .font(.largeTitle.bold())
                .padding(.top, 28)

            Text("Optional. It only personalizes your greeting and stays on this device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            TextField("Your name", text: $draftName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { nameFocused = false }
                .font(.title3)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(nameFocused ? Color.appBlue.opacity(0.6) : Color.primary.opacity(0.12), lineWidth: nameFocused ? 1.5 : 1)
                }
                .padding(.top, 24)

            Spacer(minLength: 24)

            Button {
                finish(.addProtocol)
            } label: {
                Text("Set Up My First Protocol")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appBlue)
            .controlSize(.large)

            Button {
                finish(.explore)
            } label: {
                Text("Look Around First")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(Color.appBlue)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func finish(_ outcome: Outcome) {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            profileName = trimmed
        }
        nameFocused = false
        onFinish(outcome)
    }
}

private struct OnboardingPoint: View {
    var systemImage: String
    var tint: Color
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Setup checklist

/// The three things that make the app useful, shown on Home until they are
/// all done or the person dismisses the card.
struct SetupChecklistCard: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.openURL) private var openURL
    @AppStorage(OnboardingStorage.checklistDismissedKey) private var dismissed = false

    var onAddProtocol: () -> Void
    var onLogDose: () -> Void

    private var hasProtocol: Bool { !store.medications.isEmpty }
    private var hasReminders: Bool { store.notificationsAuthorized }
    private var hasLoggedDose: Bool { store.logs.contains { $0.status == .taken } }
    private var doneCount: Int { [hasProtocol, hasReminders, hasLoggedDose].filter { $0 }.count }

    /// Callers use this to drop the section header and spacing with the card.
    static func isVisible(store: DoseStore, dismissed: Bool) -> Bool {
        guard !dismissed else { return false }
        let done = !store.medications.isEmpty
            && store.notificationsAuthorized
            && store.logs.contains { $0.status == .taken }
        return !done
    }

    var body: some View {
        if Self.isVisible(store: store, dismissed: dismissed) {
            ModelCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get set up")
                                .font(.title3.bold())
                            Text("\(doneCount) of 3 done")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                        if hasProtocol {
                            Button {
                                withAnimation(.snappy) { dismissed = true }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, height: 30)
                                    .background(Color.primary.opacity(0.06), in: Circle())
                            }
                            .accessibilityLabel("Hide setup checklist")
                        }
                    }

                    ProgressView(value: Double(doneCount), total: 3)
                        .tint(Color.appBlue)
                        .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        SetupStepRow(
                            title: "Add your first protocol",
                            detail: "Pick a medication, dose and schedule.",
                            isDone: hasProtocol,
                            isEnabled: true,
                            action: onAddProtocol
                        )
                        Divider().padding(.leading, 44)
                        SetupStepRow(
                            title: "Turn on reminders",
                            detail: reminderDetail,
                            isDone: hasReminders,
                            isEnabled: true,
                            action: enableReminders
                        )
                        Divider().padding(.leading, 44)
                        SetupStepRow(
                            title: "Log your first dose",
                            detail: hasProtocol ? "Tap the plus next to a dose when you take it." : "Available once you have a protocol.",
                            isDone: hasLoggedDose,
                            isEnabled: hasProtocol,
                            action: onLogDose
                        )
                    }
                }
            }
            .animation(.snappy, value: doneCount)
            .task {
                await store.refreshNotificationAuthorization()
            }
        }
    }

    private var reminderDetail: String {
        store.notificationAuthorization == .denied
            ? "Notifications are off for DoesTrack. Tap to open Settings."
            : "Get a nudge when a dose is due."
    }

    private func enableReminders() {
        if store.notificationAuthorization == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
            return
        }
        Task {
            _ = try? await store.enableNotifications()
        }
    }
}

private struct SetupStepRow: View {
    var title: String
    var detail: String
    var isDone: Bool
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .strikethrough(isDone, color: .secondary)
                        .foregroundStyle(isDone ? .secondary : .primary)
                    if !isDone {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                if !isDone && isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .opacity(isEnabled || isDone ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(isDone || !isEnabled)
        .accessibilityLabel(isDone ? "\(title), done" : title)
        .accessibilityHint(isDone ? "" : detail)
    }
}
