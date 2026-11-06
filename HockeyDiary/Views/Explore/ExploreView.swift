import SwiftUI
import HockeyCore

/// 탐색 (하키 라이브러리). 규칙 도감과 링크장 찾기.
struct ExploreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text("하키 라이브러리").font(.title3.bold()).foregroundStyle(.white)
                    Text("헷갈리는 규칙을 그림과 퀴즈로 익혀봐. 링크장도 찾을 수 있어.")
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
                    Text("\(RuleGuide.source)을 보고 쉽게 풀어 썼어. 대회나 동호회마다 다를 수 있으니 꼭 확인해줘.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                NavigationLink { RinkFinderView() } label: {
                    Card {
                        CardHeader(title: "링크장 찾기", systemImage: "map.fill")
                        Text("이름이나 동네로 찾아봐. 자주 가는 곳과 시설 정보를 모아둘 수 있어.")
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
