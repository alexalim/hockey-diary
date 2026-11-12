import SwiftUI
import SwiftData
import HockeyCore

/// 홈의 '이달의 퀘스트' 블록. 이달 빙판 목표 진행 바 + 이번 주 퀘스트 3개.
struct QuestCard: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query private var drills: [DrillLog]
    @Query private var checks: [BodyCheck]
    @Query private var journals: [DailyJournal]
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @AppStorage(QuestStore.targetKey) private var targetOverride = 0
    @AppStorage(RestPrefs.key) private var restJSON = "[]"

    var body: some View {
        let s = QuestStore.summary(now: Date(),
                                   facts: QuestStore.facts(sessions: sessions, drills: drills, checks: checks, journals: journals),
                                   level: PlayerLevel(rawValue: levelRaw), targetOverride: targetOverride)
        let resting = RestPrefs.isResting(restJSON)
        NavigationLink { QuestView() } label: {
            Card {
                HStack {
                    Label("이달의 퀘스트", systemImage: "flag.checkered").font(.headline).foregroundStyle(Theme.title)
                    Spacer()
                    Text("\(s.points)점").font(.caption.bold()).foregroundStyle(Theme.accentText)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Theme.achievementSoft, in: Capsule())
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkTertiary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(s.monthDone)").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.title)
                    Text("/ \(s.monthTarget)회 빙판").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    Text(s.monthReached ? "이달 배지 획득!" : "\(s.monthTarget - s.monthDone)번 남았어").font(.caption).foregroundStyle(s.monthReached ? Theme.success : Theme.inkSecondary)
                }
                ProgressView(value: Double(min(s.monthDone, s.monthTarget)), total: Double(max(s.monthTarget, 1)))
                    .tint(s.monthReached ? Theme.success : Theme.neonPink)
                if resting {
                    Text("쉬는 중이라 퀘스트도 쉬어. 돌아오면 이어서.").font(.caption).foregroundStyle(Theme.inkSecondary)
                } else {
                    Divider()
                    ForEach(s.weekly) { p in QuestRow(progress: p, compact: true) }
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear { QuestStore.awardBadges(context) }
    }
}

/// 퀘스트 한 줄: 아이콘, 제목, 진행, 체크.
struct QuestRow: View {
    let progress: QuestProgress
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: progress.isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(progress.isDone ? Theme.success : Theme.inkTertiary)
            Image(systemName: progress.quest.kind.symbol).font(.subheadline).foregroundStyle(Theme.accent).frame(width: 22)
            Text(progress.quest.title).font(compact ? .subheadline : .subheadline.bold())
                .foregroundStyle(progress.isDone ? Theme.inkSecondary : Theme.title)
                .strikethrough(progress.isDone, color: Theme.inkTertiary)
            Spacer()
            Text("\(min(progress.done, progress.quest.target))/\(progress.quest.target)\(progress.quest.unit)")
                .font(.caption.bold()).foregroundStyle(progress.isDone ? Theme.success : Theme.inkSecondary)
        }
        .frame(minHeight: compact ? 30 : Theme.touch)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.quest.title), \(progress.done) 중 \(progress.quest.target)\(progress.isDone ? ", 완료" : "")")
    }
}

/// 퀘스트 화면: 이달 목표·포인트, 이번 주 퀘스트, 받은 달 배지.
struct QuestView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query private var drills: [DrillLog]
    @Query private var checks: [BodyCheck]
    @Query private var journals: [DailyJournal]
    @Query private var earned: [EarnedSticker]
    @AppStorage(RecordPrefs.levelKey) private var levelRaw = ""
    @AppStorage(QuestStore.targetKey) private var targetOverride = 0
    @AppStorage(RestPrefs.key) private var restJSON = "[]"

    private var level: PlayerLevel? { PlayerLevel(rawValue: levelRaw) }

    var body: some View {
        let s = QuestStore.summary(now: Date(),
                                   facts: QuestStore.facts(sessions: sessions, drills: drills, checks: checks, journals: journals),
                                   level: level, targetOverride: targetOverride)
        ScrollView {
            VStack(spacing: 12) {
                monthHero(s)
                targetCard(s)
                SectionHeader(title: "이번 주 퀘스트", trailing: weekText(s.week))
                Card {
                    if RestPrefs.isResting(restJSON) {
                        EmptyHint(text: "쉬는 중이라 퀘스트도 쉬어. 쉬는 동안은 못 채워도 아무 일 없어.", systemImage: "moon.zzz.fill")
                    }
                    ForEach(s.weekly) { p in QuestRow(progress: p) }
                    Text("월요일마다 새 퀘스트 3개가 와. 하나 끝낼 때마다 \(Quest.pointsPerQuest)점. 못 채운 주는 그냥 지나가.")
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                SectionHeader(title: "받은 배지")
                badgesCard
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("퀘스트")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { QuestStore.awardBadges(context) }
    }

    private func monthHero(_ s: QuestStore.Summary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(s.month.start.formatted(.dateTime.month(.wide)).uppercased() + " QUEST")
                    .font(.system(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("\(s.points)점").font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.18), in: Capsule())
            }
            Text("이달 빙판 \(s.monthDone) / \(s.monthTarget)회").font(.title2.bold()).foregroundStyle(.white)
            ProgressView(value: Double(min(s.monthDone, s.monthTarget)), total: Double(max(s.monthTarget, 1))).tint(.white)
            Text(s.monthReached ? "목표 달성! \(s.month.start.formatted(.dateTime.month())) 배지를 받았어. 락커 문에 붙여봐."
                                : "\(s.monthTarget - s.monthDone)번 더 타면 \(s.month.start.formatted(.dateTime.month())) 배지야.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    private func targetCard(_ s: QuestStore.Summary) -> some View {
        Card {
            CardHeader(title: "이달 목표", systemImage: "target",
                       trailing: targetOverride > 0 ? "직접 정함" : "레벨 기본값")
            Stepper("빙판 \(s.monthTarget)회", value: Binding(get: { s.monthTarget }, set: { targetOverride = $0 }), in: 1...31)
            if targetOverride > 0 {
                Button("레벨 기본값(\(Quest.monthlyTarget(level: level))회)으로") { targetOverride = 0 }.font(.subheadline)
            } else {
                Text(level == nil ? "레벨을 정하면 목표가 거기에 맞춰져. 지금은 4회." : "\(level!.title)은 한 달 \(s.monthTarget)회가 기본이야. 바꿔도 돼.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var badgesCard: some View {
        let badges = earned.filter { $0.stickerKey.hasPrefix("badge-") }.sorted { $0.stickerKey > $1.stickerKey }
        return Card {
            if badges.isEmpty {
                EmptyHint(text: "이달 목표를 채우면 첫 배지를 받아. 받은 배지는 락커 문에 붙일 수 있어.", systemImage: "medal.fill")
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(badges, id: \.stickerKey) { b in
                        VStack(spacing: 4) {
                            StickerView(key: b.stickerKey, photo: nil, side: 56)
                            Text(badgeLabel(b.stickerKey)).font(.caption2).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
                Text("배지는 락커 꾸미기의 성취 스티커에도 있어.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private func badgeLabel(_ key: String) -> String {
        guard let m = Quest.badgeMonth(key) else { return key }
        return "\(m.year % 100)년 \(m.month)월"
    }

    private func weekText(_ w: DateInterval) -> String {
        let end = w.end.addingTimeInterval(-1)
        return "\(w.start.formatted(.dateTime.month(.defaultDigits).day()))~\(end.formatted(.dateTime.month(.defaultDigits).day()))"
    }
}
