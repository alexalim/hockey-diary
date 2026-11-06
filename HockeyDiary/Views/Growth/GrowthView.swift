import SwiftUI
import SwiftData
import Charts
import HockeyCore

/// 나의 빙판 리포트 (S06). 모든 요약에 기간·표본 수·출처를 붙이고, 표본이 모자라면 그래프 대신 안내한다.
struct GrowthView: View {
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \Skill.name) private var skills: [Skill]

    @State private var period: Period = .month

    private var samples: [ActivitySample] {
        Insights.inPeriod(sessions.map(\.sample), from: period.start(from: Date()), to: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("기간", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { p in Text(p.title).tag(p) }
                }
                .pickerStyle(.segmented)
                activityCard
                moodCard
                surfaceCard
                skillsCard
                SleepGrowthCard(samples: samples, periodTitle: period.longTitle)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("성장")
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
                    Text(minutesText(total)).font(.headline).foregroundStyle(.secondary)
                }
                Chart(rows, id: \.0) { row in
                    BarMark(x: .value("횟수", row.1.count), y: .value("종류", row.0.title))
                        .foregroundStyle(row.0 == .lesson ? Theme.neonPink : Theme.accent)
                        .annotation(position: .trailing) {
                            Text("\(row.1.count)").font(.caption2).foregroundStyle(.secondary)
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
                    moodStat("나아짐", change.improved, Theme.neonPink)
                    moodStat("그대로", change.same, Theme.cobalt)
                    moodStat("낮아짐", change.worse, Color.secondary)
                }
                Text("기분은 내가 고른 자기평가야. 운동 때문이라고 단정하지 않아.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                EmptyHint(text: change.sufficiency == .empty
                          ? "운동 전후 기분을 둘 다 남긴 기록이 아직 없어."
                          : change.sufficiency.message)
            }
            footnote(change.paired, note: "전후 기분이 모두 있는 활동만")
        }
    }

    private func moodStat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack {
            Text("\(value)").font(.title2.bold()).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Theme.cobaltSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 빙판 유형 (7.3)

    private var surfaceCard: some View {
        let bySurface = Insights.bySurface(samples)
        return Card {
            CardHeader(title: "어디서 탔어?", systemImage: "snowflake")
            if samples.isEmpty {
                EmptyHint(text: Sufficiency.empty.message)
            } else {
                ForEach(SurfaceType.allCases, id: \.self) { s in
                    let v = bySurface[s] ?? CountMinutes()
                    if v.count > 0 {
                        HStack {
                            Label(s.isUnspecified ? "미입력" : s.title, systemImage: s.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(s.isUnspecified ? .secondary : Theme.title)
                            Spacer()
                            Text("\(v.count)회 · \(minutesText(v.minutes))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 32)
                    }
                }
                Text("장소에 따라 더 잘했다·못했다를 판단하지 않아. 맥락만 보여줘.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            footnote(samples.count)
        }
    }

    // MARK: - 기술 (S04)

    private var skillsCard: some View {
        let used = skills.filter { !$0.learnings.isEmpty || !$0.attempts.isEmpty }
        return Card {
            CardHeader(title: "기술 성장", systemImage: "chart.line.uptrend.xyaxis")
            if used.isEmpty {
                EmptyHint(text: "수업에서 배운 기술을 기록하면 여기서 경기 적용까지 이어서 볼 수 있어.")
            }
            ForEach(used) { skill in
                NavigationLink { SkillDetailView(skill: skill) } label: { SkillRow(skill: skill) }
                    .buttonStyle(.plain)
            }
            if !used.isEmpty {
                Text("전체 기간 · 직접 입력 기준").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func footnote(_ count: Int, note: String? = nil) -> some View {
        Text(Insights.footnote(periodTitle: period.longTitle, count: count) + (note.map { " · \($0)" } ?? ""))
            .font(.caption2).foregroundStyle(.secondary)
    }
}

struct SkillRow: View {
    let skill: Skill

    var body: some View {
        let st = skill.stats
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text("수업 \(st.lessonCount) · 써봄 \(st.triedEvents) · 못 써봄 \(st.untriedEvents)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if st.evaluated > 0 {
                Text("성공 \(st.successes)/\(st.evaluated)").font(.caption.bold()).foregroundStyle(Theme.accent)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: Theme.touch)
        .accessibilityElement(children: .combine)
    }
}

/// 기술 하나의 학습·적용 타임라인 (S04, FR-04).
struct SkillDetailView: View {
    let skill: Skill

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
                    Text("처음보다 나아졌을까? 숫자는 서로 다른 걸 세.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    stat("배운 수업", "\(st.lessonCount)회")
                    stat("경기에서 써봄", "\(st.triedEvents)회")
                    stat("기회가 없었음", "\(st.untriedEvents)회")
                    stat("성공 기록", st.evaluated == 0 ? "평가 없음" : "\(st.successes)/\(st.evaluated)")
                }
                if st.partials > 0 || st.difficulties > 0 {
                    Card {
                        Text("일부 성공 \(st.partials) · 어려움 \(st.difficulties) · 시도 횟수 합 \(st.attemptTotal)")
                            .font(.subheadline)
                        Text("내가 남긴 평가 기준이야. 실제 샷 성공률과는 달라.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
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

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(Theme.title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func eventRow(_ e: Event) -> some View {
        HStack(alignment: .top, spacing: 10) {
            switch e {
            case .learned(let l, let s):
                Image(systemName: "graduationcap.fill").foregroundStyle(Theme.neonPink).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(s.startsAt.dayTitle) 수업에서 배움").font(.subheadline.bold())
                    if !l.feedback.isEmpty { Text(l.feedback).font(.caption).foregroundStyle(.secondary) }
                    if let d = l.difficulty { Text("체감 난도 \(d)").font(.caption2).foregroundStyle(.secondary) }
                }
            case .attempted(let a, let s):
                Image(systemName: "figure.hockey").foregroundStyle(Theme.accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(s.startsAt.dayTitle) \(s.type.title) · \(a.tried ? (a.outcome?.title ?? "써봤어") : "못 써봄")")
                        .font(.subheadline.bold())
                    if !a.notes.isEmpty { Text(a.notes).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
        }
        .frame(minHeight: Theme.touch)
    }
}
