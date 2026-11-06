# 마하다 (My Ice Hockey Diary)

배우고, 시도하고, 돌아보고, 성장하는 나의 빙판 생활. 수업에서 배운 기술과 경기 적용, 하루 일기, 장비·연마를 한곳에 기록하는 iPhone 앱이다.

기준 문서: 마이 아이스하키 다이어리 UX·서비스 기획서 v1.3 (2026-11-05). 첫 빌드 범위는 **MVP B**까지.

## 들어간 것
| 탭 | 내용 |
|---|---|
| 홈 | 오늘 카드, 빠른 기록(수업·경기·일기), 다음 목표, 최근 피드백, 연마 점검, 설정(⚙︎) |
| 다이어리 | 표정 달력, 날짜별 타임라인(일기·활동·사진), 검색 |
| 성장 | 활동량, 운동 전후 기분, 빙판 유형별, 기술 성장, 수면·컨디션(Apple 건강), 주기와 컨디션(별도 동의), AI 돌아보기(기기 안·opt-in), 시즌 리포트 이미지 |
| 탐색 | 규칙 도감 6종(IIHF 2026/27 대조, 도식·퀴즈), 링크장 찾기(Apple 지도 자동완성·즐겨찾기·내가 확인한 시설 정보) |
| 락커 | 문 열림 연출, 번호판·이름표·색·스티커 꾸미기, 성취 스티커, 스케이트·러너·연마(RoH 단면 카드), 헬멧·유니폼·스틱 등 |
| Apple Watch | 활동 시작·종료, 운동 전후 기분, 하키 운동 세션(시간·심박) → 아이폰 기록으로 전달 |

- 수업 → 경기 → 기술 연결: 경기 기록 때 최근 배운 기술을 추천하고, 기술마다 "못 써봄/써봤어"를 반드시 고른다. 못 써본 건 실패로 세지 않는다.
- 실내 링크 / 야외 링크 / 폰드 / 기타 / 나중에: 활동 종류와 따로 저장한다.
- 기록은 기기 안(SwiftData)에만 저장한다. 서버·iCloud 전송 없음. 링크장 검색어만 Apple 지도로 간다. 일기는 기본 비공개.
- Apple 건강은 연결했을 때만 읽고 앱에 저장하지 않는다. 생리 데이터는 별도 토글을 켤 때만 따로 요청한다.

## 하지 않는 것
- Garmin 직접 API·Connect IQ: Garmin 사업자 프로그램 승인과 서버가 필요하다. 가민 데이터는 Garmin Connect → Apple 건강 동기화로 들어온다.
- 기획서 12.3 제외 항목: AI 경기력 판정, 의료 위험 예측, 생리 주기 운동 처방, 팀 소셜 피드, 자동 플레이 인식.

## 구조
```
HockeyCore/        Foundation만 쓰는 판단 로직 (Linux에서 swift test)
HockeyDiary/       SwiftUI 앱 (Models · Services · Views)
HockeyDiaryTests/  메모리 SwiftData 통합 테스트
HockeyDiaryWatch/  watchOS 앱
project.yml        XcodeGen
```

## 테스트
| 계층 | 위치 | 실행 |
|---|---|---|
| Unit | `HockeyCore/Tests` | `docker run --rm -v "$PWD/HockeyCore":/pkg -w /pkg swift:6.1-jammy swift test` 또는 CI |
| Integration | `HockeyDiaryTests` (실제 SwiftData, 메모리 모드) | CI `build-check` 시뮬레이터 |

## 빌드·배포
맥 없이 GitHub Actions로 빌드하고 TestFlight에 올린다 — [docs/RELEASE_FROM_LINUX.md](docs/RELEASE_FROM_LINUX.md)
