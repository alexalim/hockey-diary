import SwiftUI
import HockeyCore

// 1차 뼈대 확인용 자리표시 화면. 기능 화면이 들어오면 이 파일은 지운다.

struct HomeView: View {
    @Binding var newEntry: NewEntry?
    var body: some View { Text("홈").navigationTitle("홈") }
}

struct DiaryView: View {
    @Binding var newEntry: NewEntry?
    var body: some View { Text("다이어리").navigationTitle("다이어리") }
}

struct GrowthView: View {
    var body: some View { Text("성장").navigationTitle("성장") }
}

struct ExploreView: View {
    var body: some View { Text("탐색").navigationTitle("탐색") }
}

struct LockerView: View {
    var body: some View { Text("락커").navigationTitle("락커") }
}

struct SessionEditorView: View {
    var newType: ActivityType
    var body: some View { Text(newType.title) }
}

struct JournalEditorView: View {
    var newDate: Date
    var body: some View { Text("하루 일기") }
}
