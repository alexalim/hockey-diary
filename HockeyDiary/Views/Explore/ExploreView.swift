import SwiftUI
import HockeyCore

/// 하키 아카데미 → 규칙·전술. 규칙 도감과 전술 노트.
struct ExploreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text("규칙·전술").font(.title3.bold()).foregroundStyle(.white)
                    Text("헷갈리는 규칙과 전술을 그림으로 익혀봐. 경기에서 겪은 상황을 여기서 다시 봐.")
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
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                Card {
                    CardHeader(title: "전술 노트", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    ForEach(TacticGuide.topics) { t in
                        NavigationLink { TacticDetailView(topic: t) } label: {
                            HStack(spacing: 10) {
                                StatusTag(text: t.tag)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                                    Text(t.summary).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            .frame(minHeight: Theme.touch)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle("규칙·전술")
        .navigationBarTitleDisplayMode(.inline)
    }
}
