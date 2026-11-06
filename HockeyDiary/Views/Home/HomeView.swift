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

    @State private var showingSettings = false
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
                todayCard
                quickButtons
                goalCard
                feedbackCard
                sharpeningCard
                recentCard
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("오늘의 빙판")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("설정")
            }
        }
        .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView() } }
    }

    private var storeWarning: some View {
        Card(tint: Theme.neonPink.opacity(0.15)) {
            Label(health.openFailed ? "저장소를 열지 못해서 지금 기록은 앱을 끄면 사라져. 앱을 다시 켜봐."
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
                Text("수업 끝나고 10분 안에 남기면 잊기 전에 붙잡을 수 있어.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            } else {
                Text("오늘 \(todaySessions.count)개 활동\(todayJournal == nil ? "" : " · 일기 1개")")
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
        if let s = lastWithGoal {
            Card {
                CardHeader(title: "다음 목표", systemImage: "target", trailing: s.startsAt.dayTitle)
                Text(s.nextGoal).font(.body).foregroundStyle(Theme.title)
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
        let due = runners.filter { r in
            EquipmentMath.needsCheck(minutesSince: DiaryStore.minutesSinceSharpening(r, context: context),
                                     thresholdMinutes: r.checkThresholdMinutes)
        }
        if skates.isEmpty {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "장비 점검", systemImage: "shoeprints.fill")
                Text("락커에 스케이트를 등록하면 연마 후 얼음 위 시간을 세어줄게.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } else if !due.isEmpty {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "연마 점검해볼까?", systemImage: "wrench.and.screwdriver.fill")
                ForEach(due) { r in
                    Text("러너 \(r.name): 마지막 연마 후 \(minutesText(DiaryStore.minutesSinceSharpening(r, context: context))) 탔어. 내가 정한 기준에 닿았어.")
                        .font(.subheadline)
                }
                Text("엣지가 밀리는 느낌이 없으면 더 타도 돼. 기준은 락커에서 바꿀 수 있어.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
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

    var body: some View {
        List {
            Section("내 기록은 어디에 있어?") {
                Label("모든 기록은 이 아이폰 안에만 저장돼.", systemImage: "iphone")
                Label("서버나 iCloud로 보내지 않아. 링크장 검색어만 Apple 지도로 보내.", systemImage: "icloud.slash")
                Label("Apple 건강은 연결했을 때만 읽고, 앱에 저장하지 않아.", systemImage: "heart.text.square")
                Label("AI 요약은 켰을 때만, 기기 안에서 하키 기록만 써.", systemImage: "sparkles")
                Label("일기는 기본 비공개고, 내용을 자동으로 분석하지 않아.", systemImage: "lock.fill")
                Label("사진은 고른 것만 사본으로 담고 위치 정보는 지워.", systemImage: "photo")
            }
            Section("연결") {
                NavigationLink { HealthConnectView() } label: { Label("Apple 건강", systemImage: "heart.text.square.fill") }
            }
            Section("아직 없는 기능") {
                Text("Apple Watch 앱은 다음 업데이트에서 열려.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
                Text("분석은 내 기록의 경향만 보여줘. 의료 조언이나 경기력 예측이 아니야.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
    }
}
