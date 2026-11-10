import Foundation
import SwiftData
import WatchConnectivity
import HockeyCore

/// 아이폰 ↔ 워치. 워치에서 끝낸 활동을 받아 Session으로 저장한다.
/// 전달 id를 Session.id로 써서 같은 전달이 두 번 와도 한 건만 남긴다.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var container: ModelContainer?

    /// 앱이 켜질 때 부른다. 워치 기록 때문에 앱이 뒤에서 깨어날 때도 이 경로로 받는다.
    func activate(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func handle(_ info: [String: Any]) {
        guard let payload = WatchWorkoutPayload(dictionary: info) else { return }
        Task { @MainActor in
            guard let context = self.container?.mainContext else { return }
            WatchBridge.importWorkout(payload, context: context)
        }
    }

    @MainActor
    static func importWorkout(_ p: WatchWorkoutPayload, context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        guard !all.contains(where: { $0.id == p.id }) else { return }
        let s = Session(type: p.type, startsAt: p.start, minutes: max(1, Int(p.end.timeIntervalSince(p.start) / 60)))
        s.id = p.id
        s.endsAt = p.end
        s.moodBefore = p.moodBefore
        s.moodAfter = p.moodAfter
        if let surface = p.surface { s.surface = surface }
        s.shifts = p.shifts
        s.onIceMinutes = p.onIceSeconds.map { max(1, Int((Double($0) / 60).rounded())) }
        s.distanceMeters = p.distanceMeters
        context.insert(s)
        context.saveOrReport()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { handle(userInfo) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
