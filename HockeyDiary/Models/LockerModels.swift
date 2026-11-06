import Foundation
import SwiftData
import HockeyCore

// 락커 꾸미기와 그 밖의 장비. 장식 데이터는 장비·연마 데이터와 완전히 분리한다 (LK-10, T19).
// 기존 모델은 바꾸지 않고 새 모델만 추가한다(기기에 쌓인 기록 보호).

/// 락커 외관 (User 1:1).
@Model
final class LockerProfile {
    var id: UUID = UUID()
    /// 숫자 0~4자리 문자열. "007" 그대로 (T17).
    var numberText: String = ""
    var nameplate: String = "MY LOCKER"
    var themeRaw: String = LockerTheme.cobalt.rawValue

    init() { self.id = UUID() }

    var theme: LockerTheme {
        get { LockerTheme(rawValue: themeRaw) ?? .cobalt }
        set { themeRaw = newValue.rawValue }
    }
}

/// 문에 붙인 스티커 하나. 좌표는 0~1 정규화.
@Model
final class StickerPlacement {
    var id: UUID = UUID()
    /// StickerCatalog 키. 사진 스티커면 "photo".
    var stickerKey: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var x: Double = 0.5
    var y: Double = 0.5
    var scale: Double = 1
    var rotation: Double = 0
    var zIndex: Int = 0
    var createdAt: Date = Date()

    init(stickerKey: String, x: Double, y: Double, zIndex: Int) {
        self.id = UUID()
        self.stickerKey = stickerKey
        self.x = x
        self.y = y
        self.zIndex = zIndex
        self.createdAt = Date()
    }

    var placement: Placement {
        get { Placement(x: x, y: y, scale: scale, rotation: rotation, z: zIndex) }
        set {
            let c = newValue.clamped()
            x = c.x; y = c.y; scale = c.scale; rotation = c.rotation; zIndex = c.z
        }
    }
}

/// 받은 성취 스티커. 같은 키는 한 번만.
@Model
final class EarnedSticker {
    var id: UUID = UUID()
    var stickerKey: String = ""
    var earnedAt: Date = Date()

    init(stickerKey: String) {
        self.id = UUID()
        self.stickerKey = stickerKey
        self.earnedAt = Date()
    }
}

/// 스케이트 말고 다른 장비(헬멧·장갑·유니폼·보호대·스틱·테이프).
@Model
final class GearItem {
    var id: UUID = UUID()
    var kindRaw: String = GearKind.helmet.rawValue
    var brand: String = ""
    var model: String = ""
    var size: String = ""
    var statusRaw: String = SkateStatus.main.rawValue
    var purchasedAt: Date?
    var memo: String = ""
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date = Date()

    init(kind: GearKind) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.createdAt = Date()
    }

    var kind: GearKind {
        get { GearKind(rawValue: kindRaw) ?? .helmet }
        set { kindRaw = newValue.rawValue }
    }
    var status: SkateStatus {
        get { SkateStatus(rawValue: statusRaw) ?? .main }
        set { statusRaw = newValue.rawValue }
    }
    var name: String {
        let n = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        return n.isEmpty ? kind.title : n
    }
}

enum GearKind: String, CaseIterable {
    case helmet, neck, gloves, shoulder, elbow, pants, shin, jersey, pads, stick, tape

    var title: String {
        switch self {
        case .helmet: return "헬멧"
        case .neck: return "목 보호대"
        case .shoulder: return "어깨·가슴 보호대"
        case .elbow: return "팔꿈치 보호대"
        case .pants: return "하키 바지"
        case .shin: return "정강이 보호대"
        case .gloves: return "장갑"
        case .jersey: return "유니폼"
        case .pads: return "기타 보호대"
        case .stick: return "스틱"
        case .tape: return "테이프"
        }
    }

    var symbol: String {
        switch self {
        case .helmet: return "shield.lefthalf.filled"
        case .neck: return "person.crop.circle"
        case .shoulder: return "figure.arms.open"
        case .elbow: return "figure.strengthtraining.traditional"
        case .pants: return "figure.walk"
        case .shin: return "figure.run"
        case .gloves: return "hand.raised.fill"
        case .jersey: return "tshirt.fill"
        case .pads: return "figure.cooldown"
        case .stick: return "line.diagonal"
        case .tape: return "circle.circle"
        }
    }

    /// 락커 구역별 묶음 (8.1.1 장비 핫스팟).
    enum Zone: String, CaseIterable {
        case top, middle, side
        var title: String {
            switch self {
            case .top: return "헬멧 · 목 · 장갑"
            case .middle: return "유니폼 · 보호대"
            case .side: return "스틱 · 테이프"
            }
        }
        var kinds: [GearKind] {
            switch self {
            case .top: return [.helmet, .neck, .gloves]
            case .middle: return [.shoulder, .elbow, .pants, .shin, .jersey, .pads]
            case .side: return [.stick, .tape]
            }
        }
        var symbol: String {
            switch self {
            case .top: return "shield.lefthalf.filled"
            case .middle: return "tshirt.fill"
            case .side: return "line.diagonal"
            }
        }
    }
}

enum LockerStore {
    static func profile(_ context: ModelContext) -> LockerProfile {
        if let p = try? context.fetch(FetchDescriptor<LockerProfile>()).first { return p }
        let p = LockerProfile()
        context.insert(p)
        return p
    }

    /// 기록을 보고 새 성취 스티커를 발급한다. 이미 받은 것은 건너뛴다.
    @discardableResult
    static func awardMilestones(_ context: ModelContext) -> [String] {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let sharpenings = (try? context.fetchCount(FetchDescriptor<SharpeningLog>())) ?? 0
        let facts = MilestoneFacts(
            lessons: sessions.filter { $0.type == .lesson }.count,
            games: sessions.filter { $0.type.isGame }.count,
            goals: sessions.compactMap(\.goals).reduce(0, +),
            sessions: sessions.count,
            pondSessions: sessions.filter { $0.surface == .pond }.count,
            sharpenings: sharpenings)
        let earned = Set(((try? context.fetch(FetchDescriptor<EarnedSticker>())) ?? []).map(\.stickerKey))
        let fresh = Milestones.newlyEarned(facts, alreadyEarned: earned)
        for key in fresh { context.insert(EarnedSticker(stickerKey: key)) }
        if !fresh.isEmpty { context.saveOrReport() }
        return fresh
    }
}
