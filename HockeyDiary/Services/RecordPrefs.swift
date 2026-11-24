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
        case .simple: what = "핵심만 짧게 적습니다."
        case .detailed: what = "모든 항목을 처음부터 펼칩니다."
        case .normal, .auto: what = "기본 항목만 보이고, 나머지는 '더 적기'로 펼칩니다."
        }
        let hint = mode(defaults) == .auto && level(defaults) == nil ? " 실력 레벨을 정하면 거기에 맞춰집니다." : ""
        return "지금은 '\(m.title)' 방식입니다. \(what)\(hint)"
    }
}
