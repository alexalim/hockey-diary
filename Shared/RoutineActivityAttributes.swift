import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// 루틴 러너의 실시간 활동(잠금 화면·다이내믹 아일랜드). 앱과 위젯이 같은 정의를 쓴다.
struct RoutineActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var drillTitle: String
        var skillName: String
        /// 지금 몇 번째 드릴인지(1부터), 전체 개수.
        var index: Int
        var total: Int
        /// 분 단위 드릴이면 타이머가 끝나는 시각(돌고 있을 때만), 아니면 nil.
        var endDate: Date?
        /// 멈춰 있을 때 남은 초(분 단위 드릴).
        var secondsLeft: Int
        /// 횟수 드릴의 지금 횟수와 목표.
        var count: Int
        var target: Int
        var isMinutes: Bool
    }

    var routineName: String
}
#endif
