import SwiftUI
import SwiftData
import HockeyCore

/// 홈 (S01). 오늘 카드, 빠른 기록, 다음 목표, 최근 피드백, 연마 점검.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Binding var newEntry: NewEntry?

    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \DailyJournal.entryDate, order: .reverse) private var journals: [DailyJournal]
    @Query(sort: \RunnerSet.createdAt) private var runners: [RunnerSet]
    @Query private var skates: [Skate]
    @Query(sort: \TeamEvent.at) private var teamEvents: [TeamEvent]
    @Query private var teams: [Team]

    @State private var showingSettings = false
    @State private var showingEdit = false
    @AppStorage(RestPrefs.key) private var restJSON = "[]"
    @AppStorage("homeBlocks") private var orderRaw = HomeBlock.defaultOrder
    @AppStorage("homeHidden") private var hiddenRaw = ""

    private var resting: Bool { RestPrefs.isResting(restJSON) }
    private var visibleBlocks: [HomeBlock] {
        let hidden = Set(hiddenRaw.split(separator: ",").map(String.init))
        return HomeBlock.order(orderRaw).filter { !hidden.contains($0.rawValue) }
    }
    private var health = StoreHealth.shared

    init(newEntry: Binding<NewEntry?>) {
        _newEntry = newEntry
    }

    private var todaySessions: [Session] { sessions.filter { Calendar.current.isDateInToday($0.startsAt) } }
    private var todayJournal: DailyJournal? { journals.first { Calendar.current.isDateInToday($0.entryDate) } }
    private var lastWithGoal: Session? { sessions.first { !$0.nextGoal.isEmpty } }
    private var lastLesson: Session? { sessions.first { $0.type == .lesson } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if health.openFailed || health.lastSaveFailed { storeWarning }
                promptCard
                todayCard
                quickButtons
                ForEach(visibleBlocks) { b in block(b) }
                Button { showingEdit = true } label: {
                    Label("홈 꾸미기", systemImage: "slider.horizontal.3").font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.accent)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("오늘의 하키")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("설정")
            }
        }
        .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $showingEdit) { NavigationStack { HomeEditView() } }
    }

    @ViewBuilder
    private func block(_ b: HomeBlock) -> some View {
        switch b {
        case .goal: goalCard
        case .feedback: feedbackCard
        case .sharpening: sharpeningCard
        case .team: teamCard
        case .recent: recentCard
        }
    }

    // MARK: - 지금 할 일 하나 (시간대·오늘 상태로 고른다)

    private var prompt: HomePrompt? {
        HomePrompt.pick(now: Date(), resting: resting,
                        events: teamEvents.map { .init(title: $0.title, start: $0.at, minutes: $0.minutes, logged: $0.sessionID != nil) },
                        loggedToday: !todaySessions.isEmpty, journaledToday: todayJournal != nil,
                        goal: lastWithGoal?.nextGoal)
    }

    @ViewBuilder
    private var promptCard: some View {
        if let p = prompt {
            Card(tint: p == .resting ? Theme.iceBlue : Theme.neonPink.opacity(0.12)) {
                switch p {
                case .resting:
                    Label("쉬는 중이야", systemImage: "moon.zzz.fill").font(.headline).foregroundStyle(Theme.title)
                    Text("연속 기록과 목표는 그대로 둘게. 돌아오면 이어서 세.").font(.subheadline).foregroundStyle(.secondary)
                    Button("다시 탈래") { restJSON = RestPrefs.toggled(restJSON) }.buttonStyle(.bordered)
                case .logEvent(let title):
                    Label("\(title) 끝났지? 바로 남기자", systemImage: "pencil.and.list.clipboard").font(.headline).foregroundStyle(Theme.title)
                    Text("시간이랑 장소는 팀 일정으로 채워둘게.").font(.subheadline).foregroundStyle(.secondary)
                    Button {
                        let kind = teamEvents.first { $0.title == title && $0.sessionID == nil }.flatMap { ActivityType(rawValue: $0.kindRaw) } ?? .regularGame
                        newEntry = .session(kind)
                    } label: { Text("기록하기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                    .buttonStyle(PinkButtonStyle())
                case .beforeEvent(let title, let at):
                    Label("오늘 \(at.formatted(date: .omitted, time: .shortened)) \(title)", systemImage: "calendar.badge.clock").font(.headline).foregroundStyle(Theme.title)
                    if let g = lastWithGoal?.nextGoal, !g.isEmpty {
                        Text("오늘 목표: \(g)").font(.subheadline).foregroundStyle(Theme.title)
                    } else {
                        Text("오늘 해볼 거 하나 정해두면 좋아.").font(.subheadline).foregroundStyle(.secondary)
                    }
                case .morningGoal(let goal):
                    Label("오늘 해볼 거", systemImage: "target").font(.headline).foregroundStyle(Theme.title)
                    Text(goal).font(.subheadline).foregroundStyle(Theme.title)
                case .eveningJournal:
                    Label("오늘 어땠어?", systemImage: "book.fill").font(.headline).foregroundStyle(Theme.title)
                    Text("한 줄이면 돼. 내일의 나한테 남기는 거야.").font(.subheadline).foregroundStyle(.secondary)
                    Button { newEntry = .journal(Date()) } label: { Text("일기 쓰기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                        .buttonStyle(PinkButtonStyle())
                }
            }
        }
    }

    // MARK: - 오늘 카드의 원 3개

    private var weekCount: Int {
        var cal = Calendar.current; cal.firstWeekday = 2
        guard let w = cal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return sessions.filter { w.contains($0.startsAt) }.count
    }

    private var todayMood: Int? { todaySessions.compactMap(\.moodAfter).first ?? todayJournal?.mood }

    private var rings: some View {
        HStack(spacing: 4) {
            HomeRing(value: todaySessions.isEmpty ? 0 : 1, center: "\(todaySessions.count)", label: "오늘 기록", color: Theme.neonPink)
            HomeRing(value: Double(weekCount) / 2, center: "\(weekCount)/2", label: "이번 주", color: Color(hex: 0x4CC38A))
            HomeRing(value: Double(todayMood ?? 0) / 5, center: todayMood.map(Mood.face) ?? "–", label: "컨디션", color: Color(hex: 0xFFC04D))
        }
        .padding(.top, 4)
    }

    private var storeWarning: some View {
        Card(tint: Theme.dangerSoft) {
            Label(health.openFailed ? "기록을 불러오지 못했어. 지금 쓰는 건 앱을 끄면 사라져. 앱을 다시 켜봐."
                                    : "방금 기록을 저장하지 못했어. 한 번 더 저장해줘.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.title)
        }
    }

    private var todayCard: some View {
        Card(tint: Theme.cobalt) {
            Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            if todaySessions.isEmpty && todayJournal == nil {
                Text("오늘은 아직 기록이 없어.").font(.title3.bold()).foregroundStyle(.white)
                Text("수업 끝나고 10분 안에 남겨봐. 잊어버리기 전에.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            } else {
                Text(todaySessions.isEmpty ? "오늘은 하키 기록이 없어 · 일기 1개" : "오늘 하키 \(todaySessions.count)번\(todayJournal == nil ? "" : " · 일기 1개")")
                    .font(.title3.bold()).foregroundStyle(.white)
                ForEach(todaySessions) { s in
                    NavigationLink { SessionDetailView(session: s) } label: {
                        HStack {
                            Image(systemName: s.type.systemImage)
                            Text("\(s.startsAt.timeTitle) \(s.title)")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .foregroundStyle(.white)
                        .frame(minHeight: 32)
                    }
                }
            }
            rings
            Text("이번 주는 두 번 타면 원이 다 차.").font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var quickButtons: some View {
        HStack(spacing: 8) {
            quick("수업 기록", "graduationcap.fill") { newEntry = .session(.lesson) }
            quick("경기 리뷰", "figure.hockey") { newEntry = .session(.miniGame) }
            quick("하루 일기", "book.fill") {
                if let todayJournal {
                    editingJournal = todayJournal
                } else {
                    newEntry = .journal(Date())
                }
            }
        }
        .sheet(item: $editingJournal) { j in NavigationStack { JournalEditorView(journal: j) } }
    }

    @State private var editingJournal: DailyJournal?

    private func quick(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .foregroundStyle(Theme.title)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.cobaltSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var goalCard: some View {
        // 맨 위 안내 카드가 이미 목표를 보여주면 아래 목표 카드는 숨긴다(같은 말 두 번).
        let promptShowsGoal: Bool = {
            switch prompt { case .morningGoal?, .beforeEvent?: return true; default: return false }
        }()
        if let s = lastWithGoal, !resting, !promptShowsGoal {
            Card {
                CardHeader(title: "다음 목표", systemImage: "target", trailing: s.startsAt.dayTitle)
                Text(s.nextGoal).font(.body).foregroundStyle(Theme.title)
                Button { restJSON = RestPrefs.toggled(restJSON) } label: {
                    Label("한동안 쉬어 (비시즌·부상)", systemImage: "moon.zzz").font(.caption)
                }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var feedbackCard: some View {
        if let lesson = lastLesson, !(lesson.coachNotes.isEmpty && lesson.learnings.allSatisfy { $0.feedback.isEmpty }) {
            Card {
                CardHeader(title: "최근 피드백", systemImage: "quote.bubble", trailing: lesson.startsAt.dayTitle)
                if !lesson.coachNotes.isEmpty { Text(lesson.coachNotes).font(.subheadline) }
                ForEach(lesson.learnings.filter { !$0.feedback.isEmpty }) { l in
                    Text("• \(l.skill?.name ?? ""): \(l.feedback)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var sharpeningCard: some View {
        let due = runners.filter { $0.retiredAt == nil && DiaryStore.needsCheck($0, context: context) }
        let worn = runners.filter(\.needsReplacement)
        if skates.isEmpty {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "장비 점검", systemImage: "shoeprints.fill")
                Text("락커에 스케이트를 넣으면 연마하고 얼마나 탔는지 세어줄게.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } else if !due.isEmpty || !worn.isEmpty {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "연마 점검해볼까?", systemImage: "wrench.and.screwdriver.fill")
                ForEach(worn) { r in
                    Text("러너 \(r.name): \(r.lifeSummary). 날 교체를 생각해볼 때야.").font(.subheadline)
                }
                ForEach(due) { r in
                    Text("러너 \(r.name): \(DiaryStore.sharpeningSummary(r, context: context)). 정해둔 만큼 탔어.")
                        .font(.subheadline)
                }
                Text("엣지가 밀리지 않으면 더 타도 돼. 기준은 락커에서 바꿀 수 있어.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// 우리 팀: 다음 일정 하나. 팀이 없으면 만들기 안내.
    @ViewBuilder
    private var teamCard: some View {
        let next = teamEvents.first { $0.at >= Calendar.current.startOfDay(for: Date()) }
        NavigationLink { TeamView() } label: {
            Card {
                CardHeader(title: teams.first?.name ?? "우리 팀", systemImage: "person.3.fill",
                           trailing: next.map { $0.at.formatted(.dateTime.month().day().weekday(.abbreviated)) })
                if let next {
                    Text("\(next.title) · \(next.at.formatted(.dateTime.hour().minute()))\(next.rinkName.isEmpty ? "" : " · \(next.rinkName)")")
                        .font(.subheadline).foregroundStyle(Theme.title)
                } else if teams.isEmpty {
                    Text("팀 일정·참석·라인업을 정리하고 카톡에 올려봐.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("다음 일정이 없어. 하나 넣어볼까?").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recentCard: some View {
        let recent = sessions.filter { !Calendar.current.isDateInToday($0.startsAt) }.prefix(5)
        if !recent.isEmpty {
            Card {
                CardHeader(title: "최근 기록", systemImage: "clock.arrow.circlepath")
                ForEach(Array(recent)) { s in
                    NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 설정 (홈 아바타). 개인정보 원칙과 앱 정보.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RestPrefs.key) private var restJSON = "[]"
    @AppStorage(TeamReminder.enabledKey) private var teamReminder = false
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section("내 기록은 어디에 있어?") {
                Label("기록은 모두 이 아이폰에만 저장돼.", systemImage: "iphone")
                Label("서버나 iCloud로 안 보내. 링크장 검색어만 Apple 지도로 가.", systemImage: "icloud.slash")
                Label("Apple 건강은 연결했을 때만 읽어. 읽은 값은 따로 저장하지 않아.", systemImage: "heart.text.square")
                Label("AI 요약은 켰을 때만 써. 아이폰 안에서 하키 기록만 봐.", systemImage: "sparkles")
                Label("Apple Watch로 잰 운동은 건강 앱에도 저장돼.", systemImage: "applewatch")
                Label("일기는 '리포트 공유'를 켠 것만 시즌 리포트에 한 줄 들어가. 내용을 따로 분석하지 않아.", systemImage: "lock.fill")
                Label("사진은 고른 것만 복사해 둬. 위치 정보는 지워.", systemImage: "photo")
            }
            Section("연결") {
                NavigationLink { HealthConnectView() } label: { Label("Apple 건강", systemImage: "heart.text.square.fill") }
            }
            Section {
                Toggle(isOn: Binding(get: { RestPrefs.isResting(restJSON) }, set: { _ in restJSON = RestPrefs.toggled(restJSON) })) {
                    Label("쉬는 중", systemImage: "moon.zzz.fill")
                }
                Toggle(isOn: Binding(get: { teamReminder }, set: { on in
                    Task { @MainActor in
                        teamReminder = on ? await TeamReminder.requestPermission() : false
                        await TeamReminder.reschedule(context)
                    }
                })) { Label("팀 경기 이틀 전 알림", systemImage: "bell.badge") }
            } footer: {
                Text("쉬는 동안엔 주간 연속 기록이 안 끊겨. 팀 알림은 아직 참석을 안 정한 사람이 있을 때만 이 폰에서 울려.")
            }
            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
                Text("분석은 내 기록이 어땠는지만 보여줘. 의료 조언이나 실력 예측은 하지 않아.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
    }
}
