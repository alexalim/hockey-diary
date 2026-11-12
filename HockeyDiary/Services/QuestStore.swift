import Foundation
import SwiftData
import HockeyCore

/// 퀘스트 계산과 달 배지 발급. 값은 기록에서 매번 계산하고, 배지만 EarnedSticker로 남긴다.
enum QuestStore {
    /// 이달 목표 직접 지정(0이면 레벨 기본값).
    static let targetKey = "quest.monthlyTarget"

    struct Summary {
        var month: DateInterval
        var monthDone: Int
        var monthTarget: Int
        var points: Int
        var week: DateInterval
        var weekly: [QuestProgress]
        var monthReached: Bool { monthDone >= monthTarget }
    }

    static func facts(sessions: [Session], drills: [DrillLog], checks: [BodyCheck], journals: [DailyJournal]) -> QuestFacts {
        QuestFacts(sessions: sessions.map { .init(date: $0.startsAt, minutes: $0.minutes) },
                   drillDates: drills.map(\.at),
                   conditionDays: checks.map(\.day),
                   journalDates: journals.map(\.entryDate))
    }

    static func monthlyTarget(level: PlayerLevel?, override: Int) -> Int {
        override > 0 ? override : Quest.monthlyTarget(level: level)
    }

    static func summary(now: Date, facts: QuestFacts, level: PlayerLevel?, targetOverride: Int) -> Summary {
        let m = Quest.month(containing: now)
        return Summary(month: m,
                       monthDone: Quest.monthDone(facts: facts, month: m),
                       monthTarget: monthlyTarget(level: level, override: targetOverride),
                       points: Quest.monthPoints(now: now, facts: facts, level: level),
                       week: Quest.week(containing: now),
                       weekly: Quest.weeklyProgress(now: now, facts: facts, level: level))
    }

    /// 이달과 지난달의 목표 달성을 보고 배지를 준다. 이미 받은 건 건너뛴다.
    @discardableResult
    static func awardBadges(_ context: ModelContext, now: Date = Date()) -> [String] {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let facts = QuestFacts(sessions: sessions.map { .init(date: $0.startsAt, minutes: $0.minutes) })
        let target = monthlyTarget(level: RecordPrefs.level(), override: UserDefaults.standard.integer(forKey: targetKey))
        let earned = Set(((try? context.fetch(FetchDescriptor<EarnedSticker>())) ?? []).map(\.stickerKey))
        var fresh: [String] = []
        let cal = Calendar.current
        for back in 0...1 {
            guard let anchor = cal.date(byAdding: .month, value: -back, to: now) else { continue }
            let m = Quest.month(containing: anchor)
            let key = Quest.badgeKey(month: m.start)
            guard !earned.contains(key), Quest.monthDone(facts: facts, month: m) >= target else { continue }
            context.insert(EarnedSticker(stickerKey: key))
            fresh.append(key)
        }
        if !fresh.isEmpty { context.saveOrReport() }
        return fresh
    }
}
