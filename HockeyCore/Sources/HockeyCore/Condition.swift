import Foundation

/// 하루치 컨디션. 모르는 값은 nil(빈칸은 나쁜 날이 아니다).
public struct ConditionDay: Equatable, Sendable {
    public var day: Date
    public var sleepMinutes: Int?
    public var restingHR: Double?
    public var hrv: Double?
    public var mood: Int?
    public var fatigue: Int?
    /// 하키 안 탄 날도 남기는 '오늘 몸 상태' 1~5.
    public var body: Int?
    public var skated: Bool
    public var period: Bool

    public init(day: Date, sleepMinutes: Int? = nil, restingHR: Double? = nil, hrv: Double? = nil,
                mood: Int? = nil, fatigue: Int? = nil, body: Int? = nil, skated: Bool = false, period: Bool = false) {
        self.day = day; self.sleepMinutes = sleepMinutes; self.restingHR = restingHR; self.hrv = hrv
        self.mood = mood; self.fatigue = fatigue; self.body = body; self.skated = skated; self.period = period
    }
}

public enum ConditionMetric: String, CaseIterable, Sendable {
    case sleep, restingHR, hrv, mood, fatigue, body

    public var title: String {
        switch self {
        case .sleep: return "잔 시간"
        case .restingHR: return "안정 심박"
        case .hrv: return "심박 변이도"
        case .mood: return "기분"
        case .fatigue: return "힘듦"
        case .body: return "몸 상태"
        }
    }

    /// 무엇을 재는지 한 줄 풀이.
    public var help: String {
        switch self {
        case .sleep: return "그날 아침까지 잠든 시간. 낮잠도 더해요."
        case .restingHR: return "가만히 있을 때 심박. Apple Watch가 하루 한 번 재요."
        case .hrv: return "심박 사이 간격이 얼마나 흔들리는지. 보통 쉬면 오르고 지치면 내려가요. 사람마다 크게 달라서 내 평소와만 견줘요."
        case .mood: return "기록과 일기에 남긴 기분 1~5."
        case .fatigue: return "기록에 남긴 '얼마나 힘들었어요?' 1~5."
        case .body: return "홈에서 남긴 '오늘 몸 상태' 1~5."
        }
    }

    public func value(_ d: ConditionDay) -> Double? {
        switch self {
        case .sleep: return d.sleepMinutes.map(Double.init)
        case .restingHR: return d.restingHR
        case .hrv: return d.hrv
        case .mood: return d.mood.map(Double.init)
        case .fatigue: return d.fatigue.map(Double.init)
        case .body: return d.body.map(Double.init)
        }
    }

    public func text(_ v: Double) -> String {
        switch self {
        case .sleep:
            let m = Int(v.rounded()); return m % 60 == 0 ? "\(m / 60)시간" : "\(m / 60)시간 \(m % 60)분"
        case .restingHR: return "\(Int(v.rounded()))bpm"
        case .hrv: return "\(Int(v.rounded()))ms"
        default: return String(format: "%.1f", v)
        }
    }
}

public enum ConditionTrack {
    /// 잠든 구간을 '깬 날' 기준으로 하루씩 합친다. 2시간 안에 이어지면 한 번의 잠, 겹치는 기록은 한 번만 센다.
    public static func sleepByWakeDay(_ segments: [SleepSegment], calendar: Calendar = .current) -> [Date: Int] {
        let sorted = segments.sorted { $0.start < $1.start }
        var clusters: [[SleepSegment]] = []
        for seg in sorted {
            if let lastEnd = clusters.last?.map(\.end).max(), seg.start <= lastEnd.addingTimeInterval(2 * 3600) {
                clusters[clusters.count - 1].append(seg)
            } else {
                clusters.append([seg])
            }
        }
        var out: [Date: Int] = [:]
        for c in clusters {
            let day = calendar.startOfDay(for: c.map(\.end).max()!)
            out[day, default: 0] += TimeMerge.unionMinutes(c.map { TimeSpan(start: $0.start, end: $0.end) })
        }
        return out
    }

    /// 평소와 다른 점을 한 줄씩. 최근 7일을 그 앞 28일(평소)과 견준다. 평소 자료가 7일 미만이면 말하지 않는다.
    /// 원인을 말하거나 운동을 하라·말라 하지 않는다.
    public static func unusual(_ days: [ConditionDay], now: Date, calendar: Calendar = .current) -> [String] {
        let today = calendar.startOfDay(for: now)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let baseStart = calendar.date(byAdding: .day, value: -34, to: today) else { return [] }
        let recent = days.filter { $0.day >= weekStart && $0.day <= today }
        let base = days.filter { $0.day >= baseStart && $0.day < weekStart }
        func values(_ list: [ConditionDay], _ m: ConditionMetric) -> [Double] { list.compactMap { m.value($0) } }
        func median(_ v: [Double]) -> Double {
            let s = v.sorted(); return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
        }
        var out: [String] = []

        let bSleep = values(base, .sleep)
        if bSleep.count >= 7 {
            let usual = median(bSleep)
            let short = values(recent, .sleep).filter { $0 < usual - 60 }.count
            if short >= 2 { out.append("잠이 평소보다 1시간 넘게 적은 날이 최근 7일에 \(short)번이에요.") }
        }
        let bHR = values(base, .restingHR), rHR = values(recent, .restingHR)
        if bHR.count >= 7, rHR.count >= 3 {
            let diff = rHR.reduce(0, +) / Double(rHR.count) - median(bHR)
            if diff >= 5 { out.append("안정 심박이 평소보다 \(Int(diff.rounded()))bpm 높아요.") }
        }
        let bHRV = values(base, .hrv), rHRV = values(recent, .hrv)
        if bHRV.count >= 7, rHRV.count >= 3 {
            let usual = median(bHRV), avg = rHRV.reduce(0, +) / Double(rHRV.count)
            if avg < usual * 0.8 { out.append("심박 변이도가 평소보다 \(Int(((1 - avg / usual) * 100).rounded()))% 낮아요.") }
        }
        let rF = values(recent, .fatigue)
        if rF.count >= 3, rF.reduce(0, +) / Double(rF.count) >= 4 {
            out.append("최근 7일 '힘듦'이 높은 편이에요(평균 \(String(format: "%.1f", rF.reduce(0, +) / Double(rF.count)))).")
        }
        return out
    }
}
