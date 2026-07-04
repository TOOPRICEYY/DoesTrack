import Charts
import SwiftUI

private let pkBackground = Color.appBackground
private let pkBlue = Color.appBlue

struct PKModelView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMedicationID: UUID?

    private var profiles: [PKMedicationProfile] {
        PKModeler.profiles(in: store)
    }

    private var unsupportedMedications: [Medication] {
        PKModeler.unsupportedActiveMedications(in: store)
    }

    private var selectedProfile: PKMedicationProfile? {
        if let selectedMedicationID,
           let profile = profiles.first(where: { $0.id == selectedMedicationID }) {
            return profile
        }

        return profiles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if profiles.isEmpty {
                        ContentUnavailableView(
                            "No supported PK model",
                            systemImage: "function",
                            description: Text("Add Testosterone Cypionate, hCG, Tirzepatide, or BPC-157 to an active protocol to see a cited relative exposure curve.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        medicationSelector

                        if let selectedProfile {
                            profileChart(selectedProfile)
                            metrics(for: selectedProfile)
                            modelNotes(for: selectedProfile)
                            recentEvents(for: selectedProfile)
                            citations(for: selectedProfile)
                        }
                    }

                    if !unsupportedMedications.isEmpty {
                        unsupportedCard
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(pkBackground.ignoresSafeArea())
            .navigationTitle("PK Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        PKCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Relative exposure", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(pkBlue)

                Text("First-order elimination model based on scheduled doses, recorded taken doses, and cited default parameters. This is not a serum level, dosing recommendation, or substitute for labs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var medicationSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(profiles) { profile in
                    let isSelected = selectedProfile?.id == profile.id
                    Button {
                        selectedMedicationID = profile.id
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.medication.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Text(profile.parameters.drugName)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.86) : .secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 150, alignment: .leading)
                        .background(isSelected ? pkBlue : .white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? pkBlue : .black.opacity(0.10))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func profileChart(_ profile: PKMedicationProfile) -> some View {
        PKCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.medication.name)
                        .font(.title3.bold())
                    Text("\(profile.windowStart.formatted(date: .abbreviated, time: .omitted)) - \(profile.windowEnd.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(profile.points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Relative exposure", point.value)
                        )
                        .foregroundStyle(pkBlue.opacity(0.18))

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Relative exposure", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(pkBlue)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }

                    RuleMark(x: .value("Today", Date()))
                        .foregroundStyle(.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartXScale(domain: profile.windowStart...profile.windowEnd)
                .chartYAxisLabel(profile.unitLabel)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 240)
            }
        }
    }

    private func metrics(for profile: PKMedicationProfile) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            PKMetricCard(title: "Current", value: exposure(profile.currentValue, unit: profile.unitLabel))
            PKMetricCard(title: "Peak", value: exposure(profile.peakValue, unit: profile.unitLabel))
            PKMetricCard(title: "Trough", value: exposure(profile.troughValue, unit: profile.unitLabel))
            PKMetricCard(title: "Mean", value: exposure(profile.averageValue, unit: profile.unitLabel))
            PKMetricCard(title: "Half-life", value: halfLife(profile.parameters.halfLifeDays))
            PKMetricCard(title: "Scale", value: percent(profile.parameters.availabilityMultiplier))
        }
    }

    private func modelNotes(for profile: PKMedicationProfile) -> some View {
        PKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Model Basis")
                    .font(.headline)
                Text(profile.parameters.parameterSummary)
                    .font(.subheadline.bold())
                Text(profile.parameters.modelNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(profile.parameters.route, systemImage: "syringe")
                    .font(.caption.bold())
                    .foregroundStyle(pkBlue)
            }
        }
    }

    private func recentEvents(for profile: PKMedicationProfile) -> some View {
        PKCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dose Events")
                    .font(.headline)

                ForEach(Array(profile.events.suffix(8).reversed())) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.subheadline.bold())
                            Text("Included in the curve")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(exposure(event.amount, unit: profile.medication.unit.isEmpty ? "units" : profile.medication.unit))
                            .font(.subheadline.bold())
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }

    private func citations(for profile: PKMedicationProfile) -> some View {
        PKCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Citations")
                    .font(.headline)

                ForEach(profile.parameters.citations) { citation in
                    VStack(alignment: .leading, spacing: 6) {
                        if let url = URL(string: citation.url) {
                            Link(destination: url) {
                                Label(citation.title, systemImage: "link")
                                    .font(.subheadline.bold())
                            }
                        } else {
                            Text(citation.title)
                                .font(.subheadline.bold())
                        }

                        Text(citation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var unsupportedCard: some View {
        PKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Not modelled")
                    .font(.headline)
                Text("No cited default PK parameter set is bundled for these active medications yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(unsupportedMedications.prefix(6)) { medication in
                    HStack {
                        Circle()
                            .fill(Color(hex: medication.colorHex))
                            .frame(width: 8, height: 8)
                        Text(medication.name)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
    }

    private func exposure(_ value: Double, unit: String) -> String {
        "\(number(value)) \(unit)"
    }

    private func number(_ value: Double) -> String {
        if value >= 100 {
            return value.formatted(.number.precision(.fractionLength(0)))
        }

        return value.formatted(.number.precision(.fractionLength(1)))
    }

    private func halfLife(_ days: Double) -> String {
        let hours = days * 24
        if hours < 1 {
            let minutes = hours * 60
            return "\(number(minutes)) min"
        }

        if hours < 48 {
            return "\(number(hours)) hr"
        }

        return "\(number(days)) d"
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct PKCard<Content: View>: View {
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

private struct PKMetricCard: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.black.opacity(0.08))
        }
    }
}
