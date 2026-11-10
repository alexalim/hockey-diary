import SwiftUI
import UIKit
import HockeyCore

/// 부록 B 디자인 토큰. 코발트 블루 중심, 네온 핑크는 CTA·선택 강조에만 소량.
enum Theme {
    static let deepNavy = Color(hex: 0x152B4F)
    /// 채움용(흰 글자를 얹는 카드·버튼). 글자색으로 쓰지 않는다.
    static let cobalt = Color(hex: 0x0047AB)
    /// 글자·아이콘·틴트용. 다크 모드에서는 밝은 코발트로 바꿔 대비를 지킨다.
    static let accent = Color(light: 0x0047AB, dark: 0x7AA7FF)
    static let cobaltSoft = Color(light: 0xDCE7FB, dark: 0x1B2D4D)
    static let iceBlue = Color(light: 0xD4EBFA, dark: 0x16303A)
    static let neonPink = Color(hex: 0xFF2D95)

    /// 제목·강조 텍스트. 어두운 화면에서는 밝은 아이스 톤.
    static let title = Color(light: 0x152B4F, dark: 0xE7F0FF)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1F26)
    static let background = Color(light: 0xEDF1F7, dark: 0x0E1117)

    static let corner: CGFloat = 18
    /// 터치 타깃 44pt 이상.
    static let touch: CGFloat = 44

    // MARK: 상태색 — 뜻이 있는 색. 핑크는 ① 주요 버튼 ② 선택됨 ③ 골 표시에만 쓴다.
    /// 참석, 여유 있음, 목표 달성, 복사 완료.
    static let success = Color(light: 0x1B8F5A, dark: 0x4CC38A)
    static let successSoft = Color(light: 0xDDF3E7, dark: 0x173A2B)
    /// 미정, 점검 시기 가까움, 블록.
    static let warning = Color(light: 0xC77700, dark: 0xFFC04D)
    static let warningFill = Color(light: 0xFFB020, dark: 0xFFC04D)
    static let warningSoft = Color(light: 0xFFF1D6, dark: 0x3D2E10)
    /// 불참, 오류, 교체 시기, 지우기.
    static let danger = Color(light: 0xD8343F, dark: 0xFF6B6B)
    static let dangerSoft = Color(light: 0xFCE1E3, dark: 0x3F1C1F)

    // MARK: 링크 그림 — 슛 차트·규칙 그림·전술·링크 도면이 같은 색을 쓴다.
    static let rinkRed = Color(hex: 0xE5484D)
    static let rinkBlue = Color(hex: 0x2F6BFF)
    static let ice = Color(light: 0xF2FAFF, dark: 0x1B2A36)

    /// 심박 구간 5단계: 가볍게 → 전력.
    static let heartZones: [Color] = [Color(light: 0x9FB7D9, dark: 0x5E6F8A), accent, success, warningFill, danger]
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
        case .other, .unknown: return Color.secondary
        }
    }
}

extension ShotOutcome {
    var color: Color {
        switch self {
        case .goal: return Theme.neonPink
        case .saved: return Theme.cobalt
        case .missed: return Color.secondary
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
        case .unknown: return Color.secondary
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
                Text(trailing).font(.caption).foregroundStyle(.secondary)
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
            Text(text).font(.subheadline).foregroundStyle(.secondary)
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

/// 네온 핑크 CTA 버튼.
struct PinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Theme.touch)
            .background(Theme.neonPink.opacity(configuration.isPressed ? 0.75 : 1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}
