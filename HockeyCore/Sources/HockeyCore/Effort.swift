import Foundation

/// 심박 표본 하나.
public struct HeartSample: Equatable, Sendable {
    public var at: Date
    public var bpm: Double
    public init(at: Date, bpm: Double) { self.at = at; self.bpm = bpm }
}

/// 심박 구간(최고 심박 대비 %). 5단계.
public enum HeartZones {
    public static let bounds: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9]
    public static let titles = ["가볍게", "편안", "유산소", "힘듦", "전력"]

    /// 표본 사이 시간을 그 표본의 구간에 더한다. 결과는 구간별 초(5칸). 60% 미만은 0번 칸.
    public static func seconds(_ samples: [HeartSample], maxHR: Double) -> [Int] {
        var out = [0, 0, 0, 0, 0]
        guard maxHR > 0, samples.count >= 2 else { return out }
        let s = samples.sorted { $0.at < $1.at }
        for i in 0..<(s.count - 1) {
            let dt = min(s[i + 1].at.timeIntervalSince(s[i].at), 60)   // 표본이 끊긴 구간은 60초까지만
            guard dt > 0 else { continue }
            out[zoneIndex(s[i].bpm / maxHR)] += Int(dt.rounded())
        }
        return out
    }

    public static func zoneIndex(_ ratio: Double) -> Int {
        var idx = 0
        for (i, b) in bounds.enumerated() where ratio >= b { idx = i }
        return min(max(idx, 0), 4)
    }
}

/// 심박으로 쉬프트(얼음 위 구간)를 짐작한다. 실험 기능이라 '짐작'으로만 보여준다.
public enum ShiftDetector {
    /// 심박이 높게 유지된 구간을 찾는다.
    /// 기준선: 20번째 백분위(벤치)와 90번째 백분위(얼음) 사이의 중간. 그 위로 minimumSeconds 이상 이어지면 한 쉬프트.
    /// mergeGapSeconds 안에서 끊긴 건 같은 쉬프트로 잇는다.
    public static func estimate(_ samples: [HeartSample], minimumSeconds: TimeInterval = 30,
                                mergeGapSeconds: TimeInterval = 20) -> [TimeSpan] {
        let s = samples.sorted { $0.at < $1.at }
        guard s.count >= 6 else { return [] }
        let sorted = s.map(\.bpm).sorted()
        let low = sorted[Int(Double(sorted.count - 1) * 0.2)]
        let high = sorted[Int(Double(sorted.count - 1) * 0.9)]
        guard high - low >= 15 else { return [] }   // 심박 차이가 작으면 쉬프트를 나눌 수 없다
        let threshold = low + (high - low) * 0.5

        var spans: [TimeSpan] = []
        var start: Date?
        var lastHigh: Date?
        for p in s {
            if p.bpm >= threshold {
                if start == nil { start = p.at }
                lastHigh = p.at
            } else if let st = start, let lh = lastHigh, p.at.timeIntervalSince(lh) > mergeGapSeconds {
                spans.append(TimeSpan(start: st, end: lh))
                start = nil; lastHigh = nil
            }
        }
        if let st = start, let lh = lastHigh { spans.append(TimeSpan(start: st, end: lh)) }
        return spans.filter { $0.end.timeIntervalSince($0.start) >= minimumSeconds }
    }

    public static func onIceSeconds(_ spans: [TimeSpan]) -> Int {
        Int(spans.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }.rounded())
    }
}

/// 워치가 잰 운동량 요약(아이폰 화면용).
public struct EffortSummary: Equatable, Sendable {
    public var shifts: Int?
    public var onIceMinutes: Int?
    public var distanceMeters: Double?
    public var kilocalories: Double?

    public init(shifts: Int? = nil, onIceMinutes: Int? = nil, distanceMeters: Double? = nil, kilocalories: Double? = nil) {
        self.shifts = shifts; self.onIceMinutes = onIceMinutes; self.distanceMeters = distanceMeters; self.kilocalories = kilocalories
    }

    public var lines: [String] {
        var out: [String] = []
        if let s = shifts, s > 0 { out.append("쉬프트 \(s)번") }
        if let m = onIceMinutes, m > 0 { out.append("얼음 위 \(m)분") }
        if let d = distanceMeters, d >= 100 { out.append(String(format: "%.1fkm", d / 1000)) }
        if let k = kilocalories, k > 0 { out.append("\(Int(k.rounded()))kcal") }
        return out
    }
}
