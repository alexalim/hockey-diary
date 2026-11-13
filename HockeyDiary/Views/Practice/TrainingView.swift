import SwiftUI
import SwiftData
import HockeyCore

/// 훈련 탭. 얼음 위에서 하는 모든 것을 연습 · 경기 · 드릴 세 갈래로 나눠 시작하고 돌아본다.
/// 기록 탭은 달력·일기·컨디션(지난 것), 훈련 탭은 지금 할 것과 그 갈래의 최근 흐름이다.
struct TrainingView: View {
    @Binding var newEntry: NewEntry?

    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \TeamEvent.at) private var teamEvents: [TeamEvent]
    @Query private var teams: [Team]

    enum Branch: String, CaseIterable { case practice = "연습", game = "경기", drill = "드릴" }
    @State private var branch: Branch = .practice
    @Environment(AppJumper.self) private var jumper: AppJumper?

    /// 다른 화면의 '드릴로 가기' 같은 요청이 있으면 그 갈래를 편다.
    private func consumeBranch() {
        guard let b = jumper?.pendingBranch else { return }
        branch = b
        jumper?.pendingBranch = nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: "TRAINING STUDIO", title: "훈련", subtitle: "연습, 경기, 드릴을 한곳에서.") {
                    NavigationLink { SkillGuideListView() } label: {
                        Image(systemName: "book.pages").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.title)
                            .frame(width: 44, height: 44).background(Theme.card, in: Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityLabel("기술 도감")
                }
                Picker("갈래", selection: $branch) {
                    ForEach(Branch.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("훈련-갈래")

                switch branch {
                case .practice: PracticeBranch(sessions: sessions, newEntry: $newEntry)
                case .game: GameBranch(sessions: sessions, teams: teams, teamEvents: teamEvents, newEntry: $newEntry)
                case .drill: DrillSection()
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .onAppear { consumeBranch() }
        .onChange(of: jumper?.pendingBranch) { _, _ in consumeBranch() }
        
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

/// 연습 갈래: 수업·자유 연습을 시작하고, 이번 달 흐름과 지난 수업의 다음 목표를 본다.
struct PracticeBranch: View {
    let sessions: [Session]
    @Binding var newEntry: NewEntry?

    private var mine: [Session] { sessions.filter { $0.type == .lesson || $0.type == .freePractice } }
    private var thisMonth: [Session] { mine.filter { Calendar.current.isDate($0.startsAt, equalTo: Date(), toGranularity: .month) } }

    var body: some View {
        Card(tint: Theme.cobalt) {
            Text("PRACTICE").font(.system(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(.white.opacity(0.75))
            Text("이번 달 연습 \(thisMonth.count)회").font(.title3.bold()).foregroundStyle(.white)
            Text(thisMonth.isEmpty ? "이번 달 첫 연습을 남겨 보세요." : "\(TrainingText.hours(thisMonth.map(\.minutes).reduce(0, +))) 탔어요.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) {
                HeroButton(title: "수업 기록", systemImage: "graduationcap.fill") { newEntry = .session(.lesson) }
                HeroButton(title: "자유 연습", systemImage: "snowflake") { newEntry = .session(.freePractice) }
            }
        }
        if let goal = sessions.first(where: { !$0.nextGoal.isEmpty })?.nextGoal {
            Card {
                CardHeader(title: "다음 목표", systemImage: "target")
                Text(goal).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text("지난 수업에서 적은 목표예요. 드릴 갈래에서 이어서 다듬어 보세요.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        SectionHeader(title: "최근 연습")
        RecentSessions(sessions: Array(mine.prefix(6)), empty: "아직 연습 기록이 없어요. 위에서 수업이나 자유 연습을 남겨 보세요.")
    }
}

/// 경기 갈래: 정규게임·미니게임 리뷰를 시작하고, 다음 팀 경기와 올해 성적을 본다.
struct GameBranch: View {
    let sessions: [Session]
    let teams: [Team]
    let teamEvents: [TeamEvent]
    @Binding var newEntry: NewEntry?

    private var games: [Session] { sessions.filter { $0.type == .regularGame || $0.type == .miniGame } }
    private var thisYear: [Session] { games.filter { Calendar.current.isDate($0.startsAt, equalTo: Date(), toGranularity: .year) } }

    var body: some View {
        let goals = thisYear.compactMap(\.goals).reduce(0, +), assists = thisYear.compactMap(\.assists).reduce(0, +)
        Card(tint: Theme.cobalt) {
            Text("GAME DAY").font(.system(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(.white.opacity(0.75))
            Text("올해 경기 \(thisYear.count)회").font(.title3.bold()).foregroundStyle(.white)
            Text(thisYear.isEmpty ? "첫 경기를 리뷰하면 골과 어시스트가 보이기 시작해요." : "골 \(goals) · 어시스트 \(assists)")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) {
                HeroButton(title: "정규게임 리뷰", systemImage: "trophy.fill") { newEntry = .session(.regularGame) }
                HeroButton(title: "미니게임 리뷰", systemImage: "figure.hockey") { newEntry = .session(.miniGame) }
            }
        }
        Card {
            CardHeader(title: "다음 경기", systemImage: "calendar.badge.clock")
            if let team = teams.first, let next = teamEvents.first(where: { $0.at >= Calendar.current.startOfDay(for: Date()) }) {
                NavigationLink { TeamEventView(event: next, team: team) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.opponent.isEmpty ? next.title : "\(team.name) vs \(next.opponent)")
                                .font(.subheadline.bold()).foregroundStyle(Theme.title)
                            Text([next.at.dayTitle + " " + next.at.timeTitle, next.rinkName].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.inkTertiary)
                    }
                    .frame(minHeight: Theme.touch)
                }
                .buttonStyle(.plain)
            } else {
                EmptyHint(text: teams.isEmpty ? "팀을 만들면 다음 경기 일정과 참석 인원이 보여요." : "잡힌 경기가 없어요.", systemImage: "person.3",
                          link: teams.isEmpty ? EmptyLink("팀 만들기") { TeamView() } : nil)
            }
            NavigationLink { TeamView() } label: {
                Label("팀 일정 전체", systemImage: "person.3.fill").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
        }
        SectionHeader(title: "최근 경기")
        RecentSessions(sessions: Array(games.prefix(6)), empty: "아직 경기 기록이 없어요. 위에서 리뷰를 남겨 보세요.")
    }
}

/// 히어로 카드 안의 흰 버튼(두 개 나란히).
struct HeroButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).font(.subheadline.bold()).foregroundStyle(Theme.cobalt)
                .frame(maxWidth: .infinity, minHeight: Theme.touch)
                .background(.white, in: RoundedRectangle(cornerRadius: Theme.buttonCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 최근 기록 목록(한 갈래 분). 누르면 상세로.
struct RecentSessions: View {
    let sessions: [Session]
    let empty: String

    var body: some View {
        Card {
            if sessions.isEmpty { EmptyHint(text: empty) }
            ForEach(sessions) { s in
                NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }.buttonStyle(.plain)
            }
        }
    }
}

enum TrainingText {
    /// 분 → "1시간 30분" / "45분".
    static func hours(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)분" }
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }
}
