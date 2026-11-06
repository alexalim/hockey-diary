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
}
