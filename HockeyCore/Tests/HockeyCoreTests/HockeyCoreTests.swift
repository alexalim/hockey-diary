// 테스트 계층: Unit — HockeyCore 순수 로직. 외부 의존성 없음. 기획서 12.2 출시 전 검증 시나리오 번호를 함께 적는다.
import XCTest
@testable import HockeyCore

final class SkillStatsTests: XCTestCase {
    let s1 = UUID(), s2 = UUID(), s3 = UUID()

    // T03: 기술이 떠올랐지만 경기에서 못 써봄 → 미시도는 실패로 집계되지 않는다.
    func testUntriedIsNotFailure() {
        let stats = SkillStats.compute(lessonSessionIDs: [s1], attempts: [
            AttemptRecord(sessionID: s2, tried: false),
            AttemptRecord(sessionID: s3, tried: true, outcome: .success),
        ])
        XCTAssertEqual(stats.untriedEvents, 1)
        XCTAssertEqual(stats.triedEvents, 1)
        XCTAssertEqual(stats.evaluated, 1)
        XCTAssertEqual(stats.successRate, 1.0)
    }

    func testOnlyUntriedHasNoRate() {
        let stats = SkillStats.compute(lessonSessionIDs: [], attempts: [AttemptRecord(sessionID: s1, tried: false)])
        XCTAssertNil(stats.successRate, "평가할 시도가 없으면 0%가 아니라 '없음'")
    }

    // 7.1: 시도 횟수를 비우면 1건으로, 일부 성공은 성공과 따로 센다.
    func testCountsAndPartial() {
        let stats = SkillStats.compute(lessonSessionIDs: [s1, s1, s2], attempts: [
            AttemptRecord(sessionID: s3, tried: true, outcome: .partial, count: 4),
            AttemptRecord(sessionID: s2, tried: true, outcome: nil, count: nil),
        ])
        XCTAssertEqual(stats.lessonCount, 2, "같은 수업이 두 번 연결돼도 1회")
        XCTAssertEqual(stats.attemptTotal, 5)
        XCTAssertEqual(stats.partials, 1)
        XCTAssertEqual(stats.successes, 0)
        XCTAssertEqual(stats.evaluated, 1, "결과 없는 시도는 평가 대상이 아님")
        XCTAssertEqual(stats.successRate, 0)
    }

    // F-A03: 경기 전에 배운 기술을 최근 순, 중복 없이.
    func testRecommendRecentSkills() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let a = UUID(), b = UUID(), c = UUID()
        let learned = [
            SkillRecommender.Learned(skillID: a, learnedAt: now.addingTimeInterval(-86_400 * 2)),
            SkillRecommender.Learned(skillID: b, learnedAt: now.addingTimeInterval(-86_400)),
            SkillRecommender.Learned(skillID: a, learnedAt: now.addingTimeInterval(-3_600)),
            SkillRecommender.Learned(skillID: c, learnedAt: now.addingTimeInterval(3_600)), // 경기 이후
        ]
        XCTAssertEqual(SkillRecommender.recent(learned, before: now), [a, b])
    }
}

final class TimeMergeTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // T04: 워치 2대로 같은 시간을 재도 운동 시간은 한 번만 합산한다.
    func testOverlappingDevicesCountOnce() {
        let watch = TimeSpan(start: t0, end: t0.addingTimeInterval(60 * 60))
        let garmin = TimeSpan(start: t0.addingTimeInterval(5 * 60), end: t0.addingTimeInterval(65 * 60))
        XCTAssertEqual(TimeMerge.unionMinutes([watch, garmin]), 65)
        XCTAssertTrue(TimeMerge.isMergeCandidate(watch, garmin))
    }

    func testSeparateSpansAdd() {
        let a = TimeSpan(start: t0, end: t0.addingTimeInterval(30 * 60))
        let b = TimeSpan(start: t0.addingTimeInterval(120 * 60), end: t0.addingTimeInterval(150 * 60))
        XCTAssertEqual(TimeMerge.unionMinutes([b, a]), 60)
        XCTAssertFalse(TimeMerge.isMergeCandidate(a, b))
    }
}

final class EquipmentTests: XCTestCase {
    let runnerA = UUID(), runnerB = UUID(), skate1 = UUID(), skate2 = UUID()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func day(_ n: Int) -> Date { t0.addingTimeInterval(Double(n) * 86_400) }

    // T11: 연마 후 빙상시간을 추가하면 마지막 연마 이후 사용만 누적된다.
    func testMinutesSinceSharpening() {
        let usages = [
            UsageRecord(sessionID: UUID(), at: day(1), skateID: skate1, runnerID: runnerA, iceMinutes: 50),
            UsageRecord(sessionID: UUID(), at: day(3), skateID: skate1, runnerID: runnerA, iceMinutes: 40),
            UsageRecord(sessionID: UUID(), at: day(4), skateID: skate1, runnerID: runnerA, iceMinutes: 30),
        ]
        XCTAssertEqual(EquipmentMath.iceMinutesSinceSharpening(runnerID: runnerA, usages: usages, lastSharpenedAt: day(2)), 70)
        XCTAssertEqual(EquipmentMath.iceMinutesSinceSharpening(runnerID: runnerA, usages: usages, lastSharpenedAt: nil), 120)
    }

    // T13·FR-16: 주력·서브를 번갈아 쓰면 고른 장비에만 반영하고, 같은 활동은 1회만.
    func testUsageAttributedToSelectedEquipmentOnly() {
        let session = UUID()
        let usages = [
            UsageRecord(sessionID: session, at: day(1), skateID: skate1, runnerID: runnerA, iceMinutes: 45),
            UsageRecord(sessionID: session, at: day(1), skateID: skate1, runnerID: runnerA, iceMinutes: 45),
            UsageRecord(sessionID: UUID(), at: day(2), skateID: skate2, runnerID: runnerB, iceMinutes: 60),
        ]
        XCTAssertEqual(EquipmentMath.iceMinutes(skateID: skate1, usages: usages), 45)
        XCTAssertEqual(EquipmentMath.iceMinutes(skateID: skate2, usages: usages), 60)
        XCTAssertEqual(EquipmentMath.iceMinutesSinceSharpening(runnerID: runnerB, usages: usages, lastSharpenedAt: nil), 60)
    }

    // 연마한 지 얼마나 됐는지: 날짜 기준, 3개월이 넘어도 '개월 전'으로.
    func testElapsedText() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 12))!
        func ago(_ d: Int, hour: Int = 12) -> String {
            let past = cal.date(byAdding: .day, value: -d, to: now)!
            return ElapsedText.since(cal.date(bySettingHour: hour, minute: 0, second: 0, of: past)!, now: now, calendar: cal)
        }
        XCTAssertEqual(ago(0), "오늘")
        XCTAssertEqual(ago(1, hour: 23), "어제", "어젯밤 연마도 어제")
        XCTAssertEqual(ago(5), "5일 전")
        XCTAssertEqual(ago(21), "3주 전")
        XCTAssertEqual(ago(95), "3개월 전")
        XCTAssertEqual(ago(400), "1년 전")
    }

    // 연마 후 횟수로 세는 사람: 같은 활동은 1번, 연마 이전 활동은 빼고 센다.
    func testSessionsSinceSharpening() {
        let s = UUID()
        let usages = [
            UsageRecord(sessionID: UUID(), at: day(1), skateID: skate1, runnerID: runnerA, iceMinutes: 50),
            UsageRecord(sessionID: s, at: day(3), skateID: skate1, runnerID: runnerA, iceMinutes: 40),
            UsageRecord(sessionID: s, at: day(3), skateID: skate1, runnerID: runnerA, iceMinutes: 40),
            UsageRecord(sessionID: UUID(), at: day(4), skateID: skate1, runnerID: runnerA, iceMinutes: 30),
            UsageRecord(sessionID: UUID(), at: day(4), skateID: skate2, runnerID: runnerB, iceMinutes: 30),
        ]
        XCTAssertEqual(EquipmentMath.sessionsSinceSharpening(runnerID: runnerA, usages: usages, lastSharpenedAt: day(2)), 2)
        XCTAssertTrue(EquipmentMath.needsCheck(minutesSince: 10, sessionsSince: 8, thresholdMinutes: nil, thresholdSessions: 8))
        XCTAssertFalse(EquipmentMath.needsCheck(minutesSince: 10, sessionsSince: 7, thresholdMinutes: nil, thresholdSessions: 8))
        XCTAssertTrue(EquipmentMath.needsCheck(minutesSince: 600, sessionsSince: 1, thresholdMinutes: 600, thresholdSessions: 8))
        XCTAssertFalse(EquipmentMath.needsCheck(minutesSince: 999, sessionsSince: 99, thresholdMinutes: nil, thresholdSessions: nil))
    }

    // 날 교체: 연마 횟수 또는 사용 기간 중 정한 기준에 닿으면 알림.
    func testRunnerReplacement() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 6))!
        let start = cal.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        XCTAssertEqual(RunnerLife.monthsUsed(since: start, now: now, calendar: cal), 11)
        XCTAssertTrue(RunnerLife.needsReplacement(sharpenings: 20, monthsUsed: 3, afterSharpenings: 20, afterMonths: nil))
        XCTAssertFalse(RunnerLife.needsReplacement(sharpenings: 19, monthsUsed: 3, afterSharpenings: 20, afterMonths: nil))
        XCTAssertTrue(RunnerLife.needsReplacement(sharpenings: 2, monthsUsed: 12, afterSharpenings: nil, afterMonths: 12))
        XCTAssertFalse(RunnerLife.needsReplacement(sharpenings: 99, monthsUsed: 99, afterSharpenings: nil, afterMonths: nil))
    }

    func testCheckOnlyWithUserThreshold() {
        XCTAssertFalse(EquipmentMath.needsCheck(minutesSince: 10_000, thresholdMinutes: nil), "기준 없으면 처방하지 않음")
        XCTAssertTrue(EquipmentMath.needsCheck(minutesSince: 600, thresholdMinutes: 600))
        XCTAssertFalse(EquipmentMath.needsCheck(minutesSince: 599, thresholdMinutes: 600))
    }

    // T14: 한 부츠에서 러너 A↔B 교체 시 이력이 남고 중복 장착은 막힌다.
    func testSwapKeepsHistoryAndBlocksDoubleInstall() throws {
        var spans = [InstallSpan(runnerID: runnerA, skateID: skate1, from: day(0), to: nil)]

        // A가 부츠1에 달린 채로 부츠2에 같은 시점 장착 → 거부
        let clash = InstallSpan(runnerID: runnerA, skateID: skate2, from: day(1), to: nil)
        if case .failure(let e) = InstallPlanner.validate(clash, existing: spans) {
            XCTAssertEqual(e, .runnerAlreadyInstalled(onSkate: skate1))
        } else { XCTFail("충돌이 잡혀야 함") }

        // 부츠1에 B로 교체 → A 구간이 닫히고 B가 열린다
        let result = try InstallPlanner.swap(onto: skate1, runnerID: runnerB, at: day(5), existing: spans).get()
        XCTAssertEqual(result.closing, [0])
        for i in result.closing { spans[i].to = day(5) }
        spans.append(result.new)
        XCTAssertEqual(spans[0].to, day(5), "A의 장착 기간 보존")
        XCTAssertNil(spans[1].to)

        // 이제 A는 비어 있으니 부츠2에 달 수 있다
        let moveA = try InstallPlanner.swap(onto: skate2, runnerID: runnerA, at: day(6), existing: spans).get()
        XCTAssertEqual(moveA.closing, [], "부츠2에는 열린 구간이 없고 A도 이미 닫힘")
    }

    func testMovingInstalledRunnerClosesOldSpan() throws {
        let spans = [InstallSpan(runnerID: runnerA, skateID: skate1, from: day(0), to: nil)]
        let result = try InstallPlanner.swap(onto: skate2, runnerID: runnerA, at: day(2), existing: spans).get()
        XCTAssertEqual(result.closing, [0], "다른 부츠에 달려 있던 같은 러너는 먼저 떼어낸다")
    }

    func testInvalidRange() {
        let bad = InstallSpan(runnerID: runnerA, skateID: skate1, from: day(2), to: day(1))
        if case .failure(let e) = InstallPlanner.validate(bad, existing: []) {
            XCTAssertEqual(e, .invalidRange)
        } else { XCTFail() }
    }
}

final class HollowTests: XCTestCase {
    // T15: 1/2 · 5/8 · 3/4 선택값이 정확히 저장되고 그림 깊이 순서가 일치한다.
    func testPresetLabelsAndDepthOrder() throws {
        let labels = Hollow.presets.map(\.label)
        XCTAssertEqual(labels, ["5/16", "3/8", "7/16", "1/2", "9/16", "5/8", "11/16", "3/4", "7/8", "1"])
        XCTAssertTrue(Hollow.presets.allSatisfy { $0.nickname != nil }, "프리셋마다 별명")
        XCTAssertEqual(Hollow(label: "9/16")?.nickname, "맥데이빗")
        XCTAssertEqual(Hollow(label: "1/2")?.playerNickname, "크로스비")
        XCTAssertEqual(Hollow(label: "5/16")?.playerNickname, "차라")
        XCTAssertNil(Hollow(label: "3/4")?.playerNickname)
        XCTAssertEqual(Hollow(label: "3/4")?.nickname, "활주 스타일")
        XCTAssertEqual(Hollow(label: "1")?.nickname, "활주 스타일", "케인(5/8) 다음부터는 모두 활주 스타일")
        XCTAssertNil(Hollow(label: "0.55")?.nickname, "직접 입력값은 별명 없음")
        XCTAssertEqual(Hollow(label: "1/2")?.feel, "깊은 홈")
        XCTAssertEqual(Hollow(label: "9/16")?.feel, "중간")
        XCTAssertEqual(Hollow(label: "5/8")?.feel, "얕은 홈")
        let depths = Hollow.presets.map(\.grooveDepthInches)
        XCTAssertEqual(depths, depths.sorted(by: >), "반경이 작을수록 홈이 깊다")
        let half = try XCTUnwrap(Hollow(label: "1/2"))
        let fiveEighths = try XCTUnwrap(Hollow(label: "5/8"))
        let threeQuarters = try XCTUnwrap(Hollow(label: "3/4"))
        XCTAssertGreaterThan(half.relativeDepth, fiveEighths.relativeDepth)
        XCTAssertGreaterThan(fiveEighths.relativeDepth, threeQuarters.relativeDepth)
        XCTAssertEqual(Hollow.presets.first?.relativeDepth, 1)
    }

    func testCustomInput() {
        XCTAssertEqual(Hollow(label: "0.55")?.inches, 0.55)
        XCTAssertEqual(Hollow(label: "1 1/4")?.inches, 1.25)
        XCTAssertEqual(Hollow(label: " 5/8\" ")?.label, "5/8")
        XCTAssertNil(Hollow(label: "abc"))
        XCTAssertNil(Hollow(label: "0"))
        XCTAssertNil(Hollow(label: "1/0"))
    }
}

final class InsightsTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // T08: 표본 1건으로 그래프를 열면 인과 단정 없이 표본 부족 상태.
    func testOneSampleIsInsufficient() {
        let s = [ActivitySample(sessionID: UUID(), at: t0, type: .lesson, surface: .indoorRink, minutes: 60,
                                moodBefore: 2, moodAfter: 4)]
        let change = Insights.moodChange(s)
        XCTAssertEqual(change.sufficiency, .insufficient(count: 1, needed: 3))
        XCTAssertNil(change.sentence)
        XCTAssertEqual(Sufficiency(count: 0), .empty)
    }

    // F-B05: 관찰 사실만 말한다. 전후가 다 있는 활동만 비교.
    func testMoodChangeSentence() {
        let s = [
            ActivitySample(sessionID: UUID(), at: t0, type: .lesson, surface: .indoorRink, minutes: 60, moodBefore: 2, moodAfter: 4),
            ActivitySample(sessionID: UUID(), at: t0, type: .miniGame, surface: .indoorRink, minutes: 60, moodBefore: 3, moodAfter: 3),
            ActivitySample(sessionID: UUID(), at: t0, type: .lesson, surface: .pond, minutes: 60, moodBefore: 4, moodAfter: 5),
            ActivitySample(sessionID: UUID(), at: t0, type: .lesson, surface: .pond, minutes: 60, moodBefore: nil, moodAfter: 5),
        ]
        let change = Insights.moodChange(s)
        XCTAssertEqual(change.paired, 3)
        XCTAssertEqual(change.improved, 2)
        XCTAssertEqual(change.same, 1)
        XCTAssertEqual(change.sentence, "운동 전후 기분을 다 남긴 3번 중 2번은 운동하고 기분이 나아졌어요.")
        XCTAssertFalse(change.sentence!.contains("때문"), "원인 단정 금지")
    }

    // ICE-01·ICE-04·T21: 활동 종류와 빙판 유형은 따로 집계, 미입력은 별도.
    func testTypeAndSurfaceAreIndependent() {
        let s = [
            ActivitySample(sessionID: UUID(), at: t0, type: .lesson, surface: .indoorRink, minutes: 60),
            ActivitySample(sessionID: UUID(), at: t0, type: .regularGame, surface: .outdoorRink, minutes: 90),
            ActivitySample(sessionID: UUID(), at: t0, type: .freePractice, surface: .pond, minutes: 40),
            ActivitySample(sessionID: UUID(), at: t0, type: .freePractice, surface: .unknown, minutes: 20),
        ]
        let types = Insights.byType(s)
        let surfaces = Insights.bySurface(s)
        XCTAssertEqual(types[.freePractice], CountMinutes(count: 2, minutes: 60))
        XCTAssertEqual(surfaces[.pond], CountMinutes(count: 1, minutes: 40))
        XCTAssertEqual(surfaces[.unknown], CountMinutes(count: 1, minutes: 20))
        XCTAssertTrue(SurfaceType.unknown.isUnspecified)
    }

    func testPeriodFilterDedupes() {
        let id = UUID()
        let s = [
            ActivitySample(sessionID: id, at: t0, type: .lesson, surface: .indoorRink, minutes: 60),
            ActivitySample(sessionID: id, at: t0, type: .lesson, surface: .indoorRink, minutes: 60),
            ActivitySample(sessionID: UUID(), at: t0.addingTimeInterval(-86_400 * 40), type: .lesson, surface: .indoorRink, minutes: 60),
        ]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let from = Period.month.start(from: t0, calendar: cal)
        XCTAssertEqual(Insights.inPeriod(s, from: from, to: t0).count, 1)
        XCTAssertEqual(Insights.inPeriod(s, from: nil, to: t0).count, 2)
    }
}

final class SleepTests: XCTestCase {
    // 2026-11-05 00:00 KST 기준 시각 도우미
    let base = ISO8601DateFormatter().date(from: "2026-11-04T15:00:00Z")!
    func at(_ hours: Double) -> Date { base.addingTimeInterval(hours * 3600) }

    // T07: 자정 넘는 수면(전날 23:30~다음날 07:00)이 다음날 저녁 경기 직전 잠으로 귀속된다.
    func testCrossMidnightSleepAttributedToNextActivity() throws {
        let segs = [
            SleepSegment(start: at(-0.5), end: at(3)),   // 23:30~03:00
            SleepSegment(start: at(3.3), end: at(7)),    // 잠깐 깼다가 03:18~07:00
            SleepSegment(start: at(13), end: at(13.5)),  // 13:00 낮잠 30분
        ]
        let night = try XCTUnwrap(SleepAttribution.nightBefore(at(20), segments: segs))
        XCTAssertEqual(night.start, at(-0.5))
        XCTAssertEqual(night.end, at(7))
        XCTAssertEqual(night.asleepMinutes, 3 * 60 + 30 + 222, "중간에 깬 18분은 빼고 합산")
    }

    func testOverlappingSourcesCountOnce() throws {
        // 워치와 가민이 같은 잠을 둘 다 기록
        let segs = [SleepSegment(start: at(0), end: at(7)), SleepSegment(start: at(0.2), end: at(7.1))]
        XCTAssertEqual(try XCTUnwrap(SleepAttribution.nightBefore(at(19), segments: segs)).asleepMinutes, 426)
    }

    func testSleepAfterActivityIsIgnored() {
        let segs = [SleepSegment(start: at(23), end: at(31))]
        XCTAssertNil(SleepAttribution.nightBefore(at(20), segments: segs), "활동 뒤의 잠은 귀속하지 않음")
        XCTAssertNil(SleepAttribution.nightBefore(at(20), segments: []))
    }

    // 7.2: 표본이 모자라면 문장 없음, 충분하면 관찰 사실만.
    func testSleepMoodComparison() {
        let few = SleepMoodComparison.compute([(480, 5), (300, 2)])
        XCTAssertNil(few.sentence)
        let pairs: [(sleepMinutes: Int, moodAfter: Int?)] = [(480, 5), (450, 4), (500, 5), (300, 3), (360, 2), (390, 3), (400, nil)]
        let c = SleepMoodComparison.compute(pairs)
        XCTAssertEqual(c.longCount, 3)
        XCTAssertEqual(c.shortCount, 3, "기분 없는 기록은 제외")
        XCTAssertEqual(c.sentence, "최근 6번 기록이에요. 7시간 넘게 잔 날(3번)이 덜 잔 날(3번)보다 운동 후 기분이 더 좋았어요.")
        XCTAssertFalse(c.sentence!.contains("때문"))
    }
}

final class LockerTests: XCTestCase {
    // T17: 번호판 007은 문자열 그대로, 앞자리 0 유지, 4자리까지.
    func testLockerNumberKeepsLeadingZeros() {
        XCTAssertEqual(LockerNumber.normalize("007"), "007")
        XCTAssertEqual(LockerNumber.normalize("00"), "00")
        XCTAssertEqual(LockerNumber.normalize("12345"), "1234")
        XCTAssertEqual(LockerNumber.normalize("9a-8"), "98")
        XCTAssertEqual(LockerNumber.normalize("٣"), "", "아라비아 숫자 등 비ASCII 숫자는 받지 않음")
        XCTAssertEqual(LockerNumber.normalize(""), "")
    }

    func testPlacementClamp() {
        let p = Placement(x: 1.4, y: -0.2, scale: 9, rotation: 540, z: 2).clamped()
        XCTAssertEqual(p.x, 1); XCTAssertEqual(p.y, 0); XCTAssertEqual(p.scale, 3)
        XCTAssertEqual(p.rotation, 180)
        XCTAssertEqual(Placement(x: 0.5, y: 0.5, rotation: -200).clamped().rotation, 160)
    }

    func testStickerOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        XCTAssertEqual(StickerOrder.bringToFront(a, in: [a, b, c]), [b, c, a])
        XCTAssertEqual(StickerOrder.sendToBack(c, in: [a, b, c]), [c, a, b])
        XCTAssertEqual(StickerOrder.bringToFront(UUID(), in: [a, b]), [a, b])
    }

    // LK-13: 실제 기록과 연결된 성취 스티커, 중복 발급 없음.
    func testMilestonesNoDuplicates() {
        let f = MilestoneFacts(lessons: 1, games: 2, goals: 0, sessions: 10, pondSessions: 0, sharpenings: 1)
        XCTAssertEqual(Milestones.earned(f), ["first-lesson", "first-game", "ten-sessions", "first-sharpening"])
        XCTAssertEqual(Milestones.newlyEarned(f, alreadyEarned: ["first-lesson", "ten-sessions"]), ["first-game", "first-sharpening"])
        XCTAssertEqual(Milestones.newlyEarned(f, alreadyEarned: Milestones.earned(f)), [])
        XCTAssertTrue(Milestones.earned(f).allSatisfy { StickerCatalog.def($0)?.kind == .achievement })
    }

    // 락커 스와이프: 왼쪽으로 쓸면 열리고, 범위 밖으로 넘지 않고, 관성으로 휙 넘기면 열린다.
    func testDoorSwing() {
        XCTAssertEqual(DoorSwing.angle(from: 0, translation: -150, width: 300), 70)
        XCTAssertEqual(DoorSwing.angle(from: 0, translation: 200, width: 300), 0, "반대로 밀면 닫힌 채")
        XCTAssertEqual(DoorSwing.angle(from: 0, translation: -900, width: 300), DoorSwing.openAngle)
        XCTAssertEqual(DoorSwing.angle(from: DoorSwing.openAngle, translation: 150, width: 300), 35, "열린 문을 오른쪽으로 쓸면 닫힘")
        XCTAssertFalse(DoorSwing.shouldOpen(current: 20, predicted: 30, wasOpen: false), "살짝 열다 놓으면 다시 닫힘")
        XCTAssertTrue(DoorSwing.shouldOpen(current: 20, predicted: 90, wasOpen: false), "휙 넘기면 열림")
        XCTAssertTrue(DoorSwing.shouldOpen(current: 60, predicted: 60, wasOpen: false))
        XCTAssertTrue(DoorSwing.shouldOpen(current: 90, predicted: 80, wasOpen: true), "열린 문을 조금 밀면 열린 채")
        XCTAssertFalse(DoorSwing.shouldOpen(current: 50, predicted: 40, wasOpen: true))
        XCTAssertEqual(DoorSwing.progress(DoorSwing.openAngle / 2), 0.5, accuracy: 1e-9)
    }

    func testCatalogKeysUnique() {
        let keys = StickerCatalog.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}

final class RuleGuideTests: XCTestCase {
    // 8.2: 초기 주제 6개, 각 카드에 퀴즈 1문항, 정답 번호가 보기 범위 안.
    func testTopicsAreComplete() {
        XCTAssertEqual(RuleGuide.topics.map(\.id), ["offside", "icing", "faceoff", "linechange", "penalties", "rink", "equipment", "gametime", "nogoal", "fouls", "goalie", "terms", "positions"])
        for t in RuleGuide.topics {
            XCTAssertFalse(t.summary.isEmpty)
            XCTAssertGreaterThanOrEqual(t.points.count, 3, t.id)
            XCTAssertTrue(t.quiz.options.indices.contains(t.quiz.answer), t.id)
            XCTAssertTrue(t.reference.hasPrefix("Rule"), t.id)
        }
    }
}

final class SeasonReportTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // T09·P1 시즌 리포트: 기간 안 활동만, 기술은 많이 나온 순, 기분 값은 내보내지 않고 '최고의 날' 수만.
    func testReportSummaries() {
        let samples = [
            ActivitySample(sessionID: UUID(), at: t0, type: .lesson, surface: .indoorRink, minutes: 60, moodBefore: 2, moodAfter: 5),
            ActivitySample(sessionID: UUID(), at: t0.addingTimeInterval(3600 * 24), type: .miniGame, surface: .pond, minutes: 40, moodAfter: 4),
            ActivitySample(sessionID: UUID(), at: t0.addingTimeInterval(-3600 * 24 * 400), type: .lesson, surface: .indoorRink, minutes: 60),
        ]
        let events = [
            SeasonReport.SkillEvent(skill: "크로스오버", at: t0, lesson: true, tried: false),
            SeasonReport.SkillEvent(skill: "크로스오버", at: t0.addingTimeInterval(86_400), lesson: false, tried: true),
            SeasonReport.SkillEvent(skill: "하키 스톱", at: t0, lesson: true, tried: false),
            SeasonReport.SkillEvent(skill: "하키 스톱", at: t0.addingTimeInterval(86_400), lesson: false, tried: false),
        ]
        let r = SeasonReport.make(title: "이번 시즌", from: t0.addingTimeInterval(-86_400 * 30), to: t0.addingTimeInterval(86_400 * 2),
                                  samples: samples, skillEvents: events)
        XCTAssertEqual(r.sessions, 2, "기간 밖 활동 제외")
        XCTAssertEqual(r.minutes, 100)
        XCTAssertEqual(r.byType[.lesson], 1)
        XCTAssertEqual(r.bySurface[.pond], 1)
        XCTAssertEqual(r.skillsLearned, 2)
        XCTAssertEqual(r.topSkills.first?.name, "크로스오버")
        XCTAssertEqual(r.topSkills.first?.tried, 1)
        XCTAssertEqual(r.topSkills.last?.tried, 0, "미시도는 시도로 세지 않음")
        XCTAssertEqual(r.bestDays, 1)
    }

    // 리포트 공유를 켠 일기만, 기간 안, 최근 2개, 40자까지.
    func testSharedJournalLines() {
        let long = String(repeating: "가", count: 50)
        let lines = [
            SeasonReport.SharedLine(at: t0, text: "첫 골 넣은 날"),
            SeasonReport.SharedLine(at: t0.addingTimeInterval(-86_400), text: long),
            SeasonReport.SharedLine(at: t0.addingTimeInterval(-86_400 * 2), text: "오래된 한 줄"),
            SeasonReport.SharedLine(at: t0.addingTimeInterval(-86_400 * 500), text: "기간 밖"),
        ]
        let r = SeasonReport.make(title: "t", from: t0.addingTimeInterval(-86_400 * 30), to: t0, samples: [], skillEvents: [], sharedLines: lines)
        XCTAssertEqual(r.sharedLines, ["첫 골 넣은 날", String(repeating: "가", count: 40) + "…"])
        XCTAssertEqual(SeasonReport.make(title: "t", from: nil, to: t0, samples: [], skillEvents: []).sharedLines, [], "아무것도 안 넘기면 일기 없음")
    }

    // 11.2 deny-by-default: 리포트 타입에 민감 정보 칸이 없다.
    func testReportHasNoSensitiveFields() {
        let r = SeasonReport.make(title: "t", from: nil, to: t0, samples: [], skillEvents: [])
        let labels = Mirror(reflecting: r).children.compactMap(\.label).joined(separator: ",").lowercased()
        for banned in ["journal", "diary", "body", "sleep", "heart", "health", "photo", "latitude", "location", "mood"] {
            XCTAssertFalse(labels.contains(banned), banned)
        }
    }
}

final class SummaryFactsTests: XCTestCase {
    // P2 AI 요약: 고른 기간 사실만, 미시도는 '기회 없음'으로, 메모는 켰을 때만.
    func testFactsText() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let s = [SummaryFacts.SessionFact(at: t, type: .miniGame, minutes: 60, learned: [],
                                          tried: [("크로스오버", .partial)], untried: ["하키 스톱"], notes: "턴이 늦었다")]
        let with = SummaryFacts.text(periodTitle: "최근 30일", sessions: s, includeNotes: true)
        XCTAssertTrue(with.contains("크로스오버(일부 성공)"))
        XCTAssertTrue(with.contains("기회가 없어 못 써본 기술: 하키 스톱"))
        XCTAssertTrue(with.contains("메모: 턴이 늦었다"))
        XCTAssertFalse(SummaryFacts.text(periodTitle: "x", sessions: s, includeNotes: false).contains("턴이 늦었다"))
        XCTAssertTrue(SummaryFacts.instructions.contains("의료"))
        // 피드백: AI 요약에 ** 기호가 그대로 보임 → 화면에 보이기 전에 지운다.
        XCTAssertEqual(SummaryFacts.clean("최근 **페이스오프**를 연습했어.\n- **퍽 드리블**도 해봐.\n## 끝"),
                       "최근 페이스오프를 연습했어.\n퍽 드리블도 해봐.\n끝")
    }
}

final class CycleTests: XCTestCase {
    // F-C04·7.2: 표본이 모자라면 문장 없음, 충분하면 관찰 사실만(처방 없음).
    func testCycleFatigueComparison() {
        XCTAssertNil(CycleFatigueComparison.compute([(true, 4), (false, 2)]).sentence)
        let pairs: [(inPeriod: Bool, fatigue: Int?)] = [(true, 4), (true, 5), (true, 4), (false, 2), (false, 3), (false, 2), (false, nil)]
        let c = CycleFatigueComparison.compute(pairs)
        XCTAssertEqual(c.otherCount, 3)
        XCTAssertEqual(c.sentence, "생리 기간에 탄 날(3번)이 다른 날(3번)보다 피로도가 더 높았어요.")
        for banned in ["하면 안", "쉬어", "때문"] { XCTAssertFalse(c.sentence!.contains(banned)) }
    }
}

final class WatchPayloadTests: XCTestCase {
    // P2 워치: 아이폰으로 보내는 형식 왕복, 잘못된 값은 거부.
    func testRoundTripAndValidation() throws {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let p = WatchWorkoutPayload(type: .miniGame, start: t, end: t.addingTimeInterval(3600), moodBefore: 2, moodAfter: 4, savedToHealth: true)
        let back = try XCTUnwrap(WatchWorkoutPayload(dictionary: p.dictionary))
        XCTAssertEqual(back, p)
        var bad = p.dictionary; bad["end"] = t.addingTimeInterval(-10).timeIntervalSince1970
        XCTAssertNil(WatchWorkoutPayload(dictionary: bad), "끝이 시작보다 빠르면 거부")
        var odd = p.dictionary; odd["moodAfter"] = 9
        XCTAssertNil(WatchWorkoutPayload(dictionary: odd)?.moodAfter, "범위 밖 기분은 버림")
        XCTAssertNil(WatchWorkoutPayload(dictionary: ["kind": "other"]))
        // 쉬프트·거리·빙판 유형 왕복, 음수는 버림
        let q = WatchWorkoutPayload(type: .freePractice, start: t, end: t.addingTimeInterval(1800), shifts: 9, onIceSeconds: 840, distanceMeters: 2300, surface: .pond)
        let qb = try XCTUnwrap(WatchWorkoutPayload(dictionary: q.dictionary))
        XCTAssertEqual(qb, q)
        var neg = q.dictionary; neg["shifts"] = -1; neg["distance"] = -5.0
        let nb = try XCTUnwrap(WatchWorkoutPayload(dictionary: neg))
        XCTAssertNil(nb.shifts); XCTAssertNil(nb.distanceMeters)
    }
}

final class EffortTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func hr(_ pattern: [(seconds: Int, bpm: Double)]) -> [HeartSample] {
        pattern.map { HeartSample(at: t0.addingTimeInterval(TimeInterval($0.seconds)), bpm: $0.bpm) }
    }

    // 심박 구간: 표본 사이 시간을 구간에 더한다. 끊긴 구간은 60초까지만.
    func testZones() {
        let s = hr([(0, 100), (10, 150), (20, 175), (30, 175), (400, 120)])
        let z = HeartZones.seconds(s, maxHR: 190)   // 100/190=.53→0, 150=.79→2, 175=.92→4, 175→4(60초 상한)
        XCTAssertEqual(z, [10, 0, 10, 0, 70])
        XCTAssertEqual(HeartZones.zoneIndex(0.3), 0)
        XCTAssertEqual(HeartZones.zoneIndex(0.95), 4)
        XCTAssertEqual(HeartZones.seconds([], maxHR: 190), [0, 0, 0, 0, 0])
    }

    // 쉬프트 짐작: 높은 심박 구간 두 개, 짧은 튐과 짧은 끊김은 무시.
    func testShiftEstimate() {
        var p: [(Int, Double)] = []
        for s in stride(from: 0, to: 60, by: 5) { p.append((s, 110)) }        // 벤치 1분
        for s in stride(from: 60, to: 120, by: 5) { p.append((s, 165)) }      // 얼음 1분
        p.append((122, 120)); p.append((127, 118))                             // 10초 끊김(이어 붙임)
        for s in stride(from: 130, to: 160, by: 5) { p.append((s, 168)) }     // 얼음 30초 더
        for s in stride(from: 160, to: 240, by: 5) { p.append((s, 108)) }     // 벤치
        p.append((245, 170))                                                   // 5초 튐(무시)
        for s in stride(from: 250, to: 320, by: 5) { p.append((s, 105)) }
        for s in stride(from: 320, to: 380, by: 5) { p.append((s, 170)) }     // 얼음 1분
        let spans = ShiftDetector.estimate(hr(p.map { (seconds: $0.0, bpm: $0.1) }))
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(ShiftDetector.onIceSeconds(spans), 95 + 55)
        XCTAssertEqual(ShiftDetector.estimate(hr([(0, 120), (30, 122), (60, 121), (90, 119), (120, 120), (150, 123)])), [], "심박 차이가 작으면 못 나눔")
    }

    func testEffortLines() {
        XCTAssertEqual(EffortSummary(shifts: 9, onIceMinutes: 14, distanceMeters: 2340, kilocalories: 512.4).lines,
                       ["쉬프트 9번", "얼음 위 14분", "2.3km", "512kcal"])
        XCTAssertEqual(EffortSummary(distanceMeters: 50).lines, [], "100m 미만 거리는 안 보여줌")
    }
}

final class TacticGuideTests: XCTestCase {
    func testTacticsComplete() {
        let ids = TacticGuide.topics.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for t in TacticGuide.topics {
            XCTAssertGreaterThanOrEqual(t.points.count, 3, t.id)
            XCTAssertFalse(t.when.isEmpty || t.practice.isEmpty || t.summary.isEmpty, t.id)
        }
    }
}

final class ShotTests: XCTestCase {
    // 슛 차트: 구역 나누기, 성공률, 표본 부족 처리, 골리 세이브율.
    func testZones() {
        XCTAssertEqual(ShotZone.classify(x: 0.5, y: 0.35), .slot)
        XCTAssertEqual(ShotZone.classify(x: 0.2, y: 0.35), .leftCircle)
        XCTAssertEqual(ShotZone.classify(x: 0.8, y: 0.35), .rightCircle)
        XCTAssertEqual(ShotZone.classify(x: 0.5, y: 0.8), .point)
        XCTAssertEqual(ShotZone.classify(x: 0.5, y: 0.05), .nearGoalLine)
        XCTAssertEqual(ShotPoint(x: 1.4, y: -1, outcome: .goal).x, 1, "좌표는 0~1로 자른다")
    }

    func testShotStats() {
        let shots = [
            ShotPoint(x: 0.5, y: 0.3, outcome: .goal), ShotPoint(x: 0.5, y: 0.4, outcome: .saved), ShotPoint(x: 0.55, y: 0.3, outcome: .goal),
            ShotPoint(x: 0.2, y: 0.3, outcome: .missed), ShotPoint(x: 0.5, y: 0.8, outcome: .blocked),
        ]
        let st = ShotStats.compute(shots)
        XCTAssertEqual(st.total, 5); XCTAssertEqual(st.goals, 2); XCTAssertEqual(st.onTarget, 3)
        XCTAssertEqual(st.byZone[.slot]?.shots, 3); XCTAssertEqual(st.byZone[.slot]?.goals, 2)
        XCTAssertEqual(st.bestZone(), .slot)
        XCTAssertEqual(st.sentence(), "슛 5번 중 2골. 슬롯에서 3번 쏴서 2골(67%)로 가장 잘 들어갔어요.")
        XCTAssertNil(ShotStats.compute([shots[0]]).sentence(), "표본 부족이면 문장 없음")
        XCTAssertNil(ShotStats.compute([]).shootingRate, "슛이 없으면 0%가 아니라 없음")
    }

    func testGoalieStats() {
        let g = GoalieStats(saves: 27, goalsAgainst: 3)
        XCTAssertEqual(g.shotsFaced, 30)
        XCTAssertEqual(g.savePctText, "90.0%")
        XCTAssertNil(GoalieStats(saves: 0, goalsAgainst: 0).savePct)
        XCTAssertEqual(GoalieStats.sum([g, GoalieStats(saves: 13, goalsAgainst: 2)]).savePctText, "88.9%")
    }
}

final class DrillTests: XCTestCase {
    // 드릴은 모두 기존 기술 사전의 기술과 이어져야 한다(연습량이 기술 성장에 붙으려면).
    func testCatalogLinksToSkills() {
        let skills = Set(SkillGuide.entries.map(\.name))
        for d in DrillCatalog.all {
            XCTAssertTrue(skills.contains(d.skillName), "\(d.key) → \(d.skillName)")
            XCTAssertFalse(d.howTo.isEmpty)
            XCTAssertGreaterThan(d.defaultTarget, 0)
        }
        XCTAssertEqual(Set(DrillCatalog.all.map(\.key)).count, DrillCatalog.all.count, "키 중복 없음")
        XCTAssertFalse(DrillCatalog.offIce.isEmpty)
    }

    func testRoutineRoundTripAndEstimate() {
        for r in StarterRoutine.all {
            XCTAssertTrue(r.items.allSatisfy { DrillCatalog.drill($0.drillKey) != nil }, r.name)
        }
        let items = StarterRoutine.all[1].items
        XCTAssertEqual(RoutineItem.decode(RoutineItem.encode(items)), items)
        XCTAssertEqual(RoutineItem.decode("깨진 값"), [])
        // 10번(1분) + 10번(1분) + 3분 + 50번(5분) + 25번(3분) = 13분
        XCTAssertEqual(StarterRoutine.estimatedMinutes(items), 13)
        XCTAssertEqual(RoutineItem(drillKey: "x", target: 0).target, 1, "목표는 1 이상")
    }

    func testDrillStats() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let e = [
            DrillStats.Entry(skillName: "퍽 드리블", at: t, amount: 2, unit: .minutes),
            DrillStats.Entry(skillName: "퍽 드리블", at: t.addingTimeInterval(600), amount: 5, unit: .minutes),
            DrillStats.Entry(skillName: "리스트 샷", at: t.addingTimeInterval(86_400), amount: 25, unit: .reps),
        ]
        let by = DrillStats.bySkill(e)
        XCTAssertEqual(by["퍽 드리블"], DrillStats.SkillLine(sessions: 2, reps: 0, minutes: 7))
        XCTAssertEqual(by["리스트 샷"]?.text, "1회 · 25번")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        XCTAssertEqual(DrillStats.practiceDays(e, calendar: cal), 2)
    }
}

final class TeamTests: XCTestCase {
    let a = UUID(), b = UUID(), c = UUID()

    // 라인업: 한 사람은 한 자리에만, 왕복 저장, 카톡 글.
    func testLineup() {
        var l = Lineup()
        l.assign(a, to: .c1); l.assign(b, to: .lw1); l.assign(a, to: .c2)
        XCTAssertNil(l[.c1], "다른 자리로 옮기면 원래 자리는 비운다")
        XCTAssertEqual(l[.c2], a)
        l.assign(c, to: .g1)
        XCTAssertEqual(Lineup.decode(l.encode()), l)
        XCTAssertEqual(Lineup.decode("깨짐"), Lineup())
        let names = [a: "민수", b: "지훈", c: "골리킴"]
        XCTAssertEqual(l.text(names: names), "1라인  지훈 · — · —\n2라인  — · 민수 · —\n골리  골리킴")
        XCTAssertEqual(l.assignedMembers, [a, b, c])
    }

    func testAttendance() {
        var s = AttendanceSheet()
        s[a] = .going; s[b] = .maybe; s[c] = .going
        XCTAssertEqual(s.count(.going, among: [a, b, c]), 2)
        XCTAssertEqual(s[UUID()], .unknown)
        s[a] = .unknown
        XCTAssertNil(s.marks[a], "답 없음은 저장하지 않는다")
        XCTAssertEqual(AttendanceSheet.decode(s.encode()), s)
    }

    func testEventText() {
        let t = TeamText.event(teamName: "목동 펭귄스", title: "정규게임", when: "11월 15일 (토) 21:00", rink: "목동 아이스링크",
                               opponent: "강남 베어스", memo: "흰 저지", going: 11, maybe: 2, total: 15, lineup: "1라인  A · B · C")
        XCTAssertTrue(t.hasPrefix("[목동 펭귄스] 정규게임\n⏰ 11월 15일 (토) 21:00\n📍 목동 아이스링크\n🆚 강남 베어스\n✅ 참석 11명 · 미정 2명 (15명 중)"))
        XCTAssertTrue(t.hasSuffix("라인업\n1라인  A · B · C"))
    }
}

final class DomainTests: XCTestCase {
    // FR-02: 미니게임은 점수 없이, 정규게임 스탯은 정규게임에서만 보인다.
    func testGameStatsOnlyForRegularGame() {
        XCTAssertFalse(ActivityType.miniGame.showsGameStats)
        XCTAssertTrue(ActivityType.regularGame.showsGameStats)
        XCTAssertTrue(ActivityType.miniGame.isGame)
        XCTAssertFalse(ActivityType.lesson.isGame)
    }

    func testSurfaceRawValuesMatchSpec() {
        XCTAssertEqual(SurfaceType.allCases.map(\.rawValue), ["INDOOR_RINK", "OUTDOOR_RINK", "POND", "OTHER", "UNKNOWN"])
    }

    func testTags() {
        XCTAssertEqual(JournalTag.parse(" 업무, 연애 ,업무,,하키"), ["업무", "연애", "하키"])
        XCTAssertEqual(JournalTag.join(["하키", "하키", " 업무"]), "하키,업무")
    }

    // 기본 기술은 모두 설명이 있고 이름이 겹치지 않는다. 사용자 기술은 설명 없음.
    func testSkillGuideCoversDefaults() {
        let names = SkillGuide.entries.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(SkillGuide.entries.allSatisfy { !$0.summary.isEmpty && !$0.category.isEmpty })
        XCTAssertNotNil(SkillGuide.summary(for: " 페이스오프 "))
        XCTAssertNotNil(SkillGuide.summary(for: "포지셔닝"))
        XCTAssertNil(SkillGuide.summary(for: "내가 만든 기술"))
    }

    func testMoodClamp() {
        XCTAssertNil(Mood.clamp(0))
        XCTAssertEqual(Mood.clamp(5), 5)
        XCTAssertNil(Mood.clamp(nil))
    }
}

final class RinkDirectoryTests: XCTestCase {
    let sample = [
        RinkEntry(name: "아이스웍스 역삼점", aliases: ["아이스웍스", "역삼", "강남"], address: "서울특별시 강남구 역삼로 123", latitude: 37.49, longitude: 127.04),
        RinkEntry(name: "목동아이스링크", aliases: ["목동", "양천"], address: "서울특별시 양천구 안양천로 939", latitude: 37.53, longitude: 126.87),
        RinkEntry(name: "고양 어울림누리 얼음마루", aliases: ["고양", "성사동"], address: "경기도 고양시 덕양구 어울림로 33", latitude: 37.65, longitude: 126.83),
    ]

    func testNeighbourhoodFindsRink() {
        XCTAssertEqual(RinkDirectory.search("역삼", in: sample).map(\.name), ["아이스웍스 역삼점"])
        XCTAssertEqual(RinkDirectory.search("강남 아이스링크", in: sample).map(\.name), ["아이스웍스 역삼점"])
    }

    func testGenericWordAloneReturnsAll() {
        XCTAssertEqual(RinkDirectory.search("아이스링크", in: sample).count, 3)
        XCTAssertEqual(RinkDirectory.search("빙상장", in: sample).count, 3)
        XCTAssertTrue(RinkDirectory.search("  ", in: sample).isEmpty)
    }

    func testNameMatchRanksAboveAddressMatch() {
        // "양천"은 목동의 별칭이자 주소. 이름에 들어간 "목동"이 먼저.
        XCTAssertEqual(RinkDirectory.search("목동", in: sample).first?.name, "목동아이스링크")
        XCTAssertTrue(RinkDirectory.search("부산", in: sample).isEmpty)
    }

    func testMultipleTokensMustAllMatch() {
        XCTAssertEqual(RinkDirectory.search("고양 덕양구", in: sample).count, 1)
        XCTAssertTrue(RinkDirectory.search("고양 강남", in: sample).isEmpty)
    }

    func testSameRinkIgnoresSpacingAndPrefix() {
        XCTAssertTrue(RinkDirectory.sameRink("목동 아이스링크", "목동아이스링크"))
        XCTAssertTrue(RinkDirectory.sameRink("아이스웍스 역삼점", "아이스웍스"))
        XCTAssertFalse(RinkDirectory.sameRink("목동아이스링크", "태릉국제스케이트장"))
    }

    func testBundledDirectoryCoversKnownRinks() {
        let all = RinkDirectory.all
        XCTAssertGreaterThanOrEqual(all.count, 30, "내장 목록이 너무 적다")
        XCTAssertFalse(RinkDirectory.search("역삼").isEmpty, "역삼 검색이 비면 피드백 재발")
        XCTAssertFalse(RinkDirectory.search("목동").isEmpty)
        XCTAssertEqual(RinkDirectory.search("역삼").first?.name, "아이스웍스 역삼점")
        XCTAssertTrue(RinkDirectory.search("역삼").first?.verified ?? false)
        XCTAssertGreaterThanOrEqual(all.filter(\.verified).count, 30, "운영 확인된 곳이 너무 적다")
        XCTAssertEqual(Set(all.map(\.name)).count, all.count, "이름 중복")
        for e in all {
            XCTAssertFalse(e.address.isEmpty, "\(e.name) 주소 없음")
        }
    }
}

final class PersonalBestTests: XCTestCase {
    func testNewGoalRecord() {
        let past = [BestInput(type: .miniGame, minutes: 60, goals: 1), BestInput(type: .regularGame, minutes: 90, goals: 2)]
        let r = PersonalBest.check(BestInput(type: .miniGame, minutes: 60, goals: 3), history: past)
        XCTAssertEqual(r.map(\.title), ["한 경기 최다 골"])
        XCTAssertEqual(r.first?.previous, 2)
    }

    func testNoBadgeWithoutHistoryOrZero() {
        XCTAssertTrue(PersonalBest.check(BestInput(type: .miniGame, minutes: 60, goals: 2), history: []).isEmpty)
        let past = [BestInput(type: .miniGame, minutes: 60, goals: 0)]
        XCTAssertEqual(PersonalBest.check(BestInput(type: .miniGame, minutes: 60, goals: 0), history: past).count, 0)
        // 지난 기록에 골 칸이 비어 있으면 비교할 게 없다.
        XCTAssertTrue(PersonalBest.check(BestInput(type: .miniGame, minutes: 50, goals: 2), history: [BestInput(type: .miniGame, minutes: 60)]).isEmpty)
    }

    func testLongestSameTypeOnly() {
        let past = [BestInput(type: .lesson, minutes: 60), BestInput(type: .freePractice, minutes: 120)]
        XCTAssertEqual(PersonalBest.check(BestInput(type: .lesson, minutes: 90), history: past).map(\.title), ["가장 오래 탄 수업"])
        XCTAssertTrue(PersonalBest.check(BestInput(type: .lesson, minutes: 60), history: past).isEmpty, "같으면 새 기록 아님")
    }
}

final class QuickPrefillTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    func d(_ h: Int, _ m: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: h, minute: m))! }

    func testWorkoutWins() {
        let p = QuickPrefill.plan(now: d(21, 40), defaultMinutes: 60, lastMinutes: 50,
                                  events: [.init(start: d(20, 0), minutes: 90)],
                                  workouts: [(d(20, 5), d(21, 20))], calendar: cal)
        XCTAssertEqual(p.source, .workout)
        XCTAssertEqual(p.start, d(20, 5)); XCTAssertEqual(p.minutes, 75)
    }

    func testOldWorkoutIgnoredThenTeamEvent() {
        let p = QuickPrefill.plan(now: d(21, 40), defaultMinutes: 60, lastMinutes: 50,
                                  events: [.init(start: d(9, 0), minutes: 60), .init(start: d(20, 0), minutes: 90)],
                                  workouts: [(d(10, 0), d(11, 0))], calendar: cal)
        XCTAssertEqual(p.source, .teamEvent(index: 1))
        XCTAssertEqual(p.start, d(20, 0)); XCTAssertEqual(p.minutes, 90)
    }

    func testLastSessionMinutesRoundedDown() {
        let p = QuickPrefill.plan(now: d(21, 43), defaultMinutes: 60, lastMinutes: 50, events: [], workouts: [], calendar: cal)
        XCTAssertEqual(p.source, .lastSession)
        XCTAssertEqual(p.minutes, 50); XCTAssertEqual(p.start, d(20, 50))
        let q = QuickPrefill.plan(now: d(21, 43), defaultMinutes: 60, lastMinutes: nil, events: [], workouts: [], calendar: cal)
        XCTAssertEqual(q.source, .none); XCTAssertEqual(q.start, d(20, 40))
    }
}

final class TrendTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    func day(_ d: Int, _ h: Int = 20) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    func testWeekDailyBucketsAndPrevious() {
        let now = day(10, 22)
        let items: [(at: Date, value: Int)] = [(day(10), 1), (day(10, 8), 1), (day(4), 1), (day(3), 1), (day(1), 1)]
        let t = Trend.build(items, period: .week, now: now, calendar: cal)
        XCTAssertEqual(t.buckets.count, 7)
        XCTAssertEqual(t.buckets.last?.current, 2, "오늘 칸")
        XCTAssertEqual(t.buckets.first?.current, 1, "11/4 칸")
        XCTAssertEqual(t.total, 3)
        XCTAssertEqual(t.previousTotal, 2, "11/3, 11/1은 앞선 7일")
        XCTAssertEqual(t.comparison(.sessions, periodTitle: "7일"), "그 전 7일보다 1회 늘었어요.")
    }

    func testMonthAndQuarterShapes() {
        let now = day(10)
        XCTAssertEqual(Trend.build([], period: .month, now: now, calendar: cal).buckets.count, 5)
        XCTAssertEqual(Trend.build([], period: .quarter, now: now, calendar: cal).buckets.count, 13)
        XCTAssertNil(Trend.build([], period: .month, now: now, calendar: cal).comparison(.minutes, periodTitle: "30일"))
    }

    func testAllIsMonthlyWithoutComparison() {
        let t = Trend.build([(day(2), 60), (day(10), 30)], period: .all, now: day(10), calendar: cal)
        XCTAssertEqual(t.buckets.count, 12)
        XCTAssertEqual(t.buckets.last?.current, 90)
        XCTAssertNil(t.previousTotal)
    }
}

final class HabitTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    // 2026-11-09는 월요일
    func d(_ m: Int, _ day: Int, _ h: Int = 20) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: day, hour: h))! }

    func testStreakCountsWeeksAndKeepsThisWeekPending() {
        // 10/19주, 10/26주, 11/2주 탐. 이번 주(11/9~)는 아직.
        let s = WeeklyStreak.compute([d(10, 20), d(10, 28), d(11, 3), d(11, 5)], now: d(11, 10), calendar: cal)
        XCTAssertEqual(s.current, 3)
        XCTAssertTrue(s.thisWeekPending)
        XCTAssertEqual(s.best, 3)
    }

    func testGapBreaksButRestDoesNot() {
        let dates = [d(10, 6), d(10, 13), d(11, 3), d(11, 10)]   // 10/20주, 10/27주 비었음
        XCTAssertEqual(WeeklyStreak.compute(dates, now: d(11, 10), calendar: cal).current, 2)
        XCTAssertEqual(WeeklyStreak.compute(dates, now: d(11, 10), calendar: cal).best, 2)
        let rest = [RestRange(start: d(10, 19, 0), end: d(11, 1, 0))]
        let r = WeeklyStreak.compute(dates, rests: rest, now: d(11, 10), calendar: cal)
        XCTAssertEqual(r.current, 4, "쉬는 기간은 끊지 않는다")
        XCTAssertEqual(r.milestone, 4)
    }

    func testRestRangeRoundTrip() {
        let list = [RestRange(start: d(1, 1), end: d(2, 1)), RestRange(start: d(11, 1))]
        XCTAssertEqual(RestRange.decode(RestRange.encode(list)), list)
    }

    func testHomePromptOrder() {
        let ev = HomePrompt.Event(title: "정규게임", start: d(11, 10, 19), minutes: 90, logged: false)
        XCTAssertEqual(HomePrompt.pick(now: d(11, 10, 21), resting: false, events: [ev], loggedToday: false, journaledToday: false, goal: nil, calendar: cal),
                       .logEvent(title: "정규게임"))
        XCTAssertEqual(HomePrompt.pick(now: d(11, 10, 9), resting: false, events: [ev], loggedToday: false, journaledToday: false, goal: "스톱", calendar: cal),
                       .beforeEvent(title: "정규게임", at: d(11, 10, 19)))
        XCTAssertEqual(HomePrompt.pick(now: d(11, 10, 9), resting: false, events: [], loggedToday: false, journaledToday: false, goal: "스톱", calendar: cal),
                       .morningGoal(goal: "스톱"))
        XCTAssertEqual(HomePrompt.pick(now: d(11, 10, 22), resting: false, events: [], loggedToday: true, journaledToday: false, goal: nil, calendar: cal),
                       .eveningJournal)
        XCTAssertNil(HomePrompt.pick(now: d(11, 10, 15), resting: false, events: [], loggedToday: false, journaledToday: false, goal: nil, calendar: cal))
        XCTAssertEqual(HomePrompt.pick(now: d(11, 10, 22), resting: true, events: [ev], loggedToday: false, journaledToday: false, goal: nil, calendar: cal), .resting)
    }
}

final class ConditionTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    func t(_ day: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))! }
    func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: t(11, 12)))! }

    func testSleepGroupedByWakeDayWithOverlapOnce() {
        // 10일 밤 23시~11일 7시(워치·다른 기기 겹침) + 11일 낮잠 30분
        let segs = [SleepSegment(start: t(10, 23), end: t(11, 3)), SleepSegment(start: t(11, 2), end: t(11, 7)),
                    SleepSegment(start: t(11, 14), end: t(11, 14, 30))]
        let r = ConditionTrack.sleepByWakeDay(segs, calendar: cal)
        XCTAssertEqual(r[cal.startOfDay(for: t(11, 0))], 8 * 60 + 30)
    }

    func testUnusualNeedsBaseline() {
        let few = (0..<5).map { ConditionDay(day: day(-$0), sleepMinutes: 300) }
        XCTAssertTrue(ConditionTrack.unusual(few, now: t(11, 12), calendar: cal).isEmpty)
    }

    func testUnusualSleepHeartAndFatigue() {
        var days: [ConditionDay] = []
        for o in 7...30 { days.append(ConditionDay(day: day(-o), sleepMinutes: 450, restingHR: 55, hrv: 60)) }
        for o in 0...6 { days.append(ConditionDay(day: day(-o), sleepMinutes: o < 3 ? 330 : 450, restingHR: 62, hrv: 40, fatigue: o < 3 ? 5 : nil)) }
        let lines = ConditionTrack.unusual(days, now: t(11, 12), calendar: cal)
        XCTAssertEqual(lines, ["최근 7일 중 평소보다 1시간 넘게 덜 잔 날이 3번이에요.",
                               "안정 심박이 평소보다 7bpm 높아요.",
                               "심박 변이도가 평소보다 33% 낮아요.",
                               "최근 7일 '힘듦'이 높은 편이에요(평균 5.0)."])
    }

    func testMetricText() {
        XCTAssertEqual(ConditionMetric.sleep.text(450), "7시간 30분")
        XCTAssertEqual(ConditionMetric.restingHR.text(54.6), "55bpm")
    }
}

final class RecordModeTests: XCTestCase {
    func testAutoFollowsLevelAndExplicitWins() {
        XCTAssertEqual(RecordMode.resolve(.auto, level: nil), .normal)
        XCTAssertEqual(RecordMode.resolve(.auto, level: .starter), .simple)
        XCTAssertEqual(RecordMode.resolve(.auto, level: .growing), .normal)
        XCTAssertEqual(RecordMode.resolve(.auto, level: .seasoned), .detailed)
        XCTAssertEqual(RecordMode.resolve(.simple, level: .seasoned), .simple)
    }

    func testPresets() {
        let simple = RecordMode.simple.preset, normal = RecordMode.normal.preset, detailed = RecordMode.detailed.preset
        XCTAssertFalse(simple.expandedByDefault); XCTAssertFalse(simple.showsGameStats); XCTAssertFalse(simple.showsSkillDetail)
        XCTAssertFalse(normal.expandedByDefault); XCTAssertTrue(normal.showsGameStats)
        XCTAssertTrue(detailed.expandedByDefault); XCTAssertTrue(detailed.gameDetailsOpen)
        XCTAssertEqual(RecordMode.auto.preset, normal)
        XCTAssertEqual(simple.defaultMinutes(for: .miniGame), 60)
        XCTAssertEqual(normal.defaultMinutes(for: .miniGame), 90)
        XCTAssertEqual(detailed.defaultMinutes(for: .lesson), 60)
    }
}

final class QuestTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 10) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }

    func testWeeklyIsStableDistinctAndMondayBased() {
        let w = Quest.week(containing: d(2026, 11, 12), calendar: cal)
        XCTAssertEqual(cal.component(.weekday, from: w.start), 2)
        XCTAssertEqual(cal.component(.day, from: w.start), 9)
        let a = Quest.weekly(weekStart: w.start, level: nil)
        XCTAssertEqual(a, Quest.weekly(weekStart: w.start, level: nil))
        XCTAssertEqual(Set(a.map(\.kind)).count, 3)
        XCTAssertNotEqual(a.map(\.kind), Quest.weekly(weekStart: w.end, level: nil).map(\.kind))
    }

    func testTargetsByLevel() {
        XCTAssertEqual(Quest.monthlyTarget(level: nil), 4)
        XCTAssertEqual(Quest.monthlyTarget(level: .growing), 6)
        XCTAssertEqual(Quest.monthlyTarget(level: .seasoned), 8)
        var low: [QuestKind: Int] = [:], high: [QuestKind: Int] = [:]
        var w = Quest.week(containing: d(2026, 11, 2), calendar: cal)
        for _ in 0..<5 {
            for q in Quest.weekly(weekStart: w.start, level: .starter) { low[q.kind] = q.target }
            for q in Quest.weekly(weekStart: w.start, level: .seasoned) { high[q.kind] = q.target }
            w = DateInterval(start: w.end, duration: w.duration)
        }
        XCTAssertEqual(low[.minutes], 60); XCTAssertEqual(high[.minutes], 120)
        XCTAssertEqual(low[.sessions], 1); XCTAssertEqual(high[.sessions], 2)
        XCTAssertEqual(low[.conditions], 3); XCTAssertEqual(high[.conditions], 3)
    }

    func testDoneCountsOnlyThisWeek() {
        let week = Quest.week(containing: d(2026, 11, 12), calendar: cal)   // 11/9 ~ 11/15
        let facts = QuestFacts(
            sessions: [.init(date: d(2026, 11, 10), minutes: 60), .init(date: d(2026, 11, 14), minutes: 90), .init(date: d(2026, 11, 16), minutes: 60)],
            drillDates: [d(2026, 11, 11, 9), d(2026, 11, 11, 20)],
            conditionDays: [d(2026, 11, 10, 8), d(2026, 11, 10, 21), d(2026, 11, 12)],
            journalDates: [d(2026, 11, 8)])
        func done(_ k: QuestKind) -> Int { Quest.done(WeeklyQuest(kind: k, target: 1), facts: facts, week: week, calendar: cal) }
        XCTAssertEqual(done(.sessions), 2)
        XCTAssertEqual(done(.minutes), 150)
        XCTAssertEqual(done(.drills), 2)
        XCTAssertEqual(done(.conditions), 2)
        XCTAssertEqual(done(.journals), 0)
    }

    func testMonthDoneAndPoints() {
        let now = d(2026, 11, 12)
        // 11/2 주: 전부 넉넉히 → 그 주 퀘스트 3개 전부 달성. 10/26 주(10월 시작)에도 넉넉히 → 11월 포인트엔 안 들어감.
        var facts = QuestFacts()
        for day in [2, 3, 4] { facts.sessions.append(.init(date: d(2026, 11, day), minutes: 200)); facts.drillDates += [d(2026, 11, day), d(2026, 11, day, 20)]; facts.conditionDays.append(d(2026, 11, day)); facts.journalDates += [d(2026, 11, day), d(2026, 11, day, 21)] }
        for day in [27, 28, 29] { facts.sessions.append(.init(date: d(2026, 10, day), minutes: 200)); facts.drillDates += [d(2026, 10, day), d(2026, 10, day, 20)]; facts.conditionDays.append(d(2026, 10, day)); facts.journalDates += [d(2026, 10, day), d(2026, 10, day, 21)] }
        XCTAssertEqual(Quest.monthDone(facts: facts, month: Quest.month(containing: now, calendar: cal)), 3)
        XCTAssertEqual(Quest.monthPoints(now: now, facts: facts, level: nil, calendar: cal), 3 * Quest.pointsPerQuest)
        XCTAssertEqual(Quest.weeklyProgress(now: now, facts: facts, level: nil, calendar: cal).filter(\.isDone).count, 0)
    }

    func testBadgeKeys() {
        XCTAssertEqual(Quest.badgeKey(month: d(2026, 11, 1), calendar: cal), "badge-2026-11")
        XCTAssertEqual(Quest.badgeTitle("badge-2026-11"), "11월 배지")
        XCTAssertNil(Quest.badgeMonth("first-goal"))
        XCTAssertEqual(StickerCatalog.def("badge-2026-03")?.title, "3월 배지")
    }
}
