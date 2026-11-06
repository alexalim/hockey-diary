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

    private let session: Session?

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

    init(newType: ActivityType, startsAt: Date = Date()) {
        session = nil
        _type = State(initialValue: newType)
        _startsAt = State(initialValue: startsAt)
        _minutes = State(initialValue: newType.isGame ? 90 : 60)
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
        _iceMinutes = State(initialValue: newType.isGame ? 90 : 60)
        _iceMinutesEdited = State(initialValue: false)
    }

    init(session: Session) {
        self.session = session
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
        _iceMinutes = State(initialValue: usage?.iceMinutes ?? session.minutes)
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
            return "기술마다 '못 써봄' 또는 '써봤어'를 골라줘. 못 써본 건 실패로 안 세."
        }
        if type == .lesson && !canSave {
            return "기술을 하나 고르거나 메모를 한 줄 남겨줘."
        }
        return nil
    }

    var body: some View {
        Form {
            basicsSection
            if type == .lesson { lessonSkillsSection }
            if type.isGame { gameSkillsSection }
            moodSection
            notesSection
            placeSection
            equipmentSection
            Section("사진") {
                PhotoPickerRow(existing: session?.photos ?? [], removedIDs: $removedPhotoIDs, added: $addedPhotos)
            }
            if let saveHint {
                Section { Text(saveHint).font(.footnote).foregroundStyle(Theme.neonPink) }
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
        .onChange(of: minutes) { _, new in if !iceMinutesEdited { iceMinutes = new } }
        .onChange(of: type) { _, new in if new.isGame && attempts.isEmpty { suggestSkills() } }
    }

    // MARK: - Sections

    private var basicsSection: some View {
        Section {
            LabeledChoice(title: "종류",
                          options: ActivityType.allCases.map { ChoiceOption(value: $0, title: $0.title, art: .symbol($0.systemImage)) },
                          selection: $type, columns: 4, minHeight: 68)
            DatePicker("시작", selection: $startsAt)
            Stepper("활동 시간 \(minutesText(minutes))", value: $minutes, in: 1...360, step: 5)
        }
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
                    ScalePicker(title: "체감 난도", low: "쉬움", high: "어려움", value: $draft.difficulty)
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
            Text("기술 없이 메모만 남겨도 저장돼.")
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
                    Text("시합에서 실제 써봤어?").font(.subheadline).foregroundStyle(.secondary)
                    ChoiceCards(options: [
                        ChoiceOption(value: Optional(false), title: "못 써봄", subtitle: "기회가 없었어", art: .symbol("moon.zzz")),
                        ChoiceOption(value: Optional(true), title: "써봤어", subtitle: "시도했어", art: .symbol("figure.hockey")),
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
                        OptionalNumberField(title: "시도 횟수", value: $draft.count)
                        TextField("어떤 상황이었어?", text: $draft.notes, axis: .vertical)
                    } else if draft.tried == false {
                        Text("괜찮아. 기회가 없었던 날도 기록이야. 실패로 세지 않아.")
                            .font(.caption).foregroundStyle(.secondary)
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
            Text("배운 기술, 써봤어?")
        } footer: {
            Text(attempts.isEmpty ? "최근 수업에서 배운 기술이 없으면 직접 추가해줘." : "최근 수업에서 배운 기술을 넣어뒀어. 빼거나 더해도 돼.")
        }
    }

    private var moodSection: some View {
        Section("기분·컨디션") {
            MoodPicker(title: "운동 전 기분", value: $moodBefore)
            MoodPicker(title: "운동 후 기분", value: $moodAfter)
            ScalePicker(title: "피로도", low: "가뿐", high: "녹초", value: $fatigue)
        }
    }

    private var notesSection: some View {
        Section {
            TextField("오늘의 배움 한 줄", text: $learnedToday, axis: .vertical)
            if type == .lesson {
                TextField("코치 메모", text: $coachNotes, axis: .vertical)
                TextField("다음 목표", text: $nextGoal, axis: .vertical)
                ScalePicker(title: "오늘 내 평가", low: "아쉬움", high: "만족", value: $selfRating)
            }
            if type.isGame {
                DisclosureGroup("경기 정보 더 기록하기", isExpanded: $showingMore) {
                    TextField("상대 팀", text: $opponent)
                    if type.showsGameStats {
                        OptionalNumberField(title: "우리 팀 점수", value: $scoreFor)
                        OptionalNumberField(title: "상대 팀 점수", value: $scoreAgainst)
                        TextField("포지션", text: $position)
                        OptionalNumberField(title: "골", value: $goals)
                        OptionalNumberField(title: "어시스트", value: $assists)
                    }
                    TextField("경기 회고", text: $review, axis: .vertical)
                    TextField("다음 목표", text: $nextGoal, axis: .vertical)
                }
            }
        } header: {
            Text("메모")
        } footer: {
            if type == .miniGame { Text("미니게임은 점수 없이 저장해도 돼.") }
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
            Text("어디서 탔어?")
        } footer: {
            if surface == .pond {
                Text("얼음이 안전한지는 앱이 알 수 없어. 현장 안내를 꼭 확인해줘. 정확한 위치는 저장하지 않아.")
            } else {
                Text("빙질은 내가 느낀 대로 남기면 돼.")
            }
        }
    }

    private var activeSkates: [Skate] { skates.filter { $0.status.isActive || $0.id == skateID } }

    private var equipmentSection: some View {
        Section {
            if skates.isEmpty {
                Text("락커 탭에 스케이트를 넣으면 연마하고 탄 시간이 저절로 쌓여.")
                    .font(.footnote).foregroundStyle(.secondary)
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
                Text("벤치에 있던 시간은 빼줘. 고른 스케이트·러너에만 쌓여.")
            }
        }
    }

    // MARK: - Actions

    private func prefill() {
        guard isNew, !didPrefill else { return }
        didPrefill = true
        // 최근 활동의 빙판 유형·링크장을 제안한다. 확인은 사용자 몫.
        if let last = allSessions.first {
            surface = last.surface
            rinkName = last.rinkName
        }
        if let primary = skates.first(where: { $0.isPrimary && $0.status.isActive }) ?? skates.first(where: { $0.status.isActive }) {
            skateID = primary.id
            runnerID = primary.currentRunner?.id
        }
        if type.isGame { suggestSkills() }
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

        context.saveOrReport()
        dismiss()
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
