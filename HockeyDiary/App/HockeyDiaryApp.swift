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
                // UI 시험은 `-holdSplash`로 저절로 넘어가지 않게 해 '누르면 넘어감'만 본다
                // (앱이 한가해질 때까지 기다리는 시험 시작이 2초를 넘겨 그림을 못 보고 지나갔다).
                guard !ProcessInfo.processInfo.arguments.contains("-holdSplash") else { return }
                try? await Task.sleep(for: .milliseconds(2500))
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


/// 앱 시작 직후 보이는 화면. 사용자가 준 로딩 그림(12장 움직이는 그림)을 0.12초마다 넘겨 재생한다.
/// 그림은 정사각형이라 화면 폭에 맞춰 가운데 두고, 위아래는 그림 가장자리 색으로 이어 칠한다.
/// 아무 데나 누르면 홈으로. iOS 시작 화면은 같은 남색(LaunchBackground)만 쓴다.
struct SplashView: View {
    var onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let frames = (0..<12).map { String(format: "splash-%02d", $0) }
    private static let top = Color(hex: 0x183879), bottom = Color(hex: 0x052161)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            TimelineView(.animation(minimumInterval: 0.12, paused: reduceMotion)) { ctx in
                let n = reduceMotion ? 0 : Int(ctx.date.timeIntervalSinceReferenceDate / 0.12) % Self.frames.count
                Image(Self.frames[n])
                    .resizable()
                    .scaledToFit()
                    // 그림 위아래 가장자리를 바탕으로 녹여 네모 경계가 안 보이게
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                                                 .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
            VStack {
                Spacer()
                Text("누르면 시작")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement()
        .accessibilityLabel("마하다 시작 화면")
        .accessibilityHint("누르면 홈으로 넘어가요")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("splash")
    }
}
