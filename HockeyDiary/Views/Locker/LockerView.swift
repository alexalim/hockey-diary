import SwiftUI
import SwiftData
import PhotosUI
import HockeyCore

/// 나의 락커 (S08). 닫힌 문 → 열린 락커 → 장비 구역.
/// 동작 줄이기면 애니메이션 없이 바로 열고, 필수 기능은 텍스트 버튼으로도 들어갈 수 있다 (8.1.1).
struct LockerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lockerOpen") private var isOpen = false
    /// 문 각도(0=닫힘, DoorSwing.openAngle=활짝). 손가락을 따라 움직인다.
    @State private var angle: Double = 0
    @State private var dragBase: Double?
    @State private var horizontalDrag: Bool?
    @State private var latchTick = 0
    @State private var hinted = false
    @State private var customizing = false
    @State private var newStickers: [String] = []

    @Query private var skates: [Skate]
    @Query private var gear: [GearItem]
    @Query private var profiles: [LockerProfile]
    @Query(sort: \StickerPlacement.zIndex) private var placements: [StickerPlacement]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !newStickers.isEmpty { earnedBanner }
                GeometryReader { geo in
                    let progress = DoorSwing.progress(angle)
                    ZStack {
                        LockerInside(skateCount: skates.count, gear: gear)
                            .scaleEffect(0.94 + 0.06 * progress)
                            .brightness(-0.25 * (1 - progress))
                            .allowsHitTesting(angle >= DoorSwing.openAngle - 1)
                        LockerDoor(profile: profiles.first, placements: placements)
                            // 문이 돌수록 빛을 덜 받아 어두워진다.
                            .overlay(Color.black.opacity(0.4 * progress).clipShape(RoundedRectangle(cornerRadius: 14)))
                            .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
                            .shadow(color: .black.opacity(0.35 * progress), radius: 18 * progress, x: -10 * progress)
                            .opacity(angle > 88 ? 0 : 1)
                            .allowsHitTesting(angle < 1)
                            .onTapGesture(perform: toggle)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(doorLabel)
                            .accessibilityHint("두 번 탭하면 문이 열려")
                            .accessibilityAddTraits(.isButton)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(swipe(width: geo.size.width))
                }
                .frame(height: 440)
                .sensoryFeedback(.selection, trigger: latchTick)
                .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)

                HStack(spacing: 8) {
                    Button(isOpen ? "문 닫기" : "문 열기", action: toggle)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button { customizing = true } label: { Label("꾸미기", systemImage: "paintbrush.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.neonPink)
                }
                .frame(minHeight: Theme.touch)

                Card {
                    CardHeader(title: "바로 가기", systemImage: "list.bullet")
                    NavigationLink { SkateListView() } label: { shortcut("스케이트", "shoeprints.fill", "\(skates.count)켤레") }
                    NavigationLink { RunnerListView() } label: { shortcut("러너(날)", "minus", nil) }
                    NavigationLink { RunnerListView(focusSharpening: true) } label: { shortcut("연마", "wrench.and.screwdriver.fill", nil) }
                    ForEach(GearKind.Zone.allCases, id: \.self) { zone in
                        let count = gear.filter { zone.kinds.contains($0.kind) }.count
                        NavigationLink { GearListView(zone: zone) } label: { shortcut(zone.title, zone.symbol, "\(count)개") }
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("나의 락커")
        .sheet(isPresented: $customizing) {
            NavigationStack { LockerCustomizeView(profile: LockerStore.profile(context)) }
        }
        .onAppear {
            let fresh = LockerStore.awardMilestones(context)
            if !fresh.isEmpty { newStickers = fresh }
            angle = isOpen ? DoorSwing.openAngle : 0
            hint()
        }
    }

    /// 손잡이를 잡고 가로로 쓸어 문을 연다. 세로 움직임은 스크롤에 양보한다.
    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if horizontalDrag == nil {
                    horizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard horizontalDrag == true else { return }
                if reduceMotion { return }
                let base = dragBase ?? angle
                if dragBase == nil { dragBase = base }
                let next = DoorSwing.angle(from: base, translation: value.translation.width, width: width)
                // 문고리가 풀리는 순간 가볍게 한 번 '딸깍'.
                if (angle < DoorSwing.latchAngle) != (next < DoorSwing.latchAngle) { latchTick += 1 }
                angle = next
            }
            .onEnded { value in
                defer { dragBase = nil; horizontalDrag = nil }
                guard horizontalDrag == true else { return }
                let base = dragBase ?? angle
                let predicted = DoorSwing.angle(from: base, translation: value.predictedEndTranslation.width, width: width)
                if reduceMotion {
                    // 동작 줄이기: 쓸어넘긴 방향으로 바로 여닫는다.
                    setOpen(value.translation.width < 0)
                    return
                }
                setOpen(DoorSwing.shouldOpen(current: angle, predicted: predicted, wasOpen: isOpen))
            }
    }

    private func setOpen(_ open: Bool) {
        if reduceMotion {
            angle = open ? DoorSwing.openAngle : 0
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: open ? 0.72 : 0.8)) {
                angle = open ? DoorSwing.openAngle : 0
            }
        }
        isOpen = open
    }

    /// 닫힌 문을 처음 보면 살짝 들썩여 '밀 수 있다'는 걸 알려준다.
    private func hint() {
        guard !hinted, !isOpen, !reduceMotion else { return }
        hinted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { angle = 9 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if dragBase == nil && !isOpen { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { angle = 0 } }
            }
        }
    }

    private var doorLabel: String {
        let p = profiles.first
        var parts = ["닫힌 락커 문"]
        if let n = p?.numberText, !n.isEmpty { parts.append("번호 \(n)") }
        if !placements.isEmpty { parts.append("스티커 \(placements.count)개") }
        return parts.joined(separator: ", ")
    }

    private var earnedBanner: some View {
        Card(tint: Theme.neonPink.opacity(0.15)) {
            Label("새 스티커를 받았어!", systemImage: "gift.fill").font(.headline).foregroundStyle(Theme.title)
            Text(newStickers.compactMap { StickerCatalog.def($0)?.title }.joined(separator: " · "))
                .font(.subheadline)
            Text("내 기록으로 받은 스티커야. 꾸미기에서 문에 붙여봐.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func shortcut(_ title: String, _ icon: String, _ trailing: String?) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(Theme.title)
            Spacer()
            if let trailing { Text(trailing).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: Theme.touch)
    }

    private func toggle() {
        // 드래그 중의 탭은 무시한다.
        guard dragBase == nil else { return }
        setOpen(!isOpen)
    }
}

extension LockerTheme {
    var colors: [Color] {
        switch self {
        case .cobalt: return [Theme.cobalt, Theme.deepNavy]
        case .navy: return [Theme.deepNavy, Color(hex: 0x0A1428)]
        case .neonPink: return [Theme.neonPink, Color(hex: 0x9E0F57)]
        case .iceBlue: return [Color(hex: 0xA9D8F2), Color(hex: 0x5D9CC4)]
        }
    }
}

/// 락커 문 바탕(번호판·이름표·통풍구·손잡이).
struct LockerDoorBase: View {
    var profile: LockerProfile?

    var body: some View {
        let theme = profile?.theme ?? .cobalt
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: theme.colors, startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 2))
            .overlay(alignment: .top) {
                VStack(spacing: 14) {
                    Text((profile?.nameplate.isEmpty == false ? profile!.nameplate : "MY LOCKER"))
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.deepNavy)
                        .lineLimit(1)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6))
                    if let n = profile?.numberText, !n.isEmpty {
                        Text(n)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 2))
                    }
                    VStack(spacing: 7) {
                        ForEach(0..<5, id: \.self) { _ in
                            Capsule().fill(.black.opacity(0.3)).frame(width: 140, height: 6)
                        }
                    }
                }
                .padding(.top, 30)
            }
            .overlay(alignment: .trailing) {
                Capsule().fill(.white.opacity(0.85)).frame(width: 12, height: 70).padding(.trailing, 22)
            }
    }
}

/// 꾸민 락커 문(보기 전용).
struct LockerDoor: View {
    var profile: LockerProfile?
    var placements: [StickerPlacement]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LockerDoorBase(profile: profile)
                ForEach(placements) { p in
                    StickerView(key: p.stickerKey, photo: p.photoData, side: 64)
                        .scaleEffect(p.scale)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                        .zIndex(Double(p.zIndex))
                }
            }
        }
        .overlay(alignment: .bottom) {
            Label("손잡이를 밀어서 열기", systemImage: "chevron.left.2").font(.caption).foregroundStyle(.white.opacity(0.8)).padding(.bottom, 16)
        }
    }
}

/// 스티커 그림. 사진 스티커는 동그랗게 자른 사진.
struct StickerView: View {
    var key: String
    var photo: Data?
    var side: CGFloat

    var body: some View {
        if key == "photo", let photo, let image = UIImage(data: photo) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: side, height: side)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 2, y: 1)
        } else if let def = StickerCatalog.def(key) {
            let (fg, bg) = Self.colors(def.palette)
            Image(systemName: def.symbol)
                .font(.system(size: side * 0.45, weight: .bold))
                .foregroundStyle(fg)
                .frame(width: side, height: side)
                .background(bg, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 2, y: 1)
        } else {
            Circle().fill(.gray.opacity(0.4)).frame(width: side, height: side)
        }
    }

    static func colors(_ palette: Int) -> (Color, Color) {
        switch palette {
        case 0: return (.white, Theme.neonPink)
        case 1: return (.white, Theme.cobalt)
        case 3: return (Theme.deepNavy, Color(hex: 0xFFC83D))
        default: return (Theme.cobalt, Color(hex: 0xE9F6FB))
        }
    }
}

/// 열린 락커 안. 장비 구역 핫스팟.
struct LockerInside: View {
    var skateCount: Int
    var gear: [GearItem]

    var body: some View {
        VStack(spacing: 8) {
            zoneLink(.top)
            zoneLink(.middle)
            NavigationLink { SkateListView() } label: {
                zoneLabel(skateCount == 0 ? "스케이트 · 첫 장비 등록" : "스케이트 \(skateCount)켤레", "shoeprints.fill")
            }
            .buttonStyle(.plain)
            zoneLink(.side)
        }
        .padding(12)
        .background(Theme.deepNavy.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func zoneLink(_ zone: GearKind.Zone) -> some View {
        let count = gear.filter { zone.kinds.contains($0.kind) }.count
        return NavigationLink { GearListView(zone: zone) } label: {
            zoneLabel(count == 0 ? "\(zone.title) · 첫 장비 등록" : "\(zone.title) \(count)개", zone.symbol)
        }
        .buttonStyle(.plain)
    }

    private func zoneLabel(_ title: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.title2).frame(width: 40)
            Text(title).font(.headline)
            Spacer()
            Text("열기").font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.neonPink, in: Capsule())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 90)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 락커 꾸미기 (S14). 번호판·이름표·색·스티커. 바꾸는 즉시 저장한다(LK-14 자동 저장).
struct LockerCustomizeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: LockerProfile
    @Query(sort: \StickerPlacement.zIndex) private var placements: [StickerPlacement]

    @State private var selected: UUID?
    @State private var showingLibrary = false
    @State private var confirmingReset = false

    private var selectedItem: StickerPlacement? { placements.first { $0.id == selected } }

    var body: some View {
        Form {
            Section {
                GeometryReader { geo in
                    ZStack {
                        LockerDoorBase(profile: profile)
                            .onTapGesture { selected = nil }
                        ForEach(placements) { p in
                            EditableSticker(item: p, size: geo.size, isSelected: p.id == selected) {
                                selected = p.id
                            } onEnd: {
                                context.saveOrReport()
                            }
                        }
                    }
                }
                .frame(height: 380)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("락커 문 미리보기, 스티커 \(placements.count)개. 아래 목록에서도 고칠 수 있어.")
                if let item = selectedItem { selectionTools(item) }
                Button { showingLibrary = true } label: { Label("스티커 붙이기", systemImage: "plus.circle.fill") }
            } footer: {
                Text("스티커를 끌어서 옮겨봐. 두 손가락으로 키우고 돌릴 수도 있어. 바꾸면 바로 저장돼.")
            }

            Section("번호판·이름표") {
                HStack {
                    Text("락커 번호")
                    Spacer()
                    TextField("예: 007", text: Binding(
                        get: { profile.numberText },
                        set: { profile.numberText = LockerNumber.normalize($0); context.saveOrReport() }))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                HStack {
                    Text("이름표")
                    Spacer()
                    TextField("MY LOCKER", text: Binding(
                        get: { profile.nameplate },
                        set: { profile.nameplate = String($0.prefix(14)); context.saveOrReport() }))
                        .multilineTextAlignment(.trailing)
                }
                Text("꾸미기용 번호야. 링크장 사물함 예약과는 상관없어.").font(.caption).foregroundStyle(.secondary)
            }

            Section("문 색") {
                HStack(spacing: 10) {
                    ForEach(LockerTheme.allCases, id: \.self) { t in
                        Button {
                            profile.theme = t
                            context.saveOrReport()
                        } label: {
                            VStack(spacing: 4) {
                                Circle().fill(LinearGradient(colors: t.colors, startPoint: .top, endPoint: .bottom))
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().stroke(profile.theme == t ? Theme.neonPink : .clear, lineWidth: 3))
                                Text(t.title).font(.caption2)
                            }
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t.title)
                        .accessibilityAddTraits(profile.theme == t ? .isSelected : [])
                    }
                }
            }

            if !placements.isEmpty {
                Section {
                    ForEach(placements.reversed()) { p in
                        HStack {
                            StickerView(key: p.stickerKey, photo: p.photoData, side: 32)
                            Text(p.stickerKey == "photo" ? "사진 스티커" : (StickerCatalog.def(p.stickerKey)?.title ?? "스티커"))
                            Spacer()
                            if p.id == selected { Image(systemName: "checkmark").foregroundStyle(Theme.neonPink) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = p.id }
                        .accessibilityAddTraits(.isButton)
                    }
                    .onDelete { offsets in
                        let list = Array(placements.reversed())
                        for i in offsets { context.delete(list[i]) }
                        context.saveOrReport()
                    }
                    Button("모든 스티커 떼기", role: .destructive) { confirmingReset = true }
                } header: {
                    Text("붙인 스티커 (위가 맨 앞)")
                } footer: {
                    Text("목록에서 고른 뒤 위 버튼으로 순서·크기·각도를 바꿔도 돼. 왼쪽으로 밀면 떼져.")
                }
            }
        }
        .navigationTitle("락커 꾸미기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { context.saveOrReport(); dismiss() } } }
        .sheet(isPresented: $showingLibrary) {
            NavigationStack { StickerLibraryView { key, photo in add(key, photo: photo) } }
        }
        .confirmationDialog("붙인 스티커를 모두 뗄까?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("모두 떼기", role: .destructive) {
                for p in placements { context.delete(p) }
                selected = nil
                context.saveOrReport()
            }
        } message: {
            Text("받은 스티커는 그대로 남아. 다시 붙일 수 있어.")
        }
    }

    private func selectionTools(_ item: StickerPlacement) -> some View {
        HStack(spacing: 6) {
            tool("arrow.up.to.line", "맨 앞으로") { reorder { StickerOrder.bringToFront(item.id, in: $0) } }
            tool("arrow.down.to.line", "맨 뒤로") { reorder { StickerOrder.sendToBack(item.id, in: $0) } }
            tool("minus.magnifyingglass", "작게") { adjust(item) { $0.scale -= 0.15 } }
            tool("plus.magnifyingglass", "크게") { adjust(item) { $0.scale += 0.15 } }
            tool("rotate.left", "왼쪽으로 돌리기") { adjust(item) { $0.rotation -= 15 } }
            tool("rotate.right", "오른쪽으로 돌리기") { adjust(item) { $0.rotation += 15 } }
            tool("trash", "떼기", role: .destructive) {
                context.delete(item)
                selected = nil
                context.saveOrReport()
            }
        }
        .buttonStyle(.borderless)
    }

    private func tool(_ icon: String, _ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon).frame(maxWidth: .infinity, minHeight: Theme.touch)
        }
        .accessibilityLabel(label)
    }

    private func adjust(_ item: StickerPlacement, _ change: (inout Placement) -> Void) {
        var p = item.placement
        change(&p)
        item.placement = p
        context.saveOrReport()
    }

    private func reorder(_ op: ([UUID]) -> [UUID]) {
        let ids = op(placements.map(\.id))
        for (i, id) in ids.enumerated() { placements.first { $0.id == id }?.zIndex = i }
        context.saveOrReport()
    }

    private func add(_ key: String, photo: Data?) {
        let z = (placements.map(\.zIndex).max() ?? -1) + 1
        let jitter = Double(placements.count % 5) * 0.06
        let p = StickerPlacement(stickerKey: key, x: 0.35 + jitter, y: 0.6 + jitter / 2, zIndex: z)
        p.photoData = photo
        context.insert(p)
        context.saveOrReport()
        selected = p.id
    }
}

/// 손가락으로 옮기고 키우고 돌리는 스티커.
struct EditableSticker: View {
    let item: StickerPlacement
    let size: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onEnd: () -> Void
    @State private var base: Placement?

    var body: some View {
        StickerView(key: item.stickerKey, photo: item.photoData, side: 64)
            .overlay(Circle().stroke(isSelected ? Theme.neonPink : .clear, style: StrokeStyle(lineWidth: 3, dash: [6, 4])).padding(-6))
            .scaleEffect(item.scale)
            .rotationEffect(.degrees(item.rotation))
            .position(x: item.x * size.width, y: item.y * size.height)
            .zIndex(Double(item.zIndex) + (isSelected ? 1000 : 0))
            .gesture(
                SimultaneousGesture(DragGesture(minimumDistance: 2), SimultaneousGesture(MagnifyGesture(), RotateGesture()))
                    .onChanged { value in
                        let b: Placement
                        if let base { b = base } else { b = item.placement; base = b; onSelect() }
                        var p = b
                        if let drag = value.first, size.width > 0, size.height > 0 {
                            p.x = b.x + drag.translation.width / size.width
                            p.y = b.y + drag.translation.height / size.height
                        }
                        if let magnify = value.second?.first { p.scale = b.scale * magnify.magnification }
                        if let rotate = value.second?.second { p.rotation = b.rotation + rotate.rotation.degrees }
                        item.placement = p
                    }
                    .onEnded { _ in
                        base = nil
                        onEnd()
                    })
            .onTapGesture(perform: onSelect)
    }
}

/// 스티커 고르기 (LK-12). 기본·하키·꾸미기, 받은 성취 스티커, 내 사진 스티커.
struct StickerLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var earned: [EarnedSticker]
    var onPick: (String, Data?) -> Void
    @State private var photoItem: PhotosPickerItem?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                group("기본", .basic)
                group("하키", .hockey)
                group("꾸미기", .deco)
                achievements
                photoSection
            }
            .padding(16)
        }
        .navigationTitle("스티커")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let small = ImageShrinker.jpeg(from: data, maxSide: 400) {
                    onPick("photo", small)
                    dismiss()
                }
            }
        }
    }

    private func group(_ title: String, _ kind: StickerDef.Kind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(Theme.title)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(StickerCatalog.all.filter { $0.kind == kind }, id: \.key) { d in
                    pickButton(d, locked: false)
                }
            }
        }
    }

    private var achievements: some View {
        let have = Set(earned.map(\.stickerKey))
        return VStack(alignment: .leading, spacing: 10) {
            Text("성취 스티커").font(.headline).foregroundStyle(Theme.title)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(StickerCatalog.all.filter { $0.kind == .achievement }, id: \.key) { d in
                    pickButton(d, locked: !have.contains(d.key))
                }
            }
            Text("첫 수업, 첫 경기, 첫 골처럼 기록을 남기면 받아. 잠긴 건 기록이 쌓이면 열려.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("내 사진 스티커").font(.headline).foregroundStyle(Theme.title)
            Text("다른 사람 얼굴이나 팀 로고는 허락받은 것만 붙여줘. 사진 스티커는 이 아이폰에만 있어.")
                .font(.caption).foregroundStyle(.secondary)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("사진 고르기", systemImage: "photo.badge.plus").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
        }
    }

    private func pickButton(_ d: StickerDef, locked: Bool) -> some View {
        Button {
            onPick(d.key, nil)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                StickerView(key: d.key, photo: nil, side: 54)
                    .opacity(locked ? 0.25 : 1)
                    .overlay { if locked { Image(systemName: "lock.fill").foregroundStyle(.secondary) } }
                Text(d.title).font(.caption2).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(locked ? "\(d.title), 잠김" : d.title)
    }
}

/// 헬멧·장갑 / 유니폼·보호대 / 스틱·테이프 목록.
struct GearListView: View {
    let zone: GearKind.Zone
    @Query(sort: \GearItem.createdAt) private var all: [GearItem]
    @State private var adding: GearKind?

    var body: some View {
        List {
            ForEach(zone.kinds, id: \.self) { kind in
                Section(kind.title) {
                    let items = all.filter { $0.kind == kind }
                    if items.isEmpty {
                        Text("아직 없어.").foregroundStyle(.secondary)
                    }
                    ForEach(items) { g in
                        NavigationLink { GearEditorView(kind: kind, item: g) } label: {
                            HStack {
                                if let data = g.photo { PhotoThumb(data: data, size: 40) }
                                else { Image(systemName: kind.symbol).frame(width: 40, height: 40).foregroundStyle(Theme.accent) }
                                VStack(alignment: .leading) {
                                    Text(g.name).font(.subheadline.bold())
                                    Text([g.size.isEmpty ? nil : g.size, g.status.title].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button { adding = kind } label: { Label("\(kind.title) 추가", systemImage: "plus") }
                }
            }
        }
        .navigationTitle(zone.title)
        .sheet(item: $adding) { kind in NavigationStack { GearEditorView(kind: kind, item: nil) } }
    }
}

extension GearKind: Identifiable { var id: String { rawValue } }

struct GearEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let kind: GearKind
    let item: GearItem?

    @State private var brand = ""
    @State private var model = ""
    @State private var size = ""
    @State private var status: SkateStatus = .main
    @State private var memo = ""
    @State private var photos: [Data] = []
    @State private var removed: Set<UUID> = []
    @State private var loaded = false

    var body: some View {
        Form {
            Section(kind.title) {
                TextField("브랜드", text: $brand)
                TextField("모델명", text: $model)
                TextField("사이즈", text: $size)
                LabeledChoice(title: "상태", options: SkateStatus.choices, selection: $status, columns: 4, minHeight: 64)
            }
            Section("사진") {
                if let data = item?.photo, photos.isEmpty { PhotoThumb(data: data, size: 90) }
                PhotoPickerRow(existing: [], removedIDs: $removed, added: Binding(get: { photos }, set: { photos = Array($0.suffix(1)) }))
            }
            Section("메모") { TextField("메모", text: $memo, axis: .vertical) }
            if item != nil {
                Section { Text("지우지 말고 '사용 종료'로 바꿔두면 기록이 남아.").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(item == nil ? "\(kind.title) 추가" : kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if item == nil { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
        }
        .onAppear {
            guard !loaded, let item else { return }
            loaded = true
            brand = item.brand; model = item.model; size = item.size; status = item.status; memo = item.memo
        }
    }

    private func save() {
        let target: GearItem
        if let item { target = item } else { target = GearItem(kind: kind); context.insert(target) }
        target.brand = brand.trimmingCharacters(in: .whitespaces)
        target.model = model.trimmingCharacters(in: .whitespaces)
        target.size = size
        target.status = status
        target.memo = memo
        if let p = photos.last { target.photo = p }
        context.saveOrReport()
        dismiss()
    }
}
