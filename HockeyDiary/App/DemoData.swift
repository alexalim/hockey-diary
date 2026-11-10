import Foundation
import SwiftData
import HockeyCore

/// 화면 점검용 예시 데이터. `-ui-demo` 인자로 켜면 메모리 저장소에만 채운다(실제 기록과 섞이지 않는다).
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-demo") }

    @MainActor
    static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        func daysAgo(_ d: Int, hour: Int = 20) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -d, to: Date())!)!
        }
        let skills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        func skill(_ name: String) -> Skill? { skills.first { $0.name == name } }

        // 장비
        let skate = Skate(brand: "Bauer", model: "Vapor X5")
        skate.size = "8"; skate.fit = "Fit 2"; skate.isPrimary = true
        context.insert(skate)
        let a = RunnerSet(name: "A세트"), b = RunnerSet(name: "B세트")
        context.insert(a); context.insert(b)
        a.currentHollow = "1/2"; a.checkThresholdSessions = 6; a.replaceAfterSharpenings = 20
        b.currentHollow = "5/8"
        DiaryStore.install(a, on: skate, at: daysAgo(40), context: context)
        for d in [30, 12] {
            let log = SharpeningLog(hollow: "1/2", at: daysAgo(d, hour: 12))
            context.insert(log); log.runner = a; log.shop = "목동 프로샵"; log.grip = 4; log.glide = 3
        }

        // 수업
        let lesson = Session(type: .lesson, startsAt: daysAgo(3), minutes: 60)
        context.insert(lesson)
        lesson.surface = .indoorRink; lesson.rinkName = "목동 아이스링크"; lesson.iceFeel = .normal
        lesson.moodBefore = 2; lesson.moodAfter = 4; lesson.fatigue = 3
        lesson.coachNotes = "무릎을 더 굽혀서 낮게"; lesson.nextGoal = "크로스오버 리듬 맞추기"
        for (name, fb) in [("크로스오버", "바깥 발 넘길 때 상체가 들려"), ("하키 스톱", "왼쪽은 잘 되는데 오른쪽이 밀려")] {
            guard let s = skill(name) else { continue }
            let l = SkillLearning(); context.insert(l); l.skill = s; l.session = lesson; l.feedback = fb; l.difficulty = 3
        }
        DiaryStore.setUsage(for: lesson, skate: skate, runner: a, iceMinutes: 50, context: context)

        // 미니게임
        let game = Session(type: .miniGame, startsAt: daysAgo(1), minutes: 90)
        context.insert(game)
        game.surface = .indoorRink; game.rinkName = "목동 아이스링크"; game.moodBefore = 3; game.moodAfter = 5
        game.review = "패스 받을 자리를 먼저 잡았더니 편했어"
        if let s = skill("크로스오버") {
            let t = SkillAttempt(); context.insert(t); t.skill = s; t.session = game; t.tried = true; t.outcome = .partial; t.count = 3
        }
        if let s = skill("하키 스톱") {
            let t = SkillAttempt(); context.insert(t); t.skill = s; t.session = game; t.tried = false
        }
        DiaryStore.setUsage(for: game, skate: skate, runner: a, iceMinutes: 45, context: context)
        game.shifts = 14; game.penaltyMinutes = 2
        DiaryStore.replaceShots(for: game.id, with: [
            ShotPoint(x: 0.48, y: 0.3, outcome: .goal), ShotPoint(x: 0.55, y: 0.36, outcome: .saved),
            ShotPoint(x: 0.22, y: 0.4, outcome: .missed), ShotPoint(x: 0.5, y: 0.8, outcome: .blocked),
            ShotPoint(x: 0.62, y: 0.28, outcome: .goal),
        ], context: context)

        // 폰드
        let pond = Session(type: .freePractice, startsAt: daysAgo(10, hour: 15), minutes: 40)
        context.insert(pond)
        pond.surface = .pond; pond.rinkName = "동네 저수지"; pond.weatherMemo = "영하 6도, 바람 약함"; pond.moodAfter = 5

        // 일기
        let j = DailyJournal(entryDate: Date())
        context.insert(j)
        j.mood = 4; j.body = "퇴근하고 링크 다녀옴. 머리가 맑아졌어"; j.tags = ["하키", "업무"]; j.isPrivate = false

        // 락커
        let profile = LockerStore.profile(context)
        profile.numberText = "007"; profile.nameplate = "MAHADA"
        for (i, key) in ["star", "puck"].enumerated() {
            context.insert(StickerPlacement(stickerKey: key, x: 0.3 + 0.35 * Double(i), y: 0.62, zIndex: i))
        }

        // 링크장
        let rink = Rink(name: "목동 아이스링크", address: "서울 양천구 목동")
        rink.isFavorite = true
        context.insert(rink)

        context.saveOrReport()
        LockerStore.awardMilestones(context)
        PracticeStore.seedRoutinesIfNeeded(context)
        let team = Team(name: "목동 펭귄스"); context.insert(team)
        var ids: [UUID] = []
        for (n, num, pos) in [("민수", "9", Position.forward), ("지훈", "17", .forward), ("현우", "23", .forward), ("서준", "4", .defense),
                              ("도윤", "7", .defense), ("골리킴", "30", .goalie), ("용병 재호", "", .any)] {
            let m = TeamMember(teamID: team.id, name: n); m.number = num; m.position = pos; m.isGuest = n.hasPrefix("용병")
            context.insert(m); ids.append(m.id)
        }
        let ev = TeamEvent(teamID: team.id, at: cal.date(byAdding: .day, value: 3, to: daysAgo(0, hour: 21))!)
        ev.rinkName = "목동 아이스링크"; ev.opponent = "강남 베어스"; ev.memo = "흰 저지 · 20:30 집합"
        var att = AttendanceSheet(); for i in 0..<5 { att[ids[i]] = .going }; att[ids[5]] = .maybe; ev.attendance = att
        var lu = Lineup(); lu.assign(ids[0], to: .lw1); lu.assign(ids[1], to: .c1); lu.assign(ids[2], to: .rw1)
        lu.assign(ids[3], to: .ld1); lu.assign(ids[4], to: .rd1); lu.assign(ids[5], to: .g1); ev.lineup = lu
        context.insert(ev)
        context.saveOrReport()
        if let d1 = DrillCatalog.drill("stickhandle-8"), let d2 = DrillCatalog.drill("stop-lines"), let d3 = DrillCatalog.drill("office-ball") {
            context.insert(DrillLog(drill: d1, amount: 3, at: daysAgo(2, hour: 19)))
            context.insert(DrillLog(drill: d2, amount: 10, at: daysAgo(2, hour: 19)))
            context.insert(DrillLog(drill: d3, amount: 5, at: daysAgo(0, hour: 8)))
            context.saveOrReport()
        }
    }
}
