import SwiftUI
import SwiftData
import HockeyCore

/// 모든 러너 세트.
struct RunnerListView: View {
    @Query(sort: \RunnerSet.createdAt) private var runners: [RunnerSet]
    var focusSharpening = false
    @State private var adding = false

    var body: some View {
        List {
            if runners.isEmpty {
                Text("아직 러너(날)가 없어. 스케이트 화면에서 추가하면 바로 달려.")
                    .foregroundStyle(.secondary)
            }
            ForEach(runners.filter { $0.retiredAt == nil }) { r in
                NavigationLink { RunnerDetailView(runner: r) } label: {
                    RunnerRow(runner: r, badge: r.needsReplacement ? "교체 시기" : r.installedSkate.map { "\($0.name)에 장착" })
                }
            }
            let retired = runners.filter { $0.retiredAt != nil }
            if !retired.isEmpty {
                Section("교체한 날") {
                    ForEach(retired) { r in
                        NavigationLink { RunnerDetailView(runner: r) } label: {
                            RunnerRow(runner: r, badge: r.retiredAt.map { "\($0.formatted(.dateTime.year().month())) 교체" })
                        }
                    }
                }
            }
        }
        .navigationTitle(focusSharpening ? "연마" : "러너(날)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("러너 추가")
            }
        }
        .sheet(isPresented: $adding) { NavigationStack { RunnerEditorView(runner: nil, installOn: nil) } }
    }
}

struct RunnerRow: View {
    @Environment(\.modelContext) private var context
    let runner: RunnerSet
    var badge: String?

    var body: some View {
        HStack {
            if let h = runner.currentHollow.flatMap(Hollow.init(label:)) {
                HollowGlyph(hollow: h).frame(width: 34, height: 34)
            } else {
                Image(systemName: "minus").frame(width: 34, height: 34).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(runner.name).font(.subheadline.bold())
                Text("RoH \(runner.currentHollow.map { "\($0)\"" } ?? "미확인") · \(DiaryStore.sharpeningSummary(runner, context: context))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let badge {
                Text(badge).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Theme.cobaltSoft, in: Capsule())
            }
        }
        .frame(minHeight: Theme.touch)
        .accessibilityElement(children: .combine)
    }
}

/// 러너 세트 등록·수정.
struct RunnerEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let runner: RunnerSet?
    let installOn: Skate?

    @State private var name = ""
    @State private var model = ""
    @State private var memo = ""
    enum CheckBy: String, CaseIterable { case hours, sessions
        var title: String { self == .hours ? "탄 시간" : "탄 횟수" }
    }
    @State private var useThreshold = false
    @State private var checkBy: CheckBy = .sessions
    @State private var thresholdHours = 10
    @State private var thresholdSessions = 8
    enum ReplaceBy: String, CaseIterable { case sharpenings, months
        var title: String { self == .sharpenings ? "연마 횟수" : "쓴 기간" }
    }
    @State private var useReplace = false
    @State private var replaceBy: ReplaceBy = .sharpenings
    @State private var replaceSharpenings = 20
    @State private var replaceMonths = 12
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextField("이름 (예: A세트, 스텔스)", text: $name)
                TextField("모델 (예: Step Blacksteel)", text: $model)
            } header: {
                Text("러너(날)")
            } footer: {
                Text("러너는 부츠에 끼우는 날이야. 연마는 이 날을 가는 거야. 그래서 연마 기록과 알림도 날마다 따로 세.")
            }
            Section {
                Toggle("연마 점검 알림 받기", isOn: $useThreshold)
                if useThreshold {
                    ChoiceCards(options: [
                        ChoiceOption(value: CheckBy.sessions, title: "탄 횟수", art: .symbol("number")),
                        ChoiceOption(value: CheckBy.hours, title: "탄 시간", art: .symbol("clock")),
                    ], selection: $checkBy, columns: 2, minHeight: 60)
                    if checkBy == .hours {
                        Stepper("연마하고 \(thresholdHours)시간 타면 알려줘", value: $thresholdHours, in: 1...100)
                    } else {
                        Stepper("연마하고 \(thresholdSessions)번 타면 알려줘", value: $thresholdSessions, in: 1...60)
                    }
                }
            } header: {
                Text("연마 점검 알림")
            } footer: {
                Text("이 날로 정해둔 만큼 타면 다시 갈 때가 됐다고 알려줘. 정해진 주기는 없으니 내 느낌대로 정하면 돼.")
            }
            Section {
                Toggle("날 교체 알림 받기", isOn: $useReplace)
                if useReplace {
                    ChoiceCards(options: [
                        ChoiceOption(value: ReplaceBy.sharpenings, title: "연마 횟수", art: .symbol("wrench.and.screwdriver")),
                        ChoiceOption(value: ReplaceBy.months, title: "쓴 기간", art: .symbol("calendar")),
                    ], selection: $replaceBy, columns: 2, minHeight: 60)
                    if replaceBy == .sharpenings {
                        Stepper("연마 \(replaceSharpenings)번 하면 알려줘", value: $replaceSharpenings, in: 5...100)
                    } else {
                        Stepper("\(replaceMonths)개월 쓰면 알려줘", value: $replaceMonths, in: 1...48)
                    }
                }
            } header: {
                Text("날 교체 알림")
            } footer: {
                Text("날은 갈수록 깎여. 얼마나 쓰면 바꿀지는 사람마다 달라. 내 기준으로 정해줘.")
            }
            Section("메모") { TextField("메모", text: $memo, axis: .vertical) }
        }
        .navigationTitle(runner == nil ? "러너(날) 추가" : "러너(날) 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard !loaded, let runner else { return }
            loaded = true
            name = runner.name; model = runner.model; memo = runner.memo
            if let t = runner.checkThresholdMinutes { useThreshold = true; checkBy = .hours; thresholdHours = max(1, t / 60) }
            if let n = runner.checkThresholdSessions { useThreshold = true; checkBy = .sessions; thresholdSessions = n }
            if let n = runner.replaceAfterSharpenings { useReplace = true; replaceBy = .sharpenings; replaceSharpenings = n }
            if let m = runner.replaceAfterMonths { useReplace = true; replaceBy = .months; replaceMonths = m }
        }
    }

    private func save() {
        let target: RunnerSet
        if let runner {
            target = runner
        } else {
            target = RunnerSet(name: "")
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.model = model
        target.memo = memo
        target.checkThresholdMinutes = useThreshold && checkBy == .hours ? thresholdHours * 60 : nil
        target.checkThresholdSessions = useThreshold && checkBy == .sessions ? thresholdSessions : nil
        target.replaceAfterSharpenings = useReplace && replaceBy == .sharpenings ? replaceSharpenings : nil
        target.replaceAfterMonths = useReplace && replaceBy == .months ? replaceMonths : nil
        context.saveOrReport()
        if runner == nil, let installOn {
            DiaryStore.install(target, on: installOn, context: context)
        }
        dismiss()
    }
}

/// 러너 상세 (S12-1). 연마 이력과 점검 기준.
struct RunnerDetailView: View {
    @Environment(\.modelContext) private var context
    let runner: RunnerSet

    @State private var addingSharpening = false
    @State private var editing = false
    @State private var confirmingRetire = false

    var body: some View {
        let since = DiaryStore.minutesSinceSharpening(runner, context: context)
        let rides = DiaryStore.sessionsSinceSharpening(runner, context: context)
        List {
            Section {
                HStack(spacing: 16) {
                    if let h = runner.currentHollow.flatMap(Hollow.init(label:)) {
                        HollowGlyph(hollow: h).frame(width: 70, height: 70)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(runner.name).font(.title3.bold())
                        Text("현재 RoH \(runner.currentHollow.map { "\($0)\"" } ?? "미확인")").font(.subheadline)
                        Text(runner.installedSkate.map { "\($0.name)에 장착 중" } ?? "보관 중")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("마지막 연마")
                    Spacer()
                    if let last = runner.lastSharpening {
                        Text("\(ElapsedText.since(last.at)) · \(last.at.formatted(.dateTime.month().day()))").bold()
                    } else {
                        Text("기록 없음").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("그 뒤로 탄 횟수")
                    Spacer()
                    Text(rides == 0 ? "아직 안 탔어" : "\(rides)번").bold()
                }
                HStack {
                    Text("그 뒤로 탄 시간")
                    Spacer()
                    Text(minutesText(since)).bold()
                }
                if let n = runner.checkThresholdSessions {
                    ProgressView(value: Double(min(rides, n)), total: Double(n)) {
                        Text("\(n)번 타면 알림").font(.caption)
                    }
                    .tint(rides >= n ? Theme.neonPink : Theme.accent)
                } else if let t = runner.checkThresholdMinutes {
                    ProgressView(value: min(Double(since), Double(t)), total: Double(t)) {
                        Text("\(minutesText(t)) 타면 알림").font(.caption)
                    }
                    .tint(since >= t ? Theme.neonPink : Theme.accent)
                }
            } footer: {
                Text("기록할 때 이 러너를 고른 활동만 세. 시간은 '실제로 탄 시간'으로 더해.")
            }

            Section {
                HStack {
                    Text("날 상태")
                    Spacer()
                    Text(runner.lifeSummary).bold()
                }
                if let n = runner.replaceAfterSharpenings {
                    ProgressView(value: Double(min(runner.sharpenings.count, n)), total: Double(n)) {
                        Text("연마 \(n)번 하면 교체 알림").font(.caption)
                    }
                    .tint(runner.needsReplacement ? Theme.neonPink : Theme.accent)
                } else if let m = runner.replaceAfterMonths {
                    let used = RunnerLife.monthsUsed(since: runner.firstUsedAt)
                    ProgressView(value: Double(min(used, m)), total: Double(m)) {
                        Text("\(m)개월 쓰면 교체 알림").font(.caption)
                    }
                    .tint(runner.needsReplacement ? Theme.neonPink : Theme.accent)
                }
                if let retired = runner.retiredAt {
                    Text("\(retired.formatted(date: .abbreviated, time: .omitted))에 교체했어.").foregroundStyle(.secondary)
                } else {
                    Button("이 날 교체했어") { confirmingRetire = true }
                }
            } header: {
                Text("날 교체")
            } footer: {
                Text("교체했다고 하면 이 러너는 '교체한 날'로 옮겨져. 지난 기록은 그대로 남아.")
            }

            Section {
                Button { addingSharpening = true } label: { Label("연마 기록 추가", systemImage: "plus") }
                ForEach(runner.sharpenings.sorted { $0.at > $1.at }) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.at.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.bold())
                            Spacer()
                            Text(log.hollow.isEmpty ? "RoH 미확인" : "\(log.hollow)\"").font(.subheadline)
                        }
                        let feels = [("그립", log.grip), ("활주", log.glide), ("스톱", log.stop), ("턴", log.turn)]
                            .compactMap { n, v in v.map { "\(n) \($0)" } }
                        if !feels.isEmpty { Text(feels.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                        if !log.shop.isEmpty { Text(log.shop).font(.caption).foregroundStyle(.secondary) }
                        if !log.memo.isEmpty { Text(log.memo).font(.caption) }
                    }
                }
            } header: {
                Text("연마 이력")
            }
        }
        .navigationTitle("러너")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("고치기") { editing = true } } }
        .sheet(isPresented: $addingSharpening) { NavigationStack { SharpeningEditorView(runner: runner) } }
        .confirmationDialog("이 날을 교체했어?", isPresented: $confirmingRetire, titleVisibility: .visible) {
            Button("교체했어") {
                DiaryStore.uninstall(runner, context: context)
                runner.retiredAt = Date()
                context.saveOrReport()
            }
        } message: {
            Text("부츠에서 떼고 '교체한 날'로 옮길게. 새 날은 스케이트 화면에서 추가해줘.")
        }
        .sheet(isPresented: $editing) { NavigationStack { RunnerEditorView(runner: runner, installOn: nil) } }
    }
}

/// 연마 기록 (S13). 홀로우를 단면 그림 카드로 고른다.
struct SharpeningEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let runner: RunnerSet

    @State private var at = Date()
    @State private var hollowLabel: String?
    @State private var customHollow = ""
    @State private var shop = ""
    @State private var grip: Int?
    @State private var glide: Int?
    @State private var stop: Int?
    @State private var turn: Int?
    @State private var memo = ""

    private var chosenHollow: Hollow? {
        if !customHollow.isEmpty { return Hollow(label: customHollow) }
        return hollowLabel.flatMap(Hollow.init(label:))
    }

    private var customInvalid: Bool { !customHollow.isEmpty && Hollow(label: customHollow) == nil }

    var body: some View {
        Form {
            Section { DatePicker("연마일", selection: $at, displayedComponents: .date) }
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Hollow.presets, id: \.self) { h in
                        HollowCard(hollow: h, selected: customHollow.isEmpty && hollowLabel == h.label) {
                            customHollow = ""
                            hollowLabel = hollowLabel == h.label ? nil : h.label
                        }
                    }
                }
                .padding(.vertical, 4)
                TextField("직접 입력 (예: 9/16, 0.55)", text: $customHollow)
                    .keyboardType(.numbersAndPunctuation)
                if customInvalid {
                    Text("인치 값으로 적어줘. 예: 5/8, 0.55").font(.caption).foregroundStyle(Theme.neonPink)
                }
            } header: {
                Text("홀로우 (RoH)")
            } footer: {
                Text("숫자가 작을수록 홈이 깊어. 그림은 깊이 차이만 보여주는 예시야. 모르면 비워둬도 돼.")
            }
            Section("어디서?") { TextField("연마한 곳 (업체·링크장)", text: $shop) }
            Section("연마 후 느낌") {
                ScalePicker(title: "그립", low: "약함", high: "강함", value: $grip)
                ScalePicker(title: "활주", low: "무거움", high: "잘 나감", value: $glide)
                ScalePicker(title: "스톱", low: "밀림", high: "잘 섬", value: $stop)
                ScalePicker(title: "턴", low: "어려움", high: "편함", value: $turn)
                TextField("메모", text: $memo, axis: .vertical)
            }
        }
        .navigationTitle("연마 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("저장", action: save).disabled(customInvalid) }
        }
    }

    private func save() {
        let label = chosenHollow?.label ?? ""
        let log = SharpeningLog(hollow: label, at: at)
        context.insert(log)
        log.runner = runner
        log.shop = shop
        log.grip = grip; log.glide = glide; log.stop = stop; log.turn = turn
        log.memo = memo
        // 가장 최근 연마일 때만 현재 홀로우를 바꾼다.
        let latest = runner.sharpenings.map(\.at).max() ?? at
        if !label.isEmpty && at >= latest { runner.currentHollow = label }
        context.saveOrReport()
        dismiss()
    }
}

/// 날 단면 카드.
struct HollowCard: View {
    let hollow: Hollow
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HollowGlyph(hollow: hollow).frame(height: 54)
                Text(hollow.display).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .foregroundStyle(Theme.title)
            .background(selected ? Theme.cobaltSoft : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Theme.neonPink : Color.secondary.opacity(0.25), lineWidth: selected ? 2.5 : 1))
            .overlay(alignment: .topTrailing) {
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.neonPink).padding(4) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("홀로우 \(hollow.label)인치")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 날 아랫면의 U자 홈 단면. 깊이는 Hollow.relativeDepth(기하 공식)에서만 나온다 (EQ-04).
struct HollowGlyph: View {
    let hollow: Hollow

    var body: some View {
        BladeSection(relativeDepth: hollow.relativeDepth)
            .fill(LinearGradient(colors: [Color(light: 0xB8C4D6, dark: 0x8A97AA), Color(light: 0x6D7B91, dark: 0x5B6779)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(BladeSection(relativeDepth: hollow.relativeDepth).stroke(Theme.deepNavy.opacity(0.6), lineWidth: 1))
            .aspectRatio(0.9, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

struct BladeSection: Shape {
    var relativeDepth: Double

    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.6
        let x0 = rect.midX - w / 2, x1 = rect.midX + w / 2
        let maxDepth = rect.height * 0.45
        let depth = maxDepth * relativeDepth
        var p = Path()
        p.move(to: CGPoint(x: x0, y: rect.minY))
        p.addLine(to: CGPoint(x: x1, y: rect.minY))
        p.addLine(to: CGPoint(x: x1, y: rect.maxY))
        // 2차 곡선의 꼭짓점 깊이는 제어점 깊이의 절반이다.
        p.addQuadCurve(to: CGPoint(x: x0, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY - depth * 2))
        p.closeSubpath()
        return p
    }
}
