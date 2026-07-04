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
                        .foregroundStyle(.primary)
                        .frame(width: 74, height: 74)
                        .background(Color.appBlue, in: Circle())
                        .shadow(radius: 12, y: 6)
                }
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
                    Text(stack.isActive ? "Active" : "Inactive")
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

                Divider()

                HStack(spacing: 28) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.appBlue)
                    }
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.orange)
                    }
                    Button(action: stack.isActive ? onPause : onResume) {
                        Image(systemName: stack.isActive ? "pause.fill" : "play.fill")
                            .foregroundStyle(.orange)
                    }
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    Spacer()
                    Button(action: onToggle) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.title2)

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
                                Text("\(medication.displayDose) \(frequencyLabel(for: medication))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var shareText: String {
        "\(stack.name): \(stack.medications.map { $0.name }.joined(separator: ", "))"
    }

    private func frequencyLabel(for medication: Medication) -> String {
        medication.frequencyLabel
    }
}
