import Foundation
import SwiftData
import WidgetKit
import HockeyCore

/// 위젯에 보여 줄 숫자를 계산해 공유 키체인에 두고 위젯을 새로 고친다.
/// 앱이 켜질 때, 다시 앞으로 올 때, 기록 시트를 닫을 때 부른다.
enum WidgetBridge {
    static func refresh(_ context: ModelContext, now: Date = Date()) {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let drills = (try? context.fetch(FetchDescriptor<DrillLog>())) ?? []
        let checks = (try? context.fetch(FetchDescriptor<BodyCheck>())) ?? []
        let journals = (try? context.fetch(FetchDescriptor<DailyJournal>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<TeamEvent>(sortBy: [SortDescriptor(\.at)]))) ?? []
        let team = (try? context.fetch(FetchDescriptor<Team>()))?.first
        let defaults = UserDefaults.standard
        let restJSON = defaults.string(forKey: RestPrefs.key) ?? "[]"

        let cal = Quest.mondayCalendar()
        let week = Quest.week(containing: now)
        var days = Array(repeating: false, count: 7)
        for s in sessions where s.startsAt >= week.start && s.startsAt < week.end {
            let i = cal.dateComponents([.day], from: cal.startOfDay(for: week.start), to: cal.startOfDay(for: s.startsAt)).day ?? 0
            if (0..<7).contains(i) { days[i] = true }
        }
        let todayIndex = min(6, max(0, cal.dateComponents([.day], from: cal.startOfDay(for: week.start), to: cal.startOfDay(for: now)).day ?? 0))
        let streak = WeeklyStreak.compute(sessions.map(\.startsAt), rests: RestPrefs.ranges(restJSON), now: now)
        let quest = QuestStore.summary(now: now,
                                       facts: QuestStore.facts(sessions: sessions, drills: drills, checks: checks, journals: journals),
                                       level: RecordPrefs.level(), targetOverride: defaults.integer(forKey: QuestStore.targetKey))
        let next = events.first { $0.at >= cal.startOfDay(for: now) }
        let nextTitle = next.map { e in e.opponent.isEmpty ? e.title : "\(team?.name ?? "우리 팀") vs \(e.opponent)" }

        let snap = WidgetSnapshot(weekDays: days, todayIndex: todayIndex, streakWeeks: streak.current,
                                  monthDone: quest.monthDone, monthTarget: quest.monthTarget, points: quest.points,
                                  resting: RestPrefs.isResting(restJSON),
                                  nextEventTitle: nextTitle, nextEventAt: next?.at, updatedAt: now)
        SharedStore.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
