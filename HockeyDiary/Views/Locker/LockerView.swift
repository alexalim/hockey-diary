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
    @GestureState private var doorActive = false
    @State private var hinted = false
    @State private var editingProfile: LockerProfile?
    @State private var newStickers: [String] = []

    @Query private var skates: [Skate]
    @Query private var gear: [GearItem]
    @AppStorage(FirstIce.prestarterKey) private var prestarter = false
    @Query private var profiles: [LockerProfile]
    @Query(sort: \StickerPlacement.zIndex) private var placements: [StickerPlacement]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenHeader(eyebrow: "", title: "내 락커", subtitle: "장비도 추억도 여기 다 있어요.")
                    .toolbar { BarAction(icon: "pencil", label: "꾸미기") { editingProfile = LockerStore.profile(context) } }
                if !newStickers.isEmpty { earnedBanner }
                // 입문 전이고 장비가 아직 없으면: 무엇부터 준비할지(락커 칸마다 '등록'만 보이면 할 게 없다).
                if prestarter && gear.isEmpty && skates.isEmpty {
                    NavigationLink { StarterGearView() } label: {
                        HStack(spacing: 12) {
                            AppIcon("tshirt.fill", size: 22).foregroundStyle(Theme.neonPink)
                                .frame(width: 40, height: 40).background(Theme.neonPink.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("처음 장비, 뭐부터?").font(.subheadline.bold()).foregroundStyle(Theme.title)
                                Text("빌려도 되는 것과 먼저 살 것을 나눠 봤어요.").font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer(minLength: 0)
                            AppIcon("chevron.right", size: 12).foregroundStyle(Theme.inkTertiary)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.neonPink.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                GeometryReader { geo in
                    let progress = DoorSwing.progress(angle)
                    ZStack {
                        LockerInside(skateCount: skates.count, gear: gear,
                                     skatePhoto: (skates.first { $0.isPrimary } ?? skates.first)?.coverPhoto)
                            .scaleEffect(0.94 + 0.06 * progress)
                            .brightness(-0.25 * (1 - progress))
                            .allowsHitTesting(angle >= DoorSwing.openAngle - 1)
                        LockerDoor(profile: profiles.first, placements: placements)
                            // 문이 돌수록 빛을 덜 받아 어두워진다.
                            .overlay(Color.black.opacity(0.4 * progress).clipShape(RoundedRectangle(cornerRadius: LockerDoorBase.corner, style: .continuous)))
                            // 경첩은 오른쪽(열린 락커 그림에서 문이 오른쪽에 달려 있다). 왼쪽 손잡이를 오른쪽으로 끌어 연다.
                            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.45)
                            .shadow(color: .black.opacity(0.35 * progress), radius: 18 * progress, x: 10 * progress)
                            .opacity(angle > 88 ? 0 : 1)
                            .allowsHitTesting(angle < 1)
                            .onTapGesture(perform: toggle)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(doorLabel)
                            .accessibilityHint("두 번 탭하면 문이 열려요")
                            .accessibilityAddTraits(.isButton)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(swipe(width: geo.size.width))
                }
                .frame(height: 440)
                .sensoryFeedback(.selection, trigger: latchTick)
                // 스크롤 등에 손가락을 빼앗겨 onEnded가 안 불려도 상태를 정리하고 문을 가까운 쪽으로 보낸다.
                .onChange(of: doorActive) { _, active in
                    guard !active else { return }
                    if dragBase != nil { dragBase = nil; setOpen(angle > DoorSwing.openAngle / 2) }
                    horizontalDrag = nil
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)

                BigToggle(isOn: isOpen, onTitle: "문 닫기", offTitle: "문 열기", onImage: "door.left.hand.open", offImage: "door.left.hand.closed", action: toggle)
                    .frame(maxWidth: 160)
                    .frame(maxWidth: .infinity, minHeight: Theme.touch)

                PaperCard(tape: Theme.tapeMint, tapeAngle: -4) {
                    PaperTitle(text: "바로 가기", systemImage: "list.bullet")
                    NavigationLink { SkateListView() } label: { shortcut("스케이트", "shoeprints.fill", "\(skates.count)켤레", 0, art: "gear-skate") }
                        .buttonStyle(.plain)
                    NavigationLink { RunnerListView() } label: { shortcut("러너(날)", "skateblade", nil, 1) }
                        .buttonStyle(.plain)
                    NavigationLink { RunnerListView(focusSharpening: true) } label: { shortcut("연마", "wrench.and.screwdriver.fill", nil, 2) }
                        .buttonStyle(.plain)
                    ForEach(Array(GearKind.Zone.allCases.enumerated()), id: \.element) { i, zone in
                        let count = gear.filter { zone.kinds.contains($0.kind) }.count
                        NavigationLink { GearListView(zone: zone) } label: { shortcut(zone.title, zone.symbol, "\(count)개", 3 + i, art: zone.art) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingProfile) { profile in
            NavigationStack { LockerCustomizeView(profile: profile) }
        }
        .onAppear {
            let fresh = LockerStore.awardMilestones(context) + QuestStore.awardBadges(context)
            if !fresh.isEmpty { newStickers = fresh }
            angle = isOpen ? DoorSwing.openAngle : 0
            hint()
        }
    }

    /// 손잡이를 잡고 가로로 쓸어 문을 연다. 세로 움직임은 스크롤에 양보한다.
    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($doorActive) { _, state, _ in state = true }
            .onChanged { value in
                if horizontalDrag == nil {
                    horizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard horizontalDrag == true else { return }
                if reduceMotion { return }
                let base = dragBase ?? angle
                if dragBase == nil { dragBase = base }
                let next = DoorSwing.angle(from: base, translation: -value.translation.width, width: width)
                // 문고리가 풀리는 순간 가볍게 한 번 '딸깍'.
                if (angle < DoorSwing.latchAngle) != (next < DoorSwing.latchAngle) { latchTick += 1 }
                angle = next
            }
            .onEnded { value in
                defer { dragBase = nil; horizontalDrag = nil }
                guard horizontalDrag == true else { return }
                let base = dragBase ?? angle
                let predicted = DoorSwing.angle(from: base, translation: -value.predictedEndTranslation.width, width: width)
                if reduceMotion {
                    // 동작 줄이기: 쓸어넘긴 방향으로 바로 여닫는다.
                    setOpen(value.translation.width > 0)
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
        PaperCard(tape: Theme.tapeYellow, tapeAngle: 4, dotted: true) {
            PaperTitle(text: "새 스티커를 받았어요!", systemImage: "gift.fill")
            FlowLayout(spacing: 8) {
                ForEach(Array(newStickers.compactMap { StickerCatalog.def($0)?.title }.enumerated()), id: \.offset) { i, title in
                    Sticker(text: title, index: i, on: false, small: true)
                }
            }
            .padding(.vertical, 2)
            Text("내 기록으로 받은 스티커예요. 꾸미기에서 문에 붙여 보세요.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
        }
    }

    /// 바로 가기 한 줄. 파스텔 동그라미 아이콘, 오른쪽 개수는 작은 스티커.
    private func shortcut(_ title: String, _ icon: String, _ trailing: String?, _ index: Int, art: String? = nil) -> some View {
        HStack(spacing: 12) {
            if let art {
                Image(art).resizable().scaledToFit().frame(width: 44, height: 44).accessibilityHidden(true)
            } else {
                AppIcon(icon, size: 20)
                    .foregroundStyle(Theme.paperInk)
                    .frame(width: 40, height: 40)
                    .background(Theme.stickers[index % Theme.stickers.count], in: Circle())
            }
            Text(title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.paperInk)
            Spacer(minLength: 0)
            if let trailing { Sticker(text: trailing, index: index, on: false, small: true) }
            AppIcon("chevron.right").font(.caption).foregroundStyle(Theme.paperInkSoft)
        }
        .frame(minHeight: Theme.touch)
        .contentShape(Rectangle())
    }

    private func toggle() {
        // 드래그 중의 탭은 무시한다.
        guard dragBase == nil else { return }
        setOpen(!isOpen)
    }
}

extension GearKind.Zone {
    /// 칸을 대표하는 장비 그림.
    var art: String {
        switch self {
        case .top: return "gear-gloves"
        case .middle: return "gear-jersey"
        case .side: return "gear-stick"
        }
    }
}

extension LockerTheme {
    var colors: [Color] {
        switch self {
        case .cobalt: return [Theme.cobalt, Theme.deepNavy]
        case .navy: return Theme.navyDoor
        case .neonPink: return Theme.pinkDoor
        case .iceBlue: return Theme.iceDoor
        case .strawberry: return Theme.strawberryDoor
        case .mint: return Theme.mintDoor
        case .lemon: return Theme.lemonDoor
        case .lavender: return Theme.lavenderDoor
        }
    }
}

/// 락커 문 바탕(번호판·이름표·통풍구·손잡이).
struct LockerDoorBase: View {
    var profile: LockerProfile?
    /// 문·안쪽·스윙 그림자가 같이 쓰는 모서리. 하나만 바꾸면 문이 돌 때 귀퉁이가 어긋난다.
    static let corner: CGFloat = 22

    /// 테마별 문 그림 이름. 그림이 들어오면 자동으로 그림을 쓰고, 없으면 코드로 그린 문을 쓴다.
    static func artName(_ theme: LockerTheme) -> String { "locker-door-\(theme.rawValue)" }

    @AppStorage(MyPrefs.nicknameKey) private var nicknameForPlate = ""

    static func plateText(_ plate: String?, nickname: String) -> String {
        let p = (plate ?? "").trimmingCharacters(in: .whitespaces)
        if !p.isEmpty && p != "MY LOCKER" { return p }
        return nickname.isEmpty ? "내 락커" : nickname
    }

    var body: some View {
        let theme = profile?.theme ?? .cobalt
        if UIImage(named: Self.artName(theme)) != nil {
            artDoor(theme)
        } else {
            drawnDoor(theme)
        }
    }

    /// 그림 문: 문·손잡이·통풍구·질감은 그림에, 이름표와 번호만 코드로 얹는다.
    /// 스티커 좌표는 문 크기 대비 비율이라 그림이 틀을 꽉 채워야 한다(늘려서 채운다).
    private func artDoor(_ theme: LockerTheme) -> some View {
        Image(Self.artName(theme))
            .resizable()
            .scaleEffect(x: -1, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
            .overlay(alignment: .top) { plates.padding(.top, 34) }
    }

    private func drawnDoor(_ theme: LockerTheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
        let line: Color = theme.isPastel ? Theme.doorInk : .white
        return shape
            .fill(LinearGradient(colors: theme.colors, startPoint: .top, endPoint: .bottom))
            // 가장자리 바느질 선
            .overlay(shape.inset(by: 7).stroke(line.opacity(theme.isPastel ? 0.22 : 0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6])))
            .overlay(alignment: .top) {
                VStack(spacing: 18) {
                    plates
                    // 통풍구: 말랑한 캡슐
                    VStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { _ in
                            Capsule().fill(line.opacity(theme.isPastel ? 0.12 : 0.22)).frame(width: 128, height: 8)
                        }
                    }
                }
                .padding(.top, 34)
            }
            .overlay(alignment: .leading) {
                // 손잡이: 파스텔 사탕(경첩이 오른쪽이라 왼쪽에)
                Capsule().fill(theme.isPastel ? Color.white : Theme.stickers[0])
                    .frame(width: 16, height: 72)
                    .overlay(Capsule().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .padding(.leading, 22)
            }
    }

    /// 이름표와 번호. 그림 문과 코드 문이 같이 쓴다.
    private var plates: some View {
                VStack(spacing: 18) {
                    // 이름표: 테이프로 붙인 종이 쪽지
                    // 기본 이름표가 영어 'MY LOCKER'였다. 손대지 않았으면 닉네임, 없으면 '내 락커'.
                    Text(LockerDoorBase.plateText(profile?.nameplate, nickname: nicknameForPlate))
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.paperInk)
                        .lineLimit(1)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(alignment: .top) { WashiTape(color: Theme.tapePink, angle: -5, width: 56).offset(y: -9) }
                        .rotationEffect(.degrees(-2))
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                    // 번호: 동그란 스티커
                    if let n = profile?.numberText, !n.isEmpty {
                        Text(n)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.paperInk)
                            .padding(.horizontal, 10)
                            .frame(minWidth: 70, minHeight: 70)
                            .background(Theme.stickers[1], in: Capsule())
                            .overlay(Capsule().stroke(.white, lineWidth: 4))
                            .rotationEffect(.degrees(6))
                            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                    }
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
            Label("손잡이를 밀어서 열기", icon: "chevron.right.2").font(.caption)
                .foregroundStyle((profile?.theme.isPastel ?? false) ? Theme.doorInk.opacity(0.7) : Color.white.opacity(0.8))
                .padding(.bottom, 16)
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
                .overlay(Circle().stroke(.white, lineWidth: max(3, side * 0.07)))
                .shadow(color: Theme.deepNavy.opacity(0.18), radius: 3, y: 2)
        } else if let def = StickerCatalog.def(key) {
            let (fg, bg) = Self.colors(def.palette)
            AppIcon(def.symbol, size: side * 0.5)
                .foregroundStyle(fg)
                .frame(width: side, height: side)
                .background(bg, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: max(3, side * 0.07)))
                .shadow(color: Theme.deepNavy.opacity(0.18), radius: 3, y: 2)
        } else {
            Circle().fill(Theme.inkTertiary.opacity(0.4)).frame(width: side, height: side)
        }
    }

    static func colors(_ palette: Int) -> (Color, Color) {
        switch palette {
        case 0: return (Theme.paperInk, Theme.stickers[0])   // 분홍
        case 1: return (Theme.paperInk, Theme.stickers[3])   // 하늘
        case 3: return (Theme.deepNavy, Theme.gold)          // 배지는 금색 그대로
        default: return (Theme.paperInk, Theme.stickers[2])  // 민트
        }
    }
}

/// 열린 락커 안. 장비 구역 핫스팟.
struct LockerInside: View {
    var skateCount: Int
    var gear: [GearItem]
    /// 주력 스케이트 사진(없으면 스케이트 그림).
    var skatePhoto: Data? = nil

    /// 그림 안에서 칸이 차지하는 자리(가로·세로 0~1). 그림을 바꾸면 여기도 맞춘다.
    private enum Spot {
        static let helmet = CGRect(x: 0.05, y: 0.07, width: 0.55, height: 0.19)
        static let uniform = CGRect(x: 0.05, y: 0.27, width: 0.55, height: 0.32)
        static let gloves = CGRect(x: 0.05, y: 0.60, width: 0.55, height: 0.14)
        static let skates = CGRect(x: 0.05, y: 0.75, width: 0.55, height: 0.19)
        static let stick = CGRect(x: 0.61, y: 0.13, width: 0.13, height: 0.72)
    }

    var body: some View {
        // 열린 락커 그림 위에 칸마다 투명한 버튼을 얹는다. 칸 이름은 그림에 적혀 있고, 개수만 알약으로 붙인다.
        Image("locker-open")
            .resizable().scaledToFit()
            .overlay {
                GeometryReader { g in
                    ZStack(alignment: .topLeading) {
                        // 등록한 장비가 있는 칸은 흐린 윤곽 위에 장비 그림(사진이 있으면 사진)을 얹는다(빌드 94 피드백).
                        filled([.helmet], art: nil, Spot.helmet, in: g.size)
                        filled([.jersey, .pants, .shoulder, .elbow, .shin, .pads], art: "gear-jersey", Spot.uniform, in: g.size)
                        filled([.neck, .gloves, .tape], art: "gear-gloves", Spot.gloves, in: g.size)
                        filled([.stick], art: "gear-stick", Spot.stick, in: g.size)
                        if skateCount > 0 { picture(photo: skatePhoto, art: "gear-skate").placed(Spot.skates, in: g.size) }
                        zone(.top, Spot.helmet, in: g.size)
                        zone(.middle, Spot.uniform, in: g.size)
                        zone(.top, Spot.gloves, in: g.size, showBadge: false)
                        skates(in: g.size)
                        zone(.side, Spot.stick, in: g.size)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 이 종류의 장비가 하나라도 있으면 그 칸에 그림을 얹는다. 그림 파일이 없는 종류(헬멧)는 사진이 있을 때만.
    @ViewBuilder
    private func filled(_ kinds: [GearKind], art: String?, _ spot: CGRect, in size: CGSize) -> some View {
        let items = gear.filter { kinds.contains($0.kind) }
        let photo = items.first { $0.photo != nil }?.photo
        if !items.isEmpty, photo != nil || art != nil {
            picture(photo: photo, art: art).placed(spot, in: size)
        }
    }

    /// 칸 안에 놓는 그림: 락커 그림체에 맞게 장비 그림을 크게 두고, 내 사진이 있으면 모서리에 작은 폴라로이드로 붙인다.
    /// 그림이 없는 종류(헬멧)는 사진을 크게 둔다.
    @ViewBuilder
    private func picture(photo: Data?, art: String?) -> some View {
        GeometryReader { g in
            ZStack(alignment: .bottomTrailing) {
                if let art {
                    Image(art).resizable().scaledToFit()
                        .frame(width: g.size.width * 0.88, height: g.size.height * 0.88)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .frame(width: g.size.width, height: g.size.height)
                    if let photo, let ui = UIImage(data: photo) {
                        let side = min(g.size.width, g.size.height) * 0.42
                        polaroid(ui, side: side).rotationEffect(.degrees(6)).offset(x: -2, y: -2)
                    }
                } else if let photo, let ui = UIImage(data: photo) {
                    polaroid(ui, side: min(g.size.width, g.size.height) * 0.8)
                        .frame(width: g.size.width, height: g.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func polaroid(_ ui: UIImage, side: CGFloat) -> some View {
        Image(uiImage: ui).resizable().scaledToFill()
            .frame(width: side, height: side)
            .clipped()
            .padding(3).padding(.bottom, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    private func zone(_ zone: GearKind.Zone, _ spot: CGRect, in size: CGSize, showBadge: Bool = true) -> some View {
        let count = gear.filter { zone.kinds.contains($0.kind) }.count
        return NavigationLink { GearListView(zone: zone) } label: {
            hitArea(badge: showBadge ? (count == 0 ? "등록" : "\(count)개") : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count == 0 ? "\(zone.title), 아직 비어 있어요" : "\(zone.title) \(count)개")
        .placed(spot, in: size)
    }

    private func skates(in size: CGSize) -> some View {
        NavigationLink { SkateListView() } label: {
            hitArea(badge: skateCount == 0 ? "등록" : "\(skateCount)켤레")
        }
        .buttonStyle(.plain)
        // UI 테스트가 "스케이트 1켤레"를 글자 하나로 찾는다. 나누지 말 것.
        .accessibilityLabel(skateCount == 0 ? "스케이트, 아직 비어 있어요" : "스케이트 \(skateCount)켤레")
        .placed(Spot.skates, in: size)
    }

    private func hitArea(badge: String?) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(.system(.caption2, design: .rounded).bold())
                        .lineLimit(1).fixedSize()   // 좁은 스틱 칸에서 글자가 세로로 꺾이지 않게
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Theme.neonPink, in: Capsule())
                        .padding(4)
                }
            }
    }
}

private extension View {
    /// 그림 안의 비율 자리에 놓는다.
    func placed(_ spot: CGRect, in size: CGSize) -> some View {
        frame(width: spot.width * size.width, height: spot.height * size.height)
            .position(x: spot.midX * size.width, y: spot.midY * size.height)
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
                .listRowBackground(Theme.paper)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("락커 문 미리보기, 스티커 \(placements.count)개. 아래 목록에서도 고칠 수 있어요.")
                if let item = selectedItem { selectionTools(item).listRowBackground(Theme.paper) }
                Button { showingLibrary = true } label: {
                    Label("스티커 붙이기", icon: "plus.circle.fill")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
                .listRowBackground(Theme.paper)
            } footer: {
                Text("스티커를 끌어서 옮겨 보세요. 두 손가락으로 키우고 돌릴 수도 있어요. 바꾸면 바로 저장돼요.")
                    .foregroundStyle(Theme.paperInkSoft)
            }

            Section {
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
                    TextField("내 락커", text: Binding(
                        get: { profile.nameplate },
                        set: { profile.nameplate = String($0.prefix(14)); context.saveOrReport() }))
                        .multilineTextAlignment(.trailing)
                }
                Text("꾸미기용 번호예요. 링크장 사물함 예약과는 상관없어요.").font(.caption).foregroundStyle(Theme.paperInkSoft)
            } header: {
                paperHeader("번호판·이름표", "pencil", Theme.tapeYellow)
            }
            .listRowBackground(Theme.paper)

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                    ForEach(LockerTheme.allCases, id: \.self) { t in
                        Button {
                            profile.theme = t
                            context.saveOrReport()
                        } label: {
                            VStack(spacing: 4) {
                                Circle().fill(LinearGradient(colors: t.colors, startPoint: .top, endPoint: .bottom))
                                    .frame(width: 42, height: 42)
                                    .overlay(Circle().stroke(.white, lineWidth: 3))
                                    .overlay(Circle().stroke(profile.theme == t ? Theme.neonPink : .clear, lineWidth: 3).padding(-4))
                                    .shadow(color: Theme.deepNavy.opacity(0.15), radius: 2, y: 1)
                                    .scaleEffect(profile.theme == t ? 1.08 : 1)
                                Text(t.title).font(.system(.caption2, design: .rounded)).foregroundStyle(Theme.paperInk)
                            }
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t.title)
                        .accessibilityAddTraits(profile.theme == t ? .isSelected : [])
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: profile.theme)
            } header: {
                paperHeader("문 색", "paintbrush.fill", Theme.tapeMint)
            }
            .listRowBackground(Theme.paper)

            if !placements.isEmpty {
                Section {
                    ForEach(placements.reversed()) { p in
                        HStack {
                            StickerView(key: p.stickerKey, photo: p.photoData, side: 32)
                            Text(p.stickerKey == "photo" ? "사진 스티커" : (StickerCatalog.def(p.stickerKey)?.title ?? "스티커"))
                            Spacer()
                            if p.id == selected { AppIcon("checkmark").foregroundStyle(Theme.neonPink) }
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
                    paperHeader("붙인 스티커 (위가 맨 앞)", "seal", Theme.tapePink)
                } footer: {
                    Text("목록에서 고른 뒤 위 버튼으로 순서·크기·각도를 바꿔도 돼요. 왼쪽으로 밀면 떼져요.")
                        .foregroundStyle(Theme.paperInkSoft)
                }
                .listRowBackground(Theme.paper)
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Theme.paperInk)
        .scrollContentBackground(.hidden)
        .listRowSeparatorTint(Theme.paperDot)
        .screenBackground()
        .navigationTitle("락커 꾸미기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { context.saveOrReport(); dismiss() } } }
        .sheet(isPresented: $showingLibrary) {
            NavigationStack { StickerLibraryView { key, photo in add(key, photo: photo) } }
        }
        .confirmationDialog("붙인 스티커를 모두 뗄까요?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("모두 떼기", role: .destructive) {
                for p in placements { context.delete(p) }
                selected = nil
                context.saveOrReport()
            }
        } message: {
            Text("받은 스티커는 그대로 남아요. 다시 붙일 수 있어요.")
        }
    }

    /// 섹션 제목: 테이프 한 조각 + 둥근 글꼴.
    private func paperHeader(_ text: String, _ icon: String, _ tape: Color) -> some View {
        PaperTitle(text: text, systemImage: icon)
            .textCase(nil)
            .padding(.top, 10)
            .overlay(alignment: .topLeading) { WashiTape(color: tape, angle: -4, width: 40).offset(x: -6, y: -2) }
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
            AppIcon(icon)
                .foregroundStyle(role == .destructive ? Theme.danger : Theme.paperInk)
                .frame(width: 40, height: 40)
                .background(role == .destructive ? Theme.dangerSoft : Theme.stickers[3], in: Circle())
                .frame(maxWidth: .infinity, minHeight: Theme.touch)
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
    @GestureState private var active = false

    var body: some View {
        StickerView(key: item.stickerKey, photo: item.photoData, side: 64)
            .overlay(Circle().stroke(isSelected ? Theme.neonPink : .clear, style: StrokeStyle(lineWidth: 3, dash: [6, 4])).padding(-6))
            .scaleEffect(item.scale)
            .rotationEffect(.degrees(item.rotation))
            .position(x: item.x * size.width, y: item.y * size.height)
            .zIndex(Double(item.zIndex) + (isSelected ? 1000 : 0))
            .gesture(
                SimultaneousGesture(DragGesture(minimumDistance: 2), SimultaneousGesture(MagnifyGesture(), RotateGesture()))
                    .updating($active) { _, state, _ in state = true }
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
            // 제스처가 취소돼도 기준점을 비워서 다음 드래그가 튀지 않게 한다.
            .onChange(of: active) { _, isActive in
                if !isActive, base != nil { base = nil; onEnd() }
            }
    }
}

/// 스티커 고르기 (LK-12). 기본·하키·꾸미기, 받은 성취 스티커, 내 사진 스티커.
struct StickerLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var earned: [EarnedSticker]
    var onPick: (String, Data?) -> Void
    @State private var photoItem: PhotosPickerItem?
    @State private var photoFailed = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                group("기본", .basic, Theme.tapePink)
                group("하키", .hockey, Theme.tapeMint)
                group("꾸미기", .deco, Theme.tapeYellow)
                achievements
                photoSection
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 16)
        }
        .screenBackground()
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
                } else {
                    photoFailed = true
                }
            }
        }
        .alert("사진을 불러오지 못했어요", isPresented: $photoFailed) { Button("확인", role: .cancel) {} } message: { Text("다른 사진을 골라 주세요.") }
    }

    private func group(_ title: String, _ kind: StickerDef.Kind, _ tape: Color) -> some View {
        PaperCard(tape: tape, tapeAngle: -4, dotted: true) {
            PaperTitle(text: title, systemImage: "seal")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(StickerCatalog.all.filter { $0.kind == kind }, id: \.key) { d in
                    pickButton(d, locked: false)
                }
            }
        }
    }

    private var achievements: some View {
        let have = Set(earned.map(\.stickerKey))
        return PaperCard(tape: Theme.tapeYellow, tapeAngle: 4, dotted: true) {
            PaperTitle(text: "성취 스티커", systemImage: "medal.fill")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(StickerCatalog.all.filter { $0.kind == .achievement }, id: \.key) { d in
                    pickButton(d, locked: !have.contains(d.key))
                }
                ForEach(earned.filter { $0.stickerKey.hasPrefix("badge-") }.sorted { $0.stickerKey > $1.stickerKey }, id: \.stickerKey) { e in
                    if let d = StickerCatalog.def(e.stickerKey) { pickButton(d, locked: false) }
                }
            }
            Text("첫 수업, 첫 경기, 첫 골처럼 기록을 남기면 받아요. 잠긴 건 기록이 쌓이면 열려요. 이달 퀘스트를 채우면 그달 배지도 생겨요.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
        }
    }

    private var photoSection: some View {
        PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
            PaperTitle(text: "내 사진 스티커", systemImage: "camera")
            Text("다른 사람 얼굴이나 팀 로고는 허락받은 것만 붙여 주세요. 사진 스티커는 이 아이폰에만 있어요.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("사진 고르기", icon: "photo.badge.plus")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
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
                    .overlay { if locked { AppIcon("lock.fill").foregroundStyle(Theme.paperInkSoft) } }
                Text(d.title).font(.system(.caption2, design: .rounded)).foregroundStyle(Theme.paperInk).lineLimit(1)
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

    private let tapes = [Theme.tapePink, Theme.tapeMint, Theme.tapeYellow]
    private let angles: [Double] = [-4, 3, -2]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(zone.kinds.enumerated()), id: \.element) { k, kind in
                    let items = all.filter { $0.kind == kind }
                    PaperCard(tape: tapes[k % tapes.count], tapeAngle: angles[k % angles.count]) {
                        PaperTitle(text: kind.title, systemImage: kind.symbol)
                        if items.isEmpty {
                            EmptyHint(text: "아직 없어요.", systemImage: kind.symbol)
                        }
                        // 등록한 장비는 스티커처럼: 두 칸 격자, 흰 테두리, 조금씩 기울여 붙인 모양.
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, g in
                                NavigationLink { GearEditorView(kind: kind, item: g) } label: {
                                    GearStickerTile(index: i + k, title: g.name,
                                                    detail: g.size.isEmpty ? nil : g.size, badge: g.status.title,
                                                    photo: g.photo, art: GearKind.Zone.allCases.first { $0.kinds.contains(kind) }?.art,
                                                    symbol: kind.symbol)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        Button { adding = kind } label: {
                            Label("\(kind.title) 추가", icon: "plus")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(Theme.accentText)
                                .frame(maxWidth: .infinity, minHeight: Theme.touch)
                                .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.paperDot, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle(zone.title)
        .sheet(item: $adding) { kind in NavigationStack { GearEditorView(kind: kind, item: nil) } }
    }

    /// 장비 한 줄. 사진은 폴라로이드, 없으면 파스텔 동그라미. 상태는 작은 스티커.
    static func stickerIndex(_ status: SkateStatus) -> Int {
        switch status {
        case .main: return 0
        case .sub: return 1
        case .stored: return 2
        case .retired: return 4
        }
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
    @State private var removePhoto = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PaperCard(tape: Theme.tapePink, tapeAngle: -4) {
                    PaperTitle(text: kind.title, systemImage: kind.symbol)
                    field("브랜드", text: $brand)
                    field("모델명", text: $model)
                    field("사이즈", text: $size)
                    LabeledChoice(title: "상태", options: SkateStatus.choices, selection: $status, columns: 4, minHeight: 64)
                }
                PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
                    PaperTitle(text: "사진", systemImage: "camera")
                    if let data = item?.photo, photos.isEmpty, !removePhoto {
                        HStack(spacing: 16) {
                            PolaroidThumb(data: data, size: 90)
                            Button("사진 빼기", role: .destructive) { removePhoto = true }
                                .font(.system(.subheadline, design: .rounded))
                                .buttonStyle(.borderless)
                        }
                    }
                    PhotoPickerRow(existing: [], removedIDs: $removed, added: Binding(get: { photos }, set: { photos = Array($0.suffix(1)) }))
                }
                PaperCard(tape: Theme.tapeYellow, tapeAngle: -2, dotted: true) {
                    PaperTitle(text: "메모", systemImage: "pencil.line")
                    field("메모", text: $memo, vertical: true)
                }
                if item != nil {
                    Text("지우지 말고 '사용 종료'로 바꿔두면 기록이 남아요.")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: save) {
                    Label("저장하기", icon: "heart.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
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

    /// 종이 위 입력 칸. Form 밖이라 반투명 바탕을 깐다.
    private func field(_ title: String, text: Binding<String>, vertical: Bool = false) -> some View {
        Group {
            if vertical {
                TextField(title, text: text, axis: .vertical).lineLimit(3...8)
            } else {
                TextField(title, text: text)
            }
        }
        .font(.system(.body, design: .rounded))
        .foregroundStyle(Theme.paperInk)
        .tint(Theme.accentText)
        .padding(10)
        .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func save() {
        let target: GearItem
        if let item { target = item } else { target = GearItem(kind: kind); context.insert(target) }
        target.brand = brand.trimmingCharacters(in: .whitespaces)
        target.model = model.trimmingCharacters(in: .whitespaces)
        target.size = size
        target.status = status
        target.memo = memo
        if let p = photos.last { target.photo = p } else if removePhoto { target.photo = nil }
        context.saveOrReport()
        dismiss()
    }
}


/// 등록한 장비 한 개를 스티커처럼 보여 준다: 파스텔 바탕, 두꺼운 흰 테두리, 살짝 그림자, 조금씩 다른 기울기.
/// 사진이 있으면 사진을 흰 테두리로 오려 붙이고, 없으면 장비 그림(없으면 아이콘)을 쓴다.
struct GearStickerTile: View {
    let index: Int
    let title: String
    var detail: String?
    var badge: String?
    var photo: Data?
    var art: String?
    var symbol: String

    private static let tilts: [Double] = [-2.5, 1.8, -1.2, 2.4, -1.8, 1.2]

    var body: some View {
        VStack(spacing: 6) {
            picture.frame(height: 76)
            Text(title)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(Theme.paperInk)
                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
            if let detail {
                Text(detail).font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft).lineLimit(1)
            }
            if let badge { Sticker(text: badge, index: index, on: false, small: true) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 168)
        .background(Theme.stickers[index % Theme.stickers.count], in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        // 오려 낸 스티커의 흰 가장자리
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 5))
        .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 3)
        .rotationEffect(.degrees(Self.tilts[index % Self.tilts.count]))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var picture: some View {
        if let photo, let ui = UIImage(data: photo) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white, lineWidth: 3))
                .rotationEffect(.degrees(-3))
        } else if let art {
            Image(art).resizable().scaledToFit()
        } else {
            AppIcon(symbol, size: 34).foregroundStyle(Theme.paperInk)
        }
    }
}
