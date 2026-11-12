import SwiftUI

struct ProtocolStacksView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = "Protocols"
    @State private var selectedStatus = "Active"
    @State private var expandedStacks: Set<String> = []
    @State private var editorStack: ProtocolStack?
    @State private var showsNewEditor = false

    private let categories = ["Protocols", "Blends", "Vitality", "Fuel"]

    private var stacks: [ProtocolStack] {
        store.protocolStacks(includeInactive: true)
            .filter { selectedStatus == "Active" ? $0.isActive : !$0.isActive }
            .filter(matchesSelectedCategory)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title2.bold())
                                    .frame(width: 52, height: 52)
                                    .background(Color.appSurface, in: Circle())
                            }
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Close optimization stacks")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Optimization Stacks")
                                    .font(.largeTitle.bold())
                                Text("Treatment protocols and medications.")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Picker("Status", selection: $selectedStatus) {
                            Text("Active (\(store.protocolStacks().filter(\.isActive).count))").tag("Active")
                            Text("Inactive (\(store.protocolStacks().filter { !$0.isActive }.count))").tag("Inactive")
                        }
                        .pickerStyle(.segmented)

                        if stacks.isEmpty {
                            EmptyStateView(systemImage: "square.stack.3d.up", title: "No \(selectedStatus.lowercased()) stacks", message: "Add a protocol to start building your optimization stack.")
                        } else {
                            ForEach(stacks) { stack in
                                ProtocolStackCard(
                                    stack: stack,
                                    isExpanded: expandedStacks.contains(stack.name),
                                    onToggle: {
                                        if expandedStacks.contains(stack.name) {
                                            expandedStacks.remove(stack.name)
                                        } else {
                                            expandedStacks.insert(stack.name)
                                        }
                                    },
                                    onEdit: { editorStack = stack },
                                    onPause: { store.setStack(named: stack.name, isActive: false) },
                                    onResume: { store.setStack(named: stack.name, isActive: true) },
                                    onDelete: { store.deleteStack(named: stack.name) }
                                )
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }

                Button {
                    showsNewEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(Color.appBlue, in: Circle())
                        .shadow(radius: 12, y: 6)
                }
                .accessibilityLabel("New protocol")
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(item: $editorStack) { stack in
                ProtocolEditorView(stack: stack)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsNewEditor) {
                ProtocolEditorView()
                    .environmentObject(store)
            }
        }
    }

    private func matchesSelectedCategory(_ stack: ProtocolStack) -> Bool {
        guard selectedCategory != "Protocols" else { return true }

        let haystack = ([stack.name] + stack.medications.map(\.name))
            .joined(separator: " ")
            .lowercased()

        switch selectedCategory {
        case "Blends":
            return haystack.contains("blend") || haystack.contains("stack")
        case "Vitality":
            return ["testosterone", "hcg", "nad", "glutathione", "longevity", "immune"].contains { haystack.contains($0) }
        case "Fuel":
            return ["vitamin", "magnesium", "fuel", "protein", "metabolic"].contains { haystack.contains($0) }
        default:
            return true
        }
    }
}

struct ProtocolStackCard: View {
    var stack: ProtocolStack
    var isExpanded: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onDelete: () -> Void
    @EnvironmentObject private var store: DoseStore
    @State private var confirmsDelete = false
    @State private var pausingMedication: Medication?

    private var pausedCount: Int {
        stack.medications.filter { !$0.isActive }.count
    }

    var body: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Circle()
                        .fill(stack.isActive ? .green : .gray)
                        .frame(width: 14, height: 14)
                    Text(stack.name)
                        .font(.title.bold())
                    Spacer()
                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(stack.isActive ? .green : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((stack.isActive ? Color.green : Color.gray).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Label("\(stack.medicationCount) medication\(stack.medicationCount == 1 ? "" : "s")", systemImage: "cross.case")
                    Label("Started \(stack.startedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")", systemImage: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if stack.isActive && pausedCount > 0 {
                    Label("\(pausedCount) of \(stack.medicationCount) paused", systemImage: "pause.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Divider()

                HStack(spacing: 28) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.appBlue)
                    }
                    .accessibilityLabel("Share \(stack.name)")
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.orange)
                    }
                    .accessibilityLabel("Edit \(stack.name)")
                    Button(action: stack.isActive ? onPause : onResume) {
                        Image(systemName: stack.isActive ? "pause.fill" : "play.fill")
                            .foregroundStyle(.orange)
                    }
                    .accessibilityLabel(stack.isActive ? "Pause \(stack.name)" : "Resume \(stack.name)")
                    Button(role: .destructive) {
                        confirmsDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete \(stack.name)")
                    Spacer()
                    Button(action: onToggle) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(isExpanded ? "Collapse \(stack.name)" : "Expand \(stack.name)")
                }
                .font(.title2)
                .sheet(item: $pausingMedication) { medication in
                    PauseMedicationSheet(medication: medication)
                        .environmentObject(store)
                }
                .confirmationDialog("Delete \(stack.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button("Delete Protocol", role: .destructive, action: onDelete)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the protocol's medications along with their dose history and batches on every synced device. Pause it instead to keep the history.")
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(stack.medications) { medication in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(medication.name)
                                        .font(.headline)
                                    Text(medication.instructions.isEmpty ? "SubQ" : medication.instructions)
                                        .foregroundStyle(.secondary)
                                    Text("Started \(medication.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                        .foregroundStyle(.secondary.opacity(0.7))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 8) {
                                    Text("\(medication.displayDose) \(frequencyLabel(for: medication))")
                                        .foregroundStyle(.secondary)
                                    if stack.medicationCount > 1 || stack.isActive {
                                        medicationPauseButton(medication)
                                    }
                                }
                            }
                            .opacity(medication.isActive ? 1 : 0.7)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var statusText: String {
        guard stack.isActive else { return "Inactive" }
        return pausedCount > 0 ? "Partly active" : "Active"
    }

    private func medicationPauseButton(_ medication: Medication) -> some View {
        Button {
            if medication.isActive {
                pausingMedication = medication
            } else {
                withAnimation(.snappy) {
                    store.setMedicationActive(medication, isActive: true)
                }
            }
        } label: {
            Label(medication.isActive ? "Pause" : "Resume", systemImage: medication.isActive ? "pause.fill" : "play.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background((medication.isActive ? Color.orange : Color.appBlue).opacity(0.14), in: Capsule())
                .foregroundStyle(medication.isActive ? Color.orange : Color.appBlue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(medication.isActive ? "Pause \(medication.name)" : "Resume \(medication.name)")
    }

    private var shareText: String {
        "\(stack.name): \(stack.medications.map { $0.name }.joined(separator: ", "))"
    }

    private func frequencyLabel(for medication: Medication) -> String {
        medication.frequencyLabel
    }
}
