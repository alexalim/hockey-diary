import SwiftUI
import HockeyCore

/// 무엇을 새로 기록할지.
enum NewEntry: Identifiable, Hashable {
    case session(ActivityType, Date = Date())
    case journal(Date)

    var id: String {
        switch self {
        case .session(let t, let d): return "session-\(t.rawValue)-\(d.timeIntervalSince1970)"
        case .journal(let d): return "journal-\(d.timeIntervalSince1970)"
        }
    }
}

/// 하단 탭 5개 (3.1). 어디서나 상단 (+)로 새 기록을 시작한다 (3.3).
struct RootView: View {
    enum Tab: Hashable { case home, diary, growth, explore, locker }

    @State private var tab: Tab = .home
    @State private var newEntry: NewEntry?
    @State private var showingQuickMenu = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(newEntry: $newEntry).toolbar { plusButton } }
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(Tab.home)
            NavigationStack { DiaryView(newEntry: $newEntry).toolbar { plusButton } }
                .tabItem { Label("다이어리", systemImage: "calendar") }
                .tag(Tab.diary)
            NavigationStack { GrowthView().toolbar { plusButton } }
                .tabItem { Label("성장", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.growth)
            NavigationStack { ExploreView().toolbar { plusButton } }
                .tabItem { Label("룰", systemImage: "book.closed.fill") }
                .tag(Tab.explore)
            NavigationStack { LockerView().toolbar { plusButton } }
                .tabItem { Label("락커", systemImage: "door.left.hand.closed") }
                .tag(Tab.locker)
        }
        .confirmationDialog("무엇을 기록할까?", isPresented: $showingQuickMenu, titleVisibility: .visible) {
            Button("수업 기록") { newEntry = .session(.lesson) }
            Button("미니게임 리뷰") { newEntry = .session(.miniGame) }
            Button("정규게임 리뷰") { newEntry = .session(.regularGame) }
            Button("자유 연습") { newEntry = .session(.freePractice) }
            Button("하루 일기") { newEntry = .journal(Date()) }
        }
        .sheet(item: $newEntry) { entry in
            switch entry {
            case .session(let type, let date):
                NavigationStack { SessionEditorView(newType: type, startsAt: date) }
            case .journal(let date):
                NavigationStack { JournalEditorView(newDate: date) }
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
