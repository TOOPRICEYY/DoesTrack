import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: DoseStore
    @State private var selectedDate = Date()
    @State private var isSchedulingNotifications = false
    @State private var alertMessage = ""
    @State private var showsAlert = false

    private var doses: [ScheduledDose] {
        store.scheduledDoses(on: selectedDate)
    }

    private var dueDoses: [ScheduledDose] {
        doses.filter { $0.effectiveStatus == nil || $0.effectiveStatus == .missed }
    }

    private var completedDoses: [ScheduledDose] {
        doses.filter { $0.effectiveStatus == .taken || $0.effectiveStatus == .skipped }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.medications.isEmpty {
                    EmptyStateView(
                        systemImage: "pills",
                        title: "No medications",
                        message: "Add medications and schedules to start tracking doses."
                    )
                } else if doses.isEmpty {
                    EmptyStateView(
                        systemImage: "calendar.badge.clock",
                        title: "No doses scheduled",
                        message: "There are no active doses for the selected date."
                    )
                } else {
                    List {
                        if !dueDoses.isEmpty {
                            Section("Due") {
                                ForEach(dueDoses) { dose in
                                    DoseRow(dose: dose) { status in
                                        store.record(dose, status: status)
                                    }
                                }
                            }
                        }

                        if !completedDoses.isEmpty {
                            Section("Logged") {
                                ForEach(completedDoses) { dose in
                                    DoseRow(dose: dose) { status in
                                        store.record(dose, status: status)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .safeAreaInset(edge: .top) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .navigationTitle(selectedDate.isSameDay(as: Date()) ? "Today" : selectedDate.formatted(date: .abbreviated, time: .omitted))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        scheduleNotifications()
                    } label: {
                        if isSchedulingNotifications {
                            ProgressView()
                        } else {
                            Image(systemName: "bell.badge")
                        }
                    }
                    .disabled(isSchedulingNotifications || store.medications.isEmpty)
                    .accessibilityLabel("Schedule reminders")
                }
            }
            .alert("DoseTrack", isPresented: $showsAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func scheduleNotifications() {
        isSchedulingNotifications = true
        Task {
            do {
                let scheduler = NotificationScheduler()
                let granted = try await scheduler.requestAuthorization()
                if granted {
                    try await scheduler.schedule(medications: store.medications)
                    alertMessage = "Reminders scheduled for the next 28 days."
                } else {
                    alertMessage = "Notification permission was not granted."
                }
            } catch {
                alertMessage = error.localizedDescription
            }

            isSchedulingNotifications = false
            showsAlert = true
        }
    }
}

private struct DoseRow: View {
    var dose: ScheduledDose
    var onRecord: (DoseLogStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        MedicationSwatch(colorHex: dose.medication.colorHex)
                        Text(dose.medication.name)
                            .font(.headline)
                    }

                    Text([dose.medication.displayDose, dose.schedule.label].filter { !$0.isEmpty }.joined(separator: " - "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(dose.scheduledAt.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                    StatusChip(status: dose.effectiveStatus)
                }
            }

            if !dose.medication.instructions.isEmpty {
                Text(dose.medication.instructions)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    onRecord(.taken)
                } label: {
                    Label("Taken", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(dose.log?.status == .taken)

                Button {
                    onRecord(.skipped)
                } label: {
                    Label("Skip", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(dose.log?.status == .skipped)
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
