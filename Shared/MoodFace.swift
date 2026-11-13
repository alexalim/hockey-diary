import SwiftUI

/// 기분 5단계 얼굴. 시스템 이모지 대신 앱이 직접 그린다(앱·위젯·워치 공용이라 색은 여기서 고정).
/// 1 힘들어요 → 5 최고. 파스텔 바탕에 갈색 선, 4·5는 볼터치.
struct MoodFace: View {
    let level: Int
    var size: CGFloat = 32
    /// 접근성 라벨. 없으면 장식으로 숨긴다(호출한 쪽이 글자로 뜻을 적는 경우).
    var label: String? = nil

    private static let fills: [Color] = [
        Color(red: 0.886, green: 0.902, blue: 0.929),   // 0xE2E6ED 흐린 회청
        Color(red: 0.851, green: 0.925, blue: 1.000),   // 0xD9ECFF 하늘
        Color(red: 1.000, green: 0.941, blue: 0.722),   // 0xFFF0B8 노랑
        Color(red: 0.827, green: 0.953, blue: 0.910),   // 0xD3F3E8 민트
        Color(red: 1.000, green: 0.851, blue: 0.910),   // 0xFFD9E8 분홍
    ]
    private static let ink = Color(red: 0.294, green: 0.227, blue: 0.173)        // 0x4B3A2C
    private static let blush = Color(red: 1.000, green: 0.553, blue: 0.706)      // 0xFF8DB4
    private static let drop = Color(red: 0.478, green: 0.655, blue: 1.000)       // 0x7AA7FF

    var body: some View {
        let lv = min(max(level, 1), 5)
        Canvas { ctx, s in
            let w = s.width
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * w) }
            let stroke = StrokeStyle(lineWidth: max(1.2, w * 0.075), lineCap: .round, lineJoin: .round)

            // 얼굴
            let face = Path(ellipseIn: CGRect(x: w * 0.03, y: w * 0.03, width: w * 0.94, height: w * 0.94))
            ctx.fill(face, with: .color(Self.fills[lv - 1]))
            ctx.stroke(face, with: .color(Self.ink.opacity(0.14)), lineWidth: max(0.8, w * 0.03))

            // 볼터치 (좋아요·최고)
            if lv >= 4 {
                for cx in [0.24, 0.76] {
                    ctx.fill(Path(ellipseIn: CGRect(x: w * (cx - 0.09), y: w * 0.56, width: w * 0.18, height: w * 0.11)),
                             with: .color(Self.blush.opacity(lv == 5 ? 0.6 : 0.42)))
                }
            }

            // 눈
            switch lv {
            case 1:
                // >< 눈
                for (ex, dir) in [(0.34, 1.0), (0.66, -1.0)] {
                    var e = Path()
                    e.move(to: p(ex - 0.07 * dir, 0.36)); e.addLine(to: p(ex + 0.04 * dir, 0.43))
                    e.move(to: p(ex - 0.07 * dir, 0.50)); e.addLine(to: p(ex + 0.04 * dir, 0.43))
                    ctx.stroke(e, with: .color(Self.ink), style: stroke)
                }
            case 5:
                // ^ ^ 웃는 눈
                for ex in [0.34, 0.66] {
                    var e = Path()
                    e.addArc(center: p(ex, 0.47), radius: w * 0.085, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                    ctx.stroke(e, with: .color(Self.ink), style: stroke)
                }
            default:
                for ex in [0.35, 0.65] {
                    ctx.fill(Path(ellipseIn: CGRect(x: w * (ex - 0.055), y: w * 0.37, width: w * 0.11, height: w * 0.12)), with: .color(Self.ink))
                }
            }

            // 입
            var m = Path()
            switch lv {
            case 1:
                m.addArc(center: p(0.5, 0.80), radius: w * 0.15, startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
                ctx.stroke(m, with: .color(Self.ink), style: stroke)
                // 땀방울
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.74, y: w * 0.22, width: w * 0.11, height: w * 0.15)), with: .color(Self.drop))
            case 2:
                m.addArc(center: p(0.5, 0.78), radius: w * 0.13, startAngle: .degrees(215), endAngle: .degrees(325), clockwise: false)
                ctx.stroke(m, with: .color(Self.ink), style: stroke)
            case 3:
                m.move(to: p(0.39, 0.67)); m.addLine(to: p(0.61, 0.67))
                ctx.stroke(m, with: .color(Self.ink), style: stroke)
            case 4:
                m.addArc(center: p(0.5, 0.58), radius: w * 0.17, startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
                ctx.stroke(m, with: .color(Self.ink), style: stroke)
            default:
                // 크게 벌린 입 + 혀
                m.addArc(center: p(0.5, 0.60), radius: w * 0.19, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                m.closeSubpath()
                ctx.fill(m, with: .color(Self.ink))
                var t = Path()
                t.addArc(center: p(0.5, 0.70), radius: w * 0.08, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                t.closeSubpath()
                ctx.fill(t, with: .color(Self.blush))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(label == nil)
        .accessibilityLabel(label ?? "")
    }
}
