import Charts
import SwiftUI

// MARK: - Chat thread

struct ChatThreadView: View {
    var messages: [ChatMessage]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(messages) { message in
                ChatBubble(message: message)
            }
        }
    }
}

private struct ChatBubble: View {
    var message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let title = message.title, !title.isEmpty {
                    Label(title, systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Color.appBlue)
                }

                Text(message.text)
                    .font(.subheadline)

                ForEach(message.bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(12)
            .background(
                message.role == .user ? Color.appBlue.opacity(0.14) : .white,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(message.role == .user ? Color.appBlue.opacity(0.30) : .primary.opacity(0.08))
            }

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }
}

// MARK: - Fortnightly review

struct FortnightlyReviewView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    adherenceCard
                    dosesCard
                    checkInCard
                    bodyCard
                    labsCard
                    recommendationsCard

                    Text("Generated on-device from your tracked data. Not medical advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Fortnightly Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Data

    private var currentAdherence: Double { store.adherenceRate(days: 14) }
    private var previousAdherence: Double { store.adherenceRate(days: 14, endingAt: Date().addingDays(-14)) }
    private var adherenceDelta: Double { currentAdherence - previousAdherence }

    private var rows: [AdherenceRow] { store.adherenceRows(days: 14) }
    private var takenCount: Int { rows.reduce(0) { $0 + $1.taken } }
    private var scheduledCount: Int { rows.reduce(0) { $0 + $1.scheduled } }

    private var recentCheckIns: [SymptomCheckIn] {
        store.symptomCheckIns.filter { $0.createdAt >= Date().addingDays(-14) }
    }

    private var averageCheckInRating: Double? {
        let ratings = recentCheckIns.compactMap(\.averageRating)
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your last 14 days")
                .font(.title2.bold())
            Text("\(Date().addingDays(-13).formatted(date: .abbreviated, time: .omitted)) – \(Date().formatted(date: .abbreviated, time: .omitted))")
                .foregroundStyle(.secondary)
        }
    }

    private var adherenceCard: some View {
        reviewCard("Adherence", systemImage: "chart.line.uptrend.xyaxis") {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(currentAdherence.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 42, weight: .bold))
                Text("\(adherenceDelta >= 0 ? "+" : "")\(adherenceDelta.formatted(.percent.precision(.fractionLength(0)))) vs prior 14 days")
                    .font(.subheadline)
                    .foregroundStyle(adherenceDelta >= 0 ? .green : .orange)
            }

            Chart(rows) { row in
                BarMark(
                    x: .value("Day", row.date, unit: .day),
                    y: .value("Rate", row.rate)
                )
                .foregroundStyle(Color.appBlue)
            }
            .chartYScale(domain: 0...1)
            .frame(height: 120)
        }
    }

    private var dosesCard: some View {
        reviewCard("Doses", systemImage: "pills.fill") {
            LabeledContent("Taken", value: "\(takenCount) of \(scheduledCount) scheduled")
            LabeledContent("Streak", value: "\(store.currentStreak() / 7) weeks")
            if !store.inventoryWarnings().isEmpty {
                LabeledContent("Refill needed") {
                    Text(store.inventoryWarnings().prefix(2).map(\.name).joined(separator: ", "))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var checkInCard: some View {
        reviewCard("Check-Ins", systemImage: "heart.text.square") {
            if recentCheckIns.isEmpty {
                Text("No weekly check-ins in this window. A quick check-in keeps symptom trends meaningful.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Completed", value: "\(recentCheckIns.count)")
                if let averageCheckInRating {
                    LabeledContent("Average rating", value: "\(averageCheckInRating.formatted(.number.precision(.fractionLength(1)))) / 5")
                }
            }
        }
    }

    private var bodyCard: some View {
        reviewCard("Body", systemImage: "scalemass.fill") {
            LabeledContent("Weight", value: store.healthMetrics.weightValueText)
            LabeledContent("Trend", value: store.healthMetrics.weightTrendText)
            LabeledContent("Resting HR", value: store.healthMetrics.restingHeartRateText)
            LabeledContent("Sleep", value: store.healthMetrics.sleepText)
        }
    }

    private var labsCard: some View {
        reviewCard("Labs", systemImage: "testtube.2") {
            if store.labResults.isEmpty {
                Text("No lab results tracked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Results tracked", value: "\(store.labResults.count)")
                LabeledContent("Out of range") {
                    Text("\(store.outOfRangeMarkers.count)")
                        .foregroundStyle(store.outOfRangeMarkers.isEmpty ? .green : .red)
                }
            }
        }
    }

    private var recommendationsCard: some View {
        reviewCard("Recommendations", systemImage: "lightbulb.fill") {
            ForEach(recommendations, id: \.self) { recommendation in
                Label(recommendation, systemImage: "arrow.right.circle")
                    .font(.subheadline)
            }
        }
    }

    private var recommendations: [String] {
        var output: [String] = []

        if scheduledCount == 0 {
            output.append("No doses were scheduled in this window. Add or resume a protocol to start tracking.")
        } else if currentAdherence < 0.8 {
            output.append("Adherence is under 80%. Consider enabling reminders or moving dose times to fit your routine.")
        }

        if adherenceDelta < -0.05, scheduledCount > 0 {
            output.append("Adherence dropped versus the prior two weeks. Review skipped-dose reasons in History.")
        }

        if !store.inventoryWarnings().isEmpty {
            output.append("Inventory is low for \(store.inventoryWarnings().prefix(2).map(\.name).joined(separator: " and ")). Plan a refill.")
        }

        if store.isWeeklyCheckInDue {
            output.append("Your weekly check-in is due. It takes under a minute from Notifications > Reminders.")
        }

        if store.labResults.isEmpty {
            output.append("Add lab results to unlock biomarker trends and out-of-range tracking.")
        } else if !store.outOfRangeMarkers.isEmpty {
            output.append("\(store.outOfRangeMarkers.count) marker\(store.outOfRangeMarkers.count == 1 ? " is" : "s are") outside its reference range — worth discussing with your clinician.")
        }

        if output.isEmpty {
            output.append("On track: adherence is holding and nothing needs attention. Keep the streak going.")
        }

        return output
    }

    private func reviewCard(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.appBlue)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.08))
        }
    }
}
