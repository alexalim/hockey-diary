import SwiftUI
import SwiftData
import HockeyCore

/// 스케이트 컬렉션 (S11). 주력·서브·보관 중·사용 종료를 한 화면에서 구분한다.
/// 모양은 일기와 같은 다이어리 속지(종이 카드·테이프·스티커, JournalParts.swift). 저장 모델은 그대로.
struct SkateListView: View {
    @Query(sort: \Skate.createdAt) private var skates: [Skate]
    @State private var adding = false

    private let tapes = [Theme.tapePink, Theme.tapeMint, Theme.tapeYellow]
    private let angles: [Double] = [-4, 3, -2]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if skates.isEmpty {
                    EmptyHint(text: "아직 스케이트가 없어요. 사진 없이도 등록돼요. 여러 켤레를 넣고 주력 하나를 정해 보세요.",
                              systemImage: "shoeprints.fill",
                              action: EmptyAction(title: "첫 스케이트 등록") { adding = true })
                }
                ForEach(Array(groups.enumerated()), id: \.element.0) { gi, group in
                    PaperCard(tape: tapes[gi % tapes.count], tapeAngle: angles[gi % angles.count]) {
                        PaperTitle(text: group.0, systemImage: groupSymbol(group.0))
                        ForEach(Array(group.1.enumerated()), id: \.element.id) { i, s in
                            if i > 0 { Divider().overlay(Theme.paperDot) }
                            NavigationLink { SkateDetailView(skate: s) } label: {
                                HStack(spacing: 8) {
                                    SkateRow(skate: s, index: i + gi)
                                    Spacer(minLength: 0)
                                    AppIcon("chevron.right").font(.caption.bold()).foregroundStyle(Theme.paperInkSoft)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("스케이트")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { AppIcon("plus") }.accessibilityLabel("스케이트 추가")
            }
        }
        .sheet(isPresented: $adding) { NavigationStack { SkateEditorView(skate: nil) } }
    }

    private var groups: [(String, [Skate])] {
        let active = skates.filter { $0.status.isActive }.sorted { $0.isPrimary && !$1.isPrimary }
        let stored = skates.filter { $0.status == .stored }
        let retired = skates.filter { $0.status == .retired }
        return [("사용 중", active), ("보관 중", stored), ("사용 종료", retired)].filter { !$0.1.isEmpty }
    }

    private func groupSymbol(_ title: String) -> String {
        switch title {
        case "사용 중": return "figure.skating"
        case "보관 중": return "archivebox"
        default: return "moon.zzz"
        }
    }
}

struct SkateRow: View {
    let skate: Skate
    var index: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            if let data = skate.coverPhoto {
                PolaroidThumb(data: data, size: 46, index: index)
            } else {
                AppIcon("shoeprints.fill", size: 22)
                    .foregroundStyle(Theme.paperInk)
                    .frame(width: 46, height: 46)
                    .background(Theme.stickers[index % 5], in: Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(skate.name)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Theme.paperInk)
                    if skate.isPrimary { Sticker(text: "주력", index: 0, small: true) }
                }
                Text([skate.size.isEmpty ? nil : "사이즈 \(skate.size)", skate.status.title,
                      skate.currentRunner.map { "러너 \($0.name)\($0.currentHollow.map { " · \($0)\"" } ?? "")" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
            }
        }
        .frame(minHeight: Theme.touch)
        .accessibilityElement(children: .combine)
    }
}

/// 스케이트 등록·수정.
struct SkateEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allSkates: [Skate]

    let skate: Skate?

    @State private var brand = ""
    @State private var model = ""
    @State private var size = ""
    @State private var fit = ""
    @State private var status: SkateStatus = .main
    @State private var hasPurchase = false
    @State private var purchasedAt = Date()
    @State private var memo = ""
    @State private var photos: [Data] = []
    @State private var removed: Set<UUID> = []
    @State private var loaded = false

    private var canSave: Bool {
        !(brand.trimmingCharacters(in: .whitespaces).isEmpty && model.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PaperCard(tape: Theme.tapePink, tapeAngle: -4) {
                    PaperTitle(text: "스케이트 정보", systemImage: "shoeprints.fill")
                    paperField("브랜드 (예: Bauer)", text: $brand)
                    paperField("모델명", text: $model)
                    HStack(spacing: 10) {
                        paperField("사이즈", text: $size)
                        paperField("FIT·발볼", text: $fit)
                    }
                    LabeledChoice(title: "상태", options: SkateStatus.choices, selection: $status, columns: 4, minHeight: 64)
                    Toggle(isOn: $hasPurchase) {
                        Text("구매일 기록").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                    }
                    .tint(Theme.neonPink)
                    if hasPurchase {
                        DatePicker(selection: $purchasedAt, displayedComponents: .date) {
                            Text("구매일").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                        }
                        .tint(Theme.accentText)
                    }
                }
                PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
                    PaperTitle(text: "대표 사진", systemImage: "camera")
                    if let data = skate?.coverPhoto, photos.isEmpty {
                        PolaroidThumb(data: data, size: 90, index: 2)
                            .padding(.vertical, 4)
                    }
                    PhotoPickerRow(existing: [], removedIDs: $removed, added: Binding(
                        get: { photos },
                        set: { photos = Array($0.suffix(1)) }
                    ))
                }
                PaperCard(tape: Theme.tapeYellow, tapeAngle: -2, dotted: true) {
                    PaperTitle(text: "메모", systemImage: "pencil.line")
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(3...10)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.paperInk)
                        .tint(Theme.accentText)
                        .padding(10)
                        .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .navigationTitle(skate == nil ? "스케이트 등록" : "스케이트 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save)
                    .disabled(!canSave)
            }
        }
        .onAppear {
            guard !loaded, let skate else { return }
            loaded = true
            brand = skate.brand; model = skate.model; size = skate.size; fit = skate.fit
            status = skate.status; memo = skate.memo
            if let p = skate.purchasedAt { hasPurchase = true; purchasedAt = p }
        }
    }

    private func paperField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Theme.paperInk)
            .tint(Theme.accentText)
            .padding(10)
            .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func save() {
        let target: Skate
        if let skate {
            target = skate
        } else {
            target = Skate(brand: "", model: "")
            context.insert(target)
            // 첫 스케이트는 대표로.
            if allSkates.allSatisfy({ !$0.isPrimary || $0.id == target.id }) { target.isPrimary = true }
        }
        target.brand = brand.trimmingCharacters(in: .whitespaces)
        target.model = model.trimmingCharacters(in: .whitespaces)
        target.size = size
        target.fit = fit
        target.status = status
        target.purchasedAt = hasPurchase ? purchasedAt : nil
        target.memo = memo
        if let p = photos.last { target.coverPhoto = p }
        if !status.isActive { target.isPrimary = false }
        context.saveOrReport()
        dismiss()
    }
}

/// 스케이트 상세 (S12). 러너 장착·교체 이력, 누적 시간.
struct SkateDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RunnerSet.createdAt) private var runners: [RunnerSet]

    let skate: Skate

    @State private var editing = false
    @State private var addingRunner = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                runnerCard
                if !history.isEmpty { historyCard }
                if !skate.memo.isEmpty {
                    PaperCard(tape: Theme.tapePink, tapeAngle: 4, dotted: true) {
                        PaperTitle(text: "메모", systemImage: "pencil.line")
                        Text(skate.memo)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.paperInk)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("스케이트 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("고치기") { editing = true } } }
        .sheet(isPresented: $editing) { NavigationStack { SkateEditorView(skate: skate) } }
        .sheet(isPresented: $addingRunner) { NavigationStack { RunnerEditorView(runner: nil, installOn: skate) } }
        .alert("러너를 달 수 없어요", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: 카드들

    /// 대표 사진(큰 폴라로이드)과 이름·사이즈·탄 시간, 상태.
    private var summaryCard: some View {
        PaperCard(tape: Theme.tapeYellow, tapeAngle: -4) {
            if let data = skate.coverPhoto {
                PolaroidThumb(data: data, size: 180, index: 0)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(skate.name)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(Theme.paperInk)
                    if skate.isPrimary { Sticker(text: "주력", index: 0, small: true) }
                }
                Text([skate.size.isEmpty ? nil : "사이즈 \(skate.size)", skate.fit.isEmpty ? nil : skate.fit, skate.status.title]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                Text("지금까지 탄 시간 \(minutesText(EquipmentMath.iceMinutes(skateID: skate.id, usages: DiaryStore.usageRecords(context))))")
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
            }
            if !skate.isPrimary {
                Button { DiaryStore.makePrimary(skate, context: context) } label: {
                    Label("대표 스케이트로 정하기", icon: "star")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .padding(.horizontal, 14).frame(minHeight: 40)
                }
                .buttonStyle(.bordered).tint(Theme.neonPink).buttonBorderShape(.capsule)
            }
            LabeledChoice(title: "상태", options: SkateStatus.choices, selection: Binding(
                get: { skate.status },
                set: { skate.status = $0; if !$0.isActive { skate.isPrimary = false }; context.saveOrReport() }
            ), columns: 4, minHeight: 64)
            Text("지우지 말고 '사용 종료'로 바꿔두면 지난 기록이 남아요.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
        }
    }

    /// 지금 달린 러너, 바꿔 달 수 있는 러너, 새 러너.
    private var runnerCard: some View {
        PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
            PaperTitle(text: "러너(날)", systemImage: "line.diagonal")
            if let current = skate.currentRunner {
                NavigationLink { RunnerDetailView(runner: current) } label: {
                    HStack(spacing: 8) {
                        RunnerRow(runner: current, badge: "장착 중")
                        AppIcon("chevron.right").font(.caption.bold()).foregroundStyle(Theme.paperInkSoft)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button("러너 떼기", role: .destructive) { DiaryStore.uninstall(current, context: context) }
                    .font(.system(.subheadline, design: .rounded))
                    .frame(minHeight: Theme.touch)
            } else {
                Text("장착된 러너가 없어요.")
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
            }
            ForEach(swappable) { r in
                Button {
                    if let e = DiaryStore.install(r, on: skate, context: context) {
                        errorText = message(e)
                    }
                } label: {
                    Label("\(Josa.ro(r.name)) 교체\(r.installedSkate.map { " · 지금 \($0.name)에서 떼어 옴" } ?? "")",
                          icon: "arrow.triangle.2.circlepath")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.accentText)
                        .frame(maxWidth: .infinity, minHeight: Theme.touch, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button { addingRunner = true } label: {
                Label("새 러너(날) 추가", icon: "plus")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .padding(.horizontal, 14).frame(minHeight: 40)
            }
            .buttonStyle(.bordered).tint(Theme.neonPink).buttonBorderShape(.capsule)
            Text("러너 하나는 부츠 하나에만 달 수 있어요. 바꿔 달면 언제부터 언제까지 썼는지 남아요.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
        }
    }

    /// 장착 이력. 종이 카드 안 목록.
    private var historyCard: some View {
        PaperCard(tape: Theme.tapePink, tapeAngle: -3) {
            PaperTitle(text: "장착 이력", systemImage: "clock")
            ForEach(Array(history.enumerated()), id: \.element.id) { i, inst in
                if i > 0 { Divider().overlay(Theme.paperDot) }
                HStack {
                    Text(inst.runner?.name ?? "-")
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInk)
                    Spacer()
                    Text("\(inst.installedAt.formatted(date: .numeric, time: .omitted)) ~ \(inst.removedAt?.formatted(date: .numeric, time: .omitted) ?? "지금")")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                }
            }
        }
    }

    /// 이 부츠에 달 수 있는 다른 러너들 (이 부츠에 달린 적 있거나 어디에도 안 달린 러너).
    private var swappable: [RunnerSet] {
        runners.filter { r in
            r.retiredAt == nil && r.id != skate.currentRunner?.id
                && (r.installedSkate == nil || r.installations.contains { $0.skate?.id == skate.id })
        }
    }

    private var history: [RunnerInstallation] {
        skate.installations.sorted { $0.installedAt > $1.installedAt }
    }

    private func message(_ e: InstallError) -> String {
        switch e {
        case .runnerAlreadyInstalled: return "이 러너는 그때 다른 부츠에 달려 있었어요."
        case .invalidRange: return "장착 기간이 맞지 않아요."
        }
    }
}

/// 받침에 따라 조사를 고른다. 한글이 아닌 글자로 끝나면 받침 없는 쪽을 쓴다.
enum Josa {
    /// "A세트로", "블랙스틸로", "1번으로". ㄹ 받침은 '로'.
    static func ro(_ word: String) -> String {
        guard let last = word.unicodeScalars.last else { return word + "로" }
        let v = last.value
        if (0xAC00...0xD7A3).contains(v) {
            let jong = (v - 0xAC00) % 28
            return word + ((jong == 0 || jong == 8) ? "로" : "으로")
        }
        // 숫자로 끝나면 읽는 소리 기준: 0,1,3,6,7,8은 받침 있음(영, 일, 삼, 육, 칠, 팔). 1·7·8은 ㄹ이라 '로'.
        if let d = Int(String(last)), (0...9).contains(d) {
            return word + ([0, 3, 6].contains(d) ? "으로" : "로")
        }
        return word + "로"
    }
}
