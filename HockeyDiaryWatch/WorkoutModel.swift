import Foundation
import HealthKit
import CoreLocation
import WatchConnectivity
import HockeyCore

/// 워치 운동 세션. 하키 운동으로 시간·심박을 재고, 쉬프트(얼음↔벤치)를 직접 눌러 세고,
/// 야외·폰드면 GPS로 총거리만 잰다(경로는 저장하지 않는다). 끝나면 아이폰으로 활동을 보낸다.
/// 건강 권한이 없거나 센서를 못 쓰면 타이머만으로 잰다.
@MainActor
final class WorkoutModel: NSObject, ObservableObject {
    enum Phase: Equatable { case idle, running, finishing, sent }

    @Published var phase: Phase = .idle
    @Published var type: ActivityType = .lesson
    @Published var surface: SurfaceType = .indoorRink
    @Published var moodBefore: Int?
    @Published var moodAfter: Int?
    @Published var heartRate: Double?
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var usingHealth = false

    // 쉬프트: 직접 누른 값만 센다.
    @Published var onIce = false
    @Published var shiftCount = 0
    @Published private(set) var onIceSecondsDone = 0
    private var onIceSince: Date?

    // 거리(야외·폰드만). 총거리만 더하고 위치는 남기지 않는다.
    @Published var distanceMeters: Double = 0
    @Published var locationDenied = false
    private var lastLocation: CLLocation?
    private let locationManager = CLLocationManager()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var usesGPS: Bool { surface == .outdoorRink || surface == .pond }

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
    }

    /// 지금까지 얼음 위에 있던 시간(초). 지금 얼음 위면 진행 중인 쉬프트도 더한다.
    func onIceSeconds(at now: Date = Date()) -> Int {
        onIceSecondsDone + (onIceSince.map { Int(now.timeIntervalSince($0)) } ?? 0)
    }

    func start() async {
        startDate = Date()
        endDate = nil
        heartRate = nil
        onIce = false; shiftCount = 0; onIceSecondsDone = 0; onIceSince = nil
        distanceMeters = 0; lastLocation = nil
        phase = .running
        usingHealth = false
        if usesGPS {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                                 read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
            let config = HKWorkoutConfiguration()
            config.activityType = .hockey
            config.locationType = usesGPS ? .outdoor : .indoor
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

    /// 얼음 위 ↔ 벤치. 얼음에 올라갈 때 쉬프트를 하나 센다.
    func toggleShift() {
        let now = Date()
        if onIce {
            if let since = onIceSince { onIceSecondsDone += Int(now.timeIntervalSince(since)) }
            onIceSince = nil
            onIce = false
        } else {
            onIceSince = now
            onIce = true
            shiftCount += 1
        }
    }

    func stop() async {
        let end = Date()
        if onIce { toggleShift() }
        endDate = end
        phase = .finishing
        locationManager.stopUpdatingLocation()
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
        let payload = WatchWorkoutPayload(
            type: type, start: start, end: end,
            moodBefore: moodBefore, moodAfter: moodAfter, savedToHealth: usingHealth,
            shifts: shiftCount > 0 ? shiftCount : nil,
            onIceSeconds: onIceSecondsDone > 0 ? onIceSecondsDone : nil,
            distanceMeters: usesGPS && distanceMeters >= 50 ? distanceMeters : nil,
            surface: surface)
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
        onIce = false; shiftCount = 0; onIceSecondsDone = 0; onIceSince = nil
        distanceMeters = 0; lastLocation = nil
    }
}

extension WorkoutModel: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate, CLLocationManagerDelegate {
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

    // 위치: 정확한 점만 쓰고, 이동 거리만 더한다. 점은 바로 버린다.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let good = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < 30 }
        guard !good.isEmpty else { return }
        Task { @MainActor in
            for loc in good {
                if let last = self.lastLocation {
                    let d = loc.distance(from: last)
                    let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                    // 1초에 15m 넘게 튄 점(GPS 오류)은 건너뛴다.
                    if dt > 0, d / dt < 15 { self.distanceMeters += d }
                }
                self.lastLocation = loc
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        Task { @MainActor in self.locationDenied = denied }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
