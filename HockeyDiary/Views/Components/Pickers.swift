import SwiftUI
import HockeyCore

/// 표정 5단계 기분 선택. 같은 표정을 다시 누르면 선택이 풀린다(입력 안 해도 됨).
struct MoodPicker: View {
    var title: String
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(value.map(Mood.label) ?? "선택 안 함").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(Array(Mood.range), id: \.self) { v in
                    let selected = value == v
                    Button {
                        value = selected ? nil : v
                    } label: {
                        Text(Mood.face(v))
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                            .background(selected ? Theme.neonPink.opacity(0.15) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? Theme.neonPink : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(Mood.label(v))")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// 1~5 숫자 평가(난도·피로도·체감). 다시 누르면 해제.
struct ScalePicker: View {
    var title: String
    var low: String = "낮음"
    var high: String = "높음"
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(low) ← → \(high)").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { v in
                    let selected = value == v
                    Button {
                        value = selected ? nil : v
                    } label: {
                        Text("\(v)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                            .foregroundStyle(selected ? .white : Theme.title)
                            .background(selected ? Theme.cobalt : Theme.cobaltSoft,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(v)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension SurfaceType {
    var systemImage: String {
        switch self {
        case .indoorRink: return "building.2.fill"
        case .outdoorRink: return "cloud.sun.fill"
        case .pond: return "water.waves"
        case .other: return "mappin.and.ellipse"
        case .unknown: return "questionmark.circle"
        }
    }
}

extension ActivityType {
    var systemImage: String {
        switch self {
        case .lesson: return "graduationcap.fill"
        case .miniGame: return "figure.hockey"
        case .regularGame: return "trophy.fill"
        case .freePractice: return "figure.skating"
        }
    }
}

/// 빙판 유형 큰 카드 3개 + 기타/나중에 (S15). 기본값은 제안일 뿐, 고르는 건 사용자.
struct SurfacePicker: View {
    @Binding var value: SurfaceType

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach([SurfaceType.indoorRink, .outdoorRink, .pond], id: \.self) { s in
                    card(s)
                }
            }
            HStack(spacing: 8) {
                ForEach([SurfaceType.other, .unknown], id: \.self) { s in
                    small(s)
                }
            }
            Text(value.detail).font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func card(_ s: SurfaceType) -> some View {
        let selected = value == s
        return Button { value = s } label: {
            VStack(spacing: 6) {
                Image(systemName: s.systemImage).font(.title2)
                Text(s.title).font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .foregroundStyle(selected ? .white : Theme.title)
            .background(selected ? Theme.cobalt : Theme.iceBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.neonPink).padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func small(_ s: SurfaceType) -> some View {
        let selected = value == s
        return Button { value = s } label: {
            Label(s.title, systemImage: s.systemImage)
                .font(.footnote)
                .frame(maxWidth: .infinity, minHeight: Theme.touch)
                .foregroundStyle(selected ? .white : Theme.title)
                .background(selected ? Theme.cobalt : Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 태그 칩 토글.
struct TagChips: View {
    var options: [String]
    @Binding var selected: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { tag in
                let on = selected.contains(tag)
                Button {
                    if on { selected.removeAll { $0 == tag } } else { selected.append(tag) }
                } label: {
                    Text("#\(tag)")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .foregroundStyle(on ? .white : Theme.title)
                        .background(on ? Theme.cobalt : Theme.cobaltSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// 줄바꿈되는 가로 배치.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 숫자 입력(비우면 nil).
struct OptionalNumberField: View {
    var title: String
    @Binding var value: Int?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("선택", text: Binding(
                get: { value.map(String.init) ?? "" },
                set: { value = Int($0.filter(\.isNumber)) }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 90)
        }
    }
}

extension Date {
    var dayTitle: String { formatted(.dateTime.month().day().weekday(.abbreviated)) }
    var timeTitle: String { formatted(.dateTime.hour().minute()) }
}

func minutesText(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m)분" }
    return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
}
