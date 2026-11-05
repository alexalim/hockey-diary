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
                Text("러너 세트가 없어. 스케이트 상세에서 추가하면 바로 장착돼.")
                    .foregroundStyle(.secondary)
            }
            ForEach(runners) { r in
                NavigationLink { RunnerDetailView(runner: r) } label: {
                    RunnerRow(runner: r, badge: r.installedSkate.map { "\($0.name)에 장착" })
                }
            }
        }
        .navigationTitle(focusSharpening ? "연마" : "러너")
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
                Image(systemName: "minus").frame(width: 34, height: 34).foregroundStyle(Theme.cobalt)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(runner.name).font(.subheadline.bold())
                Text("RoH \(runner.currentHollow.map { "\($0)\"" } ?? "미확인") · 연마 후 \(minutesText(DiaryStore.minutesSinceSharpening(runner, context: context)))")
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
    @State private var useThreshold = false
    @State private var thresholdHours = 10
    @State private var loaded = false

    var body: some View {
        Form {
            Section("러너 세트") {
                TextField("이름 (예: A세트, 스텔스)", text: $name)
                TextField("모델 (예: Step Blacksteel)", text: $model)
            }
            Section {
                Toggle("점검 알림 받기", isOn: $useThreshold)
                if useThreshold {
                    Stepper("연마 후 \(thresholdHours)시간 타면 알려줘", value: $thresholdHours, in: 1...100)
                }
            } header: {
                Text("내 점검 기준")
            } footer: {
                Text("정답인 연마 주기는 없어. 내 느낌과 기록에 맞춰 정해줘.")
            }
            Section("메모") { TextField("메모", text: $memo, axis: .vertical) }
        }
        .navigationTitle(runner == nil ? "러너 추가" : "러너 고치기")
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
            if let t = runner.checkThresholdMinutes { useThreshold = true; thresholdHours = max(1, t / 60) }
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
        target.checkThresholdMinutes = useThreshold ? thresholdHours * 60 : nil
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

    var body: some View {
        let since = DiaryStore.minutesSinceSharpening(runner, context: context)
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
                    Text("마지막 연마 후 얼음 위")
                    Spacer()
                    Text(minutesText(since)).bold()
                }
                if let t = runner.checkThresholdMinutes {
                    ProgressView(value: min(Double(since), Double(t)), total: Double(t)) {
                        Text("내 점검 기준 \(minutesText(t))").font(.caption)
                    }
                    .tint(since >= t ? Theme.neonPink : Theme.cobalt)
                }
            } footer: {
                Text("기록한 활동에서 고른 러너의 '실제 얼음 위 시간'만 더해.")
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
                Text("그림은 상대적인 깊이를 보여주는 도식이야. 숫자가 작을수록 홈이 깊어. 모르면 비워둬도 돼.")
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
