import Foundation
import ActivityKit
import HockeyCore

/// 진행 중인 경기 점수판 하나. 누를 때마다 기기에 저장해서 앱이 꺼지거나 전화가 와도 이어진다.
/// 잠금 화면 실시간 활동도 여기서 맞춘다.
@MainActor
@Observable
final class ScoreboardStore {
    static let shared = ScoreboardStore()
    private static let key = "scoreboard.current"

    private(set) var current: Scoreboard?
    private var activity: Activity<ScoreActivityAttributes>?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key) {
            current = try? JSONDecoder().decode(Scoreboard.self, from: data)
        }
    }

    func start(_ board: Scoreboard) {
        current = board
        save()
        startActivity(board)
    }

    /// 점수·피리어드를 바꾼다. 바꾼 뒤 바로 저장하고 잠금 화면을 맞춘다.
    func change(_ edit: (inout Scoreboard) -> Void) {
        guard var b = current else { return }
        edit(&b)
        current = b
        save()
        if activity == nil { startActivity(b) } else { updateActivity(b) }
    }

    /// 끝내기·버리기. 저장한 점수판과 잠금 화면 표시를 지운다.
    func finish() {
        current = nil
        UserDefaults.standard.removeObject(forKey: Self.key)
        if let activity {
            self.activity = nil
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func save() {
        guard let current, let data = try? JSONEncoder().encode(current) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    // MARK: - 잠금 화면

    private func state(_ b: Scoreboard) -> ScoreActivityAttributes.ContentState {
        .init(us: b.us, them: b.them, period: b.periodTitle)
    }

    private func startActivity(_ b: Scoreboard) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = ScoreActivityAttributes(teamName: b.teamName.isEmpty ? "우리" : b.teamName,
                                            opponent: b.opponent.isEmpty ? "상대" : b.opponent, startedAt: b.startedAt)
        activity = try? Activity.request(attributes: attrs, content: .init(state: state(b), staleDate: nil), pushType: nil)
    }

    private func updateActivity(_ b: Scoreboard) {
        guard let activity else { return }
        let s = state(b)
        Task { await activity.update(.init(state: s, staleDate: nil)) }
    }
}
