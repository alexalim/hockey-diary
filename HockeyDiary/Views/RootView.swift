import SwiftUI
import HockeyCore

/// 무엇을 새로 기록할지.
enum NewEntry: Identifiable, Hashable {
    /// 날짜가 nil이면 방금 끝난 운동(시간을 미리 채운다). 달력에서 고른 날이면 그 날짜.
    case session(ActivityType, Date? = nil)
    case journal(Date)
    case practice

    var id: String {
        switch self {
        case .session(let t, let d): return "session-\(t.rawValue)-\(d?.timeIntervalSince1970 ?? 0)"
        case .journal(let d): return "journal-\(d.timeIntervalSince1970)"
        case .practice: return "practice"
        }
    }
}

/// 하단 탭 5개 (3.1). 홈이 가운데 큰 버튼이고 시작 화면도 홈이다. 어디서나 상단 (+)로 새 기록을 시작한다 (3.3).
struct RootView: View {
    enum Tab: Hashable, CaseIterable {
        case diary, growth, home, explore, locker

        var title: String {
            switch self {
            case .home: return "홈"
            case .diary: return "다이어리"
            case .growth: return "성장"
            case .explore: return "룰"
            case .locker: return "락커"
            }
        }

        var symbol: String {
            switch self {
            case .home: return "house.fill"
            case .diary: return "calendar"
            case .growth: return "chart.line.uptrend.xyaxis"
            case .explore: return "book.closed.fill"
            case .locker: return "door.left.hand.closed"
            }
        }
    }

    @State private var tab: Tab = .home
    @State private var newEntry: NewEntry?
    @State private var showingQuickMenu = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // TabView(UIKit 탭 컨트롤러)는 바깥에서 건 안전영역 여백을 탭 안의 스크롤에 전해 주지 않아
        // 마지막 줄이 하단 바에 가려졌다. 그래서 TabView 대신 다섯 스택을 겹쳐 두고 고른 것만 보여준다.
        // 숨은 스택도 살아 있어 각 탭의 스크롤 위치·밀어 들어간 화면이 유지된다(TabView와 같은 동작).
        ZStack {
            stack(.diary) { DiaryView(newEntry: $newEntry) }
            stack(.growth) { GrowthView() }
            stack(.home) { HomeView(newEntry: $newEntry) }
            stack(.explore) { ExploreView() }
            stack(.locker) { LockerView() }
        }
        // 바는 안전영역 삽입으로 놓되, 스크롤 내용의 아래 여백은 contentMargins로 따로 준다.
        // (iOS 26 시뮬레이터 측정: 안전영역 삽입만으로는 NavigationStack 안의 ScrollView·List 내용 여백이 늘지 않았다.)
        .safeAreaInset(edge: .bottom, spacing: 0) { MahadaTabBar(selection: $tab) }
        .contentMargins(.bottom, MahadaTabBar.height, for: .scrollContent)
        .contentMargins(.bottom, MahadaTabBar.height, for: .scrollIndicators)
        .task { await TeamReminder.reschedule(context) }
        .onChange(of: scenePhase) { _, p in if p == .active { Task { await TeamReminder.reschedule(context) } } }
        .confirmationDialog("무엇을 기록할까?", isPresented: $showingQuickMenu, titleVisibility: .visible) {
            Button("수업 기록") { newEntry = .session(.lesson) }
            Button("미니게임 리뷰") { newEntry = .session(.miniGame) }
            Button("정규게임 리뷰") { newEntry = .session(.regularGame) }
            Button("자유 연습") { newEntry = .session(.freePractice) }
            Button("하루 일기") { newEntry = .journal(Date()) }
            Button("연습 드릴") { newEntry = .practice }
        }
        .sheet(item: $newEntry) { entry in
            switch entry {
            case .session(let type, let date):
                NavigationStack { SessionEditorView(newType: type, startsAt: date ?? Date(), fromNow: date == nil) }
            case .journal(let date):
                NavigationStack { JournalEditorView(newDate: date) }
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
                Image(systemName: "plus.circle.fill")
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

    /// 홈 원이 바 위로 솟은 높이. 이만큼 투명한 띠를 두어 화면 내용이 원 뒤에 가려지지 않게 한다.
    static let raise: CGFloat = 14
    private static let itemHeight: CGFloat = 50
    private static let padTop: CGFloat = 6
    private static let padBottom: CGFloat = 4
    /// 기기 아래 안전영역을 뺀 바 전체 높이. 각 탭 내용은 이만큼 아래 여백을 둔다.
    static let height: CGFloat = raise + padTop + itemHeight + padBottom

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Self.raise)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(RootView.Tab.allCases, id: \.self) { t in
                    if t == .home { homeButton } else { item(t) }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, Self.padTop)
            .padding(.bottom, Self.padBottom)
            .background(.bar, ignoresSafeAreaEdges: .bottom)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private func item(_ t: RootView.Tab) -> some View {
        let on = selection == t
        return Button {
            selection = t
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.symbol).font(.system(size: 21, weight: on ? .semibold : .regular))
                Text(t.title).font(.system(size: 10, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Theme.accent : Color.secondary)
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
            selection = .home
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle().fill(on ? Theme.cobalt : Theme.card)
                        .overlay(Circle().stroke(Theme.cobalt, lineWidth: on ? 0 : 2))
                        .shadow(color: Theme.cobalt.opacity(on ? 0.35 : 0.15), radius: 10, y: 4)
                    Image(systemName: "house.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(on ? .white : Theme.accent)
                }
                .frame(width: 62, height: 62)
                .offset(y: -Self.raise)
                Text("홈").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(on ? Theme.accent : Color.secondary)
                    .offset(y: -12)
            }
            .frame(maxWidth: .infinity, minHeight: Self.itemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-홈")
        .accessibilityLabel("홈")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
