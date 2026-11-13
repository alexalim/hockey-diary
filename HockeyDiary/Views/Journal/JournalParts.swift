import SwiftUI
import HockeyCore

// 일기 화면 부품 — 다이어리 속지 느낌. 종이 카드, 마스킹테이프, 기분 얼굴, 스티커 태그, 폴라로이드.
// 저장 값은 그대로고 보이는 모양만 다르다.

/// 크림색 종이 카드. 위에 테이프 한 조각, 안쪽은 선택적으로 점 격자.
struct PaperCard<Content: View>: View {
    var tape: Color? = nil
    var tapeAngle: Double = -4
    var dotted = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .padding(.top, tape == nil ? 0 : 6)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.paper)
                    if dotted { DotGrid().clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.paperDot.opacity(0.6), lineWidth: 1))
            .shadow(color: Theme.deepNavy.opacity(0.07), radius: 10, y: 4)
            .overlay(alignment: .top) {
                if let tape { WashiTape(color: tape, angle: tapeAngle).offset(y: -9) }
            }
            .padding(.top, tape == nil ? 0 : 8)
    }
}

/// 마스킹테이프 한 조각. 반투명이라 밑의 종이가 비친다.
struct WashiTape: View {
    var color: Color
    var angle: Double = -4
    var width: CGFloat = 68

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color.opacity(0.85))
            .frame(width: width, height: 18)
            .overlay(
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { _ in Circle().fill(.white.opacity(0.35)).frame(width: 3, height: 3) }
                }
            )
            .rotationEffect(.degrees(angle))
            .accessibilityHidden(true)
    }
}

/// 종이 점 격자.
struct DotGrid: View {
    var step: CGFloat = 18

    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 12
            while x < size.width {
                var y: CGFloat = 12
                while y < size.height {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(Theme.paperDot))
                    y += step
                }
                x += step
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 기분 얼굴 다섯 개. 고른 얼굴이 통통 튀어 오르고 나머지는 한 발 물러선다.
struct MoodFaces: View {
    @Binding var value: Int?
    private let names = ["힘들어요", "별로", "그냥", "좋아요", "최고"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(Mood.range), id: \.self) { v in
                let selected = value == v
                let dimmed = value != nil && !selected
                Button {
                    value = selected ? nil : v
                } label: {
                    VStack(spacing: 6) {
                        Text(Mood.face(v))
                            .font(.system(size: 30))
                            .frame(width: 54, height: 54)
                            .background(Theme.moodFills[v - 1], in: Circle())
                            .overlay(Circle().stroke(selected ? Theme.neonPink : .clear, lineWidth: 2.5))
                            .shadow(color: selected ? Theme.neonPink.opacity(0.35) : .clear, radius: 8, y: 3)
                        Text(names[v - 1])
                            .font(.system(.caption, design: .rounded).weight(selected ? .bold : .regular))
                            .foregroundStyle(selected ? Theme.accentText : Theme.paperInkSoft)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    .scaleEffect(selected ? 1.12 : (dimmed ? 0.9 : 1))
                    .rotationEffect(.degrees(selected ? -6 : 0))
                    .opacity(dimmed ? 0.55 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("오늘 기분 \(Mood.label(v))")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.5), value: value)
    }
}

/// 스티커처럼 비뚤게 붙는 태그 칩. 누르면 붙고 떼진다.
struct StickerChips: View {
    var options: [String]
    @Binding var selected: [String]

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.element) { i, tag in
                let on = selected.contains(tag)
                Button {
                    if on { selected.removeAll { $0 == tag } } else { selected.append(tag) }
                } label: {
                    Sticker(text: "#\(tag)", index: i, on: on)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("태그 \(tag)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
    }
}

/// 스티커 한 장. 흰 테두리와 살짝 기운 각도가 붙여 둔 느낌을 낸다.
struct Sticker: View {
    var text: String
    var index: Int
    var on: Bool = true
    var small = false

    var body: some View {
        Text(text)
            .font(.system(small ? .caption : .subheadline, design: .rounded).bold())
            .foregroundStyle(Theme.paperInk)
            .padding(.horizontal, small ? 8 : 12)
            .frame(minHeight: small ? 24 : 36)
            .background(Theme.stickers[index % Theme.stickers.count], in: RoundedRectangle(cornerRadius: small ? 7 : 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: small ? 7 : 10, style: .continuous)
                .stroke(on ? Theme.neonPink : Theme.paper, lineWidth: on ? 2 : 2.5))
            .overlay(alignment: .topTrailing) {
                if on && !small {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.white, Theme.neonPink)
                        .offset(x: 6, y: -6)
                }
            }
            .shadow(color: Theme.deepNavy.opacity(on ? 0.14 : 0.06), radius: on ? 4 : 2, y: 2)
            .rotationEffect(.degrees(Double((index % 3) - 1) * 2.5))
            .scaleEffect(on ? 1.04 : 1)
            .opacity(on || small ? 1 : 0.8)
    }
}

/// 폴라로이드 틀에 든 사진.
struct PolaroidThumb: View {
    var data: Data
    var size: CGFloat = 64
    var index: Int = 0

    var body: some View {
        PhotoThumb(data: data, size: size, corner: 2)
            .padding(.horizontal, 5).padding(.top, 5).padding(.bottom, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .shadow(color: Theme.deepNavy.opacity(0.12), radius: 4, y: 2)
            .rotationEffect(.degrees(Double((index % 3) - 1) * 3))
    }
}

/// 종이 카드 제목 줄. 둥근 글꼴에 작은 아이콘.
struct PaperTitle: View {
    var text: String
    var systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(Theme.paperInk)
    }
}

/// 기록 탭에 붙는 일기 한 장(포스트잇). 기분 얼굴, 한 줄, 스티커, 폴라로이드.
struct JournalNote: View {
    let journal: DailyJournal

    var body: some View {
        PaperCard(tape: journal.mood.map { Theme.moodFills[$0 - 1] } ?? Theme.tapePink, tapeAngle: 5, dotted: true) {
            HStack(alignment: .top, spacing: 12) {
                Text(journal.mood.map(Mood.face) ?? "📝")
                    .font(.system(size: 26))
                    .frame(width: 46, height: 46)
                    .background(journal.mood.map { Theme.moodFills[$0 - 1] } ?? Theme.tapePink, in: Circle())
                    .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
                    .shadow(color: Theme.deepNavy.opacity(0.1), radius: 3, y: 2)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(journal.entryDate.dayTitle)
                            .font(.system(.caption, design: .rounded).bold()).foregroundStyle(Theme.paperInkSoft)
                        if let mood = journal.mood {
                            Text(Mood.label(mood)).font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                        }
                        if !journal.isPrivate {
                            Image(systemName: "square.and.arrow.up").font(.caption2).foregroundStyle(Theme.paperInkSoft)
                                .accessibilityLabel("리포트 공유")
                        }
                    }
                    if !journal.body.isEmpty {
                        Text(journal.body)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.paperInk)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                    if !journal.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(Array(journal.tags.enumerated()), id: \.element) { i, t in
                                Sticker(text: "#\(t)", index: i, on: false, small: true)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            if !journal.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(journal.photos.enumerated()), id: \.element.id) { i, p in
                            PolaroidThumb(data: p.imageData, size: 60, index: i)
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 6)
                }
            }
        }
    }
}
