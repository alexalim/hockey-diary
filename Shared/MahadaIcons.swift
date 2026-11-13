import SwiftUI

// 마하다 아이콘 — 시스템 기호(SF Symbols) 대신 앱이 직접 그리는 선 아이콘.
// 모양 데이터는 MahadaIconData.swift(자동 생성). 원본은 Tabler Icons와 Phosphor Icons(둘 다 MIT,
// docs/LICENSES.md)이고, 24칸 격자 좌표로 바꿔 Canvas로 그린다. 앱·위젯·워치가 같이 쓴다.
//
// 쓰는 법: `AppIcon("figure.hockey")`처럼 SF Symbols 이름으로 부르면
// 그려 둔 아이콘이 있으면 그것을, 없으면 시스템 기호를 보여 준다.

/// 그리기 명령. 24×24 격자 좌표.
enum IconOp {
    case m(CGFloat, CGFloat)                                           // 이동
    case l(CGFloat, CGFloat)                                           // 직선
    case k(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)       // 3차 곡선: 조절점1, 조절점2, 끝
    case z                                                              // 닫기
    case f                                                              // 이 조각은 선 대신 채움(짝홀)
}

enum MahadaIcon: String, CaseIterable {
    case player, skate, tools, school, trophy, targetArrow, rink, target, flame, medal, flag, notebook, users
    case home, calendar, chartBar, door, heart, sparkles, star, pencil, moon, body, clock, bolt, run, scoreboard
    case blade, helmet, jersey, glove, gift, archive

    /// SF Symbols 이름 → 그려 둔 아이콘.
    static let bySymbol: [String: MahadaIcon] = [
        "figure.hockey": .player, "hockey.puck.fill": .player, "hockey.puck": .player,
        "figure.skating": .skate, "shoeprints.fill": .skate,
        "wrench.and.screwdriver.fill": .tools, "wrench.and.screwdriver": .tools,
        "graduationcap.fill": .school, "graduationcap": .school,
        "trophy.fill": .trophy, "trophy": .trophy,
        "scope": .targetArrow,
        "map": .rink, "sportscourt": .rink, "sportscourt.fill": .rink,
        "target": .target,
        "flame.fill": .flame, "flame": .flame,
        "medal.fill": .medal, "rosette": .medal,
        "flag.checkered": .flag,
        "book.fill": .notebook, "book": .notebook, "note.text": .notebook,
        "person.3.fill": .users, "person.3": .users,
        "house.fill": .home, "house": .home,
        "calendar": .calendar, "calendar.badge.clock": .calendar, "calendar.badge.plus": .calendar,
        "chart.bar.xaxis": .chartBar, "chart.line.uptrend.xyaxis": .chartBar, "chart.bar.fill": .chartBar,
        "door.left.hand.closed": .door,
        "heart.fill": .heart,
        "sparkles": .sparkles,
        "star.fill": .star,
        "pencil": .pencil, "pencil.line": .pencil, "square.and.pencil": .pencil, "pencil.and.list.clipboard": .pencil, "pencil.and.scribble": .pencil,
        "moon.zzz.fill": .moon, "moon.zzz": .moon,
        "figure.stand": .body,
        "clock": .clock, "clock.fill": .clock, "clock.arrow.circlepath": .clock,
        "bolt.fill": .bolt, "bolt": .bolt,
        "figure.run": .run,
        "line.diagonal": .player, "skateblade": .skate,
        "shield.lefthalf.filled": .helmet, "tshirt.fill": .jersey, "hand.raised.fill": .glove,
        "gift.fill": .gift, "archivebox.fill": .archive,
    ]

    /// 조각 목록. 각 조각은 기본이 선이고, `.f`가 들어 있으면 채운다.
    var ops: [[IconOp]] { Self.data[self] ?? [] }
}

/// 아이콘 한 개를 그린다. 크기는 정사각형 한 변.
struct MahadaIconView: View {
    let icon: MahadaIcon
    var size: CGFloat = 24

    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 24
            let lw = max(1.3, 1.9 * k)
            for piece in icon.ops {
                var path = Path()
                var fill = false
                for op in piece {
                    switch op {
                    case .m(let x, let y): path.move(to: CGPoint(x: x * k, y: y * k))
                    case .l(let x, let y): path.addLine(to: CGPoint(x: x * k, y: y * k))
                    case .k(let x1, let y1, let x2, let y2, let x, let y):
                        path.addCurve(to: CGPoint(x: x * k, y: y * k), control1: CGPoint(x: x1 * k, y: y1 * k), control2: CGPoint(x: x2 * k, y: y2 * k))
                    case .z: path.closeSubpath()
                    case .f: fill = true
                    }
                }
                if fill {
                    ctx.fill(path, with: .foreground, style: FillStyle(eoFill: true))
                } else {
                    ctx.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// SF Symbols 이름으로 부르는 아이콘. 그려 둔 게 있으면 그것, 없으면 시스템 기호.
/// 크기를 안 주면 둘러싼 글꼴(.font)에서 어림한다.
struct AppIcon: View {
    let name: String
    var size: CGFloat? = nil
    @Environment(\.font) private var font

    init(_ name: String, size: CGFloat? = nil) {
        self.name = name
        self.size = size
    }

    var body: some View {
        if let icon = MahadaIcon.bySymbol[name] {
            MahadaIconView(icon: icon, size: size ?? Self.guess(font))
        } else {
            Image(systemName: name)
        }
    }

    /// 글꼴 → 아이콘 한 변. 시스템 기호가 글꼴보다 조금 크게 보이는 비율(약 1.15)을 따른다.
    static func guess(_ font: Font?) -> CGFloat {
        guard let font else { return 19.5 }
        let table: [(Font, CGFloat)] = [
            (.largeTitle, 34), (.title, 28), (.title2, 22), (.title3, 20), (.headline, 17), (.body, 17),
            (.callout, 16), (.subheadline, 15), (.footnote, 13), (.caption, 12), (.caption2, 11),
            (.title.bold(), 28), (.title2.bold(), 22), (.title3.bold(), 20), (.headline.bold(), 17),
            (.subheadline.bold(), 15), (.footnote.bold(), 13), (.caption.bold(), 12), (.caption2.bold(), 11),
            (.caption2.weight(.heavy), 11), (.caption.weight(.semibold), 12), (.footnote.weight(.semibold), 13),
        ]
        for (f, pt) in table where f == font { return pt * 1.15 }
        return 19.5
    }
}

extension Label where Title == Text, Icon == AppIcon {
    /// `Label("제목", systemImage:)` 대신. 그려 둔 아이콘이 있으면 그것을 쓴다.
    init(_ title: String, icon: String) {
        self.init { Text(title) } icon: { AppIcon(icon) }
    }
}
