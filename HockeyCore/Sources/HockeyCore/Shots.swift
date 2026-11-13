import Foundation

/// 슛 하나의 결과.
public enum ShotOutcome: String, CaseIterable, Codable, Sendable {
    case goal, saved, missed, blocked

    public var title: String {
        switch self {
        case .goal: return "골"
        case .saved: return "막힘"
        case .missed: return "빗나감"
        case .blocked: return "블록"
        }
    }

    /// 골대 안으로 간 슛(골 또는 골키퍼가 막음).
    public var onTarget: Bool { self == .goal || self == .saved }
}

/// 공격 지역 반쪽 링크 그림 위의 구역. 좌표는 0~1 정규화(x: 왼쪽→오른쪽, y: 골라인 쪽 0 → 블루라인 쪽 1).
public enum ShotZone: String, CaseIterable, Sendable {
    case slot, leftCircle, rightCircle, point, nearGoalLine

    public var title: String {
        switch self {
        case .slot: return "슬롯"
        case .leftCircle: return "왼쪽 서클"
        case .rightCircle: return "오른쪽 서클"
        case .point: return "포인트"
        case .nearGoalLine: return "골라인 근처"
        }
    }

    /// 그림 좌표로 구역을 정한다. 골라인은 y≈0.12, 블루라인은 y≈0.95.
    public static func classify(x: Double, y: Double) -> ShotZone {
        if y < 0.14 { return .nearGoalLine }
        if y >= 0.62 { return .point }
        if x < 0.32 { return .leftCircle }
        if x > 0.68 { return .rightCircle }
        return .slot
    }
}

/// 슛 표시 하나.
public struct ShotPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var outcome: ShotOutcome

    public init(x: Double, y: Double, outcome: ShotOutcome) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
        self.outcome = outcome
    }

    public var zone: ShotZone { ShotZone.classify(x: x, y: y) }
}

/// 슛 통계. 성공률은 골 / 전체 슛. 평가할 슛이 없으면 nil(0%와 구분).
public struct ShotStats: Equatable, Sendable {
    public struct ZoneLine: Equatable, Sendable {
        public var shots: Int = 0
        public var goals: Int = 0
        public var rate: Double? { shots == 0 ? nil : Double(goals) / Double(shots) }
    }

    public var total: Int
    public var goals: Int
    public var onTarget: Int
    public var byZone: [ShotZone: ZoneLine]

    public var shootingRate: Double? { total == 0 ? nil : Double(goals) / Double(total) }

    public static func compute(_ shots: [ShotPoint]) -> ShotStats {
        var zones: [ShotZone: ZoneLine] = [:]
        for s in shots {
            zones[s.zone, default: ZoneLine()].shots += 1
            if s.outcome == .goal { zones[s.zone, default: ZoneLine()].goals += 1 }
        }
        return ShotStats(total: shots.count,
                         goals: shots.filter { $0.outcome == .goal }.count,
                         onTarget: shots.filter { $0.outcome.onTarget }.count,
                         byZone: zones)
    }

    /// 슛이 가장 많이 들어간 구역(3번 이상 쏜 곳만). 없으면 nil.
    public func bestZone(minimumShots: Int = 3) -> ShotZone? {
        byZone.filter { $0.value.shots >= minimumShots && $0.value.goals > 0 }
            .max { ($0.value.rate ?? 0, $0.value.shots) < ($1.value.rate ?? 0, $1.value.shots) }?.key
    }

    /// 관찰 사실만 말한다. 표본이 모자라면 nil.
    public func sentence(minimumShots: Int = 3) -> String? {
        guard total >= minimumShots else { return nil }
        if let z = bestZone(minimumShots: minimumShots), let line = byZone[z], let r = line.rate {
            return "슛 \(total)번 중 \(goals)골. \(z.title)에서 \(line.shots)번 쏴서 \(line.goals)골(\(Int((r * 100).rounded()))%)로 가장 잘 들어갔어요."
        }
        return "슛 \(total)번 중 \(goals)골이에요. 골대 안으로 간 건 \(onTarget)번."
    }
}

/// 골리 기록. 세이브율 = 세이브 / (세이브 + 실점).
public struct GoalieStats: Equatable, Sendable {
    public var saves: Int
    public var goalsAgainst: Int

    public init(saves: Int, goalsAgainst: Int) {
        self.saves = max(saves, 0)
        self.goalsAgainst = max(goalsAgainst, 0)
    }

    public var shotsFaced: Int { saves + goalsAgainst }
    public var savePct: Double? { shotsFaced == 0 ? nil : Double(saves) / Double(shotsFaced) }

    /// 여러 경기를 합친다.
    public static func sum(_ games: [GoalieStats]) -> GoalieStats {
        GoalieStats(saves: games.reduce(0) { $0 + $1.saves }, goalsAgainst: games.reduce(0) { $0 + $1.goalsAgainst })
    }

    public var savePctText: String {
        guard let p = savePct else { return "–" }
        return String(format: "%.1f%%", p * 100)
    }
}
