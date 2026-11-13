import SwiftUI
import SwiftData
import HockeyCore

/// 수업에서 배운 기술 초안.
struct LearningDraft: Identifiable, Equatable {
    var id: UUID { skillID }
    var skillID: UUID
    var name: String
    var feedback: String = ""
    var difficulty: Int?
}

/// 경기에서 적용한 기술 초안. tried가 nil이면 아직 시도 여부를 고르지 않은 상태.
struct AttemptDraft: Identifiable, Equatable {
    var id: UUID { skillID }
    var skillID: UUID
    var name: String
    var tried: Bool?
    var outcome: AttemptOutcome?
    var count: Int?
    var notes: String = ""
}

/// 수업·미니게임·정규게임·자유 연습 기록 (S02·S03·S15).
/// 필수 입력은 최소로 두고, 나머지는 '더 기록하기'에 접어 둔다 (1분 입력 원칙).
struct SessionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Skill.name) private var allSkills: [Skill]
    @Query(sort: \Skate.createdAt) private var skates: [Skate]
    @Query(sort: \Session.startsAt, order: .reverse) private var allSessions: [Session]
    @Query(sort: \TeamEvent.at) private var teamEvents: [TeamEvent]

    private let session: Session?
    /// 방금 끝난 운동을 적는 경우(+ 버튼·홈 바로가기). 달력에서 고른 날이면 false.
    private let fromNow: Bool

    @State private var type: ActivityType
    @State private var startsAt: Date
    @State private var minutes: Int
    @State private var surface: SurfaceType
    @State private var rinkName: String
    @State private var iceFeel: IceFeel?
    @State private var weatherMemo: String
    @State private var moodBefore: Int?
    @State private var moodAfter: Int?
    @State private var fatigue: Int?
    @State private var learnedToday: String
    @State private var coachNotes: String
    @State private var selfRating: Int?
    @State private var nextGoal: String
    @State private var opponent: String
    @State private var scoreFor: Int?
    @State private var scoreAgainst: Int?
    @State private var position: String
    @State private var goals: Int?
    @State private var assists: Int?
    @State private var review: String
    @State private var plusMinus: Int?
    @State private var penaltyMinutes: Int?
    @State private var shifts: Int?
    @State private var playedGoalie = false
    @State private var saves: Int?
    @State private var goalsAgainst: Int?
    @State private var shots: [ShotPoint] = []
    @State private var shotOutcome: ShotOutcome = .goal
    @State private var didLoadShots = false
    @State private var learnings: [LearningDraft]
    @State private var attempts: [AttemptDraft]
    @State private var skateID: UUID?
    @State private var runnerID: UUID?
    @State private var iceMinutes: Int
    @State private var iceMinutesEdited: Bool
    @State private var removedPhotoIDs: Set<UUID> = []
    @State private var addedPhotos: [Data] = []

    @State private var showingSkillPicker = false
    @State private var showingMore = false
    @State private var didPrefill = false
    /// 새 기록은 핵심만 보이고 나머지는 '더 적기'에 접어 둔다. 고치기는 다 펼친다.
    @State private var expanded: Bool
    /// 실력 레벨·입력 방식에 따라 무엇을 처음부터 보여 줄지(설정 > 기록 방식).
    private let preset: RecordPreset
    @State private var prefillNote: String?
    /// 그날 건강 앱 운동(종류 상관없이). 직접 골라 시간을 채운다.
    @State private var dayWorkouts: [HealthWorkout] = []
    @State private var userTouchedTime = false
    @State private var linkedEventID: UUID?
    @State private var saved: Session?
    @State private var bests: [PersonalBest] = []

    init(newType: ActivityType, startsAt: Date = Date(), fromNow: Bool = false) {
        session = nil
        self.fromNow = fromNow
        let preset = RecordPrefs.preset()
        self.preset = preset
        _expanded = State(initialValue: preset.expandedByDefault)
        _showingMore = State(initialValue: preset.gameDetailsOpen)
        _type = State(initialValue: newType)
        _startsAt = State(initialValue: startsAt)
        _minutes = State(initialValue: preset.defaultMinutes(for: newType))
        _surface = State(initialValue: .unknown)
        _rinkName = State(initialValue: "")
        _iceFeel = State(initialValue: nil)
        _weatherMemo = State(initialValue: "")
        _moodBefore = State(initialValue: nil)
        _moodAfter = State(initialValue: nil)
        _fatigue = State(initialValue: nil)
        _learnedToday = State(initialValue: "")
        _coachNotes = State(initialValue: "")
        _selfRating = State(initialValue: nil)
        _nextGoal = State(initialValue: "")
        _opponent = State(initialValue: "")
        _scoreFor = State(initialValue: nil)
        _scoreAgainst = State(initialValue: nil)
        _position = State(initialValue: "")
        _goals = State(initialValue: nil)
        _assists = State(initialValue: nil)
        _review = State(initialValue: "")
        _learnings = State(initialValue: [])
        _attempts = State(initialValue: [])
        _skateID = State(initialValue: nil)
        _runnerID = State(initialValue: nil)
        _iceMinutes = State(initialValue: preset.defaultMinutes(for: newType))
        _iceMinutesEdited = State(initialValue: false)
    }

    init(session: Session) {
        self.session = session
        self.fromNow = false
        self.preset = RecordPrefs.preset()
        _expanded = State(initialValue: true)
        _type = State(initialValue: session.type)
        _startsAt = State(initialValue: session.startsAt)
        _minutes = State(initialValue: max(session.minutes, 1))
        _surface = State(initialValue: session.surface)
        _rinkName = State(initialValue: session.rinkName)
        _iceFeel = State(initialValue: session.iceFeel)
        _weatherMemo = State(initialValue: session.weatherMemo)
        _moodBefore = State(initialValue: session.moodBefore)
        _moodAfter = State(initialValue: session.moodAfter)
        _fatigue = State(initialValue: session.fatigue)
        _learnedToday = State(initialValue: session.learnedToday)
        _coachNotes = State(initialValue: session.coachNotes)
        _selfRating = State(initialValue: session.selfRating)
        _nextGoal = State(initialValue: session.nextGoal)
        _opponent = State(initialValue: session.opponent)
        _scoreFor = State(initialValue: session.scoreFor)
        _scoreAgainst = State(initialValue: session.scoreAgainst)
        _position = State(initialValue: session.position)
        _goals = State(initialValue: session.goals)
        _assists = State(initialValue: session.assists)
        _review = State(initialValue: session.review)
        _plusMinus = State(initialValue: session.plusMinus)
        _penaltyMinutes = State(initialValue: session.penaltyMinutes)
        _shifts = State(initialValue: session.shifts)
        _playedGoalie = State(initialValue: session.playedGoalie)
        _saves = State(initialValue: session.saves)
        _goalsAgainst = State(initialValue: session.goalsAgainst)
        _learnings = State(initialValue: session.learnings.compactMap { l in
            guard let skill = l.skill else { return nil }
            return LearningDraft(skillID: skill.id, name: skill.name, feedback: l.feedback, difficulty: l.difficulty)
        })
        _attempts = State(initialValue: session.attempts.compactMap { a in
            guard let skill = a.skill else { return nil }
            return AttemptDraft(skillID: skill.id, name: skill.name, tried: a.tried, outcome: a.outcome, count: a.count, notes: a.notes)
        })
        let usage = session.usages.first
        _skateID = State(initialValue: usage?.skateID)
        _runnerID = State(initialValue: usage?.runnerID)
        _iceMinutes = State(initialValue: usage?.iceMinutes ?? session.onIceMinutes ?? session.minutes)
        _iceMinutesEdited = State(initialValue: usage != nil)
        _showingMore = State(initialValue: true)
    }

    private var isNew: Bool { session == nil }

    private var canSave: Bool {
        if type.isGame && attempts.contains(where: { $0.tried == nil }) { return false }
        if type == .lesson {
            let hasMemo = ![coachNotes, learnedToday, nextGoal].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return !learnings.isEmpty || hasMemo
        }
        return true
    }

    private var saveHint: String? {
        if type.isGame && attempts.contains(where: { $0.tried == nil }) {
            return "기술마다 '못 써봄' 또는 '써봤어'를 골라 주세요. 못 써본 건 실패로 안 세요."
        }
        if type == .lesson && !canSave {
            return "기술을 하나 고르거나 메모를 한 줄 남겨 주세요."
        }
        return nil
    }

    var body: some View {
        if let saved {
            SessionSavedView(session: saved, bests: bests, shotCount: shots.count) { dismiss() }
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            basicsSection
            if type == .lesson { lessonSkillsSection }
            if type.isGame { gameSkillsSection }
            moodSection
            if expanded {
                if type.isGame { goalieSection }
                if type.isGame && !playedGoalie { shotSection }
            }
            notesSection
            if expanded {
                placeSection
                equipmentSection
                Section("사진") {
                    PhotoPickerRow(existing: session?.photos ?? [], removedIDs: $removedPhotoIDs, added: $addedPhotos)
                }
            } else {
                moreSection
            }
            if let saveHint {
                Section { Text(saveHint).font(.footnote).foregroundStyle(Theme.danger) }
            }
        }
        .navigationTitle(isNew ? "\(type.title) 기록" : "기록 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingSkillPicker) {
            NavigationStack {
                SkillPickerView(selected: Set(type == .lesson ? learnings.map(\.skillID) : attempts.map(\.skillID))) { picked in
                    applyPicked(picked)
                }
            }
        }
        .onAppear(perform: prefill)
        .task(id: Calendar.current.startOfDay(for: startsAt)) { await loadDayWorkouts() }
        .onChange(of: minutes) { _, new in if !iceMinutesEdited { iceMinutes = new } }
        .onChange(of: type) { _, new in if new.isGame && attempts.isEmpty { suggestSkills() } }
    }

    // MARK: - Sections

    private var basicsSection: some View {
        Section {
            LabeledChoice(title: "종류",
                          options: ActivityType.allCases.map { ChoiceOption(value: $0, title: $0.title, art: .symbol($0.systemImage)) },
                          selection: $type, columns: 4, minHeight: 68)
            DatePicker("시작", selection: Binding(get: { startsAt }, set: { startsAt = $0; userTouchedTime = true }))
            Stepper("활동 시간 \(minutesText(minutes))", value: Binding(get: { minutes }, set: { minutes = $0; userTouchedTime = true }), in: 1...360, step: 5)
            if !dayWorkouts.isEmpty {
                Menu {
                    ForEach(dayWorkouts) { w in
                        Button {
                            startsAt = w.start
                            minutes = max(1, Int((w.end.timeIntervalSince(w.start) / 60).rounded()))
                            if !iceMinutesEdited { iceMinutes = minutes }
                            userTouchedTime = true
                            prefillNote = "건강 앱 '\(w.activityName)' 운동 시간으로 채웠어요."
                        } label: {
                            Text("\(w.activityName) · \(w.start.formatted(date: .omitted, time: .shortened))~\(w.end.formatted(date: .omitted, time: .shortened))\(w.kilocalories.map { " · \(Int($0))kcal" } ?? "")")
                        }
                    }
                } label: {
                    Label("건강 앱 운동에서 가져오기 (\(dayWorkouts.count))", systemImage: "heart.text.square")
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let prefillNote { Text(prefillNote) }
                if isNew, let note = RecordPrefs.editorNote() { Text(note) }
            }
        }
    }

    /// 접힌 항목 안내. 숨어 있어도 저장되는 값(장소·장비)을 한 줄로 보여준다.
    private var moreSection: some View {
        Section {
            Button {
                withAnimation { expanded = true }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("더 적기").font(.headline).foregroundStyle(Theme.accent)
                        Text(moreSummary).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(Theme.accent)
                }
                .frame(minHeight: Theme.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("더 적기")
        } footer: {
            Text(type.isGame ? "슛 차트, 골리, 경기 정보, 장소, 장비, 사진은 여기 있어요. 안 열어도 저장돼요."
                             : (type == .lesson ? "코치 메모, 다음 목표, 장소, 장비, 사진은 여기 있어요. 안 열어도 저장돼요."
                                                : "장소, 장비, 사진은 여기 있어요. 안 열어도 저장돼요."))
        }
    }

    private var moreSummary: String {
        var parts: [String] = []
        if !rinkName.isEmpty { parts.append(rinkName) } else if surface != .unknown { parts.append(surface.title) }
        if let skate = skates.first(where: { $0.id == skateID }) {
            parts.append(skate.name)
            if let r = skate.installations.compactMap(\.runner).first(where: { $0.id == runnerID }) { parts.append(r.name) }
        }
        return parts.isEmpty ? "장소·장비 안 고름" : parts.joined(separator: " · ")
    }

    private var lessonSkillsSection: some View {
        Section {
            ForEach($learnings) { $draft in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(draft.name).font(.headline).foregroundStyle(Theme.title)
                        SkillInfoButton(name: draft.name)
                        Spacer()
                        Button(role: .destructive) {
                            learnings.removeAll { $0.skillID == draft.skillID }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(draft.name) 빼기")
                    }
                    TextField("코치 피드백·느낀 점", text: $draft.feedback, axis: .vertical)
                    if preset.showsSkillDetail {
                        ScalePicker(title: "체감 난도", low: "쉬움", high: "어려움", value: $draft.difficulty)
                    }
                }
                .padding(.vertical, 4)
            }
            Button {
                showingSkillPicker = true
            } label: {
                Label(learnings.isEmpty ? "오늘 배운 기술 고르기" : "기술 더 고르기", systemImage: "plus")
            }
        } header: {
            Text("오늘 배운 기술")
        } footer: {
            Text("기술 없이 메모만 남겨도 저장돼요.")
        }
    }

    private var gameSkillsSection: some View {
        Section {
            ForEach($attempts) { $draft in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(draft.name).font(.headline).foregroundStyle(Theme.title)
                        SkillInfoButton(name: draft.name)
                        Spacer()
                        Button(role: .destructive) {
                            attempts.removeAll { $0.skillID == draft.skillID }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(draft.name) 빼기")
                    }
                    Text("시합에서 실제 써봤어요?").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    ChoiceCards(options: [
                        ChoiceOption(value: Optional(false), title: "못 써봄", subtitle: "기회가 없었어요", art: .symbol("moon.zzz")),
                        ChoiceOption(value: Optional(true), title: "써봤어요", subtitle: "시도했어요", art: .symbol("figure.hockey")),
                    ], selection: Binding(
                        get: { draft.tried },
                        set: { draft.tried = $0; if $0 != true { draft.outcome = nil; draft.count = nil } }
                    ), columns: 2, minHeight: 64)
                    if draft.tried == true {
                        ChoiceCards(options: [ChoiceOption(value: AttemptOutcome?.none, title: "미정", art: .symbol("questionmark"))]
                                    + AttemptOutcome.allCases.map { o in
                                        ChoiceOption(value: Optional(o), title: o.title,
                                                     art: .symbol(o == .success ? "checkmark.seal.fill" : (o == .partial ? "circle.lefthalf.filled" : "tortoise.fill")))
                                    },
                                    selection: $draft.outcome, columns: 4, minHeight: 60)
                        if preset.showsSkillDetail { OptionalNumberField(title: "시도 횟수", value: $draft.count) }
                        TextField("어떤 상황이었어요?", text: $draft.notes, axis: .vertical)
                    } else if draft.tried == false {
                        Text("괜찮아요. 기회가 없었던 날도 기록이에요. 실패로 세지 않아요.")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Button {
                showingSkillPicker = true
            } label: {
                Label("기술 추가", systemImage: "plus")
            }
        } header: {
            Text("배운 기술, 써봤어요?")
        } footer: {
            Text(attempts.isEmpty ? "최근 수업에서 배운 기술이 없으면 직접 추가해 주세요." : "최근 수업에서 배운 기술을 넣어 뒀어요. 빼거나 더해도 돼요.")
        }
    }

    private var moodSection: some View {
        Section("기분·컨디션") {
            MoodPicker(title: "운동 전 기분", value: $moodBefore)
            MoodPicker(title: "운동 후 기분", value: $moodAfter)
            EffortPicker(value: $fatigue)
        }
    }

    private var notesSection: some View {
        Section {
            TextField("오늘의 배움 한 줄", text: $learnedToday, axis: .vertical)
            if expanded && type == .lesson {
                if preset.showsCoachNotes { TextField("코치 메모", text: $coachNotes, axis: .vertical) }
                TextField("다음 목표", text: $nextGoal, axis: .vertical)
                if preset.showsCoachNotes { ScalePicker(title: "오늘 내 평가", low: "아쉬움", high: "만족", value: $selfRating) }
            }
            if expanded && type.isGame {
                DisclosureGroup("경기 정보 더 기록하기", isExpanded: $showingMore) {
                    TextField("상대 팀", text: $opponent)
                    if type.showsGameStats && preset.showsGameStats {
                        OptionalNumberField(title: "우리 팀 점수", value: $scoreFor)
                        OptionalNumberField(title: "상대 팀 점수", value: $scoreAgainst)
                        TextField("포지션", text: $position)
                        if !playedGoalie {
                            OptionalNumberField(title: "골", value: $goals)
                            OptionalNumberField(title: "어시스트", value: $assists)
                            OptionalNumberField(title: "+/- (내가 있을 때 득점−실점)", value: $plusMinus)
                        }
                        OptionalNumberField(title: "페널티 (분)", value: $penaltyMinutes)
                        OptionalNumberField(title: "쉬프트 수", value: $shifts)
                    }
                    TextField("경기 회고", text: $review, axis: .vertical)
                    TextField("다음 목표", text: $nextGoal, axis: .vertical)
                }
            }
        } header: {
            Text("메모")
        } footer: {
            if type == .miniGame { Text("미니게임은 점수 없이 저장해도 돼요.") }
        }
    }

    private var placeSection: some View {
        Section {
            SurfacePicker(value: $surface)
            if surface == .indoorRink || surface == .outdoorRink {
                RinkNameField(text: $rinkName)
            } else {
                TextField(surface == .pond ? "장소 메모 (예: 동네 저수지)" : "장소 이름", text: $rinkName)
            }
            if surface != .unknown {
                LabeledChoice(title: "체감 빙질",
                              options: [ChoiceOption(value: IceFeel?.none, title: "안 고름", art: .symbol("minus"))]
                                + IceFeel.allCases.map { f in
                                    ChoiceOption(value: Optional(f), title: f.title,
                                                 art: .symbol(f == .hard ? "cube.fill" : (f == .normal ? "square.grid.2x2" : "drop.fill")))
                                },
                              selection: $iceFeel, columns: 4, minHeight: 60)
                if surface == .outdoorRink || surface == .pond {
                    TextField("날씨·기온·바람 메모", text: $weatherMemo, axis: .vertical)
                }
            }
        } header: {
            Text("어디서 탔어요?")
        } footer: {
            if surface == .pond {
                Text("얼음이 안전한지는 앱이 알 수 없어요. 현장 안내를 꼭 확인해 주세요. 정확한 위치는 저장하지 않아요.")
            } else {
                Text("빙질은 내가 느낀 대로 남기면 돼요.")
            }
        }
    }

    private var activeSkates: [Skate] { skates.filter { $0.status.isActive || $0.id == skateID } }

    private var equipmentSection: some View {
        Section {
            if skates.isEmpty {
                Text("락커 탭에 스케이트를 넣으면 연마하고 탄 시간이 저절로 쌓여요.")
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
            } else {
                LabeledChoice(title: "스케이트",
                              options: [ChoiceOption(value: UUID?.none, title: "안 고름", art: .symbol("minus"))]
                                + activeSkates.map { s in
                                    ChoiceOption(value: Optional(s.id), title: s.name,
                                                 subtitle: s.isPrimary ? "★ 대표" : (s.size.isEmpty ? s.status.title : "사이즈 \(s.size)"),
                                                 art: s.coverPhoto.map { ChoiceOption<UUID?>.Art.photo($0) } ?? ChoiceOption<UUID?>.Art.symbol("shoeprints.fill"))
                                },
                              selection: $skateID, columns: 2, minHeight: 84)
                .onChange(of: skateID) { _, new in
                    runnerID = skates.first { $0.id == new }?.currentRunner?.id
                }
                if let skate = skates.first(where: { $0.id == skateID }) {
                    let runners = skate.installations.compactMap(\.runner)
                        .reduce(into: [RunnerSet]()) { acc, r in if !acc.contains(where: { $0.id == r.id }) { acc.append(r) } }
                    LabeledChoice(title: "러너(날)",
                                  options: [ChoiceOption(value: UUID?.none, title: "안 고름", art: .symbol("minus"))]
                                    + runners.map { r in
                                        ChoiceOption(value: Optional(r.id), title: r.name,
                                                     subtitle: r.currentHollow.map { "RoH \($0)\"" } ?? (r.id == skate.currentRunner?.id ? "장착 중" : nil),
                                                     art: r.currentHollow.flatMap(Hollow.init(label:)).map { ChoiceOption<UUID?>.Art.hollow($0) } ?? ChoiceOption<UUID?>.Art.symbol("minus"))
                                    },
                                  selection: $runnerID, columns: 3, minHeight: 84)
                }
                if skateID != nil {
                    Stepper("실제로 탄 시간 \(minutesText(iceMinutes))", value: Binding(
                        get: { iceMinutes },
                        set: { iceMinutes = $0; iceMinutesEdited = true }
                    ), in: 0...360, step: 5)
                }
            }
        } header: {
            Text("장비")
        } footer: {
            if skateID != nil {
                Text("벤치에 있던 시간은 빼 주세요. 고른 스케이트·러너에만 쌓여요.")
            }
        }
    }

    // MARK: - Actions

    /// 골리로 뛴 날: 세이브·실점·세이브율.
    private var goalieSection: some View {
        Section {
            Toggle("오늘 골리로 뛰었어요", isOn: $playedGoalie)
            if playedGoalie {
                OptionalNumberField(title: "세이브", value: $saves)
                OptionalNumberField(title: "실점", value: $goalsAgainst)
                let g = GoalieStats(saves: saves ?? 0, goalsAgainst: goalsAgainst ?? 0)
                HStack {
                    Text("세이브율")
                    Spacer()
                    Text(g.shotsFaced == 0 ? "아직 없음" : "\(g.savePctText) · 상대 슛 \(g.shotsFaced)개").bold()
                }
            }
        } footer: {
            if playedGoalie { Text("세이브율은 세이브 ÷ (세이브 + 실점)이에요. 몰라도 저장돼요.") }
        }
    }

    /// 슛 차트: 결과를 고르고 그림을 누르면 그 자리에 표시가 찍힌다.
    private var shotSection: some View {
        Section {
            ChoiceCards(options: ShotOutcome.choices, selection: $shotOutcome, columns: 4, minHeight: 60)
            ShotChartCanvas(shots: shots, editable: true) { x, y in
                withAnimation(.spring(response: 0.25)) { shots.append(ShotPoint(x: x, y: y, outcome: shotOutcome)) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("슛 차트. 표시 \(shots.count)개. 아래 숫자 칸으로도 적을 수 있어요.")
            HStack {
                ShotLegend()
                Spacer()
                if !shots.isEmpty {
                    Button { withAnimation { _ = shots.popLast() } } label: { Label("되돌리기", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(.borderless).font(.footnote)
                }
            }
            if !shots.isEmpty {
                Text(shotSummaryText(ShotStats.compute(shots))).font(.subheadline.bold()).foregroundStyle(Theme.title)
            }
        } header: {
            Text("슛 차트")
        } footer: {
            Text("위에서 결과를 고르고, 슛을 쏜 자리를 눌러 주세요. 위가 상대 골대예요. 골로 찍은 수는 골 칸과 따로 세요.")
        }
    }

    private func loadShotsIfNeeded() {
        guard !didLoadShots else { return }
        didLoadShots = true
        if let session { shots = DiaryStore.shots(for: session.id, context: context).map(\.point) }
    }

    private func prefill() {
        loadShotsIfNeeded()
        guard isNew, !didPrefill else { return }
        didPrefill = true
        // 최근 활동의 빙판 유형·링크장을 제안한다. 확인은 사용자 몫.
        if let last = allSessions.first {
            surface = last.surface
            rinkName = last.rinkName
        }
        let lastSame = allSessions.first { $0.type == type }
        if fromNow {
            let open = openEvents
            let plan = QuickPrefill.plan(now: Date(), defaultMinutes: minutes, lastMinutes: lastSame?.minutes,
                                         events: open.map { .init(start: $0.at, minutes: $0.minutes) }, workouts: [])
            apply(plan, events: open)
            Task { await prefillFromHealth(open) }
        } else if let lastSame {
            minutes = max(lastSame.minutes, 1)
        }
        if let primary = skates.first(where: { $0.isPrimary && $0.status.isActive }) ?? skates.first(where: { $0.status.isActive }) {
            skateID = primary.id
            runnerID = primary.currentRunner?.id
        }
        if type.isGame { suggestSkills() }
    }

    /// 고른 날의 건강 앱 운동을 종류 상관없이 모두 불러온다(직접 고르기용). 권한 창은 띄우지 않는다.
    private func loadDayWorkouts() async {
        guard UserDefaults.standard.bool(forKey: HealthPrefs.enabledKey), HealthService.shared.isAvailable else { return }
        let day = Calendar.current.startOfDay(for: startsAt)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? Date()
        let ws = (try? await HealthService.shared.workouts(from: day, to: end)) ?? []
        dayWorkouts = ws.sorted { $0.start > $1.start }
    }

    /// 아직 기록과 이어지지 않은 팀 일정.
    private var openEvents: [TeamEvent] { teamEvents.filter { $0.sessionID == nil } }

    private func apply(_ plan: QuickPrefill.Plan, events: [TeamEvent]) {
        startsAt = plan.start
        minutes = plan.minutes
        if !iceMinutesEdited { iceMinutes = plan.minutes }
        switch plan.source {
        case .teamEvent(let i):
            let e = events[i]
            linkedEventID = e.id
            if let k = ActivityType(rawValue: e.kindRaw), k.isGame == type.isGame { type = k }
            if !e.rinkName.isEmpty {
                rinkName = e.rinkName
                if surface == .unknown { surface = .indoorRink }
            }
            if !e.opponent.isEmpty { opponent = e.opponent }
            prefillNote = "팀 일정(\(e.at.formatted(date: .omitted, time: .shortened)))으로 채웠어요. 맞는지만 봐 주세요."
        case .workout:
            linkedEventID = nil
            prefillNote = "Apple 건강 운동 기록으로 시간을 채웠어요. 맞는지만 봐 주세요."
        case .lastSession:
            prefillNote = "지난 \(type.title) 시간(\(minutesText(plan.minutes)))만큼 지금부터 거슬러 채웠어요."
        case .none:
            prefillNote = nil
        }
    }

    /// 건강 앱에 방금 끝난 하키·스케이트 운동이 있으면 그 시간으로 바꾼다. 사용자가 이미 고쳤으면 건드리지 않는다.
    /// 권한 창은 여기서 띄우지 않는다(연결은 설정에서만).
    private func prefillFromHealth(_ open: [TeamEvent]) async {
        guard UserDefaults.standard.bool(forKey: HealthPrefs.enabledKey), HealthService.shared.isAvailable else { return }
        let now = Date()
        guard let ws = try? await HealthService.shared.workouts(from: now.addingTimeInterval(-4 * 3600), to: now) else { return }
        let hockey = ws.filter { $0.activityName == "하키" || $0.activityName == "스케이팅" }.map { (start: $0.start, end: $0.end) }
        guard !hockey.isEmpty, !userTouchedTime, saved == nil else { return }
        let plan = QuickPrefill.plan(now: now, defaultMinutes: minutes, lastMinutes: nil,
                                     events: open.map { .init(start: $0.at, minutes: $0.minutes) }, workouts: hockey)
        if plan.source == .workout { apply(plan, events: open) }
    }

    private func suggestSkills() {
        let recommended = DiaryStore.recommendedSkills(before: startsAt, context: context)
        attempts = recommended.map { AttemptDraft(skillID: $0.id, name: $0.name) }
    }

    private func applyPicked(_ picked: [Skill]) {
        let ids = Set(picked.map(\.id))
        if type == .lesson {
            learnings.removeAll { !ids.contains($0.skillID) }
            for s in picked where !learnings.contains(where: { $0.skillID == s.id }) {
                learnings.append(LearningDraft(skillID: s.id, name: s.name))
            }
        } else {
            attempts.removeAll { !ids.contains($0.skillID) }
            for s in picked where !attempts.contains(where: { $0.skillID == s.id }) {
                attempts.append(AttemptDraft(skillID: s.id, name: s.name))
            }
        }
    }

    private func save() {
        let target: Session
        if let session {
            target = session
        } else {
            target = Session(type: type, startsAt: startsAt, minutes: minutes)
            context.insert(target)
        }
        target.type = type
        target.startsAt = startsAt
        target.endsAt = startsAt.addingTimeInterval(Double(minutes) * 60)
        target.surface = surface
        target.rinkName = rinkName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.iceFeel = surface == .unknown ? nil : iceFeel
        target.weatherMemo = weatherMemo
        target.moodBefore = moodBefore
        target.moodAfter = moodAfter
        target.fatigue = fatigue
        target.learnedToday = learnedToday
        target.coachNotes = type == .lesson ? coachNotes : target.coachNotes
        target.selfRating = type == .lesson ? selfRating : target.selfRating
        target.nextGoal = nextGoal
        target.opponent = opponent
        target.scoreFor = type.showsGameStats ? scoreFor : nil
        target.scoreAgainst = type.showsGameStats ? scoreAgainst : nil
        target.position = type.showsGameStats ? position : ""
        target.goals = type.showsGameStats ? goals : nil
        target.assists = type.showsGameStats ? assists : nil
        target.review = review
        target.plusMinus = type.showsGameStats && !playedGoalie ? plusMinus : nil
        target.penaltyMinutes = type.showsGameStats ? penaltyMinutes : nil
        target.shifts = type.showsGameStats ? shifts : nil
        target.playedGoalie = type.isGame && playedGoalie
        target.saves = target.playedGoalie ? saves : nil
        target.goalsAgainst = target.playedGoalie ? goalsAgainst : nil
        DiaryStore.replaceShots(for: target.id, with: type.isGame && !playedGoalie ? shots : [], context: context)

        // 기술 연결은 초안대로 다시 만든다. 통계는 연결에서 계산되므로 원본 손실이 없다.
        // 지금 종류에 해당하는 연결만 다시 만든다. 종류를 바꿔도 다른 쪽 기록은 지우지 않는다.
        if type == .lesson {
            for l in target.learnings { context.delete(l) }
            target.learnings = []
        }
        if type.isGame {
            for a in target.attempts { context.delete(a) }
            target.attempts = []
        }
        if type == .lesson {
            for d in learnings {
                guard let skill = allSkills.first(where: { $0.id == d.skillID }) else { continue }
                let l = SkillLearning()
                context.insert(l)
                l.skill = skill
                l.session = target
                l.feedback = d.feedback
                l.difficulty = d.difficulty
            }
        } else if type.isGame {
            for d in attempts {
                guard let skill = allSkills.first(where: { $0.id == d.skillID }), let tried = d.tried else { continue }
                let a = SkillAttempt()
                context.insert(a)
                a.skill = skill
                a.session = target
                a.tried = tried
                a.outcome = tried ? d.outcome : nil
                a.count = tried ? d.count : nil
                a.notes = tried ? d.notes : ""
            }
        }

        let skate = skates.first { $0.id == skateID }
        let runner = skate?.installations.compactMap(\.runner).first { $0.id == runnerID }
        DiaryStore.setUsage(for: target, skate: skate, runner: runner, iceMinutes: iceMinutes, context: context)
        // 실내·야외 링크장 이름은 다음 기록 추천용으로 남긴다. 폰드 장소는 남기지 않는다.
        if surface == .indoorRink || surface == .outdoorRink { RinkStore.touch(name: target.rinkName, context: context) }

        for photo in target.photos where removedPhotoIDs.contains(photo.id) {
            context.delete(photo)
        }
        for data in addedPhotos {
            let p = PhotoAsset(imageData: data)
            context.insert(p)
            p.session = target
        }

        if isNew, let id = linkedEventID, let e = teamEvents.first(where: { $0.id == id }), e.sessionID == nil {
            e.sessionID = target.id
        }

        context.saveOrReport()
        guard isNew else { dismiss(); return }
        // 새 기록은 완료 화면으로. 개인 최고는 이번 기록을 뺀 지난 기록과 견준다.
        let marks = (try? context.fetch(FetchDescriptor<ShotMark>())) ?? []
        let shotCounts = Dictionary(grouping: marks, by: \.sessionID).mapValues(\.count)
        let history = allSessions.filter { $0.id != target.id }.map { bestInput($0, shots: shotCounts[$0.id]) }
        let myShots = type.isGame && !playedGoalie && !shots.isEmpty ? shots.count : nil
        bests = PersonalBest.check(bestInput(target, shots: myShots), history: history)
        withAnimation { saved = target }
    }

    private func bestInput(_ s: Session, shots: Int?) -> BestInput {
        BestInput(type: s.type, minutes: s.minutes, goals: s.goals, assists: s.assists, saves: s.saves, shots: shots)
    }
}

/// 기술 사전에서 여러 개 고르기. 없으면 새로 만든다.
struct SkillPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Skill.name) private var skills: [Skill]

    @State var selected: Set<UUID>
    var onDone: ([Skill]) -> Void

    @State private var search = ""
    @State private var newName = ""

    private var grouped: [(String, [Skill])] {
        let filtered = search.isEmpty ? skills : skills.filter { $0.name.localizedCaseInsensitiveContains(search) }
        let dict = Dictionary(grouping: filtered, by: \.category)
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("새 기술 이름", text: $newName)
                    Button("추가") {
                        if let s = DiaryStore.skill(named: newName, context: context) {
                            context.saveOrReport()
                            selected.insert(s.id)
                            newName = ""
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            ForEach(grouped, id: \.0) { category, items in
                Section(category) {
                    ForEach(items) { skill in
                        // 행 선택 버튼과 ? 버튼을 나란히 둔다(버튼 안에 버튼을 넣으면 탭이 겹친다).
                        HStack(spacing: 4) {
                            Button {
                                if selected.contains(skill.id) { selected.remove(skill.id) } else { selected.insert(skill.id) }
                            } label: {
                                HStack {
                                    Text(skill.name).foregroundStyle(.primary)
                                    Spacer()
                                    if selected.contains(skill.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.neonPink)
                                    }
                                }
                                .frame(minHeight: Theme.touch)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityAddTraits(selected.contains(skill.id) ? .isSelected : [])
                            SkillInfoButton(name: skill.name)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "기술 찾기")
        .navigationTitle("기술 고르기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("완료 \(selected.count)") {
                    onDone(skills.filter { selected.contains($0.id) })
                    dismiss()
                }
            }
        }
    }
}
