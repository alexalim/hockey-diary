import SwiftUI
import HockeyCore

/// 새 기록 저장 직후 화면: 저장됐다는 확인 → 이번 기록 요약 → 새 개인 기록 → 공유.
struct SessionSavedView: View {
    let session: Session
    let bests: [PersonalBest]
    let shotCount: Int
    var onClose: () -> Void

    @State private var shareImage: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56)).foregroundStyle(Theme.success)
                        .symbolEffect(.bounce, value: true)
                    Text("저장했어").font(.title2.bold()).foregroundStyle(Theme.title)
                    Text("다이어리와 성장에 바로 들어갔어.").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 12)
                .accessibilityElement(children: .combine)

                SessionShareCard(session: session, bests: bests, shotCount: shotCount)
                    .frame(maxWidth: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                if !bests.isEmpty {
                    Card {
                        CardHeader(title: "새 기록", systemImage: "rosette")
                        ForEach(bests, id: \.title) { b in
                            HStack {
                                Text(b.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                                Spacer()
                                Text("\(b.value)").font(.headline).foregroundStyle(Theme.neonPink)
                                Text("전엔 \(b.previous)").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 32)
                        }
                    }
                }

                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("마하다 \(session.type.title) 기록", image: shareImage)) {
                        Label("이미지로 공유", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(.bordered)
                }
                Button { onClose() } label: { Text("닫기") }
                    .buttonStyle(PinkButtonStyle())
                Text("공유 이미지엔 종류, 날짜, 시간, 기술 수, 골·슛 수만 들어가. 메모·장소·사진은 안 넣어.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .task { shareImage = render() }
    }

    @MainActor
    private func render() -> Image? {
        let r = ImageRenderer(content: SessionShareCard(session: session, bests: bests, shotCount: shotCount)
            .frame(width: 360).environment(\.colorScheme, .light))
        r.scale = 3
        return r.uiImage.map { Image(uiImage: $0) }
    }
}

/// 기록 한 건 요약 카드(화면과 공유 이미지에 같이 쓴다). 색은 라이트·다크와 무관하게 고정.
struct SessionShareCard: View {
    let session: Session
    let bests: [PersonalBest]
    let shotCount: Int

    private var triedCount: Int { session.attempts.filter(\.tried).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("마하다").font(.system(.headline, design: .rounded).weight(.heavy))
                Spacer()
                Text(session.startsAt.formatted(.dateTime.month().day().weekday(.abbreviated))).font(.caption.bold())
            }
            .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 10) {
                Image(systemName: session.type.systemImage).font(.title2)
                Text(session.type.title).font(.title.bold())
            }
            .foregroundStyle(.white)
            HStack(spacing: 8) {
                stat(minutesText(session.minutes), "탄 시간")
                if session.type == .lesson {
                    stat("\(session.learnings.count)개", "배운 기술")
                } else if session.type.isGame {
                    stat("\(triedCount)/\(session.attempts.count)", "써본 기술")
                }
                if session.playedGoalie, let s = session.saves {
                    stat("\(s)", "세이브")
                } else if let g = session.goals {
                    stat("\(g)", "골")
                } else if shotCount > 0 {
                    stat("\(shotCount)", "슛")
                }
                if let m = session.moodAfter { stat(Mood.face(m), "끝나고 기분") }
            }
            if let b = bests.first {
                Label("새 기록 · \(b.title) \(b.value)", systemImage: "rosette")
                    .font(.footnote.bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: 0xFF2D8A), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x0047AB), Color(hex: 0x152B4F)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.75))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
