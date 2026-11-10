import SwiftUI
import HockeyCore

/// 공격 지역 반쪽 링크(세로). 위가 골대, 아래가 블루라인. 좌표는 0~1.
struct ShotChartCanvas: View {
    var shots: [ShotPoint]
    var editable = false
    var onTap: ((Double, Double) -> Void)? = nil

    private let goalLineY: CGFloat = 0.12
    private let blueLineY: CGFloat = 0.95

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: w * 0.28, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: w * 0.28)
                    .fill(Color(light: 0xF2FAFF, dark: 0x1B2A36))
                UnevenRoundedRectangle(topLeadingRadius: w * 0.28, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: w * 0.28)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                // 골라인·크리스·골대
                Rectangle().fill(Color(hex: 0xE5484D).opacity(0.75)).frame(width: w * 0.86, height: 1.5).position(x: w / 2, y: h * goalLineY)
                Circle().trim(from: 0, to: 0.5).stroke(Color(hex: 0x2F6BFF).opacity(0.6), lineWidth: 1.5)
                    .frame(width: w * 0.22, height: w * 0.22).position(x: w / 2, y: h * goalLineY)
                RoundedRectangle(cornerRadius: 2).stroke(Color(hex: 0xE5484D), lineWidth: 2)
                    .frame(width: w * 0.16, height: h * 0.05).position(x: w / 2, y: h * goalLineY - h * 0.03)
                // 페이스오프 서클 둘
                ForEach([0.22, 0.78], id: \.self) { x in
                    Circle().stroke(Color(hex: 0xE5484D).opacity(0.6), lineWidth: 1.2)
                        .frame(width: w * 0.3, height: w * 0.3).position(x: w * x, y: h * 0.36)
                    Circle().fill(Color(hex: 0xE5484D)).frame(width: 5, height: 5).position(x: w * x, y: h * 0.36)
                }
                // 블루라인
                Rectangle().fill(Color(hex: 0x2F6BFF)).frame(width: w, height: 5).position(x: w / 2, y: h * blueLineY)
                // 슛 표시
                ForEach(Array(shots.enumerated()), id: \.offset) { i, s in
                    mark(s.outcome).position(x: w * s.x, y: h * s.y)
                        .transition(.scale)
                        .accessibilityHidden(true)
                }
                if editable {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { location in
                            guard w > 0, h > 0 else { return }
                            onTap?(Double(location.x / w), Double(location.y / h))
                        }
                }
            }
        }
        .aspectRatio(0.95, contentMode: .fit)
    }

    @ViewBuilder
    private func mark(_ o: ShotOutcome) -> some View {
        switch o {
        case .goal:
            ZStack {
                Circle().fill(Theme.neonPink)
                Image(systemName: "star.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 18, height: 18).overlay(Circle().stroke(.white, lineWidth: 1.5))
        case .saved:
            Circle().fill(Theme.cobalt).frame(width: 14, height: 14).overlay(Circle().stroke(.white, lineWidth: 1.5))
        case .missed:
            Image(systemName: "xmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.secondary)
        case .blocked:
            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.7)).frame(width: 11, height: 11)
        }
    }
}

/// 표시 뜻풀이.
struct ShotLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(Theme.neonPink, "star.fill", "골")
            item(Theme.cobalt, nil, "막힘")
            HStack(spacing: 3) { Image(systemName: "xmark").font(.caption2.weight(.heavy)).foregroundStyle(.secondary); Text("빗나감").font(.caption2).foregroundStyle(.secondary) }
            HStack(spacing: 3) { RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.7)).frame(width: 8, height: 8); Text("블록").font(.caption2).foregroundStyle(.secondary) }
        }
    }

    private func item(_ c: Color, _ symbol: String?, _ t: String) -> some View {
        HStack(spacing: 3) {
            ZStack {
                Circle().fill(c).frame(width: 10, height: 10)
                if let symbol { Image(systemName: symbol).font(.system(size: 5, weight: .bold)).foregroundStyle(.white) }
            }
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

extension ShotOutcome {
    var symbol: String {
        switch self {
        case .goal: return "star.fill"
        case .saved: return "hand.raised.fill"
        case .missed: return "arrow.up.right"
        case .blocked: return "shield.fill"
        }
    }

    static var choices: [ChoiceOption<ShotOutcome>] {
        allCases.map { ChoiceOption(value: $0, title: $0.title, art: .symbol($0.symbol)) }
    }
}

/// 슛 요약 한 줄: "슛 7 · 골 2 · 유효 5"
func shotSummaryText(_ st: ShotStats) -> String {
    "슛 \(st.total) · 골 \(st.goals) · 골대 안 \(st.onTarget)"
}
