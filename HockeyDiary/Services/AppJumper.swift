import SwiftUI

/// "어디로 가라"는 안내문 옆 버튼이 실제로 그곳으로 데려가게 하는 통로.
/// 어느 화면이든 `@Environment(AppJumper.self)`로 받아 `go(_:)`를 부르면 RootView가 탭을 바꾸고 시트를 연다.
enum AppJump: Hashable {
    /// 탭만 바꾼다.
    case tab(RootView.Tab)
    /// 훈련 탭의 갈래(연습·경기·드릴)까지 고른다.
    case training(TrainingView.Branch)
    /// 기록 시트를 연다(열려 있던 시트는 닫고).
    case entry(NewEntry)
    /// 홈의 설정 시트를 연다.
    case settings
}

@Observable
final class AppJumper {
    /// 요청. RootView가 처리하고 nil로 되돌린다.
    var request: AppJump?
    /// 훈련 탭이 다음에 보일 때 골라야 할 갈래.
    var pendingBranch: TrainingView.Branch?
    /// 홈이 설정 시트를 열어야 하는지.
    var pendingSettings = false

    func go(_ jump: AppJump) { request = jump }
}
