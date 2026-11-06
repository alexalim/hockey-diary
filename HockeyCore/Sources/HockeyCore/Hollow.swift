import Foundation

/// 연마 홀로우 반경(RoH). 저장은 사용자가 고른 표기 그대로, 비교·그림은 인치 값으로 한다.
public struct Hollow: Equatable, Hashable, Sendable {
    /// 화면·저장용 표기. 예: "1/2", "5/8", "0.55".
    public let label: String
    /// 반경(인치).
    public let inches: Double

    public static let presets: [Hollow] = ["5/16", "3/8", "7/16", "1/2", "9/16", "5/8", "11/16", "3/4", "7/8", "1"].compactMap(Hollow.init(label:))

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

    /// 국내 연마점에서 단계를 부르는 선수 이름 별명. 그 선수가 실제로 쓰는 값이라는 뜻은 아니다.
    public var playerNickname: String? {
        ["5/16": "차라", "3/8": "말킨", "7/16": "오베츠킨", "1/2": "크로스비", "9/16": "맥데이빗", "5/8": "케인"][label]
    }

    /// 화면에 보일 별명: 선수 별명이 있으면 그것, 없으면 느낌 별명. 목록에 없는 값은 nil.
    public var nickname: String? {
        playerNickname ?? (Hollow.presets.contains(self) && inches > 0.625 ? "활주 스타일" : nil)
    }

    public static let playerNicknameNote = "선수 이름은 연마점에서 단계를 부르는 별명이야. 그 선수가 실제로 쓰는 값은 아니야."

    /// 홈 깊이 구분. 반경이 작을수록 홈이 깊다(기하 사실).
    public var feel: String {
        if inches < 0.53 { return "깊은 홈" }
        if inches < 0.6 { return "중간" }
        return "얕은 홈"
    }
}

/// 연마 안내(마하다 자체 구성). 권장 시간은 자료마다 달라서 숫자로 정해주지 않는다.
public enum SharpeningGuide {
    public struct Section: Sendable {
        public let title: String
        public let points: [String]
    }

    public static let sections: [Section] = [
        Section(title: "타기 전 체크", points: [
            "날 옆면을 빛에 비스듬히 비춰봐. 날 끝에 반짝이는 줄이 보이면 그 자리가 둥글게 닳은 거야.",
            "날을 앞에서 뒤까지 훑어보며 홈이 끊기거나 깨진 곳이 없는지 봐.",
            "두 발 날을 다 봐. 한쪽만 닳는 경우도 많아.",
        ]),
        Section(title: "얼음 위 느낌", points: [
            "턴할 때 발이 바깥으로 흘러가면 날이 얼음을 덜 잡는 거야.",
            "스톱할 때 얼음이 안 긁히고 쭉 밀리면 점검해봐.",
            "느낌이 이상하면 마지막으로 간 지 얼마 안 됐어도 확인해. 날짜보다 느낌이 먼저야.",
        ]),
        Section(title: "연마점에서", points: [
            "러너 화면에 있는 지금 RoH를 보여줘. 같은 값으로 해달라고 하면 돼.",
            "더 꽉 잡히는 게 좋은지, 더 쭉 나가는 게 좋은지 한마디 해줘.",
            "값을 바꿔볼 땐 차이를 작게 해. 크게 바꾸면 적응이 어려워.",
            "다 갈고 나면 여기 기록에 느낌을 남겨둬. 다음에 고를 때 도움이 돼.",
        ]),
        Section(title: "보관", points: [
            "링크에서 나오면 수건으로 날과 홀더까지 닦아.",
            "가방에 넣을 땐 천 가드를 씌워. 젖은 플라스틱 가드를 낀 채 두면 녹이 생겨.",
            "집에 오면 가방을 열어 말려줘.",
        ]),
    ]
}
