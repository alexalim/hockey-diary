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
    @Query(sort: \BodyCheck.day, order: .reverse) private var checks: [BodyCheck]

    @State private var showingSettings = false
    /// 홈에서 밀어 여는 화면(팀·뭐할까).
    @State private var homeScreen: HomeScreen?
    @AppStorage(MyPrefs.nicknameKey) private var nickname = ""
    @Environment(AppJumper.self) private var jumper: AppJumper?
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
    private var nudge = WorkoutNudgeService.shared
    @AppStorage(WorkoutNudgeService.notifyKey) private var nudgeNotify = false
    @State private var nudgeDenied = false

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
                ScreenHeader(eyebrow: Date().formatted(.dateTime.weekday(.wide).month().day()).uppercased(),
                             title: nickname.isEmpty ? "오늘도, 빙판 위에서." : "\(nickname), 오늘도 빙판 위에서.", subtitle: "작은 기록이 나의 플레이를 바꿔요.")
                    .toolbar { BarAction(icon: "gearshape.fill", label: "설정") { showingSettings = true } }
                if health.openFailed || health.lastSaveFailed { storeWarning }
                // 매일 여는 화면이라 '다음 경기 → 오늘 할 일 → 바로 기록'을 먼저 둔다. 한 번만 묻는 실력 질문은 아래로.
                // 워치·가민이 잰 하키가 아직 기록에 없으면 가장 먼저 묻는다(알림을 놓친 경우에도 보이게).
                unloggedWorkoutCard
                nextGameHero
                promptCard
                shortcutRow
                SectionHeader(title: "빠른 시작")
                quickButtons
                bodyCard
                weekCard
                levelCard
                ForEach(visibleBlocks) { b in block(b) }
                Button { showingEdit = true } label: {
                    Label("홈 꾸미기", icon: "slider.horizontal.3").font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView() } }
        .onChange(of: jumper?.pendingSettings) { _, on in if on == true { showingSettings = true; jumper?.pendingSettings = false } }
        .navigationDestination(item: $homeScreen) { d in
            switch d {
            case .team: TeamView()
            case .whatNow: WhatNowView(newEntry: $newEntry)
            }
        }
        .onChange(of: jumper?.pendingHome) { _, d in if let d { homeScreen = d; jumper?.pendingHome = nil } }
        .sheet(isPresented: $showingEdit) { NavigationStack { HomeEditView() } }
    }

    /// 팀과 뭐할까는 하단 메뉴에서 빠졌다. 홈에서 들어간다.
    private var shortcutRow: some View {
        HStack(spacing: 10) {
            shortcut("팀", "person.3.fill", "일정·참석·라인업", .team)
            shortcut("뭐할까", "sparkles", "지금 할 것 추천", .whatNow)
        }
    }

    private func shortcut(_ title: String, _ icon: String, _ detail: String, _ to: HomeScreen) -> some View {
        Button { homeScreen = to } label: {
            HStack(spacing: 10) {
                AppIcon(icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                    Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                AppIcon("chevron.right").font(.caption).foregroundStyle(Theme.inkTertiary)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityIdentifier("home-\(title)")
        .accessibilityAddTraits(.isButton)
    }

    /// 실력 레벨을 아직 안 정했을 때 한 번 묻는다. 고르면 기록 입력 방식이 거기에 맞춰진다.
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @ViewBuilder
    private var levelCard: some View {
        if levelRaw.isEmpty {
            Card {
                CardHeader(title: "내 하키 실력은 어느 정도예요?", systemImage: "person.crop.circle.badge.questionmark")
                Text("레벨에 따라 입력 칸이 간단해지거나 자세해져요. 구력은 참고만 하세요. 설정에서 언제든 바꿀 수 있어요.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                HStack(spacing: 8) {
                    ForEach(PlayerLevel.allCases, id: \.rawValue) { l in
                        Button { levelRaw = l.rawValue } label: {
                            VStack(spacing: 2) {
                                Text(l.title).font(.subheadline.bold())
                                Text(l.yearsText).font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(.bordered).tint(Theme.cobalt)
                        .accessibilityLabel("실력 \(l.title)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func block(_ b: HomeBlock) -> some View {
        switch b {
        case .quest: QuestCard()
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
    private var unloggedWorkoutCard: some View {
        if let w = nudge.pending.first {
            Card(tint: Theme.neonPink.opacity(0.12)) {
                Label("\(w.activityName) 운동, 기록할까요?", icon: "applewatch.radiowaves.left.and.right")
                    .font(.headline).foregroundStyle(Theme.title)
                Text("\(w.summary)\(w.source.isEmpty ? "" : " · \(w.source)")")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                if nudge.pending.count > 1 {
                    Text("기록 안 한 운동이 \(nudge.pending.count - 1)개 더 있어요.").font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                HStack(spacing: 8) {
                    Button { newEntry = .workout(w) } label: {
                        Text("기록하기").frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(PinkButtonStyle())
                    Button("아니에요") { withAnimation { nudge.skip(w) } }
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.touch)
                }
                if nudgeDenied {
                    NotificationDeniedNote()
                } else if !nudgeNotify {
                    Button("다음부터 알림으로 받기") {
                        Task { nudgeNotify = await WorkoutNudgeService.requestPermission(); nudgeDenied = !nudgeNotify }
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("기록 안 된 운동")
        }
    }

    @ViewBuilder
    private var promptCard: some View {
        if let p = prompt {
            Card(tint: p == .resting ? Theme.iceBlue : Theme.neonPink.opacity(0.12)) {
                switch p {
                case .resting:
                    Label("쉬는 중이에요", icon: "moon.zzz.fill").font(.headline).foregroundStyle(Theme.title)
                    Text("연속 기록과 목표는 멈춰 있어요. 돌아오면 이어서 세요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    Button("다시 탈래요") { restJSON = RestPrefs.toggled(restJSON) }.buttonStyle(.bordered)
                case .logEvent(let title):
                    Label("\(title) 끝났죠? 바로 남겨요", icon: "pencil.and.list.clipboard").font(.headline).foregroundStyle(Theme.title)
                    Text("시간과 장소는 팀 일정에서 가져와 미리 채워져요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    Button {
                        let kind = teamEvents.first { $0.title == title && $0.sessionID == nil }.flatMap { ActivityType(rawValue: $0.kindRaw) } ?? .regularGame
                        newEntry = .session(kind)
                    } label: { Text("기록하기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                    .buttonStyle(PinkButtonStyle())
                case .beforeEvent(let title, let at):
                    Label("오늘 \(at.formatted(date: .omitted, time: .shortened)) \(title)", icon: "calendar.badge.clock").font(.headline).foregroundStyle(Theme.title)
                    if let g = lastWithGoal?.nextGoal, !g.isEmpty {
                        Text("오늘 목표: \(g)").font(.subheadline).foregroundStyle(Theme.title)
                    } else {
                        Text("오늘 해볼 거 하나 정해 두면 좋아요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                case .morningGoal(let goal):
                    Label("오늘 해볼 거", icon: "target").font(.headline).foregroundStyle(Theme.title)
                    Text(goal).font(.subheadline).foregroundStyle(Theme.title)
                case .eveningJournal:
                    Label("오늘 어땠어요?", icon: "book.fill").font(.headline).foregroundStyle(Theme.title)
                    Text("한 줄이면 돼요. 내일의 나한테 남기는 거예요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    Button { newEntry = .journal(Date()) } label: { Text("일기 쓰기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                        .buttonStyle(PinkButtonStyle())
                }
            }
        }
    }

    // MARK: - 오늘 몸 상태(하키 안 탄 날도)

    private var todayCheck: BodyCheck? { checks.first { Calendar.current.isDateInToday($0.day) } }

    @ViewBuilder
    private var bodyCard: some View {
        if ConditionPrefs.isOn(.body) {
            Card {
                HStack {
                    Label("오늘 몸 상태", icon: "figure.stand").font(.headline).foregroundStyle(Theme.title)
                    Spacer()
                    NavigationLink { ConditionView() } label: {
                        Text("흐름 보기").font(.caption.bold())
                    }
                }
                BodyCheckRow(value: todayCheck?.value) { v in BodyCheckStore.set(v, context: context) }
            }
        }
    }

    // MARK: - 오늘 카드의 원 3개

    private var weekCount: Int {
        var cal = Calendar.current; cal.firstWeekday = 2
        guard let w = cal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return sessions.filter { w.contains($0.startsAt) }.count
    }

    private var todayMood: Int? { todaySessions.compactMap(\.moodAfter).first ?? todayJournal?.mood ?? todayCheck?.value }

    private var rings: some View {
        HStack(spacing: 4) {
            HomeRing(value: todaySessions.isEmpty ? 0 : 1, center: "\(todaySessions.count)", label: "오늘 기록", color: Theme.neonPink)
            HomeRing(value: Double(weekCount) / 2, center: "\(weekCount)/2", label: "이번 주", color: Theme.success)
            HomeRing(value: Double(todayMood ?? 0) / 5, center: todayMood.map(Mood.label) ?? "–", label: "컨디션", color: Theme.warningFill, face: todayMood)
        }
        .padding(.top, 4)
    }

    private var storeWarning: some View {
        Card(tint: Theme.dangerSoft) {
            Label(health.openFailed ? "기록을 불러오지 못했어요. 지금 쓰는 건 앱을 끄면 사라져요. 앱을 다시 켜 보세요."
                                    : "방금 기록을 저장하지 못했어요. 한 번 더 저장해 주세요.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.title)
        }
    }

    /// 다음 경기(팀 일정) 히어로. 일정이 없으면 보이지 않는다.
    @ViewBuilder
    private var nextGameHero: some View {
        if let next = teamEvents.first(where: { $0.at >= Calendar.current.startOfDay(for: Date()) }),
           let team = teams.first(where: { $0.id == next.teamID }) {
            let members = TeamStore.members(of: team, context: context)
            let sheet = next.attendance
            let going = sheet.count(.going, among: members.map(\.id)), maybe = sheet.count(.maybe, among: members.map(\.id))
            let unanswered = members.filter { sheet[$0.id] == .unknown }.count
            NavigationLink { TeamEventView(event: next, team: team) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("NEXT GAME").font(.system(size: 11, weight: .bold)).tracking(0.6)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.18), in: Capsule())
                        Spacer()
                        Text(next.at.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated).hour().minute())).font(.caption.bold())
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    Text(next.opponent.isEmpty ? next.title : "\(team.name) vs \(next.opponent)")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    if !next.rinkName.isEmpty || !next.memo.isEmpty {
                        Label([next.rinkName, next.memo].filter { !$0.isEmpty }.joined(separator: " · "), icon: "mappin")
                            .font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                    }
                    if !members.isEmpty {
                        HStack(spacing: 6) {
                            pill("참석 \(going)명"); pill("미정 \(maybe)명"); pill("미응답 \(unanswered)명")
                        }
                    }
                    Text("경기 일정 · 출석 확인 ›").font(.subheadline.bold()).foregroundStyle(Theme.cobalt)
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                        .background(.white, in: RoundedRectangle(cornerRadius: Theme.buttonCorner, style: .continuous))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.heroGradient,
                            in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text).font(.caption2.bold()).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.16), in: Capsule())
    }

    /// 이번 주 하키: 목표 2회 대비 진행 바. 오늘 기록이 있으면 아래에 줄로 보여준다.
    private var weekCard: some View {
        let goal = 2
        return Card {
            HStack {
                Label("이번 주 하키", icon: "target").font(.headline).foregroundStyle(Theme.title)
                Spacer()
                Text("목표 \(goal)회").font(.caption.bold()).foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Theme.cobaltSoft, in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(weekCount)").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.title)
                Text("/ \(goal)회").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                Spacer()
                Text("\(min(100, weekCount * 100 / goal))% 달성").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            ProgressView(value: Double(min(weekCount, goal)), total: Double(goal)).tint(weekCount >= goal ? Theme.success : Theme.cobalt)
            Text(weekCount >= goal ? "이번 주 목표 달성! 더 타면 보너스예요." : (weekCount == goal - 1 ? "한 번만 더 타면 주간 목표 달성이에요." : "하키는 매주 꾸준히가 제일 어려워요. 한 번부터요."))
                .font(.caption).foregroundStyle(Theme.inkSecondary)
            if !todaySessions.isEmpty {
                Divider()
                ForEach(todaySessions) { s in
                    NavigationLink { SessionDetailView(session: s) } label: {
                        HStack {
                            AppIcon(s.type.systemImage).foregroundStyle(Theme.accent)
                            Text("오늘 \(s.startsAt.timeTitle) \(s.title)").font(.subheadline).foregroundStyle(Theme.title)
                            Spacer()
                            AppIcon("chevron.right").font(.caption).foregroundStyle(Theme.inkTertiary)
                        }
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var todayCard: some View {
        Card(tint: Theme.cobalt) {
            Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            if todaySessions.isEmpty && todayJournal == nil {
                Text("오늘은 아직 기록이 없어요.").font(.title3.bold()).foregroundStyle(.white)
                Text("수업 끝나고 10분 안에 남겨 보세요. 잊어버리기 전에요.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            } else {
                Text(todaySessions.isEmpty ? "오늘은 하키 기록이 없어요 · 일기 1개" : "오늘 하키 \(todaySessions.count)번\(todayJournal == nil ? "" : " · 일기 1개")")
                    .font(.title3.bold()).foregroundStyle(.white)
                ForEach(todaySessions) { s in
                    NavigationLink { SessionDetailView(session: s) } label: {
                        HStack {
                            AppIcon(s.type.systemImage)
                            Text("\(s.startsAt.timeTitle) \(s.title)")
                            Spacer()
                            AppIcon("chevron.right").font(.caption)
                        }
                        .foregroundStyle(.white)
                        .frame(minHeight: 32)
                    }
                }
            }
            rings
            Text("이번 주는 두 번 타면 원이 다 차요.").font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var quickButtons: some View {
        HStack(spacing: 8) {
            // 수업·자유 연습·게임 모두 여기서 적는다(기록 화면에서 종류를 고른다). 처음 종류는 가장 최근에 적은 것.
            QuickAction(title: "기록", systemImage: "square.and.pencil", bubble: Theme.stickers[3]) { newEntry = .session(sessions.first?.type ?? .lesson) }
            QuickAction(title: "경기 리뷰", systemImage: "trophy.fill", bubble: Theme.stickers[1]) { newEntry = .session(.regularGame) }
            QuickAction(title: "하루 일기", systemImage: "book.fill", bubble: Theme.stickers[0]) {
                if let todayJournal {
                    editingJournal = todayJournal
                } else {
                    newEntry = .journal(Date())
                }
            }
            QuickAction(title: "드릴 시작", systemImage: "bolt.fill", bubble: Theme.stickers[2]) { newEntry = .practice }
        }
        .sheet(item: $editingJournal) { j in NavigationStack { JournalEditorView(journal: j) } }
    }

    @State private var editingJournal: DailyJournal?

    private func quick(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                AppIcon(icon).font(.title2)
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
                    Label("한동안 쉬어요 (비시즌·부상)", icon: "moon.zzz").font(.caption)
                }
                .buttonStyle(.borderless).foregroundStyle(Theme.inkSecondary)
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
                    Text("• \(l.skill?.name ?? ""): \(l.feedback)").font(.subheadline).foregroundStyle(Theme.inkSecondary)
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
                Text("락커에 스케이트를 넣어 두면 연마한 뒤 얼마나 탔는지 알 수 있어요.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                Button { jumper?.go(.tab(.locker)) } label: {
                    Label("락커로 가기", icon: "arrow.right").font(.subheadline.bold())
                }
                .buttonStyle(.bordered).tint(Theme.cobalt)
            }
        } else if !due.isEmpty || !worn.isEmpty {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "연마 점검해 볼까요?", systemImage: "wrench.and.screwdriver.fill")
                ForEach(worn) { r in
                    Text("러너 \(r.name): \(r.lifeSummary). 날 교체를 생각해 볼 때예요.").font(.subheadline)
                }
                ForEach(due) { r in
                    Text("러너 \(r.name): \(DiaryStore.sharpeningSummary(r, context: context)). 정해 둔 만큼 탔어요.")
                        .font(.subheadline)
                }
                Text("엣지가 밀리지 않으면 더 타도 돼요. 기준은 락커에서 바꿀 수 있어요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                Button { jumper?.go(.tab(.locker)) } label: {
                    Label("락커에서 보기", icon: "arrow.right").font(.subheadline.bold())
                }
                .buttonStyle(.bordered).tint(Theme.cobalt)
            }
        }
    }

    /// 우리 팀: 다음 일정 하나. 팀이 없으면 만들기 안내.
    @ViewBuilder
    private var teamCard: some View {
        let next = teamEvents.first { $0.at >= Calendar.current.startOfDay(for: Date()) }
        NavigationLink { TeamView() } label: {
            Card {
                // 팀이 여럿이면 다음 일정이 속한 팀 이름을 적는다.
                CardHeader(title: next.flatMap { n in teams.first { $0.id == n.teamID } }?.name ?? (teams.count == 1 ? teams[0].name : "우리 팀"), systemImage: "person.3.fill",
                           trailing: next.map { $0.at.formatted(.dateTime.month().day().weekday(.abbreviated)) })
                if let next {
                    Text("\(next.title) · \(next.at.formatted(.dateTime.hour().minute()))\(next.rinkName.isEmpty ? "" : " · \(next.rinkName)")")
                        .font(.subheadline).foregroundStyle(Theme.title)
                } else if teams.isEmpty {
                    Text("팀 일정·참석·라인업을 정리하고 카톡에 올려 보세요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                } else {
                    Text("다음 일정이 없어요. 하나 넣어 볼까요?").font(.subheadline).foregroundStyle(Theme.inkSecondary)
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

/// 기록 템플릿 목록(설정 > 나). 만들기는 기록 상세의 '템플릿으로 저장'에서 한다.
struct RecordTemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecordTemplate.createdAt) private var templates: [RecordTemplate]

    var body: some View {
        List {
            if templates.isEmpty {
                Text("아직 템플릿이 없습니다. 기록을 열고 아래의 '템플릿으로 저장'을 누르면 여기에 생깁니다.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            if !templates.isEmpty {
                // 줄을 눌러도 아무 일이 없어 헷갈렸다. 어디서 쓰는지 먼저 적는다.
                Text("기록 화면 위쪽 '템플릿으로 채우기'에서 골라 써요. 왼쪽으로 밀면 지워요.")
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
            }
            ForEach(templates) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                    Text(t.summary).font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .onDelete { idx in
                for i in idx { context.delete(templates[i]) }
                context.saveOrReport()
            }
        }
        .navigationTitle("기록 템플릿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if !templates.isEmpty { EditButton() } }
    }
}

/// 설정 (홈 아바타). 개인정보 원칙과 앱 정보.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RestPrefs.key) private var restJSON = "[]"
    @AppStorage(TeamReminder.enabledKey) private var teamReminder = false
    @State private var reminderDenied = false
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @AppStorage(RecordPrefs.modeKey) private var modeRaw = RecordMode.auto.rawValue
    @Environment(\.modelContext) private var context
    @State private var showingStorageDetail = false
    @AppStorage(MyPrefs.nicknameKey) private var nickname = ""

    /// 안내 한 줄: 아이콘 + 굵은 한마디 + 짧은 설명.
    private func fact(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            AppIcon(icon).font(.body).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        List {
            Section {
                TextField("닉네임 (예: 하키왕)", text: Binding(get: { nickname }, set: { nickname = MyPrefs.clean($0) }))
                    .accessibilityIdentifier("닉네임")
                NavigationLink { RecordTemplatesView() } label: {
                    fact("square.on.square", "기록 템플릿", "자주 적는 기록의 종류·시간·장소를 저장해 둡니다.")
                }
            } header: {
                Text("나")
            } footer: {
                Text("홈 인사말에 나옵니다. 이 아이폰에만 저장됩니다.")
            }
            Section {
                Picker("실력 레벨", selection: $levelRaw) {
                    Text("정하지 않음").tag("")
                    ForEach(PlayerLevel.allCases, id: \.rawValue) { l in Text("\(l.title) · \(l.yearsText)").tag(l.rawValue) }
                }
                Picker("입력 방식", selection: $modeRaw) {
                    ForEach(RecordMode.allCases, id: \.rawValue) { m in Text(m.title).tag(m.rawValue) }
                }
            } header: {
                Text("기록 방식")
            } footer: {
                Text(RecordPrefs.settingsSummary())
            }
            Section("연결") {
                NavigationLink { HealthConnectView() } label: {
                    fact("heart.text.square.fill", "Apple 건강", "수면·심박·운동을 기록 옆에 보여 줍니다. 가민도 됩니다.")
                }
            }
            // 스위치 설명은 스위치 바로 아래 한 줄로 둔다(아래 문단으로 떼어 두면 어느 스위치 얘기인지 찾아 읽어야 한다).
            Section("쉼·알림") {
                Toggle(isOn: Binding(get: { RestPrefs.isResting(restJSON) }, set: { _ in restJSON = RestPrefs.toggled(restJSON) })) {
                    fact("moon.zzz.fill", "쉬는 중", "켜 두면 주간 연속 기록이 끊기지 않습니다.")
                }
                Toggle(isOn: Binding(get: { teamReminder }, set: { on in
                    Task { @MainActor in
                        teamReminder = on ? await TeamReminder.requestPermission() : false
                        reminderDenied = on && !teamReminder
                        await TeamReminder.reschedule(context)
                    }
                })) { fact("bell.badge", "팀 경기 이틀 전 알림", "참석을 안 정한 사람이 있을 때만 울립니다.") }
                if reminderDenied { NotificationDeniedNote() }
            }
            // 한눈에 볼 세 가지만 먼저, 나머지 안내는 '자세히'로 접는다. 내용은 빼지 않는다.
            Section("내 기록 보관") {
                fact("iphone", "이 아이폰에만 저장", "서버나 iCloud로 보내지 않습니다.")
                fact("heart.text.square", "건강·AI는 켰을 때만", "읽은 건강 값은 따로 저장하지 않습니다.")
                fact("photo", "사진은 고른 것만", "복사해 두고 위치 정보는 지웁니다.")
                DisclosureGroup("자세히", isExpanded: $showingStorageDetail) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 링크장 검색어만 Apple 지도로 전달됩니다.")
                        Text("• AI 요약은 아이폰 안에서 하키 기록만 사용합니다.")
                        Text("• Apple Watch로 잰 운동은 건강 앱에도 저장됩니다.")
                        Text("• 일기는 '리포트 공유'를 켠 것만 시즌 리포트에 한 줄 들어갑니다. 내용을 따로 분석하지 않습니다.")
                        Text("• 분석은 내 기록의 흐름만 보여 줍니다. 의료 조언이나 실력 예측은 하지 않습니다.")
                    }
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
                .font(.subheadline)
            }
            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                        .foregroundStyle(Theme.inkSecondary)
                }
                Link(destination: URL(string: "https://alexalim.github.io/hockey-diary/")!) { Label("개인정보 처리방침", icon: "lock.fill") }
                Link(destination: URL(string: "mailto:esl2dev@gmail.com")!) { Label("문의하기", icon: "envelope.fill") }
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
    }
}
