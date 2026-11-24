import XCTest

// 테스트 계층: E2E — 실제 앱을 시뮬레이터에서 빈 저장소(-inMemoryStore, 예시 데이터 없음)로 띄우고
// 컴포넌트 하나씩 사용자처럼 구동한다: 적고 → 저장하고 → 다른 화면에서 보이는지 → 지우면 사라지는지.
// 화면을 찍는 ScreenTourTests와 달리 결과를 단언한다. 네트워크·건강 앱처럼 시뮬레이터 밖에 기대는 것은 다루지 않는다.
final class ComponentDriveTests: XCTestCase {
    private var app: XCUIApplication!

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

    // MARK: 수업 기록: 저장 → 기록 탭에 보임 → 상세 → 지우면 사라짐

    func test_lesson_save_show_delete() {
        let memo = "크로스오버 바깥 발 체중"
        XCTAssertTrue(newRecord("수업 기록"))
        guard let field = formField("오늘의 배움 한 줄") else { XCTFail("오늘의 배움 칸이 없다"); return }
        field.tap(); field.typeText(memo)
        XCTAssertTrue(tapButton("저장"), "저장 버튼이 없다")
        XCTAssertTrue(app.staticTexts["저장했어요"].waitForExistence(timeout: 5), "저장 완료 화면이 안 나왔다")
        tapButton("닫기")

        tab("기록")
        XCTAssertNotNil(find("수업"), "기록 탭 오늘 칸에 수업 기록이 없다")
        XCTAssertTrue(tapText("수업"), "수업 기록을 못 눌렀다")
        XCTAssertNotNil(find(memo), "상세에 적은 메모가 없다")
        XCTAssertTrue(tapText("이 기록 지우기"), "지우기 버튼이 없다")
        let confirm = app.sheets.buttons["지우기"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "지우기 확인창이 없다"); confirm.tap()
        sleep(1)
        tab("기록")
        XCTAssertNil(find("수업", swipes: 2), "지운 뒤에도 수업 기록이 남아 있다")
        XCTAssertNotNil(find("이날은 비어 있어요"), "빈 안내가 다시 안 나온다")
    }

    // MARK: 하루 일기: 저장 → 기록 탭에 본문 보임

    func test_journal_save_shows_in_diary() {
        let body = "첫 자유 연습 다녀옴"
        XCTAssertTrue(newRecord("하루 일기"))
        guard let field = formField("오늘 하루 어땠어요?") else { XCTFail("일기 칸이 없다"); return }
        field.tap(); field.typeText(body)
        XCTAssertTrue(tapButton("저장"))
        sleep(1)
        tab("기록")
        XCTAssertNotNil(find(body), "기록 탭에 일기 본문이 없다")
    }

    // MARK: 자유 연습·미니게임·정규게임: 빈 채로도 저장되고 기록 탭에 종류가 남는다

    func test_practice_and_games_save() {
        for label in ["자유 연습", "미니게임 리뷰", "정규게임 리뷰"] {
            tab("홈")
            XCTAssertTrue(newRecord(label), "\(label) 편집기가 안 열렸다")
            XCTAssertTrue(tapButton("저장"), "\(label) 저장 버튼이 없다")
            XCTAssertTrue(app.staticTexts["저장했어요"].waitForExistence(timeout: 5), "\(label) 저장 완료 화면이 안 나왔다")
            tapButton("닫기")
        }
        tab("기록")
        for title in ["자유 연습", "미니게임", "정규게임"] {
            XCTAssertNotNil(find(title), "기록 탭에 \(title)이 없다")
        }
    }

    // MARK: 드릴: 고르기 → 세기 → 끝내고 저장 → 최근 드릴에 남음

    func test_drill_run_is_logged() {
        tab("훈련"); branch("드릴")
        XCTAssertTrue(tapText("드릴 고르기"))
        XCTAssertTrue(tapText("라인 스톱"), "드릴 목록에 라인 스톱이 없다")
        let plus = app.buttons["+1"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "+1 버튼이 없다")
        for _ in 0..<3 { plus.tap() }
        XCTAssertTrue(tapText("끝내고 저장"), "끝내고 저장 버튼이 없다")
        XCTAssertTrue(app.staticTexts["오늘 훈련 끝!"].waitForExistence(timeout: 5), "훈련 끝 화면이 안 나왔다")
        XCTAssertNotNil(find("라인 스톱 3번", swipes: 0), "저장한 드릴 수가 다르다")
        tapButton("닫기")
        tab("훈련"); branch("드릴")
        XCTAssertNotNil(find("라인 스톱"), "최근 드릴에 라인 스톱이 없다")
        XCTAssertNil(find("아직 드릴 기록이 없어요", swipes: 1), "드릴을 저장했는데 빈 안내가 남아 있다")
    }

    // MARK: 팀 탭 → 만들기 화면이 바로 보인다 / 뭐할까 탭 → 드릴 카드의 '지금 시작'이 러너를 띄운다

    func test_team_tab_and_whatNow_drill() {
        tab("팀")
        XCTAssertTrue(app.staticTexts["우리 팀 만들기"].waitForExistence(timeout: 5), "팀 탭에 만들기 화면이 없다")

        tab("뭐할까")
        XCTAssertNotNil(find("지금 하나", swipes: 0), "뭐할까 첫 묶음 제목이 없다")
        // 빈 저장소: 몸 상태 카드가 먼저, 드릴 카드는 집에서 하는 첫 드릴이어야 한다.
        XCTAssertNotNil(find("오늘 몸 상태 남기기", swipes: 0), "몸 상태 카드가 없다")
        let start = app.buttons["whatnow-drill"].firstMatch
        for _ in 0..<4 where !(start.exists && start.isHittable) { nudgeUp() }
        XCTAssertTrue(start.exists && start.isHittable, "드릴 카드의 지금 시작 버튼이 없다")
        start.tap(); sleep(2)
        XCTAssertTrue(app.staticTexts["스틱핸들링 볼 (집)"].waitForExistence(timeout: 5), "드릴 러너가 추천 드릴로 안 열렸다")
        tapButton("그만"); sleep(1)
        if let confirm = [app.sheets.buttons["그만두기"].firstMatch, app.sheets.buttons["그만"].firstMatch].first(where: { $0.exists }) { confirm.tap() }
    }

    // MARK: 오늘 몸 상태: 누르면 선택되고 퀘스트가 1/3로 오른다

    func test_body_check_updates_quest() {
        let three = app.buttons["몸 상태 보통"].firstMatch
        XCTAssertTrue(three.waitForExistence(timeout: 5), "몸 상태 버튼이 없다")
        three.tap(); sleep(1)
        XCTAssertTrue(three.isSelected, "몸 상태가 선택 상태로 안 바뀐다")
        XCTAssertNotNil(find("1/3일"), "몸 상태 퀘스트가 1/3로 오르지 않았다")
    }

    // MARK: 락커: 스케이트 등록 → 목록에 보임 → 락커 칸이 1켤레

    func test_skate_register() {
        tab("락커")
        // 락커 화면에서 끌면 문이 열리는 제스처로 먹힌다. 끌지 않고 문을 열어 안쪽 '스케이트' 칸을 바로 누른다.
        XCTAssertTrue(tapButton("문 열기"), "문 열기 버튼이 없다"); sleep(2)
        let zone = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "스케이트,")).firstMatch
        XCTAssertTrue(zone.waitForExistence(timeout: 5), "락커 안 스케이트 칸이 없다"); zone.tap()
        XCTAssertTrue(app.navigationBars["스케이트"].waitForExistence(timeout: 5), "스케이트 목록이 안 열렸다")
        XCTAssertTrue(tapButton("스케이트 추가"), "스케이트 추가 버튼이 없다")
        guard let brand = formField("브랜드 (예: Bauer)") else { XCTFail("브랜드 칸이 없다"); return }
        brand.tap(); brand.typeText("Bauer")
        if let model = formField("모델명") { model.tap(); model.typeText("Vapor") }
        XCTAssertTrue(tapButton("저장"))
        sleep(1)
        XCTAssertNotNil(find("Bauer"), "스케이트 목록에 등록한 스케이트가 없다")
        back()
        let one = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "스케이트 1켤레")).firstMatch
        XCTAssertTrue(one.waitForExistence(timeout: 5), "락커 안 스케이트 칸이 1켤레로 안 바뀐다")
    }

    // MARK: 팀: 만들기 → 팀원 추가 → 명단에 보임

    func test_team_create_and_member() {
        XCTAssertTrue(tapText("우리 팀"), "홈에 우리 팀 카드가 없다")
        guard let name = formField("팀 이름 (예: 목동 펭귄스)") else { XCTFail("팀 이름 칸이 없다"); return }
        name.tap(); name.typeText("테스트 펭귄스")
        XCTAssertTrue(tapButton("만들기"))
        // 제목은 '팀'으로 고정이고 팀 이름은 화면 안 이름표에 보인다.
        XCTAssertNotNil(find("테스트 펭귄스"), "팀 화면 이름표에 팀 이름이 없다")
        XCTAssertFalse(app.navigationBars["테스트 펭귄스"].exists, "팀 이름이 화면 제목으로 올라가 있다")
        XCTAssertTrue(tapText("팀원 추가"))
        guard let member = formField("이름 또는 별명") else { XCTFail("팀원 이름 칸이 없다"); return }
        member.tap(); member.typeText("김하키")
        XCTAssertTrue(tapButton("저장"))
        sleep(1)
        XCTAssertNotNil(find("김하키"), "명단에 추가한 팀원이 없다")
    }

    // MARK: 팀 일정으로 만든 기록을 기록 탭에서 지움 → 팀 탭이 빈 화면이 아니라 일정으로 돌아옴

    func test_deleting_event_record_elsewhere_does_not_blank_team_tab() {
        tab("팀")
        guard let name = formField("팀 이름 (예: 목동 펭귄스)") else { XCTFail("팀 이름 칸이 없다"); return }
        name.tap(); name.typeText("테스트 펭귄스")
        XCTAssertTrue(tapButton("만들기"))
        XCTAssertTrue(tapText("일정 추가"), "일정 추가 버튼이 없다")
        XCTAssertTrue(tapButton("저장"), "일정 저장 버튼이 없다")
        sleep(1)
        // 줄 한가운데는 빈 자리라 눌리지 않는다. 글자를 누른다.
        let rowTitle = app.staticTexts.matching(NSPredicate(format: "label == %@", "정규게임")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(rowTitle, "만든 일정이 목록에 없다")
        rowTitle?.tap(); sleep(1)
        XCTAssertTrue(app.navigationBars["일정"].waitForExistence(timeout: 5), "일정 화면이 안 열렸다")
        XCTAssertTrue(tapText("이 일정으로 기록 만들기"), "기록 만들기 버튼이 없다")
        snap("link-1-team-record-open")
        XCTAssertNotNil(find("이 기록 지우기"), "팀 탭에 기록 상세가 안 열렸다")

        // 팀 탭에 상세를 열어 둔 채로 기록 탭에서 같은 기록을 지운다.
        tab("기록")
        XCTAssertTrue(tapText("정규게임"), "기록 탭에 일정으로 만든 기록이 없다")
        XCTAssertTrue(tapText("이 기록 지우기"), "지우기 버튼이 없다")
        let confirm = app.sheets.buttons["지우기"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "지우기 확인창이 없다"); snap("link-2-delete-in-record-tab"); confirm.tap()
        sleep(2)
        snap("link-3-record-tab-after-delete")

        // 한 번만 누른다(두 번 누르면 탭이 처음 화면으로 돌아가 버려 증상이 가려진다).
        app.buttons["tab-팀"].tap(); sleep(2)
        snap("link-4-team-tab-after-delete")
        XCTAssertNotNil(find("이 일정으로 기록 만들기"), "팀 탭이 일정 화면으로 돌아오지 않았다(빈 화면)")
        snap("link-5-event-button-back")
    }

    // MARK: - 도우미 (ScreenTourTests와 같은 규칙)

    private func snap(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// 하단 바가 보일 때만 그 윗선 아래를 버린다(바 뒤를 누르면 탭이 대신 눌린다). 시트 안에서는 화면 끝까지 본다.
    private var barTop: CGFloat {
        let bar = app.buttons["tab-홈"]
        return bar.exists && bar.isHittable ? bar.frame.minY - 4 : app.frame.maxY
    }

    /// 글자가 들어간 보이는 요소를 찾는다. 안 보이면 조금씩 내려서 찾는다.
    private func find(_ text: String, swipes: Int = 8) -> XCUIElement? {
        let pred = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        for i in 0...swipes {
            for q in [app.buttons, app.cells, app.staticTexts, app.textFields, app.textViews] {
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

    /// Form 안의 글칸. 화면 밖 칸은 늦게 만들어지므로 보일 때까지 내린다.
    /// 숨은 탭 스택에 같은 칸이 하나 더 있을 수 있어(팀 탭의 팀 이름 칸) firstMatch 대신 보이는 것을 고른다.
    private func formField(_ placeholder: String) -> XCUIElement? {
        for _ in 0..<8 {
            for q in [app.textFields, app.textViews] {
                let all = q.matching(NSPredicate(format: "placeholderValue == %@ OR label == %@ OR identifier == %@", placeholder, placeholder, placeholder))
                for i in 0..<min(all.count, 6) {
                    let f = all.element(boundBy: i)
                    if f.exists && f.isHittable { return f }
                }
            }
            nudgeUp()
        }
        return nil
    }

    private func nudgeUp() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @discardableResult
    private func newRecord(_ label: String) -> Bool {
        guard tapVisible("새 기록") else { return false }
        sleep(1)
        guard tapVisible(label) else { return false }
        sleep(1); return true
    }

    @discardableResult
    private func tapVisible(_ label: String) -> Bool {
        let all = app.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label))
        _ = all.firstMatch.waitForExistence(timeout: 3)
        for i in 0..<min(all.count, 10) {
            let b = all.element(boundBy: i)
            if b.exists && b.isHittable { b.tap(); return true }
        }
        return false
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

    private func back() {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.exists { b.tap(); sleep(1) }
    }

    /// 같은 라벨의 버튼이 숨은 탭 스택에도 있을 수 있다(팀 탭의 '만들기'). 보이는 것을 누른다.
    @discardableResult
    private func tapButton(_ label: String) -> Bool {
        let all = app.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label))
        _ = all.firstMatch.waitForExistence(timeout: 3)
        for i in 0..<min(all.count, 10) {
            let b = all.element(boundBy: i)
            if b.exists && b.isHittable { b.tap(); return true }
        }
        return false
    }
}
