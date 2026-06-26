import SwiftUI

struct MedicationListView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var searchText = ""
    @State private var showsAddMedication = false

    private var filteredMedications: [Medication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.medications }

        return store.medications.filter { medication in
            medication.name.localizedCaseInsensitiveContains(query) ||
            medication.dose.localizedCaseInsensitiveContains(query) ||
            medication.unit.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.medications.isEmpty {
                    EmptyStateView(
                        systemImage: "pills",
                        title: "No medications",
                        message: "Add your first medication with dosage, schedule, and refill details."
                    )
                } else {
                    List {
                        ForEach(filteredMedications) { medication in
                            NavigationLink {
                                MedicationEditorView(medication: medication)
                            } label: {
                                MedicationListRow(medication: medication)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.deleteMedication(medication)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search medications")
                }
            }
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsAddMedication = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add medication")
                }
            }
            .sheet(isPresented: $showsAddMedication) {
                MedicationEditorView()
            }
        }
    }
}

private struct MedicationListRow: View {
    var medication: Medication

    var body: some View {
        HStack(spacing: 12) {
            MedicationSwatch(colorHex: medication.colorHex)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(medication.name)
                        .font(.headline)
                    if !medication.isActive {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }

                Text(medication.displayDose.isEmpty ? "No dosage set" : medication.displayDose)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !medication.schedules.isEmpty {
                    Text(medication.schedules.map(\.timeLabel).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if medication.inventory.isTracked {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(medication.inventory.currentQuantity, specifier: "%.0f")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(medication.inventory.needsRefill ? .red : .primary)
                    Text(medication.inventory.unitLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
