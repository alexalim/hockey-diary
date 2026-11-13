import Foundation
import HockeyCore

/// 실력 레벨·입력 방식 설정. 값은 UserDefaults에만 둔다(기록 데이터와 무관).
enum RecordPrefs {
    static let levelKey = "player.level"
    static let modeKey = "record.mode"

    static func level(_ defaults: UserDefaults = .standard) -> PlayerLevel? {
        defaults.string(forKey: levelKey).flatMap(PlayerLevel.init(rawValue:))
    }

    static func mode(_ defaults: UserDefaults = .standard) -> RecordMode {
        defaults.string(forKey: modeKey).flatMap(RecordMode.init(rawValue:)) ?? .auto
    }

    /// 지금 실제로 적용되는 방식(auto 풀림).
    static func resolved(_ defaults: UserDefaults = .standard) -> RecordMode {
        RecordMode.resolve(mode(defaults), level: level(defaults))
    }

    static func preset(_ defaults: UserDefaults = .standard) -> RecordPreset { resolved(defaults).preset }

    /// 편집기 안내 한 줄. 보통일 땐 아무 말 안 한다.
    static func editorNote(_ defaults: UserDefaults = .standard) -> String? {
        let m = resolved(defaults)
        guard m != .normal else { return nil }
        return "지금은 '\(m.title)' 입력이에요. 설정 > 기록 방식에서 바꿀 수 있어요."
    }

    /// 설정 화면 설명(설정은 합니다체).
    static func settingsSummary(_ defaults: UserDefaults = .standard) -> String {
        let m = resolved(defaults)
        let what: String
        switch m {
        case .simple: what = "기술 난도, 시도 횟수, 경기 스탯, 코치 메모를 숨기고 짧게 적습니다."
        case .detailed: what = "장소, 장비, 사진, 슛 차트, 경기 정보까지 처음부터 펼쳐 보여 줍니다."
        case .normal, .auto: what = "기본 항목을 보여 주고, 나머지는 '더 적기'로 펼칩니다."
        }
        let from = mode(defaults) == .auto ? (level(defaults) == nil ? "실력 레벨을 정하지 않아 보통으로 적용 중입니다. " : "실력 레벨에 맞춰 적용 중입니다. ") : ""
        return "\(from)지금 방식은 '\(m.title)'입니다. \(what)"
    }
}
