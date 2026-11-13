import SwiftUI

// 마하다 아이콘 — 시스템 기호 대신 앱이 직접 그린 선 아이콘(24칸 격자, 둥근 선).
// 앱·위젯·워치가 같이 쓴다. 색은 바깥의 foregroundStyle을 그대로 따른다.
//
// 쓰는 법: `AppIcon("figure.hockey")`처럼 SF Symbols 이름으로 부르면
// 그려 둔 아이콘이 있으면 그것을, 없으면 시스템 기호를 보여 준다.

/// 그리기 명령. 24×24 격자 좌표.
enum IconOp {
    case m(CGFloat, CGFloat)                       // 이동
    case l(CGFloat, CGFloat)                       // 직선
    case q(CGFloat, CGFloat, CGFloat, CGFloat)     // 곡선: 조절점(cx,cy) → 끝(x,y)
    case c(CGFloat, CGFloat, CGFloat)              // 원: 중심(x,y) 반지름 r
    case rr(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) // 둥근 네모: x y w h r
    case z                                          // 닫기
    case f                                          // 이 조각은 선 대신 채움
}

enum MahadaIcon: String, CaseIterable {
    case player, stick, skate, whistle, trophy, net, rink, target, flame, medal, flag, book, team
    case home, calendar, growth, locker, heart, sparkles, star, pencil, moon, body, clock, puck

    /// SF Symbols 이름 → 그려 둔 아이콘.
    static let bySymbol: [String: MahadaIcon] = [
        "figure.hockey": .player, "figure.skating": .player,
        "bolt.fill": .stick, "bolt": .stick,
        "shoeprints.fill": .skate, "wrench.and.screwdriver.fill": .skate,
        "graduationcap.fill": .whistle, "graduationcap": .whistle,
        "trophy.fill": .trophy, "trophy": .trophy,
        "scope": .net,
        "map": .rink, "sportscourt": .rink, "sportscourt.fill": .rink,
        "target": .target,
        "flame.fill": .flame, "flame": .flame,
        "medal.fill": .medal, "rosette": .medal,
        "flag.checkered": .flag,
        "book.fill": .book, "book": .book, "note.text": .book,
        "person.3.fill": .team, "person.3": .team,
        "house.fill": .home, "house": .home,
        "calendar": .calendar, "calendar.badge.clock": .calendar, "calendar.badge.plus": .calendar,
        "chart.bar.xaxis": .growth, "chart.line.uptrend.xyaxis": .growth, "chart.bar.fill": .growth,
        "door.left.hand.closed": .locker,
        "heart.fill": .heart,
        "sparkles": .sparkles,
        "star.fill": .star,
        "pencil": .pencil, "pencil.line": .pencil, "square.and.pencil": .pencil, "pencil.and.list.clipboard": .pencil, "pencil.and.scribble": .pencil,
        "moon.zzz.fill": .moon, "moon.zzz": .moon,
        "figure.stand": .body,
        "clock": .clock, "clock.fill": .clock, "clock.arrow.circlepath": .clock,
        "hockey.puck.fill": .puck, "hockey.puck": .puck,
    ]

    /// 조각 목록. 각 조각은 기본이 선이고, `.f`가 들어 있으면 채운다.
    var ops: [[IconOp]] {
        switch self {
        case .player:
            return [[.c(15.5, 4.5, 2.1)],
                    [.m(13.5, 7.8), .l(9.5, 13.5), .l(5, 19)],
                    [.m(9.5, 13.5), .l(14, 16.5), .l(13, 21)],
                    [.m(12.2, 9.8), .l(17.5, 12.5)],
                    [.m(15.5, 8), .l(20.5, 18), .q(21.5, 21.5, 18.5, 21.5)],
                    [.m(3.5, 20.5), .l(7, 20.5)],
                    [.m(11.5, 22.3), .l(15, 22.3)]]
        case .stick:
            return [[.m(6, 2.5), .l(17, 17.5), .q(18.5, 21, 21.5, 21)],
                    [.m(8.3, 4), .l(10.3, 6.4)],
                    [.m(9.8, 6), .l(11.8, 8.4)]]
        case .skate:
            return [[.m(6, 3), .l(6, 15), .l(19, 15), .q(19, 11, 15, 10), .l(12, 9), .l(10, 3), .z],
                    [.m(4.5, 19.5), .l(20.5, 19.5)],
                    [.m(8.5, 15), .l(8.5, 19.5)],
                    [.m(16.5, 15), .l(16.5, 19.5)],
                    [.m(8, 7), .l(10.5, 7)],
                    [.m(8, 10), .l(11, 10)]]
        case .whistle:
            return [[.c(9.5, 14, 5.5)],
                    [.m(13.5, 9.3), .l(22, 9.3), .l(22, 13.2), .l(15, 13.2)],
                    [.c(9.5, 14, 1.3), .f]]
        case .trophy:
            return [[.m(7, 3), .l(17, 3), .l(16.5, 9), .q(16, 14, 12, 14), .q(8, 14, 7.5, 9), .z],
                    [.m(7, 5), .l(4, 5), .l(4, 8), .q(4, 10.5, 7.5, 10.5)],
                    [.m(17, 5), .l(20, 5), .l(20, 8), .q(20, 10.5, 16.5, 10.5)],
                    [.m(12, 14), .l(12, 18)],
                    [.m(8, 21), .l(16, 21), .l(14.5, 18), .l(9.5, 18), .z]]
        case .net:
            return [[.m(4, 20.5), .l(4, 6), .l(20, 6), .l(20, 20.5)],
                    [.m(4, 11), .l(20, 11)], [.m(4, 16), .l(20, 16)],
                    [.m(9.5, 6), .l(9.5, 20.5)], [.m(14.5, 6), .l(14.5, 20.5)],
                    [.c(12, 20.5, 1.4), .f]]
        case .rink:
            return [[.rr(2.5, 5, 19, 14, 5)],
                    [.m(12, 5), .l(12, 19)],
                    [.c(12, 12, 3)],
                    [.m(6, 8), .l(6, 16)], [.m(18, 8), .l(18, 16)]]
        case .target:
            return [[.c(12, 12, 9)], [.c(12, 12, 5)], [.c(12, 12, 1.6), .f]]
        case .flame:
            return [[.m(12, 2), .q(19, 8.5, 17, 15), .q(16, 20.5, 12, 21.5), .q(8, 20.5, 7, 15), .q(6.5, 11, 9, 8.5), .q(8.5, 12, 11, 13), .q(10, 9, 12, 2), .z, .f]]
        case .medal:
            return [[.m(8, 2.5), .l(12, 9.5), .l(16, 2.5)],
                    [.c(12, 15.5, 5.5)],
                    [.c(12, 15.5, 1.8), .f]]
        case .flag:
            return [[.m(5, 22), .l(5, 3)],
                    [.m(5, 4), .l(19.5, 4), .l(17, 8.5), .l(19.5, 13), .l(5, 13)],
                    [.rr(5.4, 4.4, 3.4, 3.4, 0), .f], [.rr(8.8, 8.6, 3.4, 3.4, 0), .f], [.rr(12.2, 4.4, 3.4, 3.4, 0), .f]]
        case .book:
            return [[.rr(6, 2.5, 13, 19, 2)],
                    [.m(6, 6), .l(3.5, 6)], [.m(6, 10), .l(3.5, 10)], [.m(6, 14), .l(3.5, 14)], [.m(6, 18), .l(3.5, 18)],
                    [.m(10, 8.5), .l(15.5, 8.5)], [.m(10, 12.5), .l(15.5, 12.5)]]
        case .team:
            return [[.c(12, 6.5, 3)], [.c(5.5, 8.5, 2.4)], [.c(18.5, 8.5, 2.4)],
                    [.m(6.5, 20), .q(6.5, 12.5, 12, 12.5), .q(17.5, 12.5, 17.5, 20)],
                    [.m(2, 18.5), .q(2, 13.5, 5.5, 13.5)],
                    [.m(22, 18.5), .q(22, 13.5, 18.5, 13.5)]]
        case .home:
            return [[.m(3.5, 11.5), .l(12, 4), .l(20.5, 11.5)],
                    [.m(6, 10), .l(6, 20.5), .l(18, 20.5), .l(18, 10)],
                    [.m(10, 20.5), .l(10, 15), .l(14, 15), .l(14, 20.5)]]
        case .calendar:
            return [[.rr(3.5, 5, 17, 16, 2.5)],
                    [.m(3.5, 10), .l(20.5, 10)],
                    [.m(8, 3), .l(8, 7)], [.m(16, 3), .l(16, 7)],
                    [.c(8, 14, 1.1), .f], [.c(12, 14, 1.1), .f], [.c(16, 14, 1.1), .f],
                    [.c(8, 17.5, 1.1), .f], [.c(12, 17.5, 1.1), .f]]
        case .growth:
            return [[.m(3, 21), .l(21, 21)],
                    [.rr(5, 13, 3.6, 8, 1)], [.rr(10.2, 8, 3.6, 13, 1)], [.rr(15.4, 3.5, 3.6, 17.5, 1), .f]]
        case .locker:
            return [[.rr(5.5, 2.5, 13, 19, 1.5)],
                    [.m(8.5, 6), .l(16, 6)], [.m(8.5, 9), .l(16, 9)],
                    [.m(15.5, 14), .l(15.5, 17.5)]]
        case .heart:
            return [[.m(12, 20.5), .l(4.2, 13), .q(1.5, 9.5, 4, 6), .q(7.5, 3, 12, 7.5), .q(16.5, 3, 20, 6), .q(22.5, 9.5, 19.8, 13), .z, .f]]
        case .sparkles:
            return [[.m(9, 3), .q(9.8, 9.2, 16, 10), .q(9.8, 10.8, 9, 17), .q(8.2, 10.8, 2, 10), .q(8.2, 9.2, 9, 3), .z, .f],
                    [.m(18, 13), .q(18.4, 16.6, 22, 17), .q(18.4, 17.4, 18, 21), .q(17.6, 17.4, 14, 17), .q(17.6, 16.6, 18, 13), .z, .f]]
        case .star:
            return [[.m(12, 2.5), .l(14.8, 8.6), .l(21.5, 9.4), .l(16.6, 14), .l(17.9, 20.6), .l(12, 17.3), .l(6.1, 20.6), .l(7.4, 14), .l(2.5, 9.4), .l(9.2, 8.6), .z, .f]]
        case .pencil:
            return [[.m(4, 20), .l(4.5, 16), .l(16.5, 4), .l(20, 7.5), .l(8, 19.5), .z],
                    [.m(14, 6.5), .l(17.5, 10)]]
        case .moon:
            return [[.m(15, 3), .q(5, 6, 6, 13.5), .q(7, 20.5, 16.5, 21), .q(10.5, 18.5, 10, 12.5), .q(10, 6, 15, 3), .z, .f]]
        case .body:
            return [[.c(12, 4.5, 2.3)],
                    [.m(12, 7.5), .l(12, 14)],
                    [.m(6.5, 10), .l(17.5, 10)],
                    [.m(12, 14), .l(8.5, 21)], [.m(12, 14), .l(15.5, 21)]]
        case .clock:
            return [[.c(12, 12, 9)], [.m(12, 6.5), .l(12, 12), .l(16, 14.5)]]
        case .puck:
            return [[.m(3, 8.5), .q(12, 4, 21, 8.5), .q(12, 13, 3, 8.5), .z],
                    [.m(3, 8.5), .l(3, 15), .q(12, 19.5, 21, 15), .l(21, 8.5)]]
        }
    }
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
                    case .q(let cx, let cy, let x, let y): path.addQuadCurve(to: CGPoint(x: x * k, y: y * k), control: CGPoint(x: cx * k, y: cy * k))
                    case .c(let x, let y, let r): path.addEllipse(in: CGRect(x: (x - r) * k, y: (y - r) * k, width: 2 * r * k, height: 2 * r * k))
                    case .rr(let x, let y, let w, let h, let r): path.addRoundedRect(in: CGRect(x: x * k, y: y * k, width: w * k, height: h * k), cornerSize: CGSize(width: r * k, height: r * k))
                    case .z: path.closeSubpath()
                    case .f: fill = true
                    }
                }
                if fill {
                    ctx.fill(path, with: .foreground)
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
