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
        XCTAssertTrue(app.buttons["tab-홈"].waitForExistence(timeout: 15), "홈 탭이 보여야 한다")
        snap("01-home")
        app.swipeUp(); snap("01b-home-bottom")

        // 수업 기록 편집기
        app.swipeDown()
        if tapText("수업 기록") {
            snap("02-lesson-editor")
            if tapText("더 적기") { snap("02b-lesson-editor-mid"); app.swipeUp(); snap("02c-lesson-editor-bottom") }
            tapButton("닫기")
        }

        // 접힌 상태로도 저장되고 완료 화면이 나와야 한다(한 줄만 적고 저장).
        tab("홈")
        if tapText("수업 기록") {
            let line = app.textFields["오늘의 배움 한 줄"].firstMatch
            let lineView = line.exists ? line : app.textViews["오늘의 배움 한 줄"].firstMatch
            if lineView.waitForExistence(timeout: 3) {
                lineView.tap(); lineView.typeText("스톱 왼쪽이 잘 됐어")
                XCTAssertTrue(tapButton("저장"), "저장 버튼이 없다")
                XCTAssertTrue(app.staticTexts["저장했어"].waitForExistence(timeout: 5), "저장 후 완료 화면이 안 나왔다")
                snap("02h-saved")
                tapButton("닫기")
            } else {
                XCTFail("오늘의 배움 칸을 못 찾았다")
                tapButton("닫기")
            }
        }

        // 우리 팀: 일정·참석·라인업
        tab("홈")
        if tapText("목동 펭귄스") {
            snap("01c-team")
            if tapText("강남 베어스") { snap("01d-team-event"); app.swipeUp(); snap("01e-team-event-bottom"); back() }
            back()
        }

        // 미니게임 기록: 슛 차트
        if tapText("경기 리뷰") {
            snap("02d-game-editor")
            if tapText("더 적기"), tapText("슛 차트") { snap("02e-shot-chart") }
            tapButton("닫기")
        }
        // 최근 기록에서 미니게임 상세
        tab("홈")
        if tapText("미니게임") { snap("02f-game-detail"); app.swipeUp(); snap("02g-game-detail-bottom"); back() }

        // 연습: 홈 → (+) 메뉴 대신 성장 탭의 연습 카드로
        tab("성장")
        if tapText("연습하러 가기") {
            snap("04d-practice")
            if tapText("드릴 고르기") { snap("04e-drill-picker"); if tapText("라인 스톱") { sleep(1); snap("04f-drill-run"); tapButton("그만") } else { tapButton("닫기") } }
            back()
        }

        // 성장: 기술 상세(내 최고)
        tab("성장")
        if tapText("하키 스톱") { sleep(1); snap("04g-skill-detail"); app.swipeUp(); snap("04h-skill-detail-bottom"); back() }

        // 홈 꾸미기·설정
        tab("홈")
        if tapText("홈 꾸미기") { sleep(1); snap("01f-home-edit"); tapButton("완료") }
        if tapButton("설정") { sleep(1); app.swipeUp(); snap("01g-settings"); tapButton("닫기") }

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
        // 하단 바 가림 검사: 룰 목록 맨 아래 카드(링크장 찾기)가 끝까지 내렸을 때 바 위에 온전히 보여야 한다.
        tab("룰")
        for _ in 0..<6 { app.swipeUp() }
        sleep(1); snap("05g2-explore-bottom")
        let lastCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "링크장 찾기")).firstMatch
        let barTop = app.buttons["tab-룰"].frame.minY - 20   // 바 위 여백(6) + 홈 원이 솟은 높이(14)
        XCTAssertTrue(lastCard.exists, "룰 맨 아래 카드가 없다")
        XCTAssertLessThanOrEqual(lastCard.frame.maxY, barTop + 1, "맨 아래 카드가 하단 바에 가려짐: 카드 끝 \(lastCard.frame.maxY) > 바 위 \(barTop)")
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
        // 직접 그린 하단 바(식별자 tab-이름). 예전 기본 탭 바도 받아준다.
        let custom = app.buttons["tab-\(name)"]
        if custom.waitForExistence(timeout: 5) { custom.tap(); return }
        let b = app.tabBars.buttons[name]
        if b.waitForExistence(timeout: 3) { b.tap() } else { XCTFail("탭 \(name)이 없다") }
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
        // 하단 바(있으면 그 윗선, 시트 안이면 화면 92%) 아래는 누르지 않는다. 바 뒤를 누르면 바의 탭이 대신 눌린다.
        let bar = app.buttons["tab-홈"]
        let limit = bar.exists && bar.isHittable ? bar.frame.minY - 20 : app.frame.height * 0.92
        for _ in 0..<10 {
            for q in [app.buttons, app.cells, app.staticTexts] {
                let el = q.matching(pred).firstMatch
                if el.exists && el.isHittable && el.frame.midY < limit { el.tap(); return true }
            }
            nudgeUp()
        }
        XCTContext.runActivity(named: "못 찾음: \(text)") { _ in }
        snap("miss-\(text)")   // 왜 못 찾았는지 화면으로 남긴다.
        return false
    }
}
