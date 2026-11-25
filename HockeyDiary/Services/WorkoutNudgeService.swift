import Foundation
import HealthKit
import SwiftData
import UIKit
import UserNotifications
import HockeyCore

/// 기록 안 된 건강 앱 하키 운동 한 건. 홈 카드와 알림이 이걸 들고 기록 화면을 연다.
struct UnloggedWorkout: Identifiable, Hashable {
    var id: String
    var start: Date
    var end: Date
    var activityName: String
    var source: String

    var minutes: Int { max(1, Int((end.timeIntervalSince(start) / 60).rounded())) }
    /// "어제 20:10 · 하키 80분"
    var summary: String {
        let day = Calendar.current.isDateInToday(start) ? "오늘"
            : Calendar.current.isDateInYesterday(start) ? "어제"
            : start.formatted(.dateTime.month().day().weekday(.abbreviated))
        return "\(day) \(start.formatted(date: .omitted, time: .shortened)) · \(activityName) \(minutesText(minutes))"
    }
}

/// 워치·가민이 건강 앱에 하키 운동을 넣으면 알아채고 "기록할까요?"를 묻는다.
/// - 앱이 꺼져 있어도 iOS가 깨워 준다(HealthKit 백그라운드 전달). 그때 기기 알림을 하나 띄운다.
/// - 앱을 열면 홈 카드로도 보인다(알림을 놓쳤거나 꺼 둔 사람).
/// 운동 데이터는 저장하지 않는다. 기억하는 건 '이미 알린 id'와 '아니에요로 넘긴 id'뿐이다.
@MainActor
@Observable
final class WorkoutNudgeService {
    static let shared = WorkoutNudgeService()
    static let notifyKey = "workoutNudgeNotify"
    private static let skippedKey = "workoutNudgeSkipped"
    private static let notifiedKey = "workoutNudgeNotified"
    private static let idPrefix = "workout-nudge-"

    /// 홈 카드에 보일 것(최근 것부터).
    private(set) var pending: [UnloggedWorkout] = []
    /// 알림을 눌러 열어야 할 운동. RootView가 기록 화면을 열고 nil로 되돌린다.
    var opened: UnloggedWorkout?

    private var container: ModelContainer?
    private var observing = false
    private let store = HKHealthStore()

    static var notifyEnabled: Bool { UserDefaults.standard.bool(forKey: notifyKey) }
    private var healthOn: Bool { UserDefaults.standard.bool(forKey: HealthPrefs.enabledKey) && HealthService.shared.isAvailable }

    /// 앱이 켜질 때(백그라운드로 깨워진 때 포함) 한 번 부른다.
    func start(container: ModelContainer) {
        self.container = container
        UNUserNotificationCenter.current().delegate = NudgeNotificationDelegate.shared
        observe()
    }

    /// 건강 앱에 운동이 들어오면 불린다. 건강 연결을 켠 뒤에도 부른다.
    func observe() {
        guard healthOn, !observing, !Self.demo, !DemoData.isEnabled else { return }
        observing = true
        let type = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            Task { @MainActor in
                await WorkoutNudgeService.shared.refresh(notify: true)
                completion()
            }
        }
        store.execute(query)
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }

    /// 다시 판정한다. notify면 아직 안 알린 운동을 기기 알림으로 띄운다(앱을 보고 있으면 카드로 충분해 띄우지 않는다).
    func refresh(notify: Bool = false) async {
        guard let container else { return }
        if Self.demo { pending = demoFiltered(container); return }
        guard healthOn else { pending = []; return }
        let now = Date()
        let raw = (try? await HealthService.shared.workouts(from: now.addingTimeInterval(-WorkoutNudge.lookback - 6 * 3600), to: now)) ?? []
        pending = Self.judge(raw.map {
            UnloggedWorkout(id: $0.id.uuidString, start: $0.start, end: $0.end, activityName: $0.activityName, source: $0.source)
        }, context: container.mainContext, now: now)
        if notify, Self.notifyEnabled, UIApplication.shared.applicationState != .active { await post() }
    }

    /// '아니에요': 다시 묻지 않는다.
    func skip(_ w: UnloggedWorkout) {
        var s = Self.ids(Self.skippedKey)
        s.insert(w.id)
        Self.save(s, Self.skippedKey)
        pending.removeAll { $0.id == w.id }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.idPrefix + w.id])
    }

    /// 기록을 저장했거나 지웠을 때 카드를 다시 맞춘다.
    func recheck() {
        guard let container else { return }
        pending = Self.judge(pending, context: container.mainContext, now: Date())
    }

    // MARK: - 판정

    private static func judge(_ list: [UnloggedWorkout], context: ModelContext, now: Date) -> [UnloggedWorkout] {
        let from = now.addingTimeInterval(-WorkoutNudge.lookback - 24 * 3600)
        let sessions = ((try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.endsAt >= from })))  ?? [])
            .map { TimeSpan(start: $0.startsAt, end: $0.endsAt) }
        let input = list.map { WorkoutNudge.Workout(id: $0.id, span: TimeSpan(start: $0.start, end: $0.end), isHockey: isHockey($0.activityName)) }
        let keep = WorkoutNudge.unlogged(input, sessions: sessions, skipped: ids(skippedKey), now: now).map(\.id)
        return keep.compactMap { id in list.first { $0.id == id } }
    }

    /// 가민 '아이스하키'는 건강 앱에 하키로, '스케이트'는 스케이팅으로 들어온다.
    static func isHockey(_ name: String) -> Bool { name == "하키" || name == "스케이팅" }

    // MARK: - 알림

    /// 켤 때 한 번 권한을 묻는다. 거절하면 false.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func post() async {
        var notified = Self.ids(Self.notifiedKey)
        let center = UNUserNotificationCenter.current()
        for w in pending where !notified.contains(w.id) {
            let c = UNMutableNotificationContent()
            c.title = "\(w.activityName) 운동, 기록할까요?"
            c.body = "\(w.summary) (\(w.source)). 누르면 시간이 채워진 기록 화면이 열려요."
            c.sound = .default
            c.userInfo = ["id": w.id, "start": w.start.timeIntervalSince1970, "end": w.end.timeIntervalSince1970,
                          "name": w.activityName, "source": w.source]
            try? await center.add(UNNotificationRequest(identifier: Self.idPrefix + w.id, content: c, trigger: nil))
            notified.insert(w.id)
        }
        Self.save(notified, Self.notifiedKey)
    }

    fileprivate func open(from info: [AnyHashable: Any]) {
        guard let id = info["id"] as? String, let s = info["start"] as? Double, let e = info["end"] as? Double else { return }
        opened = UnloggedWorkout(id: id, start: Date(timeIntervalSince1970: s), end: Date(timeIntervalSince1970: e),
                                 activityName: info["name"] as? String ?? "하키", source: info["source"] as? String ?? "")
    }

    // MARK: - 저장(id만, 최근 200개)

    private static func ids(_ key: String) -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
    private static func save(_ s: Set<String>, _ key: String) { UserDefaults.standard.set(Array(s.suffix(200)), forKey: key) }

    // MARK: - 화면 점검용(-demoUnloggedWorkout): 어제 저녁 가민 하키 80분. 건강 앱 없이 카드·기록 흐름을 시험한다.

    private static var demo: Bool { ProcessInfo.processInfo.arguments.contains("-demoUnloggedWorkout") }

    private func demoFiltered(_ container: ModelContainer) -> [UnloggedWorkout] {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let start = cal.date(bySettingHour: 20, minute: 10, second: 0, of: day)!
        let demo = UnloggedWorkout(id: "demo-garmin", start: start, end: start.addingTimeInterval(80 * 60),
                                   activityName: "하키", source: "Garmin Connect")
        return Self.judge([demo], context: container.mainContext, now: Date())
    }
}

/// 알림을 눌렀을 때와 앱을 보는 중에 알림이 왔을 때.
final class NudgeNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NudgeNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        await MainActor.run { WorkoutNudgeService.shared.open(from: info) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
