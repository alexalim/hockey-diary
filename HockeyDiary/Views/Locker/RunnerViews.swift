import SwiftUI
import SwiftData
import HockeyCore

// 러너·연마 화면 — 일기처럼 다이어리 속지 톤(종이 카드·테이프·스티커, JournalParts.swift). 저장 값은 그대로.

/// 카드마다 돌려 쓰는 테이프 색과 각도.
private enum RunnerPaper {
    static let tapes: [Color] = [Theme.tapePink, Theme.tapeMint, Theme.tapeYellow]
    static let angles: [Double] = [-4, 3, -2, 5, -5]
    static func tape(_ i: Int) -> Color { tapes[i % tapes.count] }
    static func angle(_ i: Int) -> Double { angles[i % angles.count] }
}

/// 종이 카드 안의 "이름 · 값" 한 줄.
private struct RunnerValueRow: View {
    var title: String
    var value: String
    var soft = false

    var body: some View {
        HStack {
            Text(title).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(soft ? .regular : .bold))
                .foregroundStyle(soft ? Theme.paperInkSoft : Theme.paperInk)
        }
    }
}

/// 종이 카드 아래 작은 설명 글.
private struct RunnerNote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 종이 위 입력 칸 바탕.
private extension View {
    func runnerField() -> some View {
        self
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Theme.paperInk)
            .tint(Theme.accentText)
            .padding(10)
            .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 모든 러너 세트.
struct RunnerListView: View {
    @Query(sort: \RunnerSet.createdAt) private var runners: [RunnerSet]
    var focusSharpening = false
    @State private var adding = false

    var body: some View {
        let active = runners.filter { $0.retiredAt == nil }
        let retired = runners.filter { $0.retiredAt != nil }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if runners.isEmpty {
                    EmptyHint(text: "아직 러너(날)가 없어요. 스케이트 화면에서 추가하면 바로 달려요.", systemImage: "skateblade",
                              link: EmptyLink("스케이트로") { SkateListView() })
                }
                ForEach(Array(active.enumerated()), id: \.element.id) { i, r in
                    runnerCard(r, index: i, badge: r.needsReplacement ? "교체 시기" : r.installedSkate.map { "\($0.name)에 장착" })
                }
                if !retired.isEmpty {
                    PaperTitle(text: "교체한 날", systemImage: "archivebox")
                        .padding(.top, 8)
                    ForEach(Array(retired.enumerated()), id: \.element.id) { i, r in
                        runnerCard(r, index: active.count + i, badge: r.retiredAt.map { "\($0.formatted(.dateTime.year().month())) 교체" })
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle(focusSharpening ? "연마" : "러너(날)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { AppIcon("plus") }.accessibilityLabel("러너 추가")
            }
        }
        .sheet(isPresented: $adding) { NavigationStack { RunnerEditorView(runner: nil, installOn: nil) } }
    }

    private func runnerCard(_ r: RunnerSet, index i: Int, badge: String?) -> some View {
        NavigationLink { RunnerDetailView(runner: r) } label: {
            PaperCard(tape: RunnerPaper.tape(i), tapeAngle: RunnerPaper.angle(i)) {
                HStack(spacing: 8) {
                    RunnerRow(runner: r, badge: badge, iconIndex: i)
                    AppIcon("chevron.right").font(.caption.bold()).foregroundStyle(Theme.paperInkSoft)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RunnerRow: View {
    @Environment(\.modelContext) private var context
    let runner: RunnerSet
    var badge: String?
    /// 파스텔 동그라미 색 순번.
    var iconIndex = 0

    /// 교체 시기는 분홍 테두리로 눈에 띄게, 교체한 날은 보라, 장착은 민트.
    private var badgeIndex: Int {
        guard let badge else { return 0 }
        if badge == "교체 시기" { return 0 }
        return badge.hasSuffix("교체") ? 4 : 2
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIcon("skateblade", size: 22)
                .foregroundStyle(Theme.paperInk)
                .frame(width: 46, height: 46)
                .background(Theme.stickers[iconIndex % 5], in: Circle())
                .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
            VStack(alignment: .leading, spacing: 6) {
                Text(runner.name)
                    .font(.system(.headline, design: .rounded)).foregroundStyle(Theme.paperInk)
                FlowLayout(spacing: 6) {
                    Sticker(text: "RoH \(runner.currentHollow.map { "\($0)\"" } ?? "미확인")", index: 1, on: false, small: true)
                    if let badge {
                        Sticker(text: badge, index: badgeIndex, on: badge == "교체 시기", small: true)
                    }
                }
                Text(DiaryStore.sharpeningSummary(runner, context: context))
                    .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
            }
            Spacer(minLength: 0)
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

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PaperCard(tape: Theme.tapePink, tapeAngle: -4) {
                    PaperTitle(text: "러너(날)", systemImage: "skateblade")
                    TextField("이름 (예: A세트, 스텔스)", text: $name).runnerField()
                    TextField("모델 (예: Step Blacksteel)", text: $model).runnerField()
                    RunnerNote(text: "러너는 부츠에 끼우는 날이에요. 연마는 이 날을 가는 거예요. 그래서 연마 기록과 알림도 날마다 따로 세요.")
                }
                PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
                    PaperTitle(text: "연마 점검", systemImage: "wrench.and.screwdriver")
                    Toggle("연마 점검 표시하기", isOn: $useThreshold)
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                        .tint(Theme.neonPink)
                    if useThreshold {
                        ChoiceCards(options: [
                            ChoiceOption(value: CheckBy.sessions, title: "탄 횟수", art: .symbol("number")),
                            ChoiceOption(value: CheckBy.hours, title: "탄 시간", art: .symbol("clock")),
                        ], selection: $checkBy, columns: 2, minHeight: 60)
                        Group {
                            if checkBy == .hours {
                                Stepper("연마하고 \(thresholdHours)시간 타면 표시", value: $thresholdHours, in: 1...100)
                            } else {
                                Stepper("연마하고 \(thresholdSessions)번 타면 표시", value: $thresholdSessions, in: 1...60)
                            }
                        }
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                    }
                    RunnerNote(text: "이 날로 정해둔 만큼 타면 홈 화면에 갈 때가 됐다고 띄워 줘요. 휴대폰 알림은 아직 안 보내요. 정해진 주기는 없으니 내 느낌대로 정하면 돼요.")
                }
                PaperCard(tape: Theme.tapeYellow, tapeAngle: -2) {
                    PaperTitle(text: "날 교체 시기", systemImage: "calendar")
                    Toggle("날 교체 시기 표시하기", isOn: $useReplace)
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                        .tint(Theme.neonPink)
                    if useReplace {
                        ChoiceCards(options: [
                            ChoiceOption(value: ReplaceBy.sharpenings, title: "연마 횟수", art: .symbol("wrench.and.screwdriver")),
                            ChoiceOption(value: ReplaceBy.months, title: "쓴 기간", art: .symbol("calendar")),
                        ], selection: $replaceBy, columns: 2, minHeight: 60)
                        Group {
                            if replaceBy == .sharpenings {
                                Stepper("연마 \(replaceSharpenings)번 하면 표시", value: $replaceSharpenings, in: 5...100)
                            } else {
                                Stepper("\(replaceMonths)개월 쓰면 표시", value: $replaceMonths, in: 1...48)
                            }
                        }
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                    }
                    RunnerNote(text: "날은 갈수록 깎여요. 얼마나 쓰면 바꿀지는 사람마다 달라요. 내 기준으로 정해 주세요.")
                }
                PaperCard(tape: Theme.tapePink, tapeAngle: 4, dotted: true) {
                    PaperTitle(text: "메모", systemImage: "pencil.line")
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(2...8)
                        .runnerField()
                }
                Button(action: save) {
                    Label("저장하기", icon: "heart.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
                .disabled(!canSave)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
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
        ScrollView {
            VStack(spacing: 16) {
                PaperCard(tape: Theme.tapePink, tapeAngle: -4, dotted: true) {
                    HStack(spacing: 16) {
                        if let h = runner.currentHollow.flatMap(Hollow.init(label:)) {
                            HollowGlyph(hollow: h).frame(width: 70, height: 70)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(runner.name)
                                .font(.system(.title3, design: .rounded).bold()).foregroundStyle(Theme.paperInk)
                            Text("현재 RoH \(runner.currentHollow.map { "\($0)\"" } ?? "미확인")\(runner.currentHollow.flatMap(Hollow.init(label:))?.nickname.map { " · \($0)" } ?? "")")
                                .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                            Sticker(text: runner.installedSkate.map { "\($0.name)에 장착 중" } ?? "보관 중",
                                    index: runner.installedSkate == nil ? 3 : 2, on: false, small: true)
                        }
                        Spacer(minLength: 0)
                    }
                    if let last = runner.lastSharpening {
                        RunnerValueRow(title: "마지막 연마", value: "\(ElapsedText.since(last.at)) · \(last.at.formatted(.dateTime.month().day()))")
                    } else {
                        RunnerValueRow(title: "마지막 연마", value: "기록 없음", soft: true)
                    }
                    RunnerValueRow(title: "그 뒤로 탄 횟수", value: rides == 0 ? "아직 안 탔어요" : "\(rides)번")
                    RunnerValueRow(title: "그 뒤로 탄 시간", value: minutesText(since))
                    if let n = runner.checkThresholdSessions {
                        ProgressTrack(value: Double(rides), total: Double(n), label: "\(n)번 타면 홈에 표시", trailing: "\(rides)/\(n)")
                    } else if let t = runner.checkThresholdMinutes {
                        ProgressTrack(value: Double(since), total: Double(t), label: "\(minutesText(t)) 타면 홈에 표시", trailing: minutesText(since))
                    }
                    RunnerNote(text: "기록할 때 이 러너를 고른 활동만 세요. 시간은 '실제로 탄 시간'으로 더해요.")
                }

                PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
                    PaperTitle(text: "날 교체", systemImage: "arrow.triangle.2.circlepath")
                    RunnerValueRow(title: "날 상태", value: runner.lifeSummary)
                    if let n = runner.replaceAfterSharpenings {
                        ProgressTrack(value: Double(runner.sharpenings.count), total: Double(n), label: "연마 \(n)번 하면 교체 표시", trailing: "\(runner.sharpenings.count)/\(n)")
                    } else if let m = runner.replaceAfterMonths {
                        let used = RunnerLife.monthsUsed(since: runner.firstUsedAt)
                        ProgressTrack(value: Double(used), total: Double(m), label: "\(m)개월 쓰면 교체 표시", trailing: "\(used)개월")
                    }
                    if let retired = runner.retiredAt {
                        Text("\(retired.formatted(date: .abbreviated, time: .omitted))에 교체했어요.")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                    } else {
                        Button("이 날 교체했어요") { confirmingRetire = true }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .buttonStyle(.bordered).tint(Theme.accentText).buttonBorderShape(.capsule)
                    }
                    RunnerNote(text: "교체했다고 하면 이 러너는 '교체한 날'로 옮겨져요. 지난 기록은 그대로 남아요.")
                }

                PaperCard(tape: Theme.tapeYellow, tapeAngle: -2) { SharpeningGuideCard() }

                PaperCard(tape: Theme.tapePink, tapeAngle: 5, dotted: true) {
                    PaperTitle(text: "연마 이력", systemImage: "clock.arrow.circlepath")
                    Button { addingSharpening = true } label: {
                        Label("연마 기록 추가", icon: "plus")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
                    ForEach(Array(runner.sharpenings.sorted { $0.at > $1.at }.enumerated()), id: \.element.id) { i, log in
                        sharpeningLine(log, index: i)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("러너")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("고치기") { editing = true } } }
        .sheet(isPresented: $addingSharpening) { NavigationStack { SharpeningEditorView(runner: runner) } }
        .confirmationDialog("이 날을 교체했어요?", isPresented: $confirmingRetire, titleVisibility: .visible) {
            Button("교체했어요") {
                DiaryStore.uninstall(runner, context: context)
                runner.retiredAt = Date()
                context.saveOrReport()
            }
        } message: {
            Text("부츠에서 떼서 '교체한 날'로 옮겨요. 새 날은 스케이트 화면에서 추가해 주세요.")
        }
        .sheet(isPresented: $editing) { NavigationStack { RunnerEditorView(runner: runner, installOn: nil) } }
    }

    /// 연마 한 번 = 날짜 스티커 + 한 줄.
    private func sharpeningLine(_ log: SharpeningLog, index i: Int) -> some View {
        let feels = [("그립", log.grip), ("활주", log.glide), ("스톱", log.stop), ("턴", log.turn)]
            .compactMap { n, v in v.map { "\(n) \($0)" } }
        let line = ([log.hollow.isEmpty ? "RoH 미확인" : "\(log.hollow)\""] + feels + (log.shop.isEmpty ? [] : [log.shop]))
            .joined(separator: " · ")
        return HStack(alignment: .top, spacing: 10) {
            Sticker(text: log.at.formatted(date: .abbreviated, time: .omitted), index: i, on: false, small: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(line)
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !log.memo.isEmpty {
                    Text(log.memo).font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
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
        ScrollView {
            VStack(spacing: 16) {
                PaperCard(tape: Theme.tapePink, tapeAngle: -4) {
                    DatePicker("연마한 때", selection: $at, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(.headline, design: .rounded)).foregroundStyle(Theme.paperInk)
                        .tint(Theme.accentText)
                }
                PaperCard(tape: Theme.tapeYellow, tapeAngle: 3) { SharpeningGuideCard() }
                PaperCard(tape: Theme.tapeMint, tapeAngle: -2, dotted: true) {
                    PaperTitle(text: "홀로우 (RoH)", systemImage: "skateblade")
                    HStack {
                        Text("작은 숫자 · 깊은 홈").font(.caption.bold()).foregroundStyle(Theme.warning)
                        Spacer()
                        AppIcon("arrow.left.and.right").font(.caption).foregroundStyle(Theme.paperInkSoft)
                        Spacer()
                        Text("큰 숫자 · 얕은 홈").font(.caption.bold()).foregroundStyle(Theme.accent)
                    }
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
                        .runnerField()
                    if customInvalid {
                        Text("인치 값으로 적어 주세요. 예: 5/8, 0.55").font(.caption).foregroundStyle(Theme.danger)
                    }
                    RunnerNote(text: "홈이 깊으면 날이 얼음을 꽉 잡아서 턴과 스톱이 단단해요. 얕으면 덜 잡는 대신 쭉 나가요. 그림은 깊이 차이만 보여 줘요. 모르면 비워 둬도 돼요.\n\(Hollow.playerNicknameNote)")
                }
                PaperCard(tape: Theme.tapePink, tapeAngle: 4) {
                    PaperTitle(text: "어디서?", systemImage: "mappin.and.ellipse")
                    TextField("연마한 곳 (업체·링크장)", text: $shop).runnerField()
                }
                PaperCard(tape: Theme.tapeYellow, tapeAngle: -3) {
                    PaperTitle(text: "연마 후 느낌", systemImage: "sparkles")
                    ScalePicker(title: "그립", low: "약함", high: "강함", value: $grip)
                    ScalePicker(title: "활주", low: "무거움", high: "잘 나감", value: $glide)
                    ScalePicker(title: "스톱", low: "밀림", high: "잘 섬", value: $stop)
                    ScalePicker(title: "턴", low: "어려움", high: "편함", value: $turn)
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(2...8)
                        .runnerField()
                }
                Button(action: save) {
                    Label("저장하기", icon: "heart.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
                .disabled(customInvalid)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
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
                if let nick = hollow.nickname {
                    Text(nick).font(hollow.playerNickname != nil ? .subheadline.bold() : .caption.bold())
                        .foregroundStyle(Theme.title)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Text(hollow.feel).font(.caption2.bold())
                    .foregroundStyle(hollow.feel == "깊은 홈" ? Theme.warning : (hollow.feel == "얕은 홈" ? Theme.accent : Theme.inkTertiary))
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 128)
            .foregroundStyle(Theme.title)
            .background(selected ? Theme.cobaltSoft : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Theme.neonPink : Theme.inkTertiary.opacity(0.25), lineWidth: selected ? 2.5 : 1))
            .overlay(alignment: .topTrailing) {
                if selected { AppIcon("checkmark.circle.fill").foregroundStyle(Theme.neonPink).padding(4) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("홀로우 \(hollow.label)인치\(hollow.nickname.map { ", \($0)" } ?? ""), \(hollow.feel)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 날 아랫면의 U자 홈 단면. 깊이는 Hollow.relativeDepth(기하 공식)에서만 나온다 (EQ-04).
struct HollowGlyph: View {
    let hollow: Hollow

    var body: some View {
        BladeSection(relativeDepth: hollow.relativeDepth)
            .fill(LinearGradient(colors: Theme.steel,
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

/// 날 관리 메모: 타기 전 체크 / 얼음 위 느낌 / 연마점에서 / 보관
struct SharpeningGuideCard: View {
    @State private var tab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("날 관리 메모", icon: "lightbulb").font(.headline).foregroundStyle(Theme.title)
            ChoiceCards(options: SharpeningGuide.sections.indices.map { i in
                ChoiceOption(value: i, title: SharpeningGuide.sections[i].title,
                             art: .symbol(["eye", "figure.skating", "wrench.and.screwdriver", "bag"][i]))
            }, selection: $tab, columns: 4, minHeight: 60)
            ForEach(Array(SharpeningGuide.sections[tab].points.enumerated()), id: \.offset) { i, p in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1)").font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 20, height: 20).background(Theme.cobalt, in: Circle())
                    Text(p).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// 아이콘을 글자 오른쪽에 두는 라벨.
struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon }
    }
}
