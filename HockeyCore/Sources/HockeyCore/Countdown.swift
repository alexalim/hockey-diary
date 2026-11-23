import Foundation

/// 드릴 타이머. 1초씩 빼지 않고 끝나는 시각을 기억해 두고 남은 시간을 그때그때 계산한다.
/// 화면이 잠기거나 앱이 뒤로 가서 틱이 빠져도, 돌아왔을 때 값이 맞는다.
public struct Countdown: Equatable, Sendable {
    /// 멈춰 있을 때의 남은 초.
    private var pausedLeft: Int
    /// 돌고 있을 때 끝나는 시각. 멈춰 있으면 nil.
    public private(set) var endsAt: Date?

    public init(seconds: Int) {
        pausedLeft = max(0, seconds)
    }

    public var isRunning: Bool { endsAt != nil }

    /// 지금 남은 초. 끝난 뒤로는 0.
    public func secondsLeft(at now: Date) -> Int {
        guard let endsAt else { return pausedLeft }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }

    /// 시작 또는 계속. 이미 돌고 있거나 다 썼으면 아무 일도 없다.
    public mutating func start(at now: Date) {
        guard endsAt == nil, pausedLeft > 0 else { return }
        endsAt = now.addingTimeInterval(TimeInterval(pausedLeft))
    }

    /// 잠깐 멈춤. 지금까지 흐른 만큼 줄여 둔다.
    public mutating func pause(at now: Date) {
        guard endsAt != nil else { return }
        pausedLeft = secondsLeft(at: now)
        endsAt = nil
    }

    /// 소리로 알릴 순간.
    public enum Cue: Equatable, Sendable { case minuteLeft, tenSeconds, finished }

    /// 남은 초가 before에서 after로 줄었을 때 알릴 것. 여러 지점을 한꺼번에 지났으면 가장 나중 것만.
    public static func cue(from before: Int, to after: Int) -> Cue? {
        guard after < before else { return nil }
        if after == 0 { return .finished }
        if before > 10 && after <= 10 { return .tenSeconds }
        if before > 60 && after <= 60 { return .minuteLeft }
        return nil
    }
}
