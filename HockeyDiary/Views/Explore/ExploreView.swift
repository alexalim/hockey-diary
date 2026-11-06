import SwiftUI
import HockeyCore

/// 탐색 (하키 라이브러리). 규칙 도감과 링크장 찾기.
struct ExploreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text("하키 라이브러리").font(.title3.bold()).foregroundStyle(.white)
                    Text("헷갈리는 규칙과 전술을 그림으로 익혀봐. 링크장도 찾을 수 있어.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                Card {
                    CardHeader(title: "규칙 도감", systemImage: "book.closed.fill")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(RuleGuide.topics) { topic in
                            NavigationLink { RuleDetailView(topic: topic) } label: {
                                VStack(spacing: 6) {
                                    RuleArt(id: topic.id, compact: true)
                                        .frame(height: 64)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                    Label(topic.title, systemImage: topic.symbol)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                        .foregroundStyle(Theme.title)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Theme.iceBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("\(RuleGuide.source)을 보고 쉽게 풀어 썼어. 대회나 동호회마다 다를 수 있으니 꼭 확인해줘.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Card {
                    CardHeader(title: "전술 노트", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    ForEach(TacticGuide.topics) { t in
                        NavigationLink { TacticDetailView(topic: t) } label: {
                            HStack(spacing: 10) {
                                Text(t.tag).font(.caption2.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Theme.neonPink, in: Capsule())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                                    Text(t.summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: Theme.touch)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
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
