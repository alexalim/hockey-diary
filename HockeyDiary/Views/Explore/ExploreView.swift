import SwiftUI
import HockeyCore

/// 탐색 (하키 라이브러리). 규칙 도감과 링크장 찾기.
struct ExploreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text("하키 라이브러리").font(.title3.bold()).foregroundStyle(.white)
                    Text("규칙 카드·상황 도식·퀴즈로 헷갈리는 규칙을 익히고, 링크장을 찾아봐.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                Card {
                    CardHeader(title: "규칙 도감", systemImage: "book.closed.fill")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(RuleGuide.topics) { topic in
                            NavigationLink { RuleDetailView(topic: topic) } label: {
                                Label(topic.title, systemImage: topic.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .foregroundStyle(Theme.title)
                                    .background(Theme.iceBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("\(RuleGuide.source) 기준으로 직접 정리했어. 대회·동호회마다 규칙 적용이 다를 수 있으니 대회 운영 규정을 꼭 확인해줘.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                NavigationLink { RinkFinderView() } label: {
                    Card {
                        CardHeader(title: "링크장 찾기", systemImage: "map.fill")
                        Text("이름이나 지역으로 찾고, 즐겨찾기와 내가 확인한 시설 정보를 모아둬.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("탐색")
    }
}
