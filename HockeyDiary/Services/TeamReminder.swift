import Foundation
import SwiftData
import UserNotifications
import HockeyCore

/// 팀 경기 이틀 전 저녁 7시에 이 폰에서만 울리는 알림. 서버 없이 기기 알림으로 한다.
/// 아직 참석을 안 정한(미정·답 없음) 사람이 있는 일정만 알린다. 끄면 예약한 알림을 모두 지운다.
enum TeamReminder {
    static let enabledKey = "teamReminder"
    private static let prefix = "team-event-"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// 켤 때 한 번 권한을 묻는다. 거절하면 false.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// 다가오는 일정 기준으로 알림을 다시 짠다. 앱이 켜질 때와 일정·참석이 바뀔 때 부른다.
    @MainActor
    static func reschedule(_ context: ModelContext, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isEnabled, let team = TeamStore.team(context) else { return }
        let members = TeamStore.members(of: team, context: context).map(\.id)
        let cal = Calendar.current
        for e in TeamStore.events(of: team, context: context) where e.at > now {
            let sheet = e.attendance
            let undecided = members.filter { [.maybe, .unknown].contains(sheet[$0]) }.count
            guard undecided > 0,
                  let day = cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: e.at)),
                  let fire = cal.date(bySettingHour: 19, minute: 0, second: 0, of: day), fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(e.at.formatted(.dateTime.weekday(.wide))) \(e.title)"
            content.body = "아직 참석 여부를 안 정한 사람이 \(undecided)명 있어요. 확인해 볼래요?"
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let req = UNNotificationRequest(identifier: prefix + e.id.uuidString, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(req)
        }
    }
}
