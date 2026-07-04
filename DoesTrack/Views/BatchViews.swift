import SwiftUI

// MARK: - Tracker tab block

struct BatchesSection: View {
    @EnvironmentObject private var store: DoseStore
    @State private var editingBatch: MedicationBatch?
    @State private var showsNewBatch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Batches (\(store.batches.count))")
                    .font(.title.bold())
                Spacer()
                Button {
                    showsNewBatch = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.headline)
                }
                .disabled(store.medications.isEmpty)
                .accessibilityLabel("Add batch")
            }

            if store.batches.isEmpty {
                ModelCard {
                    Text("Track vials and lots per medication: supplier, concentration, purchase date, and remaining quantity. Every logged dose draws down its batch.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(store.batches) { batch in
                    Button {
                        editingBatch = batch
                    } label: {
                        BatchRow(batch: batch, medication: store.medication(for: batch.medicationID))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit batch \(batch.displayName)")
                }
            }
        }
        .sheet(isPresented: $showsNewBatch) {
            BatchEditorView(batch: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingBatch) { batch in
            BatchEditorView(batch: batch)
                .environmentObject(store)
        }
    }
}

private struct BatchRow: View {
    var batch: MedicationBatch
    var medication: Medication?

    private var unit: String {
        medication?.unit ?? ""
    }

    var body: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(batch.displayName)
                            .font(.headline)
                        Text(medication?.name ?? "Unknown medication")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if batch.isFinished {
                        Text("Finished")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray5), in: Capsule())
                    } else if batch.isDepleted {
                        Text("Empty")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.red.opacity(0.12), in: Capsule())
                    }
                }

                ProgressView(value: batch.remainingFraction)
                    .tint(batch.remainingFraction < 0.15 ? .red : Color.appBlue)

                HStack {
                    Text("\(quantity(batch.remainingQuantity)) / \(quantity(batch.totalQuantity)) \(unit)")
                        .font(.subheadline.weight(.semibold))
                    if let concentration = batch.concentrationPerMl {
                        Text("· \(quantity(concentration)) \(unit)/mL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Purchased \(batch.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func quantity(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

// MARK: - Editor

struct BatchEditorView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var medicationID: UUID?
    @State private var supplier: String
    @State private var label: String
    @State private var concentrationText: String
    @State private var purchaseDate: Date
    @State private var totalText: String
    @State private var remainingText: String
    @State private var notes: String
    @State private var isFinished: Bool

    private let existing: MedicationBatch?

    init(batch: MedicationBatch?) {
        self.existing = batch
        _medicationID = State(initialValue: batch?.medicationID)
        _supplier = State(initialValue: batch?.supplier ?? "")
        _label = State(initialValue: batch?.label ?? "")
        _concentrationText = State(initialValue: batch?.concentrationPerMl.map { $0.formatted(.number.precision(.fractionLength(0...3)).grouping(.never)) } ?? "")
        _purchaseDate = State(initialValue: batch?.purchaseDate ?? Date())
        _totalText = State(initialValue: batch.map { $0.totalQuantity.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? "")
        _remainingText = State(initialValue: batch.map { $0.remainingQuantity.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? "")
        _notes = State(initialValue: batch?.notes ?? "")
        _isFinished = State(initialValue: batch?.isFinished ?? false)
    }

    private var medicationUnit: String {
        medicationID.flatMap { store.medication(for: $0)?.unit } ?? "units"
    }

    private var canSave: Bool {
        medicationID != nil && Double(totalText) != nil && (remainingText.isEmpty || Double(remainingText) != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    Picker("Medication", selection: $medicationID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(store.medications) { medication in
                            Text(medication.name).tag(UUID?.some(medication.id))
                        }
                    }
                }

                Section("Batch") {
                    TextField("Supplier", text: $supplier)
                    TextField("Label / lot (optional)", text: $label)
                    DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                    HStack {
                        Text("Concentration")
                        Spacer()
                        TextField("optional", text: $concentrationText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("\(medicationUnit)/mL")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Quantity (\(medicationUnit))") {
                    HStack {
                        Text("Total")
                        Spacer()
                        TextField("0", text: $totalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                            .accessibilityLabel("Total quantity")
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        TextField(totalText.isEmpty ? "0" : totalText, text: $remainingText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                            .accessibilityLabel("Remaining quantity")
                    }
                    if let concentration = Double(concentrationText), concentration > 0,
                       let remaining = Double(remainingText.isEmpty ? totalText : remainingText) {
                        LabeledContent("Remaining volume", value: "\((remaining / concentration).formatted(.number.precision(.fractionLength(0...2)))) mL")
                    }
                    Toggle("Finished", isOn: $isFinished)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let existing {
                    Section {
                        Button("Delete Batch", role: .destructive) {
                            store.deleteBatch(existing)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Batch" : "Edit Batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if medicationID == nil {
                    medicationID = store.medications.first(where: \.isActive)?.id ?? store.medications.first?.id
                }
            }
        }
    }

    private func save() {
        guard let medicationID, let total = Double(totalText) else { return }
        let remaining = Double(remainingText) ?? total

        store.upsertBatch(
            MedicationBatch(
                id: existing?.id ?? UUID(),
                medicationID: medicationID,
                supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                concentrationPerMl: Double(concentrationText),
                purchaseDate: purchaseDate,
                totalQuantity: total,
                remainingQuantity: remaining,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                isFinished: isFinished,
                createdAt: existing?.createdAt ?? Date()
            )
        )
        dismiss()
    }
}
