import SwiftUI

struct NotificationsCenterView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab = "Today"
    @State private var loggingDose: ScheduledDose?

    private var attentionCount: Int {
        store.notificationAttentionCount()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .frame(width: 52, height: 52)
                            .background(.white, in: Circle())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Close notifications")

                    VStack(alignment: .leading) {
                        Text("Notifications")
                            .font(.largeTitle.bold())
                        Text(attentionCount == 0 ? "You're all caught up" : "\(attentionCount) new item\(attentionCount == 1 ? "" : "s") need attention")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        store.markAllNotificationsRead()
                    } label: {
                        Label(attentionCount == 0 ? "Marked" : "Mark all", systemImage: "checkmark")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.appBlue.opacity(0.14), in: Capsule())
                    }
                    .disabled(attentionCount == 0)
                }

                Picker("Notifications", selection: $tab) {
                    Text("Today").tag("Today")
                    Text("Upcoming").tag("Upcoming")
                    Text("Reminders").tag("Reminders")
                }
                .pickerStyle(.segmented)

                ScrollView {
                    if tab == "Reminders" {
                        ReminderCard()
                    } else {
                        let doses = tab == "Today" ? store.scheduledDoses(on: Date()) : store.upcomingDoses(limit: 8)
                        if tab == "Today" {
                            VStack(alignment: .leading, spacing: 18) {
                                DailySummaryCard(doses: doses)

                                if doses.isEmpty {
                                    EmptyStateView(systemImage: "tray", title: "Clear", message: "No medications scheduled today.")
                                } else {
                                    HStack(spacing: 10) {
                                        SectionHeader(title: "MEDICATIONS")
                                        Text("\(doses.count)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 6)
                                            .background(.white, in: Circle())
                                        Spacer()
                                    }

                                    VStack(spacing: 12) {
                                        ForEach(doses) { dose in
                                            NotificationTodayMedicationCard(dose: dose) {
                                                loggingDose = dose
                                            }
                                        }
                                    }
                                }
                            }
                        } else if doses.isEmpty {
                            EmptyStateView(systemImage: "tray", title: "Clear", message: "No medications scheduled soon.")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(doses) { dose in
                                    NotificationDoseRow(dose: dose) { status in
                                        store.record(dose, status: status)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $loggingDose) { dose in
                LogDoseSheet(scheduledDose: dose)
                    .environmentObject(store)
            }
        }
    }
}

struct DailySummaryCard: View {
    var doses: [ScheduledDose]

    private var takenCount: Int {
        doses.filter { $0.log?.status == .taken }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "calendar")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 58, height: 58)
                    .background(Color.appBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appBlue.opacity(0.28), lineWidth: 1.5)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Daily Summary")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(takenCount)/\(doses.count)")
                        .font(.system(size: 42, weight: .bold))
                }
            }

            ProgressView(value: doses.isEmpty ? 0 : Double(takenCount) / Double(doses.count))
                .tint(Color.appBlue)

            Text("\(takenCount) of \(doses.count) scheduled medication\(doses.count == 1 ? "" : "s") logged today.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.appBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBlue.opacity(0.35), lineWidth: 1.5)
        }
    }
}

struct NotificationTodayMedicationCard: View {
    var dose: ScheduledDose
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 16) {
                Image(systemName: dose.medication.instructions.localizedCaseInsensitiveContains("oral") ? "pills.fill" : "cross.case.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 58, height: 58)
                    .background(Color.appBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appBlue.opacity(0.32), lineWidth: 1.5)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(dose.medication.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                    Text(dose.medication.stackName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(statusText, systemImage: "clock")
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .overlay {
                        Capsule().stroke(statusColor.opacity(0.38), lineWidth: 1.5)
                    }
            }
            .padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appBlue.opacity(0.32), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dose.medication.name) \(statusText)")
    }

    private var statusColor: Color {
        switch dose.log?.status {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        case .wasted: return .orange
        case nil:
            return dose.scheduledAt < Date() ? .red : Color.appBlue
        }
    }

    private var statusText: String {
        switch dose.log?.status {
        case .taken: return "TAKEN"
        case .skipped: return "SKIPPED"
        case .missed: return "MISSED"
        case .wasted: return "WASTED"
        case nil:
            return dose.scheduledAt < Date() ? "OVERDUE" : "DUE"
        }
    }
}

struct NotificationDoseRow: View {
    var dose: ScheduledDose
    var onRecord: (DoseLogStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 56, height: 56)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 7) {
                    Text(dose.medication.name)
                        .font(.title2.bold())
                    Text("\(dose.medication.stackName) · due \(dose.scheduledAt.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }

            HStack {
                Button {
                    onRecord(.taken)
                } label: {
                    Label("Taken", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(dose.log?.status == .taken)

                Button {
                    onRecord(.skipped)
                } label: {
                    Label("Skip", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(dose.log?.status == .skipped)
            }
            .controlSize(.small)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(statusColor.opacity(0.35))
        }
    }

    private var statusColor: Color {
        switch dose.log?.status {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        case .wasted: return .orange
        case nil: return dose.scheduledAt < Date() ? .red : .cyan
        }
    }

    private var statusText: String {
        switch dose.log?.status {
        case .taken: return "TAKEN"
        case .skipped: return "SKIPPED"
        case .missed: return "MISSED"
        case .wasted: return "WASTED"
        case nil: return dose.scheduledAt < Date() ? "OVERDUE" : "UPCOMING"
        }
    }
}

struct ReminderCard: View {
    @EnvironmentObject private var store: DoseStore
    @State private var showsCheckIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "HEALTH CHECKS")
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.green)
                    .frame(width: 48, height: 48)
                    .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading) {
                    Text("Weekly Check-In")
                        .font(.headline)
                    Text(lastCheckInText)
                        .foregroundStyle(.secondary)
                    Button(isDue ? "Check In" : "Checked In") {
                        showsCheckIn = true
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                }
                Spacer()
                Text(isDue ? "DUE" : "DONE")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.12), in: Capsule())
            }
            .padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
        }
        .sheet(isPresented: $showsCheckIn) {
            WeeklyCheckInView()
                .environmentObject(store)
        }
    }

    private var lastCheckInDate: Date? {
        store.latestSymptomCheckIn?.createdAt
    }

    private var isDue: Bool {
        guard let lastCheckInDate else { return true }
        return Date().timeIntervalSince(lastCheckInDate) >= 7 * 86_400
    }

    private var lastCheckInText: String {
        guard let lastCheckInDate else { return "No check-in logged yet" }
        return "Last checked in \(lastCheckInDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct WeeklyCheckInView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedArea: SymptomCheckInArea = .mental
    @State private var ratings: [String: Int] = [:]
    @State private var notes = ""
    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    Text("Rate each area from 1 to 5 and add any notes for this week.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(selectedArea.sectionTitle)
                            .font(.headline)
                            .kerning(4)
                            .foregroundStyle(.secondary.opacity(0.65))
                        Spacer()
                        Image(systemName: "info.circle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Rating information")
                    }

                    areaPicker

                    symptomRatingsCard

                    Text("Body")
                        .font(.headline)
                        .kerning(4)
                        .foregroundStyle(.secondary.opacity(0.65))

                    bodyCard
                    notesCard

                    Button {
                        save()
                    } label: {
                        Label("Save Check-In", systemImage: "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(ratings.isEmpty)
                    .opacity(ratings.isEmpty ? 0.45 : 1)
                    .accessibilityLabel("Save check in")
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                if weightText.isEmpty, let weight = store.healthMetrics.bodyMassPounds?.value {
                    weightText = weight.formatted(.number.precision(.fractionLength(1)))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title.bold())
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(.primary)
            .accessibilityLabel("Close check in")

            VStack(alignment: .leading, spacing: 2) {
                Text("How are you feeling?")
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Rate each area and add notes")
                    .font(.title3)
            }
        }
    }

    private var areaPicker: some View {
        HStack(spacing: 0) {
            ForEach(SymptomCheckInArea.allCases) { area in
                Button {
                    selectedArea = area
                } label: {
                    Text(area.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(selectedArea == area ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(selectedArea == area ? Color.appBlue.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selectedArea == area ? Color.appBlue : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.10))
        }
    }

    private var symptomRatingsCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(selectedArea.symptomNames, id: \.self) { symptom in
                SymptomRatingRow(
                    title: symptom,
                    selectedValue: ratings[ratingKey(for: symptom)]
                ) { value in
                    ratings[ratingKey(for: symptom)] = value
                }
            }
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.10))
        }
    }

    private var bodyCard: some View {
        HStack {
            Text("Current weight")
                .font(.title2)
            Spacer()
            TextField("---", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title2.bold())
                .frame(width: 120)
                .accessibilityLabel("Current weight")
        }
        .padding(22)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.10))
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)
            TextField("Anything notable this week?", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.10))
        }
    }

    private func ratingKey(for symptom: String) -> String {
        "\(selectedArea.rawValue).\(symptom)"
    }

    private func save() {
        let weight = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
        store.recordSymptomCheckIn(
            SymptomCheckIn(
                ratings: ratings,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                weightPounds: weight
            )
        )
        dismiss()
    }
}

struct SymptomRatingRow: View {
    var title: String
    var selectedValue: Int?
    var onSelect: (Int) -> Void

    private let colors: [Int: Color] = [
        1: .red,
        2: .orange,
        3: .yellow,
        4: .green.opacity(0.55),
        5: .green
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2)

            HStack {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        onSelect(value)
                    } label: {
                        Text("\(value)")
                            .font(.title3.bold())
                            .foregroundStyle(colors[value] ?? .secondary)
                            .frame(width: 48, height: 48)
                            .background(selectedValue == value ? (colors[value] ?? .blue).opacity(0.15) : .clear, in: Circle())
                            .overlay {
                                Circle().stroke(colors[value] ?? .secondary, lineWidth: selectedValue == value ? 2.5 : 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(value)")

                    if value < 5 {
                        Spacer(minLength: 10)
                    }
                }
            }
        }
    }
}
