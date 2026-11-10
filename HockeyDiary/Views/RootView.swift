import SwiftUI
import HockeyCore

/// 무엇을 새로 기록할지.
enum NewEntry: Identifiable, Hashable {
    case session(ActivityType, Date = Date())
    case journal(Date)
    case practice

    var id: String {
        switch self {
        case .session(let t, let d): return "session-\(t.rawValue)-\(d.timeIntervalSince1970)"
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

    var body: some View {
        // 기본 탭 바는 숨기고 MahadaTabBar를 겹쳐 그린다(가운데 홈을 크게 만들기 위해).
        // TabView에 safeAreaInset을 걸면 탭 안의 스크롤까지 전달되지 않아 마지막 줄이 바에 가려졌다.
        // 그래서 탭마다 바 높이만큼 안전영역을 직접 넓힌다.
        TabView(selection: $tab) {
            NavigationStack { DiaryView(newEntry: $newEntry).toolbar { plusButton }.toolbar(.hidden, for: .tabBar) }
                .safeAreaPadding(.bottom, MahadaTabBar.height)
                .tag(Tab.diary)
            NavigationStack { GrowthView().toolbar { plusButton }.toolbar(.hidden, for: .tabBar) }
                .safeAreaPadding(.bottom, MahadaTabBar.height)
                .tag(Tab.growth)
            NavigationStack { HomeView(newEntry: $newEntry).toolbar { plusButton }.toolbar(.hidden, for: .tabBar) }
                .safeAreaPadding(.bottom, MahadaTabBar.height)
                .tag(Tab.home)
            NavigationStack { ExploreView().toolbar { plusButton }.toolbar(.hidden, for: .tabBar) }
                .safeAreaPadding(.bottom, MahadaTabBar.height)
                .tag(Tab.explore)
            NavigationStack { LockerView().toolbar { plusButton }.toolbar(.hidden, for: .tabBar) }
                .safeAreaPadding(.bottom, MahadaTabBar.height)
                .tag(Tab.locker)
        }
        .overlay(alignment: .bottom) { MahadaTabBar(selection: $tab) }
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
                NavigationStack { SessionEditorView(newType: type, startsAt: date) }
            case .journal(let date):
                NavigationStack { JournalEditorView(newDate: date) }
            case .practice:
                NavigationStack {
                    PracticeView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { newEntry = nil } } }
                }
            }
        }
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
