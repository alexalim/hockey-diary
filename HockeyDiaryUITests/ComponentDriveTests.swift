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
        // 줄 한가운데(제목 오른쪽 빈 자리)를 누른다. 글자만 눌리던 때는 여기서 화면이 안 열렸다.
        XCTAssertTrue(tapText("정규게임"), "만든 일정이 목록에 없다")
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

    // MARK: 팀 여러 개: 두 번째 팀 추가 → 팀마다 자기 일정만 보임 → 팀 지우면 남은 팀으로

    func test_two_teams_switch_and_delete() {
        tab("팀")
        guard let name = formField("팀 이름 (예: 목동 펭귄스)") else { XCTFail("팀 이름 칸이 없다"); return }
        name.tap(); name.typeText("펭귄스")
        XCTAssertTrue(tapButton("만들기"))
        XCTAssertTrue(tapText("일정 추가"), "일정 추가 버튼이 없다")
        XCTAssertTrue(tapButton("저장"), "일정 저장 버튼이 없다")
        sleep(1)
        XCTAssertNotNil(find("정규게임", swipes: 0), "첫 팀에 만든 일정이 없다")

        // 두 번째 팀: 만들면 그 팀으로 바뀌고, 첫 팀의 일정은 안 보인다.
        XCTAssertTrue(tapButton("팀 추가"), "팀 추가 버튼이 없다")
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "새 팀 이름 칸이 없다")
        field.typeText("베어스")
        app.alerts.buttons["만들기"].tap(); sleep(1)
        snap("teams-1-second-team")
        XCTAssertTrue(app.buttons["팀 베어스"].isSelected, "새 팀이 골라지지 않았다")
        XCTAssertNil(find("정규게임", swipes: 0), "두 번째 팀에 첫 팀의 일정이 보인다")

        // 첫 팀으로 돌아가면 일정이 다시 보인다.
        XCTAssertTrue(tapButton("팀 펭귄스"), "팀 고르기에 첫 팀이 없다")
        sleep(1)
        snap("teams-2-back-to-first")
        XCTAssertNotNil(find("정규게임", swipes: 0), "첫 팀으로 돌아왔는데 일정이 없다")

        // 첫 팀을 지우면 남은 팀이 보이고, 지운 팀은 고르기에서 사라진다.
        XCTAssertTrue(tapText("이 팀 지우기"), "팀 지우기 버튼이 없다")
        let confirm = app.sheets.buttons["지우기"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "팀 지우기 확인창이 없다"); confirm.tap()
        sleep(2)
        snap("teams-3-after-delete")
        XCTAssertTrue(app.buttons["팀 베어스"].waitForExistence(timeout: 3), "남은 팀이 안 보인다")
        XCTAssertFalse(app.buttons["팀 펭귄스"].exists, "지운 팀이 고르기에 남아 있다")
    }

    // MARK: 설정: 짧은 줄로 보이고, 자세한 안내는 '자세히'를 눌러야 나온다

    func test_settings_short_rows_and_details() {
        XCTAssertTrue(tapButton("설정"), "홈에 설정 버튼이 없다")
        sleep(1)
        snap("settings-1-top")
        XCTAssertNotNil(find("이 아이폰에만 저장"), "보관 안내 첫 줄이 없다")
        snap("settings-2-storage")
        XCTAssertNil(find("링크장 검색어", swipes: 0), "자세한 안내가 처음부터 펼쳐져 있다")
        XCTAssertTrue(tapText("자세히"), "자세히 줄이 없다")
        XCTAssertNotNil(find("링크장 검색어"), "자세히를 눌러도 안내가 안 나온다")
        snap("settings-3-details")
    }

    // MARK: 닉네임: 설정에서 적으면 홈 인사말에 나온다

    func test_nickname_shows_in_home_greeting() {
        // 설정값은 테스트 사이에 남는다. 앞뒤로 칸을 비운다.
        let wipe = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12)
        XCTAssertTrue(tapButton("설정"), "홈에 설정 버튼이 없다")
        guard let field = formField("닉네임") else { XCTFail("닉네임 칸이 없다"); return }
        field.tap(); field.typeText(wipe + "하키왕")
        snap("nickname-1-settings")
        XCTAssertTrue(tapButton("닫기"))
        sleep(1)
        snap("nickname-2-home")
        XCTAssertNotNil(find("하키왕, 오늘도 빙판 위에서.", swipes: 0), "홈 인사말에 닉네임이 없다")

        XCTAssertTrue(tapButton("설정"))
        guard let again = formField("닉네임") else { XCTFail("닉네임 칸이 없다"); return }
        again.tap(); again.typeText(wipe)
        XCTAssertTrue(tapButton("닫기"))
        sleep(1)
        XCTAssertNotNil(find("오늘도, 빙판 위에서.", swipes: 0), "닉네임을 지워도 인사말이 안 돌아온다")
    }

    // MARK: 루틴 템플릿: 가져오면 나의 루틴에 생긴다

    func test_routine_template_import() {
        tab("훈련"); branch("드릴")
        XCTAssertTrue(tapText("템플릿에서 가져오기"), "템플릿에서 가져오기 버튼이 없다")
        snap("template-1-routine-picker")
        XCTAssertTrue(tapButton("슈팅 집중 가져오기"), "슈팅 집중 템플릿이 없다")
        sleep(1)
        XCTAssertNotNil(find("슈팅 집중"), "가져온 루틴이 나의 루틴에 없다")
        snap("template-2-routine-imported")
    }

    // MARK: 기록 템플릿: 기록에서 저장 → 새 기록에서 골라 채움

    func test_record_template_save_and_apply() {
        XCTAssertTrue(newRecord("수업 기록"))
        XCTAssertTrue(tapButton("저장"), "저장 버튼이 없다")
        XCTAssertTrue(app.staticTexts["저장했어요"].waitForExistence(timeout: 5), "저장 완료 화면이 안 나왔다")
        tapButton("닫기")
        tab("기록")
        XCTAssertTrue(tapText("수업"), "수업 기록을 못 눌렀다")
        XCTAssertTrue(tapText("템플릿으로 저장"), "템플릿으로 저장 버튼이 없다")
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "템플릿 이름 칸이 없다")
        field.typeText(" 화요일")
        snap("template-3-record-name")
        app.alerts.buttons["저장"].tap(); sleep(1)

        // 새 기록(정규게임)을 열어 템플릿을 고르면 종류가 수업으로 바뀐다.
        XCTAssertTrue(newRecord("정규게임 리뷰"))
        XCTAssertTrue(tapText("템플릿으로 채우기"), "새 기록에 템플릿 줄이 없다")
        snap("template-4-record-menu")
        let item = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "화요일")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "메뉴에 만든 템플릿이 없다"); item.tap(); sleep(1)
        snap("template-5-record-filled")
        XCTAssertNotNil(find("템플릿으로 채웠어요"), "템플릿으로 채웠다는 안내가 없다")
        XCTAssertTrue(app.navigationBars["수업 기록"].exists, "종류가 템플릿의 수업으로 바뀌지 않았다")
        tapButton("닫기")
    }

    // MARK: 화면 손질: 가민 안내는 단계로, 루틴 줄에만 고치기, 스크롤한 홈 캡처

    func test_ux_health_steps_and_routine_header() {
        XCTAssertTrue(tapButton("설정"), "홈에 설정 버튼이 없다")
        XCTAssertTrue(tapText("Apple 건강"), "설정에 Apple 건강 줄이 없다")
        XCTAssertNotNil(find("Garmin Connect 앱 열기"), "가민 안내가 단계로 안 나온다")
        snap("ux-1-health")
        tapButton("닫기")

        tab("훈련"); branch("드릴")
        XCTAssertNotNil(find("나의 루틴"), "나의 루틴 제목이 없다")
        XCTAssertFalse(app.buttons["루틴 편집"].exists, "첫 루틴만 여는 '루틴 편집' 버튼이 남아 있다")

        // 스크롤한 홈: 내용이 시계·위쪽 버튼과 겹치지 않는지 캡처로 본다.
        tab("홈")
        for _ in 0..<3 { nudgeUp() }
        snap("ux-2-home-scrolled")
    }

    // MARK: 기록 길이: 빠른 기록은 운동 후 기분만, 상세 기록은 운동 전 기분도 묻는다

    func test_record_quick_and_detailed_switch() {
        snap("redesign-1-home-top")
        XCTAssertTrue(newRecord("수업 기록"))
        XCTAssertNotNil(find("운동 후 기분"), "빠른 기록에 운동 후 기분이 없다")
        XCTAssertNil(find("운동 전 기분", swipes: 0), "빠른 기록인데 운동 전 기분을 묻는다")
        for _ in 0..<4 { app.swipeDown() }
        snap("redesign-2-record-quick")
        branch("상세 기록")
        XCTAssertNotNil(find("운동 전 기분"), "상세 기록으로 바꿔도 운동 전 기분이 안 나온다")
        snap("redesign-3-record-detailed")
        tapButton("닫기")
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
