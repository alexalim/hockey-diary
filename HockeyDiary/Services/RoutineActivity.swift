import Foundation
import ActivityKit

/// 루틴 러너를 잠금 화면·다이내믹 아일랜드에 띄운다. 타이머는 끝나는 시각만 넘겨 시스템이 센다.
@MainActor
final class RoutineActivity {
    static let shared = RoutineActivity()
    private var activity: Activity<RoutineActivityAttributes>?

    func start(routineName: String, state: RoutineActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attrs = RoutineActivityAttributes(routineName: routineName)
        activity = try? Activity.request(attributes: attrs, content: .init(state: state, staleDate: nil), pushType: nil)
    }

    func update(_ state: RoutineActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
