import SwiftUI
import UIKit

/// 부록 B 디자인 토큰. 코발트 블루 중심, 네온 핑크는 CTA·선택 강조에만 소량.
enum Theme {
    static let deepNavy = Color(hex: 0x152B4F)
    static let cobalt = Color(hex: 0x0047AB)
    static let cobaltSoft = Color(light: 0xE7F0FF, dark: 0x1B2D4D)
    static let iceBlue = Color(light: 0xE9F6FB, dark: 0x16303A)
    static let neonPink = Color(hex: 0xFF2D95)

    /// 제목·강조 텍스트. 어두운 화면에서는 밝은 아이스 톤.
    static let title = Color(light: 0x152B4F, dark: 0xE7F0FF)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1F26)
    static let background = Color(light: 0xF4F7FC, dark: 0x0E1117)

    static let corner: CGFloat = 18
    /// 터치 타깃 44pt 이상.
    static let touch: CGFloat = 44
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
            Image(systemName: systemImage).foregroundStyle(Theme.cobalt)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
