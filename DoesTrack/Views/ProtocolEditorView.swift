import SwiftUI

struct ProtocolEditorView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProtocolDraft
    @State private var selectedMedicationID: UUID?
    @State private var configureTab = "Dose"

    private let originalStackName: String?

    init(template: ProtocolTemplate? = nil, stack: ProtocolStack? = nil) {
        self.originalStackName = stack?.name
        let initialDraft = ProtocolDraft(template: template, stack: stack)
        _draft = State(initialValue: initialDraft)
        _selectedMedicationID = State(initialValue: initialDraft.medications.first?.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        stepHeader
                        stepContent
                    }
                    .padding()
                    .padding(.bottom, 100)
                }

                footer
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var stepHeader: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                }
                .foregroundStyle(.primary)

                Spacer()

                Text("Edit Protocol")
                    .font(.largeTitle.bold())

                Spacer()
                Color.clear.frame(width: 28, height: 28)
            }

            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(index <= draft.step ? Color.appBlue : Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            if index < draft.step {
                                Image(systemName: "checkmark")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.headline.bold())
                                    .foregroundStyle(index <= draft.step ? .white : .secondary)
                            }
                        }
                        Text(["Name", "Configure", "Costs", "Review"][index])
                            .font(.subheadline.weight(index == draft.step ? .bold : .regular))
                            .foregroundStyle(index <= draft.step ? .primary : .secondary)
                    }
                    if index < 3 {
                        Rectangle()
                            .fill(index < draft.step ? Color.appBlue : Color(.systemGray5))
                            .frame(height: 3)
                            .offset(y: -16)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.step {
        case 0:
            nameStep
        case 1:
            configureStep
        case 2:
            inventoryStep
        default:
            reviewStep
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Protocol Name")
                .font(.title2.bold())
            TextField("Protocol name", text: $draft.name)
                .font(.title2)
                .padding()
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))

            Text("Add Medications")
                .font(.title2.bold())
                .padding(.top)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search medications...", text: $draft.searchText)
            }
            .font(.title3)
            .padding()
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))

            if !medicationSuggestions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(medicationSuggestions) { item in
                        Button {
                            draft.addMedication(item)
                            selectedMedicationID = draft.medications.last?.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.route == "Oral" ? "pills.fill" : "syringe.fill")
                                    .foregroundStyle(Color.appBlue)
                                    .frame(width: 36, height: 36)
                                    .background(Color.appBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text("\(item.defaultDose) \(item.defaultUnit) · \(item.defaultFrequency) · \(item.route)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .padding()
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.08))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                draft.addMedication()
                selectedMedicationID = draft.medications.last?.id
            } label: {
                Label(draft.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add custom medication" : "Add \"\(draft.searchText)\"", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Text("Selected Medications")
                .font(.title2.bold())

            ForEach($draft.medications) { $medication in
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                    TextField("Medication", text: $medication.name, axis: .vertical)
                        .font(.title3)
                    Button(role: .destructive) {
                        draft.medications.removeAll { $0.id == medication.id }
                        selectedMedicationID = draft.medications.first?.id
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                }
                .padding()
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var configureStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if draft.medications.isEmpty {
                EmptyStateView(systemImage: "pills", title: "No medications", message: "Go back and add at least one medication.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(draft.medications) { medication in
                            Button {
                                selectedMedicationID = medication.id
                            } label: {
                                Text(medication.name.isEmpty ? "Medication" : medication.name)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(selectedMedicationID == medication.id ? Color.appBlue : Color(.systemGray5), in: Capsule())
                                    .foregroundStyle(selectedMedicationID == medication.id ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Picker("Configure", selection: $configureTab) {
                    Text("Dose").tag("Dose")
                    Text("Schedule").tag("Schedule")
                    Text("Preferences").tag("Preferences")
                }
                .pickerStyle(.segmented)

                if let index = selectedDraftMedicationIndex {
                    switch configureTab {
                    case "Schedule":
                        scheduleFields(index: index)
                    case "Preferences":
                        preferenceFields(index: index)
                    default:
                        doseFields(index: index)
                    }
                }
            }
        }
    }

    private var inventoryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($draft.medications) { $medication in
                ModelCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(medication.name.isEmpty ? "Medication" : medication.name)
                            .font(.headline)
                        Toggle("Track Cost", isOn: $medication.tracksCost)
                        if medication.tracksCost {
                            HStack {
                                Text("Cost per dose ($)")
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $medication.costText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .accessibilityLabel("Cost per dose")
                            }
                        }
                        Text("Vial and lot quantities are tracked as Batches in the Tracker tab; every logged dose draws down its batch.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            ModelCard(background: Color.appBlue.opacity(0.12), stroke: Color.appBlue.opacity(0.35)) {
                HStack {
                    Image(systemName: "list.clipboard.fill")
                        .font(.title)
                        .foregroundStyle(Color.appBlue)
                    VStack(alignment: .leading) {
                        Text("Protocol")
                            .foregroundStyle(.secondary)
                        Text(draft.name)
                            .font(.title.bold())
                    }
                }
            }

            Text("Medications (\(draft.medications.count))")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(draft.medications) { medication in
                HStack(spacing: 14) {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(Color.appBlue)
                        .frame(width: 52, height: 52)
                        .background(Color.appBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(medication.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(medication.frequency)
                            .foregroundStyle(.secondary)
                        Text("\(medication.route) · \(medication.startDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    Spacer()
                    Text("\(medication.doseText) \(medication.unit)")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 14))
            }

            HStack {
                ReviewStat(value: "\(draft.medications.count)", title: "Medications", systemImage: "cross.case.fill", tint: Color.appBlue)
                ReviewStat(value: "\(draft.medications.filter(\.tracksCost).count)", title: "With Cost", systemImage: "dollarsign.circle.fill", tint: .green)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                if draft.step == 0 {
                    dismiss()
                } else {
                    draft.step -= 1
                }
            } label: {
                Text(draft.step == 0 ? "Cancel" : "Back")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)

            Button {
                if draft.step == 3 {
                    save()
                } else {
                    draft.step += 1
                }
            } label: {
                Text(draft.step == 3 ? "Save" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(draft.step == 3 ? .green : Color.appBlue)
            .disabled(!draft.canAdvance)
        }
        .padding()
        .background(.bar)
    }

    private var selectedDraftMedicationIndex: Int? {
        guard let selectedMedicationID else { return draft.medications.indices.first }
        return draft.medications.firstIndex { $0.id == selectedMedicationID }
    }

    private var medicationSuggestions: [MedicationCatalogItem] {
        MedicationCatalog.search(
            draft.searchText,
            excluding: Set(draft.medications.map { $0.name.lowercased() })
        )
    }

    private func doseFields(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Display Name (Optional)")
            TextField("e.g., Test C", text: $draft.medications[index].displayName)
                .textFieldStyle(.roundedBorder)

            Text("Dose Amount")
            HStack {
                TextField("25.0", text: $draft.medications[index].doseText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    ForEach(["MG", "MCG", "IU", "ML", "UNITS"], id: \.self) { option in
                        Button(option) { draft.medications[index].unit = option }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(draft.medications[index].unit)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 90, height: 34)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Dose unit")
            }

            Picker("Dose Amount Represents", selection: $draft.medications[index].doseRepresents) {
                Text("Per dose").tag("Per dose")
                Text("Weekly total").tag("Weekly total")
            }
            .pickerStyle(.segmented)
        }
    }

    private func scheduleFields(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Frequency")
            Picker("Frequency", selection: $draft.medications[index].frequency) {
                ForEach(draft.medications[index].frequencyOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)

            DatePicker("Start Date", selection: $draft.medications[index].startDate, displayedComponents: .date)

            DatePicker("Dose Time", selection: $draft.medications[index].time, displayedComponents: .hourAndMinute)

            if draft.medications[index].frequency == DraftMedication.twiceDailyFrequency {
                DatePicker("Second Dose Time", selection: $draft.medications[index].secondTime, displayedComponents: .hourAndMinute)
            }

            if draft.medications[index].frequency == DraftMedication.customWeekdaysFrequency {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dose Days")
                        .font(.headline)
                    WeekdayToggleSelector(selection: $draft.medications[index].customDays)
                }
            }

            if draft.medications[index].frequency == DraftMedication.everyNDaysFrequency {
                Stepper(value: $draft.medications[index].everyNDays, in: 2...60) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dose every \(draft.medications[index].everyNDays) days")
                        Text("Anchored to the selected start date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func preferenceFields(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Administration Route")
            Picker("Administration Route", selection: $draft.medications[index].route) {
                Text("Subcutaneous (SubQ)").tag("SubQ")
                Text("Intramuscular (IM)").tag("IM")
                Text("Oral").tag("Oral")
            }
            .pickerStyle(.menu)

            Toggle("Notifications enabled", isOn: $draft.medications[index].remindersEnabled)

            Text("Injection sites can be configured after saving the protocol.")
                .font(.subheadline)
                .foregroundStyle(Color.appBlue)
                .padding()
                .background(Color.appBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func save() {
        store.upsertProtocol(named: draft.name, medications: draft.makeMedications(), replacing: originalStackName)
        dismiss()
    }
}

struct ProtocolDraft {
    var step = 0
    var name: String
    var searchText = ""
    var medications: [DraftMedication]

    init(template: ProtocolTemplate?, stack: ProtocolStack?) {
        if let stack {
            name = stack.name
            medications = stack.medications.map(DraftMedication.init)
        } else if let template {
            name = template.name
            medications = template.medications.map(DraftMedication.init)
        } else {
            name = ""
            medications = []
        }
    }

    var canAdvance: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !medications.isEmpty &&
        medications.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    mutating func addMedication() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        medications.append(DraftMedication(name: name.isEmpty ? "New Medication" : name))
        searchText = ""
    }

    mutating func addMedication(_ catalogItem: MedicationCatalogItem) {
        medications.append(DraftMedication(catalogItem: catalogItem))
        searchText = ""
    }

    func makeMedications() -> [Medication] {
        medications.map { $0.makeMedication(protocolName: name.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

struct MedicationCatalogItem: Identifiable {
    var id: String { name }
    var name: String
    var defaultDose: String
    var defaultUnit: String
    var defaultFrequency: String
    var route: String
}

enum MedicationCatalog {
    static let items: [MedicationCatalogItem] = [
        MedicationCatalogItem(name: "Testosterone Cypionate", defaultDose: "25", defaultUnit: "mg", defaultFrequency: "Twice Weekly", route: "SubQ"),
        MedicationCatalogItem(name: "hCG (Human Chorionic Gonadotropin)", defaultDose: "300", defaultUnit: "IU", defaultFrequency: "Twice Weekly", route: "SubQ"),
        MedicationCatalogItem(name: "Tirzepatide", defaultDose: "2.5", defaultUnit: "mg", defaultFrequency: "Weekly", route: "SubQ"),
        MedicationCatalogItem(name: "Thymosin Alpha-1", defaultDose: "1.5", defaultUnit: "mg", defaultFrequency: "Twice Weekly", route: "SubQ"),
        MedicationCatalogItem(name: "BPC-157", defaultDose: "250", defaultUnit: "mcg", defaultFrequency: "Daily", route: "SubQ"),
        MedicationCatalogItem(name: "NAD+", defaultDose: "100", defaultUnit: "mg", defaultFrequency: "Weekly", route: "SubQ"),
        MedicationCatalogItem(name: "Glutathione", defaultDose: "200", defaultUnit: "mg", defaultFrequency: "Twice Weekly", route: "SubQ"),
        MedicationCatalogItem(name: "Vitamin D3", defaultDose: "5000", defaultUnit: "IU", defaultFrequency: "Daily", route: "Oral"),
        MedicationCatalogItem(name: "Magnesium Glycinate", defaultDose: "200", defaultUnit: "mg", defaultFrequency: "Daily", route: "Oral")
    ]

    static func search(_ query: String, excluding selectedNames: Set<String>) -> [MedicationCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { !selectedNames.contains($0.name.lowercased()) }

        guard !trimmed.isEmpty else {
            return Array(filtered.prefix(4))
        }

        return filtered
            .filter { item in
                item.name.localizedCaseInsensitiveContains(trimmed) ||
                item.route.localizedCaseInsensitiveContains(trimmed)
            }
            .prefix(5)
            .map { $0 }
    }
}

struct DraftMedication: Identifiable {
    static let dailyFrequency = "Daily"
    static let twiceDailyFrequency = "Twice Daily"
    static let twiceWeeklyFrequency = "Twice Weekly"
    static let weeklyFrequency = "Weekly"
    static let customWeekdaysFrequency = "Custom Weekdays"
    static let everyNDaysFrequency = "Every N Days"

    var id: UUID
    var existingMedication: Medication?
    var name: String
    var displayName: String
    var doseText: String
    var unit: String
    var doseRepresents: String
    var frequency: String
    var startDate: Date
    var time: Date
    var secondTime: Date
    var customDays: Set<Weekday>
    var everyNDays: Int
    var route: String
    var remindersEnabled: Bool
    var tracksCost: Bool
    var costText: String
    var tracksInventory: Bool
    var quantity: Double
    var lowQuantity: Double

    /// Days of the original schedule, kept so a round-trip edit that doesn't
    /// touch frequency preserves custom weekday selections (e.g. Mon/Wed/Fri).
    private var originalDays: Set<Weekday>?
    private var originalFrequency: String?

    init(name: String) {
        self.id = UUID()
        self.existingMedication = nil
        self.name = name
        self.displayName = ""
        self.doseText = "25.0"
        self.unit = "MG"
        self.doseRepresents = "Per dose"
        self.frequency = Self.twiceWeeklyFrequency
        self.startDate = Date()
        self.time = Calendar.doseTrackCalendar.dateBySettingTime(hour: 9, minute: 0, on: Date()) ?? Date()
        self.secondTime = Calendar.doseTrackCalendar.dateBySettingTime(hour: 20, minute: 0, on: Date()) ?? Date()
        self.customDays = [.monday, .thursday]
        self.everyNDays = 3
        self.route = "SubQ"
        self.remindersEnabled = true
        self.tracksCost = false
        self.costText = ""
        self.tracksInventory = false
        self.quantity = 0
        self.lowQuantity = 5
    }

    init(catalogItem: MedicationCatalogItem) {
        self.init(name: catalogItem.name)
        self.doseText = catalogItem.defaultDose
        self.unit = catalogItem.defaultUnit
        self.frequency = catalogItem.defaultFrequency
        self.route = catalogItem.route
    }

    init(medication: Medication) {
        self.id = medication.id
        self.existingMedication = medication
        self.name = medication.name
        self.displayName = medication.displayName ?? ""
        self.doseText = medication.dose
        self.unit = medication.unit.uppercased()
        self.doseRepresents = "Per dose"
        self.frequency = Self.frequency(for: medication)
        let sortedSchedules = medication.schedules.sorted { lhs, rhs in
            if lhs.hour == rhs.hour { return lhs.minute < rhs.minute }
            return lhs.hour < rhs.hour
        }
        let firstSchedule = sortedSchedules.first
        self.startDate = firstSchedule?.startDate ?? medication.createdAt
        self.time = Calendar.doseTrackCalendar.dateBySettingTime(
            hour: firstSchedule?.hour ?? 9,
            minute: firstSchedule?.minute ?? 0,
            on: Date()
        ) ?? Date()
        let secondSchedule = sortedSchedules.dropFirst().first
        self.secondTime = Calendar.doseTrackCalendar.dateBySettingTime(
            hour: secondSchedule?.hour ?? 20,
            minute: secondSchedule?.minute ?? 0,
            on: Date()
        ) ?? (Calendar.doseTrackCalendar.dateBySettingTime(hour: 20, minute: 0, on: Date()) ?? Date())
        self.customDays = firstSchedule?.daysOfWeek ?? [.monday, .thursday]
        self.everyNDays = max(2, firstSchedule?.intervalDays ?? 3)
        self.route = medication.instructions.isEmpty ? "SubQ" : medication.instructions
        self.remindersEnabled = firstSchedule?.reminderEnabled ?? true
        self.tracksCost = medication.costPerDose != nil
        self.costText = medication.costPerDose.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        self.tracksInventory = medication.inventory.isTracked
        self.quantity = medication.inventory.currentQuantity
        self.lowQuantity = medication.inventory.lowQuantityThreshold
        self.originalDays = firstSchedule?.daysOfWeek
        self.originalFrequency = self.frequency
    }

    var frequencyOptions: [String] {
        var options = [
            Self.dailyFrequency,
            Self.twiceDailyFrequency,
            Self.twiceWeeklyFrequency,
            Self.weeklyFrequency,
            Self.customWeekdaysFrequency,
            Self.everyNDaysFrequency
        ]
        if let originalFrequency, !options.contains(originalFrequency) {
            options.append(originalFrequency)
        }
        return options
    }

    func makeMedication(protocolName: String) -> Medication {
        let components = Calendar.doseTrackCalendar.dateComponents([.hour, .minute], from: time)
        let days = daysForFrequency
        let enteredAmount = Double(doseText) ?? 1
        let perDoseAmount = doseRepresents == "Weekly total"
            ? enteredAmount / estimatedDosesPerWeek
            : enteredAmount
        let perDoseText = perDoseAmount.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))

        let scheduleLabel = route == "Oral" ? "Dose" : "Injection"
        let scheduleIDs = existingMedication?.schedules.map(\.id) ?? []
        let intervalDays = frequency == Self.everyNDaysFrequency ? everyNDays : nil
        let firstSchedule = DoseSchedule(
            id: scheduleIDs.first ?? UUID(),
            label: frequency == Self.twiceDailyFrequency ? "Morning" : scheduleLabel,
            hour: components.hour ?? 9,
            minute: components.minute ?? 0,
            amount: perDoseAmount,
            daysOfWeek: days,
            intervalDays: intervalDays,
            startDate: startDate,
            reminderEnabled: remindersEnabled
        )
        let schedules: [DoseSchedule]
        if frequency == Self.twiceDailyFrequency {
            let secondComponents = Calendar.doseTrackCalendar.dateComponents([.hour, .minute], from: secondTime)
            let secondSchedule = DoseSchedule(
                id: scheduleIDs.dropFirst().first ?? UUID(),
                label: "Evening",
                hour: secondComponents.hour ?? 20,
                minute: secondComponents.minute ?? 0,
                amount: perDoseAmount,
                daysOfWeek: days,
                startDate: startDate,
                reminderEnabled: remindersEnabled
            )
            schedules = [firstSchedule, secondSchedule]
        } else {
            schedules = [firstSchedule]
        }

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        return Medication(
            id: id,
            protocolName: protocolName,
            name: name,
            displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
            dose: perDoseText,
            unit: unit,
            instructions: route,
            notes: existingMedication?.notes ?? "",
            colorHex: existingMedication?.colorHex ?? (route == "Oral" ? "#34C759" : "#1687F3"),
            inventory: existingMedication?.inventory ?? .empty,
            schedules: schedules,
            isActive: existingMedication?.isActive ?? true,
            pausedUntil: existingMedication?.pausedUntil,
            costPerDose: tracksCost ? Double(costText) : nil,
            createdAt: existingMedication?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }

    private var daysForFrequency: Set<Weekday> {
        // Frequency untouched during an edit: keep the exact original days.
        if let originalDays, frequency == originalFrequency {
            return originalDays
        }

        switch frequency {
        case Self.dailyFrequency, Self.twiceDailyFrequency, Self.everyNDaysFrequency:
            return Set(Weekday.allCases)
        case Self.weeklyFrequency:
            return [.monday]
        case Self.customWeekdaysFrequency:
            return customDays.isEmpty ? [.monday] : customDays
        default:
            return [.monday, .thursday]
        }
    }

    private var estimatedDosesPerWeek: Double {
        switch frequency {
        case Self.twiceDailyFrequency:
            return 14
        case Self.everyNDaysFrequency:
            return max(1, 7 / Double(max(2, everyNDays)))
        default:
            return Double(max(1, daysForFrequency.count))
        }
    }

    private static func frequency(for medication: Medication) -> String {
        let schedules = medication.schedules.sorted { lhs, rhs in
            if lhs.hour == rhs.hour { return lhs.minute < rhs.minute }
            return lhs.hour < rhs.hour
        }
        guard let first = schedules.first else { return Self.twiceWeeklyFrequency }

        if schedules.count == 2,
           schedules.allSatisfy({ $0.intervalDays == nil && $0.daysOfWeek == Set(Weekday.allCases) }) {
            return Self.twiceDailyFrequency
        }

        if let intervalDays = first.intervalDays, intervalDays > 1 {
            return Self.everyNDaysFrequency
        }

        if first.daysOfWeek == Set(Weekday.allCases) {
            return Self.dailyFrequency
        }

        if first.daysOfWeek == [.monday, .thursday] {
            return Self.twiceWeeklyFrequency
        }

        if first.daysOfWeek.count == 1 {
            return Self.weeklyFrequency
        }

        return Self.customWeekdaysFrequency
    }
}

struct WeekdayToggleSelector: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected {
                        if selection.count > 1 {
                            selection.remove(day)
                        }
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.shortName)
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(isSelected ? Color.appBlue : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? Color.appBlue.opacity(0.4) : Color.black.opacity(0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
            }
        }
    }
}

struct ReviewStat: View {
    var value: String
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.14), in: Circle())
            Text(value)
                .font(.title.bold())
            Text(title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18))
    }
}
