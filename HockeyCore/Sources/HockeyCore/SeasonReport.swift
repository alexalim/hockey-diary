import Foundation

/// 공유용 시즌 리포트. 하키 활동 숫자와 기술 이름, 그리고 사용자가 '리포트 공유'를 켠 일기 한 줄만 담는다.
/// 기분 메모·수면·심박·생리·사진·장소 좌표는 담을 칸이 없다 — 공유 페이로드에서 구조적으로 제외 (11.2, T09).
public struct SeasonReport: Equatable, Sendable {
    public struct SkillLine: Equatable, Sendable {
        public let name: String
        public let lessons: Int
        public let tried: Int
    }

    public var title: String
    public var from: Date?
    public var to: Date
    public var sessions: Int
    public var minutes: Int
    public var byType: [ActivityType: Int]
    public var bySurface: [SurfaceType: Int]
    public var skillsLearned: Int
    public var topSkills: [SkillLine]
    /// 운동 후 기분을 가장 좋게(5) 남긴 날 수. 기분 값 자체는 내보내지 않는다.
    public var bestDays: Int
    /// '리포트 공유'를 켠 일기에서 고른 한 줄(최근 것부터 최대 2개, 40자까지).
    public var sharedLines: [String]

    /// 사용자가 리포트에 넣어도 된다고 고른 일기 한 줄.
    public struct SharedLine: Sendable {
        public let at: Date
        public let text: String
        public init(at: Date, text: String) { self.at = at; self.text = text }
    }

    public struct SkillEvent: Sendable {
        public let skill: String
        public let at: Date
        public let lesson: Bool
        public let tried: Bool
        public init(skill: String, at: Date, lesson: Bool, tried: Bool) {
            self.skill = skill; self.at = at; self.lesson = lesson; self.tried = tried
        }
    }

    public static func make(title: String, from: Date?, to: Date,
                            samples: [ActivitySample], skillEvents: [SkillEvent],
                            sharedLines: [SharedLine] = [], topCount: Int = 3) -> SeasonReport {
        let s = Insights.inPeriod(samples, from: from, to: to)
        let events = skillEvents.filter { (from == nil || $0.at >= from!) && $0.at <= to }
        var lessons: [String: Int] = [:], tried: [String: Int] = [:]
        for e in events {
            if e.lesson { lessons[e.skill, default: 0] += 1 } else if e.tried { tried[e.skill, default: 0] += 1 }
        }
        let names = Set(lessons.keys).union(tried.keys)
        let top = names.map { SkillLine(name: $0, lessons: lessons[$0] ?? 0, tried: tried[$0] ?? 0) }
            .sorted { ($0.lessons + $0.tried, $0.name) > ($1.lessons + $1.tried, $1.name) }
        return SeasonReport(
            title: title, from: from, to: to,
            sessions: s.count,
            minutes: s.reduce(0) { $0 + max($1.minutes, 0) },
            byType: Insights.byType(s).mapValues(\.count),
            bySurface: Insights.bySurface(s).mapValues(\.count),
            skillsLearned: lessons.count,
            topSkills: Array(top.prefix(topCount)),
            bestDays: s.filter { $0.moodAfter == 5 }.count,
            sharedLines: sharedLines
                .filter { (from == nil || $0.at >= from!) && $0.at <= to }
                .sorted { $0.at > $1.at }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(2)
                .map { $0.count > 40 ? String($0.prefix(40)) + "…" : $0 })
    }
}
