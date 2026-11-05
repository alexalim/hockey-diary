import Foundation

/// 경기에서 기술 하나를 적용한 기록. tried=false(미시도)는 성공·실패 계산에서 빠진다 (FR-03, T03).
public struct AttemptRecord: Equatable, Sendable {
    public var sessionID: UUID
    public var tried: Bool
    public var outcome: AttemptOutcome?
    /// 시도 횟수. 비워 두면 1건의 적용 기록으로 센다 (7.1).
    public var count: Int?

    public init(sessionID: UUID, tried: Bool, outcome: AttemptOutcome? = nil, count: Int? = nil) {
        self.sessionID = sessionID
        self.tried = tried
        self.outcome = outcome
        self.count = count
    }
}

/// 기술 하나의 누적 지표. 숙련도·수업 수·경기 시도·성공을 서로 다른 수치로 보여 준다 (S04).
public struct SkillStats: Equatable, Sendable {
    /// 이 기술을 배운 수업 수 (같은 수업에 두 번 연결돼도 1회).
    public var lessonCount: Int
    /// "시도함"으로 저장한 경기 기록 수.
    public var triedEvents: Int
    /// 시도 횟수 합계. 횟수를 비운 기록은 1로 센다.
    public var attemptTotal: Int
    /// 기회가 없어 못 써본 기록 수. 실패가 아니다.
    public var untriedEvents: Int
    public var successes: Int
    public var partials: Int
    public var difficulties: Int

    /// 결과까지 입력해 평가 가능한 시도 기록 수.
    public var evaluated: Int { successes + partials + difficulties }

    /// 성공 / 평가 가능한 시도. 평가할 기록이 없으면 nil (0%와 구분).
    public var successRate: Double? {
        evaluated == 0 ? nil : Double(successes) / Double(evaluated)
    }

    public static func compute(lessonSessionIDs: [UUID], attempts: [AttemptRecord]) -> SkillStats {
        var stats = SkillStats(lessonCount: Set(lessonSessionIDs).count, triedEvents: 0, attemptTotal: 0,
                               untriedEvents: 0, successes: 0, partials: 0, difficulties: 0)
        for attempt in attempts {
            guard attempt.tried else {
                stats.untriedEvents += 1
                continue
            }
            stats.triedEvents += 1
            stats.attemptTotal += max(attempt.count ?? 1, 1)
            switch attempt.outcome {
            case .success: stats.successes += 1
            case .partial: stats.partials += 1
            case .difficult: stats.difficulties += 1
            case nil: break
            }
        }
        return stats
    }
}

/// 경기 기록을 만들 때 최근에 배운 기술을 추천한다 (F-A03). 사용자는 추가·삭제할 수 있다.
public enum SkillRecommender {
    public struct Learned: Sendable {
        public var skillID: UUID
        public var learnedAt: Date
        public init(skillID: UUID, learnedAt: Date) {
            self.skillID = skillID
            self.learnedAt = learnedAt
        }
    }

    /// 경기 시각 이전에 배운 기술을 최근 순으로, 중복 없이 최대 limit개.
    public static func recent(_ learned: [Learned], before date: Date, within days: Int = 30, limit: Int = 6) -> [UUID] {
        let from = date.addingTimeInterval(-Double(days) * 86_400)
        var seen = Set<UUID>()
        return learned
            .filter { $0.learnedAt <= date && $0.learnedAt >= from }
            .sorted { $0.learnedAt > $1.learnedAt }
            .compactMap { seen.insert($0.skillID).inserted ? $0.skillID : nil }
            .prefix(limit)
            .map { $0 }
    }
}
