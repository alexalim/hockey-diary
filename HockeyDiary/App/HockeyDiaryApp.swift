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

    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .tint(Theme.accent)
                if showingSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // 시작 화면에서 이어 받아 잠깐 보여 준 뒤 사라진다. 그동안 뒤의 홈은 이미 그려져 있다.
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.35)) { showingSplash = false }
            }
        }
        .modelContainer(container)
    }
}

/// 저장소 상태. 실패 원인 문구는 로그에 남기지 않는다(일기 본문이 섞일 수 있음).
@Observable
final class StoreHealth {
    static let shared = StoreHealth()
    var openFailed = false
    var lastSaveFailed = false
}


/// 앱 시작 직후 잠깐 보이는 화면. iOS 시작 화면(LaunchBackground + LaunchLogo)과 같은 색·같은 자리·같은 크기라
/// 넘어가는 순간이 끊기지 않는다. 그 아래로 이름이 떠오르고, 홈으로 부드럽게 사라진다. 누름은 받지 않는다.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo")
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .scaleEffect(shown && !reduceMotion ? 1.04 : 1)
            VStack(spacing: 6) {
                Text("마하다").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("오늘의 하키를 한 줄로").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            }
            .offset(y: 150)
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { shown = true } }
    }
}
