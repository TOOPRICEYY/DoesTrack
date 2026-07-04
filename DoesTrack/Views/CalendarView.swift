import SwiftUI

struct CalendarShotsView: View {
    @EnvironmentObject private var store: DoseStore
    @Environment(\.dismiss) private var dismiss
    @State private var visibleMonth = Date()
    @State private var selectedDate = Date()
    @State private var showsEditor = false
    @State private var showsManualDose = false
    @State private var loggingDose: ScheduledDose?

    private var calendar: Calendar { .doseTrackCalendar }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title.bold())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Close calendar")

                    monthHeader
                    monthGrid
                    selectedDayCard
                    upcomingShotsSection
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showsEditor) {
                ProtocolEditorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showsManualDose) {
                ManualDoseSheet(scheduledAt: selectedDate)
                    .environmentObject(store)
            }
            .sheet(item: $loggingDose) { dose in
                LogDoseSheet(scheduledDose: dose)
                    .environmentObject(store)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.largeTitle.bold())
            Spacer()
            Button {
                visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .font(.title2.bold())
        .foregroundStyle(.primary)
    }

    private var monthGrid: some View {
        let days = monthDays()
        let marked = store.scheduledDoseDates(inMonthContaining: visibleMonth)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 20) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.subheadline)
            }

            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    let day = calendar.component(.day, from: date)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 5) {
                            Text("\(day)")
                                .font(.title3.weight(selectedDate.isSameDay(as: date) ? .bold : .regular))
                                .foregroundStyle(selectedDate.isSameDay(as: date) ? .white : .primary)
                                .frame(width: 48, height: 48)
                                .background(selectedDate.isSameDay(as: date) ? Color.appBlue : .clear, in: RoundedRectangle(cornerRadius: 10))
                            Circle()
                                .fill(marked.contains(day) ? Color.appBlue : .clear)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 60)
                }
            }
        }
    }

    private var selectedDayCard: some View {
        let doses = store.scheduledDoses(on: selectedDate)
        return ModelCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(selectedDate.formatted(date: .long, time: .omitted))
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        if store.medications.isEmpty {
                            showsEditor = true
                        } else {
                            showsManualDose = true
                        }
                    } label: {
                        Label("Add Dose", systemImage: "plus")
                    }
                    .font(.headline)
                }

                if doses.isEmpty {
                    Text("No doses on this day")
                } else {
                    VStack(spacing: 10) {
                        ForEach(doses) { dose in
                            CalendarScheduledDoseRow(dose: dose) { selectedDose in
                                loggingDose = selectedDose
                            }
                        }
                    }
                }
            }
        }
    }

    private var upcomingShotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Shots")
                .font(.largeTitle.bold())
            HStack {
                LegendDot(color: .red, text: "Overdue")
                LegendDot(color: .orange, text: "Due Today")
                LegendDot(color: .cyan, text: "Tomorrow")
                LegendDot(color: Color.appBlue, text: "Upcoming")
            }
            .font(.caption)

            ForEach(store.upcomingDoses(limit: 8)) { dose in
                UpcomingDoseCard(dose: dose)
            }
        }
    }

    private func monthDays() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        guard let start = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: start)
        else { return [] }

        let leading = calendar.component(.weekday, from: start) - 1
        return Array(repeating: nil, count: leading) + range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }
}

struct UpcomingDoseCard: View {
    var dose: ScheduledDose

    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Text(dose.scheduledAt.formatted(.dateTime.day()))
                    .font(.title.bold())
                Text(dose.scheduledAt.formatted(.dateTime.month(.abbreviated)))
                    .font(.headline)
            }
            .foregroundStyle(statusColor)
            .frame(width: 70, height: 70)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke(statusColor.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(dose.medication.name)
                    .font(.headline)
                Text("\(dose.medication.displayDose) · \(dose.medication.instructions)")
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.10))
        }
    }

    private var statusColor: Color {
        if dose.scheduledAt < Date() { return .red }
        if dose.scheduledAt.isSameDay(as: Date()) { return .orange }
        if dose.scheduledAt.isSameDay(as: Date().addingDays(1)) { return .cyan }
        return Color.appBlue
    }

    private var statusText: String {
        if dose.scheduledAt < Date() { return "Overdue" }
        if dose.scheduledAt.isSameDay(as: Date()) { return "Due Today" }
        if dose.scheduledAt.isSameDay(as: Date().addingDays(1)) { return "Tomorrow" }
        return "Upcoming"
    }
}

struct LegendDot: View {
    var color: Color
    var text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .foregroundStyle(color)
    }
}
