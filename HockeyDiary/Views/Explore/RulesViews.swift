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
                Card {
                    CardHeader(title: "자세히", systemImage: "list.bullet")
                    ForEach(Array(topic.points.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Theme.neonPink).frame(width: 6, height: 6).padding(.top, 7)
                            Text(p).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                quizCard
                Text("\(RuleGuide.source)의 \(topic.reference) 내용을 보고 쉽게 풀어 썼어. 대회나 동호회마다 다를 수 있으니 꼭 확인해줘.")
                    .font(.caption).foregroundStyle(.secondary)
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
                        if picked != nil && isAnswer { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        if chosen && !isAnswer { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.neonPink) }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
            }
            if let picked {
                Text((picked == topic.quiz.answer ? "맞았어! " : "아쉬워. ") + topic.quiz.explain)
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

    static let blue = Color(hex: 0x2F6BFF)
    static let red = Color(hex: 0xE5484D)

    static let scenes: [String: [RuleScene]] = [
        "offside": [
            RuleScene(title: "잘못된 상황", ok: false,
                      lines: [Line(x: 0.55, color: blue, label: "상대 블루라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.3, y: 0.45), to: CGPoint(x: 0.78, y: 0.45)),
                                Marker(kind: .puck, from: CGPoint(x: 0.18, y: 0.62), to: CGPoint(x: 0.62, y: 0.62))],
                      caption: "선수가 퍽보다 먼저 블루라인을 넘었어 → 오프사이드"),
            RuleScene(title: "정상 상황", ok: true,
                      lines: [Line(x: 0.55, color: blue, label: "상대 블루라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.25, y: 0.45), to: CGPoint(x: 0.7, y: 0.45)),
                                Marker(kind: .puck, from: CGPoint(x: 0.4, y: 0.62), to: CGPoint(x: 0.88, y: 0.62))],
                      caption: "퍽이 먼저 라인을 넘고 선수가 따라 들어가 → 정상"),
        ],
        "icing": [
            RuleScene(title: "잘못된 상황", ok: false,
                      lines: [Line(x: 0.5, color: red, label: "센터 레드라인"), Line(x: 0.93, color: red, label: "상대 골라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.22, y: 0.4), to: CGPoint(x: 0.22, y: 0.4)),
                                Marker(kind: .puck, from: CGPoint(x: 0.26, y: 0.55), to: CGPoint(x: 0.98, y: 0.55))],
                      caption: "레드라인 뒤에서 친 퍽이 그대로 골라인을 넘어 → 아이싱"),
            RuleScene(title: "정상 상황", ok: true,
                      lines: [Line(x: 0.5, color: red, label: "센터 레드라인"), Line(x: 0.93, color: red, label: "상대 골라인")],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.3, y: 0.4), to: CGPoint(x: 0.56, y: 0.4)),
                                Marker(kind: .puck, from: CGPoint(x: 0.34, y: 0.55), to: CGPoint(x: 0.98, y: 0.55))],
                      caption: "퍽을 몰고 레드라인을 넘은 뒤 쳤어 → 아이싱 아님"),
        ],
        "faceoff": [
            RuleScene(title: "잘못된 상황", ok: false, lines: [],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.42, y: 0.6), to: CGPoint(x: 0.49, y: 0.6)),
                                Marker(kind: .defender, from: CGPoint(x: 0.58, y: 0.6), to: CGPoint(x: 0.58, y: 0.6)),
                                Marker(kind: .puck, from: CGPoint(x: 0.5, y: 0.1), to: CGPoint(x: 0.5, y: 0.35))],
                      caption: "퍽이 떨어지기 전에 먼저 움직였어 → 위반, 센터가 바뀌어"),
            RuleScene(title: "정상 상황", ok: true, lines: [],
                      markers: [Marker(kind: .attacker, from: CGPoint(x: 0.42, y: 0.6), to: CGPoint(x: 0.42, y: 0.6)),
                                Marker(kind: .defender, from: CGPoint(x: 0.58, y: 0.6), to: CGPoint(x: 0.58, y: 0.6)),
                                Marker(kind: .puck, from: CGPoint(x: 0.5, y: 0.1), to: CGPoint(x: 0.5, y: 0.6))],
                      caption: "퍽이 얼음에 닿은 다음에 다퉈 → 정상"),
        ],
        "linechange": [
            RuleScene(title: "잘못된 상황", ok: false, lines: [], bench: true,
                      markers: [Marker(kind: .defender, from: CGPoint(x: 0.5, y: 0.8), to: CGPoint(x: 0.5, y: 0.55)),
                                Marker(kind: .attacker, from: CGPoint(x: 0.35, y: 0.12), to: CGPoint(x: 0.4, y: 0.62)),
                                Marker(kind: .puck, from: CGPoint(x: 0.45, y: 0.7), to: CGPoint(x: 0.45, y: 0.7))],
                      caption: "나가는 선수가 벤치에 닿기 전에 새 선수가 퍽을 건드렸어 → 투 매니 플레이어"),
            RuleScene(title: "정상 상황", ok: true, lines: [], bench: true,
                      markers: [Marker(kind: .defender, from: CGPoint(x: 0.5, y: 0.8), to: CGPoint(x: 0.5, y: 0.14)),
                                Marker(kind: .attacker, from: CGPoint(x: 0.35, y: 0.12), to: CGPoint(x: 0.4, y: 0.62)),
                                Marker(kind: .puck, from: CGPoint(x: 0.45, y: 0.7), to: CGPoint(x: 0.45, y: 0.7))],
                      caption: "나가는 선수가 벤치 1.5m 안에 들어온 뒤 새 선수가 뛰어 → 정상"),
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
                    .foregroundStyle(scene.ok ? Theme.accent : Theme.neonPink)
                Text(scene.caption).font(.subheadline)
            }
            if !reduceMotion {
                Button { play() } label: { Label("다시 보기", systemImage: "play.circle") }.font(.footnote)
            }
            Text("그림은 이해를 돕는 도식이야.").font(.caption2).foregroundStyle(.secondary)
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
                RoundedRectangle(cornerRadius: 16).fill(Color(light: 0xF2FAFF, dark: 0x1B2A36))
                RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                if scene.bench {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.25))
                        .frame(width: w * 0.5, height: h * 0.16)
                        .position(x: w * 0.4, y: h * 0.08)
                    Text("벤치").font(.caption2).foregroundStyle(.secondary).position(x: w * 0.4, y: h * 0.08)
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
            Image(systemName: "figure.hockey").font(.title2).foregroundStyle(Theme.neonPink)
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
                    RoundedRectangle(cornerRadius: 16).fill(Color(light: 0xF2FAFF, dark: 0x1B2A36))
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
        ("골키퍼", CGPoint(x: 0.5, y: 0.88), Theme.deepNavy),
        ("왼쪽 수비", CGPoint(x: 0.3, y: 0.66), Theme.cobalt),
        ("오른쪽 수비", CGPoint(x: 0.7, y: 0.66), Theme.cobalt),
        ("센터", CGPoint(x: 0.5, y: 0.38), Theme.neonPink),
        ("왼쪽 윙", CGPoint(x: 0.18, y: 0.24), Theme.neonPink),
        ("오른쪽 윙", CGPoint(x: 0.82, y: 0.24), Theme.neonPink),
    ]
}
