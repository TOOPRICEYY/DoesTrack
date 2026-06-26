import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: DoseStore

    private var sevenDayRate: Double {
        store.adherenceRate(days: 7)
    }

    private var thirtyDayRate: Double {
        store.adherenceRate(days: 30)
    }

    private var rows: [AdherenceRow] {
        store.adherenceRows(days: 7)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(
                            title: "7-day adherence",
                            value: sevenDayRate.formatted(.percent.precision(.fractionLength(0))),
                            systemImage: "checkmark.seal.fill",
                            tint: .green
                        )

                        MetricTile(
                            title: "30-day adherence",
                            value: thirtyDayRate.formatted(.percent.precision(.fractionLength(0))),
                            systemImage: "calendar.badge.checkmark",
                            tint: .blue
                        )

                        MetricTile(
                            title: "Current streak",
                            value: "\(store.currentStreak()) days",
                            systemImage: "flame.fill",
                            tint: .orange
                        )

                        MetricTile(
                            title: "Refill alerts",
                            value: "\(store.inventoryWarnings().count)",
                            systemImage: "shippingbox.fill",
                            tint: .red
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Last 7 Days")
                            .font(.headline)

                        Chart(rows) { row in
                            BarMark(
                                x: .value("Day", row.label),
                                y: .value("Adherence", row.rate * 100)
                            )
                            .foregroundStyle(row.rate >= 0.8 ? Color.green : Color.orange)
                            .annotation(position: .top) {
                                if row.scheduled > 0 {
                                    Text("\(Int(row.rate * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 220)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.quaternary)
                    }

                    refillSection
                    recentActivitySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }

    @ViewBuilder
    private var refillSection: some View {
        let warnings = store.inventoryWarnings()
        VStack(alignment: .leading, spacing: 10) {
            Text("Refill Watch")
                .font(.headline)

            if warnings.isEmpty {
                Text("No refill alerts right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(warnings) { medication in
                    HStack {
                        MedicationSwatch(colorHex: medication.colorHex)
                        VStack(alignment: .leading) {
                            Text(medication.name)
                                .font(.subheadline.weight(.semibold))
                            Text("Remaining: \(medication.inventory.currentQuantity, specifier: "%.0f") \(medication.inventory.unitLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Logs")
                .font(.headline)

            let recent = Array(store.logs.prefix(5))
            if recent.isEmpty {
                Text("No doses have been logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(recent) { log in
                    HStack {
                        Image(systemName: log.status.systemImage)
                            .foregroundStyle(log.status.tint)
                        VStack(alignment: .leading) {
                            Text(store.medication(for: log.medicationID)?.name ?? "Deleted medication")
                                .font(.subheadline.weight(.semibold))
                            Text(log.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(log.status.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(log.status.tint)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
