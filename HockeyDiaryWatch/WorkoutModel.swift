import Foundation
import HealthKit
import WatchConnectivity
import HockeyCore

/// 워치 운동 세션. 하키 운동으로 시간·심박을 재고, 끝나면 아이폰으로 활동을 보낸다.
/// 건강 권한이 없거나 센서를 못 쓰면 타이머만으로 잰다(워치 없이도 핵심 기록은 아이폰에서 가능).
@MainActor
final class WorkoutModel: NSObject, ObservableObject {
    enum Phase: Equatable { case idle, running, finishing, sent }

    @Published var phase: Phase = .idle
    @Published var type: ActivityType = .lesson
    @Published var moodBefore: Int?
    @Published var moodAfter: Int?
    @Published var heartRate: Double?
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var usingHealth = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func start() async {
        startDate = Date()
        endDate = nil
        heartRate = nil
        phase = .running
        usingHealth = false
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                                 read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
            let config = HKWorkoutConfiguration()
            config.activityType = .hockey
            config.locationType = .indoor
            let s = try HKWorkoutSession(healthStore: store, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            s.delegate = self
            b.delegate = self
            session = s
            builder = b
            let now = startDate ?? Date()
            s.startActivity(with: now)
            try await b.beginCollection(at: now)
            usingHealth = true
        } catch {
            // 권한 거부·센서 문제: 타이머 모드로 계속한다.
            session = nil
            builder = nil
            usingHealth = false
        }
    }

    func stop() async {
        let end = Date()
        endDate = end
        phase = .finishing
        guard let s = session, let b = builder else { return }
        s.end()
        do {
            try await b.endCollection(at: end)
            _ = try await b.finishWorkout()
        } catch {
            usingHealth = false
        }
        session = nil
        builder = nil
    }

    /// 아이폰으로 보낸다. 아이폰 앱이 꺼져 있어도 transferUserInfo는 쌓였다가 전달된다.
    func send() {
        guard let start = startDate else { return }
        let end = max(endDate ?? Date(), start.addingTimeInterval(60))
        let payload = WatchWorkoutPayload(type: type, start: start, end: end,
                                          moodBefore: moodBefore, moodAfter: moodAfter, savedToHealth: usingHealth)
        if WCSession.isSupported() {
            WCSession.default.transferUserInfo(payload.dictionary)
        }
        phase = .sent
    }

    func reset() {
        phase = .idle
        moodBefore = nil
        moodAfter = nil
        startDate = nil
        endDate = nil
        heartRate = nil
    }
}

extension WorkoutModel: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.usingHealth = false }
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let hrType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(hrType),
              let q = workoutBuilder.statistics(for: hrType)?.mostRecentQuantity() else { return }
        let bpm = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in self.heartRate = bpm }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
