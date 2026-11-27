import Foundation

/// 입문 전(아직 얼음에 서 본 적 없는 사람)을 위한 '첫 빙판까지' 단계.
/// 홈 실력 질문에서 '아직 안 타 봤어요'를 고르면 켜지고, 첫 기록을 남기면 저절로 끝난다.
public enum FirstIce {
    public static let prestarterKey = "prestarter"
    public static let doneKey = "firstIce.done"

    public enum Step: String, CaseIterable, Sendable {
        case watch, stickhandle, rink, gear, firstSkate

        public var title: String {
            switch self {
            case .watch: return "하키 구경하기"
            case .stickhandle: return "집에서 퍽 굴려 보기"
            case .rink: return "링크장 한 번 가 보기"
            case .gear: return "장비 알아보기"
            case .firstSkate: return "처음 탄 날 남기기"
            }
        }

        public var detail: String {
            switch self {
            case .watch: return "링크 구조, 오프사이드, 포지션. 그림 세 장이면 경기가 보이기 시작해요."
            case .stickhandle: return "거실에서 공 하나로 5분. 고개를 들고 손으로 느끼는 연습이에요."
            case .rink: return "자유 스케이팅 시간에 스케이트를 빌려 서 보는 게 첫걸음이에요."
            case .gear: return "처음엔 대부분 빌려도 돼요. 먼저 살 것과 신어 보고 살 것을 나눠 봤어요."
            case .firstSkate: return "얼음 위에 처음 선 날, 한 줄이면 돼요. 여기서부터 기록이 쌓여요."
            }
        }

        public var action: String {
            switch self {
            case .watch: return "그림으로 보기"
            case .stickhandle: return "5분 해 보기"
            case .rink: return "링크장 찾기"
            case .gear: return "처음 장비 보기"
            case .firstSkate: return "기록하기"
            }
        }

        public var systemImage: String {
            switch self {
            case .watch: return "flag.2.crossed"
            case .stickhandle: return "figure.hockey"
            case .rink: return "mappin.and.ellipse"
            case .gear: return "tshirt.fill"
            case .firstSkate: return "pencil"
            }
        }
    }

    /// 입문 안내를 보여 줄지: 입문 전이라고 했고, 아직 기록이 없을 때만.
    public static func isActive(prestarter: Bool, hasSessions: Bool) -> Bool { prestarter && !hasSessions }

    public static func done(_ raw: String) -> Set<Step> {
        Set(raw.split(separator: ",").compactMap { Step(rawValue: String($0)) })
    }

    public static func encode(_ s: Set<Step>) -> String {
        Step.allCases.filter(s.contains).map(\.rawValue).joined(separator: ",")
    }

    public static func marking(_ raw: String, _ step: Step) -> String {
        var s = done(raw); s.insert(step); return encode(s)
    }

    public static func toggling(_ raw: String, _ step: Step) -> String {
        var s = done(raw)
        if s.contains(step) { s.remove(step) } else { s.insert(step) }
        return encode(s)
    }

    /// 다음에 할 단계(안 한 것 중 맨 앞). 다 했으면 nil.
    public static func next(_ done: Set<Step>) -> Step? { Step.allCases.first { !done.contains($0) } }
}

/// 처음 장비: 무엇을 빌려도 되고 무엇을 먼저 사는지. 강습처·링크장마다 다르니 안내는 '보통 이렇다' 수준으로.
public enum StarterGear {
    public enum Plan: String, CaseIterable, Sendable {
        case rent, buyFirst, tryOn, later

        public var title: String {
            switch self {
            case .buyFirst: return "먼저 사면 좋아요"
            case .tryOn: return "신어 보고 사요"
            case .rent: return "처음엔 빌려도 돼요"
            case .later: return "나중에"
            }
        }
    }

    public struct Item: Equatable, Sendable, Identifiable {
        public let key: String
        public let name: String
        public let plan: Plan
        public let why: String
        public var id: String { key }
    }

    /// 보여 주는 순서: 먼저 살 것 → 신어 볼 것 → 빌려도 되는 것 → 나중에.
    public static let order: [Plan] = [.buyFirst, .tryOn, .rent, .later]

    public static let all: [Item] = [
        Item(key: "gloves", name: "하키 장갑", plan: .buyFirst, why: "땀이 많이 배서 빌린 건 찝찝해요. 처음 사기 좋은 장비예요."),
        Item(key: "jock", name: "낭심 보호대", plan: .buyFirst, why: "몸에 바로 닿아서 내 것으로 써요."),
        Item(key: "socks-tape", name: "하키 양말·테이프", plan: .buyFirst, why: "싸고, 정강이 보호대를 고정할 때 써요."),
        Item(key: "skates", name: "스케이트", plan: .tryOn, why: "처음엔 링크장에서 빌려 타도 돼요. 살 땐 매장에서 꼭 신어 보고요."),
        Item(key: "helmet", name: "헬멧(케이지 달린 것)", plan: .rent, why: "강습처에서 빌려주는 곳이 많아요. 살 땐 머리 둘레를 재요."),
        Item(key: "stick", name: "스틱", plan: .rent, why: "키에 맞는 길이가 있어요. 빌려 써 보며 왼손·오른손을 정해요."),
        Item(key: "shins", name: "정강이 보호대", plan: .rent, why: "무릎부터 스케이트 위까지 덮는 길이로요."),
        Item(key: "pants", name: "하키 팬츠", plan: .rent, why: "넘어질 때 엉덩이·허벅지를 지켜 줘요."),
        Item(key: "shoulder-elbow", name: "어깨·팔꿈치 보호대", plan: .rent, why: "넘어지며 짚을 때 다치기 쉬운 곳이에요."),
        Item(key: "neck", name: "목 보호대", plan: .rent, why: "스케이트 날에서 목을 지켜요. 동호회에 따라 꼭 쓰라는 곳도 있어요."),
        Item(key: "bag", name: "장비 가방", plan: .later, why: "장비가 하나둘 생기면 그때요."),
    ]

    public static func items(_ plan: Plan) -> [Item] { all.filter { $0.plan == plan } }

    public static let readyKey = "starterGear.ready"
    public static func ready(_ raw: String) -> Set<String> { Set(raw.split(separator: ",").map(String.init)) }
    public static func toggling(_ raw: String, _ key: String) -> String {
        var s = ready(raw)
        if s.contains(key) { s.remove(key) } else { s.insert(key) }
        return all.map(\.key).filter(s.contains).joined(separator: ",")
    }
}
