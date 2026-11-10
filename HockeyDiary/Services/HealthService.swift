import Foundation
import HealthKit
import HockeyCore

/// 건강 앱에서 읽은 운동 한 건(앱에 저장하지 않는다).
struct HealthWorkout: Identifiable, Equatable {
    var id: UUID
    var start: Date
    var end: Date
    var activityName: String
    var source: String
    var kilocalories: Double?

    var span: TimeSpan { TimeSpan(start: start, end: end) }
    var minutes: Int { span.minutes }
}

/// 활동 시간대의 건강 앱 데이터 묶음.
struct SessionHealth: Equatable {
    var night: SleepNight?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var workouts: [HealthWorkout]
    /// 활동 시간대 심박 표본(구간·쉬프트 짐작용). 앱에 저장하지 않는다.
    var samples: [HeartSample] = []
    /// 여러 기기가 잰 운동 시간을 한 번만 센 값 (9.2).
    var mergedWorkoutMinutes: Int { TimeMerge.unionMinutes(workouts.map(\.span)) }
    var isEmpty: Bool { night == nil && averageHeartRate == nil && workouts.isEmpty }
}

/// Apple 건강 읽기 전용 창구. 건강 앱에 아무것도 쓰지 않고, 읽은 값은 앱에 저장하지 않는다.
/// 읽기 권한을 거부해도 iOS는 알려주지 않고 빈 결과만 준다 — 화면에서 '데이터 없음'으로 안내한다.
final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

    static let sleepType = HKCategoryType(.sleepAnalysis)
    static let heartRateType = HKQuantityType(.heartRate)
    static let readTypes: Set<HKObjectType> = [sleepType, heartRateType, HKObjectType.workoutType()]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 사용자가 '연결하기'를 눌렀을 때만 부른다 (11.2).
    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func sleepSegments(from: Date, to: Date) async throws -> [SleepSegment] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: Self.sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: store)
        return samples.compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  HKCategoryValueSleepAnalysis.allAsleepValues.contains(value) else { return nil }
            return SleepSegment(start: sample.startDate, end: sample.endDate)
        }
    }

    func heartRate(from: Date, to: Date) async throws -> (average: Double, max: Double)? {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.heartRateType, predicate: predicate),
            options: [.discreteAverage, .discreteMax])
        guard let stats = try await descriptor.result(for: store) else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        guard let avg = stats.averageQuantity()?.doubleValue(for: unit),
              let mx = stats.maximumQuantity()?.doubleValue(for: unit) else { return nil }
        return (avg, mx)
    }

    func workouts(from: Date, to: Date) async throws -> [HealthWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let workouts = try await descriptor.result(for: store)
        let energy = HKQuantityType(.activeEnergyBurned)
        return workouts.map { w in
            HealthWorkout(id: w.uuid, start: w.startDate, end: w.endDate,
                          activityName: Self.name(of: w.workoutActivityType),
                          source: w.sourceRevision.source.name,
                          kilocalories: w.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie()))
        }
    }

    /// 활동 시간대 심박 표본(시간순).
    func heartRateSamples(from: Date, to: Date) async throws -> [HeartSample] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: Self.heartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)], limit: 4000)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await descriptor.result(for: store).map { HeartSample(at: $0.startDate, bpm: $0.quantity.doubleValue(for: unit)) }
    }

    /// 활동 하나에 필요한 건강 데이터를 한 번에 읽는다.
    func health(for start: Date, end: Date) async -> SessionHealth {
        let sleepFrom = start.addingTimeInterval(-30 * 3600)
        let segments = (try? await sleepSegments(from: sleepFrom, to: start)) ?? []
        let hr = try? await heartRate(from: start, to: end)
        // 앞뒤 15분 여유를 두고 겹치는 운동을 찾는다.
        let window = TimeSpan(start: start.addingTimeInterval(-900), end: end.addingTimeInterval(900))
        let ws = ((try? await workouts(from: window.start, to: window.end)) ?? [])
            .filter { TimeMerge.isMergeCandidate($0.span, TimeSpan(start: start, end: end), ratio: 0.3) }
        let samples = (try? await heartRateSamples(from: start, to: end)) ?? []
        return SessionHealth(night: SleepAttribution.nightBefore(start, segments: segments),
                             averageHeartRate: hr?.average, maxHeartRate: hr?.max, workouts: ws, samples: samples)
    }

    // MARK: - 생리 주기 (별도 동의, F-C04)

    static let menstrualType = HKCategoryType(.menstrualFlow)

    /// 생리 주기 토글을 켤 때만 따로 요청한다.
    func requestCycleAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [Self.menstrualType])
    }

    /// 출혈이 기록된 날(하루 시작 시각) 모음.
    func menstrualDays(from: Date, to: Date) async throws -> Set<Date> {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: Self.menstrualType, predicate: predicate)],
            sortDescriptors: [])
        let samples = try await descriptor.result(for: store)
        let cal = Calendar.current
        var days = Set<Date>()
        for s in samples where s.value != HKCategoryValueMenstrualFlow.none.rawValue {
            // 기록이 걸친 날을 모두 넣는다(하루짜리 기록은 그날 하루).
            var d = cal.startOfDay(for: s.startDate)
            repeat {
                days.insert(d)
                guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            } while d < s.endDate
        }
        return days
    }

    static func name(of type: HKWorkoutActivityType) -> String {
        switch type {
        case .hockey: return "하키"
        case .skatingSports: return "스케이팅"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "근력 운동"
        case .running: return "달리기"
        case .cycling: return "사이클"
        default: return "운동"
        }
    }
}

/// 건강 연결 상태(사용자가 켠 것만 기억). 권한 자체는 iOS가 관리한다.
enum HealthPrefs {
    static let enabledKey = "healthEnabled"
    static let cycleKey = "cycleEnabled"
    /// 심박 구간 계산에 쓰는 최고 심박. 사용자가 설정에서 바꾼다.
    static let maxHRKey = "maxHeartRate"
    static let defaultMaxHR = 190
}
