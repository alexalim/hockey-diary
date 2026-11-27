import XCTest

// 테스트 계층: E2E — 실제 앱을 시뮬레이터에서 빈 저장소(-inMemoryStore, 예시 데이터 없음)로 띄우고
// 컴포넌트 하나씩 사용자처럼 구동한다: 적고 → 저장하고 → 다른 화면에서 보이는지 → 지우면 사라지는지.
// 화면을 찍는 ScreenTourTests와 달리 결과를 단언한다. 네트워크·건강 앱처럼 시뮬레이터 밖에 기대는 것은 다루지 않는다.
final class ComponentDriveTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR", "-skipSplash"]
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
        openTeam()
        XCTAssertTrue(app.staticTexts["우리 팀 만들기"].waitForExistence(timeout: 5), "팀 탭에 만들기 화면이 없다")

        openWhatNow()
        XCTAssertNotNil(find("지금 하나", swipes: 0), "뭐할까 첫 묶음 제목이 없다")
        // 빈 저장소: 몸 상태 카드가 먼저, 드릴 카드는 집에서 하는 첫 드릴이어야 한다.
        XCTAssertNotNil(find("오늘 몸 상태 남기기", swipes: 0), "몸 상태 카드가 없다")
        let start = app.buttons["whatnow-drill"].firstMatch
        // 버튼이 하단 바에 걸쳐 있으면 '누를 수 있음'으로 나오지만 누르면 탭이 대신 눌린다. 바 위로 올라올 때까지 내린다.
        func ready() -> Bool { start.exists && start.isHittable && start.frame.maxY <= barTop }
        for _ in 0..<8 where !ready() { nudgeUp() }
        XCTAssertTrue(ready(), "드릴 카드의 지금 시작 버튼이 없다")
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
        // 주간 퀘스트는 주마다 다섯 가지 중 셋이 돌아가며 나온다. 몸 상태 퀘스트가 있는 주에만 진행을 확인한다.
        if find("몸 상태 3일 체크하기") != nil {
            XCTAssertNotNil(find("1/3일"), "몸 상태 퀘스트가 1/3로 오르지 않았다")
        }
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
        snap("gear-sticker-skates")
        back()
        let one = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "스케이트 1켤레")).firstMatch
        XCTAssertTrue(one.waitForExistence(timeout: 5), "락커 안 스케이트 칸이 1켤레로 안 바뀐다")
        sleep(1); snap("locker-open-skate-filled")   // 빈 윤곽 대신 스케이트 그림이 올라와야 한다
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
        openTeam()
        guard let name = formField("팀 이름 (예: 목동 펭귄스)") else { XCTFail("팀 이름 칸이 없다"); return }
        name.tap(); name.typeText("테스트 펭귄스")
        XCTAssertTrue(tapButton("만들기"))
        XCTAssertTrue(tapText("일정 추가"), "일정 추가 버튼이 없다")
        XCTAssertTrue(tapButton("저장"), "일정 저장 버튼이 없다")
        sleep(1)
        // 줄 한가운데(제목 오른쪽 빈 자리)를 누른다. 글자만 눌리던 때는 여기서 화면이 안 열렸다.
        XCTAssertTrue(tapText("정규게임"), "만든 일정이 목록에 없다")
        XCTAssertTrue(app.navigationBars["일정"].waitForExistence(timeout: 5), "일정 화면이 안 열렸다")
        // 열었다 그냥 닫으면 기록이 생기지 않는다(예전엔 누르자마자 빈 기록이 저장됐다).
        XCTAssertTrue(tapText("이 일정으로 기록 만들기"), "기록 만들기 버튼이 없다")
        XCTAssertNotNil(find("팀 일정", swipes: 0), "일정 값으로 채운 쓰기 화면이 안 열렸다")
        XCTAssertTrue(tapButton("닫기")); sleep(1)
        XCTAssertNotNil(find("이 일정으로 기록 만들기"), "쓰지 않고 닫았는데 기록이 생겼다")
        // 이번엔 저장한다 → 일정과 이어진다.
        XCTAssertTrue(tapText("이 일정으로 기록 만들기"))
        XCTAssertTrue(tapButton("저장"), "저장 버튼이 없다")
        XCTAssertTrue(app.staticTexts["저장했어요"].waitForExistence(timeout: 5), "저장 완료 화면이 안 나왔다")
        tapButton("닫기"); sleep(1)
        XCTAssertTrue(tapText("기록 보기"), "저장 뒤 일정에 기록 보기가 없다")
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
        app.buttons["tab-홈"].tap(); sleep(2)
        snap("link-4-team-tab-after-delete")
        XCTAssertNotNil(find("이 일정으로 기록 만들기"), "팀 탭이 일정 화면으로 돌아오지 않았다(빈 화면)")
        snap("link-5-event-button-back")
    }

    // MARK: 팀 여러 개: 두 번째 팀 추가 → 팀마다 자기 일정만 보임 → 팀 지우면 남은 팀으로

    func test_two_teams_switch_and_delete() {
        openTeam()
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
        XCTAssertTrue(app.buttons["닉네임 하키왕, 고치기"].waitForExistence(timeout: 3), "홈 인사말에 닉네임이 없다")

        XCTAssertTrue(tapButton("설정"))
        guard let again = formField("닉네임") else { XCTFail("닉네임 칸이 없다"); return }
        again.tap(); again.typeText(wipe)
        XCTAssertTrue(tapButton("닫기"))
        sleep(1)
        XCTAssertTrue(app.buttons["닉네임 정하기"].waitForExistence(timeout: 3), "닉네임을 지우면 '닉네임 정하기'가 보여야 한다")

        // 홈에서 바로 고치기: 꼬불 밑줄 닉네임을 누르면 입력창이 뜬다.
        app.buttons["닉네임 정하기"].tap()
        let input = app.alerts.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 3), "닉네임을 눌러도 입력창이 안 뜬다")
        input.typeText("빙판요정")
        app.alerts.buttons["저장"].tap()
        XCTAssertTrue(app.buttons["닉네임 빙판요정, 고치기"].waitForExistence(timeout: 3), "홈에서 고친 닉네임이 안 보인다")
        snap("nickname-3-home-edit")
    }

    // MARK: 루틴 템플릿: 가져오면 내 루틴에 생긴다

    func test_routine_template_import() {
        tab("훈련"); branch("드릴")
        XCTAssertTrue(tapText("템플릿에서 가져오기"), "템플릿에서 가져오기 버튼이 없다")
        snap("template-1-routine-picker")
        XCTAssertNotNil(find("블록 3개 · 약", swipes: 0) ?? find("스케이팅", swipes: 0), "템플릿이 블록 모양으로 안 보인다")
        // 템플릿 카드가 길어져 '슈팅 집중'은 아래에 있다. 내려 가며 찾는다.
        guard let imp = find("슈팅 집중 가져오기") else { XCTFail("슈팅 집중 템플릿이 없다"); return }
        snap("template-1b-shooting-card")
        imp.tap()
        sleep(1)
        XCTAssertNotNil(find("슈팅 집중"), "가져온 루틴이 내 루틴에 없다")
        snap("template-2-routine-imported")
    }

    // MARK: 기록 템플릿: 기록에서 저장 → 새 기록에서 골라 채움

    func test_record_template_save_and_apply() {
        XCTAssertTrue(newRecord("수업 기록"))
        // 내용이 하나는 있어야 저장된다.
        guard let memo = formField("오늘의 배움 한 줄") else { XCTFail("오늘의 배움 칸이 없다"); return }
        memo.tap(); memo.typeText("템플릿 테스트")
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

        // 새 기록(정규게임)을 열어 템플릿을 고르면 종류가 수업으로 바뀐다. (+) 버튼은 탭 첫 화면에만 있다.
        tab("홈")
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
        back()
        XCTAssertTrue(tapButton("닫기"), "설정으로 돌아오지 못했다")

        tab("훈련"); branch("드릴")
        XCTAssertNotNil(find("내 루틴"), "내 루틴 제목이 없다")
        XCTAssertFalse(app.buttons["루틴 편집"].exists, "첫 루틴만 여는 '루틴 편집' 버튼이 남아 있다")

        // 스크롤한 홈: 내용이 시계·위쪽 버튼과 겹치지 않는지 캡처로 본다.
        tab("홈")
        for _ in 0..<3 { nudgeUp() }
        snap("ux-2-home-scrolled")
    }

    // MARK: 기록 길이: 빠른 기록은 운동 후 기분만, 상세 기록은 운동 전 기분도 묻는다

    func test_record_quick_and_detailed_switch() {
        snap("redesign-1-home-top")
        // 빠른 기록(처음 값): 아래까지 내려 봐도 운동 전 기분은 없다.
        XCTAssertTrue(newRecord("수업 기록"))
        snap("redesign-2-record-quick")
        XCTAssertNotNil(find("운동 후 기분"), "빠른 기록에 운동 후 기분이 없다")
        XCTAssertNil(find("운동 전 기분", swipes: 0), "빠른 기록인데 운동 전 기분을 묻는다")
        XCTAssertTrue(tapButton("닫기"))
        sleep(1)

        // 상세 기록으로 바꾸면 운동 전 기분도 묻는다. 전환 버튼은 화면 맨 위에 있다.
        XCTAssertTrue(newRecord("수업 기록"))
        branch("상세 기록")
        XCTAssertNotNil(find("운동 전 기분"), "상세 기록으로 바꿔도 운동 전 기분이 안 나온다")
        snap("redesign-3-record-detailed")
        tapButton("닫기")
    }

    // MARK: 뭐할까: 남은 시간을 고르면 그 안에 끝나는 것을 권한다

    func test_whatnow_free_time() {
        openWhatNow()
        XCTAssertNotNil(find("시간이 얼마나 있어요?"), "시간 고르기 카드가 없다")
        XCTAssertTrue(tapButton("시간 5분"), "5분 버튼이 없다")
        sleep(1)
        XCTAssertNotNil(find("5분 안에 끝나요"), "5분을 골라도 추천이 안 바뀐다")
        snap("whatnow-1-five-minutes")
    }

    // MARK: 참석: 답 없는 사람 한꺼번에 채우고 상태별로 본다

    func test_attendance_fill_and_filter() {
        openTeam()
        guard let name = formField("팀 이름 (예: 목동 펭귄스)") else { XCTFail("팀 이름 칸이 없다"); return }
        name.tap(); name.typeText("펭귄스")
        XCTAssertTrue(tapButton("만들기"))
        for who in ["김하키", "박수비"] {
            XCTAssertTrue(tapText("팀원 추가"))
            guard let member = formField("이름 또는 별명") else { XCTFail("팀원 이름 칸이 없다"); return }
            member.tap(); member.typeText(who)
            XCTAssertTrue(tapButton("저장")); sleep(1)
        }
        for _ in 0..<3 { app.swipeDown() }
        XCTAssertTrue(tapText("일정 추가"), "일정 추가 버튼이 없다")
        XCTAssertTrue(tapButton("저장"), "일정 저장 버튼이 없다")
        sleep(1)
        XCTAssertTrue(tapText("정규게임"), "만든 일정이 목록에 없다")
        XCTAssertTrue(app.buttons["보기 답 없음 2"].waitForExistence(timeout: 5), "답 없음 2명이 안 보인다")
        XCTAssertTrue(tapText("답 없는 사람 한꺼번에"), "한꺼번에 메뉴가 없다")
        let all = app.buttons["답 없는 2명 모두 참석"].firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: 3), "모두 참석 항목이 없다"); all.tap(); sleep(1)
        snap("attendance-1-filled")
        XCTAssertTrue(app.buttons["보기 참석 2"].exists, "두 명이 참석으로 안 바뀌었다")
        XCTAssertTrue(tapButton("보기 불참 0"), "불참 보기 버튼이 없다")
        XCTAssertNil(find("김하키", swipes: 0), "불참만 보는데 참석한 사람이 보인다")
    }

    // MARK: 하단 메뉴는 다섯 개: 팀·뭐할까는 메뉴에 없고 홈에서 열린다

    func test_five_tabs_and_home_shortcuts() {
        for name in ["기록", "훈련", "홈", "성장", "락커"] {
            XCTAssertTrue(app.buttons["tab-\(name)"].exists, "하단 메뉴에 \(name)이 없다")
        }
        XCTAssertFalse(app.buttons["tab-팀"].exists, "팀이 하단 메뉴에 남아 있다")
        XCTAssertFalse(app.buttons["tab-뭐할까"].exists, "뭐할까가 하단 메뉴에 남아 있다")
        snap("tabs-1-home")
        openWhatNow()
        XCTAssertNotNil(find("지금 하나", swipes: 0), "홈에서 뭐할까가 안 열린다")
        snap("tabs-2-whatnow")
        openTeam()
        XCTAssertTrue(app.staticTexts["우리 팀 만들기"].waitForExistence(timeout: 5), "홈에서 팀 화면이 안 열린다")
    }

    // MARK: 기록 안 된 가민 운동: 홈 카드 → 기록하기 → 시간이 채워짐 → 저장하면 카드가 사라짐
    // 건강 앱은 시뮬레이터 밖이라 -demoUnloggedWorkout(어제 20:10 가민 하키 80분)으로 대신한다.
    // 판정 규칙 자체는 HockeyCore WorkoutNudgeTests(Unit)가, 여기서는 화면 흐름만 본다.

    func test_unlogged_garmin_workout_card_records_it() {
        relaunch(with: "-demoUnloggedWorkout")
        XCTAssertNotNil(find("하키 운동, 기록할까요?", swipes: 0), "홈 맨 위에 기록 안 된 운동 카드가 없다")
        XCTAssertNotNil(find("어제", swipes: 0), "카드에 언제 한 운동인지가 없다")
        snap("nudge-1-home-card")
        XCTAssertTrue(tapButton("기록하기"), "기록하기 버튼이 없다")
        XCTAssertNotNil(find("운동 시간으로 채웠어요", swipes: 0), "가민 운동으로 채웠다는 안내가 없다")
        XCTAssertNotNil(find("1시간 20분", swipes: 2), "활동 시간이 운동 시간(80분)으로 안 채워졌다")
        snap("nudge-2-editor")
        XCTAssertTrue(tapButton("저장"), "저장 버튼이 없다")
        XCTAssertTrue(app.staticTexts["저장했어요"].waitForExistence(timeout: 5), "저장 완료 화면이 안 나왔다")
        tapButton("닫기")
        sleep(1)
        XCTAssertNil(find("하키 운동, 기록할까요?", swipes: 0), "기록했는데도 카드가 남아 있다")
    }

    // MARK: 홈 카드가 많아도 팀·뭐할까가 스크롤 없이 첫 화면에 보인다(빌드 80: 뭐할까 어디 갔음?)

    func test_whatnow_visible_without_scrolling() {
        // 예시 데이터(-ui-demo)에는 다음 경기·오늘 할 일 카드가 있다. (가짜 가민 운동은 예시 기록과 시간이 겹쳐 카드가 안 뜬다.)
        relaunch(with: "-ui-demo")
        // (다음 경기 카드는 카드 전체가 버튼이라 안쪽 글자로는 못 찾는다. 예시 데이터에 늘 있으니 따로 확인하지 않는다.)
        XCTAssertNotNil(find("뭐할까", swipes: 0), "홈 첫 화면에 뭐할까가 없다")
        XCTAssertNotNil(find("일정·참석·라인업", swipes: 0), "홈 첫 화면에 팀이 없다")
        snap("home-shortcuts-on-top")
    }

    func test_unlogged_workout_skip_hides_card() {
        relaunch(with: "-demoUnloggedWorkout")
        XCTAssertNotNil(find("하키 운동, 기록할까요?", swipes: 0), "카드가 없다")
        XCTAssertTrue(tapButton("아니에요"), "아니에요 버튼이 없다")
        sleep(1)
        XCTAssertNil(find("하키 운동, 기록할까요?", swipes: 0), "넘겼는데 카드가 남아 있다")
    }

    // MARK: 기록 화면 안내의 '설정 열기'를 누르면 설정이 열린다(버그: 눌러도 반응 없음)
    // 안내는 입력 방식이 '보통'이 아닐 때만 나와서 '간단'으로 띄운다.

    func test_editor_open_settings_link() {
        relaunch(with: "-record.mode", "simple")
        XCTAssertTrue(newRecord("수업 기록"))
        XCTAssertTrue(app.navigationBars["수업 기록"].waitForExistence(timeout: 5), "수업 기록 화면이 안 열렸다")
        XCTAssertTrue(tapButton("설정 열기"), "기록 화면에 설정 열기가 없다")
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5), "설정 열기를 눌러도 설정이 안 열린다")
        snap("editor-open-settings")
        // 설정을 닫으면 쓰던 기록 화면으로 돌아온다(예전엔 기록 화면이 닫혀 쓴 게 사라졌다).
        // '간단' 입력에서는 메모 칸에 키보드가 안 붙어 글자로 확인하지 않고, 기록 화면이 남았는지로 본다.
        app.navigationBars["설정"].buttons["닫기"].tap()
        XCTAssertTrue(app.navigationBars["수업 기록"].waitForExistence(timeout: 5), "설정을 다녀오니 기록 화면이 닫혔다")
    }

    // MARK: 저장할 수 없을 때 저장을 누르면 이유가 뜬다(예전엔 회색 버튼이라 눌러도 반응이 없었다)

    func test_save_explains_why_it_cannot_save() {
        XCTAssertTrue(newRecord("수업 기록"))
        XCTAssertTrue(tapButton("저장"), "저장 버튼이 없다")
        let alert = app.alerts["아직 저장할 수 없어요"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "저장할 수 없는 이유가 안 뜬다")
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS '메모를 한 줄'")).firstMatch.exists, "이유 문구가 없다")
        alert.buttons["확인"].tap()
        XCTAssertFalse(app.staticTexts["저장했어요"].exists, "빈 수업 기록이 저장됐다")
    }

    // MARK: 기술 고르기: 검색 창이 처음부터 보이고, 초성으로 찾고, 없는 기술은 검색어로 바로 추가

    func test_skill_picker_search() {
        XCTAssertTrue(newRecord("수업 기록"))
        if app.buttons["상세 기록"].exists { app.buttons["상세 기록"].tap() }
        guard let open = find("오늘 배운 기술 고르기") else { XCTFail("기술 고르기 버튼이 없다"); return }
        open.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5) && field.isHittable, "검색 창이 당기지 않아도 보여야 한다")
        field.tap(); field.typeText("ㅋㄹㅅ")
        XCTAssertNotNil(find("크로스오버", swipes: 0), "초성 ㅋㄹㅅ로 크로스오버가 안 찾아진다")
        XCTAssertFalse(app.buttons["'ㅋㄹㅅ' 새 기술로 추가"].exists, "초성 검색어를 새 기술로 추가하라고 한다")
        snap("skill-search-1-initials")
        field.buttons.firstMatch.tap() // 지우기(x)
        field.typeText("토드래그연습")
        XCTAssertTrue(tapButton("'토드래그연습' 새 기술로 추가"), "없는 기술을 검색어로 추가하는 버튼이 없다")
        XCTAssertNotNil(app.buttons.matching(NSPredicate(format: "label BEGINSWITH '완료 1'")).firstMatch.waitForExistence(timeout: 3) ? true : nil,
                        "추가한 기술이 선택되지 않았다")
        snap("skill-search-2-added")
    }

    // MARK: 기록 탭 전체·하키·일기: 고르면 이날 카드가 눈에 띄게 바뀐다(예전엔 눌러도 같아 보였다)

    func test_diary_filter_changes_day_card() {
        let body = "필터 확인용 일기"
        XCTAssertTrue(newRecord("하루 일기"))
        guard let field = formField("오늘 하루 어땠어요?") else { XCTFail("일기 칸이 없다"); return }
        field.tap(); field.typeText(body)
        XCTAssertTrue(tapButton("저장"))
        sleep(1)
        tab("기록")
        XCTAssertTrue(app.buttons["일기 1"].waitForExistence(timeout: 5), "필터에 이번 달 일기 개수가 없다")
        XCTAssertTrue(tapButton("하키 0"), "하키 필터가 없다")
        XCTAssertNotNil(find("이날은 하키 기록이 없어요", swipes: 3), "하키만 볼 때 안내가 안 바뀐다")
        XCTAssertNil(find(body, swipes: 0), "하키만 볼 때도 일기가 보인다")
        snap("diary-filter-hockey")
        // 안내를 찾느라 내려간 화면을 필터가 보이는 위로 되돌린다.
        let journalChip = app.buttons["일기 1"]
        for _ in 0..<4 where !journalChip.isHittable { app.swipeDown() }
        XCTAssertTrue(journalChip.isHittable, "일기 필터가 화면에 없다")
        journalChip.tap()
        XCTAssertNotNil(find(body, swipes: 3), "일기만 볼 때 일기가 안 보인다")
    }

    // MARK: 드릴 찾기도 초성으로 찾는다(빌드 77 피드백: 'ㅋㄹㅅ'에 맞는 드릴이 없어요)

    func test_drill_search_initials() {
        tab("훈련"); branch("드릴")
        XCTAssertTrue(tapText("드릴 고르기"))
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "드릴 검색 창이 없다")
        field.tap(); field.typeText("ㅋㄹㅅ")
        XCTAssertNotNil(find("서클 크로스오버", swipes: 0), "드릴 찾기에서 초성 ㅋㄹㅅ로 크로스오버 드릴이 안 나온다")
        XCTAssertNil(find("맞는 드릴이 없어요", swipes: 0), "초성 검색에 '없어요'가 뜬다")
        snap("drill-search-initials")
    }

    // MARK: 경기 점수판: 누르면 +1, 길게 누르면 −1, 닫았다 열어도 이어지고, 끝내면 경기 리뷰가 채워진다

    func test_scoreboard_to_game_review() {
        XCTAssertTrue(newRecord("경기 점수판"))
        guard let opp = formField("상대 팀") else { XCTFail("상대 팀 칸이 없다"); return }
        opp.tap(); opp.typeText("베어스")
        XCTAssertTrue(tapButton("경기 시작"), "경기 시작 버튼이 없다")
        // 점수 칸은 버튼 특성이 붙어 있어 종류를 가리지 않고 찾는다.
        let us = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '우리 '")).firstMatch
        let them = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '상대 '")).firstMatch
        XCTAssertTrue(us.waitForExistence(timeout: 5), "우리 점수 칸이 없다")
        XCTAssertTrue(us.isHittable && them.isHittable, "점수 칸을 누를 수 없다")
        us.tap()
        let mine = app.buttons["내가 넣음"]
        XCTAssertTrue(mine.waitForExistence(timeout: 3), "누가 넣었는지 묻지 않는다"); mine.tap()
        us.tap()
        // 묻는 줄이 떠 있어도 상대 칸이 바로 눌려야 한다(예전엔 창을 닫는 데 한 번이 쓰였다).
        them.tap(); them.tap()
        them.press(forDuration: 1.0)   // 잘못 누른 것 되돌리기
        XCTAssertTrue(app.staticTexts["score-us"].label == "2" || us.label.contains("2점"), "우리 점수가 2가 아니다: \(us.label)")
        XCTAssertTrue(them.label.contains("1점"), "길게 눌러도 상대 점수가 안 줄었다: \(them.label)")
        // 두 번째 우리 골은 '다른 사람'으로 답한다. 묻는 줄이 닫히면 내 골 합계가 보인다.
        if app.buttons["다른 사람"].exists { app.buttons["다른 사람"].tap() }
        XCTAssertNotNil(find("내 골 1", swipes: 0), "내 골이 안 세어졌다")
        snap("score-1-board")

        // 닫았다 다시 열어도 이어진다(벤치에서 폰을 잠갔다 켜는 경우).
        tapButton("닫기"); sleep(1)
        XCTAssertTrue(newRecord("경기 점수판 (진행 중)"), "진행 중인 점수판이 메뉴에 없다")
        XCTAssertTrue(us.waitForExistence(timeout: 5) && us.label.contains("2점"), "다시 열었더니 점수가 사라졌다")

        XCTAssertTrue(tapButton("끝내고 기록하기"))
        let confirm = app.buttons["네, 끝내기"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "끝낼지 묻지 않는다"); confirm.tap()
        sleep(1)
        XCTAssertNotNil(find("점수판으로 채웠어요(2 : 1)", swipes: 0), "경기 리뷰에 점수판 값이 안 채워졌다")
        snap("score-2-review")
    }

    // MARK: 가로로 보기: 점수판만 돌려 그린다. 캡처로 화면 전체가 그려지는지 보고, 돌린 화면에서도 누르면 오른다.

    func test_scoreboard_landscape_view() {
        XCTAssertTrue(newRecord("경기 점수판"))
        XCTAssertTrue(tapButton("경기 시작"), "경기 시작 버튼이 없다")
        sleep(1)
        // 기본이 가로: 위 막대 없이 돌린 화면에 '세로로'가 있다.
        XCTAssertTrue(app.buttons["세로로"].waitForExistence(timeout: 3), "시작하자마자 가로로 보이지 않는다")
        let them = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH '상대 '")).firstMatch
        XCTAssertTrue(them.waitForExistence(timeout: 3) && them.isHittable, "가로에서 상대 칸을 누를 수 없다")
        them.tap()
        XCTAssertTrue(them.label.contains("1점"), "가로에서 눌렀는데 상대 점수가 안 올랐다: \(them.label)")
        snap("score-landscape-view")
        XCTAssertTrue(tapButton("세로로"), "세로로 돌아가는 버튼이 없다")
        XCTAssertTrue(app.navigationBars["점수판"].waitForExistence(timeout: 3), "세로로 돌아오지 않았다")
        // 세로에서 다시 가로로: 메뉴가 아니라 위쪽 폰 돌리기 아이콘
        XCTAssertTrue(tapButton("가로로 보기"), "가로로 돌리는 아이콘이 없다")
        snap("score-portrait-rotate-icon")
        XCTAssertTrue(app.buttons["세로로"].waitForExistence(timeout: 3), "다시 가로로 바뀌지 않았다")
    }

    // MARK: 잠금 화면·다이내믹 아일랜드를 누른 것과 같은 주소(mahada://scoreboard)로 점수판이 바로 열린다

    func test_scoreboard_deep_link() {
        tab("기록")   // 다른 화면에 있다가
        app.open(URL(string: "mahada://scoreboard")!)
        XCTAssertTrue(app.navigationBars["점수판"].waitForExistence(timeout: 8), "주소로 열었는데 점수판이 안 뜬다")
        snap("score-deeplink")
    }

    // MARK: AI 돌아보기: 요약 중일 때 움직이는 표시(빌드 90 피드백: 번쩍번쩍 효과)

    func test_ai_thinking_state_is_visible() {
        relaunch(with: "-demoAIThinking")
        tab("성장")
        XCTAssertTrue(tapText("AI로 돌아보기"), "성장에 AI 돌아보기가 없다")
        XCTAssertTrue(app.descendants(matching: .any)["요약하는 중"].waitForExistence(timeout: 5), "요약 중 표시가 없다")
        sleep(1); snap("ai-thinking")
    }

    // MARK: 처음 시작한 사람의 하루(탐색용). 빈 앱으로 첫 화면부터 처음 쓰는 사람처럼 눌러 보고 단계마다 찍는다.
    // 단언은 최소한으로: 막히는 곳을 찾는 게 목적이라, 실패해도 다음 단계로 넘어가 끝까지 찍는다.

    func test_beginner_first_day_walkthrough() {
        snap("B01-first-launch-home")
        XCTAssertNotNil(find("내 하키 실력은 어느 정도예요?", swipes: 0), "처음 온 사람에게 실력 질문이 첫 화면에 없다")
        app.swipeUp(); snap("B02-home-scrolled"); app.swipeDown(); app.swipeDown()

        // 실력 질문: 초급
        if let lv = find("실력 초급") { lv.tap(); sleep(1) }
        snap("B03-level-picked")

        // 첫 수업 기록
        if newRecord("수업 기록") {
            snap("B04-lesson-editor")
            // 기술 고르기는 따로 시험한다(test_skill_picker_search). 여기선 메모만 적고 저장해 하루 흐름을 끝까지 본다.
            // 간단 입력은 화면이 짧아 메모 칸이 맨 아래에 반쯤 걸친다. 올려서 누른다(사람도 그렇게 한다).
            app.swipeUp(); sleep(1)
            if let line = formField("오늘의 배움 한 줄") { line.tap(); sleep(1); line.typeText("처음으로 스톱 연습. 넘어지지 않음!") }
            snap("B07-lesson-filled")
            _ = tapButton("저장"); sleep(2)
            snap("B08-saved")
            _ = tapButton("닫기"); sleep(1)
        }

        // 기록 탭
        tab("기록"); sleep(1); snap("B09-diary")

        // 훈련 → 드릴
        tab("훈련"); sleep(1); snap("B10-training")
        branch("드릴"); sleep(1); snap("B11-drills")
        if tapText("드릴 고르기") {
            sleep(1); snap("B12-drill-picker")
            XCTAssertNotNil(find("처음 추천", swipes: 0), "초급인데 드릴 고르기 맨 위에 '처음 추천'이 없다")
            if let first = app.cells.firstMatch as XCUIElement?, first.exists { first.tap(); sleep(1); snap("B13-drill-run") }
            _ = tapButton("그만"); sleep(1)
            if app.buttons["닫기"].exists { app.buttons["닫기"].tap() }
        }

        // 홈 → 뭐할까
        tab("홈"); sleep(1)
        if let what = find("뭐할까", swipes: 0) { what.tap(); sleep(1); snap("B14-whatnow"); app.swipeUp(); snap("B15-whatnow-bottom"); back() }

        // 성장
        tab("성장"); sleep(1); snap("B16-growth"); app.swipeUp(); snap("B17-growth-bottom")

        // 락커: 문 열고 첫 스케이트
        tab("락커"); sleep(1); snap("B18-locker")
        if tapButton("문 열기") {
            sleep(2); snap("B19-locker-open")
            let zone = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "스케이트")).firstMatch
            if zone.waitForExistence(timeout: 3) {
                zone.tap(); sleep(1); snap("B20-skates-empty")
                if tapButton("스케이트 추가") {
                    sleep(1); snap("B21-skate-editor")
                    if let brand = formField("브랜드 (예: Bauer)") { brand.tap(); brand.typeText("CCM") }
                    _ = tapButton("저장"); sleep(1); snap("B22-skate-saved")
                }
                back()
            }
        }

        // 하키 아카데미: 규칙 처음 읽기
        tab("훈련"); branch("드릴"); sleep(1)
        app.swipeUp(); snap("B23-academy")
        if tapText("규칙·전술") { sleep(1); snap("B24-rules"); if tapText("자주 나오는 반칙") { sleep(1); snap("B25-fouls") } }
    }

    // MARK: 오래 한 사람·여러 곳에서 훈련(탐색용). 고급으로 시작해 링크장을 바꿔 가며 기록하고, 링크장별로 보이는지 본다.

    func test_veteran_multi_rink_walkthrough() {
        snap("V01-first-launch")
        if let lv = find("실력 고급") { lv.tap(); sleep(1) }
        if let name = find("이름 정하기", swipes: 0) {
            name.tap()
            let input = app.alerts.textFields.firstMatch
            if input.waitForExistence(timeout: 3) { input.typeText("베테랑"); app.alerts.buttons["저장"].tap() }
        }
        snap("V02-home-after-setup")

        // 1) A 링크장 수업(고급이라 상세로 열린다)
        if newRecord("수업 기록") {
            snap("V03-lesson-editor-veteran")
            // 상세 기록에선 메모가 '어디서 탔어요?'보다 위에 있다. 메모부터 쓰고 내려간다.
            typeInto("오늘의 배움 한 줄", "크로스오버 바깥 발")
            typeInto("코치 메모", "상체 세우기")
            dismissKeyboard()
            _ = tapText("실내 링크"); sleep(1)
            if let rink = formField("링크장 이름") { rink.tap(); rink.typeText("목동"); sleep(2); snap("V04-rink-suggest-mokdong") }
            // 앱에 든 링크장 목록이 지도 검색(도로 이름)보다 먼저 나와야 한다.
            let mokdong = app.buttons.matching(NSPredicate(format: "label CONTAINS '목동아이스링크'")).firstMatch
            XCTAssertTrue(mokdong.waitForExistence(timeout: 3), "'목동'을 쳤는데 목동아이스링크가 제안되지 않는다")
            if mokdong.exists { mokdong.tap(); sleep(1) }
            dismissKeyboard()
            snap("V05-lesson-filled")
            _ = tapButton("저장"); sleep(2); _ = tapButton("닫기"); sleep(1)
        }

        // 2) B 링크장 경기
        tab("홈")
        if newRecord("정규게임 리뷰") {
            _ = tapText("실내 링크"); sleep(1)
            if let rink = formField("링크장 이름") {
                rink.tap(); sleep(1); snap("V06-rink-field-focused-recent")   // 비워 둔 채 눌렀을 때 최근 링크장이 나오나
                rink.typeText("태릉"); sleep(2); snap("V07-rink-suggest-taereung")
            }
            let taereung = app.buttons.matching(NSPredicate(format: "label CONTAINS '태릉국제스케이트장'")).firstMatch
            if taereung.waitForExistence(timeout: 3) { taereung.tap(); sleep(1) }
            dismissKeyboard()
            snap("V08-game-filled")
            _ = tapButton("저장"); sleep(2)
            if app.alerts.firstMatch.exists { snap("V08b-save-blocked"); app.alerts.buttons.firstMatch.tap() }
            _ = tapButton("닫기"); sleep(1)
        }

        // 3) 세 번째: 자유 연습. 지난 링크장이 미리 채워지나, 바꾸기 쉬운가
        tab("홈")
        if newRecord("자유 연습") {
            snap("V09-free-prefilled-rink")
            app.swipeUp(); snap("V10-free-place-section")
            _ = tapButton("닫기"); sleep(1)
        }

        // 4) 성장: 어디서 탔어요?
        tab("성장"); sleep(1)
        for _ in 0..<3 { app.swipeUp() }
        snap("V11-growth-where")
        for _ in 0..<2 { app.swipeUp() }
        snap("V12-growth-where-more")

        // 5) 기록 검색: 링크장 이름
        tab("기록"); sleep(1)
        app.swipeDown()
        let field = app.searchFields.firstMatch
        if field.waitForExistence(timeout: 3) { field.tap(); sleep(1); if app.keyboards.firstMatch.exists { field.typeText("태릉") }; sleep(1); snap("V13-diary-search-rink") }

        // 6) 링크장 찾기: 내 링크장 목록
        tab("훈련"); sleep(1)
        if tapText("링크장 찾기") { sleep(2); snap("V14-rink-finder"); if tapText("목동아이스링크") { sleep(1); snap("V15-rink-detail") } }
    }

    /// 키보드가 떠 있으면 닫는다(다른 칸을 눌러도 먼저 칸이 키보드를 붙들고 있으면 글자가 안 들어간다).
    private func dismissKeyboard() {
        let kb = app.keyboards.firstMatch
        guard kb.exists else { return }
        let keys = kb.buttons
        if keys.count > 0 { keys.element(boundBy: keys.count - 1).tap() }   // 마지막 키 = 완료(✓)
        sleep(1)
    }

    /// 칸을 찾아 누르고, 키보드가 붙은 걸 확인한 뒤 쓴다.
    private func typeInto(_ placeholder: String, _ text: String) {
        guard let f = formField(placeholder) else { return }
        f.tap()
        if app.keyboards.firstMatch.waitForExistence(timeout: 2) { f.typeText(text) }
    }

    // MARK: 코치·감독: 명단 붙여 넣기 → 매주 반복 일정 → 지난 경기 라인업 가져오기

    func test_coach_roster_repeat_lineup() {
        openTeam()
        guard let name = formField("팀 이름 (예: 목동 펭귄스)") else { XCTFail("팀 이름 칸이 없다"); return }
        name.tap(); name.typeText("코치 팀")
        XCTAssertTrue(tapButton("만들기"))

        // 1) 명단 붙여 넣기(4명, 번호·포지션)
        XCTAssertTrue(tapText("명단 붙여 넣기"), "명단 붙여 넣기 버튼이 없다")
        let box = app.textViews["명단 칸"].exists ? app.textViews["명단 칸"] : app.textFields["명단 칸"]
        XCTAssertTrue(box.waitForExistence(timeout: 3), "명단 칸이 없다")
        box.tap(); box.typeText("9 민수\n17 지훈 D\n30 골리킴 G\n현우")
        snap("coach-1-roster-paste")
        let add = app.buttons["4명 추가"]
        XCTAssertTrue(add.waitForExistence(timeout: 3), "4명을 읽지 못했다")
        add.tap(); sleep(1)
        XCTAssertNotNil(find("골리킴"), "붙여 넣은 명단이 팀에 없다")

        // 2) 매주 4주 반복 일정
        XCTAssertTrue(tapText("일정 추가"), "일정 추가 버튼이 없다")
        let inc = app.steppers.matching(NSPredicate(format: "label CONTAINS '반복'")).firstMatch.buttons.element(boundBy: 1)
        XCTAssertTrue(inc.waitForExistence(timeout: 3), "반복 칸이 없다")
        for _ in 0..<3 { inc.tap() }
        XCTAssertNotNil(find("매주 4주 반복", swipes: 0), "반복 주 수가 안 바뀐다")
        snap("coach-2-repeat")
        XCTAssertTrue(tapButton("저장")); sleep(1)
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS '정규게임'"))
        XCTAssertGreaterThanOrEqual(rows.count, 4, "4주 반복했는데 일정이 \(rows.count)개다")
        snap("coach-3-events")

        // 3) 첫 일정 라인업에 한 명 넣고, 둘째 일정에서 '지난 경기 라인업 가져오기'
        rows.element(boundBy: 0).tap(); sleep(1)
        XCTAssertTrue(tapText("라인업 짜기"), "라인업 짜기 버튼이 없다")
        XCTAssertTrue(tapText("비어 있음"), "라인업 칸이 없다")
        XCTAssertTrue(tapText("민수"), "라인업에 고를 팀원이 없다")
        XCTAssertTrue(tapButton("저장")); sleep(1)
        back(); sleep(1)
        rows.element(boundBy: 1).tap(); sleep(1)
        XCTAssertTrue(tapText("라인업 짜기"))
        XCTAssertTrue(tapText("지난 경기 라인업 가져오기"), "둘째 일정에 지난 라인업 가져오기가 없다")
        // 민수는 포워드 1라인(화면 맨 위)에 들어간다. 버튼은 맨 아래라 위로 올려서 본다.
        for _ in 0..<3 { app.swipeDown() }
        XCTAssertNotNil(find("민수", swipes: 0), "가져온 라인업에 민수가 없다")
        snap("coach-4-lineup-carried")
    }

    // MARK: 시작 화면: 켜자마자 링크장 그림·이름이 보이고, 누르면 바로 홈으로

    func test_splash_then_home() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "-skipSplash" }
        app.launchArguments.append("-holdSplash")
        app.launch()
        let splash = app.descendants(matching: .any)["splash"]
        XCTAssertTrue(splash.waitForExistence(timeout: 5), "시작 화면이 안 보인다")
        sleep(1); snap("splash-1-start")
        // 누르면 바로 홈으로(저절로 넘어가기 전에)
        splash.tap()
        XCTAssertTrue(splash.waitForNonExistence(timeout: 1.5), "시작 화면을 눌러도 안 넘어간다")
        snap("splash-2-home")
        XCTAssertTrue(tapButton("설정"), "시작 화면이 사라진 뒤 홈을 누를 수 없다")
    }

    private func relaunch(with args: String...) {
        app.terminate()
        app.launchArguments += args
        app.launch()
        XCTAssertTrue(app.buttons["tab-홈"].waitForExistence(timeout: 15), "홈 탭이 보여야 한다")
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

    /// 팀과 뭐할까는 하단 메뉴가 아니라 홈의 바로가기로 들어간다. 홈을 첫 화면으로 되돌린 뒤 누른다.
    private func openTeam() {
        tab("홈")
        XCTAssertTrue(tapButton("home-팀"), "홈에 팀 바로가기가 없다"); sleep(1)
    }

    private func openWhatNow() {
        tab("홈")
        XCTAssertTrue(tapButton("home-뭐할까"), "홈에 뭐할까 바로가기가 없다"); sleep(1)
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

    /// 숨은 탭 스택의 제목 줄 버튼이 먼저 잡힐 수 있다. 보이는 제목 줄의 첫 버튼(뒤로)을 누른다.
    private func back() {
        let all = app.navigationBars.buttons
        for i in 0..<min(all.count, 12) {
            let b = all.element(boundBy: i)
            if b.exists && b.isHittable { b.tap(); sleep(1); return }
        }
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
