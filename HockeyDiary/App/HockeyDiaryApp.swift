import SwiftUI
import SwiftData

/// 화면 방향. 앱은 세로 고정이고, 경기 점수판이 열려 있을 때만 가로를 허용한다.
final class OrientationDelegate: NSObject, UIApplicationDelegate {
    static var allowLandscape = false

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.allowLandscape ? .allButUpsideDown : .portrait
    }

    /// 허용 방향을 바꾸고, 원하면 그쪽으로 돌린다.
    @MainActor
    static func set(landscape: Bool) {
        allowLandscape = landscape
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        // 떠 있는 화면(전체 화면 점수판 포함)마다 허용 방향을 다시 읽게 한다. 맨 아래 화면만 알리면 위 화면이 안 돈다.
        var vc = scene.windows.first?.rootViewController
        while let v = vc { v.setNeedsUpdateOfSupportedInterfaceOrientations(); vc = v.presentedViewController }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscapeRight : .portrait)) { _ in }
    }
}

@main
struct HockeyDiaryApp: App {
    @UIApplicationDelegateAdaptor(OrientationDelegate.self) private var orientation
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
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
