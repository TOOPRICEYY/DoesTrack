import SwiftUI

struct ModelHomeView: View {
    @EnvironmentObject private var store: DoseStore
    @AppStorage(HomeCardLayoutStore.storageKey) private var homeCardLayoutRaw = ""
    @State private var selectedDate = Date()
    @State private var showsProtocolEditor = false
    @State private var showsCalendar = false
    @State private var showsNotifications = false
    @State private var showsCustomize = false
    @State private var showsStacks = false
    @State private var selectedTemplate: ProtocolTemplate?
    @State private var loggingDose: ScheduledDose?
    @State private var pauseMedication: Medication?
    @State private var showsUnscheduledLog = false
    @State private var activeCardSheet: HomeCardSheet?

    enum HomeCardSheet: String, Identifiable {
        case supplements
        case labs
        case cycle
        case recon
        case converter
        case expenses

        var id: String { rawValue }
    }

    private var stacks: [ProtocolStack] {
        store.protocolStacks(includeInactive: false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    DateStripView(selectedDate: $selectedDate)

                    if store.showsSyncStaleWarning {
                        SyncStaleBanner {
                            store.dismissSyncStaleWarning()
                        }
                    }

                    if stacks.isEmpty {
                        emptyStart
                    } else {
                        configuredHome
                    }

                    suggestedSection
                }
                .padding(.horizontal)
                .padding(.bottom, 110)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showsProtocolEditor) {
                ProtocolEditorView()
                    .environmentObject(store)
            }
            .sheet(item: $selectedTemplate) { template in
                ProtocolEditorView(template: template)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsCalendar) {
                CalendarShotsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsNotifications) {
                NotificationsCenterView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsCustomize) {
                CustomizeHomeView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsStacks) {
                ProtocolStacksView()
                    .environmentObject(store)
            }
            .sheet(item: $loggingDose) { dose in
                LogDoseSheet(scheduledDose: dose)
                    .environmentObject(store)
            }
            .sheet(item: $pauseMedication) { medication in
                PauseMedicationSheet(medication: medication)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsUnscheduledLog) {
                LogDoseSheet(unscheduledOn: selectedDate)
                    .environmentObject(store)
            }
            .sheet(item: $activeCardSheet) { sheet in
                Group {
                    switch sheet {
                    case .supplements:
                        SupplementsView()
                    case .labs:
                        LabsView()
                    case .cycle:
                        CycleEditorView()
                    case .recon:
                        ReconPlannerView()
                    case .converter:
                        UnitConverterView()
                    case .expenses:
                        ExpensesView()
                    }
                }
                .environmentObject(store)
            }
        }
    }

    private func handleCardTap(_ action: HomeCardID.TapAction) {
        switch action {
        case .none:
            break
        case .addHydration:
            store.addHydration()
        case .openSupplements:
            activeCardSheet = .supplements
        case .openLabs:
            activeCardSheet = .labs
        case .openCycle:
            activeCardSheet = .cycle
        case .openRecon:
            activeCardSheet = .recon
        case .openConverter:
            activeCardSheet = .converter
        case .openExpenses:
            activeCardSheet = .expenses
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(greeting)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showsCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Open calendar")

            Button {
                showsNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    let attentionCount = store.notificationAttentionCount()
                    if attentionCount > 0 {
                        Text("\(attentionCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.red, in: Circle())
                            .offset(x: 10, y: -10)
                    }
                }
            }
            .accessibilityLabel("Open notifications")
        }
        .padding(.top, 26)
    }

    private var emptyStart: some View {
        VStack(spacing: 18) {
            Image(systemName: "syringe.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.appBlue)
                .frame(width: 84, height: 84)
                .background(Color.appBlue.opacity(0.16), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("Your journey starts here")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Add your first protocol to start tracking")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                showsProtocolEditor = true
            } label: {
                Label("Add Protocol", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appBlue)
            .controlSize(.large)
            .padding(.horizontal, 54)

            DividerWithText(text: "or")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var configuredHome: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !scheduledDosesForSelectedDate.isEmpty {
                HomeScheduledDoseSection(
                    date: selectedDate,
                    doses: scheduledDosesForSelectedDate,
                    onLogDose: { loggingDose = $0 },
                    onMedicationActions: { pauseMedication = $0 }
                )
            } else {
                stackSummarySection
            }

            Button {
                showsUnscheduledLog = true
            } label: {
                Label("Log unscheduled dose", systemImage: "plus.circle")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.appBlue.opacity(0.4))
                    }
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.appBlue)
            .accessibilityLabel("Log unscheduled dose")

            SectionHeader(title: "FOR YOU")

            pinnedHomeCardsSection

            Button {
                showsCustomize = true
            } label: {
                Label("Customize home", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .overlay {
                        Capsule().stroke(.black.opacity(0.18))
                    }
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
        }
    }

    private var stackSummarySection: some View {
        VStack(spacing: 12) {
            ForEach(stacks.prefix(2)) { stack in
                StackSuggestionRow(title: stack.name, subtitle: stack.subtitle.isEmpty ? "\(stack.medicationCount) medications" : stack.subtitle, tag: "STACK") {
                    showsStacks = true
                }
            }

            Button {
                showsProtocolEditor = true
            } label: {
                Label("Explore all protocols", systemImage: "safari")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.appBlue)
            .padding(.vertical, 14)
        }
    }

    private var scheduledDosesForSelectedDate: [ScheduledDose] {
        store.scheduledDoses(on: selectedDate)
    }

    private var pinnedHomeCardsSection: some View {
        HomeCardsGrid(
            configs: HomeCardLayoutStore.decode(homeCardLayoutRaw),
            onTap: handleCardTap
        )
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggested for you", systemImage: "hourglass")
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .symbolRenderingMode(.hierarchical)

            Text("Based on your health & wellness goal")
                .foregroundStyle(.secondary)

            ForEach(ProtocolTemplate.suggested.prefix(2)) { template in
                StackSuggestionRow(title: template.name, subtitle: template.subtitle, tag: "STACK") {
                    selectedTemplate = template
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<18: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
}

private struct SyncStaleBanner: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Backup out of date")
                    .font(.headline)
                Text("GitHub sync hasn't run in over a week. Sync from Profile > App Settings > Data Management, or turn on Auto Sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss sync warning")
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.orange.opacity(0.4))
        }
    }
}

struct DateStripView: View {
    @EnvironmentObject private var store: DoseStore
    @Binding var selectedDate: Date
    private let offsets = Array(-30...60)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(offsets, id: \.self) { offset in
                        let date = Date().startOfDay.addingDays(offset)
                        Button {
                            selectedDate = date
                        } label: {
                            let doses = store.scheduledDoses(on: date)
                            let hasMissed = doses.contains { $0.effectiveStatus == .missed }
                            let isSelected = selectedDate.isSameDay(as: date)

                            VStack(spacing: 8) {
                                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(date.formatted(.dateTime.day()))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(isSelected ? Color.appBlue : .white, in: Circle())
                                    .overlay {
                                        if hasMissed && !isSelected {
                                            Circle().stroke(.red.opacity(0.75), lineWidth: 2.5)
                                        }
                                    }
                                Circle()
                                    .fill(doses.isEmpty ? .clear : Color.appBlue)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 50)
                        .id(offset)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            }
            .accessibilityIdentifier("HomeDateStrip")
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(offset(for: selectedDate), anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                let newOffset = offset(for: newDate)
                guard offsets.contains(newOffset) else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(newOffset, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func offset(for date: Date) -> Int {
        Calendar.doseTrackCalendar.dateComponents(
            [.day],
            from: Date().startOfDay,
            to: date.startOfDay
        ).day ?? 0
    }
}
