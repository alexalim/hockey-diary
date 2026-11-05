import Foundation

/// 연마 홀로우 반경(RoH). 저장은 사용자가 고른 표기 그대로, 비교·그림은 인치 값으로 한다.
public struct Hollow: Equatable, Hashable, Sendable {
    /// 화면·저장용 표기. 예: "1/2", "5/8", "0.55".
    public let label: String
    /// 반경(인치).
    public let inches: Double

    public static let presets: [Hollow] = ["3/8", "1/2", "5/8", "3/4", "7/8", "1"].compactMap(Hollow.init(label:))

    /// 하키 날 폭(인치, 약 2.9mm). 단면 그림의 상대 깊이 계산에만 쓴다.
    public static let bladeWidthInches = 0.115

    /// "1/2", "5/8", "1", "0.55", "1 1/4" 를 읽는다. 0 이하나 숫자가 아니면 nil.
    public init?(label raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "인치", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Hollow.parse(text), value > 0, value <= 3 else { return nil }
        self.label = text
        self.inches = value
    }

    private static func parse(_ text: String) -> Double? {
        let parts = text.split(separator: " ").map(String.init)
        if parts.count == 2, let whole = Double(parts[0]), let frac = parseFraction(parts[1]) {
            return whole + frac
        }
        if parts.count == 1 {
            return parseFraction(parts[0]) ?? Double(parts[0])
        }
        return nil
    }

    private static func parseFraction(_ text: String) -> Double? {
        let nd = text.split(separator: "/")
        guard nd.count == 2, let n = Double(nd[0]), let d = Double(nd[1]), d != 0 else { return nil }
        return n / d
    }

    /// 날 폭을 현으로 하는 원호의 깊이(인치): R − √(R² − (w/2)²).
    /// 반경이 작을수록 깊어지므로 단면 그림의 깊이 순서가 실제 순서와 항상 같다 (EQ-04, T15).
    public var grooveDepthInches: Double {
        let half = Hollow.bladeWidthInches / 2
        let r = max(inches, half)
        return r - (r * r - half * half).squareRoot()
    }

    /// 프리셋 중 가장 깊은 홈을 1로 둔 상대 깊이. 그림이 눈에 보이도록 0.12 아래로는 줄이지 않는다.
    public var relativeDepth: Double {
        let deepest = Hollow.presets.map(\.grooveDepthInches).max() ?? grooveDepthInches
        return max(min(grooveDepthInches / deepest, 1), 0.12)
    }

    public var display: String { "\(label)\"" }
}
