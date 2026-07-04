import Charts
import SwiftUI

private let pulseBackground = Color.appBackground
private let pulseBlue = Color.appBlue

enum PulseSheet: Identifiable {
    case insight(PulseInsightKind)
    case question(PulseQuestionTopic)
    case stacks

    var id: String {
        switch self {
        case .insight(let kind): return "insight-\(kind.rawValue)"
        case .question(let topic): return "question-\(topic.rawValue)"
        case .stacks: return "stacks"
        }
    }
}

enum PulseInsightKind: String, Identifiable {
    case symptoms
    case doseHistory
    case riskFactors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .symptoms: return "Symptoms"
        case .doseHistory: return "Dose History"
        case .riskFactors: return "Risk Factors"
        }
    }
}

enum PulseQuestionTopic: String, Identifiable {
    case doseMechanics
    case timingAbsorption
    case sideEffects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doseMechanics: return "How does my dose work?"
        case .timingAbsorption: return "Timing & Absorption"
        case .sideEffects: return "Side Effect Management"
        }
    }
}

struct PulseAssistantReply: Identifiable {
    var id = UUID()
    var prompt: String
    var title: String
    var body: String
    var bullets: [String]

    @MainActor
    static func make(prompt: String, store: DoseStore) -> PulseAssistantReply {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let activeStacks = store.protocolStacks(includeInactive: false)
        let nextDose = store.nextScheduledDose()
        let adherence = store.adherenceRate(days: 14).formatted(.percent.precision(.fractionLength(0)))

        if lowercased.contains("risk") || lowercased.contains("miss") {
            let missed = store.adherenceRows(days: 14).reduce(0) { $0 + max(0, $1.scheduled - $1.taken) }
            return PulseAssistantReply(
                prompt: trimmed,
                title: "Tracking Risk Summary",
                body: "DoesTrack found \(missed) scheduled dose gaps in the last 14 days and \(store.inventoryWarnings().count) inventory warning\(store.inventoryWarnings().count == 1 ? "" : "s").",
                bullets: riskBullets(store: store)
            )
        }

        if lowercased.contains("next") || lowercased.contains("today") || lowercased.contains("schedule") {
            return PulseAssistantReply(
                prompt: trimmed,
                title: "Schedule Summary",
                body: nextDose.map { "Next scheduled dose is \($0.medication.name) at \($0.scheduledAt.formatted(date: .abbreviated, time: .shortened))." } ?? "No upcoming scheduled dose is currently active.",
                bullets: activeStacks.prefix(3).map { "\($0.name): \($0.medicationCount) medication\($0.medicationCount == 1 ? "" : "s")" }
            )
        }

        if lowercased.contains("pk") || lowercased.contains("clear") || lowercased.contains("half") {
            let supported = PKModeler.profiles(in: store).map { "\($0.medication.name): \($0.parameters.parameterSummary)" }
            return PulseAssistantReply(
                prompt: trimmed,
                title: "PK Model Availability",
                body: supported.isEmpty ? "No active medications match a bundled PK parameter set." : "PK modelling is available for \(supported.count) active medication\(supported.count == 1 ? "" : "s").",
                bullets: supported.isEmpty ? ["Supported defaults: Testosterone Cypionate, hCG, Tirzepatide, and BPC-157."] : supported
            )
        }

        return PulseAssistantReply(
            prompt: trimmed,
            title: "Protocol Snapshot",
            body: "You have \(activeStacks.count) active stack\(activeStacks.count == 1 ? "" : "s") with \(adherence) 14-day adherence.",
            bullets: [
                nextDose.map { "Next dose: \($0.medication.name), \($0.scheduledAt.formatted(date: .abbreviated, time: .shortened))" } ?? "No upcoming dose scheduled.",
                "Current streak: \(store.currentStreak()) day\(store.currentStreak() == 1 ? "" : "s").",
                "Protocol score: \(store.protocolScore())."
            ]
        )
    }

    @MainActor
    private static func riskBullets(store: DoseStore) -> [String] {
        var bullets: [String] = []
        let warnings = store.inventoryWarnings()
        if warnings.isEmpty {
            bullets.append("No low-inventory warnings for tracked medications.")
        } else {
            bullets.append("Low inventory: \(warnings.prefix(3).map(\.name).joined(separator: ", ")).")
        }

        let unsupportedPK = PKModeler.unsupportedActiveMedications(in: store)
        if !unsupportedPK.isEmpty {
            bullets.append("No bundled PK defaults for: \(unsupportedPK.prefix(3).map(\.name).joined(separator: ", ")).")
        }

        let today = store.scheduledDoses(on: Date())
        bullets.append("Today: \(today.filter { $0.log?.status == .taken }.count) of \(today.count) scheduled doses logged.")
        return bullets
    }
}

struct PulseInsightDetailView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    var kind: PulseInsightKind

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch kind {
                    case .symptoms:
                        symptomsContent
                    case .doseHistory:
                        doseHistoryContent
                    case .riskFactors:
                        riskFactorsContent
                    }
                }
                .padding()
            }
            .background(pulseBackground.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var symptomsContent: some View {
        let notes = store.logs.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let checkIns = store.symptomCheckIns
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                summaryCard(title: "Check-Ins", value: "\(checkIns.count)", subtitle: "weekly symptom ratings")
                summaryCard(title: "Dose Notes", value: "\(notes.count)", subtitle: "with symptom context")
            }

            if !checkIns.isEmpty {
                PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Check-Ins")
                            .font(.headline)
                        ForEach(checkIns.prefix(4)) { checkIn in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(checkIn.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.semibold))
                                    if !checkIn.notes.isEmpty {
                                        Text(checkIn.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Text(checkIn.averageRating.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "-")
                                    .font(.title3.bold())
                                    .foregroundStyle(pulseBlue)
                            }
                            if checkIn.id != checkIns.prefix(4).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            if notes.isEmpty && checkIns.isEmpty {
                emptyPulseCard("No symptom data found", "Check-ins and dose notes will appear here after you log context.")
            } else {
                ForEach(notes.prefix(12)) { log in
                    PulseCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.medication(for: log.medicationID)?.name ?? "Medication")
                                .font(.headline)
                            Text(log.notes)
                            Text(log.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var doseHistoryContent: some View {
        let rows = store.adherenceRows(days: 14)
        let scheduled = rows.reduce(0) { $0 + $1.scheduled }
        let taken = rows.reduce(0) { $0 + $1.taken }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                summaryCard(title: "Taken", value: "\(taken)", subtitle: "last 14 days")
                summaryCard(title: "Scheduled", value: "\(scheduled)", subtitle: "last 14 days")
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Adherence Trend")
                        .font(.headline)
                    Chart(rows) { row in
                        BarMark(
                            x: .value("Day", row.label),
                            y: .value("Rate", row.rate)
                        )
                        .foregroundStyle(pulseBlue)
                    }
                    .chartYScale(domain: 0...1)
                    .frame(height: 220)
                }
            }
        }
    }

    private var riskFactorsContent: some View {
        let rows = store.adherenceRows(days: 7)
        let missed = rows.reduce(0) { $0 + max(0, $1.scheduled - $1.taken) }
        let inventory = store.inventoryWarnings()
        let inactive = store.medications.filter { !$0.isActive }
        let unsupportedPK = PKModeler.unsupportedActiveMedications(in: store)

        return VStack(alignment: .leading, spacing: 12) {
            riskRow(title: "Missed or unlogged doses", value: "\(missed)", status: missed == 0 ? .green : .orange)
            riskRow(title: "Low inventory warnings", value: "\(inventory.count)", status: inventory.isEmpty ? .green : .orange)
            riskRow(title: "Paused medications", value: "\(inactive.count)", status: inactive.isEmpty ? .green : .secondary)
            riskRow(title: "Unsupported PK models", value: "\(unsupportedPK.count)", status: unsupportedPK.isEmpty ? .green : .secondary)
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func emptyPulseCard(_ title: String, _ subtitle: String) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "tray")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func riskRow(title: String, value: String, status: Color) -> some View {
        PulseCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(riskSubtitle(for: title))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .font(.title.bold())
                    .foregroundStyle(status)
            }
        }
    }

    private func riskSubtitle(for title: String) -> String {
        switch title {
        case "Missed or unlogged doses": return "last 7 days"
        case "Low inventory warnings": return "tracked inventory"
        case "Paused medications": return "inactive protocol items"
        default: return "active medications"
        }
    }
}

struct ProtocolQuestionDetailView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    var topic: PulseQuestionTopic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(topic.title)
                                .font(.title2.bold())
                            Text("This view summarizes your tracked protocol data. It is not medical advice, dosing guidance, or a replacement for clinician review.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    switch topic {
                    case .doseMechanics:
                        doseMechanics
                    case .timingAbsorption:
                        timingAbsorption
                    case .sideEffects:
                        sideEffects
                    }
                }
                .padding()
            }
            .background(pulseBackground.ignoresSafeArea())
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var doseMechanics: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.medications.filter(\.isActive).prefix(8)) { medication in
                PulseCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(medication.name)
                            .font(.headline)
                        Text("\(medication.displayDose) · \(medication.instructions)")
                            .foregroundStyle(.secondary)
                        if let parameters = PKParameterLibrary.parameterSet(for: medication) {
                            Text(parameters.parameterSummary)
                                .font(.caption)
                                .foregroundStyle(pulseBlue)
                        }
                    }
                }
            }
        }
    }

    private var timingAbsorption: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let next = store.nextScheduledDose() {
                PulseCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Scheduled Dose")
                            .font(.headline)
                        Text(next.medication.name)
                            .font(.title3.bold())
                        Text(next.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(store.protocolStacks(includeInactive: false).prefix(4)) { stack in
                PulseCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stack.name)
                            .font(.headline)
                        ForEach(stack.medications.prefix(4)) { medication in
                            Text("\(medication.name): \(medication.schedules.first?.timeLabel ?? "-")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var sideEffects: some View {
        let notes = store.logs.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return VStack(alignment: .leading, spacing: 12) {
            PulseCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Context Notes")
                        .font(.headline)
                    Text(notes.isEmpty ? "No dose notes are currently logged." : "\(notes.count) dose note\(notes.count == 1 ? "" : "s") available for review.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(notes.prefix(6)) { log in
                PulseCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.medication(for: log.medicationID)?.name ?? "Medication")
                            .font(.headline)
                        Text(log.notes)
                        Text(log.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct PulseCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.black.opacity(0.08))
            }
    }
}
