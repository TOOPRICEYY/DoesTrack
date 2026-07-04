import Charts
import SwiftUI

// MARK: - Supplements

struct SupplementsView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingSupplement: Supplement?
    @State private var showsNewSupplement = false

    private var dueToday: [Supplement] {
        store.supplements(on: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                if !dueToday.isEmpty {
                    Section("Today") {
                        ForEach(dueToday) { supplement in
                            Button {
                                store.toggleSupplement(supplement, on: Date())
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: store.isSupplementTaken(supplement, on: Date()) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(store.isSupplementTaken(supplement, on: Date()) ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(supplement.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if !supplement.displayDose.isEmpty {
                                            Text(supplement.displayDose)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .accessibilityLabel("Toggle \(supplement.name)")
                        }
                    }
                }

                Section("Benefit Coverage") {
                    if store.coveredBenefits.isEmpty {
                        Text("Add supplements with benefit tags to see coverage.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(SupplementBenefit.allCases) { benefit in
                            HStack {
                                Text(benefit.rawValue)
                                Spacer()
                                Image(systemName: store.coveredBenefits.contains(benefit) ? "checkmark.circle.fill" : "circle.dotted")
                                    .foregroundStyle(store.coveredBenefits.contains(benefit) ? .green : .secondary)
                            }
                        }
                    }
                }

                Section("All Supplements") {
                    if store.supplements.isEmpty {
                        Text("No supplements yet. Add one to start tracking.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.supplements) { supplement in
                        Button {
                            editingSupplement = supplement
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplement.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(supplementSubtitle(supplement))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !supplement.isActive {
                                    Text("Paused")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteSupplement(store.supplements[index])
                        }
                    }
                }
            }
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsNewSupplement = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add supplement")
                }
            }
            .sheet(isPresented: $showsNewSupplement) {
                SupplementEditorView(supplement: nil)
                    .environmentObject(store)
            }
            .sheet(item: $editingSupplement) { supplement in
                SupplementEditorView(supplement: supplement)
                    .environmentObject(store)
            }
        }
    }

    private func supplementSubtitle(_ supplement: Supplement) -> String {
        var parts: [String] = []
        if !supplement.displayDose.isEmpty {
            parts.append(supplement.displayDose)
        }
        parts.append(supplement.daysOfWeek.count == 7 ? "Daily" : "\(supplement.daysOfWeek.count) days/wk")
        if !supplement.benefits.isEmpty {
            parts.append(supplement.benefits.map(\.rawValue).joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }
}

private struct SupplementEditorView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var dose: String
    @State private var unit: String
    @State private var benefits: Set<SupplementBenefit>
    @State private var days: Set<Weekday>
    @State private var isActive: Bool

    private let existing: Supplement?

    init(supplement: Supplement?) {
        self.existing = supplement
        _name = State(initialValue: supplement?.name ?? "")
        _dose = State(initialValue: supplement?.dose ?? "")
        _unit = State(initialValue: supplement?.unit ?? "mg")
        _benefits = State(initialValue: Set(supplement?.benefits ?? []))
        _days = State(initialValue: supplement?.daysOfWeek ?? Set(Weekday.allCases))
        _isActive = State(initialValue: supplement?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Supplement") {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Dose", text: $dose)
                            .keyboardType(.decimalPad)
                        TextField("Unit", text: $unit)
                            .frame(width: 90)
                    }
                    Toggle("Active", isOn: $isActive)
                }

                Section("Days") {
                    HStack(spacing: 8) {
                        ForEach(Weekday.allCases) { day in
                            Button {
                                if days.contains(day) {
                                    days.remove(day)
                                } else {
                                    days.insert(day)
                                }
                            } label: {
                                Text(String(day.shortName.prefix(1)))
                                    .font(.caption.bold())
                                    .frame(width: 32, height: 32)
                                    .background(days.contains(day) ? Color.appBlue : Color(.systemGray5), in: Circle())
                                    .foregroundStyle(days.contains(day) ? .white : .primary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(day.fullName)
                        }
                    }
                }

                Section("Benefits") {
                    ForEach(SupplementBenefit.allCases) { benefit in
                        Button {
                            if benefits.contains(benefit) {
                                benefits.remove(benefit)
                            } else {
                                benefits.insert(benefit)
                            }
                        } label: {
                            HStack {
                                Text(benefit.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if benefits.contains(benefit) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appBlue)
                                }
                            }
                        }
                    }
                }

                if existing != nil {
                    Section {
                        Button("Delete Supplement", role: .destructive) {
                            if let existing {
                                store.deleteSupplement(existing)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Supplement" : "Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || days.isEmpty)
                }
            }
        }
    }

    private func save() {
        let supplement = Supplement(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dose: dose.trimmingCharacters(in: .whitespacesAndNewlines),
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            benefits: SupplementBenefit.allCases.filter { benefits.contains($0) },
            daysOfWeek: days,
            isActive: isActive,
            createdAt: existing?.createdAt ?? Date()
        )
        store.upsertSupplement(supplement)
        dismiss()
    }
}

// MARK: - Labs

struct LabsView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsNewResult = false

    var body: some View {
        NavigationStack {
            List {
                if let marker = store.trendMarkerName {
                    let series = store.labSeries(for: marker)
                    if series.count >= 2 {
                        Section("\(marker) Trend") {
                            Chart(series) { result in
                                LineMark(
                                    x: .value("Date", result.sampledAt),
                                    y: .value(marker, result.value)
                                )
                                .foregroundStyle(Color.appBlue)
                                PointMark(
                                    x: .value("Date", result.sampledAt),
                                    y: .value(marker, result.value)
                                )
                                .foregroundStyle(result.isOutOfRange ? .red : Color.appBlue)
                            }
                            .frame(height: 180)
                            .padding(.vertical, 6)
                        }
                    }
                }

                if !store.outOfRangeMarkers.isEmpty {
                    Section("Out of Range") {
                        ForEach(store.outOfRangeMarkers) { result in
                            LabResultRow(result: result)
                        }
                    }
                }

                Section("All Results") {
                    if store.labResults.isEmpty {
                        Text("No lab results yet. Add your bloodwork to track markers over time.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.labResults) { result in
                        LabResultRow(result: result)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteLabResult(store.labResults[index])
                        }
                    }
                }
            }
            .navigationTitle("Labs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsNewResult = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add lab result")
                }
            }
            .sheet(isPresented: $showsNewResult) {
                LabResultEditorView()
                    .environmentObject(store)
            }
        }
    }
}

private struct LabResultRow: View {
    var result: LabResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.marker)
                    .font(.headline)
                Text(result.sampledAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.valueText)
                    .font(.headline)
                    .foregroundStyle(result.isOutOfRange ? .red : .primary)
                if let low = result.rangeLow, let high = result.rangeHigh {
                    Text("\(low.formatted(.number.precision(.fractionLength(0...1))))–\(high.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LabResultEditorView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var marker = ""
    @State private var valueText = ""
    @State private var unit = ""
    @State private var rangeLowText = ""
    @State private var rangeHighText = ""
    @State private var sampledAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Marker") {
                    TextField("Marker (e.g. Total Testosterone)", text: $marker)
                    HStack {
                        TextField("Value", text: $valueText)
                            .keyboardType(.decimalPad)
                        TextField("Unit (e.g. ng/dL)", text: $unit)
                    }
                    DatePicker("Sampled", selection: $sampledAt, displayedComponents: .date)
                }

                Section("Reference Range (optional)") {
                    TextField("Low", text: $rangeLowText)
                        .keyboardType(.decimalPad)
                    TextField("High", text: $rangeHighText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Lab Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(marker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(valueText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let value = Double(valueText) else { return }
        store.addLabResult(
            LabResult(
                marker: marker.trimmingCharacters(in: .whitespacesAndNewlines),
                value: value,
                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                rangeLow: Double(rangeLowText),
                rangeHigh: Double(rangeHighText),
                sampledAt: sampledAt
            )
        )
        dismiss()
    }
}

// MARK: - Cycle

struct CycleEditorView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var stackName = ""
    @State private var weeksOn = 8
    @State private var weeksOff = 4
    @State private var startDate = Date()

    private var stackNames: [String] {
        store.protocolStacks().map(\.name)
    }

    private var existingCycle: ProtocolCycle? {
        store.cycle(forStack: stackName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Protocol") {
                    if stackNames.isEmpty {
                        Text("Add a protocol first, then configure its cycle.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Protocol", selection: $stackName) {
                            ForEach(stackNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                Section("Cycle") {
                    Stepper("Weeks on: \(weeksOn)", value: $weeksOn, in: 1...52)
                    Stepper("Weeks off: \(weeksOff)", value: $weeksOff, in: 0...52)
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                }

                if let cycle = existingCycle, let phase = cycle.phase(on: Date()) {
                    Section("Current Phase") {
                        LabeledContent(
                            phase.isOn ? "On cycle" : "Off cycle",
                            value: "week \(phase.weekInPhase) of \(phase.phaseLengthWeeks)"
                        )
                    }

                    Section {
                        Button("Remove Cycle", role: .destructive) {
                            store.deleteCycle(cycle)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Protocol Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertCycle(
                            ProtocolCycle(
                                id: existingCycle?.id ?? UUID(),
                                stackName: stackName,
                                weeksOn: weeksOn,
                                weeksOff: weeksOff,
                                startDate: startDate
                            )
                        )
                        dismiss()
                    }
                    .disabled(stackName.isEmpty)
                }
            }
            .onAppear {
                if stackName.isEmpty {
                    stackName = store.featuredCycle?.stackName ?? stackNames.first ?? ""
                }
                if let cycle = store.cycle(forStack: stackName) {
                    weeksOn = cycle.weeksOn
                    weeksOff = cycle.weeksOff
                    startDate = cycle.startDate
                }
            }
            .onChange(of: stackName) { _, newValue in
                guard let cycle = store.cycle(forStack: newValue) else { return }
                weeksOn = cycle.weeksOn
                weeksOff = cycle.weeksOff
                startDate = cycle.startDate
            }
        }
    }
}

// MARK: - Recon planner

struct ReconPlannerView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var vialMgText = ""
    @State private var waterMlText = ""
    @State private var doseMcgText = ""

    private var draftPlan: ReconPlan? {
        guard let vialMg = Double(vialMgText),
              let waterMl = Double(waterMlText),
              let doseMcg = Double(doseMcgText),
              vialMg > 0, waterMl > 0, doseMcg > 0
        else { return nil }

        return ReconPlan(
            id: store.activeReconPlan?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            vialMg: vialMg,
            waterMl: waterMl,
            doseMcg: doseMcg
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vial") {
                    TextField("Peptide name", text: $name)
                    HStack {
                        Text("Peptide in vial")
                        Spacer()
                        TextField("5", text: $vialMgText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mg").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bacteriostatic water")
                        Spacer()
                        TextField("2", text: $waterMlText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mL").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Target dose")
                        Spacer()
                        TextField("250", text: $doseMcgText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mcg").foregroundStyle(.secondary)
                    }
                }

                Section("Result") {
                    if let plan = draftPlan {
                        LabeledContent("Concentration", value: "\((plan.concentrationMgPerMl ?? 0).formatted(.number.precision(.fractionLength(0...2)))) mg/mL")
                        LabeledContent("Draw per dose", value: "\((plan.doseVolumeMl ?? 0).formatted(.number.precision(.fractionLength(0...3)))) mL")
                        LabeledContent("U-100 syringe", value: "\((plan.doseUnitsU100 ?? 0).formatted(.number.precision(.fractionLength(0...1)))) units")
                        LabeledContent("Doses per vial", value: (plan.dosesPerVial ?? 0).formatted(.number.precision(.fractionLength(0))))
                    } else {
                        Text("Enter vial size, water volume, and target dose to see the draw.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let active = store.activeReconPlan {
                    Section("Active Vial") {
                        LabeledContent(active.name.isEmpty ? "Unnamed" : active.name) {
                            Text("\((active.doseUnitsU100 ?? 0).formatted(.number.precision(.fractionLength(0...1)))) U per dose")
                        }
                        Button("Finish Vial", role: .destructive) {
                            store.deleteReconPlan(active)
                        }
                    }
                }
            }
            .navigationTitle("Recon Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Vial") {
                        if let plan = draftPlan {
                            store.upsertReconPlan(plan)
                            dismiss()
                        }
                    }
                    .disabled(draftPlan == nil)
                }
            }
            .onAppear {
                guard let active = store.activeReconPlan else { return }
                name = active.name
                vialMgText = active.vialMg.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
                waterMlText = active.waterMl.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
                doseMcgText = active.doseMcg.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
            }
        }
    }
}

// MARK: - Unit converter

struct UnitConverterView: View {
    @Environment(\.dismiss) private var dismiss

    private enum MassUnit: String, CaseIterable, Identifiable {
        case g, mg, mcg

        var id: String { rawValue }

        var inMilligrams: Double {
            switch self {
            case .g: return 1_000
            case .mg: return 1
            case .mcg: return 0.001
            }
        }
    }

    @State private var valueText = "1"
    @State private var fromUnit = MassUnit.mg
    @State private var toUnit = MassUnit.mcg
    @State private var concentrationText = ""
    @State private var doseText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Mass") {
                    HStack {
                        TextField("Value", text: $valueText)
                            .keyboardType(.decimalPad)
                        Picker("From", selection: $fromUnit) {
                            ForEach(MassUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Picker("To", selection: $toUnit) {
                            ForEach(MassUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                    }

                    LabeledContent("Result", value: massResult)
                }

                Section("Syringe Draw (U-100)") {
                    HStack {
                        Text("Concentration")
                        Spacer()
                        TextField("2.5", text: $concentrationText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mg/mL").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Dose")
                        Spacer()
                        TextField("250", text: $doseText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mcg").foregroundStyle(.secondary)
                    }
                    LabeledContent("Draw", value: drawResult)
                }

                Section {
                    Text("IU is substance-specific and has no universal mass conversion, so DoesTrack does not convert IU automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Unit Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var massResult: String {
        guard let value = Double(valueText) else { return "—" }
        let converted = value * fromUnit.inMilligrams / toUnit.inMilligrams
        return "\(converted.formatted(.number.precision(.fractionLength(0...4)))) \(toUnit.rawValue)"
    }

    private var drawResult: String {
        guard let concentration = Double(concentrationText), concentration > 0,
              let dose = Double(doseText), dose > 0
        else { return "—" }

        let milliliters = (dose / 1_000) / concentration
        let units = milliliters * 100
        return "\(units.formatted(.number.precision(.fractionLength(0...1)))) units (\(milliliters.formatted(.number.precision(.fractionLength(0...3)))) mL)"
    }
}
