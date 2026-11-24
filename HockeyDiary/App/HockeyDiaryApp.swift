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
