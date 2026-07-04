import Foundation
import HealthKit

struct HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationAndFetch() async throws -> HealthMetricsSnapshot {
        guard isAvailable else {
            throw HealthKitSyncError.unavailable
        }

        try await requestAuthorization()
        return try await fetchSnapshot(isEnabled: true)
    }

    func fetchSnapshot(isEnabled: Bool) async throws -> HealthMetricsSnapshot {
        guard isAvailable else {
            throw HealthKitSyncError.unavailable
        }

        async let weights = latestQuantitySamples(
            identifier: .bodyMass,
            unit: .pound(),
            limit: 2
        )
        async let restingHeartRate = latestQuantitySample(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let systolic = latestQuantitySample(
            identifier: .bloodPressureSystolic,
            unit: .millimeterOfMercury()
        )
        async let diastolic = latestQuantitySample(
            identifier: .bloodPressureDiastolic,
            unit: .millimeterOfMercury()
        )
        async let sleep = latestSleepSample()
        async let steps = todayCumulativeQuantity(
            identifier: .stepCount,
            unit: .count()
        )
        async let activeEnergy = todayCumulativeQuantity(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie()
        )

        let bodyMassSamples = try await weights

        return HealthMetricsSnapshot(
            isHealthKitEnabled: isEnabled,
            lastAuthorizationRequestedAt: Date(),
            lastSyncedAt: Date(),
            lastSyncError: nil,
            bodyMassPounds: bodyMassSamples.first,
            previousBodyMassPounds: bodyMassSamples.dropFirst().first,
            restingHeartRateBPM: try await restingHeartRate,
            bloodPressureSystolicMMHg: try await systolic,
            bloodPressureDiastolicMMHg: try await diastolic,
            sleepHours: try await sleep,
            stepCount: try await steps,
            activeEnergyKilocalories: try await activeEnergy
        )
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitSyncError.authorizationNotCompleted)
                }
            }
        }
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ]
        .compactMap { $0 }
        .reduce(into: Set<HKObjectType>()) { output, type in
            output.insert(type)
        }
    }

    private func latestQuantitySample(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> HealthMetricSample? {
        try await latestQuantitySamples(identifier: identifier, unit: unit, limit: 1).first
    }

    private func latestQuantitySamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        limit: Int
    ) async throws -> [HealthMetricSample] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitSyncError.missingType(identifier.rawValue)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let metricSamples = (samples as? [HKQuantitySample] ?? []).map { sample in
                    HealthMetricSample(
                        value: sample.quantity.doubleValue(for: unit),
                        unit: unit.unitString,
                        startDate: sample.startDate,
                        endDate: sample.endDate
                    )
                }
                continuation.resume(returning: metricSamples)
            }

            healthStore.execute(query)
        }
    }

    private func todayCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> HealthMetricSample? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitSyncError.missingType(identifier.rawValue)
        }

        let start = Date().startOfDay
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantity = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(
                    returning: HealthMetricSample(
                        value: quantity.doubleValue(for: unit),
                        unit: unit.unitString,
                        startDate: start,
                        endDate: end
                    )
                )
            }

            healthStore.execute(query)
        }
    }

    private func latestSleepSample() async throws -> HealthMetricSample? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitSyncError.missingType(HKCategoryTypeIdentifier.sleepAnalysis.rawValue)
        }

        let start = Date().addingDays(-7)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictEndDate)

        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let asleepSamples = (samples as? [HKCategorySample] ?? [])
                    .filter { Self.asleepValues.contains($0.value) }

                guard let latestDay = asleepSamples.map({ $0.endDate.startOfDay }).max() else {
                    continuation.resume(returning: nil)
                    return
                }

                let latestSamples = asleepSamples.filter { $0.endDate.startOfDay == latestDay }
                let seconds = latestSamples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }

                guard seconds > 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(
                    returning: HealthMetricSample(
                        value: seconds / 3_600,
                        unit: "hr",
                        startDate: latestSamples.map(\.startDate).min() ?? latestDay,
                        endDate: latestSamples.map(\.endDate).max() ?? latestDay
                    )
                )
            }

            healthStore.execute(query)
        }
    }

    private static let asleepValues: Set<Int> = [1, 3, 4, 5]

    private static func isNoDataError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == HKError.errorDomain,
           nsError.code == HKError.Code.errorNoData.rawValue {
            return true
        }

        return nsError.localizedDescription.localizedCaseInsensitiveContains("No data available")
    }
}

enum HealthKitSyncError: LocalizedError, Equatable {
    case unavailable
    case authorizationNotCompleted
    case missingType(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health data is not available on this device."
        case .authorizationNotCompleted:
            return "Apple Health authorization was not completed."
        case .missingType(let identifier):
            return "Apple Health type \(identifier) is not available on this device."
        }
    }
}
