import Foundation

/// 시작·종료 구간.
public struct TimeSpan: Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    public var minutes: Int { Int((end.timeIntervalSince(start) / 60).rounded()) }

    public func overlapSeconds(with other: TimeSpan) -> TimeInterval {
        max(0, min(end, other.end).timeIntervalSince(max(start, other.start)))
    }
}

/// 같은 활동을 여러 기기가 쟀을 때 시간을 한 번만 합산한다 (9.2, T04).
public enum TimeMerge {
    /// 겹치는 구간을 합집합으로 만든 뒤 총 분을 센다.
    public static func unionMinutes(_ spans: [TimeSpan]) -> Int {
        let sorted = spans.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: TimeSpan?
        for span in sorted {
            if let cur = current, span.start <= cur.end {
                current = TimeSpan(start: cur.start, end: max(cur.end, span.end))
            } else {
                if let cur = current { total += cur.end.timeIntervalSince(cur.start) }
                current = span
            }
        }
        if let cur = current { total += cur.end.timeIntervalSince(cur.start) }
        return Int((total / 60).rounded())
    }

    /// 짧은 쪽 구간의 절반 이상이 겹치면 같은 활동일 가능성이 높아 병합 후보로 제안한다.
    /// 사용자 확인 전에는 아무것도 지우지 않는다.
    public static func isMergeCandidate(_ a: TimeSpan, _ b: TimeSpan, ratio: Double = 0.5) -> Bool {
        let shorter = min(a.end.timeIntervalSince(a.start), b.end.timeIntervalSince(b.start))
        guard shorter > 0 else { return false }
        return a.overlapSeconds(with: b) / shorter >= ratio
    }
}
