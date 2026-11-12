# 리눅스에서 TestFlight까지 (하키 다이어리)

맥 없이 진행한다. 빌드는 **GitHub Actions의 클라우드 맥(`macos-26`)**, 서명 준비는 리눅스, 확인은 **본인 아이폰의 TestFlight**로 한다. 배포 인증서와 App Store Connect API 키는 `~/.shotsort-signing`에 있는 것을 그대로 쓴다(MOKI·ShotSort와 공용).

```
리눅스                  GitHub Actions (macos-26)           Apple
코드 수정 → push  ──▶  build-check: Core 테스트 + 시뮬레이터 빌드 + 통합 테스트
Secrets 등록      ──▶  release-testflight: 서명·업로드  ──▶  App Store Connect → TestFlight → 아이폰
```

## 1. 컴파일 확인 (Apple 작업 없이)
푸시하면 **Build check**가 돈다. Core 로직은 로컬 Docker로도 돌릴 수 있다.
```bash
cd HockeyCore && docker run --rm -v "$PWD":/pkg -w /pkg swift:6.1-jammy swift test
```

## 2. Bundle ID·프로파일 (완료: 2026-11-06)
- Bundle ID `com.aspynlim.hockeydiary` — App Store Connect API로 등록함
- 프로파일 `HockeyDiary AppStore` (IOS_APP_STORE, 기존 Apple Distribution 인증서) → `~/.shotsort-signing/HockeyDiary_AppStore.mobileprovision`

## 3. App Store Connect 앱 레코드 (브라우저, API로는 못 만듦)
**나의 앱 → + → 신규 앱**: iOS, 이름 `하키 다이어리`(이미 쓰이면 부제를 붙임), 기본 언어 한국어, 번들 ID `com.aspynlim.hockeydiary`, SKU `hockeydiary`.

## 4. GitHub Secrets 등록 (저장소 폴더에서)
```bash
echo y | tools/signing.sh secrets ~/.shotsort-signing/HockeyDiary_AppStore.mobileprovision ~/.shotsort-signing/AuthKey_<키ID>.p8 <Issuer-ID>
```
프로파일에서 팀 ID·이름을 읽어 Secrets 8개를 등록한다.

### 4-1. 워치·위젯 확장 프로파일 (Secrets 2개씩, 모두 12개)
워치 앱(`…hockeydiary.watchkitapp`)과 위젯(`…hockeydiary.widgets`)은 앱과 다른 번들 ID라 각자 App Store 프로파일이 필요하다.
1. developer.apple.com → Identifiers에 번들 ID 등록(기능 켜지 않아도 됨. 위젯 데이터 공유는 앱 그룹 대신 키체인 그룹을 쓰므로 포털 설정이 없다).
2. Profiles → App Store → 그 번들 ID + 같은 배포 인증서로 발급해 내려받는다. ASC API로 해도 된다(bundleIds·profiles POST).
3. 저장소 폴더에서:
```bash
tools/signing.sh extension watch  ~/.shotsort-signing/HockeyDiary_Watch_AppStore.mobileprovision
tools/signing.sh extension widget ~/.shotsort-signing/HockeyDiary_Widgets_AppStore.mobileprovision
```
`WATCH_PROFILE_NAME/BASE64`, `WIDGET_PROFILE_NAME/BASE64`가 들어간다. 프로파일의 application-identifier 끝이 맞지 않으면 스크립트가 거부한다.

앱 프로파일은 HealthKit을 켠 뒤 다시 발급했으므로(이름 "HockeyDiary AppStore 2") 기능을 새로 켤 때마다 `secrets`를 다시 돌린다.

## 5. TestFlight
```bash
gh workflow run release-testflight.yml
```
10~30분 뒤 TestFlight 탭에 빌드가 보이면 내부 테스트 그룹에 본인을 넣어 설치한다.

## 심사 제출 전
- 아이콘은 비니 쓴 퍽(빌드 7~)으로 확정. 바꾸려면 `HockeyDiary/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` 한 장(워치는 HockeyDiaryWatch 쪽 같은 자리)만 교체
- 개인정보처리방침 URL, 앱 개인정보 "데이터를 수집하지 않음"(모든 기록은 기기 안)
- 스크린샷
