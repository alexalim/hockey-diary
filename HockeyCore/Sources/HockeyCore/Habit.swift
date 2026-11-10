import Foundation

/// 쉬는 기간(비시즌·부상). 이 기간에 걸친 주는 연속 기록을 끊지도, 늘리지도 않는다.
public struct RestRange: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date?   // nil이면 지금도 쉬는 중
    public init(start: Date, end: Date? = nil) { self.start = start; self.end = end }

    public static func decode(_ json: String) -> [RestRange] {
        (try? JSONDecoder().decode([RestRange].self, from: Data(json.utf8))) ?? []
    }
    public static func encode(_ list: [RestRange]) -> String {
        (try? JSONEncoder().encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

/// 주간 연속 기록: 한 주에 한 번이라도 탔으면 그 주는 채운 것. 하키는 매일 하는 운동이 아니라서 주 단위로 센다.
public struct WeeklyStreak: Equatable, Sendable {
    public var current: Int
    public var best: Int
    /// 이번 주는 아직 안 탔지만 연속이 살아 있음(이번 주 안에 타면 이어짐).
    public var thisWeekPending: Bool

    public static let milestones = [4, 10, 20, 52]

    public var milestone: Int? { Self.milestones.last { current >= $0 } }

    public static func compute(_ dates: [Date], rests: [RestRange] = [], now: Date,
                               calendar: Calendar = .current) -> WeeklyStreak {
        var cal = calendar
        cal.firstWeekday = 2   // 월요일 시작
        func weekStart(_ d: Date) -> Date { cal.dateInterval(of: .weekOfYear, for: d)!.start }
        let active = Set(dates.map(weekStart))
        func resting(_ w: Date) -> Bool {
            let we = cal.date(byAdding: .day, value: 7, to: w)!
            return rests.contains { r in r.start < we && (r.end ?? .distantFuture) > w }
        }
        let thisWeek = weekStart(now)
        guard let first = active.min() else {
            return WeeklyStreak(current: 0, best: 0, thisWeekPending: false)
        }
        // 처음 탄 주부터 이번 주까지 주마다 훑는다.
        var weeks: [Date] = []
        var w = first
        while w <= thisWeek { weeks.append(w); w = cal.date(byAdding: .day, value: 7, to: w)! }

        var run = 0, best = 0
        for wk in weeks {
            if active.contains(wk) { run += 1; best = max(best, run) }
            else if resting(wk) { continue }
            else if wk == thisWeek { continue }   // 이번 주는 아직 끝나지 않았다
            else { run = 0 }
        }
        let pending = !active.contains(thisWeek) && !resting(thisWeek) && run > 0
        return WeeklyStreak(current: run, best: best, thisWeekPending: pending)
    }
}

/// 홈 맨 위에 하나만 띄우는 '지금 할 일'. 시간대와 오늘 상태로 고른다.
public enum HomePrompt: Equatable, Sendable {
    case resting
    case logEvent(title: String)          // 팀 일정이 끝났는데 기록이 없음
    case beforeEvent(title: String, at: Date)
    case morningGoal(goal: String)
    case eveningJournal

    public struct Event: Equatable, Sendable {
        public var title: String
        public var start: Date
        public var minutes: Int
        public var logged: Bool
        public init(title: String, start: Date, minutes: Int, logged: Bool) {
            self.title = title; self.start = start; self.minutes = minutes; self.logged = logged
        }
    }

    public static func pick(now: Date, resting: Bool, events: [Event], loggedToday: Bool,
                            journaledToday: Bool, goal: String?, calendar: Calendar = .current) -> HomePrompt? {
        if resting { return .resting }
        let todays = events.filter { calendar.isDate($0.start, inSameDayAs: now) }
        // 끝난 지 6시간 안이고 아직 기록 안 한 일정
        if let e = todays.filter({ !$0.logged }).first(where: {
            let end = $0.start.addingTimeInterval(Double($0.minutes) * 60)
            return end <= now && now.timeIntervalSince(end) <= 6 * 3600
        }) { return .logEvent(title: e.title) }
        if let e = todays.filter({ $0.start > now }).min(by: { $0.start < $1.start }) {
            return .beforeEvent(title: e.title, at: e.start)
        }
        let hour = calendar.component(.hour, from: now)
        if hour >= 20 && !journaledToday { return .eveningJournal }
        if hour < 12, let g = goal, !g.isEmpty, !loggedToday { return .morningGoal(goal: g) }
        return nil
    }
}
