import Foundation

/// 락커 번호판. 숫자 0~4자리 문자열, 앞자리 0 유지("007"), 중복 허용 (LK-09, T17).
public enum LockerNumber {
    public static let maxDigits = 4

    /// 입력에서 숫자만 남기고 4자리까지 자른다. 앞자리 0은 지우지 않는다.
    public static func normalize(_ input: String) -> String {
        String(input.filter { $0.isASCII && $0.isNumber }.prefix(maxDigits))
    }
}

/// 락커 색 테마 (LK-10). 장비 데이터와 분리된 장식 값이다.
public enum LockerTheme: String, CaseIterable, Sendable {
    // 저장 값(rawValue)이라 이름을 바꾸지 말고 뒤에만 더한다.
    case cobalt, navy, neonPink, iceBlue
    case strawberry, mint, lemon, lavender

    public var title: String {
        switch self {
        case .cobalt: return "코발트"
        case .navy: return "네이비"
        case .neonPink: return "네온 핑크"
        case .iceBlue: return "아이스 블루"
        case .strawberry: return "딸기우유"
        case .mint: return "민트"
        case .lemon: return "레몬"
        case .lavender: return "라벤더"
        }
    }

    /// 밝은 파스텔 문. 문 위 글자·선을 흰색 대신 진한 색으로 그려야 보인다.
    public var isPastel: Bool {
        switch self {
        case .strawberry, .mint, .lemon, .lavender: return true
        default: return false
        }
    }
}

/// 스티커 하나의 배치. 좌표는 문 크기에 대한 0~1 정규화 값이라 화면 크기가 달라도 같은 자리에 붙는다 (StickerPlacement).
public struct Placement: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var scale: Double
    public var rotation: Double
    public var z: Int

    public static let scaleRange = 0.4...3.0

    public init(x: Double, y: Double, scale: Double = 1, rotation: Double = 0, z: Int = 0) {
        self.x = x; self.y = y; self.scale = scale; self.rotation = rotation; self.z = z
    }

    /// 문 밖으로 나가거나 너무 작거나 크지 않게, 각도는 -180~180으로 맞춘다.
    public func clamped() -> Placement {
        var p = self
        p.x = min(max(x, 0), 1)
        p.y = min(max(y, 0), 1)
        p.scale = min(max(scale, Placement.scaleRange.lowerBound), Placement.scaleRange.upperBound)
        var r = rotation.truncatingRemainder(dividingBy: 360)
        if r > 180 { r -= 360 }
        if r <= -180 { r += 360 }
        p.rotation = r
        return p
    }
}

public enum StickerOrder {
    /// 고른 스티커를 맨 앞으로. 나머지 순서는 유지하고 0부터 다시 매긴다.
    public static func bringToFront(_ id: UUID, in order: [UUID]) -> [UUID] {
        guard order.contains(id) else { return order }
        return order.filter { $0 != id } + [id]
    }

    public static func sendToBack(_ id: UUID, in order: [UUID]) -> [UUID] {
        guard order.contains(id) else { return order }
        return [id] + order.filter { $0 != id }
    }
}

/// 스티커 사전. 실제 팀 로고는 넣지 않고 기호 그림만 쓴다.
public struct StickerDef: Equatable, Sendable {
    public enum Kind: String, Sendable { case basic, hockey, deco, achievement }
    public let key: String
    public let title: String
    public let symbol: String
    public let kind: Kind
    /// 0 핑크, 1 코발트, 2 흰색, 3 금색
    public let palette: Int
}

public enum StickerCatalog {
    public static let all: [StickerDef] = [
        StickerDef(key: "star", title: "별", symbol: "star.fill", kind: .basic, palette: 3),
        StickerDef(key: "heart", title: "하트", symbol: "heart.fill", kind: .basic, palette: 0),
        StickerDef(key: "bolt", title: "번개", symbol: "bolt.fill", kind: .basic, palette: 3),
        StickerDef(key: "flame", title: "불꽃", symbol: "flame.fill", kind: .basic, palette: 0),
        StickerDef(key: "sparkles", title: "반짝", symbol: "sparkles", kind: .basic, palette: 2),
        StickerDef(key: "puck", title: "퍽", symbol: "hockey.puck.fill", kind: .hockey, palette: 1),
        StickerDef(key: "player", title: "하키 선수", symbol: "figure.hockey", kind: .hockey, palette: 1),
        StickerDef(key: "skate", title: "스케이트", symbol: "figure.skating", kind: .hockey, palette: 2),
        StickerDef(key: "trophy", title: "트로피", symbol: "trophy.fill", kind: .hockey, palette: 3),
        StickerDef(key: "snowflake", title: "눈꽃", symbol: "snowflake", kind: .hockey, palette: 2),
        StickerDef(key: "crown", title: "왕관", symbol: "crown.fill", kind: .deco, palette: 3),
        StickerDef(key: "moon", title: "달과 별", symbol: "moon.stars.fill", kind: .deco, palette: 2),
        StickerDef(key: "music", title: "음표", symbol: "music.note", kind: .deco, palette: 0),
        StickerDef(key: "smile", title: "스마일", symbol: "face.smiling.inverse", kind: .deco, palette: 3),
        StickerDef(key: "first-lesson", title: "첫 수업", symbol: "graduationcap.fill", kind: .achievement, palette: 0),
        StickerDef(key: "first-game", title: "첫 경기", symbol: "flag.checkered", kind: .achievement, palette: 1),
        StickerDef(key: "first-goal", title: "첫 골", symbol: "target", kind: .achievement, palette: 0),
        StickerDef(key: "ten-sessions", title: "빙판 10회", symbol: "10.circle.fill", kind: .achievement, palette: 3),
        StickerDef(key: "first-pond", title: "첫 폰드", symbol: "water.waves", kind: .achievement, palette: 2),
        StickerDef(key: "first-sharpening", title: "첫 연마 기록", symbol: "wrench.and.screwdriver.fill", kind: .achievement, palette: 1),
    ]

    /// 사전에 있는 스티커, 또는 달 배지("badge-YYYY-MM", 이달 퀘스트 달성으로 받음).
    public static func def(_ key: String) -> StickerDef? {
        if let d = all.first(where: { $0.key == key }) { return d }
        if let title = Quest.badgeTitle(key) {
            return StickerDef(key: key, title: title, symbol: "medal.fill", kind: .achievement, palette: 3)
        }
        return nil
    }
}

/// 성취 스티커 판정에 쓰는 기록 요약.
public struct MilestoneFacts: Equatable, Sendable {
    public var lessons: Int
    public var games: Int
    public var goals: Int
    public var sessions: Int
    public var pondSessions: Int
    public var sharpenings: Int

    public init(lessons: Int = 0, games: Int = 0, goals: Int = 0, sessions: Int = 0, pondSessions: Int = 0, sharpenings: Int = 0) {
        self.lessons = lessons; self.games = games; self.goals = goals
        self.sessions = sessions; self.pondSessions = pondSessions; self.sharpenings = sharpenings
    }
}

public enum Milestones {
    /// 기록으로 얻은 성취 스티커 키.
    public static func earned(_ f: MilestoneFacts) -> Set<String> {
        var s = Set<String>()
        if f.lessons >= 1 { s.insert("first-lesson") }
        if f.games >= 1 { s.insert("first-game") }
        if f.goals >= 1 { s.insert("first-goal") }
        if f.sessions >= 10 { s.insert("ten-sessions") }
        if f.pondSessions >= 1 { s.insert("first-pond") }
        if f.sharpenings >= 1 { s.insert("first-sharpening") }
        return s
    }

    /// 이미 받은 것은 다시 발급하지 않는다 (EarnedSticker 중복 방지).
    public static func newlyEarned(_ f: MilestoneFacts, alreadyEarned: Set<String>) -> [String] {
        earned(f).subtracting(alreadyEarned).sorted()
    }
}

/// 락커 문을 손가락으로 여닫는 계산. 왼쪽 경첩 기준, 0°=닫힘, openAngle=활짝 열림.
/// 손잡이(오른쪽)를 왼쪽으로 쓸면(음수 이동) 열린다.
public enum DoorSwing {
    public static let openAngle = 105.0
    /// 문고리가 풀리는 각도(가벼운 진동 한 번).
    public static let latchAngle = 12.0
    /// 문 너비만큼 쓸면 몇 도 도는지.
    public static let degreesPerWidth = 140.0

    public static func angle(from base: Double, translation: Double, width: Double) -> Double {
        guard width > 0 else { return base }
        return min(max(base - translation / width * degreesPerWidth, 0), openAngle)
    }

    /// 손을 뗐을 때 열린 상태로 갈지. 지금 각도와 관성(예상 도착 각도)을 함께 본다.
    public static func shouldOpen(current: Double, predicted: Double, wasOpen: Bool) -> Bool {
        let p = min(max(predicted, -40), openAngle + 60)
        if wasOpen {
            // 열린 문은 절반 넘게 닫거나 휙 닫아야 닫힌다.
            return !(current < openAngle * 0.55 || p < openAngle * 0.35)
        }
        return current > openAngle * 0.45 || p > openAngle * 0.6
    }

    /// 0~1 진행도(안쪽 장비함 크기·문 그림자에 쓴다).
    public static func progress(_ angle: Double) -> Double { min(max(angle / openAngle, 0), 1) }
}
