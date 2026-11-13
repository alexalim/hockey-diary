import SwiftUI
import SwiftData
import Charts
import HockeyCore

/// 나의 빙판 리포트 (S06). 모든 요약에 기간·표본 수·출처를 붙이고, 표본이 모자라면 그래프 대신 안내한다.
struct GrowthView: View {
    @Environment(AppJumper.self) private var jumper: AppJumper?
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \Skill.name) private var skills: [Skill]
    @Query private var allShots: [ShotMark]
    @Query(sort: \DrillLog.at, order: .reverse) private var allDrills: [DrillLog]

    @State private var period: Period = .month
    @State private var metric: TrendMetric = .sessions

    private var periodSessions: [Session] {
        let from = period.start(from: Date())
        return sessions.filter { from == nil || $0.startsAt >= from! }
    }

    private var samples: [ActivitySample] {
        Insights.inPeriod(sessions.map(\.sample), from: period.start(from: Date()), to: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: "YOUR PROGRESS", title: "성장", subtitle: "활동과 실력은 따로, 변화는 함께.") {
                    NavigationLink { SeasonReportView() } label: {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.title)
                            .frame(width: 44, height: 44).background(Theme.card, in: Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityLabel("시즌 리포트")
                }
                Picker("기간", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { p in Text(p.title).tag(p) }
                }
                .pickerStyle(.segmented)
                trendCard
                activityCard
                moodCard
                surfaceCard
                shotsCard
                goalieCard
                skillsCard
                NavigationLink { ConditionView() } label: {
                    Card(tint: Theme.iceBlue) {
                        CardHeader(title: "컨디션 흐름", systemImage: "waveform.path.ecg")
                        Text("잔 시간, 안정 심박, 기분, 힘듦, 몸 상태를 날마다 이어서 봐요. 볼 항목은 내가 골라요.")
                            .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
                SleepGrowthCard(samples: samples, periodTitle: period.longTitle)
                CycleGrowthCard(sessions: periodSessions.map { (at: $0.startsAt, fatigue: $0.fatigue) }, periodTitle: period.longTitle)
                practiceCard
                NavigationLink { AISummaryView() } label: {
                    Card {
                        Label("AI로 돌아보기", systemImage: "sparkles").font(.headline).foregroundStyle(Theme.title)
                        Text("켜야만 동작해요. 아이폰 안에서 하키 기록만 요약해요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
                NavigationLink { SeasonReportView() } label: {
                    Card(tint: Theme.cobalt) {
                        Label("시즌 리포트 만들기", systemImage: "photo.on.rectangle.angled").font(.headline).foregroundStyle(.white)
                        Text("횟수와 기술만 담은 이미지를 만들어 저장하고 공유해요.").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 추세 (맨 위)

    private var trend: Trend {
        let items: [(at: Date, value: Int)]
        switch metric {
        case .sessions: items = sessions.map { ($0.startsAt, 1) }
        case .minutes: items = sessions.map { ($0.startsAt, $0.minutes) }
        case .drills: items = allDrills.map { ($0.at, 1) }
        }
        return Trend.build(items, period: period, now: Date())
    }

    private func bucketLabel(_ d: Date) -> String {
        switch period {
        case .week: return d.formatted(.dateTime.weekday(.narrow))
        case .all: return d.formatted(.dateTime.month(.defaultDigits)) + "월"
        default: return d.formatted(.dateTime.month(.defaultDigits).day())
        }
    }

    private var trendCard: some View {
        let t = trend
        return Card {
            CardHeader(title: "늘고 있어요?", systemImage: "chart.line.uptrend.xyaxis")
            Picker("무엇을 볼까요", selection: $metric) {
                ForEach(TrendMetric.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric == .minutes ? minutesText(t.total) : "\(t.total)\(metric.unit)")
                    .font(.largeTitle.bold()).foregroundStyle(Theme.title)
                Text(period.longTitle).font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            if t.total == 0 && (t.previousTotal ?? 0) == 0 {
                EmptyHint(text: metric == .drills ? "이 기간엔 드릴 기록이 없어요. 훈련 탭 드릴에서 세면 여기 쌓여요." : "이 기간엔 기록이 없어요.",
                          action: metric == .drills ? EmptyAction(title: "드릴로 가기") { jumper?.go(.training(.drill)) } : nil)
            } else {
                Chart {
                    ForEach(Array(t.buckets.enumerated()), id: \.offset) { i, b in
                        if let p = b.previous {
                            BarMark(x: .value("칸", bucketLabel(b.start)), y: .value("값", p), width: .ratio(0.7))
                                .foregroundStyle(Theme.inkTertiary.opacity(0.25))
                                .position(by: .value("기간", "앞선 기간"))
                        }
                        BarMark(x: .value("칸", bucketLabel(b.start)), y: .value("값", b.current), width: .ratio(0.7))
                            .foregroundStyle(Theme.barGradient)
                            .position(by: .value("기간", "이번 기간"))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(period.longTitle) \(metric.title) 합계 \(t.total)\(metric.unit)")
                HStack {
                    if t.previousTotal != nil {
                        Legend(items: [.init(color: Theme.cobalt, title: "이번 기간"), .init(color: Theme.inkTertiary.opacity(0.35), title: "앞선 기간")])
                    }
                    Spacer()
                }
                if let line = t.comparison(metric, periodTitle: period.title) {
                    Text(line).font(.subheadline.bold()).foregroundStyle(Theme.title)
                }
            }
        }
    }

    // MARK: - 활동량

    private var activityCard: some View {
        let byType = Insights.byType(samples)
        let total = samples.reduce(0) { $0 + $1.minutes }
        let rows = ActivityType.allCases.map { ($0, byType[$0] ?? CountMinutes()) }
        return Card {
            CardHeader(title: "활동량", systemImage: "chart.bar.fill")
            if samples.isEmpty {
                EmptyHint(text: Sufficiency.empty.message)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(samples.count)회").font(.largeTitle.bold()).foregroundStyle(Theme.title)
                    Text(minutesText(total)).font(.headline).foregroundStyle(Theme.inkSecondary)
                }
                Chart(rows, id: \.0) { row in
                    BarMark(x: .value("횟수", row.1.count), y: .value("종류", row.0.title))
                        .foregroundStyle(row.0.color)
                        .annotation(position: .trailing) {
                            Text("\(row.1.count)").font(.caption2).foregroundStyle(Theme.inkSecondary)
                        }
                }
                .chartXAxis(.hidden)
                .frame(height: 140)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rows.map { "\($0.0.title) \($0.1.count)회" }.joined(separator: ", "))
            }
            footnote(samples.count)
        }
    }

    // MARK: - 기분 변화 (F-B05)

    private var moodCard: some View {
        let change = Insights.moodChange(samples)
        return Card {
            CardHeader(title: "운동 전후 기분", systemImage: "face.smiling")
            if let sentence = change.sentence {
                Text(sentence).font(.subheadline).foregroundStyle(Theme.title)
                HStack(spacing: 8) {
                    StatTile(title: "나아짐", value: "\(change.improved)", tint: Theme.success)
                    StatTile(title: "그대로", value: "\(change.same)", tint: Theme.title)
                    StatTile(title: "낮아짐", value: "\(change.worse)", tint: Theme.danger)
                }
                Text("기분은 내가 고른 값이에요. 운동 덕분이라고 말하는 건 아니에요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            } else {
                EmptyHint(text: change.sufficiency == .empty
                          ? "운동 전후 기분을 둘 다 남긴 기록이 아직 없어요."
                          : change.sufficiency.message)
            }
            footnote(change.paired, note: "전후 기분이 모두 있는 활동만")
        }
    }

    // MARK: - 빙판 유형 (7.3)

    private var surfaceCard: some View {
        let bySurface = Insights.bySurface(samples)
        return Card {
            CardHeader(title: "어디서 탔어요?", systemImage: "snowflake")
            if samples.isEmpty {
                EmptyHint(text: Sufficiency.empty.message)
            } else {
                ForEach(SurfaceType.allCases, id: \.self) { s in
                    let v = bySurface[s] ?? CountMinutes()
                    if v.count > 0 {
                        HStack {
                            Label {
                                Text(s.isUnspecified ? "미입력" : s.title).foregroundStyle(s.isUnspecified ? Theme.inkTertiary : Theme.title)
                            } icon: {
                                Image(systemName: s.systemImage).foregroundStyle(s.color)
                            }
                            .font(.subheadline)
                            Spacer()
                            Text("\(v.count)회 · \(minutesText(v.minutes))").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        }
                        .frame(minHeight: 32)
                    }
                }
                Text("어디서 탔는지만 보여 줘요. 장소로 잘하고 못한 걸 따지지 않아요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            footnote(samples.count)
        }
    }

    // MARK: - 기술 (S04)

    // MARK: - 슛 차트 누적

    private var periodShots: [ShotPoint] {
        let ids = Set(periodSessions.map(\.id))
        return allShots.filter { ids.contains($0.sessionID) }.map(\.point)
    }

    private var shotsCard: some View {
        let shots = periodShots
        let st = ShotStats.compute(shots)
        return Card {
            CardHeader(title: "슛 차트", systemImage: "scope", trailing: shots.isEmpty ? nil : shotSummaryText(st))
            if shots.isEmpty {
                EmptyHint(text: "경기 기록에서 슛 자리를 찍으면 여기에 쌓여요. 어디서 쏘면 잘 들어가는지 보여 줄게요.", systemImage: "scope",
                          action: EmptyAction(title: "경기 리뷰 쓰기") { jumper?.go(.entry(.session(.regularGame))) })
            } else {
                ShotChartCanvas(shots: Array(shots.suffix(200)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(shotSummaryText(st))
                ShotLegend()
                if let s = st.sentence() {
                    Text(s).font(.subheadline).foregroundStyle(Theme.title)
                } else {
                    Text(Sufficiency(count: shots.count).message).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                }
                if shots.count >= 3 {
                    ForEach(ShotZone.allCases, id: \.self) { z in
                        if let line = st.byZone[z], line.shots > 0 {
                            HStack {
                                Text(z.title).font(.caption)
                                Spacer()
                                Text(line.shots >= 3 ? "\(line.goals)/\(line.shots) · \(Int(((line.rate ?? 0) * 100).rounded()))%" : "\(line.goals)/\(line.shots) · 더 모아 봐요")
                                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                        }
                    }
                }
                let byGame = Dictionary(grouping: allShots, by: \.sessionID)
                let games = periodSessions.filter { byGame[$0.id] != nil }.prefix(5)
                if !games.isEmpty {
                    Text("어느 경기였어요?").font(.caption.bold()).foregroundStyle(Theme.inkSecondary).padding(.top, 4)
                    ForEach(Array(games), id: \.id) { g in
                        let marks = byGame[g.id] ?? []
                        NavigationLink { SessionDetailView(session: g) } label: {
                            HStack {
                                Text(g.title).font(.subheadline).foregroundStyle(Theme.title).lineLimit(1)
                                Spacer()
                                Text("슛 \(marks.count) · 골 \(marks.filter { $0.point.outcome == .goal }.count)").font(.caption.bold()).foregroundStyle(Theme.accent)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("골로 찍은 표시만 세요. 성공률은 골 ÷ 전체 슛이에요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
            footnote(shots.count)
        }
    }

    @ViewBuilder
    private var goalieCard: some View {
        let games = periodSessions.compactMap(\.goalieStats)
        if !games.isEmpty {
            let total = GoalieStats.sum(games)
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "골리 기록", systemImage: "figure.hockey", trailing: "\(games.count)경기")
                HStack(spacing: 8) {
                    StatTile(title: "세이브", value: "\(total.saves)", tint: Theme.success)
                    StatTile(title: "실점", value: "\(total.goalsAgainst)", tint: Theme.danger)
                    StatTile(title: "세이브율", value: total.savePctText)
                }
                if games.count < 3 {
                    Text("3경기부터 흐름을 보여 줄게요.").font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                footnote(games.count, note: "골리로 뛴 경기만")
            }
        }
    }

    // MARK: - 연습

    private var periodDrills: [DrillLog] {
        let from = period.start(from: Date())
        return allDrills.filter { from == nil || $0.at >= from! }
    }

    private var practiceCard: some View {
        let logs = periodDrills
        let by = DrillStats.bySkill(logs.compactMap(\.entry))
        return Card {
            CardHeader(title: "연습", systemImage: "figure.hockey",
                       trailing: logs.isEmpty ? nil : "연습한 날 \(DrillStats.practiceDays(logs.compactMap(\.entry)))일")
            if logs.isEmpty {
                EmptyHint(text: "드릴을 세면서 연습하면 기술별 연습량이 여기 쌓여요.", systemImage: "figure.hockey",
                          action: EmptyAction(title: "드릴 시작") { jumper?.go(.training(.drill)) })
            } else {
                ForEach(by.keys.sorted { (by[$0]?.sessions ?? 0) > (by[$1]?.sessions ?? 0) }, id: \.self) { name in
                    if let line = by[name] {
                        HStack {
                            Text(name).font(.subheadline).foregroundStyle(Theme.title)
                            Spacer()
                            Text(line.text).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        }
                        .frame(minHeight: 28)
                    }
                }
            }
            NavigationLink { PracticeView() } label: {
                Label("연습하러 가기", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
            footnote(logs.count, note: "드릴 기록")
        }
    }

    private var skillsCard: some View {
        let practiced = Set(allDrills.map(\.skillName))
        let used = skills.filter { !$0.learnings.isEmpty || !$0.attempts.isEmpty || practiced.contains($0.name) }
        return Card {
            CardHeader(title: "기술 성장", systemImage: "chart.line.uptrend.xyaxis")
            if used.isEmpty {
                EmptyHint(text: "수업에서 배운 기술을 남기면 경기에서 써본 것까지 이어서 볼 수 있어요.",
                          action: EmptyAction(title: "수업 기록 쓰기") { jumper?.go(.entry(.session(.lesson))) })
            }
            ForEach(used) { skill in
                NavigationLink { SkillDetailView(skill: skill) } label: {
                    SkillRow(skill: skill, practiceCount: allDrills.filter { $0.skillName == skill.name }.count)
                }
                    .buttonStyle(.plain)
            }
            if !used.isEmpty {
                Text("전체 기간 · 직접 남긴 기록").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private func footnote(_ count: Int, note: String? = nil) -> some View {
        Text(Insights.footnote(periodTitle: period.longTitle, count: count) + (note.map { " · \($0)" } ?? ""))
            .font(.caption2).foregroundStyle(Theme.inkSecondary)
    }
}

struct SkillRow: View {
    let skill: Skill
    var practiceCount = 0

    var body: some View {
        let st = skill.stats
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text("수업 \(st.lessonCount) · 써봄 \(st.triedEvents) · 못 써봄 \(st.untriedEvents)\(practiceCount > 0 ? " · 연습 \(practiceCount)" : "")")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if st.evaluated > 0 {
                Text("성공 \(st.successes)/\(st.evaluated)").font(.caption.bold()).foregroundStyle(Theme.accent)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .frame(minHeight: Theme.touch)
        .accessibilityElement(children: .combine)
    }
}

/// 기술 하나의 학습·적용 타임라인 (S04, FR-04).
struct SkillDetailView: View {
    let skill: Skill
    @Query(sort: \DrillLog.at, order: .reverse) private var drills: [DrillLog]

    private enum Event: Identifiable {
        case learned(SkillLearning, Session)
        case attempted(SkillAttempt, Session)

        var id: UUID {
            switch self {
            case .learned(let l, _): return l.id
            case .attempted(let a, _): return a.id
            }
        }

        var session: Session {
            switch self {
            case .learned(_, let s), .attempted(_, let s): return s
            }
        }
    }

    /// 경기에서 가장 많이 시도한 날 3번(성공이 앞), 연습을 가장 많이 한 날 3번. 올해 것엔 표시.
    private var topGames: [SkillAttempt] {
        skill.attempts.filter { $0.tried && $0.session != nil }
            .sorted { ($0.outcome == .success ? 1 : 0, $0.count ?? 0) > ($1.outcome == .success ? 1 : 0, $1.count ?? 0) }
            .prefix(3).map { $0 }
    }

    private var topPracticeDays: [(day: Date, amount: Int, unit: String)] {
        let cal = Calendar.current
        let mine = drills.filter { $0.skillName == skill.name }
        let byDay = Dictionary(grouping: mine) { cal.startOfDay(for: $0.at) }
        return byDay.map { (day: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }, unit: $0.value.first?.unit.title ?? "") }
            .sorted { $0.amount > $1.amount }.prefix(3).map { $0 }
    }

    @ViewBuilder
    private var bestsCard: some View {
        let games = topGames, days = topPracticeDays
        if !games.isEmpty || !days.isEmpty {
            let year = Calendar.current.component(.year, from: Date())
            Card {
                CardHeader(title: "내 최고", systemImage: "rosette")
                ForEach(Array(games.enumerated()), id: \.element.id) { i, a in
                    if let s = a.session {
                        NavigationLink { SessionDetailView(session: s) } label: {
                            HStack {
                                Text("\(i + 1)").font(.headline).foregroundStyle(Theme.neonPink).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                                    Text("\(s.startsAt.formatted(date: .abbreviated, time: .omitted))\(Calendar.current.component(.year, from: s.startsAt) == year ? " · 올해" : "")")
                                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                                }
                                Spacer()
                                Text([a.outcome?.title, a.count.map { "\($0)번 시도" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption.bold()).foregroundStyle(Theme.accent)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            .frame(minHeight: Theme.touch)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !days.isEmpty {
                    Text("연습 많이 한 날").font(.caption.bold()).foregroundStyle(Theme.inkSecondary).padding(.top, 4)
                    ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                        HStack {
                            Text("\(i + 1)").font(.headline).foregroundStyle(Theme.neonPink).frame(width: 20)
                            Text(d.day.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                            Spacer()
                            Text("\(d.amount)\(d.unit)").font(.subheadline.bold()).foregroundStyle(Theme.title)
                        }
                        .frame(minHeight: 32)
                    }
                }
                Text("경기는 성공한 날이 앞, 그다음 시도 횟수 순이에요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var events: [Event] {
        let l = skill.learnings.compactMap { x in x.session.map { Event.learned(x, $0) } }
        let a = skill.attempts.compactMap { x in x.session.map { Event.attempted(x, $0) } }
        return (l + a).sorted { $0.session.startsAt > $1.session.startsAt }
    }

    var body: some View {
        let st = skill.stats
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text(skill.category).font(.caption).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 4) {
                        Text(skill.name).font(.title2.bold()).foregroundStyle(.white)
                        SkillInfoButton(name: skill.name, tint: .white)
                    }
                    Text("처음보다 나아졌을까요? 아래 숫자는 각각 다른 걸 세요.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatTile(title: "배운 수업", value: "\(st.lessonCount)회")
                    StatTile(title: "경기에서 써봄", value: "\(st.triedEvents)회")
                    StatTile(title: "기회가 없었음", value: "\(st.untriedEvents)회")
                    StatTile(title: "성공 기록", value: st.evaluated == 0 ? "평가 없음" : "\(st.successes)/\(st.evaluated)", tint: Theme.success)
                }
                if st.partials > 0 || st.difficulties > 0 {
                    Card {
                        Text("일부 성공 \(st.partials) · 어려움 \(st.difficulties) · 시도 횟수 합 \(st.attemptTotal)")
                            .font(.subheadline)
                        Text("내가 매긴 결과예요. 실제 슛 성공률과는 달라요.")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
                bestsCard
                Card {
                    CardHeader(title: "타임라인", systemImage: "clock")
                    ForEach(events) { e in
                        NavigationLink { SessionDetailView(session: e.session) } label: { eventRow(e) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func eventRow(_ e: Event) -> some View {
        HStack(alignment: .top, spacing: 10) {
            switch e {
            case .learned(let l, let s):
                Image(systemName: "graduationcap.fill").foregroundStyle(ActivityType.lesson.color).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(s.startsAt.dayTitle) 수업에서 배움").font(.subheadline.bold())
                    if !l.feedback.isEmpty { Text(l.feedback).font(.caption).foregroundStyle(Theme.inkSecondary) }
                    if let d = l.difficulty { Text("체감 난도 \(d)").font(.caption2).foregroundStyle(Theme.inkSecondary) }
                }
            case .attempted(let a, let s):
                Image(systemName: "figure.hockey").foregroundStyle(Theme.accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(s.startsAt.dayTitle) \(s.type.title) · \(a.tried ? (a.outcome?.title ?? "써봤어요") : "못 써봄")")
                        .font(.subheadline.bold())
                    if !a.notes.isEmpty { Text(a.notes).font(.caption).foregroundStyle(Theme.inkSecondary) }
                }
            }
            Spacer()
        }
        .frame(minHeight: Theme.touch)
    }
}
