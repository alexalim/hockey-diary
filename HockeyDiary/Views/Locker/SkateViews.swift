import SwiftUI
import SwiftData
import HockeyCore

/// 스케이트 컬렉션 (S11). 주력·서브·보관 중·사용 종료를 한 화면에서 구분한다.
struct SkateListView: View {
    @Query(sort: \Skate.createdAt) private var skates: [Skate]
    @State private var adding = false

    var body: some View {
        List {
            if skates.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("아직 스케이트가 없어.").font(.headline)
                        Text("사진 없이도 등록돼. 여러 켤레를 넣고 주력 하나를 정해봐.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("첫 스케이트 등록") { adding = true }
                            .buttonStyle(PinkButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
            }
            ForEach(groups, id: \.0) { title, items in
                Section(title) {
                    ForEach(items) { s in
                        NavigationLink { SkateDetailView(skate: s) } label: { SkateRow(skate: s) }
                    }
                }
            }
        }
        .navigationTitle("스케이트")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("스케이트 추가")
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
}

struct SkateRow: View {
    let skate: Skate

    var body: some View {
        HStack(spacing: 12) {
            if let data = skate.coverPhoto {
                PhotoThumb(data: data, size: 48)
            } else {
                Image(systemName: "shoeprints.fill")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if skate.isPrimary { Image(systemName: "star.fill").foregroundStyle(Theme.warningFill).font(.caption) }
                    Text(skate.name).font(.subheadline.bold())
                }
                Text([skate.size.isEmpty ? nil : "사이즈 \(skate.size)", skate.status.title,
                      skate.currentRunner.map { "러너 \($0.name)\($0.currentHollow.map { " · \($0)\"" } ?? "")" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
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

    var body: some View {
        Form {
            Section("스케이트") {
                TextField("브랜드 (예: Bauer)", text: $brand)
                TextField("모델명", text: $model)
                TextField("사이즈", text: $size)
                TextField("FIT·발볼", text: $fit)
                LabeledChoice(title: "상태", options: SkateStatus.choices, selection: $status, columns: 4, minHeight: 64)
                Toggle("구매일 기록", isOn: $hasPurchase)
                if hasPurchase { DatePicker("구매일", selection: $purchasedAt, displayedComponents: .date) }
            }
            Section("대표 사진") {
                if let data = skate?.coverPhoto, photos.isEmpty {
                    PhotoThumb(data: data, size: 90)
                }
                PhotoPickerRow(existing: [], removedIDs: $removed, added: Binding(
                    get: { photos },
                    set: { photos = Array($0.suffix(1)) }
                ))
            }
            Section("메모") { TextField("메모", text: $memo, axis: .vertical) }
        }
        .navigationTitle(skate == nil ? "스케이트 등록" : "스케이트 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save)
                    .disabled(brand.trimmingCharacters(in: .whitespaces).isEmpty && model.trimmingCharacters(in: .whitespaces).isEmpty)
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
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skate.name).font(.title3.bold())
                        if skate.isPrimary { Image(systemName: "star.fill").foregroundStyle(Theme.warningFill) }
                    }
                    Text([skate.size.isEmpty ? nil : "사이즈 \(skate.size)", skate.fit.isEmpty ? nil : skate.fit, skate.status.title]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("지금까지 탄 시간 \(minutesText(EquipmentMath.iceMinutes(skateID: skate.id, usages: DiaryStore.usageRecords(context))))")
                        .font(.subheadline)
                }
                if !skate.isPrimary {
                    Button("대표 스케이트로 정하기") { DiaryStore.makePrimary(skate, context: context) }
                }
                LabeledChoice(title: "상태", options: SkateStatus.choices, selection: Binding(
                    get: { skate.status },
                    set: { skate.status = $0; if !$0.isActive { skate.isPrimary = false }; context.saveOrReport() }
                ), columns: 4, minHeight: 64)
            } footer: {
                Text("지우지 말고 '사용 종료'로 바꿔두면 지난 기록이 남아.")
            }

            Section {
                if let current = skate.currentRunner {
                    NavigationLink { RunnerDetailView(runner: current) } label: {
                        RunnerRow(runner: current, badge: "장착 중")
                    }
                    Button("러너 떼기", role: .destructive) { DiaryStore.uninstall(current, context: context) }
                } else {
                    Text("장착된 러너가 없어.").foregroundStyle(.secondary)
                }
                ForEach(swappable) { r in
                    Button {
                        if let e = DiaryStore.install(r, on: skate, context: context) {
                            errorText = message(e)
                        }
                    } label: {
                        Label("\(Josa.ro(r.name)) 교체\(r.installedSkate.map { " · 지금 \($0.name)에서 떼어 옴" } ?? "")",
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                Button { addingRunner = true } label: { Label("새 러너(날) 추가", systemImage: "plus") }
            } header: {
                Text("러너(날)")
            } footer: {
                Text("러너 하나는 부츠 하나에만 달 수 있어. 바꿔 달면 언제부터 언제까지 썼는지 남아.")
            }

            if !history.isEmpty {
                Section("장착 이력") {
                    ForEach(history) { inst in
                        HStack {
                            Text(inst.runner?.name ?? "-")
                            Spacer()
                            Text("\(inst.installedAt.formatted(date: .numeric, time: .omitted)) ~ \(inst.removedAt?.formatted(date: .numeric, time: .omitted) ?? "지금")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !skate.memo.isEmpty { Section("메모") { Text(skate.memo) } }
        }
        .navigationTitle("스케이트 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("고치기") { editing = true } } }
        .sheet(isPresented: $editing) { NavigationStack { SkateEditorView(skate: skate) } }
        .sheet(isPresented: $addingRunner) { NavigationStack { RunnerEditorView(runner: nil, installOn: skate) } }
        .alert("러너를 달 수 없어", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
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
        case .runnerAlreadyInstalled: return "이 러너는 그때 다른 부츠에 달려 있었어."
        case .invalidRange: return "장착 기간이 맞지 않아."
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
