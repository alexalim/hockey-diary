// 테스트 계층: Integration — 실제 SwiftData 저장소(메모리 모드)에 쓰고 다시 읽는다. Mock 없음.
import XCTest
import SwiftData
import HockeyCore
@testable import HockeyDiary

@MainActor
final class StoreIntegrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try AppSchema.container(inMemory: true)
    }

    // T01: 하키가 없는 날 일기 단독 저장·검색·삭제.
    func testJournalWithoutHockey() throws {
        let j = DailyJournal(entryDate: Date())
        j.body = "업무가 바빴고 연인과 다퉜다."
        j.tags = ["업무", "연애"]
        context.insert(j)
        try context.save()

        let found = try context.fetch(FetchDescriptor<DailyJournal>()).filter { $0.body.contains("업무") }
        XCTAssertEqual(found.count, 1)
        XCTAssertTrue(found[0].isPrivate, "기본 비공개")
        XCTAssertEqual(found[0].tags, ["업무", "연애"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0)

        context.delete(found[0])
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyJournal>()), 0)
    }

    // T02·T03: 수업 기술 3개 → 경기에서 1개 시도, 1개 미시도.
    func testLessonToGameSkillLink() throws {
        DiaryStore.seedIfNeeded(context)
        let skills = try context.fetch(FetchDescriptor<Skill>()).prefix(3).map { $0 }
        let lesson = Session(type: .lesson, startsAt: Date().addingTimeInterval(-86_400))
        context.insert(lesson)
        for s in skills {
            let l = SkillLearning()
            context.insert(l)
            l.skill = s
            l.session = lesson
        }
        let game = Session(type: .miniGame, startsAt: Date())
        context.insert(game)
        let tried = SkillAttempt(), untried = SkillAttempt()
        context.insert(tried); context.insert(untried)
        tried.skill = skills[0]; tried.tried = true; tried.outcome = .partial
        untried.skill = skills[1]; untried.tried = false
        tried.session = game; untried.session = game
        try context.save()

        XCTAssertEqual(skills[0].stats.lessonCount, 1)
        XCTAssertEqual(skills[0].stats.triedEvents, 1)
        XCTAssertEqual(skills[1].stats.untriedEvents, 1)
        XCTAssertNil(skills[1].stats.successRate, "미시도는 실패율에 안 들어감")
        XCTAssertEqual(skills[2].stats.triedEvents + skills[2].stats.untriedEvents, 0)

        let recommended = DiaryStore.recommendedSkills(before: game.startsAt, context: context)
        XCTAssertEqual(Set(recommended.map(\.id)), Set(skills.map(\.id)))
    }

    // T14·T11: 러너 교체 이력 보존과 연마 이후 시간 누적.
    func testRunnerSwapAndSharpeningMinutes() throws {
        let skate = Skate(brand: "Bauer", model: "Vapor")
        let a = RunnerSet(name: "A"), b = RunnerSet(name: "B")
        context.insert(skate); context.insert(a); context.insert(b)
        let t0 = Date().addingTimeInterval(-86_400 * 10)
        XCTAssertNil(DiaryStore.install(a, on: skate, at: t0, context: context))
        XCTAssertEqual(skate.currentRunner?.id, a.id)

        let s1 = Session(type: .lesson, startsAt: t0.addingTimeInterval(86_400), minutes: 60)
        context.insert(s1)
        DiaryStore.setUsage(for: s1, skate: skate, runner: a, iceMinutes: 50, context: context)
        let sharp = SharpeningLog(hollow: "5/8", at: t0.addingTimeInterval(86_400 * 2))
        context.insert(sharp); sharp.runner = a
        let s2 = Session(type: .miniGame, startsAt: t0.addingTimeInterval(86_400 * 3), minutes: 90)
        context.insert(s2)
        DiaryStore.setUsage(for: s2, skate: skate, runner: a, iceMinutes: 40, context: context)
        DiaryStore.setUsage(for: s2, skate: skate, runner: a, iceMinutes: 45, context: context) // 수정해도 1건
        try context.save()
        XCTAssertEqual(s2.usages.count, 1)
        XCTAssertEqual(DiaryStore.minutesSinceSharpening(a, context: context), 45)

        XCTAssertNil(DiaryStore.install(b, on: skate, at: t0.addingTimeInterval(86_400 * 4), context: context))
        XCTAssertEqual(skate.currentRunner?.id, b.id)
        XCTAssertEqual(a.installations.count, 1)
        XCTAssertNotNil(a.installations[0].removedAt, "A의 장착 기간이 닫혀 이력으로 남음")
    }

    // ICE-01·ICE-03: 활동 종류와 빙판 유형은 별개, 빙판 유형을 바꿔도 장비 기록은 그대로.
    func testSurfaceChangeKeepsUsage() throws {
        let skate = Skate(brand: "CCM", model: "Jetspeed")
        context.insert(skate)
        let s = Session(type: .regularGame)
        s.surface = .outdoorRink
        context.insert(s)
        DiaryStore.setUsage(for: s, skate: skate, runner: nil, iceMinutes: 70, context: context)
        try context.save()
        s.surface = .pond
        try context.save()
        XCTAssertEqual(s.type, .regularGame)
        XCTAssertEqual(s.surfaceRaw, "POND")
        XCTAssertEqual(s.usages.count, 1)
        XCTAssertEqual(s.usages.first?.iceMinutes, 70)
    }

    // T18: 스티커 4개 배치·회전 후 다시 열어도 위치·크기·각도·앞뒤 순서가 그대로.
    func testStickerPlacementsPersist() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t18-\(UUID().uuidString).store")
        let schema = Schema(AppSchema.models)
        do {
            let c = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let ctx = ModelContext(c)
            for i in 0..<4 {
                let p = StickerPlacement(stickerKey: "star", x: 0.1 * Double(i + 1), y: 0.2, zIndex: i)
                ctx.insert(p)
                p.placement = Placement(x: p.x, y: 0.2 + 0.1 * Double(i), scale: 1.5, rotation: 30 * Double(i), z: 3 - i)
            }
            try ctx.save()
        }
        let c2 = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let back = try ModelContext(c2).fetch(FetchDescriptor<StickerPlacement>()).sorted { $0.x < $1.x }
        XCTAssertEqual(back.count, 4)
        for (i, p) in back.enumerated() {
            XCTAssertEqual(p.x, 0.1 * Double(i + 1), accuracy: 1e-9)
            XCTAssertEqual(p.y, 0.2 + 0.1 * Double(i), accuracy: 1e-9)
            XCTAssertEqual(p.scale, 1.5)
            XCTAssertEqual(p.rotation, 30 * Double(i), accuracy: 1e-9)
            XCTAssertEqual(p.zIndex, 3 - i)
        }
    }

    // T19·T17: 락커 테마·번호를 바꿔도 장비·연마 원본은 그대로, 번호 007 유지.
    func testLockerThemeDoesNotTouchEquipment() throws {
        let skate = Skate(brand: "Bauer", model: "Vapor")
        let runner = RunnerSet(name: "A")
        context.insert(skate); context.insert(runner)
        let log = SharpeningLog(hollow: "5/8")
        context.insert(log); log.runner = runner
        try context.save()
        let profile = LockerStore.profile(context)
        profile.numberText = LockerNumber.normalize("007")
        profile.theme = .neonPink
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<LockerProfile>()).first?.numberText, "007")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Skate>()), 1)
        XCTAssertEqual(runner.sharpenings.first?.hollow, "5/8")
        XCTAssertEqual(skate.name, "Bauer Vapor")
    }

    // LK-13: 성취 스티커는 기록 기준으로 한 번만 발급.
    func testMilestoneStickersAwardedOnce() throws {
        context.insert(Session(type: .lesson))
        try context.save()
        XCTAssertEqual(LockerStore.awardMilestones(context), ["first-lesson"])
        XCTAssertEqual(LockerStore.awardMilestones(context), [])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EarnedSticker>()), 1)
    }

    // P2 워치: 같은 전달이 두 번 와도 활동은 한 건만, 기분·시간 보존.
    func testWatchWorkoutImportedOnce() throws {
        let t0 = Date().addingTimeInterval(-7200)
        let p = WatchWorkoutPayload(type: .regularGame, start: t0, end: t0.addingTimeInterval(5400), moodBefore: 2, moodAfter: 4)
        WatchBridge.importWorkout(p, context: context)
        WatchBridge.importWorkout(p, context: context)
        let all = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].id, p.id)
        XCTAssertEqual(all[0].minutes, 90)
        XCTAssertEqual(all[0].type, .regularGame)
        XCTAssertEqual(all[0].moodAfter, 4)

        // 쉬프트·얼음 위 시간·거리·빙판 유형도 들어온다.
        let q = WatchWorkoutPayload(type: .freePractice, start: t0, end: t0.addingTimeInterval(3600), shifts: 8, onIceSeconds: 930, distanceMeters: 2100, surface: .pond)
        WatchBridge.importWorkout(q, context: context)
        let pond = try XCTUnwrap(context.fetch(FetchDescriptor<Session>()).first { $0.id == q.id })
        XCTAssertEqual(pond.surface, .pond)
        XCTAssertEqual(pond.shifts, 8)
        XCTAssertEqual(pond.onIceMinutes, 16, "930초 → 반올림 16분")
        XCTAssertEqual(pond.distanceMeters, 2100)
    }

    // 슛 차트: 활동별로 저장·교체되고, 활동을 지우면 같이 지워진다.
    func testShotsFollowSession() throws {
        let game = Session(type: .miniGame)
        context.insert(game)
        let other = Session(type: .miniGame)
        context.insert(other)
        try context.save()
        DiaryStore.replaceShots(for: game.id, with: [ShotPoint(x: 0.5, y: 0.3, outcome: .goal), ShotPoint(x: 0.2, y: 0.4, outcome: .saved)], context: context)
        DiaryStore.replaceShots(for: other.id, with: [ShotPoint(x: 0.5, y: 0.8, outcome: .missed)], context: context)
        try context.save()
        XCTAssertEqual(DiaryStore.shots(for: game.id, context: context).count, 2)
        XCTAssertEqual(ShotStats.compute(DiaryStore.shots(for: game.id, context: context).map(\.point)).goals, 1)

        DiaryStore.replaceShots(for: game.id, with: [ShotPoint(x: 0.5, y: 0.3, outcome: .blocked)], context: context)
        try context.save()
        XCTAssertEqual(DiaryStore.shots(for: game.id, context: context).map(\.point.outcome), [.blocked], "초안대로 교체")
        XCTAssertEqual(DiaryStore.shots(for: other.id, context: context).count, 1, "다른 활동 슛은 그대로")

        DiaryStore.deleteShots(for: game.id, context: context)
        context.delete(game)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ShotMark>()), 1)
    }

    // 골리 모드: 세이브·실점이 보존되고 세이브율이 맞다.
    func testGoalieFields() throws {
        let game = Session(type: .regularGame)
        context.insert(game)
        game.playedGoalie = true; game.saves = 27; game.goalsAgainst = 3
        try context.save()
        let back = try XCTUnwrap(context.fetch(FetchDescriptor<Session>()).first)
        XCTAssertEqual(back.goalieStats?.savePctText, "90.0%")
        XCTAssertNil(Session(type: .lesson).goalieStats)
    }

    // 연습: 루틴 저장·왕복, 드릴 기록이 기술별로 묶인다.
    func testRoutineAndDrillLogs() throws {
        // 테스트 호스트 앱이 뜨면서 연습 탭이 실제 저장소에 먼저 시드하고 플래그를 켠다. 메모리 저장소엔 다시 시드되게 플래그를 지운다.
        UserDefaults.standard.removeObject(forKey: "routinesSeeded")
        PracticeStore.seedRoutinesIfNeeded(context)
        let routines = try context.fetch(FetchDescriptor<PracticeRoutine>())
        XCTAssertGreaterThanOrEqual(routines.count, 2, "기본 루틴 2개")
        let r = PracticeRoutine(name: "내 루틴", items: [RoutineItem(drillKey: "stop-lines", target: 12)])
        context.insert(r)
        try context.save()
        XCTAssertEqual(r.items.first?.target, 12)

        let d = try XCTUnwrap(DrillCatalog.drill("stickhandle-8"))
        context.insert(DrillLog(drill: d, amount: 3))
        context.insert(DrillLog(drill: d, amount: 2))
        context.insert(DrillLog(customTitle: "내 드릴", skillName: "", unit: .reps, amount: 10))
        try context.save()
        let by = PracticeStore.bySkill(from: nil, to: Date().addingTimeInterval(60), context: context)
        XCTAssertEqual(by["퍽 드리블"]?.minutes, 5)
        XCTAssertEqual(by["퍽 드리블"]?.sessions, 2)
        XCTAssertNil(by[""], "기술 없는 드릴은 기술별 집계에서 빠짐")
    }

    // 팀: 명단·일정·참석·라인업 저장, 일정으로 경기 기록 만들기는 한 번만.
    func testTeamEventAndSession() throws {
        let team = Team(name: "펭귄스"); context.insert(team)
        let a = TeamMember(teamID: team.id, name: "민수"), b = TeamMember(teamID: team.id, name: "지훈")
        context.insert(a); context.insert(b)
        let ev = TeamEvent(teamID: team.id, at: Date().addingTimeInterval(86_400)); ev.opponent = "베어스"; ev.rinkName = "목동"
        context.insert(ev)
        var att = AttendanceSheet(); att[a.id] = .going; ev.attendance = att
        var lu = Lineup(); lu.assign(a.id, to: .c1); ev.lineup = lu
        try context.save()
        XCTAssertEqual(TeamStore.members(of: team, context: context).count, 2)
        XCTAssertEqual(ev.attendance.count(.going, among: [a.id, b.id]), 1)
        XCTAssertEqual(ev.lineup[.c1], a.id)
        let s1 = TeamStore.makeSession(for: ev, context: context)
        let s2 = TeamStore.makeSession(for: ev, context: context)
        XCTAssertEqual(s1.id, s2.id, "두 번 눌러도 기록은 하나")
        XCTAssertEqual(s1.opponent, "베어스"); XCTAssertEqual(s1.rinkName, "목동"); XCTAssertEqual(s1.type, .regularGame)
    }
}
