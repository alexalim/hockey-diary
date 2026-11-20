import SwiftUI
import SwiftData
import HockeyCore

/// '뭐할까' 탭: 지금 하면 좋은 것 몇 가지를 기록에서 골라 보여 준다. 고르는 규칙은 HockeyCore.WhatNow에 있다.
/// 카드마다 바로 할 수 있는 버튼 하나. 몸 상태는 카드 안에서 바로 남긴다.
struct WhatNowView: View {
    @Binding var newEntry: NewEntry?
    @Environment(\.modelContext) private var context
    @Environment(AppJumper.self) private var jumper: AppJumper?
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
    @State private var running: RoutineRun?

    private var todayCheck: BodyCheck? { checks.first { Calendar.current.isDateInToday($0.day) } }

    private var facts: WhatNow.Facts {
        let now = Date()
        let summary = QuestStore.summary(now: now,
                                         facts: QuestStore.facts(sessions: sessions, drills: drills, checks: checks, journals: journals),
                                         level: PlayerLevel(rawValue: levelRaw), targetOverride: targetOverride)
        let due = runners.contains { $0.retiredAt == nil && ($0.needsReplacement || DiaryStore.needsCheck($0, context: context)) }
        return WhatNow.Facts(
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
    }

    var body: some View {
        let list = WhatNow.suggest(facts)
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: "WHAT NOW", title: "뭐할까", subtitle: "지금 하면 좋은 것부터 골라 봤어요.")
                if list.isEmpty {
                    EmptyHint(text: "오늘 할 건 다 했어요. 푹 쉬어도 돼요.", systemImage: "sparkles")
                }
                ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                    if i == 0 { SectionHeader(title: "지금 하나") }
                    if i == 1 { SectionHeader(title: "그 다음") }
                    card(s, first: i == 0)
                }
                Text("기록이 쌓일수록 더 잘 골라요. 팀 일정, 몸 상태, 드릴, 수업 목표를 봐요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
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
                Button { act(s) } label: {
                    Text(s.action).frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(first ? AnyButtonStyle(PinkButtonStyle()) : AnyButtonStyle(BorderedButtonStyle()))
                .tint(Theme.cobalt)
                .accessibilityIdentifier("whatnow-\(s.kind.rawValue)")
            }
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
            jumper?.go(.tab(.team))
        case .bodyCheck:
            break
        case .quest:
            switch QuestKind(rawValue: s.key) {
            case .journals?: newEntry = .journal(Date())
            case .drills?: newEntry = .practice
            default: jumper?.go(.training(.practice))
            }
        case .drill:
            if let d = DrillCatalog.drill(s.key) { running = RoutineRun(single: d) } else { newEntry = .practice }
        case .goal:
            jumper?.go(.training(.practice))
        case .sharpen:
            jumper?.go(.tab(.locker))
        case .journal:
            newEntry = .journal(Date())
        case .firstIce:
            if teams.isEmpty { jumper?.go(.training(.drill)) } else { jumper?.go(.tab(.team)) }
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
        case .goal: return "target"
        case .sharpen: return "wrench.and.screwdriver.fill"
        case .journal: return "book.fill"
        case .firstIce: return "sportscourt"
        }
    }
}

/// 조건에 따라 버튼 스타일을 바꾸려고 타입을 지운다.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
