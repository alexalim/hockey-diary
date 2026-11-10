import SwiftUI
import HockeyCore

/// 쉬는 중(비시즌·부상). 이 기간엔 주간 연속 기록과 목표가 끊기지 않는다. 기기에만 저장.
enum RestPrefs {
    static let key = "restRanges"

    static func ranges(_ json: String) -> [RestRange] { RestRange.decode(json) }
    static func isResting(_ json: String) -> Bool { ranges(json).last.map { $0.end == nil } ?? false }

    /// 쉬기 시작/끝내기. 끝낼 땐 마지막 구간을 닫는다.
    static func toggled(_ json: String, now: Date = Date()) -> String {
        var list = ranges(json)
        if let last = list.last, last.end == nil {
            list[list.count - 1].end = now
        } else {
            list.append(RestRange(start: now))
        }
        return RestRange.encode(list)
    }
}

/// 홈에서 순서를 바꾸고 숨길 수 있는 블록. 맨 위 오늘 카드와 바로가기는 고정.
enum HomeBlock: String, CaseIterable, Identifiable {
    case goal, feedback, sharpening, team, recent
    var id: String { rawValue }

    var title: String {
        switch self {
        case .goal: return "다음 목표"
        case .feedback: return "최근 피드백"
        case .sharpening: return "연마 점검"
        case .team: return "우리 팀"
        case .recent: return "최근 기록"
        }
    }

    var systemImage: String {
        switch self {
        case .goal: return "target"
        case .feedback: return "quote.bubble"
        case .sharpening: return "wrench.and.screwdriver.fill"
        case .team: return "person.3.fill"
        case .recent: return "clock.arrow.circlepath"
        }
    }

    static let defaultOrder = "goal,feedback,sharpening,team,recent"

    /// 저장된 순서를 읽는다. 새로 생긴 블록은 끝에 붙인다.
    static func order(_ raw: String) -> [HomeBlock] {
        var list = raw.split(separator: ",").compactMap { HomeBlock(rawValue: String($0)) }
        for b in allCases where !list.contains(b) { list.append(b) }
        return list
    }
}

/// 홈 블록 순서 바꾸기·숨기기.
struct HomeEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeBlocks") private var orderRaw = HomeBlock.defaultOrder
    @AppStorage("homeHidden") private var hiddenRaw = ""
    @State private var order: [HomeBlock] = []

    private var hidden: Set<String> { Set(hiddenRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        List {
            Section {
                ForEach(order) { b in
                    Toggle(isOn: Binding(
                        get: { !hidden.contains(b.rawValue) },
                        set: { on in
                            var h = hidden
                            if on { h.remove(b.rawValue) } else { h.insert(b.rawValue) }
                            hiddenRaw = h.sorted().joined(separator: ",")
                        })) {
                        Label(b.title, systemImage: b.systemImage)
                    }
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                    orderRaw = order.map(\.rawValue).joined(separator: ",")
                }
            } footer: {
                Text("끌어서 순서를 바꾸고, 끄면 홈에서 숨겨. 맨 위 오늘 카드와 바로가기는 그대로야.")
            }
            Section {
                Button("처음대로") {
                    orderRaw = HomeBlock.defaultOrder
                    hiddenRaw = ""
                    order = HomeBlock.order(orderRaw)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("홈 꾸미기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        .onAppear { order = HomeBlock.order(orderRaw) }
    }
}

/// 오늘 카드 안의 작은 원 하나. 채움 정도로 읽히게.
struct HomeRing: View {
    var value: Double   // 0...1
    var center: String
    var label: String
    var color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 7)
                Circle().trim(from: 0, to: max(0.001, min(value, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(center).font(.headline.bold()).foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
            }
            .frame(width: 62, height: 62)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(center)")
    }
}
