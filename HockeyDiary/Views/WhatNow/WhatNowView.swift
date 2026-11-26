import SwiftUI
import SwiftData
import HockeyCore

/// '뭐할까' 탭: 지금 하면 좋은 것 몇 가지를 기록에서 골라 보여 준다. 고르는 규칙은 HockeyCore.WhatNow에 있다.
/// 카드마다 바로 할 수 있는 버튼 하나. 몸 상태는 카드 안에서 바로 남긴다.
struct WhatNowView: View {
    @Binding var newEntry: NewEntry?
    @Environment(\.modelContext) private var context
    @Environment(AppJumper.self) private var jumper: AppJumper?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \DailyJournal.entryDate, order: .reverse) private var journals: [DailyJournal]
    @Query(sort: \DrillLog.at, order: .reverse) private var drills: [DrillLog]
    @Query(sort: \BodyCheck.day, order: .reverse) private var checks: [BodyCheck]
    @Query(sort: \TeamEvent.at) private var teamEvents: [TeamEvent]
    @Query private var teams: [Team]
    @Query(sort: \RunnerSet.createdAt) private var runners: [RunnerSet]
    @AppStorage(RestPrefs.key) private var restJSON = "[]"
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @AppStorage(QuestStore.targetKey) private var targetOverride = 0
    @Query(sort: \PracticeRoutine.createdAt) private var routines: [PracticeRoutine]
    @State private var running: RoutineRun?
    @State private var showingRinks = false
    /// 지금 쓸 수 있는 시간(분). 고르면 그 안에 끝나는 드릴·루틴을 권한다. 다시 누르면 해제.
    @State private var minutesFree: Int?

    private var todayCheck: BodyCheck? { checks.first { Calendar.current.isDateInToday($0.day) } }

    private var facts: WhatNow.Facts {
        let now = Date()
        let summary = QuestStore.summary(now: now,
                                         facts: QuestStore.facts(sessions: sessions, drills: drills, checks: checks, journals: journals),
                                         level: PlayerLevel(rawValue: levelRaw), targetOverride: targetOverride)
        let due = runners.contains { $0.retiredAt == nil && ($0.needsReplacement || DiaryStore.needsCheck($0, context: context)) }
        var f = WhatNow.Facts(
            now: now,
            resting: RestPrefs.isResting(restJSON),
            events: teamEvents.map { .init(title: $0.title, start: $0.at, minutes: $0.minutes, logged: $0.sessionID != nil) },
            conditionOn: ConditionPrefs.isOn(.body),
            bodyCheckedToday: todayCheck != nil,
            journaledToday: journals.contains { Calendar.current.isDateInToday($0.entryDate) },
            quests: summary.weekly,
            drills: drills.compactMap { $0.skillName.isEmpty ? nil : WhatNow.DrillFact(skillName: $0.skillName, at: $0.at) },
            lastGoal: sessions.first { !$0.nextGoal.isEmpty }?.nextGoal,
            lastSessionAt: sessions.first?.startsAt,
            sharpenDue: due,
            hasTeam: !teams.isEmpty)
        f.bodyToday = todayCheck?.value
        f.minutesFree = minutesFree
        f.routines = routines.filter { !$0.items.isEmpty }
            .map { WhatNow.RoutineFact(name: $0.name, minutes: StarterRoutine.estimatedMinutes($0.items)) }
        return f
    }

    /// 남은 시간 고르기. 안 골라도 추천은 나온다.
    private var timeCard: some View {
        Card {
            CardHeader(title: "시간이 얼마나 있어요?", systemImage: "clock")
            HStack(spacing: 8) {
                ForEach([5, 15, 30], id: \.self) { m in
                    let on = minutesFree == m
                    Button { minutesFree = on ? nil : m } label: {
                        Text("\(m)분").font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                            .foregroundStyle(on ? Color.white : Theme.accent)
                            .background(on ? Theme.cobalt : Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("시간 \(m)분")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    var body: some View {
        let list = WhatNow.suggest(facts)
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: "", title: "뭐할까", subtitle: "지금 하면 좋은 것부터 골라 봤어요.")
                if list.isEmpty {
                    EmptyHint(text: "오늘 할 건 다 했어요. 푹 쉬어도 돼요.", systemImage: "sparkles")
                }
                ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                    if i == 0 { SectionHeader(title: "지금 하나") }
                    // 시간 고르기는 첫 카드 아래에 둔다(맨 위에 두면 '지금 하나'가 밀려 내려간다).
                    if i == 1 && !RestPrefs.isResting(restJSON) { timeCard }
                    if i == 1 { SectionHeader(title: "그 다음") }
                    card(s, first: i == 0)
                }
                Text("팀 일정, 몸 상태, 드릴, 수업 목표를 보고 골라요. 기록이 쌓일수록 더 잘 맞춰요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingRinks) { RinkFinderView() }
        .fullScreenCover(item: $running) { run in
            NavigationStack { RoutineRunView(run: run) }
        }
    }

    private func card(_ s: WhatNow.Suggestion, first: Bool) -> some View {
        Card(tint: first ? Theme.neonPink.opacity(0.12) : Theme.card) {
            CardHeader(title: s.title, systemImage: symbol(s.kind))
            Text(s.detail).font(.subheadline).foregroundStyle(s.kind == .goal ? Theme.title : Theme.inkSecondary)
            if s.kind == .bodyCheck {
                BodyCheckRow(value: todayCheck?.value) { v in BodyCheckStore.set(v, context: context) }
            } else if !s.action.isEmpty {
                actionButton(s, first: first)
            }
        }
    }

    /// 첫 카드는 분홍 큰 버튼, 나머지는 테두리 버튼. 스타일 종류가 달라 갈래를 나눈다.
    @ViewBuilder
    private func actionButton(_ s: WhatNow.Suggestion, first: Bool) -> some View {
        let label = Text(s.action).frame(maxWidth: .infinity, minHeight: Theme.touch)
        if first {
            Button { act(s) } label: { label }
                .buttonStyle(PinkButtonStyle())
                .accessibilityIdentifier("whatnow-\(s.kind.rawValue)")
        } else {
            Button { act(s) } label: { label }
                .buttonStyle(.bordered).tint(Theme.accent)
                .accessibilityIdentifier("whatnow-\(s.kind.rawValue)")
        }
    }

    private func act(_ s: WhatNow.Suggestion) {
        switch s.kind {
        case .rest:
            restJSON = RestPrefs.toggled(restJSON)
        case .logEvent:
            let kind = teamEvents.first { $0.title == s.key && $0.sessionID == nil }.flatMap { ActivityType(rawValue: $0.kindRaw) } ?? .regularGame
            newEntry = .session(kind)
        case .prepareEvent:
            jumper?.go(.homeScreen(.team))
        case .bodyCheck:
            break
        case .quest:
            switch QuestKind(rawValue: s.key) {
            case .journals?: newEntry = .journal(Date())
            case .drills?: newEntry = .practice
            // '기록하기'는 기록 화면을, '몸 상태 남기기'는 몸 상태 카드가 있는 홈을 연다(예전엔 둘 다 훈련 탭으로 가 아무것도 못 했다).
            case .sessions?: newEntry = .session(sessions.first?.type ?? .lesson)
            case .conditions?: dismiss()
            default: jumper?.go(.training(.practice))
            }
        case .drill:
            if let d = DrillCatalog.drill(s.key) { running = RoutineRun(single: d) } else { newEntry = .practice }
        case .routine:
            if let r = routines.first(where: { $0.name == s.key }) { running = RoutineRun(routine: r) } else { jumper?.go(.training(.drill)) }
        case .goal:
            jumper?.go(.training(.practice))
        case .sharpen:
            jumper?.go(.tab(.locker))
        case .journal:
            newEntry = .journal(Date())
        case .firstIce:
            if teams.isEmpty { showingRinks = true } else { jumper?.go(.homeScreen(.team)) }
        }
    }

    private func symbol(_ k: WhatNow.Kind) -> String {
        switch k {
        case .rest: return "moon.zzz.fill"
        case .logEvent: return "pencil.and.list.clipboard"
        case .prepareEvent: return "calendar.badge.clock"
        case .bodyCheck: return "figure.stand"
        case .quest: return "flag.checkered"
        case .drill: return "figure.hockey"
        case .routine: return "list.bullet.rectangle"
        case .goal: return "target"
        case .sharpen: return "wrench.and.screwdriver.fill"
        case .journal: return "book.fill"
        case .firstIce: return "sportscourt"
        }
    }
}
