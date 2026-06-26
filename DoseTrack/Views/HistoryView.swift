import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var selectedDate = Date()
    @State private var showsManualLog = false

    private var logs: [DoseLog] {
        store.logs(on: selectedDate)
    }

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    EmptyStateView(
                        systemImage: "clock",
                        title: "No logs",
                        message: "Taken and skipped doses for the selected date will appear here."
                    )
                } else {
                    List {
                        ForEach(logs) { log in
                            HistoryLogRow(log: log, medication: store.medication(for: log.medicationID))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .safeAreaInset(edge: .top) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsManualLog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.medications.isEmpty)
                    .accessibilityLabel("Log manual dose")
                }
            }
            .sheet(isPresented: $showsManualLog) {
                ManualDoseView()
            }
        }
    }
}

private struct HistoryLogRow: View {
    var log: DoseLog
    var medication: Medication?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: log.status.systemImage)
                .foregroundStyle(log.status.tint)
                .frame(width: 30, height: 30)
                .background(log.status.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(medication?.name ?? "Deleted medication")
                    .font(.headline)
                Text(log.status.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(log.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                Text("\(log.amount, specifier: "%g")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ManualDoseView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMedicationID = UUID()
    @State private var amount = 1.0
    @State private var notes = ""

    private var selectedMedication: Medication? {
        store.medications.first { $0.id == selectedMedicationID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dose") {
                    Picker("Medication", selection: $selectedMedicationID) {
                        ForEach(store.medications) { medication in
                            Text(medication.name).tag(medication.id)
                        }
                    }
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Manual Log")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedMedication == nil, let first = store.medications.first {
                    selectedMedicationID = first.id
                    amount = first.schedules.first?.amount ?? 1
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.recordManualDose(medicationID: selectedMedicationID, amount: amount, notes: notes)
                        dismiss()
                    }
                    .disabled(selectedMedication == nil || amount <= 0)
                }
            }
        }
    }
}
