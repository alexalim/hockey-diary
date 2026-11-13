import SwiftUI
import UIKit
import HockeyCore

/// 디자인 토큰 — ICE ATHLETIC(2026-11-11 리디자인 팩). 빙판 같은 차가운 바탕, 코발트의 집중, 핑크는 성취 순간에만.
/// 다크 모드 값은 팩에 없어 같은 느낌으로 맞췄다.
enum Theme {
    static let deepNavy = Color(hex: 0x172B4D)
    /// 채움용(흰 글자를 얹는 카드·버튼). 글자색으로 쓰지 않는다.
    static let cobalt = Color(hex: 0x0047AB)
    static let cobaltPressed = Color(hex: 0x0A3380)
    /// 글자·아이콘·틴트용. 다크 모드에서는 밝은 코발트로 바꿔 대비를 지킨다.
    static let accent = Color(light: 0x0047AB, dark: 0x7AA7FF)
    /// 선택된 칸 배경.
    static let cobaltSoft = Color(light: 0xE8F3FF, dark: 0x1B2D4D)
    static let iceBlue = Color(light: 0xE8F3FF, dark: 0x16303A)
    /// 성취·골·주요 버튼. 흰 바탕의 작은 글자엔 쓰지 않는다(대비 부족) → accentText.
    static let neonPink = Color(hex: 0xFF2D8C)
    /// 핑크 계열 글자용(흰 바탕에서 읽히는 진한 핑크).
    static let accentText = Color(light: 0xC21B68, dark: 0xFF7AB8)
    static let achievementSoft = Color(light: 0xFCE5F1, dark: 0x3A1A2B)

    /// 제목·강조 텍스트(ink.primary). 어두운 화면에서는 밝은 아이스 톤.
    static let title = Color(light: 0x172B4D, dark: 0xE7F0FF)
    /// 보조 글자(ink.secondary)·더 옅은 글자(ink.tertiary).
    static let inkSecondary = Color(light: 0x64748B, dark: 0x9AA8BC)
    static let inkTertiary = Color(light: 0x91A1B5, dark: 0x6E7C91)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1F26)
    static let background = Color(light: 0xF5F8FC, dark: 0x0E1117)
    static let border = Color(light: 0xE4EAF2, dark: 0x2A3140)

    /// 둥글기: 메인 카드 20, 작은 카드 14, 버튼 13, 시트 윗부분 26.
    static let corner: CGFloat = 20
    static let compactCorner: CGFloat = 14
    static let buttonCorner: CGFloat = 13
    /// 화면 좌우 여백 20pt.
    static let screenPadding: CGFloat = 20
    /// 터치 타깃 44pt 이상.
    static let touch: CGFloat = 44

    // MARK: 상태색 — 뜻이 있는 색. 핑크는 ① 주요 버튼 ② 선택됨 ③ 골·성취 표시에만 쓴다.
    /// 참석, 여유 있음, 목표 달성, 복사 완료.
    static let success = Color(light: 0x197A61, dark: 0x4CC38A)
    static let successSoft = Color(light: 0xE5F6EF, dark: 0x173A2B)
    /// 미정, 점검 시기 가까움, 블록.
    static let warning = Color(light: 0x9B6315, dark: 0xFFC04D)
    static let warningFill = Color(light: 0xFFB229, dark: 0xFFC04D)
    static let warningSoft = Color(light: 0xFFF1D9, dark: 0x3D2E10)
    /// 불참, 오류, 교체 시기, 지우기.
    static let danger = Color(light: 0xC92842, dark: 0xFF6B6B)
    static let dangerSoft = Color(light: 0xFCE1E3, dark: 0x3F1C1F)
    /// 슛 차트: 빗나감·블록.
    static let shotMiss = Color(light: 0x8590A2, dark: 0x8A96AA)

    // MARK: 링크 그림 — 슛 차트·규칙 그림·전술·링크 도면이 같은 색을 쓴다.
    static let rinkRed = Color(hex: 0xE5484D)
    static let rinkBlue = Color(hex: 0x2F6BFF)
    static let ice = Color(light: 0xF2FAFF, dark: 0x1B2A36)

    /// 심박 구간 5단계: 가볍게 → 전력.
    static let heartZones: [Color] = [Color(light: 0x9FB7D9, dark: 0x5E6F8A), accent, success, warningFill, danger]

    // MARK: 그라데이션 — 히어로 카드(다음 경기·오늘의 집중·저장 완료·시즌 리포트)는 전부 이 하나를 쓴다.
    static let heroGradient = LinearGradient(colors: [cobalt, deepNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
    /// 성장 막대: 위는 밝은 코발트, 아래는 코발트(컨셉 시안의 막대).
    static let barGradient = LinearGradient(colors: [Color(light: 0x7AA7FF, dark: 0x9BBCFF), cobalt], startPoint: .top, endPoint: .bottom)

    // MARK: 락커 전용 — 문 색(사용자가 고르는 스킨)과 스티커 금색. 토큰 밖 색은 여기에만 둔다.
    static let gold = Color(hex: 0xFFD447)
    static let navyDoor: [Color] = [deepNavy, Color(hex: 0x0A1428)]
    static let pinkDoor: [Color] = [neonPink, Color(hex: 0x9E0F57)]
    static let iceDoor: [Color] = [Color(hex: 0xA9D8F2), Color(hex: 0x5D9CC4)]
    /// 러너(날) 쇠 느낌.
    static let steel: [Color] = [Color(light: 0xB8C4D6, dark: 0x8A97AA), Color(light: 0x6D7B91, dark: 0x5B6779)]

    // MARK: 일기 전용 — 다이어리 속지(크림 종이·마스킹테이프·스티커). 빙판 앱 안의 따뜻한 한 칸이라 일기 화면과 일기 줄에서만 쓴다.
    static let paper = Color(light: 0xFFFBF3, dark: 0x211D18)
    static let paperDot = Color(light: 0xE3D4C1, dark: 0x3D342A)
    static let paperInk = Color(light: 0x4B3A2C, dark: 0xF0E5D3)
    static let paperInkSoft = Color(light: 0x9A8878, dark: 0xA89989)
    static let tapePink = Color(light: 0xFFC9DF, dark: 0x8A4668)
    static let tapeMint = Color(light: 0xC6EFE1, dark: 0x2F6353)
    static let tapeYellow = Color(light: 0xFFE59C, dark: 0x7A6426)
    /// 스티커(태그) 바탕 5색. 순서대로 돌려 붙인다.
    static let stickers: [Color] = [Color(light: 0xFFD9E8, dark: 0x5E2F45), Color(light: 0xFFF0B8, dark: 0x5C4F1F),
                                    Color(light: 0xD3F3E8, dark: 0x234A3E), Color(light: 0xD9ECFF, dark: 0x23405F),
                                    Color(light: 0xE8DDFF, dark: 0x3E3260)]
    /// 기분 5단계 얼굴 바탕(힘듦 → 최고). 나쁜 날도 차갑게 보이지 않게 전부 파스텔.
    static let moodFills: [Color] = [Color(light: 0xE2E6ED, dark: 0x3A4250), Color(light: 0xD9ECFF, dark: 0x23405F),
                                     Color(light: 0xFFF0B8, dark: 0x5C4F1F), Color(light: 0xD3F3E8, dark: 0x234A3E),
                                     Color(light: 0xFFD9E8, dark: 0x5E2F45)]
}

extension ActivityType {
    /// 활동 종류 색. 아이콘 배경, 달력 점, 성장 막대, 팀 일정에 공통.
    var color: Color {
        switch self {
        case .lesson: return Theme.cobalt
        case .miniGame: return Color(light: 0x18A999, dark: 0x2CC4B4)
        case .regularGame: return Color(light: 0x152B4F, dark: 0x4C6A9B)
        case .freePractice: return Color(light: 0x5B8DEF, dark: 0x7AA7FF)
        }
    }
}

extension SurfaceType {
    /// 빙판 유형 색. 선택 카드, 장소 카드, 성장 목록에 공통.
    var color: Color {
        switch self {
        case .indoorRink: return Theme.cobalt
        case .outdoorRink: return Color(light: 0x2E8FD6, dark: 0x5DB4F0)
        case .pond: return Color(light: 0x2BAE8E, dark: 0x4FD1B0)
        case .other, .unknown: return Theme.inkTertiary
        }
    }
}

extension ShotOutcome {
    var color: Color {
        switch self {
        case .goal: return Theme.neonPink
        case .saved: return Theme.cobalt
        case .missed: return Theme.shotMiss
        case .blocked: return Theme.warningFill
        }
    }
}

extension Attendance {
    var color: Color {
        switch self {
        case .going: return Theme.success
        case .maybe: return Theme.warningFill
        case .notGoing: return Theme.danger
        case .unknown: return Theme.inkTertiary
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

/// 카드형 컨테이너.
struct Card<Content: View>: View {
    var tint: Color = Theme.card
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(tint, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

/// 카드 제목 줄.
struct CardHeader: View {
    var title: String
    var systemImage: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Theme.title)
            Spacer()
            if let trailing {
                Text(trailing).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

/// 데이터가 없거나 모자랄 때의 빈 상태.
struct EmptyHint: View {
    var text: String
    var systemImage: String = "snowflake"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(Theme.accent)
            Text(text).font(.subheadline).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 기술 이름 옆 ? 버튼. 누르면 짧은 설명 말풍선. 설명이 없는 기술(사용자가 만든 것)에는 아무것도 그리지 않는다.
struct SkillInfoButton: View {
    var name: String
    var tint: Color = Theme.accent
    @State private var showing = false

    var body: some View {
        if let summary = SkillGuide.summary(for: name) {
            Button {
                showing = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(name) 설명 보기")
            .popover(isPresented: $showing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name).font(.headline).foregroundStyle(Theme.title)
                    Text(summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(width: 280, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

/// 네온 핑크 CTA 버튼(한 화면에 하나).
struct PinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Theme.touch)
            .background(Theme.neonPink.opacity(configuration.isPressed ? 0.75 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.buttonCorner, style: .continuous))
    }
}

/// 코발트 주요 버튼(저장·시작 같은 기본 행동).
struct CobaltButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Theme.touch)
            .background(configuration.isPressed ? Theme.cobaltPressed : Theme.cobalt,
                        in: RoundedRectangle(cornerRadius: Theme.buttonCorner, style: .continuous))
    }
}

/// 탭 루트 화면 머리: 작은 영문 라벨 + 큰 제목(30pt) + 한 줄 부제. 오른쪽엔 행동 버튼 하나.
struct ScreenHeader<Trailing: View>: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    @ViewBuilder var trailing: Trailing

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle; self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow).font(.system(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.inkSecondary)
                Text(title).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.title)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            trailing
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

/// 둥근 작은 행동 버튼(머리 오른쪽).
struct RoundIconButton: View {
    var systemImage: String
    var tint: Color = Theme.title
    var fill: Color = Theme.card
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: fill == Theme.card ? 1 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 빠른 시작 타일(홈·기록).
struct QuickAction: View {
    var title: String
    var systemImage: String
    var tint: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 44, height: 44).background(Theme.cobaltSoft, in: Circle())
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.title)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.compactCorner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.compactCorner, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 섹션 제목 줄(왼쪽 제목, 오른쪽 작은 링크 글자).
struct SectionHeader: View {
    var title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.title)
            Spacer()
            if let trailing {
                if let action {
                    Button(trailing, action: action).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent)
                } else {
                    Text(trailing).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.top, 4)
    }
}

extension View {
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}
