import SwiftUI
import SwiftData
import HockeyCore

/// 드릴만 따로 여는 화면(홈 '드릴 시작', (+) 메뉴). 훈련 탭 안에서는 DrillSection을 바로 쓴다.
struct PracticeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: "TRAINING STUDIO", title: "드릴", subtitle: "루틴 하나, 드릴 하나.")
                DrillSection()
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

/// 훈련 탭의 드릴 갈래: 오늘의 집중, 나의 루틴, 하키 아카데미, 드릴 하나, 최근 드릴.
struct DrillSection: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PracticeRoutine.createdAt) private var routines: [PracticeRoutine]
    @Query(sort: \DrillLog.at, order: .reverse) private var logs: [DrillLog]
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]

    @State private var running: RoutineRun?
    @State private var pickingDrill = false
    @State private var editingRoutine: PracticeRoutine?
    @State private var creatingRoutine = false

    var body: some View {
        VStack(spacing: 12) {
            focusCard
            SectionHeader(title: "나의 루틴", trailing: routines.isEmpty ? nil : "루틴 편집", action: routines.isEmpty ? nil : { editingRoutine = routines.first })
            Card {
                ForEach(routines) { r in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                            Text("\(r.items.count)개 드릴 · 약 \(StarterRoutine.estimatedMinutes(r.items))분\(r.lastUsedAt.map { " · 마지막 \(ElapsedText.since($0))" } ?? "")")
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Button { editingRoutine = r } label: { AppIcon("slider.horizontal.3") }
                            .buttonStyle(.borderless).accessibilityLabel("\(r.name) 고치기")
                        Button {
                            running = RoutineRun(routine: r)
                        } label: {
                            Label("시작", icon: "play.fill").font(.footnote.bold())
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(Theme.neonPink, in: Capsule()).foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(r.items.isEmpty)
                    }
                    .frame(minHeight: Theme.touch)
                }
                Button { creatingRoutine = true } label: { Label("새 루틴 만들기", icon: "plus") }
            }
            SectionHeader(title: "하키 아카데미")
            AcademyGrid { pickingDrill = true }
            Card {
                CardHeader(title: "드릴 하나만", systemImage: "figure.hockey")
                Text("루틴 없이 지금 하고 싶은 드릴만 골라서 세요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                Button { pickingDrill = true } label: {
                    Label("드릴 고르기", icon: "magnifyingglass").frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.bordered)
            }
            recentCard
        }
        .onAppear { PracticeStore.seedRoutinesIfNeeded(context) }
        .fullScreenCover(item: $running) { run in
            NavigationStack { RoutineRunView(run: run) }
        }
        .sheet(isPresented: $pickingDrill) {
            NavigationStack {
                DrillPickerView(title: "드릴 고르기") { drill in
                    pickingDrill = false
                    running = RoutineRun(single: drill)
                }
            }
        }
        .sheet(item: $editingRoutine) { r in NavigationStack { RoutineEditorView(routine: r) } }
        .sheet(isPresented: $creatingRoutine) { NavigationStack { RoutineEditorView(routine: nil) } }
    }

    /// 오늘의 집중: 마지막 기록의 '다음 목표'를 오늘 연습으로 잇는다. 목표가 없으면 첫 루틴을 권한다.
    @ViewBuilder
    private var focusCard: some View {
        let goal = sessions.first { !$0.nextGoal.isEmpty }?.nextGoal
        let first = routines.first { !$0.items.isEmpty }
        Card(tint: Theme.cobalt) {
            Text("TODAY'S FOCUS").font(.system(size: 12, weight: .semibold)).tracking(0.6).foregroundStyle(.white.opacity(0.75))
            Text(goal ?? "오늘은 뭘 다듬을까요?").font(.title3.bold()).foregroundStyle(.white)
            Text(goal == nil ? "수업 기록에 '다음 목표'를 적어 두면 다음 연습 때 그 목표가 먼저 보여요." : "지난 수업의 다음 목표를 오늘의 드릴로 이어가요.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            if let first {
                Button { running = RoutineRun(routine: first) } label: {
                    Text("오늘의 훈련 시작").font(.headline).foregroundStyle(Theme.cobalt)
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                        .background(.white, in: RoundedRectangle(cornerRadius: Theme.buttonCorner, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var recentCard: some View {
        let recent = Array(logs.prefix(8))
        Card {
            CardHeader(title: "최근 드릴", systemImage: "clock.arrow.circlepath",
                       trailing: logs.isEmpty ? nil : "드릴 한 날 \(DrillStats.practiceDays(logs.compactMap(\.entry)))일")
            if recent.isEmpty {
                EmptyHint(text: "아직 드릴 기록이 없어요. 위에서 루틴을 시작해 보세요.")
            }
            ForEach(recent) { log in
                HStack {
                    AppIcon(log.offIce ? "house.fill" : "snowflake").foregroundStyle(Theme.accent).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                        Text("\(log.at.dayTitle) \(log.at.timeTitle)\(log.skillName.isEmpty ? "" : " · \(log.skillName)")")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Text(log.amountText).font(.subheadline.bold())
                }
                .frame(minHeight: 36)
            }
        }
    }
}

/// 한 번의 연습 진행 상태(루틴 전체 또는 드릴 하나).
final class RoutineRun: Identifiable, ObservableObject {
    let id = UUID()
    let routine: PracticeRoutine?
    let items: [RoutineItem]
    @Published var index = 0

    init(routine: PracticeRoutine) {
        self.routine = routine
        self.items = routine.items
    }

    init(single drill: Drill) {
        self.routine = nil
        self.items = [RoutineItem(drillKey: drill.key, target: drill.defaultTarget)]
    }

    var current: (Drill, RoutineItem)? {
        guard items.indices.contains(index), let d = DrillCatalog.drill(items[index].drillKey) else { return nil }
        return (d, items[index])
    }
}

/// 드릴 진행 화면: 큰 타이머(분) 또는 큰 횟수 버튼. 끝나면 기록으로 남긴다.
struct RoutineRunView: View {
    @Environment(AppJumper.self) private var jumper: AppJumper?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var run: RoutineRun

    @State private var count = 0
    @State private var secondsLeft = 0
    @State private var timerOn = false
    @State private var done: [String] = []
    @State private var finishedTick = 0
    @State private var repTick = 0
    /// 소리로 세기. 기본 켬, 한 번 끄면 기억한다.
    @AppStorage("practiceVoice") private var voiceOn = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let (drill, item) = run.current {
                drillScreen(drill, item)
            } else {
                summaryScreen
            }
        }
        .screenBackground()
        .navigationTitle(run.routine?.name ?? "드릴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("그만") { dismiss() } }
        }
        .onReceive(timer) { _ in
            guard timerOn, secondsLeft > 0 else { return }
            secondsLeft -= 1
            if voiceOn && secondsLeft == 60 { Speaker.shared.say("1분 남았어요") }
            if voiceOn && secondsLeft == 10 { Speaker.shared.say("10초") }
            if secondsLeft == 0 {
                timerOn = false; finishedTick += 1
                if voiceOn { Speaker.shared.say("끝. 잘했어요") }
            }
        }
        .sensoryFeedback(.success, trigger: finishedTick)
        .sensoryFeedback(.selection, trigger: repTick)
        // 다음 드릴로 넘어갈 땐 +1과 다른 묵직한 진동.
        .sensoryFeedback(.impact(weight: .heavy), trigger: run.index)
        .onAppear {
            resetForCurrent()
            if let state = activityState { RoutineActivity.shared.start(routineName: run.routine?.name ?? "드릴", state: state) }
        }
        .onChange(of: run.index) { _, _ in pushActivity() }
        .onChange(of: timerOn) { _, _ in pushActivity() }
        .onChange(of: count) { _, _ in pushActivity() }
        .onDisappear { RoutineActivity.shared.end() }
    }

    /// 잠금 화면·다이내믹 아일랜드에 보여 줄 지금 상태. 드릴이 끝났으면 nil.
    private var activityState: RoutineActivityAttributes.ContentState? {
        guard let (drill, item) = run.current else { return nil }
        return .init(drillTitle: drill.title, skillName: drill.skillName, index: run.index + 1, total: run.items.count,
                     endDate: timerOn && secondsLeft > 0 ? Date().addingTimeInterval(TimeInterval(secondsLeft)) : nil,
                     secondsLeft: secondsLeft, count: count, target: item.target, isMinutes: drill.unit == .minutes)
    }

    private func pushActivity() {
        if let state = activityState { RoutineActivity.shared.update(state) } else { RoutineActivity.shared.end() }
    }

    private func drillScreen(_ drill: Drill, _ item: RoutineItem) -> some View {
        VStack(spacing: 16) {
            HStack {
                if run.items.count > 1 {
                    Text("\(run.index + 1) / \(run.items.count)").font(.caption.bold()).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Toggle(isOn: $voiceOn) { Label("소리로 세기", icon: voiceOn ? "speaker.wave.2.fill" : "speaker.slash") }
                    .toggleStyle(.button).font(.caption.bold()).tint(Theme.cobalt)
            }
            Card(tint: Theme.cobalt) {
                Text(drill.skillName).font(.caption.bold()).foregroundStyle(.white.opacity(0.85))
                Text(drill.title).font(.title2.bold()).foregroundStyle(.white)
                Text(drill.howTo).font(.subheadline).foregroundStyle(.white)
            }
            if drill.unit == .minutes {
                timerBlock(item)
            } else {
                counterBlock(item)
            }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    saveAndNext(drill, amount: drill.unit == .minutes ? max(0, item.target - secondsLeft / 60 - (secondsLeft % 60 > 0 ? 1 : 0)) : count, skipped: true)
                } label: { Text("건너뛰기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                    .buttonStyle(.bordered)
                Button {
                    saveAndNext(drill, amount: drill.unit == .minutes ? doneMinutes(item) : count, skipped: false)
                } label: { Text(run.index + 1 < run.items.count ? "다음 드릴" : "끝내고 저장").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                    .buttonStyle(PinkButtonStyle())
            }
        }
        .padding(16)
    }

    private func timerBlock(_ item: RoutineItem) -> some View {
        VStack(spacing: 12) {
            Text(String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60))
                .font(.system(size: 72, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(secondsLeft == 0 ? Theme.success : Theme.title)
            Text(secondsLeft == 0 ? "다 했어요! 다음으로 넘어가요." : "목표 \(item.target)분").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 10) {
                Button { timerOn.toggle() } label: {
                    Label(timerOn ? "잠깐" : (secondsLeft == item.target * 60 ? "시작" : "계속"), icon: timerOn ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent).tint(Theme.cobalt).disabled(secondsLeft == 0)
                Button { timerOn = false; secondsLeft = item.target * 60 } label: {
                    AppIcon("arrow.counterclockwise").frame(width: 56, height: 56)
                }
                .buttonStyle(.bordered).accessibilityLabel("처음부터")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    private func counterBlock(_ item: RoutineItem) -> some View {
        VStack(spacing: 12) {
            // 큰 숫자는 하나만: 목표 전엔 남은 횟수, 다 하면 한 횟수.
            let left = max(item.target - count, 0)
            Text("\(count >= item.target ? count : left)")
                .font(.system(size: 96, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(count >= item.target ? Theme.success : Theme.title)
                .contentTransition(.numericText())
                .accessibilityLabel(count >= item.target ? "\(count)번 했어요" : "\(left)번 남았어요")
            Text(count >= item.target ? "목표 \(item.target)번 다 했어요!" : "번 남았어요 · 지금 \(count)번").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 10) {
                Button { if count > 0 { count -= 1 } } label: { AppIcon("minus").frame(width: 64, height: 64) }
                    .buttonStyle(.bordered).accessibilityLabel("하나 빼기")
                Button {
                    withAnimation(.snappy) { count += 1 }
                    repTick += 1
                    if count == item.target { finishedTick += 1 }
                    if voiceOn, let line = Speaker.repLine(count: count, target: item.target) { Speaker.shared.say(line) }
                } label: {
                    Text("+1").font(.title.bold()).frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.borderedProminent).tint(Theme.cobalt)
                Button {
                    let before = count
                    withAnimation(.snappy) { count += 5 }
                    repTick += 1
                    if before < item.target && count >= item.target { finishedTick += 1 }
                    if voiceOn { Speaker.shared.say(count >= item.target && before < item.target ? "\(count)번. 목표 다 했어요" : "\(count)번") }
                } label: { Text("+5").font(.headline).frame(width: 64, height: 64) }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    private var summaryScreen: some View {
        VStack(spacing: 16) {
            AppIcon("checkmark.seal.fill", size: 64.4).foregroundStyle(Theme.neonPink)
            Text("오늘 훈련 끝!").font(.title.bold()).foregroundStyle(Theme.title)
            if done.isEmpty {
                Text("저장한 드릴이 없어요.").foregroundStyle(Theme.inkSecondary)
            } else {
                Card {
                    ForEach(done, id: \.self) { Text("· \($0)").font(.subheadline) }
                }
            }
            HStack(spacing: 8) {
                Text("오늘 한 드릴은 성장 탭의 기술 성장에서 볼 수 있어요.").font(.caption).foregroundStyle(Theme.inkSecondary)
                Button("성장 보기") { dismiss(); jumper?.go(.tab(.growth)) }.font(.caption.bold()).tint(Theme.accentText)
            }
            Spacer()
            Button { dismiss() } label: { Text("닫기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                .buttonStyle(PinkButtonStyle())
        }
        .padding(16)
    }

    private func doneMinutes(_ item: RoutineItem) -> Int {
        let used = item.target * 60 - secondsLeft
        return max(0, Int((Double(used) / 60).rounded()))
    }

    private func resetForCurrent() {
        count = 0
        timerOn = false
        secondsLeft = (run.current?.1.target ?? 1) * 60
    }

    private func saveAndNext(_ drill: Drill, amount: Int, skipped: Bool) {
        if amount > 0 {
            context.insert(DrillLog(drill: drill, amount: amount))
            done.append("\(drill.title) \(amount)\(drill.unit.title)")
        }
        if run.index + 1 >= run.items.count {
            run.routine?.lastUsedAt = Date()
            context.saveOrReport()
            run.index += 1
        } else {
            run.index += 1
            resetForCurrent()
        }
    }
}

/// 드릴 고르기(기술별로 묶음, 집에서 하는 것 따로).
struct DrillPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var onPick: (Drill) -> Void
    @State private var search = ""

    /// 드릴 이름·기술 이름·하는 법에서 찾는다. 띄어쓰기는 무시.
    private func matches(_ d: Drill) -> Bool {
        let q = search.replacingOccurrences(of: " ", with: "")
        guard !q.isEmpty else { return true }
        return [d.title, d.skillName, d.howTo].contains { $0.replacingOccurrences(of: " ", with: "").localizedCaseInsensitiveContains(q) }
    }

    private var groups: [(String, [Drill])] {
        let on = Dictionary(grouping: DrillCatalog.onIce.filter(matches)) { d in SkillGuide.entries.first { $0.name == d.skillName }?.category ?? "기타" }
        let order = ["스케이팅", "퍽 컨트롤", "슈팅", "게임 운영", "기타"]
        var out = order.compactMap { k in on[k].map { (k, $0) } }
        let off = DrillCatalog.offIce.filter(matches)
        if !off.isEmpty { out.append(("집에서 (오프아이스)", off)) }
        return out
    }

    var body: some View {
        List {
            if groups.isEmpty {
                Text("'\(search)'에 맞는 드릴이 없어요. 기술 이름(예: 스톱, 크로스오버)으로 찾아보세요.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            ForEach(groups, id: \.0) { name, drills in
                Section(name) {
                    ForEach(drills) { d in
                        Button { onPick(d) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(d.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Spacer()
                                    Text(d.targetText()).font(.caption.bold()).foregroundStyle(Theme.accent)
                                }
                                Text("\(d.skillName) · \(d.howTo)").font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(2)
                            }
                            .frame(minHeight: Theme.touch)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "드릴·기술 이름으로 찾기")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
    }
}

/// 루틴 만들기·고치기: 드릴 순서와 목표량.
struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let routine: PracticeRoutine?

    @State private var name = ""
    @State private var items: [RoutineItem] = []
    @State private var adding = false
    @State private var loaded = false
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section { TextField("루틴 이름 (예: 수업 전 몸풀기)", text: $name) }
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                    if let d = DrillCatalog.drill(it.drillKey) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.title).font(.subheadline.bold())
                                Text(d.skillName).font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer()
                            Stepper(d.targetText(it.target), value: Binding(
                                get: { items[i].target }, set: { items[i].target = max(1, $0) }
                            ), in: 1...200, step: d.unit == .minutes ? 1 : 5)
                            .labelsHidden()
                            Text(d.targetText(it.target)).font(.caption.bold()).frame(width: 44)
                        }
                    }
                }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { items.remove(atOffsets: $0) }
                Button { adding = true } label: { Label("드릴 추가", icon: "plus") }
            } header: {
                Text("드릴 순서 · 약 \(StarterRoutine.estimatedMinutes(items))분")
            } footer: {
                Text("길게 눌러 순서를 바꾸고, 왼쪽으로 밀어 빼요.")
            }
            if routine != nil {
                Section { Button("이 루틴 지우기", role: .destructive) { confirmingDelete = true } }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(routine == nil ? "새 루틴" : "루틴 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
            }
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                DrillPickerView(title: "드릴 추가") { d in
                    items.append(RoutineItem(drillKey: d.key, target: d.defaultTarget))
                    adding = false
                }
            }
        }
        .confirmationDialog("이 루틴을 지울까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("지우기", role: .destructive) {
                if let routine { context.delete(routine); context.saveOrReport() }
                dismiss()
            }
        } message: { Text("연습 기록은 그대로 남아요.") }
        .onAppear {
            guard !loaded, let routine else { return }
            loaded = true
            name = routine.name
            items = routine.items
        }
    }

    private func save() {
        if let routine {
            routine.name = name.trimmingCharacters(in: .whitespaces)
            routine.items = items
        } else {
            context.insert(PracticeRoutine(name: name.trimmingCharacters(in: .whitespaces), items: items))
        }
        context.saveOrReport()
        dismiss()
    }
}
