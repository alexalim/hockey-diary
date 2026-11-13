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
                ScreenHeader(eyebrow: Date().formatted(.dateTime.weekday(.wide).month().day()).uppercased(),
                             title: "오늘도, 빙판 위에서.", subtitle: "작은 기록이 나의 플레이를 바꿔요.") {
                    RoundIconButton(systemImage: "gearshape.fill", label: "설정") { showingSettings = true }
                }
                if health.openFailed || health.lastSaveFailed { storeWarning }
                promptCard
                levelCard
                nextGameHero
                weekCard
                SectionHeader(title: "빠른 시작")
                quickButtons
                bodyCard
                ForEach(visibleBlocks) { b in block(b) }
                Button { showingEdit = true } label: {
                    Label("홈 꾸미기", systemImage: "slider.horizontal.3").font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $showingEdit) { NavigationStack { HomeEditView() } }
    }

    /// 실력 레벨을 아직 안 정했을 때 한 번 묻는다. 고르면 기록 입력 방식이 거기에 맞춰진다.
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @ViewBuilder
    private var levelCard: some View {
        if levelRaw.isEmpty {
            Card {
                CardHeader(title: "내 하키 실력은 어느 정도예요?", systemImage: "person.crop.circle.badge.questionmark")
                Text("레벨에 맞춰 기록 입력을 간단하게, 또는 자세하게 맞춰 드릴게요. 구력은 참고만 하세요. 설정에서 언제든 바꿀 수 있어요.")
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
    private var promptCard: some View {
        if let p = prompt {
            Card(tint: p == .resting ? Theme.iceBlue : Theme.neonPink.opacity(0.12)) {
                switch p {
                case .resting:
                    Label("쉬는 중이에요", systemImage: "moon.zzz.fill").font(.headline).foregroundStyle(Theme.title)
                    Text("연속 기록과 목표는 그대로 둘게요. 돌아오면 이어서 세요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    Button("다시 탈래요") { restJSON = RestPrefs.toggled(restJSON) }.buttonStyle(.bordered)
                case .logEvent(let title):
                    Label("\(title) 끝났죠? 바로 남겨요", systemImage: "pencil.and.list.clipboard").font(.headline).foregroundStyle(Theme.title)
                    Text("시간이랑 장소는 팀 일정으로 채워 둘게요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
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
                        Text("오늘 해볼 거 하나 정해 두면 좋아요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                case .morningGoal(let goal):
                    Label("오늘 해볼 거", systemImage: "target").font(.headline).foregroundStyle(Theme.title)
                    Text(goal).font(.subheadline).foregroundStyle(Theme.title)
                case .eveningJournal:
                    Label("오늘 어땠어요?", systemImage: "book.fill").font(.headline).foregroundStyle(Theme.title)
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
                    Label("오늘 몸 상태", systemImage: "figure.stand").font(.headline).foregroundStyle(Theme.title)
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
            HomeRing(value: Double(todayMood ?? 0) / 5, center: todayMood.map(Mood.face) ?? "–", label: "컨디션", color: Theme.warningFill)
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
        if let team = teams.first, let next = teamEvents.first(where: { $0.at >= Calendar.current.startOfDay(for: Date()) }) {
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
                    Text(next.opponent.isEmpty ? next.title : "\(teams.first?.name ?? "우리 팀") vs \(next.opponent)")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    if !next.rinkName.isEmpty || !next.memo.isEmpty {
                        Label([next.rinkName, next.memo].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "mappin")
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
                Label("이번 주 하키", systemImage: "target").font(.headline).foregroundStyle(Theme.title)
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
                            Image(systemName: s.type.systemImage).foregroundStyle(Theme.accent)
                            Text("오늘 \(s.startsAt.timeTitle) \(s.title)").font(.subheadline).foregroundStyle(Theme.title)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkTertiary)
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
            Text("이번 주는 두 번 타면 원이 다 차요.").font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var quickButtons: some View {
        HStack(spacing: 8) {
            QuickAction(title: "연습 기록", systemImage: "graduationcap.fill", bubble: Theme.stickers[3]) { newEntry = .session(.lesson) }
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
                    Label("한동안 쉬어요 (비시즌·부상)", systemImage: "moon.zzz").font(.caption)
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
                Text("락커에 스케이트를 넣으면 연마하고 얼마나 탔는지 세어 드릴게요.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
        } else if !due.isEmpty || !worn.isEmpty {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "연마 점검해 볼까요?", systemImage: "wrench.and.screwdriver.fill")
                ForEach(worn) { r in
                    Text("러너 \(r.name): \(r.lifeSummary). 날 교체를 생각해볼 때야.").font(.subheadline)
                }
                ForEach(due) { r in
                    Text("러너 \(r.name): \(DiaryStore.sharpeningSummary(r, context: context)). 정해 둔 만큼 탔어요.")
                        .font(.subheadline)
                }
                Text("엣지가 밀리지 않으면 더 타도 돼요. 기준은 락커에서 바꿀 수 있어요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
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

/// 설정 (홈 아바타). 개인정보 원칙과 앱 정보.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RestPrefs.key) private var restJSON = "[]"
    @AppStorage(TeamReminder.enabledKey) private var teamReminder = false
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @AppStorage(RecordPrefs.modeKey) private var modeRaw = RecordMode.auto.rawValue
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
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
            Section("내 기록 보관") {
                Label("기록은 모두 이 아이폰에만 저장됩니다.", systemImage: "iphone")
                Label("서버나 iCloud로 보내지 않습니다. 링크장 검색어만 Apple 지도로 전달됩니다.", systemImage: "icloud.slash")
                Label("Apple 건강은 연결했을 때만 읽습니다. 읽은 값은 따로 저장하지 않습니다.", systemImage: "heart.text.square")
                Label("AI 요약은 켰을 때만 동작하며, 아이폰 안에서 하키 기록만 사용합니다.", systemImage: "sparkles")
                Label("Apple Watch로 잰 운동은 건강 앱에도 저장됩니다.", systemImage: "applewatch")
                Label("일기는 '리포트 공유'를 켠 것만 시즌 리포트에 한 줄 들어갑니다. 내용을 따로 분석하지 않습니다.", systemImage: "lock.fill")
                Label("사진은 고른 것만 복사해 두며, 위치 정보는 지웁니다.", systemImage: "photo")
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
                Text("쉬는 동안에는 주간 연속 기록이 끊기지 않습니다. 팀 알림은 아직 참석을 정하지 않은 사람이 있을 때만 이 아이폰에서 울립니다.")
            }
            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                        .foregroundStyle(Theme.inkSecondary)
                }
                Text("분석은 내 기록의 흐름만 보여 줍니다. 의료 조언이나 실력 예측은 하지 않습니다.")
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
    }
}
