import SwiftUI
import HockeyCore

/// 기기 연동 (S07). 데이터마다 왜 읽는지 먼저 설명하고, 사용자가 누를 때만 iOS 권한 화면을 띄운다.
struct HealthConnectView: View {
    @AppStorage(HealthPrefs.enabledKey) private var enabled = false
    @State private var requesting = false
    @State private var errorText: String?

    private let items: [(String, String, String)] = [
        ("bed.double.fill", "수면", "하키 전날 밤에 얼마나 잤는지 그날 기록 옆에 보여줄게."),
        ("heart.fill", "심박수", "수업이나 경기 중 평균·최고 심박을 보여줄게."),
        ("figure.hockey", "운동", "워치나 가민이 잰 운동을 내 기록과 맞춰볼게. 여러 기기로 재도 시간은 한 번만 세."),
    ]

    var body: some View {
        List {
            Section {
                ForEach(items, id: \.1) { icon, title, why in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            Text(why).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("읽는 데이터")
            } footer: {
                Text("아이폰 앱은 읽기만 해. 워치로 잰 하키 운동만 건강 앱에 저장돼. 읽은 값은 따로 저장하지 않고 볼 때마다 다시 가져와. 어디에도 안 보내.")
            }

            Section {
                if !HealthService.shared.isAvailable {
                    Text("이 기기에서는 Apple 건강을 쓸 수 없어.").foregroundStyle(.secondary)
                } else if enabled {
                    Label("연결됨", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Button("건강 데이터 그만 보기", role: .destructive) { enabled = false }
                } else {
                    Button {
                        connect()
                    } label: {
                        Label(requesting ? "여는 중…" : "Apple 건강 연결하기", systemImage: "heart.text.square.fill")
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(PinkButtonStyle())
                    .disabled(requesting)
                    .listRowBackground(Color.clear)
                }
                if let errorText { Text(errorText).font(.footnote).foregroundStyle(Theme.neonPink) }
            } footer: {
                Text("연결 안 해도 기록은 다 쓸 수 있어. 허용 항목은 설정 → 건강 → 데이터 접근 및 기기 → 마하다에서 바꿔.")
            }

            if enabled {
                CycleConsentSection()
            }

            Section("가민을 쓰고 있다면") {
                Text("Garmin Connect 앱 → 설정 → 연결된 앱 → Apple 건강에서 동기화를 켜줘. 그러면 가민의 수면·심박·운동이 여기로 들어와. 기기에 따라 일부만 올 수 있어. 가민 앱이 동기화한 뒤에 보여.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Apple 건강")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func connect() {
        requesting = true
        errorText = nil
        Task {
            do {
                try await HealthService.shared.requestAccess()
                enabled = true
            } catch {
                errorText = "권한 화면을 열지 못했어. 잠시 뒤 다시 해줘."
            }
            requesting = false
        }
    }
}

/// 활동 상세의 건강 카드.
struct SessionHealthCard: View {
    let start: Date
    let end: Date
    @AppStorage(HealthPrefs.enabledKey) private var enabled = false
    @State private var health: SessionHealth?
    @State private var loading = false

    var body: some View {
        if enabled {
            Card {
                CardHeader(title: "Apple 건강", systemImage: "heart.text.square", trailing: "Apple 건강에서")
                if loading && health == nil {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let h = health, !h.isEmpty {
                    if let n = h.night {
                        row("bed.double.fill", "전날 밤 수면", minutesText(n.asleepMinutes),
                            "\(n.start.timeTitle) ~ \(n.end.timeTitle)")
                    }
                    if let avg = h.averageHeartRate, let mx = h.maxHeartRate {
                        row("heart.fill", "심박", "평균 \(Int(avg.rounded())) · 최고 \(Int(mx.rounded()))", "bpm")
                    }
                    ForEach(h.workouts) { w in
                        row("applewatch", "\(w.source) · \(w.activityName)", minutesText(w.minutes),
                            w.kilocalories.map { "\(Int($0)) kcal" })
                    }
                    if h.workouts.count > 1 {
                        Text("같은 활동을 \(h.workouts.count)개 기기가 쟀어. 시간은 한 번만 세서 \(minutesText(h.mergedWorkoutMinutes))야.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    EmptyHint(text: "이 시간에 건강 앱 기록이 없어. 권한이 꺼져 있거나 아직 동기화 전일 수 있어.",
                              systemImage: "heart.slash")
                }
            }
            .task(id: start) { await load() }
        }
    }

    private func row(_ icon: String, _ title: String, _ value: String, _ detail: String?) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Theme.neonPink).frame(width: 24)
            Text(title).font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(value).font(.subheadline.bold())
                if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        loading = true
        health = await HealthService.shared.health(for: start, end: end)
        loading = false
    }
}

/// 성장 탭의 수면·컨디션 카드.
struct SleepGrowthCard: View {
    let samples: [ActivitySample]
    let periodTitle: String
    @AppStorage(HealthPrefs.enabledKey) private var enabled = false
    @State private var pairs: [(sleepMinutes: Int, moodAfter: Int?)] = []
    @State private var loaded = false

    var body: some View {
        Card(tint: Theme.iceBlue) {
            CardHeader(title: "수면·컨디션", systemImage: "bed.double.fill")
            if !enabled {
                Text("Apple 건강을 연결하면 전날 밤 잠과 운동 후 기분을 같이 볼 수 있어.")
                    .font(.subheadline).foregroundStyle(.secondary)
                NavigationLink { HealthConnectView() } label: {
                    Label("Apple 건강 연결", systemImage: "heart.text.square").frame(minHeight: Theme.touch)
                }
            } else if !loaded {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                let comparison = SleepMoodComparison.compute(pairs)
                if pairs.isEmpty {
                    EmptyHint(text: "이 기간에는 건강 앱에 잠 기록이 없어.", systemImage: "bed.double")
                } else {
                    let avg = pairs.map(\.sleepMinutes).reduce(0, +) / pairs.count
                    Text("하키 전날 평균 수면 \(minutesText(avg))").font(.headline).foregroundStyle(Theme.title)
                    if let s = comparison.sentence {
                        Text(s).font(.subheadline)
                    } else {
                        Text("7시간 넘게 잔 날과 덜 잔 날이 3번씩 쌓이면 비교해줄게.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("기록을 나란히 놓은 거야. 잠 때문이라고 말하는 건 아니야.").font(.caption).foregroundStyle(.secondary)
                }
                Text(Insights.footnote(periodTitle: periodTitle, count: pairs.count, source: "잠: Apple 건강 · 기분: 직접 입력"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .task(id: "\(enabled)-\(samples.map(\.sessionID))") { loaded = false; await load() }
    }

    private func load() async {
        guard enabled, let first = samples.map(\.at).min(), let last = samples.map(\.at).max() else {
            pairs = []; loaded = true; return
        }
        let segments = (try? await HealthService.shared.sleepSegments(from: first.addingTimeInterval(-30 * 3600), to: last)) ?? []
        pairs = samples.compactMap { s in
            SleepAttribution.nightBefore(s.at, segments: segments).map { (sleepMinutes: $0.asleepMinutes, moodAfter: s.moodAfter) }
        }
        loaded = true
    }
}

/// 생리 주기: 따로 동의한 사람만. 켤 때 그 항목 권한만 따로 요청한다.
struct CycleConsentSection: View {
    @AppStorage(HealthPrefs.cycleKey) private var cycleEnabled = false
    @State private var errorText: String?

    var body: some View {
        Section {
            Toggle("생리 주기와 컨디션 같이 보기", isOn: Binding(get: { cycleEnabled }, set: { on in
                if on {
                    Task {
                        do { try await HealthService.shared.requestCycleAccess(); cycleEnabled = true }
                        catch { errorText = "권한 화면을 열지 못했어." }
                    }
                } else { cycleEnabled = false }
            }))
            if let errorText { Text(errorText).font(.footnote).foregroundStyle(Theme.neonPink) }
        } header: {
            Text("생리 주기 (선택)")
        } footer: {
            Text("켜면 건강 앱의 생리 기록을 읽어. 생리 기간에 탄 날의 피로도를 다른 날과 같이 보여줘. 운동을 하라 말라 하지 않아. 리포트, 공유, AI 요약에는 절대 안 넣어.")
        }
    }
}

/// 성장 탭: 생리 기간과 피로도 비교 카드.
struct CycleGrowthCard: View {
    let sessions: [(at: Date, fatigue: Int?)]
    let periodTitle: String
    @AppStorage(HealthPrefs.enabledKey) private var enabled = false
    @AppStorage(HealthPrefs.cycleKey) private var cycleEnabled = false
    @State private var comparison: CycleFatigueComparison?

    var body: some View {
        if enabled && cycleEnabled {
            Card(tint: Theme.iceBlue) {
                CardHeader(title: "주기와 컨디션", systemImage: "drop.fill")
                if let c = comparison {
                    if let s = c.sentence {
                        Text(s).font(.subheadline)
                    } else {
                        Text("생리 기간과 다른 날의 피로도 기록이 3번씩 쌓이면 비교해줄게.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("피로도는 내가 직접 고른 값이야. 운동 강도를 정해주지는 않아.").font(.caption).foregroundStyle(.secondary)
                    Text(Insights.footnote(periodTitle: periodTitle, count: c.periodCount + c.otherCount, source: "생리: Apple 건강 · 피로도: 직접 입력"))
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .task(id: sessions.map(\.at)) { await load() }
        }
    }

    private func load() async {
        guard let first = sessions.map(\.at).min(), let last = sessions.map(\.at).max() else {
            comparison = CycleFatigueComparison.compute([]); return
        }
        let days = (try? await HealthService.shared.menstrualDays(from: first.addingTimeInterval(-86_400), to: last.addingTimeInterval(86_400))) ?? []
        let cal = Calendar.current
        comparison = CycleFatigueComparison.compute(sessions.map { (inPeriod: days.contains(cal.startOfDay(for: $0.at)), fatigue: $0.fatigue) })
    }
}
