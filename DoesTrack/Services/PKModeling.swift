import Foundation

struct PKCitation: Identifiable {
    var id: String { "\(title)-\(url)" }
    var title: String
    var detail: String
    var url: String
}

struct PKParameterSet: Identifiable {
    var id: String { drugName }
    var drugName: String
    var matchTerms: [String]
    var halfLifeDays: Double
    var availabilityMultiplier: Double
    var route: String
    var parameterSummary: String
    var modelNote: String
    var citations: [PKCitation]
}

struct PKDoseEvent: Identifiable {
    var id: String
    var date: Date
    var amount: Double
}

struct PKPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

struct PKMedicationProfile: Identifiable {
    var id: UUID { medication.id }
    var medication: Medication
    var parameters: PKParameterSet
    var events: [PKDoseEvent]
    var points: [PKPoint]
    var currentValue: Double
    var peakValue: Double
    var troughValue: Double
    var averageValue: Double
    var windowStart: Date
    var windowEnd: Date

    var unitLabel: String {
        medication.unit.isEmpty ? "relative units" : "relative \(medication.unit)"
    }
}

enum PKParameterLibrary {
    static let supported: [PKParameterSet] = [
        PKParameterSet(
            drugName: "Tirzepatide",
            matchTerms: ["tirzepatide", "mounjaro", "zepbound"],
            halfLifeDays: 5.0,
            availabilityMultiplier: 0.80,
            route: "Subcutaneous",
            parameterSummary: "Half-life 5 days; SC absolute bioavailability 80%.",
            modelNote: "Uses the official label half-life and absolute bioavailability to estimate relative scheduled-dose exposure.",
            citations: [
                PKCitation(
                    title: "DailyMed: Mounjaro (tirzepatide) label",
                    detail: "PK section reports an approximately 5-day elimination half-life and 80% mean absolute bioavailability after subcutaneous administration.",
                    url: "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=d2d7da5d-ad07-4228-955f-cf7e355c8cc0"
                )
            ]
        ),
        PKParameterSet(
            drugName: "hCG",
            matchTerms: ["hcg", "human chorionic gonadotropin", "chorionic gonadotropin"],
            halfLifeDays: 32.5 / 24.0,
            availabilityMultiplier: 1.0,
            route: "Subcutaneous or intramuscular",
            parameterSummary: "Half-life 32-33 hours; relative dose scale.",
            modelNote: "Uses the published average elimination half-life. Because the cited study reports relative SC/IM exposure rather than an absolute bioavailability for app dose units, dose scale is kept at 100%.",
            citations: [
                PKCitation(
                    title: "Mannaerts et al., Human Reproduction, 1998",
                    detail: "Randomized crossover PK study reporting average hCG elimination half-life of 32-33 hours across routes.",
                    url: "https://pubmed.ncbi.nlm.nih.gov/9688371/"
                ),
                PKCitation(
                    title: "Saal et al., Fertility and Sterility, 1991",
                    detail: "Clinical PK study comparing subcutaneous and intramuscular hCG administration.",
                    url: "https://pubmed.ncbi.nlm.nih.gov/1712735/"
                )
            ]
        ),
        PKParameterSet(
            drugName: "BPC-157",
            matchTerms: ["bpc-157", "bpc 157", "body-protective compound 157", "body protective compound 157", "pl 14736", "pl-14736", "bepecin"],
            halfLifeDays: 20.0 / 1_440.0,
            availabilityMultiplier: 1.0,
            route: "Subcutaneous estimate",
            parameterSummary: "Preclinical half-life estimate 20 minutes; relative dose scale.",
            modelNote: "No validated human subcutaneous PK or absolute subcutaneous bioavailability was found. This curve uses a midpoint-style preclinical short half-life estimate to visualize rapid peptide washout only; it is not a serum prediction, dosing recommendation, or safety statement.",
            citations: [
                PKCitation(
                    title: "Wu et al., Frontiers in Pharmacology, 2022",
                    detail: "Rat and dog ADME study of BPC-157 reporting short preclinical systemic half-life values. Used here only as a preclinical anchor because validated human subcutaneous PK parameters were not found.",
                    url: "https://doi.org/10.3389/fphar.2022.1026182"
                )
            ]
        ),
        PKParameterSet(
            drugName: "Testosterone cypionate",
            matchTerms: ["testosterone cypionate", "depo-testosterone", "test cyp", "tcyp"],
            halfLifeDays: 5.0,
            availabilityMultiplier: 1.0,
            route: "Intramuscular or subcutaneous",
            parameterSummary: "Effective curve half-life 5 days; relative dose scale.",
            modelNote: "This is an effective visualization parameter derived from observed serum timing after 200 mg IM testosterone cypionate, not a measured terminal half-life or serum testosterone prediction.",
            citations: [
                PKCitation(
                    title: "Nankin, Fertility and Sterility, 1987",
                    detail: "Human testosterone cypionate kinetics study reporting peak androgen values after days 2-5 and decline to basal levels by days 13-14 after 200 mg IM.",
                    url: "https://pubmed.ncbi.nlm.nih.gov/3595893/"
                ),
                PKCitation(
                    title: "DailyMed: Depo-Testosterone label",
                    detail: "Label identifies testosterone cypionate injection as intramuscular and describes replacement dosing intervals.",
                    url: "https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=cfbb53d4-b868-4a28-8436-f9112eb01c39"
                )
            ]
        )
    ]

    static func parameterSet(for medication: Medication) -> PKParameterSet? {
        let haystack = [
            medication.name,
            medication.instructions,
            medication.notes,
            medication.protocolName ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        return supported.first { parameterSet in
            parameterSet.matchTerms.contains { haystack.contains($0.lowercased()) }
        }
    }
}

@MainActor
enum PKModeler {
    static func profiles(
        in store: DoseStore,
        referenceDate: Date = Date(),
        lookbackDays: Int = 28,
        forecastDays: Int = 28,
        stepHours: Int = 12,
        includeFutureDoses: Bool = true
    ) -> [PKMedicationProfile] {
        store.medications
            .filter(\.isActive)
            .compactMap { medication in
                profile(
                    for: medication,
                    in: store,
                    referenceDate: referenceDate,
                    lookbackDays: lookbackDays,
                    forecastDays: forecastDays,
                    stepHours: stepHours,
                    includeFutureDoses: includeFutureDoses
                )
            }
            .sorted { lhs, rhs in
                lhs.medication.name.localizedCaseInsensitiveCompare(rhs.medication.name) == .orderedAscending
            }
    }

    static func unsupportedActiveMedications(in store: DoseStore) -> [Medication] {
        store.medications
            .filter { $0.isActive && PKParameterLibrary.parameterSet(for: $0) == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func profile(
        for medication: Medication,
        in store: DoseStore,
        referenceDate: Date = Date(),
        lookbackDays: Int = 28,
        forecastDays: Int = 28,
        stepHours: Int = 12,
        includeFutureDoses: Bool = true
    ) -> PKMedicationProfile? {
        guard let parameters = PKParameterLibrary.parameterSet(for: medication) else {
            return nil
        }

        let windowStart = referenceDate.startOfDay.addingDays(-lookbackDays)
        let windowEnd = referenceDate.startOfDay.addingDays(forecastDays)
        let washInDays = max(lookbackDays, Int(ceil(parameters.halfLifeDays * 5)))
        let eventStart = referenceDate.startOfDay.addingDays(-washInDays)
        // With future doses off, the forecast is pure decay of what's on board.
        let eventEnd = includeFutureDoses ? windowEnd : referenceDate
        let events = doseEvents(for: medication, in: store, from: eventStart, through: eventEnd, referenceDate: referenceDate)
            .filter { includeFutureDoses || $0.date <= referenceDate }

        guard !events.isEmpty else { return nil }

        let safeStepHours = max(1, stepHours)
        var points: [PKPoint] = []
        var cursor = windowStart
        while cursor <= windowEnd {
            points.append(PKPoint(date: cursor, value: exposure(at: cursor, events: events, parameters: parameters)))
            guard let next = Calendar.doseTrackCalendar.date(byAdding: .hour, value: safeStepHours, to: cursor) else { break }
            cursor = next
        }

        guard !points.isEmpty else { return nil }

        let values = points.map(\.value)
        let currentValue = exposure(at: referenceDate, events: events, parameters: parameters)

        return PKMedicationProfile(
            medication: medication,
            parameters: parameters,
            events: events,
            points: points,
            currentValue: currentValue,
            peakValue: values.max() ?? currentValue,
            troughValue: values.min() ?? currentValue,
            averageValue: values.reduce(0, +) / Double(values.count),
            windowStart: windowStart,
            windowEnd: windowEnd
        )
    }

    private static func doseEvents(
        for medication: Medication,
        in store: DoseStore,
        from start: Date,
        through end: Date,
        referenceDate: Date
    ) -> [PKDoseEvent] {
        var events: [PKDoseEvent] = []
        var day = start.startOfDay
        let finalDay = end.startOfDay

        while day <= finalDay {
            for scheduledDose in store.scheduledDoses(on: day) where scheduledDose.medication.id == medication.id {
                if scheduledDose.scheduledAt <= referenceDate,
                   let status = scheduledDose.log?.status,
                   status != .taken {
                    continue
                }

                let eventDate = scheduledDose.log?.takenAt ?? scheduledDose.scheduledAt
                let amount = doseAmount(for: medication, schedule: scheduledDose.schedule, log: scheduledDose.log)
                events.append(PKDoseEvent(id: scheduledDose.id, date: eventDate, amount: amount))
            }

            guard let next = Calendar.doseTrackCalendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let scheduledIDs = Set(events.map(\.date))
        let manualEvents = store.logs.compactMap { log -> PKDoseEvent? in
            guard log.medicationID == medication.id,
                  log.scheduleID == nil,
                  log.status == .taken,
                  log.scheduledAt >= start,
                  log.scheduledAt <= end
            else {
                return nil
            }

            let eventDate = log.takenAt ?? log.scheduledAt
            guard !scheduledIDs.contains(eventDate) else { return nil }
            return PKDoseEvent(id: log.id.uuidString, date: eventDate, amount: doseAmount(for: medication, schedule: nil, log: log))
        }

        return (events + manualEvents).sorted { $0.date < $1.date }
    }

    private static func exposure(at date: Date, events: [PKDoseEvent], parameters: PKParameterSet) -> Double {
        let eliminationRate = log(2) / parameters.halfLifeDays

        return events.reduce(0) { total, event in
            guard event.date <= date else { return total }
            let elapsedDays = date.timeIntervalSince(event.date) / 86_400
            let remaining = event.amount * parameters.availabilityMultiplier * exp(-eliminationRate * elapsedDays)
            return total + max(0, remaining)
        }
    }

    private static func doseAmount(for medication: Medication, schedule: DoseSchedule?, log: DoseLog?) -> Double {
        // What was actually logged always beats the medication's nominal dose:
        // a recorded half dose must plot as a half dose.
        if let amount = log?.amount, amount > 0 {
            return amount
        }

        if let parsedDose = firstNumber(in: medication.dose), parsedDose > 0 {
            return parsedDose
        }

        if let amount = schedule?.amount, amount > 0 {
            return amount
        }

        return 1
    }

    private static func firstNumber(in text: String) -> Double? {
        var buffer = ""
        var hasDigit = false

        for character in text {
            if character.isNumber || character == "." {
                buffer.append(character)
                hasDigit = hasDigit || character.isNumber
            } else if hasDigit {
                break
            }
        }

        return hasDigit ? Double(buffer) : nil
    }
}
