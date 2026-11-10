import XCTest

// 테스트 계층: E2E — 실제 앱을 시뮬레이터에서 예시 데이터(메모리 저장소)로 띄워 주요 화면을 차례로 열고
// 스크린샷을 남긴다. 화면이 열리는지 확인하는 것이 목적이고, 지도 검색 결과처럼 네트워크에 기대는 내용은 검증하지 않는다.
final class ScreenTourTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-ui-demo", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["Don’t Allow", "Don't Allow", "허용 안 함", "OK", "확인"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launch()
    }

    func test_tour() {
        XCTAssertTrue(app.tabBars.buttons["홈"].waitForExistence(timeout: 15), "홈 탭이 보여야 한다")
        snap("01-home")
        app.swipeUp(); snap("01b-home-bottom")

        // 수업 기록 편집기
        app.swipeDown()
        if tapText("수업 기록") {
            snap("02-lesson-editor")
            app.swipeUp(); snap("02b-lesson-editor-mid")
            app.swipeUp(); snap("02c-lesson-editor-bottom")
            tapButton("닫기")
        }

        // 미니게임 기록: 슛 차트
        if tapText("경기 리뷰") {
            snap("02d-game-editor")
            if tapText("슛 차트") { snap("02e-shot-chart") }
            tapButton("닫기")
        }
        // 최근 기록에서 미니게임 상세
        tab("홈")
        if tapText("미니게임") { snap("02f-game-detail"); app.swipeUp(); snap("02g-game-detail-bottom"); back() }

        // 다이어리
        tab("다이어리"); snap("03-diary")
        // 성장
        tab("성장"); snap("04-growth")
        app.swipeUp(); snap("04b-growth-mid")
        app.swipeUp(); snap("04c-growth-bottom")

        // 룰: 목록, 반칙 그림, 링크 구조, 전술, 링크장 찾기
        tab("룰"); snap("05-explore")
        if tapText("자주 나오는 반칙") { snap("05b-fouls"); app.swipeUp(); snap("05c-fouls-bottom"); back() }
        for (name, shot) in [("링크 구조", "05d-rink-rule"), ("선수 장비", "05d2-equipment"), ("주요 페널티", "05d3-penalties"),
                             ("경기 시간·연장", "05e-gametime"), ("골 무효", "05f-nogoal"), ("골키퍼가 반칙하면", "05f2-goalie"),
                             ("자주 듣는 말", "05f3-terms")] {
            tab("룰")
            if tapText(name) { snap(shot); back() }
        }
        if tapText("1-2-1 포어체크") { sleep(3); snap("05g-tactic"); back() }
        if tapText("링크장 찾기") { sleep(4); snap("05h-rink-finder"); app.swipeUp(); snap("05i-rink-finder-list"); back() }

        // 락커: 닫힌 문 → 문 열기 → 꾸미기 → 러너 → 연마 기록
        tab("락커"); sleep(2); snap("06-locker-closed")
        if tapButton("문 열기") { sleep(1); snap("06b-locker-open"); tapButton("문 닫기") }
        if tapText("꾸미기") { sleep(1); snap("06c-customize"); tapButton("완료") }
        app.swipeUp()
        tab("락커")
        // 바로 가기에서 못 찾으면 문을 열고 스케이트 → A세트 길로 들어간다.
        var inRunners = tapText("러너(날)")
        if !inRunners, tapButton("문 열기"), tapText("스케이트 1켤레") { snap("06d-skate-detail"); inRunners = true }
        if inRunners {
            snap("07-runners")
            if tapText("A세트") {
                snap("07b-runner-detail")
                app.swipeUp(); snap("07c-runner-detail-bottom")
                if tapText("연마 기록 추가") { sleep(1); snap("07d-sharpening-editor"); app.swipeUp(); snap("07e-sharpening-editor-mid"); tapButton("닫기") }
            }
        }
    }

    // MARK: - 도우미

    /// 화면을 조금만 위로 민다.
    private func nudgeUp() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func tab(_ name: String) {
        let b = app.tabBars.buttons[name]
        if b.waitForExistence(timeout: 5) { b.tap() } else { XCTFail("탭 \(name)이 없다") }
    }

    private func back() {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.exists { b.tap() }
    }

    @discardableResult
    private func tapButton(_ label: String) -> Bool {
        let b = app.buttons[label]
        guard b.waitForExistence(timeout: 3) else { return false }
        b.tap()
        return true
    }

    /// 글자가 들어간 버튼·셀·글을 찾아 누른다. 안 보이면 조금씩 내려서 찾는다(한 번에 많이 내리면 지나친다).
    @discardableResult
    private func tapText(_ text: String) -> Bool {
        let pred = NSPredicate(format: "label CONTAINS %@", text)
        for _ in 0..<10 {
            for q in [app.buttons, app.cells, app.staticTexts] {
                let el = q.matching(pred).firstMatch
                // 탭바에 가려진 아래쪽(화면 85% 아래)은 누르지 않고 더 내린다.
                if el.exists && el.isHittable && el.frame.midY < app.frame.height * 0.85 { el.tap(); return true }
            }
            nudgeUp()
        }
        XCTContext.runActivity(named: "못 찾음: \(text)") { _ in }
        return false
    }
}
