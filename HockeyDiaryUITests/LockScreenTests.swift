import XCTest

// 테스트 계층: E2E — 드릴 러너를 켜 실시간 활동(Live Activity)을 띄운 뒤 시뮬레이터를 잠가
// 잠금 화면 그대로를 찍는다. 앱 안이 아니라 시스템이 그리는 카드라 앱 스크린샷으로는 못 본다.
// 결과는 아티팩트 "screens"의 L01~L03 그림으로 눈으로 확인한다(단언은 활동이 떠 있는지까지만).
final class LockScreenTests: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["Don’t Allow", "Don't Allow", "허용 안 함", "OK", "확인"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
        app.launch()
        XCTAssertTrue(app.buttons["tab-홈"].waitForExistence(timeout: 15), "홈 탭이 보여야 한다")
    }

    override func tearDown() {
        // 다음 테스트가 잠긴 화면을 만나지 않게 푼다(시뮬레이터는 암호가 없다).
        XCUIDevice.shared.press(.home); sleep(1)
        springboard.swipeUp(); sleep(1)
        app.activate()
    }

    func test_lockScreen_liveActivity() {
        tab("훈련"); branch("드릴")
        XCTAssertTrue(tapText("드릴 고르기"))
        if !tapText("라인 스톱") { shot("L00-no-line-stop"); XCTFail("드릴 목록에 라인 스톱이 없다"); return }
        let plus = app.buttons["+1"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "+1 버튼이 없다")
        plus.tap(); sleep(1)
        shot("L01-runner")

        // 잠금 버튼을 누르면 잠금 화면이 뜬다. 실시간 활동 카드는 몇 초 늦게 그려지므로 보일 때까지 기다렸다 찍는다.
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        let card = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "라인 스톱")).firstMatch
        let shown = card.waitForExistence(timeout: 25)
        sleep(2)
        shot("L02-lock")
        XCTAssertTrue(shown, "잠금 화면에 드릴 실시간 활동이 없다")
        sleep(5)
        shot("L03-lock-5s")
        XCUIDevice.shared.press(.home); sleep(3)
        shot("L04-lock-after-home")

        // 카드 크기와 잠금 화면 요소 전체를 로그에 남겨 카드 밖으로 이어지는 요소가 있는지 본다.
        print("LIVE-ACTIVITY card frame:", card.frame)
        print("LIVE-ACTIVITY springboard tree BEGIN\n", springboard.debugDescription, "\nLIVE-ACTIVITY springboard tree END")
    }

    // MARK: 도우미

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// 하단 바(홈 원 포함) 위쪽 경계. 바에 가려진 요소를 누르면 홈으로 넘어가 버린다.
    private var barTop: CGFloat {
        let bar = app.buttons["tab-홈"]
        return bar.exists && bar.isHittable ? bar.frame.minY - 4 : app.frame.maxY
    }

    private func find(_ text: String, swipes: Int = 8) -> XCUIElement? {
        let pred = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        for i in 0...swipes {
            for q in [app.buttons, app.cells, app.staticTexts] {
                let m = q.matching(pred)
                for j in 0..<min(m.count, 12) {
                    let e = m.element(boundBy: j)
                    if e.exists && e.isHittable && e.frame.maxY <= barTop { return e }
                }
            }
            if i < swipes { nudgeUp() }
        }
        return nil
    }

    @discardableResult
    private func tapText(_ text: String) -> Bool {
        guard let e = find(text) else { return false }
        e.tap(); sleep(1); return true
    }

    private func nudgeUp() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func tab(_ name: String) {
        let b = app.buttons["tab-\(name)"]
        XCTAssertTrue(b.waitForExistence(timeout: 5), "탭 \(name)이 없다")
        b.tap(); usleep(300_000); b.tap(); sleep(1)
    }

    private func branch(_ name: String) {
        let all = app.segmentedControls.buttons.matching(NSPredicate(format: "label == %@", name))
        _ = all.firstMatch.waitForExistence(timeout: 3)
        for i in 0..<min(all.count, 10) {
            let s = all.element(boundBy: i)
            if s.exists && s.isHittable { s.tap(); sleep(1); return }
        }
        XCTFail("훈련 갈래 \(name)이 없다")
    }
}
