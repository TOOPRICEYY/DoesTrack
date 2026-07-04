import SwiftUI

private let doseLoggingBackground = Color.appBackground
private let doseLoggingBlue = Color.appBlue

struct HomeScheduledDoseSection: View {
    var date: Date
    var doses: [ScheduledDose]
    var onLogDose: (ScheduledDose) -> Void
    var onMedicationActions: (Medication) -> Void

    private var groupedDoses: [(stackName: String, doses: [ScheduledDose])] {
        Dictionary(grouping: doses, by: { $0.medication.stackName })
            .map { key, value in
                (
                    stackName: key,
                    doses: value.sorted { $0.medication.name.localizedCaseInsensitiveCompare($1.medication.name) == .orderedAscending }
                )
            }
            .sorted { $0.stackName.localizedCaseInsensitiveCompare($1.stackName) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.title2.weight(.bold))
                .foregroundStyle(doseLoggingBlue)

            ForEach(groupedDoses, id: \.stackName) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(group.stackName)
                            .font(.title.bold())
                        ProgressChip(taken: takenCount(group.doses), total: group.doses.count)
                        Spacer()
                        Button {
                            if let medication = group.doses.first?.medication {
                                onMedicationActions(medication)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 36)
                        }
                        .accessibilityLabel("Medication actions")
                    }

                    VStack(spacing: 0) {
                        ForEach(group.doses) { dose in
                            ScheduledDoseActionRow(dose: dose, onLogDose: onLogDose)
                            if dose.id != group.doses.last?.id {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.black.opacity(0.10))
                    }
                }
            }
        }
    }

    private func takenCount(_ doses: [ScheduledDose]) -> Int {
        doses.filter { $0.log?.status == .taken }.count
    }
}

struct CalendarScheduledDoseRow: View {
    var dose: ScheduledDose
    var onLogDose: (ScheduledDose) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: dose.medication.instructions.localizedCaseInsensitiveContains("oral") ? "pills.fill" : "cross.case.fill")
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text("\(doseAmountText) \(dose.medication.name)")
                    .font(.title3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text("\(routeText) • \(statusText)")
                    .font(.headline)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Button {
                onLogDose(dose)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(doseLoggingBlue)
            }
            .accessibilityLabel("Log \(dose.medication.name)")
        }
        .padding()
        .background(doseLoggingBlue.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(doseLoggingBlue.opacity(0.32), lineWidth: 1.5)
        }
    }

    private var doseAmountText: String {
        "\(DoseLoggingFormatter.amount(dose.schedule.amount)) \(dose.medication.unit.lowercased())"
    }

    private var routeText: String {
        dose.medication.instructions.isEmpty ? "SubQ" : dose.medication.instructions
    }

    private var iconColor: Color {
        dose.medication.name.localizedCaseInsensitiveContains("hCG") ? .purple : .orange
    }

    private var statusText: String {
        switch dose.effectiveStatus {
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        case .wasted: return "Wasted"
        case nil:
            return dose.scheduledAt.isSameDay(as: Date()) ? "Scheduled" : "Scheduled"
        }
    }

    private var statusColor: Color {
        switch dose.effectiveStatus {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        case .wasted: return .orange
        case nil: return doseLoggingBlue
        }
    }
}

struct PauseMedicationSheet: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var pauseDays = "7"
    var medication: Medication

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.gray.opacity(0.28))
                .frame(width: 94, height: 8)
                .padding(.top, 18)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 22) {
                Text(medication.name)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text("Temporarily hide from home screen and stop reminders")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button {
                    store.pauseMedication(medication, until: nil)
                    dismiss()
                } label: {
                    PauseOptionContent(
                        icon: "pause.circle",
                        tint: .orange,
                        title: "Pause Until I Resume",
                        subtitle: "Stay paused until you manually resume"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause Until I Resume")

                VStack(alignment: .leading, spacing: 16) {
                    PauseOptionContent(
                        icon: "timer",
                        tint: doseLoggingBlue,
                        title: "Pause for X days",
                        subtitle: "Automatically resume after specified days"
                    )

                    HStack(spacing: 14) {
                        TextField("7", text: $pauseDays)
                            .font(.title2)
                            .keyboardType(.numberPad)
                            .padding()
                            .frame(minHeight: 64)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.black.opacity(0.08))
                            }
                            .accessibilityLabel("Pause days")

                        Button {
                            let days = max(1, Int(pauseDays) ?? 7)
                            store.pauseMedication(medication, until: Date().startOfDay.addingDays(days))
                            dismiss()
                        } label: {
                            Text("Apply")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 128, height: 64)
                                .background(doseLoggingBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(Int(pauseDays) == nil)
                    }

                    if let days = Int(pauseDays), days >= 1 {
                        Text("Resumes automatically on \(Date().startOfDay.addingDays(days).formatted(date: .abbreviated, time: .omitted)).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.black.opacity(0.08))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
        }
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.hidden)
        .background(Color(.systemBackground))
    }
}

struct LogDoseSheet: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var unit: String
    @State private var method: String
    @State private var injectionSite = "Stomach - Upper Right"
    @State private var notes = ""
    @State private var showsNotes = false
    @State private var showsAdvanced = false
    @State private var loggedTime: Date
    @State private var painLevel = 0.0
    @State private var siteReaction = "None"
    @State private var showsSkipReasons = false
    @State private var showsWastedDose = false

    var scheduledDose: ScheduledDose

    private let siteOptions = DoseStore.defaultInjectionSites
    private let reactionOptions = ["None", "Redness", "Swelling", "Bruising", "Lump/Nodule", "Itching"]

    init(scheduledDose: ScheduledDose) {
        self.scheduledDose = scheduledDose
        _amountText = State(initialValue: DoseLoggingFormatter.amount(scheduledDose.schedule.amount))
        _unit = State(initialValue: scheduledDose.medication.unit.uppercased())
        _method = State(initialValue: scheduledDose.medication.instructions.localizedCaseInsensitiveContains("IM") ? "IM" : "SubQ")
        _loggedTime = State(initialValue: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Capsule()
                    .fill(.gray.opacity(0.35))
                    .frame(width: 86, height: 7)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Log New Dose")
                        .font(.largeTitle.bold())
                    Text(scheduledDose.medication.name)
                        .font(.title.bold())
                    Text("\(frequencyText) · \(method)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                doseCard
                methodCard
                injectionSiteCard

                if showsAdvanced {
                    advancedCard
                }

                notesAndAdvancedControls

                Button {
                    saveDose(status: .taken)
                } label: {
                    Label("Log Dose", systemImage: "checkmark.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(doseLoggingBlue)
                .controlSize(.large)
                .accessibilityLabel("Log Dose")

                HStack {
                    Button("Skip this dose") {
                        showsSkipReasons = true
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 34)

                    Button("Wasted dose") {
                        showsWastedDose = true
                    }
                    .frame(maxWidth: .infinity)
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 18)
            }
            .padding(.horizontal)
        }
        .background(doseLoggingBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showsSkipReasons) {
            SkipDoseReasonSheet { reason in
                saveDose(status: .skipped, skipReason: reason)
            }
        }
        .onAppear {
            if let suggested = store.suggestedInjectionSite(from: siteOptions) {
                injectionSite = suggested
            }
        }
        .sheet(isPresented: $showsWastedDose) {
            WastedDoseSheet(
                medication: scheduledDose.medication,
                standardAmount: Double(amountText) ?? scheduledDose.schedule.amount,
                unit: unit
            ) { amount in
                recordWastedDose(amount: amount)
            }
        }
    }

    private var doseCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Dose")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Dose", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.largeTitle.bold())
                    .foregroundStyle(doseLoggingBlue)
                    .frame(width: 96, height: 76)
                    .background(doseLoggingBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Dose amount")

                Menu {
                    ForEach(["MG", "MCG", "IU", "ML", "UNITS"], id: \.self) { option in
                        Button(option) { unit = option }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(unit)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 104, height: 56)
                }
            }

        }
        .doseLoggingCard()
    }

    private var methodCard: some View {
        HStack {
            Text("Method")
                .font(.title2)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Method", selection: $method) {
                Text("SubQ").tag("SubQ")
                Text("IM").tag("IM")
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
        }
        .doseLoggingCard()
    }

    private var injectionSiteCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .foregroundStyle(doseLoggingBlue)
                Text("Injection Site")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(injectionSite)
                        .font(.title2.bold())
                    Text(siteUsageText)
                        .font(.headline)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                Spacer()
                Menu {
                    ForEach(siteOptions, id: \.self) { site in
                        Button {
                            injectionSite = site
                        } label: {
                            if let lastUsed = store.lastUse(ofSite: site) {
                                Text("\(site) — last used \(lastUsed.formatted(date: .abbreviated, time: .omitted))")
                            } else {
                                Text("\(site) — never used")
                            }
                        }
                    }
                } label: {
                    Text("Choose Site")
                        .font(.headline.bold())
                        .foregroundStyle(doseLoggingBlue)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(doseLoggingBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(doseLoggingBlue.opacity(0.38), lineWidth: 1.5)
                        }
                }
            }

            Button {
                if let suggested = store.suggestedInjectionSite(from: siteOptions) {
                    injectionSite = suggested
                }
            } label: {
                Label("Rotate: pick least recently used site", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(doseLoggingBlue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pick least recently used site")
        }
        .doseLoggingCard()
    }

    private var siteUsageText: String {
        guard let lastUsed = store.lastUse(ofSite: injectionSite) else { return "Never used" }
        return "Last used \(lastUsed.formatted(date: .abbreviated, time: .omitted))"
    }

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label("Time", systemImage: "clock")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("Time", selection: $loggedTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .padding(.horizontal, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.black.opacity(0.16))
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Pain Level: \(Int(painLevel))/10", systemImage: "bandage.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Slider(value: $painLevel, in: 0...10, step: 1)
                    .tint(.orange)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("Site Reaction", systemImage: "exclamationmark.triangle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 10) {
                    ForEach(reactionOptions, id: \.self) { reaction in
                        Button {
                            siteReaction = reaction
                        } label: {
                            Text(reaction)
                                .font(.headline)
                                .foregroundStyle(siteReaction == reaction ? .red : .secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(siteReaction == reaction ? Color.red.opacity(0.10) : .white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(siteReaction == reaction ? Color.red.opacity(0.42) : Color.black.opacity(0.18), lineWidth: 1.5)
                                }
                        }
                    }
                }
            }
        }
        .doseLoggingCard()
    }

    private var notesAndAdvancedControls: some View {
        VStack(spacing: 12) {
            if showsNotes {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.black.opacity(0.08))
                    }
            }

            HStack {
                Button {
                    showsNotes.toggle()
                } label: {
                    Label(showsNotes ? "Hide notes" : "Add notes", systemImage: "note.text.badge.plus")
                }
                Spacer()
                Button {
                    withAnimation(.snappy) {
                        showsAdvanced.toggle()
                    }
                } label: {
                    Label(showsAdvanced ? "Hide advanced" : "Advanced", systemImage: showsAdvanced ? "chevron.up" : "slider.horizontal.3")
                }
            }
            .font(.headline)
            .foregroundStyle(.secondary.opacity(0.7))
        }
    }

    private var frequencyText: String {
        scheduledDose.schedule.frequencyLabel
    }

    private func saveDose(status: DoseLogStatus, skipReason: String? = nil) {
        let amount = Double(amountText) ?? scheduledDose.schedule.amount

        store.record(
            scheduledDose,
            status: status,
            amount: amount,
            takenAt: loggedTime,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            method: method,
            site: injectionSite,
            painLevel: showsAdvanced ? Int(painLevel) : nil,
            siteReaction: showsAdvanced && siteReaction != "None" ? siteReaction : nil,
            skipReason: skipReason
        )
        dismiss()
    }

    private func recordWastedDose(amount: Double) {
        let noteParts = [
            "Wasted dose of \(scheduledDose.medication.name)",
            notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ].compactMap { $0 }

        store.recordWastedDose(
            medicationID: scheduledDose.medication.id,
            amount: amount,
            occurredAt: Date(),
            notes: noteParts.joined(separator: " · ")
        )
        dismiss()
    }
}

struct ManualDoseSheet: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMedicationID = UUID()
    @State private var amountText = "1"
    @State private var loggedAt: Date
    @State private var notes = ""

    var scheduledAt: Date

    init(scheduledAt: Date = Date()) {
        self.scheduledAt = scheduledAt
        _loggedAt = State(initialValue: Self.defaultLoggedAt(for: scheduledAt))
    }

    private var selectableMedications: [Medication] {
        let active = store.medications.filter(\.isActive)
        return active.isEmpty ? store.medications : active
    }

    private var selectedMedication: Medication? {
        store.medications.first { $0.id == selectedMedicationID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dose") {
                    Picker("Medication", selection: $selectedMedicationID) {
                        ForEach(selectableMedications) { medication in
                            Text(medication.name).tag(medication.id)
                        }
                    }
                    .accessibilityLabel("Medication")

                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Amount")

                    if let selectedMedication {
                        LabeledContent("Unit", value: selectedMedication.unit.uppercased())
                    }

                    DatePicker("Logged at", selection: $loggedAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add Dose")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedMedication == nil, let first = selectableMedications.first {
                    selectedMedicationID = first.id
                    amountText = DoseLoggingFormatter.amount(first.schedules.first?.amount ?? Double(first.dose) ?? 1)
                }
            }
            .onChange(of: selectedMedicationID) { _, newValue in
                guard let medication = store.medications.first(where: { $0.id == newValue }) else { return }
                amountText = DoseLoggingFormatter.amount(medication.schedules.first?.amount ?? Double(medication.dose) ?? 1)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.recordManualDose(
                            medicationID: selectedMedicationID,
                            amount: parsedAmount,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            scheduledAt: loggedAt,
                            takenAt: loggedAt
                        )
                        dismiss()
                    }
                    .disabled(selectedMedication == nil || parsedAmount <= 0)
                }
            }
        }
    }

    private var parsedAmount: Double {
        Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func defaultLoggedAt(for date: Date) -> Date {
        let calendar = Calendar.doseTrackCalendar
        if calendar.isDateInToday(date) { return Date() }
        return calendar.dateBySettingTime(hour: 9, minute: 0, on: date) ?? date
    }
}

private struct SkipDoseReasonSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    private let reasons: [(title: String, icon: String)] = [
        ("Traveling", "airplane.departure"),
        ("Side effects", "exclamationmark.triangle"),
        ("Forgot", "clock"),
        ("Other", "ellipsis")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Capsule()
                .fill(.gray.opacity(0.30))
                .frame(width: 84, height: 7)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 14) {
                Text("Skip this dose?")
                    .font(.largeTitle.bold())
                Text("Let us know why so we can track your adherence accurately.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 6) {
                ForEach(reasons, id: \.title) { reason in
                    Button {
                        onSelect(reason.title)
                        dismiss()
                    } label: {
                        HStack(spacing: 24) {
                            Image(systemName: reason.icon)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44)
                            Text(reason.title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(reason.title)
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .presentationDetents([.height(470), .large])
        .presentationDragIndicator(.hidden)
        .background(Color(.systemBackground))
    }
}

private struct WastedDoseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    var medication: Medication
    var standardAmount: Double
    var unit: String
    var onRecord: (Double) -> Void

    init(medication: Medication, standardAmount: Double, unit: String, onRecord: @escaping (Double) -> Void) {
        self.medication = medication
        self.standardAmount = standardAmount
        self.unit = unit
        self.onRecord = onRecord
        _amountText = State(initialValue: DoseLoggingFormatter.amount(standardAmount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Capsule()
                .fill(.gray.opacity(0.30))
                .frame(width: 84, height: 7)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 14) {
                Text("Wasted Dose")
                    .font(.largeTitle.bold())
                Text("How much \(medication.name) was wasted? This will update your inventory.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowLayout(spacing: 10) {
                quickAmountButton(title: "Standard dose", amount: standardAmount)
                quickAmountButton(title: "Half dose", amount: standardAmount / 2)
                quickAmountButton(title: "Double", amount: standardAmount * 2)
            }

            HStack {
                TextField("Amount", text: $amountText)
                    .font(.system(size: 46, weight: .bold))
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Wasted amount")
                Text(unit.lowercased())
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 22)
            }
            .frame(minHeight: 78)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(doseLoggingBlue.opacity(0.56), lineWidth: 2)
            }

            Button {
                onRecord(parsedAmount)
                dismiss()
            } label: {
                Label("Record Wasted Dose", systemImage: "trash")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(parsedAmount <= 0)

            Button("Cancel") {
                dismiss()
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .presentationDetents([.height(550), .large])
        .presentationDragIndicator(.hidden)
        .background(Color(.systemBackground))
    }

    private func quickAmountButton(title: String, amount: Double) -> some View {
        Button {
            amountText = DoseLoggingFormatter.amount(amount)
        } label: {
            Text("\(title) (\(DoseLoggingFormatter.amount(amount)) \(unit.lowercased()))")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.white, in: Capsule())
                .overlay {
                    Capsule().stroke(.black.opacity(0.18), lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    private var parsedAmount: Double {
        Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
}

private struct ScheduledDoseActionRow: View {
    var dose: ScheduledDose
    var onLogDose: (ScheduledDose) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(dose.medication.name)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("\(DoseLoggingFormatter.amount(dose.schedule.amount)) \(dose.medication.unit.uppercased())")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text(frequencyText)
                    Text("·")
                    Text(statusText)
                        .foregroundStyle(statusColor)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onLogDose(dose)
            } label: {
                Image(systemName: dose.log?.status == .taken ? "checkmark" : "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(doseLoggingBlue)
                    .frame(width: 54, height: 54)
                    .background(doseLoggingBlue.opacity(0.12), in: Circle())
                    .overlay {
                        Circle().stroke(doseLoggingBlue.opacity(0.42), lineWidth: 1.5)
                    }
            }
            .accessibilityLabel("Log \(dose.medication.name)")
        }
        .padding(.horizontal)
        .padding(.vertical, 13)
    }

    private var frequencyText: String {
        dose.schedule.frequencyLabel
    }

    private var statusText: String {
        switch dose.effectiveStatus {
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        case .wasted: return "Wasted"
        case nil: return dose.scheduledAt.isSameDay(as: Date()) ? "Due today" : "Scheduled"
        }
    }

    private var statusColor: Color {
        switch dose.effectiveStatus {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        case .wasted: return .orange
        case nil: return dose.scheduledAt.isSameDay(as: Date()) ? .orange : doseLoggingBlue
        }
    }
}

private struct ProgressChip: View {
    var taken: Int
    var total: Int

    var body: some View {
        Label("\(taken)/\(total)", systemImage: "clock")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray5), in: Capsule())
    }
}

private struct PauseOptionContent: View {
    var icon: String
    var tint: Color
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title.bold())
                .foregroundStyle(tint)
                .frame(width: 62, height: 62)
                .background(tint.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FlowLayout<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: spacing)], alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}

private struct DoseLoggingFormatter {
    static func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}

private extension View {
    func doseLoggingCard() -> some View {
        padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.black.opacity(0.08))
            }
    }
}
