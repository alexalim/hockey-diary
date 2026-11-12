import Foundation

/// 구력. 기록 입력 방식의 기본값을 정한다.
public enum PlayerLevel: String, CaseIterable, Codable, Sendable {
    case starter, growing, seasoned

    public var title: String {
        switch self {
        case .starter: return "입문"
        case .growing: return "중급"
        case .seasoned: return "숙련"
        }
    }

    public var yearsText: String {
        switch self {
        case .starter: return "1년 미만"
        case .growing: return "1~3년"
        case .seasoned: return "3년 넘게"
        }
    }

    /// 구력에 맞춘 입력 방식. 입문은 간단, 중급은 보통, 숙련은 자세히.
    public var defaultMode: RecordMode {
        switch self {
        case .starter: return .simple
        case .growing: return .normal
        case .seasoned: return .detailed
        }
    }
}

/// 기록 입력 방식. auto는 구력을 따르고, 구력을 안 정했으면 보통.
public enum RecordMode: String, CaseIterable, Codable, Sendable {
    case auto, simple, normal, detailed

    public var title: String {
        switch self {
        case .auto: return "구력에 맞춤"
        case .simple: return "간단"
        case .normal: return "보통"
        case .detailed: return "자세히"
        }
    }

    /// auto를 실제 방식으로 푼다.
    public static func resolve(_ mode: RecordMode, level: PlayerLevel?) -> RecordMode {
        mode == .auto ? (level?.defaultMode ?? .normal) : mode
    }

    /// 편집기가 쓰는 설정 묶음. auto는 보통으로 본다(호출 쪽에서 먼저 resolve할 것).
    public var preset: RecordPreset {
        switch self {
        case .simple:
            return RecordPreset(expandedByDefault: false, gameDetailsOpen: false,
                                showsSkillDetail: false, showsGameStats: false, showsCoachNotes: false)
        case .auto, .normal:
            return RecordPreset(expandedByDefault: false, gameDetailsOpen: false,
                                showsSkillDetail: true, showsGameStats: true, showsCoachNotes: true)
        case .detailed:
            return RecordPreset(expandedByDefault: true, gameDetailsOpen: true,
                                showsSkillDetail: true, showsGameStats: true, showsCoachNotes: true)
        }
    }
}

/// 기록 편집기가 무엇을 처음부터 보여 줄지.
public struct RecordPreset: Equatable, Sendable {
    /// 장소·장비·사진·슛 차트까지 처음부터 펼친다.
    public var expandedByDefault: Bool
    /// '경기 정보 더 기록하기' 묶음을 펼쳐 둔다.
    public var gameDetailsOpen: Bool
    /// 기술마다 체감 난도·시도 횟수를 묻는다.
    public var showsSkillDetail: Bool
    /// 점수·골·어시스트·+/-·페널티·쉬프트 칸을 보여 준다.
    public var showsGameStats: Bool
    /// 코치 메모·오늘 내 평가 칸을 보여 준다.
    public var showsCoachNotes: Bool

    public init(expandedByDefault: Bool, gameDetailsOpen: Bool, showsSkillDetail: Bool, showsGameStats: Bool, showsCoachNotes: Bool) {
        self.expandedByDefault = expandedByDefault
        self.gameDetailsOpen = gameDetailsOpen
        self.showsSkillDetail = showsSkillDetail
        self.showsGameStats = showsGameStats
        self.showsCoachNotes = showsCoachNotes
    }

    /// 새 기록의 기본 활동 시간(분). 간단 방식은 경기도 짧게 잡는다(미니게임 위주).
    public func defaultMinutes(for type: ActivityType) -> Int {
        switch type {
        case .lesson, .freePractice: return 60
        case .miniGame: return showsGameStats ? 90 : 60
        case .regularGame: return 90
        }
    }
}
