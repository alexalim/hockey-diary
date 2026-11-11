import SwiftUI
import SwiftData
import HockeyCore

/// 다이어리 (FR-07). 달력 + 날짜 타임라인 + 검색.
/// 기록 없는 날은 빈칸이며 기분이 나쁜 날로 보지 않는다 (3.3).
struct DiaryView: View {
    @Binding var newEntry: NewEntry?

    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \DailyJournal.entryDate, order: .reverse) private var journals: [DailyJournal]

    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var search = ""
    @AppStorage(RestPrefs.key) private var restJSON = "[]"
    private enum Filter: String, CaseIterable { case all = "전체", hockey = "하키", journal = "일기" }
    @State private var filter: Filter = .all

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: "MY ICE LOG", title: "기록", subtitle: "나의 하키와 일상을 함께 남겨.")
                if search.isEmpty {
                    streakCard
                    calendarCard
                    SectionHeader(title: "활동 기록", trailing: "+ 기록하기", action: { newEntry = .session(.lesson, Self.sameTime(on: selectedDay)) })
                    Picker("보기", selection: $filter) { ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                    DayTimeline(day: selectedDay,
                                sessions: filter == .journal ? [] : sessionsOn(selectedDay),
                                journals: filter == .hockey ? [] : journalsOn(selectedDay),
                                newEntry: $newEntry)
                    SectionHeader(title: "나의 기록 도구")
                    HStack(spacing: 10) {
                        NavigationLink { ConditionView() } label: { tool("컨디션 흐름", "waveform.path.ecg") }.buttonStyle(.plain)
                        Button { newEntry = .journal(selectedDay) } label: { tool("한 줄 일기", "square.and.pencil") }.buttonStyle(.plain)
                    }
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "일기·메모·기술 찾기")
    }

    private func tool(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
            Text(title).font(.subheadline.bold()).foregroundStyle(Theme.title)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: Theme.touch)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.compactCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.compactCorner, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - 주간 연속 기록

    @ViewBuilder
    private var streakCard: some View {
        let st = WeeklyStreak.compute(sessions.map(\.startsAt), rests: RestPrefs.ranges(restJSON), now: Date())
        if st.best > 0 {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill").font(.title).foregroundStyle(st.current > 0 ? Theme.neonPink : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(st.current > 0 ? "\(st.current)주 연속 탔어" : "이번 주 한 번 타면 다시 시작해")
                            .font(.headline).foregroundStyle(Theme.title)
                        Text(streakSubtitle(st)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let m = st.milestone {
                        Text("\(m)주").font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.neonPink.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.neonPink)
                            .accessibilityLabel("\(m)주 연속 배지")
                    }
                }
            }
        }
    }

    private func streakSubtitle(_ st: WeeklyStreak) -> String {
        if RestPrefs.isResting(restJSON) { return "쉬는 중이라 안 끊겨. 최고 \(st.best)주" }
        if st.thisWeekPending { return "이번 주에 한 번 타면 이어져. 최고 \(st.best)주" }
        return "한 주에 한 번이면 이어져. 최고 \(st.best)주"
    }

    // MARK: - 달력

    private var calendarCard: some View {
        Card {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: Theme.touch, height: Theme.touch) }
                    .accessibilityLabel("이전 달")
                Spacer()
                Text(month.formatted(.dateTime.year().month(.wide))).font(.headline).foregroundStyle(Theme.title)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: Theme.touch, height: Theme.touch) }
                    .accessibilityLabel("다음 달")
            }
            let symbols = calendar.veryShortWeekdaySymbols
            let shifted = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(shifted.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 48) }
                }
            }
        }
    }

    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: month))
        }
        return days
    }

    private func dayCell(_ day: Date) -> some View {
        let daySessions = sessionsOn(day)
        let dayJournals = journalsOn(day)
        let mood = dayJournals.compactMap(\.mood).first ?? daySessions.compactMap(\.moodAfter).first
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Theme.accent : Theme.title)
                Text(mood.map(Mood.face) ?? " ").font(.callout)
                Circle()
                    .fill(daySessions.first?.type.color ?? Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? Theme.cobaltSoft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayLabel(day, sessions: daySessions.count, mood: mood, hasJournal: !dayJournals.isEmpty))
    }

    private func dayLabel(_ day: Date, sessions: Int, mood: Int?, hasJournal: Bool) -> String {
        var parts = [day.formatted(.dateTime.month().day())]
        if sessions > 0 { parts.append("하키 \(sessions)개") }
        if hasJournal { parts.append("일기 있음") }
        if let mood { parts.append("기분 \(Mood.label(mood))") }
        if sessions == 0 && !hasJournal { parts.append("기록 없음") }
        return parts.joined(separator: ", ")
    }

    private func shiftMonth(_ delta: Int) {
        if let m = calendar.date(byAdding: .month, value: delta, to: month) { month = m }
    }

    private func sessionsOn(_ day: Date) -> [Session] {
        sessions.filter { calendar.isDate($0.startsAt, inSameDayAs: day) }.sorted { $0.startsAt < $1.startsAt }
    }

    private func journalsOn(_ day: Date) -> [DailyJournal] {
        journals.filter { calendar.isDate($0.entryDate, inSameDayAs: day) }
    }

    // MARK: - 검색

    private var searchResults: some View {
        let q = search
        let js = journals.filter { j in
            j.body.localizedCaseInsensitiveContains(q) || j.tags.contains { $0.localizedCaseInsensitiveContains(q) }
        }
        let ss = sessions.filter { s in
            [s.learnedToday, s.coachNotes, s.review, s.nextGoal, s.rinkName, s.opponent]
                .contains { $0.localizedCaseInsensitiveContains(q) }
                || s.learnings.contains { ($0.skill?.name ?? "").localizedCaseInsensitiveContains(q) || $0.feedback.localizedCaseInsensitiveContains(q) }
                || s.attempts.contains { ($0.skill?.name ?? "").localizedCaseInsensitiveContains(q) || $0.notes.localizedCaseInsensitiveContains(q) }
        }
        return VStack(spacing: 12) {
            if js.isEmpty && ss.isEmpty {
                Card { EmptyHint(text: "'\(q)'와 맞는 기록이 없어.", systemImage: "magnifyingglass") }
            }
            if !ss.isEmpty {
                Card {
                    CardHeader(title: "하키 활동", systemImage: "figure.hockey", trailing: "\(ss.count)개")
                    ForEach(ss) { s in
                        NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }.buttonStyle(.plain)
                    }
                }
            }
            if !js.isEmpty {
                Card {
                    CardHeader(title: "하루 일기", systemImage: "book", trailing: "\(js.count)개")
                    ForEach(js) { j in JournalRow(journal: j) }
                }
            }
        }
    }
}

/// 선택한 날짜의 일기·하키 활동·사진 타임라인 (3.3).
struct DayTimeline: View {
    let day: Date
    let sessions: [Session]
    let journals: [DailyJournal]
    @Binding var newEntry: NewEntry?

    var body: some View {
        Card {
            CardHeader(title: day.dayTitle, systemImage: "list.bullet.below.rectangle")
            if sessions.isEmpty && journals.isEmpty {
                EmptyHint(text: "이날은 비어 있어. 하키 없는 날도 한 줄 남길 수 있어.")
            }
            ForEach(journals) { j in JournalRow(journal: j) }
            ForEach(sessions) { s in
                NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }.buttonStyle(.plain)
            }
            let photos = journals.flatMap(\.photos) + sessions.flatMap(\.photos)
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(photos) { p in PhotoThumb(data: p.imageData, size: 64) } }
                }
            }
            HStack(spacing: 8) {
                if journals.isEmpty {
                    Button { newEntry = .journal(day) } label: {
                        Label("일기 쓰기", systemImage: "square.and.pencil").frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(.bordered)
                }
                Button { newEntry = .session(.lesson, Self.sameTime(on: day)) } label: {
                    Label("하키 기록", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// 고른 날짜에 지금 시각을 붙인다. 지난 날 기록이 오늘로 들어가지 않게.
    static func sameTime(on day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return Date() }
        let now = cal.dateComponents([.hour, .minute], from: Date())
        return cal.date(bySettingHour: now.hour ?? 19, minute: now.minute ?? 0, second: 0, of: day) ?? day
    }
}

/// 일기 한 줄. 누르면 고치기.
struct JournalRow: View {
    let journal: DailyJournal
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(journal.mood.map(Mood.face) ?? "📝")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Theme.iceBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(journal.entryDate.dayTitle).font(.caption).foregroundStyle(.secondary)
                        if !journal.isPrivate {
                            Image(systemName: "square.and.arrow.up").font(.caption2).foregroundStyle(.secondary)
                                .accessibilityLabel("리포트 공유")
                        }
                    }
                    if !journal.body.isEmpty {
                        Text(journal.body).font(.subheadline).foregroundStyle(Theme.title).lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    if !journal.tags.isEmpty {
                        Text(journal.tags.map { "#\($0)" }.joined(separator: " ")).font(.caption).foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
            }
            .frame(minHeight: Theme.touch)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $editing) { NavigationStack { JournalEditorView(journal: journal) } }
    }
}
