import SwiftUI
import HockeyCore

// 규칙 도감 그림. 모두 앱 안에서 직접 그린다(외부 이미지 없음).
// compact는 목록 썸네일용: 글자를 줄이고 핵심 모양만 남긴다.

private let iceFill = Theme.ice
private let redLine = Theme.rinkRed
private let blueLine = Theme.rinkBlue

/// 주제별 그림을 고른다.
struct RuleArt: View {
    let id: String
    var compact = false

    var body: some View {
        switch id {
        case "offside", "icing", "faceoff", "linechange":
            if let s = RuleScene.scenes[id]?.first { RinkSketch(scene: s, progress: 1) } else { EmptyView() }
        case "fouls":
            if let s = FoulSketch.named("트리핑") { FoulSketchView(sketch: s) } else { EmptyView() }
        case "positions": PositionsMini()
        case "rink": RinkLayoutArt(compact: compact)
        case "equipment": EquipmentArt(compact: compact)
        case "penalties": PenaltyBarsArt(compact: compact)
        case "gametime": GameClockArt(compact: compact)
        case "nogoal": NoGoalArt(compact: compact)
        case "goalie": GoalieArt(compact: compact)
        case "terms": PowerPlayArt(compact: compact)
        default: EmptyView()
        }
    }

    /// 상세 화면에 따로 그림을 넣어야 하는 주제(장면·반칙·포지션은 이미 자기 그림이 있다).
    static func needsDetailArt(_ id: String) -> Bool {
        ["rink", "equipment", "penalties", "gametime", "nogoal", "goalie", "terms"].contains(id)
    }

    static func detailHeight(_ id: String) -> CGFloat {
        switch id {
        case "equipment": return 300
        case "nogoal": return 240
        case "penalties", "gametime": return 200
        default: return 180
        }
    }
}

// MARK: - 링크 구조

struct RinkLayoutArt: View {
    var compact = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let rinkH = compact ? h : h * 0.78
            let top = compact ? 0 : h * 0.04
            ZStack(alignment: .topLeading) {
                ZStack {
                    RoundedRectangle(cornerRadius: rinkH * 0.28).fill(iceFill)
                    RoundedRectangle(cornerRadius: rinkH * 0.28).stroke(Theme.inkTertiary.opacity(0.5), lineWidth: 1.5)
                    // 골라인(양 끝 4m = 60m의 약 6.7%)
                    ForEach([0.067, 0.933], id: \.self) { x in
                        Rectangle().fill(redLine.opacity(0.7)).frame(width: 1.5, height: rinkH * 0.86).position(x: x * w, y: rinkH / 2)
                    }
                    ForEach([0.36, 0.64], id: \.self) { x in
                        Rectangle().fill(blueLine).frame(width: compact ? 3 : 5, height: rinkH).position(x: x * w, y: rinkH / 2)
                    }
                    Rectangle().fill(redLine).frame(width: compact ? 3 : 5, height: rinkH).position(x: w / 2, y: rinkH / 2)
                    // 페이스오프 점 9개: 가운데 1, 중립 지역 4, 양 끝 지역 2씩
                    let spots: [CGPoint] = [
                        CGPoint(x: 0.5, y: 0.5),
                        CGPoint(x: 0.4, y: 0.27), CGPoint(x: 0.4, y: 0.73), CGPoint(x: 0.6, y: 0.27), CGPoint(x: 0.6, y: 0.73),
                        CGPoint(x: 0.17, y: 0.3), CGPoint(x: 0.17, y: 0.7), CGPoint(x: 0.83, y: 0.3), CGPoint(x: 0.83, y: 0.7),
                    ]
                    ForEach(Array(spots.enumerated()), id: \.offset) { i, s in
                        if i == 0 || i >= 5 {
                            Circle().stroke(i == 0 ? blueLine : redLine, lineWidth: 1).frame(width: rinkH * 0.3, height: rinkH * 0.3)
                                .position(x: s.x * w, y: s.y * rinkH)
                        }
                        Circle().fill(i == 0 ? blueLine : redLine).frame(width: compact ? 4 : 7, height: compact ? 4 : 7)
                            .position(x: s.x * w, y: s.y * rinkH)
                    }
                    ForEach([0.035, 0.965], id: \.self) { x in
                        RoundedRectangle(cornerRadius: 2).stroke(Theme.inkTertiary, lineWidth: 1.5)
                            .frame(width: w * 0.022, height: rinkH * 0.14).position(x: x * w, y: rinkH / 2)
                    }
                    if !compact {
                        zoneLabel("수비 지역", x: 0.2 * w, y: rinkH * 0.9)
                        zoneLabel("중립 지역", x: 0.5 * w, y: rinkH * 0.9)
                        zoneLabel("공격 지역", x: 0.8 * w, y: rinkH * 0.9)
                    }
                }
                .frame(width: w, height: rinkH)
                .offset(y: top)
                if !compact {
                    HStack {
                        Text("골라인 4m").font(.caption2).foregroundStyle(redLine)
                        Spacer()
                        Text("길이 60m · 폭 26~30m").font(.caption2.bold()).foregroundStyle(Theme.title)
                        Spacer()
                        Text("블루라인").font(.caption2).foregroundStyle(blueLine)
                    }
                    .offset(y: top + rinkH + 6)
                }
            }
        }
    }

    private func zoneLabel(_ t: String, x: CGFloat, y: CGFloat) -> some View {
        Text(t).font(.caption2.bold()).foregroundStyle(Theme.title)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(.background.opacity(0.85), in: Capsule())
            .position(x: x, y: y)
    }
}

// MARK: - 선수 장비

struct EquipmentArt: View {
    var compact = false
    private let items: [(String, CGFloat, Bool)] = [
        ("헬멧", 0.1, true), ("목 보호대", 0.2, false), ("어깨·가슴", 0.3, true), ("팔꿈치", 0.4, false),
        ("장갑", 0.5, true), ("하키 바지", 0.58, false), ("정강이", 0.74, true), ("스케이트", 0.92, false),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(iceFill)
                AppIcon("figure.stand", size: h * 0.9)
                    .foregroundStyle(Theme.cobalt.opacity(0.85))
                    .position(x: w / 2, y: h / 2)
                Path { p in p.move(to: CGPoint(x: w * 0.62, y: h * 0.45)); p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.95)) }
                    .stroke(Color.brown, style: StrokeStyle(lineWidth: compact ? 2 : 4, lineCap: .round))
                if !compact {
                    ForEach(items, id: \.0) { name, y, left in
                        let anchor = CGPoint(x: w * (left ? 0.45 : 0.55), y: h * y)
                        let label = CGPoint(x: w * (left ? 0.16 : 0.84), y: h * y)
                        Path { p in p.move(to: anchor); p.addLine(to: label) }
                            .stroke(Theme.accent.opacity(0.7), lineWidth: 1)
                        Circle().fill(Theme.accent).frame(width: 6, height: 6).position(anchor)
                        Text(name).font(.caption2.bold()).foregroundStyle(Theme.title)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.card, in: Capsule())
                            .position(label)
                    }
                    Text("스틱").font(.caption2.bold()).foregroundStyle(.brown).position(x: w * 0.75, y: h * 0.82)
                }
            }
        }
    }
}

// MARK: - 페널티 시간

struct PenaltyBarsArt: View {
    var compact = false
    private let rows: [(String, Double, String, Color)] = [
        ("마이너", 2, "2분 · 한 명 적게", Theme.accent),
        ("메이저", 5, "5분 · 한 명 적게", Theme.danger),
        ("미스컨덕트", 10, "10분 · 대신 들어가", Theme.warningFill),
        ("게임 미스컨덕트", 12, "경기 끝까지 퇴장", Theme.inkTertiary),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 10) {
            ForEach(rows, id: \.0) { name, minutes, caption, color in
                HStack(spacing: 8) {
                    if !compact { Text(name).font(.caption.bold()).frame(width: 92, alignment: .leading) }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.inkTertiary.opacity(0.12))
                            Capsule().fill(color).frame(width: g.size.width * minutes / 12)
                            if minutes >= 12 {
                                AppIcon("arrow.right").font(.caption2.bold()).foregroundStyle(.white)
                                    .padding(.trailing, 6).frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .frame(height: compact ? 8 : 16)
                    if !compact { Text(caption).font(.caption2).foregroundStyle(Theme.inkSecondary).frame(width: 96, alignment: .leading) }
                }
            }
            if !compact {
                HStack(spacing: 6) {
                    AppIcon("person.fill").foregroundStyle(Theme.accent)
                    Text("마이너는 상대가 골을 넣으면 바로 끝나요. 메이저는 끝까지 채워야 해요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(compact ? 6 : 12)
        .background(iceFill, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 경기 시간

struct GameClockArt: View {
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 10) {
            HStack(spacing: compact ? 2 : 4) {
                block("1P", "20분", Theme.cobalt, 3)
                block("휴식", "15분", Theme.inkTertiary.opacity(0.35), 1)
                block("2P", "20분", Theme.cobalt, 3)
                block("휴식", "15분", Theme.inkTertiary.opacity(0.35), 1)
                block("3P", "20분", Theme.cobalt, 3)
            }
            HStack(spacing: compact ? 2 : 4) {
                AppIcon("equal.circle.fill").foregroundStyle(Theme.inkSecondary).font(compact ? .caption2 : .body)
                block("연장", "최대 5분 · 3대3", Theme.warningFill, 4)
                AppIcon("arrow.right").foregroundStyle(Theme.inkSecondary).font(compact ? .caption2 : .body)
                block("슛아웃", "5명씩", Theme.danger, 3)
            }
            if !compact {
                Text("비기면 연장, 연장에서 먼저 넣으면 끝. 그래도 안 나면 슛아웃.").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(compact ? 6 : 12)
        .background(iceFill, in: RoundedRectangle(cornerRadius: 14))
    }

    private func block(_ title: String, _ sub: String, _ color: Color, _ weight: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(title).font(compact ? .system(size: 8, weight: .bold) : .caption.bold())
            if !compact { Text(sub).font(.system(size: 9)) }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: compact ? 16 : 40)
        .background(color, in: RoundedRectangle(cornerRadius: 6))
        .layoutPriority(weight)
    }
}

// MARK: - 골 무효

struct NoGoalArt: View {
    var compact = false
    private let cases: [(String, String)] = [
        ("hand.raised.fill", "손으로 쳐 넣음"),
        ("shoeprints.fill", "스케이트로 차 넣음"),
        ("arrow.up.to.line", "크로스바 위 스틱"),
        ("person.fill.xmark", "골키퍼 방해"),
        ("rectangle.portrait.slash", "골대가 빠짐"),
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 4 : 8), count: compact ? 5 : 3),
                  spacing: compact ? 4 : 8) {
            ForEach(cases, id: \.1) { icon, title in
                VStack(spacing: 4) {
                    ZStack {
                        goalFrame
                        AppIcon(icon).font(compact ? .caption : .title3).foregroundStyle(Theme.cobalt)
                        AppIcon("xmark").font(compact ? .caption2.bold() : .title2.bold())
                            .foregroundStyle(Theme.danger.opacity(0.9))
                            .offset(x: compact ? 8 : 18, y: compact ? -6 : -14)
                    }
                    .frame(height: compact ? 30 : 64)
                    if !compact { Text(title).font(.caption.bold()).foregroundStyle(Theme.title).multilineTextAlignment(.center) }
                }
                .frame(maxWidth: .infinity)
                .padding(compact ? 2 : 8)
                .background(iceFill, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var goalFrame: some View {
        RoundedRectangle(cornerRadius: 3).stroke(redLine.opacity(0.8), lineWidth: compact ? 1.5 : 2.5)
            .frame(width: compact ? 26 : 56, height: compact ? 18 : 38)
            .overlay(GridPattern().stroke(Theme.inkTertiary.opacity(0.3), lineWidth: 0.5).padding(2))
    }
}

/// 골망 무늬.
struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 1..<4 {
            let x = rect.minX + rect.width * CGFloat(i) / 4
            p.move(to: CGPoint(x: x, y: rect.minY)); p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for i in 1..<3 {
            let y = rect.minY + rect.height * CGFloat(i) / 3
            p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

// MARK: - 골키퍼 페널티

struct GoalieArt: View {
    var compact = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(iceFill)
                // 골대와 골키퍼(그대로 남음)
                RoundedRectangle(cornerRadius: 3).stroke(redLine, lineWidth: 2)
                    .frame(width: w * 0.08, height: h * 0.3).position(x: w * 0.08, y: h * 0.5)
                AppIcon("figure.hockey", size: (compact ? 18 : 34) * 1.15).foregroundStyle(Theme.cobalt)
                    .scaleEffect(x: -1, y: 1).position(x: w * 0.2, y: h * 0.5)
                if !compact { Text("골키퍼는 그대로").font(.caption2.bold()).foregroundStyle(Theme.title).position(x: w * 0.2, y: h * 0.8) }
                // 페널티 박스
                RoundedRectangle(cornerRadius: 6).stroke(Theme.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: w * 0.26, height: h * 0.42).position(x: w * 0.82, y: h * 0.42)
                if !compact { Text("페널티 박스").font(.caption2).foregroundStyle(Theme.inkSecondary).position(x: w * 0.82, y: h * 0.14) }
                AppIcon("figure.hockey", size: (compact ? 16 : 28) * 1.15).foregroundStyle(Theme.danger)
                    .position(x: w * 0.82, y: h * 0.44)
                // 다른 선수가 대신 감
                Path { p in p.move(to: CGPoint(x: w * 0.38, y: h * 0.6)); p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.48)) }
                    .stroke(Theme.danger, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                AppIcon("arrowtriangle.right.fill", size: 10.35).foregroundStyle(Theme.danger)
                    .position(x: w * 0.66, y: h * 0.48)
                if !compact { Text("다른 선수가 대신").font(.caption2.bold()).foregroundStyle(Theme.danger).position(x: w * 0.52, y: h * 0.75) }
            }
        }
    }
}

// MARK: - 파워플레이·엠티넷

struct PowerPlayArt: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 10) {
            panel(title: "파워플레이", sub: "5 대 4") {
                VStack(spacing: compact ? 2 : 4) {
                    dots(5, Theme.accent)
                    dots(4, Theme.inkTertiary)
                }
            }
            panel(title: "엠티넷", sub: "골대 비우고 +1") {
                HStack(spacing: compact ? 3 : 6) {
                    RoundedRectangle(cornerRadius: 3).stroke(redLine, lineWidth: compact ? 1.5 : 2)
                        .frame(width: compact ? 10 : 18, height: compact ? 16 : 30)
                        .overlay(AppIcon("questionmark", size: (compact ? 7 : 11) * 1.15).foregroundStyle(Theme.inkSecondary))
                    VStack(spacing: 2) {
                        dots(5, Theme.accent)
                        Text("+1").font(.system(size: compact ? 8 : 12, weight: .heavy)).foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private func dots(_ n: Int, _ c: Color) -> some View {
        HStack(spacing: compact ? 2 : 4) {
            ForEach(0..<n, id: \.self) { _ in Circle().fill(c).frame(width: compact ? 6 : 12, height: compact ? 6 : 12) }
        }
    }

    private func panel<C: View>(title: String, sub: String, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: compact ? 3 : 8) {
            content()
            if !compact {
                Text(title).font(.caption.bold()).foregroundStyle(Theme.title)
                Text(sub).font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(compact ? 4 : 10)
        .background(iceFill, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 포지션 썸네일(골키퍼 1 · 수비 2 · 공격 3).
struct PositionsMini: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(iceFill)
                ForEach(PositionsDiagram.spots, id: \.0) { _, p, color in
                    Circle().fill(color).frame(width: 9, height: 9).position(x: p.x * w, y: p.y * h)
                }
            }
        }
    }
}
