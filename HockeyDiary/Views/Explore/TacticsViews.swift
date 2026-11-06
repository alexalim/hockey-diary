import SwiftUI
import HockeyCore

/// 전술 노트 상세: 한 줄 설명 → 움직이는 링크 그림 → 핵심 → 언제 써 → 연습 팁.
struct TacticDetailView: View {
    let topic: TacticTopic

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text(topic.tag).font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.neonPink, in: Capsule())
                    Text(topic.title).font(.title2.bold()).foregroundStyle(.white)
                    Text(topic.summary).font(.body).foregroundStyle(.white)
                }
                if let plays = TacticPlay.plays[topic.id] { TacticPlayCard(play: plays) }
                Card {
                    CardHeader(title: "핵심", systemImage: "list.bullet")
                    ForEach(Array(topic.points.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1)").font(.caption.bold()).foregroundStyle(.white)
                                .frame(width: 20, height: 20).background(Theme.neonPink, in: Circle())
                            Text(p).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Card(tint: Theme.iceBlue) {
                    CardHeader(title: "언제 써?", systemImage: "clock")
                    Text(topic.when).font(.subheadline)
                }
                Card {
                    CardHeader(title: "이렇게 연습해봐", systemImage: "figure.hockey")
                    Text(topic.practice).font(.subheadline)
                }
                Text("전술은 정답이 없어. 팀마다 다르게 쓰니까 코치님 방식이 먼저야.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 전술 그림. 좌표는 링크 전체 기준 0~1(왼쪽이 우리 골대, 오른쪽이 상대 골대).
struct TacticPlay {
    enum Side { case us, them }
    struct Player { var label: String; var side: Side; var from: CGPoint; var to: CGPoint }
    enum Kind { case skate, pass }
    struct Move { var kind: Kind; var from: CGPoint; var to: CGPoint }

    var players: [Player]
    var puckFrom: CGPoint
    var puckTo: CGPoint
    var moves: [Move]
    var caption: String

    static let plays: [String: TacticPlay] = [
        "forecheck-121": TacticPlay(
            players: [
                Player(label: "F1", side: .us, from: CGPoint(x: 0.62, y: 0.5), to: CGPoint(x: 0.86, y: 0.32)),
                Player(label: "F2", side: .us, from: CGPoint(x: 0.6, y: 0.2), to: CGPoint(x: 0.76, y: 0.14)),
                Player(label: "F3", side: .us, from: CGPoint(x: 0.6, y: 0.8), to: CGPoint(x: 0.76, y: 0.84)),
                Player(label: "D", side: .us, from: CGPoint(x: 0.5, y: 0.5), to: CGPoint(x: 0.66, y: 0.5)),
                Player(label: "", side: .them, from: CGPoint(x: 0.9, y: 0.36), to: CGPoint(x: 0.9, y: 0.3)),
            ],
            puckFrom: CGPoint(x: 0.91, y: 0.4), puckTo: CGPoint(x: 0.91, y: 0.34),
            moves: [Move(kind: .skate, from: CGPoint(x: 0.62, y: 0.5), to: CGPoint(x: 0.85, y: 0.33))],
            caption: "F1이 퍽 잡은 수비에게 붙고, F2·F3가 보드 쪽 패스 길을 막아."),
        "forecheck-122": TacticPlay(
            players: [
                Player(label: "F1", side: .us, from: CGPoint(x: 0.6, y: 0.5), to: CGPoint(x: 0.8, y: 0.42)),
                Player(label: "F2", side: .us, from: CGPoint(x: 0.56, y: 0.25), to: CGPoint(x: 0.7, y: 0.25)),
                Player(label: "F3", side: .us, from: CGPoint(x: 0.56, y: 0.75), to: CGPoint(x: 0.7, y: 0.75)),
                Player(label: "D", side: .us, from: CGPoint(x: 0.5, y: 0.3), to: CGPoint(x: 0.64, y: 0.3)),
                Player(label: "D", side: .us, from: CGPoint(x: 0.5, y: 0.7), to: CGPoint(x: 0.64, y: 0.7)),
            ],
            puckFrom: CGPoint(x: 0.9, y: 0.5), puckTo: CGPoint(x: 0.88, y: 0.3),
            moves: [Move(kind: .skate, from: CGPoint(x: 0.6, y: 0.5), to: CGPoint(x: 0.79, y: 0.43))],
            caption: "F1이 한쪽으로 몰고, 나머지는 자리를 지키며 기다려."),
        "breakout": TacticPlay(
            players: [
                Player(label: "D", side: .us, from: CGPoint(x: 0.12, y: 0.45), to: CGPoint(x: 0.05, y: 0.5)),
                Player(label: "W", side: .us, from: CGPoint(x: 0.3, y: 0.12), to: CGPoint(x: 0.22, y: 0.1)),
                Player(label: "C", side: .us, from: CGPoint(x: 0.3, y: 0.5), to: CGPoint(x: 0.24, y: 0.42)),
                Player(label: "W", side: .us, from: CGPoint(x: 0.3, y: 0.88), to: CGPoint(x: 0.42, y: 0.88)),
            ],
            puckFrom: CGPoint(x: 0.05, y: 0.55), puckTo: CGPoint(x: 0.22, y: 0.12),
            moves: [Move(kind: .pass, from: CGPoint(x: 0.05, y: 0.55), to: CGPoint(x: 0.22, y: 0.12)),
                    Move(kind: .skate, from: CGPoint(x: 0.22, y: 0.1), to: CGPoint(x: 0.42, y: 0.1))],
            caption: "수비가 골대 뒤에서 퍽을 잡고, 보드 쪽 윙에게 줘서 빠져나가."),
        "board-house": TacticPlay(
            players: [
                Player(label: "F1", side: .us, from: CGPoint(x: 0.74, y: 0.15), to: CGPoint(x: 0.82, y: 0.48)),
                Player(label: "F2", side: .us, from: CGPoint(x: 0.92, y: 0.25), to: CGPoint(x: 0.92, y: 0.25)),
                Player(label: "", side: .them, from: CGPoint(x: 0.84, y: 0.3), to: CGPoint(x: 0.86, y: 0.26)),
            ],
            puckFrom: CGPoint(x: 0.75, y: 0.12), puckTo: CGPoint(x: 0.82, y: 0.48),
            moves: [Move(kind: .pass, from: CGPoint(x: 0.75, y: 0.12), to: CGPoint(x: 0.92, y: 0.22)),
                    Move(kind: .skate, from: CGPoint(x: 0.74, y: 0.15), to: CGPoint(x: 0.82, y: 0.48)),
                    Move(kind: .pass, from: CGPoint(x: 0.92, y: 0.25), to: CGPoint(x: 0.82, y: 0.48))],
            caption: "보드를 맞혀 주고 바로 골대 앞으로 들어가. 다시 받아서 쏴."),
        "cycle": TacticPlay(
            players: [
                Player(label: "F1", side: .us, from: CGPoint(x: 0.88, y: 0.12), to: CGPoint(x: 0.78, y: 0.2)),
                Player(label: "F2", side: .us, from: CGPoint(x: 0.76, y: 0.12), to: CGPoint(x: 0.9, y: 0.12)),
                Player(label: "", side: .them, from: CGPoint(x: 0.86, y: 0.22), to: CGPoint(x: 0.84, y: 0.24)),
            ],
            puckFrom: CGPoint(x: 0.9, y: 0.1), puckTo: CGPoint(x: 0.91, y: 0.1),
            moves: [Move(kind: .skate, from: CGPoint(x: 0.88, y: 0.12), to: CGPoint(x: 0.78, y: 0.2)),
                    Move(kind: .skate, from: CGPoint(x: 0.76, y: 0.12), to: CGPoint(x: 0.9, y: 0.12))],
            caption: "F1이 퍽을 남기고 위로 돌고, F2가 이어받아. 계속 돌리며 빈틈을 기다려."),
    ]
}

struct TacticPlayCard: View {
    let play: TacticPlay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        Card {
            TacticRink(play: play, progress: reduceMotion ? 1 : progress)
                .aspectRatio(2.1, contentMode: .fit)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(play.caption)
            Text(play.caption).font(.subheadline)
            HStack(spacing: 14) {
                legend(dash: false, "스케이팅")
                legend(dash: true, "패스")
                Spacer()
                if !reduceMotion {
                    Button { replay() } label: { Label("다시 보기", systemImage: "play.circle") }.font(.footnote)
                }
            }
        }
        .onAppear(perform: replay)
    }

    private func legend(dash: Bool, _ title: String) -> some View {
        HStack(spacing: 4) {
            Capsule().stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: dash ? [4, 3] : []))
                .frame(width: 22, height: 2)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func replay() {
        guard !reduceMotion else { return }
        progress = 0
        withAnimation(.easeInOut(duration: 2).delay(0.3)) { progress = 1 }
    }
}

/// 링크 전체 그림(골라인·블루라인·센터 레드라인·골대) 위에 선수·퍽·경로.
struct TacticRink: View, Animatable {
    let play: TacticPlay
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let p: (CGPoint) -> CGPoint = { CGPoint(x: $0.x * w, y: $0.y * h) }
            ZStack {
                RoundedRectangle(cornerRadius: h * 0.28).fill(Color(light: 0xF2FAFF, dark: 0x1B2A36))
                RoundedRectangle(cornerRadius: h * 0.28).stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                ForEach([0.06, 0.94], id: \.self) { x in
                    Rectangle().fill(Color(hex: 0xE5484D).opacity(0.6)).frame(width: 1.5, height: h * 0.8).position(x: x * w, y: h / 2)
                }
                ForEach([0.35, 0.65], id: \.self) { x in
                    Rectangle().fill(Color(hex: 0x2F6BFF)).frame(width: 4, height: h).position(x: x * w, y: h / 2)
                }
                Rectangle().fill(Color(hex: 0xE5484D)).frame(width: 4, height: h).position(x: w / 2, y: h / 2)
                ForEach([0.035, 0.965], id: \.self) { x in
                    RoundedRectangle(cornerRadius: 2).stroke(Color.secondary, lineWidth: 1.5)
                        .frame(width: w * 0.025, height: h * 0.14).position(x: x * w, y: h / 2)
                }
                // 경로(진행도만큼 그린다)
                ForEach(Array(play.moves.enumerated()), id: \.offset) { _, m in
                    Path { path in path.move(to: p(m.from)); path.addLine(to: p(m.to)) }
                        .trim(from: 0, to: progress)
                        .stroke(Theme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: m.kind == .pass ? [5, 4] : []))
                }
                ForEach(Array(play.players.enumerated()), id: \.offset) { _, pl in
                    let pt = p(CGPoint(x: pl.from.x + (pl.to.x - pl.from.x) * progress, y: pl.from.y + (pl.to.y - pl.from.y) * progress))
                    ZStack {
                        Circle().fill(pl.side == .us ? Theme.cobalt : Color.white)
                        Circle().stroke(pl.side == .us ? Color.white : Color.secondary, lineWidth: 1.5)
                        Text(pl.label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 22, height: 22)
                    .position(pt)
                }
                let puck = p(CGPoint(x: play.puckFrom.x + (play.puckTo.x - play.puckFrom.x) * progress,
                                     y: play.puckFrom.y + (play.puckTo.y - play.puckFrom.y) * progress))
                Circle().fill(Color.black).frame(width: 9, height: 9).overlay(Circle().stroke(.white, lineWidth: 1)).position(puck)
            }
        }
    }
}
