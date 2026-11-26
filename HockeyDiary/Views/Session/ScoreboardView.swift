import SwiftUI
import SwiftData
import HockeyCore

/// 경기 점수판. 벤치에서 장갑 낀 채 누르는 화면이라 버튼을 크게, 잘못 누른 건 바로 되돌리게 한다.
/// 끝내면 경기 리뷰가 점수·내 골·어시·상대·시간이 채워진 채로 열린다.
struct ScoreboardView: View {
    /// 팀 일정에서 열었으면 그 일정(팀 이름·상대·종류를 채우고, 끝내면 일정과 잇는다).
    var eventID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppJumper.self) private var jumper: AppJumper?
    @Query(sort: \TeamEvent.at) private var events: [TeamEvent]
    @Query(sort: \Team.createdAt) private var teams: [Team]
    @State private var store = ScoreboardStore.shared

    // 시작 전 입력
    @State private var teamName = ""
    @State private var opponent = ""
    @State private var kind: ActivityType = .regularGame
    @State private var didPrefill = false

    @State private var askingCredit = false
    @State private var confirmingFinish = false
    @State private var confirmingDiscard = false

    var body: some View {
        Group {
            if let board = store.current { boardView(board) } else { setup }
        }
        .navigationTitle("점수판")
        .navigationBarTitleDisplayMode(.inline)
        // 아래로 쓸어 닫히면 벤치에서 실수하기 쉽다. 닫기는 버튼으로만(닫아도 경기는 이어진다).
        .interactiveDismissDisabled(store.current != nil)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            if store.current != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("이 경기 버리기", role: .destructive) { confirmingDiscard = true }
                    } label: { AppIcon("ellipsis.circle") }
                    .accessibilityLabel("더 보기")
                }
            }
        }
        .onAppear(perform: prefill)
        // 경기 중 화면이 꺼지지 않게. 나가면 원래대로.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; OrientationDelegate.set(landscape: false) }
        // 경기가 시작되면 가로로 돌린다(세로로 들어도 된다). 시작 전 입력은 키보드 때문에 세로.
        .onChange(of: store.current == nil, initial: true) { _, idle in OrientationDelegate.set(landscape: !idle) }
        .confirmationDialog("누가 넣었어요?", isPresented: $askingCredit, titleVisibility: .visible) {
            Button("내가 넣었어요") { store.change { $0.creditLastGoal(.myGoal) } }
            Button("내가 어시했어요") { store.change { $0.creditLastGoal(.myAssist) } }
            Button("다른 사람", role: .cancel) {}
        }
        .confirmationDialog("경기를 끝내고 기록할까요?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("끝내고 기록하기") { finish() }
            Button("계속하기", role: .cancel) {}
        }
        .confirmationDialog("이 경기 점수를 버릴까요? 기록은 남지 않아요.", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("버리기", role: .destructive) { store.finish(); dismiss() }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - 시작 전

    private var setup: some View {
        Form {
            Section {
                TextField("우리 팀", text: $teamName)
                TextField("상대 팀", text: $opponent)
                Picker("종류", selection: $kind) {
                    Text(ActivityType.regularGame.title).tag(ActivityType.regularGame)
                    Text(ActivityType.miniGame.title).tag(ActivityType.miniGame)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("점수를 누를 때마다 이 폰에 저장돼요. 화면을 닫거나 전화가 와도 이어져요. 끝내면 경기 리뷰가 채워져요.")
            }
            Section {
                Button {
                    store.start(Scoreboard(teamName: teamName.trimmingCharacters(in: .whitespaces),
                                           opponent: opponent.trimmingCharacters(in: .whitespaces),
                                           startedAt: Date(), eventID: eventID, kind: kind))
                } label: {
                    Text("경기 시작").frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(PinkButtonStyle())
                .listRowBackground(Color.clear)
            }
        }
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        if let id = eventID, let e = events.first(where: { $0.id == id }) {
            teamName = teams.first { $0.id == e.teamID }?.name ?? ""
            opponent = e.opponent
            if e.kind.isGame { kind = e.kind }
        } else if teams.count == 1 {
            teamName = teams[0].name
        }
    }

    // MARK: - 경기 중

    private func boardView(_ b: Scoreboard) -> some View {
        GeometryReader { g in
            if g.size.width > g.size.height { landscape(b) } else { portrait(b) }
        }
        .screenBackground()
    }

    /// 가로: 왼쪽 우리, 오른쪽 상대를 크게. 가운데 좁은 기둥에 피리어드·시간·내 기록·끝내기.
    private func landscape(_ b: Scoreboard) -> some View {
        HStack(spacing: 12) {
            side(.us, name: b.teamName.isEmpty ? "우리" : b.teamName, score: b.us, color: Theme.cobalt)
            VStack(spacing: 10) {
                Picker("피리어드", selection: Binding(get: { b.period }, set: { p in store.change { $0.setPeriod(p) } })) {
                    ForEach(1...Scoreboard.lastPeriod, id: \.self) { Text(Scoreboard.periodTitle($0)).tag($0) }
                }
                .pickerStyle(.menu)
                .font(.headline)
                Text(timerInterval: b.startedAt...b.startedAt.addingTimeInterval(6 * 3600), countsDown: false)
                    .font(.title3.monospacedDigit().bold()).foregroundStyle(Theme.title)
                if b.myGoals + b.myAssists > 0 {
                    Text("내 골 \(b.myGoals) · 어시 \(b.myAssists)").font(.caption.bold()).foregroundStyle(Theme.title)
                }
                Spacer(minLength: 0)
                Text("누르면 +1\n길게 누르면 −1").font(.caption2).multilineTextAlignment(.center).foregroundStyle(Theme.inkSecondary)
                Button { confirmingFinish = true } label: { Text("끝내고 기록하기").font(.subheadline.bold()) }
                    .buttonStyle(PinkButtonStyle())
            }
            .frame(width: 150)
            side(.them, name: b.opponent.isEmpty ? "상대" : b.opponent, score: b.them, color: Theme.inkSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func portrait(_ b: Scoreboard) -> some View {
        VStack(spacing: 14) {
            HStack {
                Picker("피리어드", selection: Binding(get: { b.period }, set: { p in store.change { $0.setPeriod(p) } })) {
                    ForEach(1...Scoreboard.lastPeriod, id: \.self) { Text(Scoreboard.periodTitle($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(timerInterval: b.startedAt...b.startedAt.addingTimeInterval(6 * 3600), countsDown: false)
                    .font(.subheadline.monospacedDigit().bold()).foregroundStyle(Theme.inkSecondary)
                    .frame(minWidth: 64, alignment: .trailing)
            }
            HStack(spacing: 12) {
                side(.us, name: b.teamName.isEmpty ? "우리" : b.teamName, score: b.us, color: Theme.cobalt)
                side(.them, name: b.opponent.isEmpty ? "상대" : b.opponent, score: b.them, color: Theme.inkSecondary)
            }
            .frame(maxHeight: .infinity)
            if b.myGoals + b.myAssists > 0 {
                Text("내 골 \(b.myGoals) · 내 어시 \(b.myAssists)").font(.subheadline.bold()).foregroundStyle(Theme.title)
            }
            Text("칸을 누르면 +1, 길게 누르면 하나 빼요.").font(.caption).foregroundStyle(Theme.inkSecondary)
            Button { confirmingFinish = true } label: { Text("끝내고 기록하기") }
                .buttonStyle(PinkButtonStyle())
        }
        .padding(Theme.screenPadding)
    }

    private func side(_ side: Scoreboard.Side, name: String, score: Int, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(name).font(.headline).foregroundStyle(.white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(score)").font(.system(size: 96, weight: .black, design: .rounded)).foregroundStyle(.white)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                .accessibilityIdentifier(side == .us ? "score-us" : "score-them")
            Text("+1").font(.title3.bold()).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            store.change { $0.score(side, at: Date()) }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if side == .us { askingCredit = true }
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            store.change { $0.undo(side) }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(side == .us ? "우리" : "상대") \(score)점")
        .accessibilityHint("두 번 누르면 1점 더해요")
        .accessibilityAction(named: "1점 빼기") { store.change { $0.undo(side) } }
        .accessibilityAction { store.change { $0.score(side, at: Date()) }; if side == .us { askingCredit = true } }
    }

    private func finish() {
        guard let b = store.current else { return }
        store.finish()
        // 점수판 시트를 닫고 같은 점수로 경기 리뷰를 연다(RootView가 시트를 바꿔 끼운다).
        jumper?.go(.entry(.scoreResult(b)))
    }
}
