import SwiftUI

struct MedicationEditorView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    private let medication: Medication?
    @State private var draft: MedicationDraft
    @State private var editingSchedule: DoseSchedule?

    init(medication: Medication? = nil) {
        self.medication = medication
        _draft = State(initialValue: MedicationDraft(medication: medication))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $draft.name)
                    TextField("Dose", text: $draft.dose)
                    TextField("Unit", text: $draft.unit)
                    Toggle("Active", isOn: $draft.isActive)
                }

                Section("Instructions") {
                    TextField("Instructions", text: $draft.instructions, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Color") {
                    ColorPickerRow(selection: $draft.colorHex)
                }

                Section("Inventory") {
                    TextField("Current quantity", value: $draft.currentQuantity, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Low quantity alert", value: $draft.lowQuantityThreshold, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Refill quantity", value: $draft.refillQuantity, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Unit label", text: $draft.inventoryUnit)
                    Toggle("Track refill date", isOn: $draft.hasRefillDate)
                    if draft.hasRefillDate {
                        DatePicker("Next refill", selection: $draft.nextRefillDate, displayedComponents: [.date])
                    }
                }

                Section {
                    ForEach(draft.schedules) { schedule in
                        Button {
                            editingSchedule = schedule
                        } label: {
                            ScheduleSummaryRow(schedule: schedule)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        draft.schedules.remove(atOffsets: offsets)
                    }

                    Button {
                        editingSchedule = DoseSchedule(label: suggestedScheduleLabel())
                    } label: {
                        Label("Add schedule", systemImage: "plus")
                    }
                } header: {
                    Text("Schedules")
                } footer: {
                    if draft.schedules.isEmpty {
                        Text("Add at least one schedule to show doses in Today and reminders.")
                    }
                }
            }
            .navigationTitle(medication == nil ? "Add Medication" : "Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
            .sheet(item: $editingSchedule) { schedule in
                ScheduleEditorView(schedule: schedule) { updated in
                    upsertSchedule(updated)
                }
            }
        }
    }

    private func save() {
        let medication = draft.makeMedication(existing: medication)
        if self.medication == nil {
            store.addMedication(medication)
        } else {
            store.updateMedication(medication)
        }
        dismiss()
    }

    private func upsertSchedule(_ schedule: DoseSchedule) {
        if let index = draft.schedules.firstIndex(where: { $0.id == schedule.id }) {
            draft.schedules[index] = schedule
        } else {
            draft.schedules.append(schedule)
        }
        draft.schedules.sort { lhs, rhs in
            if lhs.hour == rhs.hour { return lhs.minute < rhs.minute }
            return lhs.hour < rhs.hour
        }
    }

    private func suggestedScheduleLabel() -> String {
        switch draft.schedules.count {
        case 0: return "Morning"
        case 1: return "Afternoon"
        case 2: return "Evening"
        default: return "Dose"
        }
    }
}

private struct MedicationDraft {
    var name: String
    var dose: String
    var unit: String
    var instructions: String
    var notes: String
    var colorHex: String
    var currentQuantity: Double
    var lowQuantityThreshold: Double
    var refillQuantity: Double
    var inventoryUnit: String
    var hasRefillDate: Bool
    var nextRefillDate: Date
    var schedules: [DoseSchedule]
    var isActive: Bool

    init(medication: Medication?) {
        self.name = medication?.name ?? ""
        self.dose = medication?.dose ?? ""
        self.unit = medication?.unit ?? "mg"
        self.instructions = medication?.instructions ?? ""
        self.notes = medication?.notes ?? ""
        self.colorHex = medication?.colorHex ?? "#176B87"
        self.currentQuantity = medication?.inventory.currentQuantity ?? 0
        self.lowQuantityThreshold = medication?.inventory.lowQuantityThreshold ?? 5
        self.refillQuantity = medication?.inventory.refillQuantity ?? 30
        self.inventoryUnit = medication?.inventory.unitLabel ?? "pills"
        self.hasRefillDate = medication?.inventory.nextRefillDate != nil
        self.nextRefillDate = medication?.inventory.nextRefillDate ?? Date()
        self.schedules = medication?.schedules ?? [DoseSchedule(label: "Morning")]
        self.isActive = medication?.isActive ?? true
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !schedules.isEmpty
    }

    func makeMedication(existing: Medication?) -> Medication {
        let inventory = MedicationInventory(
            currentQuantity: max(0, currentQuantity),
            lowQuantityThreshold: max(0, lowQuantityThreshold),
            refillQuantity: max(0, refillQuantity),
            unitLabel: inventoryUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "pills" : inventoryUnit,
            nextRefillDate: hasRefillDate ? nextRefillDate : nil
        )

        return Medication(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dose: dose.trimmingCharacters(in: .whitespacesAndNewlines),
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            inventory: inventory,
            schedules: schedules,
            isActive: isActive,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

private struct ColorPickerRow: View {
    @Binding var selection: String

    private let colors = [
        "#176B87", "#0B8457", "#B08900", "#B43F3F",
        "#7048A8", "#D95F59", "#3A6EA5", "#4D7C0F"
    ]

    var body: some View {
        HStack {
            ForEach(colors, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selection == color {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(color)")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ScheduleSummaryRow: View {
    var schedule: DoseSchedule

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.label.isEmpty ? "Dose" : schedule.label)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(schedule.timeLabel) - \(schedule.amount, specifier: "%g") dose")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(schedule.daysOfWeek.count == Weekday.allCases.count ? "Every day" : schedule.daysOfWeek.sorted { $0.rawValue < $1.rawValue }.map(\.shortName).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
