import SwiftUI
import HockeyCore

/// 규칙 카드 상세: 한 문장 설명 → 잘못된/정상 상황 도식 → 1문항 퀴즈 (8.2).
struct RuleDetailView: View {
    let topic: RuleTopic
    @State private var picked: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Label(topic.title, systemImage: topic.symbol).font(.title3.bold()).foregroundStyle(.white)
                    Text(topic.summary).font(.body).foregroundStyle(.white)
                }
                if let scenes = RuleScene.scenes[topic.id] {
                    RuleSceneCard(scenes: scenes)
                }
                if topic.id == "positions" { PositionsDiagram() }
                if RuleArt.needsDetailArt(topic.id) {
                    Card {
                        RuleArt(id: topic.id)
                            .frame(height: RuleArt.detailHeight(topic.id))
                            .accessibilityHidden(true)
                        Text("그림은 이해를 돕는 도식이에요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
                    }
                }
                if topic.id == "fouls" {
                    FoulCards(points: topic.points)
                } else {
                Card {
                    CardHeader(title: "자세히", systemImage: "list.bullet")
                    ForEach(Array(topic.points.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Theme.accent).frame(width: 6, height: 6).padding(.top, 7)
                            Text(p).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                }
                quizCard
                Text("\(RuleGuide.source)의 \(topic.reference) 내용을 보고 쉽게 풀어 썼어요. 대회나 동호회마다 다를 수 있으니 꼭 확인해 주세요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var quizCard: some View {
        Card(tint: Theme.iceBlue) {
            CardHeader(title: "퀴즈", systemImage: "questionmark.bubble")
            Text(topic.quiz.question).font(.subheadline.bold()).foregroundStyle(Theme.title)
            ForEach(Array(topic.quiz.options.enumerated()), id: \.offset) { i, option in
                let isAnswer = i == topic.quiz.answer
                let chosen = picked == i
                Button {
                    picked = i
                } label: {
                    HStack {
                        Text(option)
                        Spacer()
                        if picked != nil && isAnswer { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success) }
                        if chosen && !isAnswer { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger) }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
            }
            if let picked {
                Text((picked == topic.quiz.answer ? "맞았어요! " : "아쉬워요. ") + topic.quiz.explain)
                    .font(.subheadline)
                Button("다시 풀기") { self.picked = nil }.font(.footnote)
            }
        }
    }
}

/// 규칙 도식 한 장면. 좌표는 0~1, 시작→끝으로 움직인다.
struct RuleScene {
    enum Kind { case attacker, defender, puck }
    struct Marker { var kind: Kind; var from: CGPoint; var to: CGPoint }
    struct Line { var x: CGFloat; var color: Color; var label: String }

    var title: String
    var ok: Bool
    var lines: [Line]
    var bench: Bool = false
    var markers: [Marker]
    var caption: String

    static let blue = Theme.rinkBlue
    static let red = Theme.rinkRed

    static let scenes: [String: [RuleScene]] = [
        "offside": [
            RuleScene(title: "잘못된 상황", ok: false,
                      lines: [Line(x: 0.55, color: blue, label: "상대 블루라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.3, y: 0.45), to: CGPoint(x: 0.78, y: 0.45)),
                                Marker(kind: .puck, from: CGPoint(x: 0.18, y: 0.62), to: CGPoint(x: 0.62, y: 0.62))],
                      caption: "선수가 퍽보다 먼저 블루라인을 넘었어요 → 오프사이드"),
            RuleScene(title: "정상 상황", ok: true,
                      lines: [Line(x: 0.55, color: blue, label: "상대 블루라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.25, y: 0.45), to: CGPoint(x: 0.7, y: 0.45)),
                                Marker(kind: .puck, from: CGPoint(x: 0.4, y: 0.62), to: CGPoint(x: 0.88, y: 0.62))],
                      caption: "퍽이 먼저 라인을 넘고 선수가 따라 들어가요 → 정상"),
        ],
        "icing": [
            RuleScene(title: "잘못된 상황", ok: false,
                      lines: [Line(x: 0.5, color: red, label: "센터 레드라인"), Line(x: 0.93, color: red, label: "상대 골라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.22, y: 0.4), to: CGPoint(x: 0.22, y: 0.4)),
                                Marker(kind: .puck, from: CGPoint(x: 0.26, y: 0.55), to: CGPoint(x: 0.98, y: 0.55))],
                      caption: "레드라인 뒤에서 친 퍽이 그대로 골라인을 넘어요 → 아이싱"),
            RuleScene(title: "정상 상황", ok: true,
                      lines: [Line(x: 0.5, color: red, label: "센터 레드라인"), Line(x: 0.93, color: red, label: "상대 골라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.3, y: 0.4), to: CGPoint(x: 0.56, y: 0.4)),
                                Marker(kind: .puck, from: CGPoint(x: 0.34, y: 0.55), to: CGPoint(x: 0.98, y: 0.55))],
                      caption: "퍽을 몰고 레드라인을 넘은 뒤 쳤어요 → 아이싱 아님"),
        ],
        "faceoff": [
            RuleScene(title: "잘못된 상황", ok: false, lines: [],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.42, y: 0.6), to: CGPoint(x: 0.49, y: 0.6)),
                                Marker(kind: .defender, from: CGPoint(x: 0.58, y: 0.6), to: CGPoint(x: 0.58, y: 0.6)),
                                Marker(kind: .puck, from: CGPoint(x: 0.5, y: 0.1), to: CGPoint(x: 0.5, y: 0.35))],
                      caption: "퍽이 떨어지기 전에 먼저 움직였어요 → 위반, 센터가 바뀌어요"),
            RuleScene(title: "정상 상황", ok: true, lines: [],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.42, y: 0.6), to: CGPoint(x: 0.42, y: 0.6)),
                                Marker(kind: .defender, from: CGPoint(x: 0.58, y: 0.6), to: CGPoint(x: 0.58, y: 0.6)),
                                Marker(kind: .puck, from: CGPoint(x: 0.5, y: 0.1), to: CGPoint(x: 0.5, y: 0.6))],
                      caption: "퍽이 얼음에 닿은 다음에 다퉈요 → 정상"),
        ],
        "linechange": [
            RuleScene(title: "잘못된 상황", ok: false, lines: [], bench: true,
                      markers: [Marker(kind: .defender, from: CGPoint(x: 0.5, y: 0.8), to: CGPoint(x: 0.5, y: 0.55)),
                                Marker(kind: .attacker, from: CGPoint(x: 0.35, y: 0.12), to: CGPoint(x: 0.4, y: 0.62)),
                                Marker(kind: .puck, from: CGPoint(x: 0.45, y: 0.7), to: CGPoint(x: 0.45, y: 0.7))],
                      caption: "나가는 선수가 벤치에 닿기 전에 새 선수가 퍽을 건드렸어요 → 투 매니 플레이어"),
            RuleScene(title: "정상 상황", ok: true, lines: [], bench: true,
                      markers: [Marker(kind: .defender, from: CGPoint(x: 0.5, y: 0.8), to: CGPoint(x: 0.5, y: 0.14)),
                                Marker(kind: .attacker, from: CGPoint(x: 0.35, y: 0.12), to: CGPoint(x: 0.4, y: 0.62)),
                                Marker(kind: .puck, from: CGPoint(x: 0.45, y: 0.7), to: CGPoint(x: 0.45, y: 0.7))],
                      caption: "나가는 선수가 벤치 1.5m 안에 들어온 뒤 새 선수가 뛰어요 → 정상"),
        ],
    ]
}

/// 잘못된/정상 장면을 번갈아 보는 카드. 동작 줄이기면 움직임 없이 끝 장면만 보여준다.
struct RuleSceneCard: View {
    let scenes: [RuleScene]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var progress: CGFloat = 0

    var body: some View {
        let scene = scenes[index]
        Card {
            Picker("장면", selection: $index) {
                ForEach(scenes.indices, id: \.self) { i in Text(scenes[i].title).tag(i) }
            }
            .pickerStyle(.segmented)
            RinkSketch(scene: scene, progress: reduceMotion ? 1 : progress)
                .frame(height: 170)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(scene.caption)
            HStack(spacing: 6) {
                Image(systemName: scene.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(scene.ok ? Theme.success : Theme.danger)
                Text(scene.caption).font(.subheadline)
            }
            if !reduceMotion {
                Button { play() } label: { Label("다시 보기", systemImage: "play.circle") }.font(.footnote)
            }
            Text("그림은 이해를 돕는 도식이에요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
        .onAppear(perform: play)
        .onChange(of: index) { _, _ in play() }
    }

    private func play() {
        guard !reduceMotion else { return }
        progress = 0
        withAnimation(.easeInOut(duration: 1.8).delay(0.2)) { progress = 1 }
    }
}

/// 얼음 위 도식.
struct RinkSketch: View, Animatable {
    let scene: RuleScene
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Theme.ice)
                RoundedRectangle(cornerRadius: 16).stroke(Theme.inkTertiary.opacity(0.3), lineWidth: 1)
                if scene.bench {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.inkTertiary.opacity(0.25))
                        .frame(width: w * 0.5, height: h * 0.16)
                        .position(x: w * 0.4, y: h * 0.08)
                    Text("벤치").font(.caption2).foregroundStyle(Theme.inkSecondary).position(x: w * 0.4, y: h * 0.08)
                }
                ForEach(Array(scene.lines.enumerated()), id: \.offset) { _, line in
                    Rectangle().fill(line.color).frame(width: 5, height: h)
                        .position(x: line.x * w, y: h / 2)
                    Text(line.label).font(.caption2).foregroundStyle(line.color)
                        .padding(3).background(.background.opacity(0.8), in: Capsule())
                        .position(x: min(max(line.x * w, 44), w - 44), y: 12)
                }
                ForEach(Array(scene.markers.enumerated()), id: \.offset) { _, m in
                    let x = (m.from.x + (m.to.x - m.from.x) * progress) * w
                    let y = (m.from.y + (m.to.y - m.from.y) * progress) * h
                    marker(m.kind).position(x: x, y: y)
                }
            }
        }
    }

    @ViewBuilder
    private func marker(_ kind: RuleScene.Kind) -> some View {
        switch kind {
        case .puck:
            Ellipse().fill(Color.black).frame(width: 18, height: 10)
                .overlay(Ellipse().stroke(.white.opacity(0.7), lineWidth: 1))
        case .attacker:
            Image(systemName: "figure.hockey").font(.title2).foregroundStyle(Theme.danger)
        case .defender:
            Image(systemName: "figure.hockey").font(.title2).foregroundStyle(Theme.accent)
                .scaleEffect(x: -1, y: 1)
        }
    }
}

/// 포지션 배치 도식(공격수 3 + 수비수 2 + 골키퍼 1).
struct PositionsDiagram: View {
    var body: some View {
        Card {
            CardHeader(title: "기본 배치", systemImage: "person.3.fill")
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Theme.ice)
                    ForEach(Self.spots, id: \.0) { name, p, color in
                        VStack(spacing: 2) {
                            Circle().fill(color).frame(width: 22, height: 22)
                            Text(name).font(.caption2.bold()).foregroundStyle(Theme.title)
                        }
                        .position(x: p.x * w, y: p.y * h)
                    }
                }
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("골키퍼 1명, 수비수 2명, 센터 1명, 양쪽 윙 2명")
        }
    }

    static let spots: [(String, CGPoint, Color)] = [
        ("골키퍼", CGPoint(x: 0.5, y: 0.88), Theme.danger),
        ("왼쪽 수비", CGPoint(x: 0.3, y: 0.66), Theme.cobalt),
        ("오른쪽 수비", CGPoint(x: 0.7, y: 0.66), Theme.cobalt),
        ("센터", CGPoint(x: 0.5, y: 0.38), Theme.success),
        ("왼쪽 윙", CGPoint(x: 0.18, y: 0.24), Theme.success),
        ("오른쪽 윙", CGPoint(x: 0.82, y: 0.24), Theme.success),
    ]
}

/// 반칙 하나를 그림으로: 반칙한 선수(핑크)와 상대(파랑), 스틱, 화살표, 충돌 표시.
struct FoulSketch {
    var a: CGPoint = CGPoint(x: 0.28, y: 0.58)
    var b: CGPoint = CGPoint(x: 0.7, y: 0.58)
    var bTilt: Double = 0
    var stick: (CGPoint, CGPoint)? = nil
    var arrow: (CGPoint, CGPoint)? = nil
    var bang: CGPoint? = nil
    var hand: CGPoint? = nil
    var puck: CGPoint? = nil
    var blockedPath: (CGPoint, CGPoint)? = nil
    var boards = false
    var speedLines = false

    static func named(_ name: String) -> FoulSketch? {
        switch name {
        case "후킹":
            return FoulSketch(a: CGPoint(x: 0.3, y: 0.58), b: CGPoint(x: 0.68, y: 0.58),
                              stick: (CGPoint(x: 0.38, y: 0.62), CGPoint(x: 0.62, y: 0.6)),
                              arrow: (CGPoint(x: 0.72, y: 0.22), CGPoint(x: 0.5, y: 0.22)))
        case "슬래싱":
            return FoulSketch(stick: (CGPoint(x: 0.36, y: 0.5), CGPoint(x: 0.6, y: 0.42)),
                              arrow: (CGPoint(x: 0.36, y: 0.2), CGPoint(x: 0.58, y: 0.28)),
                              bang: CGPoint(x: 0.62, y: 0.42))
        case "트리핑":
            return FoulSketch(b: CGPoint(x: 0.7, y: 0.56), bTilt: 35,
                              stick: (CGPoint(x: 0.36, y: 0.66), CGPoint(x: 0.66, y: 0.86)),
                              bang: CGPoint(x: 0.68, y: 0.86))
        case "홀딩":
            return FoulSketch(a: CGPoint(x: 0.42, y: 0.58), b: CGPoint(x: 0.66, y: 0.58),
                              hand: CGPoint(x: 0.55, y: 0.46))
        case "인터피어런스":
            return FoulSketch(a: CGPoint(x: 0.5, y: 0.58), b: CGPoint(x: 0.28, y: 0.58),
                              puck: CGPoint(x: 0.86, y: 0.8),
                              blockedPath: (CGPoint(x: 0.34, y: 0.8), CGPoint(x: 0.8, y: 0.8)))
        case "하이 스틱":
            return FoulSketch(stick: (CGPoint(x: 0.36, y: 0.5), CGPoint(x: 0.64, y: 0.22)),
                              bang: CGPoint(x: 0.67, y: 0.22))
        case "크로스 체킹":
            return FoulSketch(a: CGPoint(x: 0.32, y: 0.58), b: CGPoint(x: 0.66, y: 0.58),
                              stick: (CGPoint(x: 0.52, y: 0.36), CGPoint(x: 0.52, y: 0.72)),
                              arrow: (CGPoint(x: 0.44, y: 0.16), CGPoint(x: 0.66, y: 0.16)),
                              bang: CGPoint(x: 0.58, y: 0.5))
        case "보딩":
            return FoulSketch(a: CGPoint(x: 0.5, y: 0.58), b: CGPoint(x: 0.78, y: 0.58),
                              arrow: (CGPoint(x: 0.42, y: 0.18), CGPoint(x: 0.7, y: 0.18)),
                              bang: CGPoint(x: 0.9, y: 0.5), boards: true)
        case "차징":
            return FoulSketch(a: CGPoint(x: 0.46, y: 0.58), b: CGPoint(x: 0.72, y: 0.58),
                              bang: CGPoint(x: 0.6, y: 0.5), speedLines: true)
        default:
            return nil
        }
    }
}

struct FoulSketchView: View {
    let sketch: FoulSketch

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let p: (CGPoint) -> CGPoint = { CGPoint(x: $0.x * w, y: $0.y * h) }
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.ice)
                if sketch.boards {
                    Rectangle().fill(Theme.inkTertiary.opacity(0.5)).frame(width: 6, height: h * 0.9).position(x: w * 0.93, y: h / 2)
                    Text("보드").font(.system(size: 9)).foregroundStyle(Theme.inkSecondary).position(x: w * 0.93, y: h * 0.06)
                }
                if sketch.speedLines {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(Theme.danger.opacity(0.5))
                            .frame(width: w * 0.2, height: 2.5)
                            .position(x: w * 0.22, y: h * (0.45 + Double(i) * 0.12))
                    }
                }
                if let path = sketch.blockedPath {
                    Path { pp in pp.move(to: p(path.0)); pp.addLine(to: p(path.1)) }
                        .stroke(Theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
                        .position(p(CGPoint(x: (path.0.x + path.1.x) / 2, y: path.0.y)))
                }
                if let s = sketch.stick {
                    Path { pp in pp.move(to: p(s.0)); pp.addLine(to: p(s.1)) }
                        .stroke(Color.brown, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                if let ar = sketch.arrow {
                    Path { pp in pp.move(to: p(ar.0)); pp.addLine(to: p(ar.1)) }
                        .stroke(Theme.danger, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    Image(systemName: ar.1.x >= ar.0.x ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
                        .font(.system(size: 10)).foregroundStyle(Theme.danger).position(p(ar.1))
                }
                player(color: Theme.danger, mirrored: false).position(p(sketch.a))
                player(color: Theme.cobalt, mirrored: true).rotationEffect(.degrees(sketch.bTilt)).position(p(sketch.b))
                if let hand = sketch.hand {
                    Image(systemName: "hand.raised.fill").font(.system(size: 16)).foregroundStyle(Theme.danger).position(p(hand))
                }
                if let puck = sketch.puck {
                    Circle().fill(Color.black).frame(width: 9, height: 9).position(p(puck))
                }
                if let bang = sketch.bang {
                    Image(systemName: "burst.fill").font(.system(size: 18)).foregroundStyle(Theme.warningFill).position(p(bang))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func player(color: Color, mirrored: Bool) -> some View {
        Image(systemName: "figure.hockey").font(.system(size: 30)).foregroundStyle(color)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }
}

/// '자주 나오는 반칙' 그림 카드 목록. "이름: 설명" 문장을 나눠 그림과 함께 보여준다.
struct FoulCards: View {
    let points: [String]

    var body: some View {
        Card {
            CardHeader(title: "그림으로 보기", systemImage: "photo")
            HStack(spacing: 12) {
                legend(Theme.danger, "반칙한 선수")
                legend(Theme.cobalt, "상대")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(items, id: \.0) { name, desc in
                    VStack(alignment: .leading, spacing: 6) {
                        if let s = FoulSketch.named(name) { FoulSketchView(sketch: s).frame(height: 88) }
                        Text(name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                        Text(desc).font(.caption).foregroundStyle(Theme.inkSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .accessibilityElement(children: .combine)
                }
            }
            ForEach(rest, id: \.self) { Text($0).font(.caption).foregroundStyle(Theme.inkSecondary) }
        }
    }

    private var items: [(String, String)] {
        points.compactMap { p in
            guard let r = p.range(of: ": ") else { return nil }
            let name = String(p[..<r.lowerBound])
            return FoulSketch.named(name) == nil ? nil : (name, String(p[r.upperBound...]))
        }
    }

    private var rest: [String] {
        points.filter { p in
            guard let r = p.range(of: ": ") else { return true }
            return FoulSketch.named(String(p[..<r.lowerBound])) == nil
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.hockey").foregroundStyle(c)
            Text(t).font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
    }
}
