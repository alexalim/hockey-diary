import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// 경기 점수판의 실시간 활동(잠금 화면·다이내믹 아일랜드). 앱과 위젯이 같은 정의를 쓴다.
/// 위젯은 HockeyCore를 모르므로 보여 줄 값만 평평하게 넘긴다.
struct ScoreActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var us: Int
        var them: Int
        /// "1P" · "2P" · "3P" · "연장"
        var period: String
    }

    var teamName: String
    var opponent: String
    /// 경기 시작 시각. 잠금 화면에서 흐른 시간을 시스템이 센다.
    var startedAt: Date
}
#endif
