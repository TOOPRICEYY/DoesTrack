import SwiftUI

// MARK: - Card identity

enum HomeCardID: String, Codable, CaseIterable, Identifiable {
    case nextDose = "Next Dose"
    case streak = "Streak"
    case weeklyCompliance = "Weekly Compliance"
    case todayDoses = "Today Doses"
    case lastDose = "Last Dose"
    case todayShots = "Today Shots"
    case todaySupps = "Today's Supps"
    case suppsLog = "Supps Log"
    case benefitCoverage = "Benefit Coverage"
    case hydration = "Hydration"
    case lastSite = "Last Site"
    case siteRotation = "Site Rotation"
    case protocols = "Protocols"
    case cycle = "Cycle"
    case weightTrend = "Weight Trend"
    case latestWeight = "Latest Weight"
    case sleep = "Sleep"
    case restingHR = "Resting HR"
    case bloodPressure = "Blood Pressure"
    case latestLabs = "Latest Labs"
    case outOfRange = "Out of Range"
    case biomarkerTrend = "Biomarker Trend"
    case recon = "Recon"
    case unitConverter = "Unit Converter"
    case costCalculator = "Cost Calculator"

    var id: String { rawValue }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .nextDose: return "bell.fill"
        case .streak: return "flame.fill"
        case .weeklyCompliance: return "chart.line.uptrend.xyaxis"
        case .todayDoses: return "pills.fill"
        case .lastDose: return "clock.fill"
        case .todayShots: return "syringe.fill"
        case .todaySupps: return "leaf.fill"
        case .suppsLog: return "checklist"
        case .benefitCoverage: return "heart.fill"
        case .hydration: return "drop.fill"
        case .lastSite: return "mappin.circle.fill"
        case .siteRotation: return "location.fill"
        case .protocols: return "square.stack.3d.up.fill"
        case .cycle: return "arrow.triangle.2.circlepath"
        case .weightTrend: return "scalemass.fill"
        case .latestWeight: return "scalemass"
        case .sleep: return "bed.double.fill"
        case .restingHR: return "heart.fill"
        case .bloodPressure: return "waveform.path.ecg"
        case .latestLabs: return "testtube.2"
        case .outOfRange: return "exclamationmark.triangle.fill"
        case .biomarkerTrend: return "chart.xyaxis.line"
        case .recon: return "flask.fill"
        case .unitConverter: return "ruler"
        case .costCalculator: return "dollarsign.circle"
        }
    }

    /// What tapping the card on Home does.
    enum TapAction {
        case none
        case addHydration
        case openSupplements
        case openLabs
        case openCycle
        case openRecon
        case openConverter
        case openExpenses
    }

    var tapAction: TapAction {
        switch self {
        case .hydration: return .addHydration
        case .todaySupps, .suppsLog, .benefitCoverage: return .openSupplements
        case .latestLabs, .outOfRange, .biomarkerTrend: return .openLabs
        case .cycle: return .openCycle
        case .recon: return .openRecon
        case .unitConverter: return .openConverter
        case .costCalculator: return .openExpenses
        default: return .none
        }
    }
}

enum HomeCardSize: String, Codable, CaseIterable {
    case half
    case full

    var label: String {
        switch self {
        case .half: return "Half"
        case .full: return "Full"
        }
    }
}

struct HomeCardConfig: Codable, Equatable, Identifiable {
    var card: HomeCardID
    var size: HomeCardSize
    var colorHex: String?

    var id: HomeCardID { card }

    init(card: HomeCardID, size: HomeCardSize? = nil, colorHex: String? = nil) {
        self.card = card
        self.size = size ?? Self.defaultSize(for: card)
        self.colorHex = colorHex
    }

    static func defaultSize(for card: HomeCardID) -> HomeCardSize {
        switch card {
        case .weeklyCompliance, .siteRotation, .biomarkerTrend, .recon, .suppsLog:
            return .full
        default:
            return .half
        }
    }

    var accent: Color {
        colorHex.map { Color(hex: $0) } ?? .primary
    }
}

// MARK: - Layout persistence

enum HomeCardLayoutStore {
    static let storageKey = "doseTrackHomeCardLayoutV2"
    static let legacyStorageKey = "doseTrackPinnedHomeCards"
    private static let legacyEmptySentinel = "-none-"

    static let defaultLayout: [HomeCardConfig] = [
        HomeCardConfig(card: .nextDose),
        HomeCardConfig(card: .streak),
        HomeCardConfig(card: .weeklyCompliance)
    ]

    static func decode(_ rawValue: String) -> [HomeCardConfig] {
        if rawValue.isEmpty {
            return migrateLegacy()
        }

        if rawValue == "[]" { return [] }

        guard let data = rawValue.data(using: .utf8),
              let configs = try? JSONDecoder().decode([HomeCardConfig].self, from: data)
        else {
            return defaultLayout
        }
        return configs
    }

    static func encode(_ configs: [HomeCardConfig]) -> String {
        guard let data = try? JSONEncoder().encode(configs),
              let raw = String(data: data, encoding: .utf8)
        else { return "" }
        return raw
    }

    /// Old format was pipe-separated card titles (with a "-none-" sentinel).
    private static func migrateLegacy() -> [HomeCardConfig] {
        guard let legacy = UserDefaults.standard.string(forKey: legacyStorageKey), !legacy.isEmpty else {
            return defaultLayout
        }
        if legacy == legacyEmptySentinel { return [] }

        let cards = legacy
            .split(separator: "|")
            .compactMap { HomeCardID(rawValue: String($0)) }
        return cards.isEmpty ? defaultLayout : cards.map { HomeCardConfig(card: $0) }
    }
}

// MARK: - Accent palette

enum HomeCardAccentPalette {
    /// Swatch row from the model app: none + nine hues.
    static let options: [String?] = [
        nil,
        "#0D80FF", "#AF52DE", "#FF2D92", "#FF9500", "#FFCC00",
        "#34C759", "#5AC8FA", "#FF3B30", "#5856D6"
    ]
}

// MARK: - Live values

@MainActor
extension HomeCardID {
    func value(in store: DoseStore) -> String {
        switch self {
        case .nextDose:
            guard let dose = store.nextScheduledDose() else { return "-" }
            return dose.scheduledAt.formatted(date: .omitted, time: .shortened)
        case .streak:
            return "\(store.currentStreak() / 7) wks"
        case .weeklyCompliance:
            return store.adherenceRate(days: 7).formatted(.percent.precision(.fractionLength(0)))
        case .todayDoses:
            let doses = store.scheduledDoses(on: Date())
            let taken = doses.filter { $0.log?.status == .taken }.count
            return "\(taken) / \(doses.count)"
        case .lastDose:
            guard let log = store.logs.first,
                  let medication = store.medication(for: log.medicationID)
            else { return "-" }
            return medication.name
        case .todayShots:
            let shots = store.scheduledDoses(on: Date()).filter {
                $0.medication.instructions.localizedCaseInsensitiveContains("SubQ") ||
                $0.medication.instructions.localizedCaseInsensitiveContains("IM")
            }
            let taken = shots.filter { $0.log?.status == .taken }.count
            return "\(taken) / \(shots.count)"
        case .todaySupps:
            let due = store.supplements(on: Date())
            let taken = due.filter { store.isSupplementTaken($0, on: Date()) }.count
            return "\(taken) / \(due.count)"
        case .suppsLog:
            return "\(store.supplements.filter(\.isActive).count) supps"
        case .benefitCoverage:
            guard !store.supplements.filter(\.isActive).isEmpty else { return "-" }
            return store.benefitCoverageRate.formatted(.percent.precision(.fractionLength(0)))
        case .hydration:
            let ounces = store.hydrationOunces(on: Date())
            return "\(ounces.formatted(.number.precision(.fractionLength(0)))) / \(store.hydrationGoalOunces.formatted(.number.precision(.fractionLength(0)))) oz"
        case .lastSite:
            return store.mostRecentInjectionSite ?? "-"
        case .siteRotation:
            return store.suggestedInjectionSite(from: DoseStore.defaultInjectionSites) ?? "Set up"
        case .protocols:
            return "\(store.protocolStacks(includeInactive: false).count)"
        case .cycle:
            guard let cycle = store.featuredCycle, let phase = cycle.phase(on: Date()) else { return "-" }
            return phase.isOn ? "ON" : "OFF"
        case .weightTrend:
            return store.healthMetrics.weightTrendText
        case .latestWeight:
            return store.healthMetrics.weightValueText
        case .sleep:
            return store.healthMetrics.sleepText
        case .restingHR:
            return store.healthMetrics.restingHeartRateText
        case .bloodPressure:
            return store.healthMetrics.bloodPressureText
        case .latestLabs:
            guard let date = store.latestLabDate else { return "No labs yet" }
            return date.formatted(date: .abbreviated, time: .omitted)
        case .outOfRange:
            return "\(store.outOfRangeMarkers.count)"
        case .biomarkerTrend:
            guard let marker = store.trendMarkerName,
                  let latest = store.labSeries(for: marker).last
            else { return "-" }
            return latest.valueText
        case .recon:
            guard let plan = store.activeReconPlan, let units = plan.doseUnitsU100 else { return "No active vials" }
            return "\(units.formatted(.number.precision(.fractionLength(0...1)))) U"
        case .unitConverter:
            return "Convert"
        case .costCalculator:
            return store.estimatedMonthlyCost.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        }
    }

    func subtitle(in store: DoseStore) -> String {
        switch self {
        case .nextDose:
            return store.nextScheduledDose()?.medication.name ?? "No scheduled dose"
        case .streak:
            return store.currentStreak() == 0 ? "Log a dose to start" : "full weeks logged"
        case .weeklyCompliance:
            let delta = store.weeklyComplianceDelta()
            let deltaText = delta.formatted(.percent.precision(.fractionLength(0)))
            return "\(delta >= 0 ? "+" : "")\(deltaText) vs last wk"
        case .todayDoses:
            return "scheduled today"
        case .lastDose:
            guard let log = store.logs.first else { return "No doses logged yet" }
            return log.scheduledAt.formatted(date: .abbreviated, time: .shortened)
        case .todayShots:
            return "injection schedule"
        case .todaySupps:
            return store.supplements.isEmpty ? "Tap to add supplements" : "logged today · tap to check off"
        case .suppsLog:
            let due = store.supplements(on: Date())
            let taken = due.filter { store.isSupplementTaken($0, on: Date()) }.count
            return due.isEmpty ? "No supplements due today" : "\(taken)/\(due.count) logged today"
        case .benefitCoverage:
            let covered = store.coveredBenefits.count
            return covered == 0
                ? "Add supplements to see benefits"
                : "\(covered) of \(SupplementBenefit.allCases.count) benefit areas"
        case .hydration:
            return "Tap to add \(Int(DoseStore.hydrationSipOunces)) oz"
        case .lastSite:
            guard let site = store.mostRecentInjectionSite,
                  let date = store.lastUse(ofSite: site)
            else { return "Log a dose to start" }
            return "used \(date.formatted(date: .abbreviated, time: .omitted))"
        case .siteRotation:
            return store.mostRecentInjectionSite == nil ? "log a dose to begin" : "least recently used next"
        case .protocols:
            return "\(store.medications.filter(\.isActive).count) active medications"
        case .cycle:
            guard let cycle = store.featuredCycle, let phase = cycle.phase(on: Date()) else {
                return "No cycling configured · tap to set up"
            }
            return "week \(phase.weekInPhase) of \(phase.phaseLengthWeeks) · \(cycle.stackName)"
        case .weightTrend:
            return store.healthMetrics.weightTrendSubtitleText
        case .latestWeight:
            return store.healthMetrics.weightSubtitleText
        case .sleep:
            return store.healthMetrics.sleepSubtitleText
        case .restingHR:
            return store.healthMetrics.restingHeartRateSubtitleText
        case .bloodPressure:
            return store.healthMetrics.bloodPressureSubtitleText
        case .latestLabs:
            let count = store.labResults.count
            return count == 0 ? "Add results to get started" : "\(count) result\(count == 1 ? "" : "s")"
        case .outOfRange:
            let markers = store.outOfRangeMarkers
            return markers.isEmpty ? "No markers" : markers.prefix(2).map(\.marker).joined(separator: ", ")
        case .biomarkerTrend:
            guard let marker = store.trendMarkerName else { return "Add labs to see trend" }
            return "\(marker) · \(store.labSeries(for: marker).count) points"
        case .recon:
            guard let plan = store.activeReconPlan else { return "Plan a vial mix · tap to start" }
            let doses = plan.dosesPerVial.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "-"
            return "\(plan.name) · \(doses) doses per vial"
        case .unitConverter:
            return "mg · mcg · IU"
        case .costCalculator:
            return store.estimatedMonthlyCost > 0 ? "estimated per month" : "Track costs in the protocol editor"
        }
    }
}

// MARK: - Home grid

struct HomeCardsGrid: View {
    @EnvironmentObject private var store: DoseStore
    var configs: [HomeCardConfig]
    var onTap: (HomeCardID.TapAction) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(rows[index]) { config in
                        card(for: config)
                    }
                    if rows[index].count == 1 && rows[index][0].size == .half {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    /// Full cards get their own row; half cards pack in pairs, in order.
    private var rows: [[HomeCardConfig]] {
        var output: [[HomeCardConfig]] = []
        var pending: HomeCardConfig?

        for config in configs {
            switch config.size {
            case .full:
                if let held = pending {
                    output.append([held])
                    pending = nil
                }
                output.append([config])
            case .half:
                if let held = pending {
                    output.append([held, config])
                    pending = nil
                } else {
                    pending = config
                }
            }
        }
        if let held = pending {
            output.append([held])
        }
        return output
    }

    @ViewBuilder
    private func card(for config: HomeCardConfig) -> some View {
        let action = config.card.tapAction
        let content = HomeMetricCard(
            title: config.card.title.uppercased(),
            value: config.card.value(in: store),
            subtitle: config.card.subtitle(in: store),
            systemImage: config.card.systemImage,
            accent: config.colorHex.map { Color(hex: $0) }
        )

        if case .none = action {
            content
        } else {
            Button {
                onTap(action)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel(config.card.title)
        }
    }
}

struct HomeMetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var systemImage: String?
    var accent: Color?

    var body: some View {
        ModelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(3)
                    Spacer()
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(accent.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
                    }
                }
                Text(value)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(accent ?? .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack {
                    ForEach(0..<7, id: \.self) { _ in
                        Capsule().fill((accent ?? .gray).opacity(0.35)).frame(height: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Customize home

struct CustomizeHomeView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HomeCardLayoutStore.storageKey) private var layoutRaw = ""

    private var configs: [HomeCardConfig] {
        HomeCardLayoutStore.decode(layoutRaw)
    }

    private var availableCards: [HomeCardID] {
        let pinned = Set(configs.map(\.card))
        return HomeCardID.allCases.filter { !pinned.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(configs) { config in
                        PinnedCardRow(
                            config: config,
                            value: config.card.value(in: store),
                            onSize: { size in update(config.card) { $0.size = size } },
                            onColor: { hex in update(config.card) { $0.colorHex = hex } },
                            onRemove: { remove(config.card) }
                        )
                        .listRowBackground(Color.appSurface)
                    }
                    .onMove(perform: move)
                } header: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PINNED")
                        Label("Drag the handle to reorder cards.", systemImage: "hand.draw")
                            .font(.caption)
                            .textCase(nil)
                    }
                }

                Section("AVAILABLE") {
                    ForEach(availableCards) { card in
                        HStack(spacing: 14) {
                            Image(systemName: card.systemImage)
                                .foregroundStyle(Color.appBlue)
                                .frame(width: 30)
                            Text(card.title)
                                .font(.headline)
                            Spacer()
                            Button {
                                add(card)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .accessibilityLabel("Pin \(card.title)")
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Customize home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.bold())
                    }
                    .accessibilityLabel("Close customize home")
                }
            }
        }
    }

    private func write(_ configs: [HomeCardConfig]) {
        layoutRaw = HomeCardLayoutStore.encode(configs)
    }

    private func update(_ card: HomeCardID, _ transform: (inout HomeCardConfig) -> Void) {
        var next = configs
        guard let index = next.firstIndex(where: { $0.card == card }) else { return }
        transform(&next[index])
        write(next)
    }

    private func add(_ card: HomeCardID) {
        write(configs + [HomeCardConfig(card: card)])
    }

    private func remove(_ card: HomeCardID) {
        write(configs.filter { $0.card != card })
    }

    private func move(from source: IndexSet, to destination: Int) {
        var next = configs
        next.move(fromOffsets: source, toOffset: destination)
        write(next)
    }
}

private struct PinnedCardRow: View {
    var config: HomeCardConfig
    var value: String
    var onSize: (HomeCardSize) -> Void
    var onColor: (String?) -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: config.card.systemImage)
                    .foregroundStyle(config.colorHex.map { Color(hex: $0) } ?? Color.appBlue)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.card.title)
                        .font(.headline)
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Picker("Size", selection: Binding(get: { config.size }, set: onSize)) {
                    ForEach(HomeCardSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)

                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Unpin \(config.card.title)")
            }

            HStack(spacing: 10) {
                ForEach(HomeCardAccentPalette.options, id: \.self) { hex in
                    Button {
                        onColor(hex)
                    } label: {
                        if let hex {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if config.colorHex == hex {
                                        Circle().stroke(.primary, lineWidth: 2.5).padding(-3)
                                    }
                                }
                        } else {
                            Image(systemName: "slash.circle")
                                .font(.title3)
                                .foregroundStyle(config.colorHex == nil ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(hex == nil ? "Default color" : "Accent \(hex ?? "")")
                }
            }
        }
        .padding(.vertical, 6)
    }
}
