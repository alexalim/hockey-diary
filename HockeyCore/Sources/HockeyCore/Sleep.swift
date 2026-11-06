import Foundation

/// 건강 앱의 '잠든' 구간 하나.
public struct SleepSegment: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) {
        self.start = min(start, end)
        self.end = max(start, end)
    }
}

/// 활동 직전의 한 번의 잠(여러 구간 묶음).
public struct SleepNight: Equatable, Sendable {
    public var start: Date
    public var end: Date
    /// 겹치는 구간(워치·가민이 같이 쓴 기록)은 한 번만 센 실제 잠든 시간.
    public var asleepMinutes: Int
}

public enum SleepAttribution {
    /// 활동 시작 직전의 잠을 찾는다 (F-C03, T07).
    /// - 활동 시작 전에 끝났고, 활동 lookback 시간 안에 끝난 구간만 본다.
    /// - 사이가 gap 이하인 구간은 한 번의 잠으로 묶는다(자정을 넘겨도 하나).
    /// - 3시간 이상인 묶음 중 가장 늦은 것을 고른다. 낮잠만 있으면 가장 늦은 묶음.
    public static func nightBefore(_ activityStart: Date, segments: [SleepSegment],
                                   gapMinutes: Double = 120, lookbackHours: Double = 20) -> SleepNight? {
        let from = activityStart.addingTimeInterval(-lookbackHours * 3600)
        let candidates = segments
            .filter { $0.end <= activityStart && $0.end >= from }
            .sorted { $0.start < $1.start }
        guard !candidates.isEmpty else { return nil }

        var clusters: [[SleepSegment]] = []
        for seg in candidates {
            if let lastEnd = clusters.last?.map(\.end).max(),
               seg.start <= lastEnd.addingTimeInterval(gapMinutes * 60) {
                clusters[clusters.count - 1].append(seg)
            } else {
                clusters.append([seg])
            }
        }
        let nights = clusters.map { c in
            SleepNight(start: c.map(\.start).min()!, end: c.map(\.end).max()!,
                       asleepMinutes: TimeMerge.unionMinutes(c.map { TimeSpan(start: $0.start, end: $0.end) }))
        }
        return nights.last(where: { $0.asleepMinutes >= 180 }) ?? nights.last
    }
}

/// 수면 시간과 운동 후 기분을 나란히 놓은 비교. 관찰된 경향만 말하고 원인을 단정하지 않는다 (7.2).
public struct SleepMoodComparison: Equatable, Sendable {
    public var thresholdMinutes: Int
    public var longCount: Int
    public var shortCount: Int
    public var longAverage: Double?
    public var shortAverage: Double?
    public var sufficiency: Sufficiency

    public static func compute(_ pairs: [(sleepMinutes: Int, moodAfter: Int?)],
                               thresholdMinutes: Int = 420, minimumPerGroup: Int = 3) -> SleepMoodComparison {
        let valid = pairs.compactMap { p in Mood.clamp(p.moodAfter).map { (p.sleepMinutes, $0) } }
        let long = valid.filter { $0.0 >= thresholdMinutes }.map(\.1)
        let short = valid.filter { $0.0 < thresholdMinutes }.map(\.1)
        func avg(_ xs: [Int]) -> Double? { xs.isEmpty ? nil : Double(xs.reduce(0, +)) / Double(xs.count) }
        let smaller = min(long.count, short.count)
        return SleepMoodComparison(thresholdMinutes: thresholdMinutes, longCount: long.count, shortCount: short.count,
                                   longAverage: avg(long), shortAverage: avg(short),
                                   sufficiency: Sufficiency(count: smaller, minimum: minimumPerGroup))
    }

    public var sentence: String? {
        guard sufficiency.isSufficient, let l = longAverage, let s = shortAverage else { return nil }
        let hours = thresholdMinutes / 60
        let total = longCount + shortCount
        let compare: String
        if l - s >= 0.3 { compare = "더 높게" } else if s - l >= 0.3 { compare = "더 낮게" } else { compare = "비슷하게" }
        return "최근 \(total)번 중 \(hours)시간 이상 잔 날(\(longCount)번)의 운동 후 기분이 덜 잔 날(\(shortCount)번)보다 \(compare) 기록됐어."
    }
}

/// 생리 기간에 한 활동과 다른 날 활동의 피로도(자기평가) 비교. 별도 동의한 사람에게만 보여준다 (F-C04).
/// 관찰된 차이만 말하고, 운동 강도를 처방하거나 원인을 단정하지 않는다 (7.2, 12.3).
public struct CycleFatigueComparison: Equatable, Sendable {
    public var periodCount: Int
    public var otherCount: Int
    public var periodAverage: Double?
    public var otherAverage: Double?
    public var sufficiency: Sufficiency

    public static func compute(_ pairs: [(inPeriod: Bool, fatigue: Int?)], minimumPerGroup: Int = 3) -> CycleFatigueComparison {
        let valid = pairs.compactMap { p in p.fatigue.flatMap { (1...5).contains($0) ? (p.inPeriod, $0) : nil } }
        let a = valid.filter { $0.0 }.map(\.1), b = valid.filter { !$0.0 }.map(\.1)
        func avg(_ xs: [Int]) -> Double? { xs.isEmpty ? nil : Double(xs.reduce(0, +)) / Double(xs.count) }
        return CycleFatigueComparison(periodCount: a.count, otherCount: b.count, periodAverage: avg(a), otherAverage: avg(b),
                                      sufficiency: Sufficiency(count: min(a.count, b.count), minimum: minimumPerGroup))
    }

    public var sentence: String? {
        guard sufficiency.isSufficient, let p = periodAverage, let o = otherAverage else { return nil }
        let compare = p - o >= 0.3 ? "더 높게" : (o - p >= 0.3 ? "더 낮게" : "비슷하게")
        return "생리 기간에 한 활동(\(periodCount)번)의 피로도가 다른 날(\(otherCount)번)보다 \(compare) 기록됐어."
    }
}
