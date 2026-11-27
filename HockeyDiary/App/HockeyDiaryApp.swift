import SwiftUI
import SwiftData

@main
struct HockeyDiaryApp: App {
    let container: ModelContainer

    init() {
        // 화면 점검(-ui-demo)은 실제 기록을 건드리지 않게 메모리 저장소만 쓴다.
        let inMemory = CommandLine.arguments.contains("-inMemoryStore") || DemoData.isEnabled
        #if targetEnvironment(simulator)
        // 화면 테스트는 저장소만 비우고 설정(락커 열림, 루틴 넣었음 표시, 닉네임 등)은 남아서, 앞 테스트가 뒤 테스트 화면을 바꿨다.
        // 테스트로 띄울 때는 설정도 처음 상태로 돌린다. 시뮬레이터에서만 한다(실기기 설정은 절대 지우지 않는다).
        if inMemory, let id = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: id) }
        #endif
        do {
            container = try AppSchema.container(inMemory: inMemory)
        } catch {
            // 저장소를 못 열면 앱이 꺼지는 대신 임시 저장소로 띄우고 화면에서 알린다.
            StoreHealth.shared.openFailed = true
            container = try! AppSchema.container(inMemory: true)
        }
        DiaryStore.seedIfNeeded(container.mainContext)
        if DemoData.isEnabled { DemoData.seed(container.mainContext) }
        WatchBridge.shared.activate(container: container)
        WorkoutNudgeService.shared.start(container: container)
    }

    /// UI 시험은 `-skipSplash`로 시작 화면을 건너뛴다(시작 화면이 첫 누름을 받아 가므로).
    @State private var showingSplash = !ProcessInfo.processInfo.arguments.contains("-skipSplash")

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .tint(Theme.accent)
                if showingSplash {
                    // 누르면 바로 넘어간다. 안 눌러도 잠시 뒤 저절로.
                    SplashView { dismissSplash() }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // 시작 화면에서 이어 받아 잠깐 보여 준 뒤 사라진다. 그동안 뒤의 홈은 이미 그려져 있다.
                try? await Task.sleep(for: .milliseconds(2200))
                dismissSplash()
            }
        }
        .modelContainer(container)
    }

    private func dismissSplash() {
        guard showingSplash else { return }
        withAnimation(.easeOut(duration: 0.3)) { showingSplash = false }
    }
}

/// 저장소 상태. 실패 원인 문구는 로그에 남기지 않는다(일기 본문이 섞일 수 있음).
@Observable
final class StoreHealth {
    static let shared = StoreHealth()
    var openFailed = false
    var lastSaveFailed = false
}


/// 앱 시작 직후 보이는 화면. 링크장 위로 퍽이 미끄러져 들어오고 이름이 뜬다. 아무 데나 누르면 홈으로.
/// iOS 시작 화면은 같은 바탕색(LaunchBackground)만 쓰고, 그림은 여기서 그린다.
struct SplashView: View {
    var onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    SplashRink()
                        .frame(width: w * 1.25, height: h * 0.5)
                        .position(x: w / 2, y: h * 0.82)
                    SplashPuckAndStick(shown: shown || reduceMotion)
                        .frame(width: 220, height: 160)
                        .position(x: w / 2, y: h * 0.40)
                    VStack(spacing: 8) {
                        Text("마하다").font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text("오늘의 하키를 한 줄로").font(.headline).foregroundStyle(.white.opacity(0.85))
                    }
                    .position(x: w / 2, y: h * 0.58)
                    .opacity(shown ? 1 : 0)
                    Text("누르면 시작")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                        .position(x: w / 2, y: h - 60)
                        .opacity(shown ? 1 : 0)
                }
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement()
        .accessibilityLabel("마하다 시작 화면")
        .accessibilityHint("누르면 홈으로 넘어가요")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("splash")
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { shown = true } }
    }
}

/// 위에서 내려다본 링크장 앞부분: 하얀 얼음, 빨간 센터 라인, 파란 라인, 페이스오프 원.
private struct SplashRink: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            let ice = Path(roundedRect: r, cornerRadius: size.height * 0.45)
            ctx.fill(ice, with: .linearGradient(Gradient(colors: [Color(hex: 0xF4FAFF), Color(hex: 0xD6E8FA)]),
                                                 startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
            ctx.stroke(ice, with: .color(Color(hex: 0xFF3E9A)), lineWidth: 6)
            ctx.clip(to: ice)
            let mid = size.width / 2
            ctx.fill(Path(CGRect(x: mid - 5, y: 0, width: 10, height: size.height)), with: .color(Color(hex: 0xE53950)))
            for dx in [-size.width * 0.22, size.width * 0.22] {
                ctx.fill(Path(CGRect(x: mid + dx - 7, y: 0, width: 14, height: size.height)), with: .color(Color(hex: 0x2F6FD6)))
            }
            let c = CGRect(x: mid - size.height * 0.28, y: size.height * 0.12, width: size.height * 0.56, height: size.height * 0.56)
            ctx.stroke(Path(ellipseIn: c), with: .color(Color(hex: 0x2F6FD6)), lineWidth: 4)
            ctx.fill(Path(ellipseIn: CGRect(x: mid - 7, y: c.midY - 7, width: 14, height: 14)), with: .color(Color(hex: 0x2F6FD6)))
            // 스케이트 자국
            var trail = Path()
            trail.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.85))
            trail.addCurve(to: CGPoint(x: size.width * 0.9, y: size.height * 0.75),
                           control1: CGPoint(x: size.width * 0.35, y: size.height * 0.55),
                           control2: CGPoint(x: size.width * 0.6, y: size.height * 1.0))
            ctx.stroke(trail, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [14, 10]))
        }
    }
}

/// 스틱이 퍽을 치고, 퍽이 속도선을 끌며 미끄러져 들어온다.
private struct SplashPuckAndStick: View {
    var shown: Bool
    var body: some View {
        ZStack {
            // 속도선
            VStack(alignment: .trailing, spacing: 10) {
                Capsule().frame(width: 70, height: 6)
                Capsule().frame(width: 100, height: 6)
                Capsule().frame(width: 55, height: 6)
            }
            .foregroundStyle(.white.opacity(0.55))
            .offset(x: -75, y: 22)
            .opacity(shown ? 1 : 0)
            // 퍽
            ZStack {
                Ellipse().fill(Color(hex: 0x0E1726)).frame(width: 96, height: 40).offset(y: 10)
                Ellipse().fill(Color(hex: 0x2A3548)).frame(width: 96, height: 40)
                Ellipse().stroke(Color(hex: 0xFF3E9A), lineWidth: 3).frame(width: 70, height: 26)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 8)
            .offset(x: shown ? 30 : -160, y: 20)
            // 스틱
            StickShape()
                .fill(LinearGradient(colors: [Color(hex: 0xFFD56A), Color(hex: 0xF5A623)], startPoint: .top, endPoint: .bottom))
                .overlay(StickShape().stroke(Color(hex: 0x0E1726).opacity(0.35), lineWidth: 1.5))
                .frame(width: 120, height: 150)
                .rotationEffect(.degrees(shown ? -8 : 18), anchor: .top)
                .offset(x: -55, y: -10)
        }
    }
}

private struct StickShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // 자루(위에서 아래로 비스듬히) + 블레이드(아래에서 오른쪽으로 꺾임)
        p.move(to: CGPoint(x: r.minX + r.width * 0.05, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.16, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.50, y: r.maxY - r.height * 0.14))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.10), control: CGPoint(x: r.width * 0.75, y: r.maxY - r.height * 0.16))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY - r.height * 0.06), control: CGPoint(x: r.width * 0.6, y: r.maxY + 2))
        p.closeSubpath()
        return p
    }
}
