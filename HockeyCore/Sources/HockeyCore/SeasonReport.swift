import Foundation

/// 공유용 시즌 리포트. 하키 활동 숫자와 기술 이름만 담는다.
/// 일기·감정 메모·수면·심박·생리·사진·장소 좌표는 담을 칸이 없다 — 공유 페이로드에서 구조적으로 제외 (11.2, T09).
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
                            samples: [ActivitySample], skillEvents: [SkillEvent], topCount: Int = 3) -> SeasonReport {
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
            bestDays: s.filter { $0.moodAfter == 5 }.count)
    }
}
