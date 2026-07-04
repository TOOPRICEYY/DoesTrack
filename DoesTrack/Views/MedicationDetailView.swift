import Charts
import SwiftUI

/// Time-series detail for one medication: dose totals bucketed by day, week,
/// or month, or the estimated PK curve, on a horizontally scrollable chart.
struct MedicationDetailView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss

    var medication: Medication

    private enum GraphMode: String, CaseIterable, Identifiable {
        case doses = "Dose Totals"
        case pk = "Estimated PK"

        var id: String { rawValue }
    }

    private enum Bucket: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var id: String { rawValue }

        var component: Calendar.Component {
            switch self {
            case .daily: return .day
            case .weekly: return .weekOfYear
            case .monthly: return .month
            }
        }

        var chartUnit: Calendar.Component {
            switch self {
            case .daily: return .day
            case .weekly: return .weekOfYear
            case .monthly: return .month
            }
        }

        /// Length of the visible window when scrolled, in seconds.
        var visibleDomainSeconds: TimeInterval {
            switch self {
            case .daily: return 14 * 86_400
            case .weekly: return 12 * 7 * 86_400
            case .monthly: return 365 * 86_400
            }
        }
    }

    @State private var mode: GraphMode = .doses
    @State private var bucket: Bucket = .daily
    @State private var editingLog: DoseLog?

    private var supportsPK: Bool {
        PKParameterLibrary.parameterSet(for: medication) != nil
    }

    private var takenLogs: [DoseLog] {
        store.logs
            .filter { $0.medicationID == medication.id && $0.status == .taken }
            .sorted { ($0.takenAt ?? $0.scheduledAt) < ($1.takenAt ?? $1.scheduledAt) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if supportsPK {
                        Picker("Graph", selection: $mode) {
                            ForEach(GraphMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    switch mode {
                    case .doses:
                        dosesSection
                    case .pk:
                        pkSection
                    }

                    recentLogsSection
                }
                .padding()
                .padding(.bottom, 30)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(medication.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingLog) { log in
                LogDoseSheet(editingLog: log)
                    .environmentObject(store)
            }
        }
    }

    private var header: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.title2.bold())
                Text("\(medication.displayDose) · \(medication.frequencyLabel)")
                    .foregroundStyle(.secondary)
                Text("\(takenLogs.count) dose\(takenLogs.count == 1 ? "" : "s") logged since \(firstLogDateText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var firstLogDateText: String {
        guard let first = takenLogs.first else {
            return medication.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        return (first.takenAt ?? first.scheduledAt).formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: Dose totals

    private struct DoseBucketPoint: Identifiable {
        var id: Date { date }
        var date: Date
        var total: Double
    }

    private var bucketPoints: [DoseBucketPoint] {
        let calendar = Calendar.doseTrackCalendar
        var totals: [Date: Double] = [:]

        for log in takenLogs {
            let when = log.takenAt ?? log.scheduledAt
            let bucketStart = calendar.dateInterval(of: bucket.component, for: when)?.start ?? when.startOfDay
            totals[bucketStart, default: 0] += log.amount
        }

        return totals
            .map { DoseBucketPoint(date: $0.key, total: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private var dosesSection: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Bucket", selection: $bucket) {
                    ForEach(Bucket.allCases) { bucket in
                        Text(bucket.rawValue).tag(bucket)
                    }
                }
                .pickerStyle(.segmented)

                if bucketPoints.isEmpty {
                    Text("No taken doses logged yet. Logged doses appear here bucketed per \(bucket.rawValue.lowercased()) period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 30)
                } else {
                    Chart(bucketPoints) { point in
                        BarMark(
                            x: .value("Period", point.date, unit: bucket.chartUnit),
                            y: .value("Total", point.total)
                        )
                        .foregroundStyle(Color.appBlue)
                        .cornerRadius(3)
                    }
                    .chartYAxisLabel(medication.unit.isEmpty ? "amount" : medication.unit)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: bucket.visibleDomainSeconds)
                    .chartScrollPosition(initialX: Date().addingTimeInterval(-bucket.visibleDomainSeconds * 0.85))
                    .frame(height: 240)

                    Text("Scroll horizontally for more history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Estimated PK

    private var pkProfile: PKMedicationProfile? {
        PKModeler.profile(for: medication, in: store, lookbackDays: 56, forecastDays: 28)
    }

    @ViewBuilder
    private var pkSection: some View {
        if let profile = pkProfile {
            ModelCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Relative exposure")
                        .font(.headline)

                    Chart {
                        ForEach(profile.points) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Exposure", point.value)
                            )
                            .foregroundStyle(Color.appBlue.opacity(0.18))

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Exposure", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.appBlue)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        }

                        RuleMark(x: .value("Today", Date()))
                            .foregroundStyle(.secondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartYAxisLabel(profile.unitLabel)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: 28 * 86_400)
                    .chartScrollPosition(initialX: Date().addingDays(-21))
                    .frame(height: 240)

                    Text(profile.parameters.parameterSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            ModelCard {
                Text("No scheduled or logged doses to model yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Recent logs

    private var recentLogsSection: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Doses")
                    .font(.headline)

                let recent = Array(takenLogs.suffix(10).reversed())
                if recent.isEmpty {
                    Text("Nothing logged yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recent) { log in
                        Button {
                            editingLog = log
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text((log.takenAt ?? log.scheduledAt).formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if let site = log.site {
                                        Text(site)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(log.amount.formatted(.number.precision(.fractionLength(0...2)))) \(medication.unit)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit dose from \((log.takenAt ?? log.scheduledAt).formatted(date: .abbreviated, time: .omitted))")
                        Divider()
                    }
                }
            }
        }
    }
}
