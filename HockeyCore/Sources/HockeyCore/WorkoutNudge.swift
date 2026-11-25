import Foundation

/// 건강 앱(워치·가민)에 있는데 마하다에 아직 기록하지 않은 하키 운동을 찾는다.
/// 알림과 홈 카드가 같은 판정을 쓴다. 저장은 하지 않고 사용자가 '기록하기'를 눌러야 기록이 생긴다.
public enum WorkoutNudge {
    /// 건강 앱 운동 한 건.
    public struct Workout: Equatable, Sendable {
        public var id: String
        public var span: TimeSpan
        public var isHockey: Bool
        public init(id: String, span: TimeSpan, isHockey: Bool) {
            self.id = id
            self.span = span
            self.isHockey = isHockey
        }
    }

    /// 며칠 전 운동까지 묻는가. 그보다 오래된 건 사용자가 일부러 안 남긴 것으로 본다.
    public static let lookback: TimeInterval = 3 * 24 * 3600
    /// 이보다 짧으면 묻지 않는다(잠깐 켰다 끈 기록).
    public static let minMinutes = 15

    /// 기록이 필요한 운동. 최근 것부터. 같은 경기를 두 기기가 쟀으면 하나로 합친다.
    /// - sessions: 마하다 기록의 시간대. 30% 이상 겹치면 이미 기록한 것으로 본다(활동 상세의 건강 카드와 같은 기준).
    /// - skipped: 사용자가 '아니에요'로 넘긴 운동 id.
    public static func unlogged(_ workouts: [Workout], sessions: [TimeSpan], skipped: Set<String>, now: Date) -> [Workout] {
        let fresh = workouts.filter {
            $0.isHockey && $0.span.minutes >= minMinutes
                && $0.span.end <= now && now.timeIntervalSince($0.span.end) <= lookback
        }
        // 같은 경기를 여러 기기가 잰 묶음. 대표는 가장 긴 것, 묶음 안 하나라도 넘겼으면 묶음 전체를 넘긴 것으로 본다.
        var groups: [[Workout]] = []
        for w in fresh.sorted(by: { $0.span.start < $1.span.start }) {
            if let i = groups.firstIndex(where: { g in g.contains { TimeMerge.isMergeCandidate($0.span, w.span) } }) {
                groups[i].append(w)
            } else {
                groups.append([w])
            }
        }
        return groups
            .filter { g in !g.contains { skipped.contains($0.id) } }
            .compactMap { g in g.max { $0.span.minutes < $1.span.minutes } }
            .filter { w in !sessions.contains { TimeMerge.isMergeCandidate($0, w.span, ratio: 0.3) } }
            .sorted { $0.span.start > $1.span.start }
    }
}
