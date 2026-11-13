import Foundation

/// 성장 화면 맨 위 추세 그래프. 기간을 같은 길이 칸으로 나눠 합치고, 바로 앞 같은 길이 기간과 견준다.
public enum TrendMetric: String, CaseIterable, Sendable {
    case sessions, minutes, drills

    public var title: String {
        switch self {
        case .sessions: return "횟수"
        case .minutes: return "탄 시간"
        case .drills: return "연습"
        }
    }

    public var unit: String {
        switch self {
        case .sessions: return "회"
        case .minutes: return "분"
        case .drills: return "번"
        }
    }
}

public struct Trend: Equatable, Sendable {
    public struct Bucket: Equatable, Sendable {
        public var start: Date
        public var current: Int
        /// 바로 앞 기간의 같은 자리 칸. '전체'면 nil.
        public var previous: Int?
    }

    public var buckets: [Bucket]
    public var total: Int
    public var previousTotal: Int?

    /// 칸 나누기: 7일=하루씩 7칸, 30일=6일씩 5칸, 90일=일주일씩 13칸(91일), 전체=달마다 최근 12칸.
    public static func build(_ items: [(at: Date, value: Int)], period: Period, now: Date,
                             calendar: Calendar = .current) -> Trend {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        func sum(_ from: Date, _ to: Date) -> Int {
            items.filter { $0.at >= from && $0.at < to }.reduce(0) { $0 + $1.value }
        }
        if period == .all {
            var buckets: [Bucket] = []
            let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            for i in (0..<12).reversed() {
                let s = calendar.date(byAdding: .month, value: -i, to: thisMonth)!
                let e = calendar.date(byAdding: .month, value: 1, to: s)!
                buckets.append(Bucket(start: s, current: sum(s, e), previous: nil))
            }
            return Trend(buckets: buckets, total: buckets.reduce(0) { $0 + $1.current }, previousTotal: nil)
        }
        let (days, count): (Int, Int) = {
            switch period {
            case .week: return (1, 7)
            case .month: return (6, 5)
            default: return (7, 13)
            }
        }()
        let span = days * count
        var buckets: [Bucket] = []
        for i in 0..<count {
            let s = calendar.date(byAdding: .day, value: -span + i * days, to: end)!
            let e = calendar.date(byAdding: .day, value: days, to: s)!
            let ps = calendar.date(byAdding: .day, value: -span, to: s)!
            let pe = calendar.date(byAdding: .day, value: -span, to: e)!
            buckets.append(Bucket(start: s, current: sum(s, e), previous: sum(ps, pe)))
        }
        return Trend(buckets: buckets,
                     total: buckets.reduce(0) { $0 + $1.current },
                     previousTotal: buckets.reduce(0) { $0 + ($1.previous ?? 0) })
    }

    /// "지난 30일보다 3회 늘었어" 같은 한 줄. 견줄 게 없으면 nil.
    public func comparison(_ metric: TrendMetric, periodTitle: String) -> String? {
        guard let p = previousTotal else { return nil }
        let d = total - p
        if p == 0 && total == 0 { return nil }
        if d == 0 { return "그 전 \(periodTitle)과 같아요." }
        return "그 전 \(periodTitle)보다 \(abs(d))\(metric.unit) \(d > 0 ? "늘었어요" : "줄었어요")."
    }
}
