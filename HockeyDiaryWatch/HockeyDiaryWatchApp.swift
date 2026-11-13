import SwiftUI
import HockeyCore

/// 마하다 워치: 활동 시작·종료, 운동 전후 기분 (P2). 장갑 낀 손을 생각해 큰 버튼만 쓴다.
@main
struct HockeyDiaryWatchApp: App {
    @StateObject private var model = WorkoutModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRootView().environmentObject(model)
            }
        }
    }
}

private let pink = Color(red: 1, green: 0.176, blue: 0.584)
private let cobalt = Color(red: 0.31, green: 0.55, blue: 1)

struct WatchRootView: View {
    @EnvironmentObject var model: WorkoutModel

    var body: some View {
        switch model.phase {
        case .idle: StartView()
        case .running: RunningView()
        case .finishing: FinishView()
        case .sent: SentView()
        }
    }
}

struct StartView: View {
    @EnvironmentObject var model: WorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("무엇을 할까요?").font(.headline)
                ForEach(ActivityType.allCases, id: \.self) { t in
                    Button {
                        model.type = t
                    } label: {
                        Text(t.title).frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .tint(model.type == t ? pink : .gray)
                }
                Text("어디서?").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                HStack(spacing: 4) {
                    ForEach([SurfaceType.indoorRink, .outdoorRink, .pond], id: \.self) { s in
                        Button { model.surface = s } label: {
                            Text(s == .indoorRink ? "실내" : (s == .outdoorRink ? "야외" : "폰드"))
                                .font(.caption2.bold()).frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .tint(model.surface == s ? cobalt : .gray)
                    }
                }
                if model.usesGPS {
                    Text("야외·폰드는 GPS로 총거리만 재요. 경로는 안 남겨요.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Text("시작 전 기분").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                WatchMoodRow(value: $model.moodBefore)
                Button {
                    Task { await model.start() }
                } label: {
                    Label("시작", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 44)
                }
                .tint(cobalt)
            }
        }
        .navigationTitle("마하다")
    }
}

struct RunningView: View {
    @EnvironmentObject var model: WorkoutModel

    var body: some View {
        ScrollView {
        VStack(spacing: 6) {
            Text(model.type.title).font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(elapsed(at: ctx.date))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                if let hr = model.heartRate {
                    Label("\(Int(hr.rounded()))", systemImage: "heart.fill").foregroundStyle(pink)
                } else {
                    Text(model.usingHealth ? "심박 재는 중" : "타이머로 재는 중").font(.caption2).foregroundStyle(.secondary)
                }
                if model.usesGPS {
                    Text(model.locationDenied ? "위치 꺼짐" : String(format: "%.1fkm", model.distanceMeters / 1000))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            // 쉬프트: 얼음에 오를 때 누르고, 벤치로 올 때 다시 누른다.
            Button {
                model.toggleShift()
            } label: {
                VStack(spacing: 2) {
                    Text(model.onIce ? "벤치로" : "얼음으로").font(.headline)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text("쉬프트 \(model.shiftCount) · 얼음 위 \(model.onIceSeconds(at: ctx.date) / 60)분")
                            .font(.caption2).monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .tint(model.onIce ? cobalt : .gray)
            Button {
                Task { await model.stop() }
            } label: {
                Label("끝내기", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: 40)
            }
            .tint(pink)
        }
        }
    }

    private func elapsed(at now: Date) -> String {
        let s = Int(now.timeIntervalSince(model.startDate ?? now))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

struct FinishView: View {
    @EnvironmentObject var model: WorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("끝나고 기분은?").font(.headline)
                WatchMoodRow(value: $model.moodAfter)
                Button {
                    model.send()
                } label: {
                    Label("아이폰에 저장", systemImage: "iphone").frame(maxWidth: .infinity, minHeight: 44)
                }
                .tint(cobalt)
                Text("기술·메모는 아이폰에서 더 적을 수 있어요.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct SentView: View {
    @EnvironmentObject var model: WorkoutModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(pink)
            Text("아이폰으로 보냈어요").font(.headline)
            Text("아이폰 앱을 열면 기록에 들어가 있어요.").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("처음으로") { model.reset() }
        }
    }
}

/// 기분 5단계(다시 누르면 해제).
struct WatchMoodRow: View {
    @Binding var value: Int?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(Mood.range), id: \.self) { v in
                Button {
                    value = value == v ? nil : v
                } label: {
                    Text(Mood.face(v)).font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(value == v ? pink.opacity(0.35) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Mood.label(v))
            }
        }
    }
}
