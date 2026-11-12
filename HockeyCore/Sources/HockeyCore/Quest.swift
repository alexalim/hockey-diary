import Foundation

/// 퀘스트: 이달 빙판 목표 하나 + 매주 바뀌는 작은 목표 3개. 서버 없이 내 기록만으로 센다.
/// 벌칙은 없다. 못 채운 주는 그냥 지나가고, 쉬는 중이면 세지 않는다.
public enum QuestKind: String, CaseIterable, Codable, Sendable {
    case sessions, drills, conditions, journals, minutes

    public var symbol: String {
        switch self {
        case .sessions: return "pencil.and.list.clipboard"
        case .drills: return "figure.hockey"
        case .conditions: return "heart.text.square"
        case .journals: return "book.fill"
        case .minutes: return "clock.fill"
        }
    }
}

public struct WeeklyQuest: Equatable, Identifiable, Sendable {
    public let kind: QuestKind
    public let target: Int
    public var id: String { kind.rawValue }

    public init(kind: QuestKind, target: Int) { self.kind = kind; self.target = target }

    public var title: String {
        switch kind {
        case .sessions: return "하키 기록 \(target)개 남기기"
        case .drills: return "드릴 \(target)개 세기"
        case .conditions: return "몸 상태 \(target)일 체크하기"
        case .journals: return "일기 \(target)개 쓰기"
        case .minutes: return "빙판 \(target)분 타기"
        }
    }

    /// 진행 표시용 단위.
    public var unit: String { kind == .minutes ? "분" : (kind == .conditions ? "일" : "개") }
}

/// 퀘스트 계산에 쓰는 기록 사실. 날짜만 넘기면 된다.
public struct QuestFacts: Equatable, Sendable {
    public struct Stay: Equatable, Sendable {
        public var date: Date
        public var minutes: Int
        public init(date: Date, minutes: Int) { self.date = date; self.minutes = minutes }
    }
    public var sessions: [Stay]
    public var drillDates: [Date]
    public var conditionDays: [Date]
    public var journalDates: [Date]

    public init(sessions: [Stay] = [], drillDates: [Date] = [], conditionDays: [Date] = [], journalDates: [Date] = []) {
        self.sessions = sessions; self.drillDates = drillDates; self.conditionDays = conditionDays; self.journalDates = journalDates
    }
}

public struct QuestProgress: Equatable, Identifiable, Sendable {
    public let quest: WeeklyQuest
    public let done: Int
    public var id: String { quest.id }
    public var isDone: Bool { done >= quest.target }
    public init(quest: WeeklyQuest, done: Int) { self.quest = quest; self.done = done }
}

public enum Quest {
    public static let pointsPerQuest = 10
    private static let pool: [QuestKind] = [.sessions, .drills, .conditions, .journals, .minutes]

    /// 월요일 시작 달력.
    public static func mondayCalendar(_ calendar: Calendar = .current) -> Calendar {
        var cal = calendar
        cal.firstWeekday = 2
        return cal
    }

    public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        mondayCalendar(calendar).dateInterval(of: .weekOfYear, for: date)!
    }

    public static func month(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)!
    }

    /// 이달 빙판 목표. 초급 4, 중급 6, 고급 8. 레벨을 안 정했으면 4.
    public static func monthlyTarget(level: PlayerLevel?) -> Int {
        switch level {
        case .starter, .none: return 4
        case .growing: return 6
        case .seasoned: return 8
        }
    }

    /// 이번 주 퀘스트 3개. 주차마다 돌아가며 고르되 같은 주엔 늘 같은 셋.
    public static func weekly(weekStart: Date, level: PlayerLevel?) -> [WeeklyQuest] {
        let index = Int(weekStart.timeIntervalSince1970 / (7 * 86400))
        let base = (index * 3) % pool.count
        return (0..<3).map { i in
            let kind = pool[(base + i) % pool.count]
            return WeeklyQuest(kind: kind, target: target(for: kind, level: level))
        }
    }

    static func target(for kind: QuestKind, level: PlayerLevel?) -> Int {
        let high = level == .seasoned
        switch kind {
        case .sessions: return high ? 2 : 1
        case .drills: return high ? 3 : 1
        case .conditions: return 3
        case .journals: return high ? 3 : 2
        case .minutes: return high ? 120 : 60
        }
    }

    /// 한 주 안에서 얼마나 했는지.
    public static func done(_ quest: WeeklyQuest, facts: QuestFacts, week: DateInterval, calendar: Calendar = .current) -> Int {
        func inWeek(_ d: Date) -> Bool { d >= week.start && d < week.end }
        switch quest.kind {
        case .sessions: return facts.sessions.filter { inWeek($0.date) }.count
        case .minutes: return facts.sessions.filter { inWeek($0.date) }.map(\.minutes).reduce(0, +)
        case .drills: return facts.drillDates.filter(inWeek).count
        case .conditions: return Set(facts.conditionDays.filter(inWeek).map { calendar.startOfDay(for: $0) }).count
        case .journals: return facts.journalDates.filter(inWeek).count
        }
    }

    public static func weeklyProgress(now: Date, facts: QuestFacts, level: PlayerLevel?, calendar: Calendar = .current) -> [QuestProgress] {
        let w = week(containing: now, calendar: calendar)
        return weekly(weekStart: w.start, level: level).map { QuestProgress(quest: $0, done: done($0, facts: facts, week: w, calendar: calendar)) }
    }

    /// 이달 빙판 횟수.
    public static func monthDone(facts: QuestFacts, month: DateInterval) -> Int {
        facts.sessions.filter { $0.date >= month.start && $0.date < month.end }.count
    }

    /// 이달 퀘스트 포인트. 주는 시작 요일이 속한 달에 넣는다. 아직 안 온 주는 세지 않는다.
    public static func monthPoints(now: Date, facts: QuestFacts, level: PlayerLevel?, calendar: Calendar = .current) -> Int {
        let m = month(containing: now, calendar: calendar)
        var w = week(containing: m.start, calendar: calendar)
        var points = 0
        while w.start < m.end && w.start <= now {
            if w.start >= m.start {
                let completed = weekly(weekStart: w.start, level: level).filter { done($0, facts: facts, week: w, calendar: calendar) >= $0.target }.count
                points += completed * pointsPerQuest
            }
            w = DateInterval(start: w.end, duration: w.duration)
        }
        return points
    }

    // MARK: 배지

    public static func badgeKey(month: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: month)
        return String(format: "badge-%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// "badge-2026-11" → (2026, 11). 배지 키가 아니면 nil.
    public static func badgeMonth(_ key: String) -> (year: Int, month: Int)? {
        let parts = key.split(separator: "-")
        guard parts.count == 3, parts[0] == "badge", let y = Int(parts[1]), let m = Int(parts[2]), (1...12).contains(m) else { return nil }
        return (y, m)
    }

    public static func badgeTitle(_ key: String) -> String? {
        badgeMonth(key).map { "\($0.month)월 배지" }
    }
}
