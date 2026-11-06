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
        XCTAssertEqual(labels, ["3/8", "1/2", "5/8", "3/4", "7/8", "1"])
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
        XCTAssertEqual(change.sentence, "운동 전후 기분을 다 남긴 3번 중 2번은 운동하고 기분이 나아졌어.")
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
        XCTAssertEqual(c.sentence, "최근 6번 기록이야. 7시간 넘게 잔 날(3번)이 덜 잔 날(3번)보다 운동 후 기분이 더 좋았어.")
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
        XCTAssertEqual(RuleGuide.topics.map(\.id), ["offside", "icing", "faceoff", "linechange", "penalties", "positions"])
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
    }
}

final class CycleTests: XCTestCase {
    // F-C04·7.2: 표본이 모자라면 문장 없음, 충분하면 관찰 사실만(처방 없음).
    func testCycleFatigueComparison() {
        XCTAssertNil(CycleFatigueComparison.compute([(true, 4), (false, 2)]).sentence)
        let pairs: [(inPeriod: Bool, fatigue: Int?)] = [(true, 4), (true, 5), (true, 4), (false, 2), (false, 3), (false, 2), (false, nil)]
        let c = CycleFatigueComparison.compute(pairs)
        XCTAssertEqual(c.otherCount, 3)
        XCTAssertEqual(c.sentence, "생리 기간에 탄 날(3번)이 다른 날(3번)보다 피로도가 더 높았어.")
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
