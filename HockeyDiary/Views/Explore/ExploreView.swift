import SwiftUI

/// 탐색 (하키 라이브러리). 규칙 도감·링크장 찾기는 확장 1·2 단계라 지금은 예고만 둔다.
struct ExploreView: View {
    private let topics: [(String, String)] = [
        ("오프사이드", "flag.fill"), ("아이싱", "snowflake"), ("페이스오프", "circle.circle"),
        ("라인체인지", "arrow.left.arrow.right"), ("주요 페널티", "exclamationmark.octagon"), ("포지션", "person.3.fill"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text("하키 라이브러리").font(.title3.bold()).foregroundStyle(.white)
                    Text("규칙 카드·상황 애니메이션·퀴즈와 링크장 찾기를 준비하고 있어.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                Card {
                    CardHeader(title: "규칙 도감 · 곧 열려", systemImage: "book.closed.fill")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(topics, id: \.0) { title, icon in
                            Label(title, systemImage: icon)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .foregroundStyle(Theme.title.opacity(0.6))
                                .background(Theme.iceBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    Text("대회·동호회마다 규칙 적용이 다를 수 있어. 대회 운영 규정을 꼭 확인해줘.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Card {
                    CardHeader(title: "링크장 찾기 · 곧 열려", systemImage: "map.fill")
                    Text("지금은 기록할 때 링크장 이름을 직접 적어줘. 최근 장소를 다음 기록에 제안해줄게.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("탐색")
    }
}
