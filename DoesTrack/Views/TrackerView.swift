import SwiftUI

struct ModelTrackerView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var showsStacks = false
    @State private var showsExpenses = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tracker")
                                .font(.largeTitle.bold())
                            Text("Monitor your treatment adherence and trends.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            showsExpenses = true
                        } label: {
                            Label("Expenses", systemImage: "wallet.pass")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.45))
                                }
                        }
                        .foregroundStyle(.orange)
                    }

                    ProtocolScoreCard(score: store.protocolScore(), adherence: store.adherenceRate(days: 7), streak: store.currentStreak(), saturation: saturation)

                    HStack {
                        Text("Medications (\(store.medications.count))")
                            .font(.title.bold())
                        Spacer()
                        Button("Show more") {
                            showsStacks = true
                        }
                        .font(.headline)
                    }

                    ForEach(store.medications.prefix(5)) { medication in
                        TrackerMedicationRow(medication: medication, loggedCount: store.logs.filter { $0.medicationID == medication.id && $0.status == .taken }.count)
                    }
                }
                .padding()
                .padding(.bottom, 110)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(isPresented: $showsStacks) {
                ProtocolStacksView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsExpenses) {
                ExpensesView()
                    .environmentObject(store)
            }
        }
    }

    private var saturation: Double {
        guard !store.medications.isEmpty else { return 0 }
        return Double(store.medications.filter(\.isActive).count) / Double(store.medications.count)
    }
}

struct ProtocolScoreCard: View {
    var score: Int
    var adherence: Double
    var streak: Int
    var saturation: Double

    var body: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Protocol Score")
                    .font(.title.bold())
                Text("Based on adherence, active protocols, streaks, and inventory health.")
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .stroke(Color.appBlue.opacity(0.18), lineWidth: 20)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0.03, Double(score) / 100)))
                        .stroke(Color.appBlue, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(size: 58, weight: .bold))
                }
                .frame(width: 190, height: 190)
                .frame(maxWidth: .infinity)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 22) {
                    ScoreMetric(title: "Adherence", value: adherence.formatted(.percent.precision(.fractionLength(0))))
                    ScoreMetric(title: "Saturation", value: saturation.formatted(.percent.precision(.fractionLength(0))))
                    ScoreMetric(title: "Streak", value: "\(streak / 7) weeks")
                    ScoreMetric(title: "Consistency", value: adherence.formatted(.percent.precision(.fractionLength(0))))
                }
            }
        }
    }
}

struct ScoreMetric: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "circle.fill")
                .font(.headline)
                .foregroundStyle(.primary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.title3.bold())
        }
    }
}

struct TrackerMedicationRow: View {
    var medication: Medication
    var loggedCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Text("\(loggedCount)")
                .font(.title3.bold())
                .foregroundStyle(Color(hex: medication.colorHex))
                .frame(width: 44, height: 44)
                .background(Color(hex: medication.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(medication.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(medication.displayDose) · \(loggedCount) doses")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(medication.isActive ? "New" : "Paused")
                    .foregroundStyle(.secondary)
                Text("Since \(medication.createdAt.formatted(date: .numeric, time: .omitted))")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(hex: medication.colorHex))
                .frame(width: 5)
        }
    }
}

struct ExpensesView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Tracked Protocols") {
                    ForEach(store.protocolStacks()) { stack in
                        LabeledContent(stack.name, value: "\(stack.medicationCount) meds")
                    }
                }

                Section("Monthly Usage Estimate") {
                    ForEach(store.medications.filter(\.isActive)) { medication in
                        LabeledContent(medication.name, value: "\(monthlyDoseCount(for: medication)) doses")
                    }
                    LabeledContent("Total scheduled doses", value: "\(store.medications.filter(\.isActive).reduce(0) { $0 + monthlyDoseCount(for: $1) })")
                }

                Section("Cost") {
                    ForEach(costedMedications) { medication in
                        LabeledContent(
                            medication.name,
                            value: monthlyCost(for: medication).formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
                        )
                    }

                    LabeledContent(
                        "Estimated monthly cost",
                        value: totalMonthlyCost.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
                    )

                    if costedMedications.isEmpty {
                        Text("Turn on Track Cost and enter a per-dose cost in the protocol editor's Inventory step to estimate spend.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var costedMedications: [Medication] {
        store.medications.filter { $0.isActive && $0.costPerDose != nil }
    }

    private var totalMonthlyCost: Double {
        store.estimatedMonthlyCost
    }

    private func monthlyCost(for medication: Medication) -> Double {
        store.estimatedMonthlyCost(for: medication)
    }

    private func monthlyDoseCount(for medication: Medication) -> Int {
        store.monthlyDoseCount(for: medication)
    }
}
