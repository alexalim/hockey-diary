import Foundation

/// 활동 종류. 빙판 유형(SurfaceType)과 섞지 않는다 (기획서 10.1.1, ICE-01).
public enum ActivityType: String, CaseIterable, Codable, Sendable {
    case lesson
    case miniGame
    case regularGame
    case freePractice

    public var title: String {
        switch self {
        case .lesson: return "수업"
        case .miniGame: return "미니게임"
        case .regularGame: return "정규게임"
        case .freePractice: return "자유 연습"
        }
    }

    public var isGame: Bool { self == .miniGame || self == .regularGame }

    /// 정규게임만 골·어시스트·포지션 입력칸을 보여 준다. 그래도 모두 선택 항목이다 (FR-02).
    public var showsGameStats: Bool { self == .regularGame }
}

/// 빙판 유형. 선호도나 위험도를 뜻하지 않고 사용 맥락으로만 기록한다.
public enum SurfaceType: String, CaseIterable, Codable, Sendable {
    case indoorRink = "INDOOR_RINK"
    case outdoorRink = "OUTDOOR_RINK"
    case pond = "POND"
    case other = "OTHER"
    case unknown = "UNKNOWN"

    public var title: String {
        switch self {
        case .indoorRink: return "실내 링크"
        case .outdoorRink: return "야외 링크"
        case .pond: return "폰드 하키"
        case .other: return "기타"
        case .unknown: return "나중에 선택"
        }
    }

    public var detail: String {
        switch self {
        case .indoorRink: return "지붕이 있는 실내 빙상장"
        case .outdoorRink: return "인공으로 관리하는 야외 빙상장"
        case .pond: return "자연적으로 얼어붙은 수면 위 하키"
        case .other: return "어디에도 안 맞는 곳"
        case .unknown: return "장소 없이 저장하고 나중에 골라요"
        }
    }

    /// 통계에서 '미입력'으로 따로 모으는 값 (ICE-04).
    public var isUnspecified: Bool { self == .unknown }
}

/// 체감 빙질. 사용자 입력값이며 객관적인 얼음 품질 지표가 아니다.
public enum IceFeel: String, CaseIterable, Codable, Sendable {
    case hard, normal, soft

    public var title: String {
        switch self {
        case .hard: return "단단함"
        case .normal: return "보통"
        case .soft: return "무름"
        }
    }
}

/// 경기에서 시도한 기술의 결과.
public enum AttemptOutcome: String, CaseIterable, Codable, Sendable {
    case success
    case partial
    case difficult

    public var title: String {
        switch self {
        case .success: return "성공"
        case .partial: return "일부 성공"
        case .difficult: return "어려움"
        }
    }
}

/// 스케이트 사용 상태. 삭제 대신 '사용 종료'로 이력을 남긴다 (EQ-02).
public enum SkateStatus: String, CaseIterable, Codable, Sendable {
    case main, sub, stored, retired

    public var title: String {
        switch self {
        case .main: return "주력"
        case .sub: return "서브"
        case .stored: return "보관 중"
        case .retired: return "사용 종료"
        }
    }

    public var isActive: Bool { self == .main || self == .sub }
}

/// 기분 1~5. 자기평가이며 인과 해석에 쓰지 않는다.
public enum Mood {
    public static let range = 1...5

    public static func face(_ value: Int) -> String {
        switch value {
        case 1: return "😣"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "·"
        }
    }

    public static func label(_ value: Int) -> String {
        switch value {
        case 1: return "많이 힘들어요"
        case 2: return "별로예요"
        case 3: return "그냥 그래요"
        case 4: return "좋아요"
        case 5: return "최고예요"
        default: return "없음"
        }
    }

    public static func clamp(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return range.contains(value) ? value : nil
    }
}

/// 하루 일기 태그 기본값.
public enum JournalTag {
    public static let defaults = ["하키", "업무", "연애", "가족", "친구", "건강", "공부", "휴식"]

    /// 쉼표로 저장된 태그를 정리한다. 공백·중복을 없애고 순서는 유지한다.
    public static func parse(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func join(_ tags: [String]) -> String {
        parse(tags.joined(separator: ",")).joined(separator: ",")
    }
}
