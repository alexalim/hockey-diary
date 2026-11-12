import SwiftUI
import HockeyCore

// 공통 컴포넌트. 화면마다 따로 그리던 모양을 여기로 모은다.

/// 상태 알약. 뜻은 네 가지뿐: 좋음·주의·위험·중립.
struct StatusTag: View {
    enum Kind { case success, warning, danger, neutral }
    var text: String
    var kind: Kind = .neutral
    var systemImage: String? = nil

    private var fg: Color {
        switch kind {
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger: return Theme.danger
        case .neutral: return Theme.title
        }
    }
    private var bg: Color {
        switch kind {
        case .success: return Theme.successSoft
        case .warning: return Theme.warningSoft
        case .danger: return Theme.dangerSoft
        case .neutral: return Theme.cobaltSoft
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .bold)) }
            Text(text).font(.caption2.bold())
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(bg, in: Capsule())
    }
}

/// 숫자 + 라벨 타일.
struct StatTile: View {
    var title: String
    var value: String
    var tint: Color = Theme.title

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title3.bold()).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cobaltSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 아이콘 · 제목 · 값 · 보조 글 한 줄.
struct MetricRow: View {
    var systemImage: String
    var title: String
    var value: String
    var detail: String? = nil
    var tint: Color = Theme.accent

    var body: some View {
        HStack {
            Image(systemName: systemImage).foregroundStyle(tint).frame(width: 24)
            Text(title).font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(value).font(.subheadline.bold())
                if let detail { Text(detail).font(.caption2).foregroundStyle(Theme.inkSecondary) }
            }
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
    }
}

/// 색 점 + 이름 범례.
struct Legend: View {
    struct Item: Identifiable {
        let id = UUID()
        var color: Color
        var title: String
        var systemImage: String? = nil
    }
    var items: [Item]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { it in
                HStack(spacing: 4) {
                    if let s = it.systemImage {
                        Image(systemName: s).font(.caption2.weight(.heavy)).foregroundStyle(it.color)
                    } else {
                        Circle().fill(it.color).frame(width: 9, height: 9)
                    }
                    Text(it.title).font(.caption2).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(items.map(\.title).joined(separator: ", "))
    }
}

/// 진행 막대. 가까워지면 주황, 넘으면 빨강.
struct ProgressTrack: View {
    var value: Double
    var total: Double
    var label: String
    var trailing: String? = nil

    private var ratio: Double { total > 0 ? min(value / total, 1) : 0 }
    private var tint: Color { value >= total ? Theme.danger : (ratio >= 0.8 ? Theme.warningFill : Theme.accent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(Theme.inkSecondary)
                Spacer()
                if let trailing { Text(trailing).font(.caption.bold()).foregroundStyle(tint) }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.inkTertiary.opacity(0.15))
                    Capsule().fill(tint).frame(width: max(ratio > 0 ? 6 : 0, g.size.width * ratio))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(Int((ratio * 100).rounded()))%")
    }
}

/// 상태가 바뀌는 큰 버튼. 켜짐 = 채움, 꺼짐 = 테두리.
struct BigToggle: View {
    var isOn: Bool
    var onTitle: String
    var offTitle: String
    var onImage: String
    var offImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isOn ? onTitle : offTitle, systemImage: isOn ? onImage : offImage)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(isOn ? .white : Theme.accent)
                .background(isOn ? Theme.cobalt : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent, lineWidth: isOn ? 0 : 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// 아래에서 떴다 사라지는 짧은 알림.
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.success, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { self.message = nil } }
                    }
            }
        }
        .animation(.spring(response: 0.35), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View { modifier(ToastModifier(message: message)) }
}
