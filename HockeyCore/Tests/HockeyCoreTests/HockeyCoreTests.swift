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
        if case .failure(let e) = RunnerInstallation.validate(clash, existing: spans) {
            XCTAssertEqual(e, .runnerAlreadyInstalled(onSkate: skate1))
        } else { XCTFail("충돌이 잡혀야 함") }

        // 부츠1에 B로 교체 → A 구간이 닫히고 B가 열린다
        let result = try RunnerInstallation.swap(onto: skate1, runnerID: runnerB, at: day(5), existing: spans).get()
        XCTAssertEqual(result.closing, [0])
        for i in result.closing { spans[i].to = day(5) }
        spans.append(result.new)
        XCTAssertEqual(spans[0].to, day(5), "A의 장착 기간 보존")
        XCTAssertNil(spans[1].to)

        // 이제 A는 비어 있으니 부츠2에 달 수 있다
        let moveA = try RunnerInstallation.swap(onto: skate2, runnerID: runnerA, at: day(6), existing: spans).get()
        XCTAssertEqual(moveA.closing, [], "부츠2에는 열린 구간이 없고 A도 이미 닫힘")
    }

    func testMovingInstalledRunnerClosesOldSpan() throws {
        let spans = [InstallSpan(runnerID: runnerA, skateID: skate1, from: day(0), to: nil)]
        let result = try RunnerInstallation.swap(onto: skate2, runnerID: runnerA, at: day(2), existing: spans).get()
        XCTAssertEqual(result.closing, [0], "다른 부츠에 달려 있던 같은 러너는 먼저 떼어낸다")
    }

    func testInvalidRange() {
        let bad = InstallSpan(runnerID: runnerA, skateID: skate1, from: day(2), to: day(1))
        if case .failure(let e) = RunnerInstallation.validate(bad, existing: []) {
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
        XCTAssertEqual(change.sentence, "운동 전후 기분을 둘 다 남긴 3번 중 2번은 운동 후 기분이 더 좋게 기록됐어.")
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

    func testMoodClamp() {
        XCTAssertNil(Mood.clamp(0))
        XCTAssertEqual(Mood.clamp(5), 5)
        XCTAssertNil(Mood.clamp(nil))
    }
}
