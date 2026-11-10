import Foundation

/// 방금 끝난 운동을 기록할 때 시작 시각·시간을 미리 정한다.
/// 우선순위: 건강 앱 운동 기록 → 가까운 팀 일정 → 직전 같은 종류 기록의 시간.
public enum QuickPrefill {
    public enum Source: Equatable, Sendable {
        case workout
        case teamEvent(index: Int)
        case lastSession
        case none
    }

    public struct Event: Equatable, Sendable {
        public var start: Date
        public var minutes: Int
        public init(start: Date, minutes: Int) { self.start = start; self.minutes = minutes }
    }

    public struct Plan: Equatable, Sendable {
        public var start: Date
        public var minutes: Int
        public var source: Source
    }

    /// - events: 아직 기록과 이어지지 않은 팀 일정.
    /// - workouts: 건강 앱의 하키·스케이트 운동(시작, 끝).
    public static func plan(now: Date, defaultMinutes: Int, lastMinutes: Int?,
                            events: [Event], workouts: [(start: Date, end: Date)],
                            calendar: Calendar = .current) -> Plan {
        // 1) 끝난 지 3시간 안의 운동 기록. 가장 최근 것.
        if let w = workouts
            .filter({ $0.end <= now.addingTimeInterval(60) && now.timeIntervalSince($0.end) <= 3 * 3600 && $0.end > $0.start })
            .max(by: { $0.end < $1.end }) {
            let m = max(1, Int((w.end.timeIntervalSince(w.start) / 60).rounded()))
            return Plan(start: w.start, minutes: m, source: .workout)
        }
        // 2) 4시간 전 ~ 1시간 뒤에 시작하는 팀 일정. 지금과 가장 가까운 것.
        let near = events.enumerated()
            .filter { now.timeIntervalSince($0.element.start) <= 4 * 3600 && $0.element.start.timeIntervalSince(now) <= 3600 }
            .min { abs($0.element.start.timeIntervalSince(now)) < abs($1.element.start.timeIntervalSince(now)) }
        if let (i, e) = near {
            return Plan(start: e.start, minutes: max(1, e.minutes), source: .teamEvent(index: i))
        }
        // 3) 직전 같은 종류 기록의 시간만큼 거슬러 올라간 시각(5분 단위로 내림).
        let m = max(1, lastMinutes ?? defaultMinutes)
        let raw = now.addingTimeInterval(-Double(m) * 60)
        return Plan(start: roundDown5(raw, calendar: calendar), minutes: m, source: lastMinutes == nil ? .none : .lastSession)
    }

    static func roundDown5(_ d: Date, calendar: Calendar) -> Date {
        var c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        c.minute = (c.minute ?? 0) / 5 * 5
        return calendar.date(from: c) ?? d
    }
}
