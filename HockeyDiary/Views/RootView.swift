import SwiftUI
import SwiftData
import HockeyCore

/// 무엇을 새로 기록할지.
enum NewEntry: Identifiable, Hashable {
    /// 날짜가 nil이면 방금 끝난 운동(시간을 미리 채운다). 달력에서 고른 날이면 그 날짜.
    case session(ActivityType, Date? = nil)
    case journal(Date)
    case practice
    /// 건강 앱에 있는데 아직 기록 안 한 운동(알림·홈 카드).
    case workout(UnloggedWorkout)

    var id: String {
        switch self {
        case .session(let t, let d): return "session-\(t.rawValue)-\(d?.timeIntervalSince1970 ?? 0)"
        case .journal(let d): return "journal-\(d.timeIntervalSince1970)"
        case .practice: return "practice"
        case .workout(let w): return "workout-\(w.id)"
        }
    }
}

/// 하단 탭 5개: 기록 · 훈련 · 홈(가운데 큰 버튼) · 성장 · 락커. 시작 화면은 홈.
/// 팀과 뭐할까는 홈에서 들어간다(홈의 바로가기, 다음 경기 카드, 훈련 > 경기의 팀 일정).
/// 훈련은 연습·경기·드릴 세 갈래. 규칙·전술·링크장은 드릴 갈래의 '하키 아카데미'에 있다. 어디서나 상단 (+)로 새 기록을 시작한다.
struct RootView: View {
    enum Tab: Hashable, CaseIterable {
        case record, practice, home, growth, locker

        var title: String {
            switch self {
            case .home: return "홈"
            case .record: return "기록"
            case .practice: return "훈련"
            case .growth: return "성장"
            case .locker: return "락커"
            }
        }

        var symbol: String {
            switch self {
            case .home: return "house.fill"
            case .record: return "calendar"
            case .practice: return "figure.hockey"
            case .growth: return "chart.bar.xaxis"
            case .locker: return "door.left.hand.closed"
            }
        }
    }

    @State private var tab: Tab = .home
    /// 지금 탭을 한 번 더 누르면 그 탭을 첫 화면으로 되돌린다(iOS 기본 탭 동작). 스택을 새로 만들어 비운다.
    @State private var resets: [Tab: Int] = [:]

    /// 안내문의 '바로 가기'. 열려 있던 기록 시트는 닫고, 시트를 다시 열어야 하면 닫히는 시간을 조금 기다린다.
    private func handle(_ jump: AppJump) {
        let hadSheet = newEntry != nil
        newEntry = nil
        let wait: TimeInterval = hadSheet ? 0.45 : 0
        switch jump {
        case .tab(let t):
            tab = t
        case .training(let b):
            tab = .practice
            jumper.pendingBranch = b
        case .entry(let e):
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { newEntry = e }
        case .homeScreen(let d):
            tab = .home
            jumper.pendingHome = d
        case .settings:
            tab = .home
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { jumper.pendingSettings = true }
        }
    }
    @State private var newEntry: NewEntry?
    @State private var showingQuickMenu = false
    @State private var jumper = AppJumper()
    @State private var nudge = WorkoutNudgeService.shared
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    /// 운동만으로는 수업인지 경기인지 모른다. 가장 최근에 적은 종류로 시작하고 사용자가 바꾼다.
    private var lastType: ActivityType { sessions.first?.type ?? .freePractice }
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // TabView(UIKit 탭 컨트롤러)는 바깥에서 건 안전영역 여백을 탭 안의 스크롤에 전해 주지 않아
        // 마지막 줄이 하단 바에 가려졌다. 그래서 TabView 대신 탭마다 스택을 겹쳐 두고 고른 것만 보여준다.
        // 숨은 스택도 살아 있어 각 탭의 스크롤 위치·밀어 들어간 화면이 유지된다(TabView와 같은 동작).
        ZStack {
            stack(.record) { DiaryView(newEntry: $newEntry) }
            stack(.practice) { TrainingView(newEntry: $newEntry) }
            stack(.home) { HomeView(newEntry: $newEntry) }
            stack(.growth) { GrowthView() }
            stack(.locker) { LockerView() }
        }
        // 바는 안전영역 삽입으로 놓되, 스크롤 내용의 아래 여백은 contentMargins로 따로 준다.
        // (iOS 26 시뮬레이터 측정: 안전영역 삽입만으로는 NavigationStack 안의 ScrollView·List 내용 여백이 늘지 않았다.)
        .safeAreaInset(edge: .bottom, spacing: 0) { MahadaTabBar(selection: $tab) { resets[$0, default: 0] += 1 } }
        .contentMargins(.bottom, MahadaTabBar.height, for: .scrollContent)
        .contentMargins(.bottom, MahadaTabBar.height, for: .scrollIndicators)
        .environment(jumper)
        .onChange(of: jumper.request) { _, r in if let r { handle(r); jumper.request = nil } }
        .task { await TeamReminder.reschedule(context); WidgetBridge.refresh(context) }
        .onChange(of: scenePhase) { _, p in if p == .active { Task { await TeamReminder.reschedule(context); await nudge.refresh() }; WidgetBridge.refresh(context) } }
        // 기록 시트를 닫으면 위젯 숫자를 바로 맞춘다.
        .onChange(of: newEntry == nil) { _, closed in if closed { WidgetBridge.refresh(context); nudge.recheck() } }
        // 기록 안 된 운동 알림을 누르면 그 운동으로 기록 화면을 연다.
        .onChange(of: nudge.opened) { _, w in
            guard let w else { return }
            nudge.opened = nil
            jumper.request = .entry(.workout(w))
        }
        .task { await nudge.refresh() }
        .confirmationDialog("무엇을 기록할까요?", isPresented: $showingQuickMenu, titleVisibility: .visible) {
            Button("수업 기록") { newEntry = .session(.lesson) }
            Button("자유 연습") { newEntry = .session(.freePractice) }
            Button("정규게임 리뷰") { newEntry = .session(.regularGame) }
            Button("미니게임 리뷰") { newEntry = .session(.miniGame) }
            Button("드릴 시작") { newEntry = .practice }
            Button("하루 일기") { newEntry = .journal(Date()) }
        }
        .sheet(item: $newEntry) { entry in
            switch entry {
            case .session(let type, let date):
                NavigationStack { SessionEditorView(newType: type, startsAt: date ?? Date(), fromNow: date == nil) }
            case .journal(let date):
                NavigationStack { JournalEditorView(newDate: date) }
            case .workout(let w):
                NavigationStack { SessionEditorView(newType: lastType, startsAt: w.start, workout: w) }
            case .practice:
                NavigationStack {
                    PracticeView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { newEntry = nil } } }
                }
            }
        }
    }

    /// 탭 하나의 화면 스택. 고르지 않은 탭은 보이지도, 눌리지도, 접근성에 잡히지도 않는다.
    private func stack<Content: View>(_ t: Tab, @ViewBuilder content: () -> Content) -> some View {
        let on = tab == t
        return NavigationStack { content().toolbar { plusButton } }
            .id(resets[t, default: 0])
            .opacity(on ? 1 : 0)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }

    @ToolbarContentBuilder
    private var plusButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingQuickMenu = true
            } label: {
                AppIcon("plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.neonPink)
            }
            .accessibilityLabel("새 기록")
        }
    }
}

/// 직접 그린 하단 바. 가운데 홈은 크고 솟은 원형 버튼.
struct MahadaTabBar: View {
    @Binding var selection: RootView.Tab
    /// 이미 고른 탭을 다시 눌렀을 때.
    var onReselect: (RootView.Tab) -> Void = { _ in }

    private func pick(_ t: RootView.Tab) {
        if selection == t { onReselect(t) } else { selection = t }
    }

    /// 홈 원이 제자리에서 위로 올라가는 거리.
    static let raise: CGFloat = 14
    /// 바 위에 두는 투명한 띠. 솟은 원과 그 그림자가 여기 들어가므로 화면 내용이 원 뒤에 가려지지 않는다.
    /// (예전엔 raise와 같았고 홈 칸 높이도 50으로 잡아, 실제 바보다 24pt 짧은 여백이 나와 맨 아래 글이 원에 가렸다. 2026-11-20)
    static let overhang: CGFloat = raise + 8
    private static let itemHeight: CGFloat = 50
    /// 홈 칸은 원(58) + 글자라 다른 칸보다 크다. 바 높이 계산이 어긋나지 않게 고정한다.
    private static let homeHeight: CGFloat = 74
    private static let padTop: CGFloat = 6
    private static let padBottom: CGFloat = 4
    /// 기기 아래 안전영역을 뺀 바 전체 높이. 각 탭 내용은 이만큼 아래 여백을 둔다.
    static let height: CGFloat = overhang + padTop + homeHeight + padBottom

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Self.overhang)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(RootView.Tab.allCases, id: \.self) { t in
                    if t == .home { homeButton } else { item(t) }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, Self.padTop)
            .padding(.bottom, Self.padBottom)
            .background(.bar, ignoresSafeAreaEdges: .bottom)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private func item(_ t: RootView.Tab) -> some View {
        let on = selection == t
        return Button {
            pick(t)
        } label: {
            VStack(spacing: 3) {
                AppIcon(t.symbol, size: 23)
                Text(t.title).font(.system(size: 11.5, weight: on ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Theme.accent : Theme.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: Self.itemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(t.title)")
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// 가운데 홈: 위로 솟은 원. 선택되면 코발트 채움, 아니면 테두리.
    private var homeButton: some View {
        let on = selection == .home
        return Button {
            pick(.home)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle().fill(on ? Theme.cobalt : Theme.card)
                        .overlay(Circle().stroke(Theme.cobalt, lineWidth: on ? 0 : 2))
                        .shadow(color: Theme.cobalt.opacity(on ? 0.35 : 0.15), radius: 10, y: 4)
                    AppIcon("house.fill", size: 28)
                        .foregroundStyle(on ? .white : Theme.accent)
                }
                .frame(width: 58, height: 58)
                .offset(y: -Self.raise)
                Text("홈").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSecondary)
                    .offset(y: -12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.homeHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-홈")
        .accessibilityLabel("홈")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
