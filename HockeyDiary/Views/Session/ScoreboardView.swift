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
    /// 가로로 보기. iOS 회전을 쓰지 않고 점수판만 90도 돌려 그린다(회전을 쓰면 화면이 반만 그려졌다, 빌드 83~85).
    /// 기본은 가로(벤치에서 옆으로 들고 보는 점수판). '세로로'를 누르면 그 선택을 기억한다.
    @AppStorage("scoreboard.landscape") private var landscape = true
    @State private var confirmingFinish = false
    @State private var confirmingDiscard = false

    var body: some View {
        Group {
            if let board = store.current { boardView(board) } else { setup }
        }
        .navigationTitle("점수판")
        .navigationBarTitleDisplayMode(.inline)
        // 가로로 볼 때는 위 막대(닫기·제목)가 세로 방향에 남아 헷갈리므로 숨기고, 돌린 화면 안에 닫기를 둔다.
        .toolbar(store.current != nil && landscape ? .hidden : .visible, for: .navigationBar)
        // 아래로 쓸어 닫히면 벤치에서 실수하기 쉽다. 닫기는 버튼으로만(닫아도 경기는 이어진다).
        .interactiveDismissDisabled(store.current != nil)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            if store.current != nil {
                // 메뉴 안에 숨기지 않고 폰 돌리기 아이콘으로 바로 보인다.
                ToolbarItem(placement: .primaryAction) {
                    Button { withAnimation { landscape = true } } label: { AppIcon("rectangle.landscape.rotate") }
                        .accessibilityLabel("가로로 보기")
                }
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
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("경기를 끝내고 기록할까요?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            // 아래 버튼과 이름이 같으면 무엇을 눌렀는지 헷갈린다(시험도 아래 버튼을 다시 눌렀다).
            Button("네, 끝내기") { finish() }
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
        Group {
            if landscape {
                // 화면은 세로 그대로 두고 내용만 시계 방향으로 90도 돌린다. 폰을 왼쪽으로 눕혀(위가 왼쪽) 본다.
                GeometryReader { g in
                    landscapeContent(b)
                        .frame(width: g.size.height, height: g.size.width)
                        .rotationEffect(.degrees(90))
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
                .ignoresSafeArea()
            } else {
                portrait(b)
            }
        }
        .screenBackground()
    }

    /// 가로: 왼쪽 우리, 오른쪽 상대를 크게. 가운데 좁은 기둥에 피리어드·시간·내 기록·끝내기·닫기.
    private func landscapeContent(_ b: Scoreboard) -> some View {
        HStack(spacing: 12) {
            side(.us, name: b.teamName.isEmpty ? "우리" : b.teamName, score: b.us, color: Theme.cobalt)
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Button { dismiss() } label: { Text("닫기").font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 36) }
                        .buttonStyle(.bordered)
                    Button { withAnimation { landscape = false } } label: {
                        AppIcon("rectangle.portrait.rotate").font(.title3).frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("세로로")
                }
                Picker("피리어드", selection: Binding(get: { b.period }, set: { p in store.change { $0.setPeriod(p) } })) {
                    ForEach(1...Scoreboard.lastPeriod, id: \.self) { Text(Scoreboard.periodTitle($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(timerInterval: b.startedAt...b.startedAt.addingTimeInterval(6 * 3600), countsDown: false)
                    .font(.title2.monospacedDigit().bold()).foregroundStyle(Theme.title)
                if askingCredit {
                    Text("방금 우리 골, 누가?").font(.caption.bold()).foregroundStyle(Theme.title)
                    creditButton("내가 넣음", .myGoal)
                    creditButton("내 어시", .myAssist)
                    creditButton("다른 사람", .other)
                } else {
                    if b.myGoals + b.myAssists > 0 {
                        Text("내 골 \(b.myGoals) · 어시 \(b.myAssists)").font(.subheadline.bold()).foregroundStyle(Theme.title)
                    }
                    Text("누르면 +1 · 길게 누르면 −1").font(.caption2).foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                Button { confirmingFinish = true } label: { Text("끝내고 기록하기").font(.subheadline.bold()) }
                    .buttonStyle(PinkButtonStyle())
            }
            .frame(width: 220)
            side(.them, name: b.opponent.isEmpty ? "상대" : b.opponent, score: b.them, color: Theme.inkSecondary)
        }
        // 돌린 뒤 위(=폰의 왼쪽 끝)에는 다이내믹 아일랜드, 아래(=오른쪽 끝)에는 홈 막대가 온다. 그만큼 비운다.
        .padding(.horizontal, 56)
        .padding(.vertical, 20)
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
            if askingCredit {
                creditBar
            } else {
                if b.myGoals + b.myAssists > 0 {
                    Text("내 골 \(b.myGoals) · 내 어시 \(b.myAssists)").font(.subheadline.bold()).foregroundStyle(Theme.title)
                }
                Text("칸을 누르면 +1, 길게 누르면 하나 빼요.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Button { confirmingFinish = true } label: { Text("끝내고 기록하기") }
                .buttonStyle(PinkButtonStyle())
        }
        .padding(Theme.screenPadding)
    }

    /// 방금 들어간 우리 골에 누가 넣었는지. 화면을 덮는 창이면 그동안 상대 칸을 눌러도 창만 닫혀 점수가 사라졌다.
    /// 그래서 점수판 아래 한 줄로 두고, 안 고르고 계속 눌러도 된다(다음 우리 골이면 그 골을 다시 묻는다).
    private var creditBar: some View {
        VStack(spacing: 6) {
            Text("방금 우리 골, 누가 넣었어요?").font(.caption.bold()).foregroundStyle(Theme.title)
            HStack(spacing: 8) {
                creditButton("내가 넣음", .myGoal)
                creditButton("내 어시", .myAssist)
                creditButton("다른 사람", .other)
            }
        }
        .transition(.opacity)
    }

    private func creditButton(_ title: String, _ credit: Scoreboard.Credit) -> some View {
        Button {
            store.change { $0.creditLastGoal(credit) }
            withAnimation { askingCredit = false }
        } label: {
            Text(title).font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(credit == .other ? Theme.title : .white)
                .background(credit == .other ? Theme.cobaltSoft : Theme.cobalt, in: Capsule())
        }
        .buttonStyle(.plain)
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
            if side == .us { askingCredit = false }
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
