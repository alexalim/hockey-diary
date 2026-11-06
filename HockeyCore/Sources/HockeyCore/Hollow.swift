import Foundation

/// 연마 홀로우 반경(RoH). 저장은 사용자가 고른 표기 그대로, 비교·그림은 인치 값으로 한다.
public struct Hollow: Equatable, Hashable, Sendable {
    /// 화면·저장용 표기. 예: "1/2", "5/8", "0.55".
    public let label: String
    /// 반경(인치).
    public let inches: Double

    public static let presets: [Hollow] = ["3/8", "7/16", "1/2", "9/16", "5/8", "11/16", "3/4", "7/8", "1"].compactMap(Hollow.init(label:))

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

    /// 느낌 쪽: 숫자가 작을수록 홈이 깊어 잘 물리고(그립), 클수록 얕아 잘 미끄러진다(활주).
    public var feel: String {
        if inches < 0.53 { return "그립 쪽" }
        if inches < 0.6 { return "중간" }
        return "활주 쪽"
    }
}

/// 연마 안내. 언제 갈지, 연마점에 어떻게 맡길지, 타고 나서 날 관리.
/// 권장 시간은 자료마다 달라서 숫자로 정해주지 않는다.
public enum SharpeningGuide {
    public struct Section: Sendable {
        public let title: String
        public let points: [String]
    }

    public static let sections: [Section] = [
        Section(title: "언제 갈까?", points: [
            "며칠 지났는지보다 얼마나 탔는지가 중요해. 탄 횟수나 시간을 같이 봐.",
            "밀어낼 때 헛밀리거나 멈출 때 미끄러지면 점검할 때야.",
            "날에 찍히거나 파인 곳이 보여도 갈아야 해.",
            "날 모서리를 손톱으로 살짝 긁어봐. 안 걸리고 미끄러지면 무뎌진 거야.",
            "권장 시간은 자료마다 달라. 느낌이 이상하면 시간과 상관없이 점검해.",
        ]),
        Section(title: "어떻게 맡길까?", points: [
            "연마점에 지난번 세팅(RoH)과 양쪽 날 상태를 말해줘. 러너 화면에 지난번 세팅이 있어.",
            "숫자가 작을수록 홈이 깊어서 잘 물려. 클수록 얕아서 잘 미끄러져.",
            "바꿔보고 싶으면 한 칸씩만 바꿔. 9/16에서 1/2처럼.",
            "갈고 나서 그립·활주·스톱·턴 느낌을 남겨두면 다음에 비교하기 쉬워.",
        ]),
        Section(title: "타고 나면?", points: [
            "얼음에서 나오면 날의 물기를 바로 닦아. 그대로 두면 녹슬어.",
            "보관할 땐 천으로 된 소프트 가드를 씌워. 딱딱한 가드는 걸어 다닐 때만 껴.",
            "다음에 타기 전에 날에 찍힌 곳이 없는지 한 번 봐.",
        ]),
    ]
}
