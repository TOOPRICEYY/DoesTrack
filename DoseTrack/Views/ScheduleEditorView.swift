import SwiftUI

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ScheduleDraft
    var onSave: (DoseSchedule) -> Void

    init(schedule: DoseSchedule, onSave: @escaping (DoseSchedule) -> Void) {
        _draft = State(initialValue: ScheduleDraft(schedule: schedule))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dose Time") {
                    TextField("Label", text: $draft.label)
                    DatePicker("Time", selection: $draft.time, displayedComponents: [.hourAndMinute])
                    TextField("Amount", value: $draft.amount, format: .number)
                        .keyboardType(.decimalPad)
                    Toggle("Reminder", isOn: $draft.reminderEnabled)
                }

                Section("Days") {
                    WeekdayPicker(selection: $draft.daysOfWeek)
                }

                Section("Date Range") {
                    DatePicker("Start", selection: $draft.startDate, displayedComponents: [.date])
                    Toggle("End date", isOn: $draft.hasEndDate)
                    if draft.hasEndDate {
                        DatePicker("End", selection: $draft.endDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft.makeSchedule())
                        dismiss()
                    }
                    .disabled(draft.daysOfWeek.isEmpty || draft.amount <= 0)
                }
            }
        }
    }
}

private struct ScheduleDraft {
    var id: UUID
    var label: String
    var time: Date
    var amount: Double
    var daysOfWeek: Set<Weekday>
    var startDate: Date
    var hasEndDate: Bool
    var endDate: Date
    var reminderEnabled: Bool

    init(schedule: DoseSchedule) {
        self.id = schedule.id
        self.label = schedule.label
        self.time = Calendar.doseTrackCalendar.dateBySettingTime(hour: schedule.hour, minute: schedule.minute, on: Date()) ?? Date()
        self.amount = schedule.amount
        self.daysOfWeek = schedule.daysOfWeek
        self.startDate = schedule.startDate
        self.hasEndDate = schedule.endDate != nil
        self.endDate = schedule.endDate ?? Date().addingDays(30)
        self.reminderEnabled = schedule.reminderEnabled
    }

    func makeSchedule() -> DoseSchedule {
        let components = Calendar.doseTrackCalendar.dateComponents([.hour, .minute], from: time)
        return DoseSchedule(
            id: id,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Dose" : label.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: components.hour ?? 9,
            minute: components.minute ?? 0,
            amount: max(0.1, amount),
            daysOfWeek: daysOfWeek,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            reminderEnabled: reminderEnabled
        )
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Every day") {
                    selection = Set(Weekday.allCases)
                }
                .buttonStyle(.bordered)

                Button("Weekdays") {
                    selection = [.monday, .tuesday, .wednesday, .thursday, .friday]
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    selection = []
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { weekday in
                    Button {
                        if selection.contains(weekday) {
                            selection.remove(weekday)
                        } else {
                            selection.insert(weekday)
                        }
                    } label: {
                        Text(weekday.shortName)
                            .font(.caption.weight(.semibold))
                            .frame(width: 38, height: 34)
                            .background(selection.contains(weekday) ? Color.accentColor : Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(selection.contains(weekday) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
