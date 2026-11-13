import Foundation

/// 그래프·인사이트를 보여 줄 만큼 기록이 모였는지 판단한다.
/// 표본이 모자라면 그래프 대신 "기록을 더 모아보자"를 보여 준다 (F-C05, T08).
public enum Sufficiency: Equatable, Sendable {
    case empty
    case insufficient(count: Int, needed: Int)
    case sufficient(count: Int)

    public static let defaultMinimum = 3

    public init(count: Int, minimum: Int = Sufficiency.defaultMinimum) {
        if count <= 0 {
            self = .empty
        } else if count < minimum {
            self = .insufficient(count: count, needed: minimum)
        } else {
            self = .sufficient(count: count)
        }
    }

    public var isSufficient: Bool {
        if case .sufficient = self { return true }
        return false
    }

    public var count: Int {
        switch self {
        case .empty: return 0
        case .insufficient(let count, _): return count
        case .sufficient(let count): return count
        }
    }

    /// 데이터 없음과 0을 구분해 안내한다 (부록 B Empty state).
    public var message: String {
        switch self {
        case .empty: return "아직 기록이 없어요. 첫 기록을 남겨 봐요."
        case .insufficient(let count, let needed): return "기록이 \(count)건이에요. \(needed)건이 되면 보여 줄게요. 조금만 더 모아 봐요."
        case .sufficient(let count): return "기록 \(count)건"
        }
    }
}
