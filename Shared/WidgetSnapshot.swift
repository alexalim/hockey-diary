import Foundation
import Security

/// 위젯이 보여 줄 숫자 묶음. 앱이 계산해 두고 위젯은 읽기만 한다.
/// 앱 그룹 대신 키체인 공유 그룹으로 넘긴다(포털 설정 없이 프로파일 기본 권한으로 된다).
struct WidgetSnapshot: Codable, Equatable {
    /// 월~일 7칸. 그날 빙판에 섰으면 true.
    var weekDays: [Bool]
    /// 오늘이 월~일 중 몇 번째인지(0~6).
    var todayIndex: Int
    var streakWeeks: Int
    var monthDone: Int
    var monthTarget: Int
    var points: Int
    var resting: Bool
    var nextEventTitle: String?
    var nextEventAt: Date?
    var updatedAt: Date

    var weekCount: Int { weekDays.filter { $0 }.count }
    var monthLeft: Int { max(0, monthTarget - monthDone) }

    static let placeholder = WidgetSnapshot(weekDays: [true, false, true, false, false, false, false], todayIndex: 3,
                                            streakWeeks: 3, monthDone: 4, monthTarget: 6, points: 20, resting: false,
                                            nextEventTitle: "목동 펭귄즈 vs 강남 베어스", nextEventAt: Date().addingTimeInterval(86400 * 2), updatedAt: Date())
}

enum SharedStore {
    static let service = "com.aspynlim.hockeydiary.widget"
    static let groupSuffix = "com.aspynlim.hockeydiary.shared"

    /// 공유 키체인 그룹 "팀ID.com.aspynlim.hockeydiary.shared".
    /// 팀 ID는 소스에 두지 않고, 기본 그룹에 넣은 항목의 접근 그룹(팀ID.번들ID)에서 앞부분만 떼어 쓴다.
    static var accessGroup: String? {
        let probe: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: "probe",
                                    kSecReturnAttributes as String: true]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(probe as CFDictionary, &result)
        if status == errSecItemNotFound {
            var add = probe
            add.removeValue(forKey: kSecReturnAttributes as String)
            add[kSecValueData as String] = Data()
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
            status = SecItemCopyMatching(probe as CFDictionary, &result)
        }
        guard status == errSecSuccess, let attrs = result as? [String: Any],
              let group = attrs[kSecAttrAccessGroup as String] as? String,
              let dot = group.firstIndex(of: ".") else { return nil }
        return String(group[..<dot]) + "." + groupSuffix
    }

    private static func query(_ group: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "snapshot",
         kSecAttrAccessGroup as String: group]
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let group = accessGroup, let data = try? JSONEncoder().encode(snapshot) else { return }
        let q = query(group)
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> WidgetSnapshot? {
        guard let group = accessGroup else { return nil }
        var q = query(group)
        q[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
