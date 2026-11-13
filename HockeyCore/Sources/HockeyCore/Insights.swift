import Foundation

/// 분석에 쓰는 활동 한 건의 요약.
public struct ActivitySample: Equatable, Sendable {
    public var sessionID: UUID
    public var at: Date
    public var type: ActivityType
    public var surface: SurfaceType
    public var minutes: Int
    public var moodBefore: Int?
    public var moodAfter: Int?

    public init(sessionID: UUID, at: Date, type: ActivityType, surface: SurfaceType, minutes: Int,
                moodBefore: Int? = nil, moodAfter: Int? = nil) {
        self.sessionID = sessionID
        self.at = at
        self.type = type
        self.surface = surface
        self.minutes = minutes
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
    }
}

/// 건수·시간 묶음.
public struct CountMinutes: Equatable, Sendable {
    public var count: Int = 0
    public var minutes: Int = 0
    public init(count: Int = 0, minutes: Int = 0) {
        self.count = count
        self.minutes = minutes
    }
}

public enum Insights {
    /// 기간 안의 활동만 남긴다. 같은 활동은 한 번만.
    public static func inPeriod(_ samples: [ActivitySample], from: Date?, to: Date) -> [ActivitySample] {
        var seen = Set<UUID>()
        return samples.filter { s in
            (from == nil || s.at >= from!) && s.at <= to && seen.insert(s.sessionID).inserted
        }
    }

    public static func byType(_ samples: [ActivitySample]) -> [ActivityType: CountMinutes] {
        var out: [ActivityType: CountMinutes] = [:]
        for s in samples {
            out[s.type, default: CountMinutes()].count += 1
            out[s.type, default: CountMinutes()].minutes += max(s.minutes, 0)
        }
        return out
    }

    /// 빙판 유형별 집계. '나중에 선택'은 따로 남겨 미입력으로 보여 준다 (ICE-04, T21).
    public static func bySurface(_ samples: [ActivitySample]) -> [SurfaceType: CountMinutes] {
        var out: [SurfaceType: CountMinutes] = [:]
        for s in samples {
            out[s.surface, default: CountMinutes()].count += 1
            out[s.surface, default: CountMinutes()].minutes += max(s.minutes, 0)
        }
        return out
    }

    /// 운동 전후 기분이 둘 다 있는 활동만 비교한다 (7.1 기분 변화).
    public struct MoodChange: Equatable, Sendable {
        public var paired: Int
        public var improved: Int
        public var same: Int
        public var worse: Int
        public var averageDelta: Double?
        public var sufficiency: Sufficiency

        /// 관찰된 사실만 말한다. 원인을 단정하지 않는다 (7.2).
        public var sentence: String? {
            guard sufficiency.isSufficient else { return nil }
            return "운동 전후 기분을 다 남긴 \(paired)번 중 \(improved)번은 운동하고 기분이 나아졌어요."
        }
    }

    public static func moodChange(_ samples: [ActivitySample], minimum: Int = Sufficiency.defaultMinimum) -> MoodChange {
        let pairs = samples.compactMap { s -> Int? in
            guard let b = Mood.clamp(s.moodBefore), let a = Mood.clamp(s.moodAfter) else { return nil }
            return a - b
        }
        let improved = pairs.filter { $0 > 0 }.count
        let worse = pairs.filter { $0 < 0 }.count
        let avg = pairs.isEmpty ? nil : Double(pairs.reduce(0, +)) / Double(pairs.count)
        return MoodChange(paired: pairs.count, improved: improved, same: pairs.count - improved - worse,
                          worse: worse, averageDelta: avg, sufficiency: Sufficiency(count: pairs.count, minimum: minimum))
    }

    /// 기간 설명 + 표본 수 + 출처를 붙인다. 분석 요약에는 이 셋이 반드시 따라간다 (7.2).
    public static func footnote(periodTitle: String, count: Int, source: String = "직접 입력") -> String {
        "\(periodTitle) · 기록 \(count)건 · \(source)"
    }
}

/// 분석 기간 필터.
public enum Period: String, CaseIterable, Sendable {
    case week, month, quarter, all

    public var title: String {
        switch self {
        case .week: return "7일"
        case .month: return "30일"
        case .quarter: return "90일"
        case .all: return "전체"
        }
    }

    public var longTitle: String {
        switch self {
        case .week: return "최근 7일"
        case .month: return "최근 30일"
        case .quarter: return "최근 90일"
        case .all: return "전체 기간"
        }
    }

    public func start(from now: Date, calendar: Calendar = .current) -> Date? {
        let days: Int
        switch self {
        case .week: days = 7
        case .month: days = 30
        case .quarter: days = 90
        case .all: return nil
        }
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today)
    }
}
