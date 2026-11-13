import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - 색(앱 토큰과 같은 값)

enum WColor {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: 1)
    }
    static let cobalt = hex(0x0047AB)
    static let deepNavy = hex(0x172B4D)
    static let pink = hex(0xFF2D8C)
    static let ice = hex(0xE8F3FF)
    static let inkSecondary = hex(0x64748B)
    static let success = hex(0x197A61)
    static let hero = LinearGradient(colors: [cobalt, deepNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - 타임라인

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: Date(), snapshot: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: context.isPreview ? .placeholder : (SharedStore.load() ?? .placeholder)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snap = SharedStore.load() ?? .placeholder
        // 앱이 기록할 때마다 새로 고치지만, 자정을 넘기면 요일 표시가 바뀌어야 하니 한 시간마다 다시 그린다.
        completion(Timeline(entries: [SnapshotEntry(date: Date(), snapshot: snap)], policy: .after(Date().addingTimeInterval(3600))))
    }
}

// MARK: - 이번 주 위젯

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mahada.week", provider: SnapshotProvider()) { entry in
            WeekView(snap: entry.snapshot).containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("이번 주 하키")
        .description("이번 주 빙판에 선 날과 몇 주째 이어 왔는지 보여요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct WeekView: View {
    @Environment(\.widgetFamily) private var family
    let snap: WidgetSnapshot
    private let labels = ["월", "화", "수", "목", "금", "토", "일"]

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(min(snap.monthDone, snap.monthTarget)), in: 0...Double(max(snap.monthTarget, 1))) {
                Image(systemName: "figure.hockey")
            } currentValueLabel: {
                Text("\(snap.monthDone)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.resting ? "쉬는 중" : "이번 주 \(snap.weekCount)회 · \(snap.streakWeeks)주 연속").font(.headline)
                dayRow(size: 14)
                Text(snap.monthLeft == 0 ? "이달 목표 달성!" : "이달 \(snap.monthLeft)번 남았어요").font(.caption2)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    dayRow(size: 24)
                    Text(line).font(.caption).foregroundStyle(WColor.inkSecondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("이달 퀘스트").font(.caption.bold()).foregroundStyle(WColor.inkSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(snap.monthDone)").font(.system(size: 28, weight: .bold)).foregroundStyle(WColor.deepNavy)
                        Text("/ \(snap.monthTarget)회").font(.caption).foregroundStyle(WColor.inkSecondary)
                    }
                    ProgressView(value: Double(min(snap.monthDone, snap.monthTarget)), total: Double(max(snap.monthTarget, 1))).tint(WColor.pink)
                    if let t = snap.nextEventTitle, let at = snap.nextEventAt {
                        Text("다음 경기 \(at.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))").font(.caption2).foregroundStyle(WColor.inkSecondary)
                        Text(t).font(.caption.bold()).foregroundStyle(WColor.deepNavy).lineLimit(1)
                    } else {
                        Text("\(snap.points)점 모았어요").font(.caption2).foregroundStyle(WColor.inkSecondary)
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                header
                dayRow(size: 18)
                Spacer(minLength: 0)
                Text(line).font(.caption2).foregroundStyle(WColor.inkSecondary).lineLimit(2)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(snap.streakWeeks > 0 ? WColor.pink : WColor.inkSecondary)
            Text(snap.streakWeeks > 0 ? "\(snap.streakWeeks)주 연속" : "이번 주 하키").font(.headline).foregroundStyle(WColor.deepNavy)
            Spacer(minLength: 0)
        }
    }

    private var line: String {
        if snap.resting { return "쉬는 중이에요. 돌아오면 이어서 해요." }
        if snap.weekCount == 0 { return "이번 주 첫 빙판은 언제예요?" }
        return "이번 주 \(snap.weekCount)회 · 이달 \(snap.monthLeft == 0 ? "목표 달성" : "\(snap.monthLeft)번 남음")"
    }

    private func dayRow(size: CGFloat) -> some View {
        HStack(spacing: size > 16 ? 6 : 3) {
            ForEach(0..<7, id: \.self) { i in
                let on = i < snap.weekDays.count && snap.weekDays[i]
                let today = i == snap.todayIndex
                VStack(spacing: 2) {
                    if size > 16 { Text(labels[i]).font(.system(size: 9)).foregroundStyle(today ? WColor.cobalt : WColor.inkSecondary) }
                    ZStack {
                        Circle().fill(on ? WColor.cobalt : WColor.ice)
                            .overlay(Circle().stroke(today ? WColor.cobalt : .clear, lineWidth: 1.5))
                        if on { Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .bold)).foregroundStyle(.white) }
                    }
                    .frame(width: size, height: size)
                }
            }
        }
    }
}

// MARK: - 루틴 실시간 활동

struct RoutineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
            lockScreen(context.attributes, context.state)
                .padding(14)
                .activityBackgroundTint(WColor.deepNavy)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.routineName, systemImage: "figure.hockey").font(.caption).foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.index)/\(context.state.total)").font(.caption.bold()).foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.drillTitle).font(.headline).foregroundStyle(.white).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    big(context.state).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(WColor.pink)
                }
            } compactLeading: {
                Image(systemName: "figure.hockey").foregroundStyle(WColor.pink)
            } compactTrailing: {
                big(context.state).font(.caption.bold().monospacedDigit()).foregroundStyle(.white).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "figure.hockey").foregroundStyle(WColor.pink)
            }
        }
    }

    @ViewBuilder
    private func big(_ s: RoutineActivityAttributes.ContentState) -> some View {
        if s.isMinutes {
            if let end = s.endDate {
                Text(timerInterval: Date()...max(end, Date()), countsDown: true).monospacedDigit()
            } else {
                Text(String(format: "%d:%02d", s.secondsLeft / 60, s.secondsLeft % 60)).monospacedDigit()
            }
        } else {
            Text("\(s.count)/\(s.target)")
        }
    }

    private func lockScreen(_ a: RoutineActivityAttributes, _ s: RoutineActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(a.routineName) · \(s.index)/\(s.total)").font(.caption).foregroundStyle(.white.opacity(0.8))
                Text(s.drillTitle).font(.headline).foregroundStyle(.white).lineLimit(1)
                Text(s.skillName).font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            big(s).font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(WColor.pink)
        }
    }
}

@main
struct MahadaWidgets: WidgetBundle {
    var body: some Widget {
        WeekWidget()
        RoutineLiveActivity()
    }
}
