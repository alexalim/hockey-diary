import Foundation

/// 활동 하나에서 실제로 쓴 장비와 얼음 위 시간.
public struct UsageRecord: Equatable, Sendable {
    public var sessionID: UUID
    public var at: Date
    public var skateID: UUID?
    public var runnerID: UUID?
    public var iceMinutes: Int

    public init(sessionID: UUID, at: Date, skateID: UUID?, runnerID: UUID?, iceMinutes: Int) {
        self.sessionID = sessionID
        self.at = at
        self.skateID = skateID
        self.runnerID = runnerID
        self.iceMinutes = iceMinutes
    }
}

public enum EquipmentMath {
    /// 같은 활동 기록이 여러 번 연결돼도 활동당 1회만 센다 (FR-16).
    private static func dedupedBySession(_ usages: [UsageRecord]) -> [UsageRecord] {
        var seen = Set<UUID>()
        return usages.filter { seen.insert($0.sessionID).inserted }
    }

    /// 그 러너의 마지막 연마 이후 얼음 위 시간만 더한다 (7.1 연마 누적 시간, T11·T13).
    public static func iceMinutesSinceSharpening(runnerID: UUID, usages: [UsageRecord], lastSharpenedAt: Date?) -> Int {
        dedupedBySession(usages.filter { $0.runnerID == runnerID })
            .filter { lastSharpenedAt == nil || $0.at > lastSharpenedAt! }
            .reduce(0) { $0 + max($1.iceMinutes, 0) }
    }

    /// 그 러너로 마지막 연마 이후 몇 번 탔는지. 같은 활동은 한 번만 센다.
    public static func sessionsSinceSharpening(runnerID: UUID, usages: [UsageRecord], lastSharpenedAt: Date?) -> Int {
        dedupedBySession(usages.filter { $0.runnerID == runnerID })
            .filter { lastSharpenedAt == nil || $0.at > lastSharpenedAt! }
            .count
    }

    /// 시간 기준·횟수 기준 중 하나라도 정해둔 값에 닿으면 알린다. 둘 다 없으면 알리지 않는다.
    public static func needsCheck(minutesSince: Int, sessionsSince: Int, thresholdMinutes: Int?, thresholdSessions: Int?) -> Bool {
        if let t = thresholdSessions, t > 0, sessionsSince >= t { return true }
        return needsCheck(minutesSince: minutesSince, thresholdMinutes: thresholdMinutes)
    }

    /// 스케이트별 누적 얼음 시간. 그 스케이트를 고른 활동에만 귀속한다 (T13).
    public static func iceMinutes(skateID: UUID, usages: [UsageRecord]) -> Int {
        dedupedBySession(usages.filter { $0.skateID == skateID })
            .reduce(0) { $0 + max($1.iceMinutes, 0) }
    }

    /// 사용자가 정한 점검 기준(분)에 다다랐는지. 기준이 없으면 알리지 않는다.
    /// 단일 연마 주기를 최적값으로 제시하지 않는다 (8.1 금지 항목).
    public static func needsCheck(minutesSince: Int, thresholdMinutes: Int?) -> Bool {
        guard let threshold = thresholdMinutes, threshold > 0 else { return false }
        return minutesSince >= threshold
    }
}

/// 러너 장착 구간. to가 nil이면 지금도 장착 중.
public struct InstallSpan: Equatable, Sendable {
    public var runnerID: UUID
    public var skateID: UUID
    public var from: Date
    public var to: Date?

    public init(runnerID: UUID, skateID: UUID, from: Date, to: Date?) {
        self.runnerID = runnerID
        self.skateID = skateID
        self.from = from
        self.to = to
    }

    func overlaps(_ other: InstallSpan) -> Bool {
        let aEnd = to ?? .distantFuture
        let bEnd = other.to ?? .distantFuture
        return from < bEnd && other.from < aEnd
    }
}

public enum InstallError: Error, Equatable {
    /// 같은 러너가 같은 시점에 다른 부츠에 장착돼 있다 (T14).
    case runnerAlreadyInstalled(onSkate: UUID)
    case invalidRange
}

public enum InstallPlanner {
    /// 새 장착 구간이 기존 이력과 충돌하는지 검사한다.
    public static func validate(_ new: InstallSpan, existing: [InstallSpan]) -> Result<Void, InstallError> {
        if let to = new.to, to <= new.from { return .failure(.invalidRange) }
        if let clash = existing.first(where: { $0.runnerID == new.runnerID && $0.overlaps(new) }) {
            return .failure(.runnerAlreadyInstalled(onSkate: clash.skateID))
        }
        return .success(())
    }

    /// 러너 교체: 부츠에 지금 달린 러너의 구간을 닫고 새 러너를 단다.
    /// 반환값은 닫아야 할 기존 구간의 인덱스와 새 구간. 충돌하면 에러.
    public static func swap(onto skateID: UUID, runnerID: UUID, at date: Date,
                            existing: [InstallSpan]) -> Result<(closing: [Int], new: InstallSpan), InstallError> {
        // 이 부츠에 열려 있는 구간과, 다른 부츠에 열려 있던 같은 러너의 구간을 함께 닫는다.
        let closing = existing.indices.filter { i in
            let s = existing[i]
            return s.to == nil && (s.skateID == skateID || s.runnerID == runnerID) && s.from < date
        }
        var trimmed = existing
        for i in closing { trimmed[i].to = date }
        let new = InstallSpan(runnerID: runnerID, skateID: skateID, from: date, to: nil)
        switch validate(new, existing: trimmed) {
        case .success: return .success((closing, new))
        case .failure(let e): return .failure(e)
        }
    }
}

/// "연마한 지 얼마나 됐는지"를 날짜 단위로 쉽게 말한다(얼음 위에서 탄 시간과 따로 보여준다).
public enum ElapsedText {
    public static func since(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "오늘"
        case 1: return "어제"
        case 2..<14: return "\(days)일 전"
        case 14..<60: return "\(days / 7)주 전"
        case 60..<365:
            let months = max(2, calendar.dateComponents([.month], from: date, to: now).month ?? days / 30)
            return "\(months)개월 전"
        default:
            let years = max(1, calendar.dateComponents([.year], from: date, to: now).year ?? days / 365)
            return "\(years)년 전"
        }
    }
}

/// 날(러너) 교체 시기. 연마할수록 날이 깎이므로 연마 횟수나 사용 기간으로 본다.
/// 정답 주기는 없어서 사용자가 정한 기준에 닿을 때만 알린다.
public enum RunnerLife {
    public static func monthsUsed(since start: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.month], from: start, to: now).month ?? 0)
    }

    public static func needsReplacement(sharpenings: Int, monthsUsed: Int,
                                        afterSharpenings: Int?, afterMonths: Int?) -> Bool {
        if let n = afterSharpenings, n > 0, sharpenings >= n { return true }
        if let m = afterMonths, m > 0, monthsUsed >= m { return true }
        return false
    }
}
