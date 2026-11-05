# 하키 다이어리 (My Ice Hockey Diary, 가칭)

배우고, 시도하고, 돌아보고, 성장하는 나의 빙판 생활. 수업에서 배운 기술과 경기 적용, 하루 일기, 장비·연마를 한곳에 기록하는 iPhone 앱이다.

기준 문서: 마이 아이스하키 다이어리 UX·서비스 기획서 v1.3 (2026-11-05). 첫 빌드 범위는 **MVP B**까지.

## 들어간 것 (MVP A + B)
| 탭 | 내용 |
|---|---|
| 홈 | 오늘 카드, 빠른 기록(수업·경기·일기), 다음 목표, 최근 피드백, 연마 점검 |
| 다이어리 | 표정 달력, 날짜별 타임라인(일기·활동·사진), 검색 |
| 성장 | 기간 필터, 활동량, 운동 전후 기분 변화, 빙판 유형별, 기술 성장 타임라인 |
| 탐색 | 규칙 도감·링크장 예고 (확장 단계) |
| 락커 | 문 열림 연출, 스케이트 컬렉션, 러너 세트 장착·교체 이력, 연마 기록(RoH 단면 카드) |

- 수업 → 경기 → 기술 연결: 경기 기록 때 최근 배운 기술을 추천하고, 기술마다 "못 써봄/써봤어"를 반드시 고른다. 못 써본 건 실패로 세지 않는다.
- 실내 링크 / 야외 링크 / 폰드 / 기타 / 나중에: 활동 종류와 따로 저장한다.
- 모든 기록은 기기 안(SwiftData)에만 저장한다. 서버·iCloud 전송 없음. 일기는 기본 비공개.

## 아직 없는 것
락커 꾸미기(번호판·스티커), Apple 건강·Apple Watch·Garmin 연동, 규칙 도감 내용, 링크장 찾기, 시즌 리포트, AI 요약.

## 구조
```
HockeyCore/        Foundation만 쓰는 판단 로직 (Linux에서 swift test)
HockeyDiary/       SwiftUI 앱 (Models · Services · Views)
HockeyDiaryTests/  메모리 SwiftData 통합 테스트
project.yml        XcodeGen
```

## 테스트
| 계층 | 위치 | 실행 |
|---|---|---|
| Unit | `HockeyCore/Tests` | `docker run --rm -v "$PWD/HockeyCore":/pkg -w /pkg swift:6.1-jammy swift test` 또는 CI |
| Integration | `HockeyDiaryTests` (실제 SwiftData, 메모리 모드) | CI `build-check` 시뮬레이터 |

## 빌드·배포
맥 없이 GitHub Actions로 빌드하고 TestFlight에 올린다 — [docs/RELEASE_FROM_LINUX.md](docs/RELEASE_FROM_LINUX.md)
