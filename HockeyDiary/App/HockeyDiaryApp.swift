import SwiftUI
import SwiftData

@main
struct HockeyDiaryApp: App {
    let container: ModelContainer

    init() {
        let inMemory = CommandLine.arguments.contains("-inMemoryStore")
        do {
            container = try AppSchema.container(inMemory: inMemory)
        } catch {
            // 저장소를 못 열면 앱이 꺼지는 대신 임시 저장소로 띄우고 화면에서 알린다.
            StoreHealth.shared.openFailed = true
            container = try! AppSchema.container(inMemory: true)
        }
        DiaryStore.seedIfNeeded(container.mainContext)
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
