import SwiftUI
import SwiftData
import Charts
import HockeyCore

/// 컨디션 흐름: 잔 시간·안정 심박·심박 변이도·기분·힘듦·몸 상태를 날마다 한 줄로, 기간 그래프로 본다.
/// 항목은 사용자가 고른 것만 보여준다. 건강 값은 볼 때마다 다시 읽고 저장하지 않는다. 의료 판단은 하지 않는다.
struct ConditionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]
    @Query(sort: \DailyJournal.entryDate, order: .reverse) private var journals: [DailyJournal]
    @Query(sort: \BodyCheck.day, order: .reverse) private var checks: [BodyCheck]
    @AppStorage(HealthPrefs.enabledKey) private var healthOn = false
    @AppStorage(HealthPrefs.cycleKey) private var cycleOn = false

    @State private var period: Period = .month
    @State private var metric: ConditionMetric = .sleep
    @State private var days: [ConditionDay] = []
    @State private var loading = false
    /// 토글을 바꾸면 다시 읽게 하는 신호.
    @State private var prefsTick = 0
    @State private var errorText: String?

    private let cal = Calendar.current

    private var enabledMetrics: [ConditionMetric] { ConditionPrefs.enabledMetrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("기간", selection: $period) {
                    ForEach([Period.week, .month, .quarter], id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                chartCard
                unusualCard
                todayBodyCard
                listCard
                settingsCard
                Text("여기 값은 내 기록이 어땠는지만 보여줘. 몸 상태를 진단하거나 운동을 하라·말라 하지 않아. 건강 값은 저장하지 않고, 리포트·공유·AI 요약에도 안 넣어.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("컨디션 흐름")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(period.rawValue)-\(prefsTick)-\(checks.count)-\(sessions.count)") { await load() }
        .onAppear { if !enabledMetrics.contains(metric), let first = enabledMetrics.first { metric = first } }
    }

    // MARK: - 그래프

    private var shown: [ConditionDay] {
        guard let from = period.start(from: Date()) else { return days }
        return days.filter { $0.day >= cal.startOfDay(for: from) }
    }

    private var chartCard: some View {
        let list = shown
        let points = list.compactMap { d in metric.value(d).map { (day: d.day, value: $0) } }
        return Card {
            CardHeader(title: "흐름", systemImage: "waveform.path.ecg")
            if enabledMetrics.isEmpty {
                EmptyHint(text: "아래에서 볼 항목을 하나 이상 켜줘.")
            } else {
                Picker("항목", selection: $metric) {
                    ForEach(enabledMetrics, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(metric.help).font(.caption).foregroundStyle(Theme.inkSecondary)
                if points.isEmpty {
                    EmptyHint(text: loading ? "불러오는 중…" : emptyReason)
                } else {
                    Chart {
                        if cycleOn {
                            ForEach(list.filter(\.period), id: \.day) { d in
                                RectangleMark(xStart: .value("시작", d.day), xEnd: .value("끝", cal.date(byAdding: .day, value: 1, to: d.day)!))
                                    .foregroundStyle(Theme.neonPink.opacity(0.10))
                            }
                        }
                        ForEach(points, id: \.day) { p in
                            if [.mood, .fatigue, .body].contains(metric) {
                                BarMark(x: .value("날", p.day, unit: .day), y: .value(metric.title, p.value))
                                    .foregroundStyle(Theme.cobalt)
                            } else {
                                LineMark(x: .value("날", p.day, unit: .day), y: .value(metric.title, p.value))
                                    .foregroundStyle(Theme.cobalt).interpolationMethod(.monotone)
                                PointMark(x: .value("날", p.day, unit: .day), y: .value(metric.title, p.value))
                                    .foregroundStyle(Theme.cobalt).symbolSize(18)
                            }
                        }
                        ForEach(list.filter(\.skated), id: \.day) { d in
                            PointMark(x: .value("날", d.day, unit: .day), y: .value("바닥", yFloor(points)))
                                .symbol(.triangle).symbolSize(26).foregroundStyle(Theme.neonPink)
                        }
                    }
                    .chartYScale(domain: yDomain(points))
                    .chartYAxis { AxisMarks(position: .leading) { v in
                        AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(metric.text(d)) } }
                    } }
                    .frame(height: 180)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(period.longTitle) \(metric.title) \(points.count)일치")
                    Legend(items: [.init(color: Theme.cobalt, title: metric.title),
                                   .init(color: Theme.neonPink, title: "하키 탄 날", systemImage: "triangle.fill")]
                           + (cycleOn ? [.init(color: Theme.neonPink.opacity(0.3), title: "생리 기간")] : []))
                    if let avg = average(points) {
                        Text("\(period.longTitle) 평균 \(metric.text(avg)) · \(points.count)일치").font(.subheadline.bold()).foregroundStyle(Theme.title)
                    }
                }
            }
        }
    }

    private var emptyReason: String {
        switch metric {
        case .sleep, .restingHR, .hrv:
            if !healthOn { return "Apple 건강을 연결하면 보여줄 수 있어. 아래 '항목 고르기'에서 연결해." }
            if let errorText { return errorText }
            return "이 기간엔 건강 앱에 \(metric.title) 기록이 없어. 워치를 차고 자면 쌓여."
        case .mood, .fatigue: return "기록을 남기면 쌓여. 운동 후 기분과 '얼마나 힘들었어?'를 적어줘."
        case .body: return "홈이나 아래에서 '오늘 몸 상태'를 남기면 쌓여."
        }
    }

    private func average(_ pts: [(day: Date, value: Double)]) -> Double? {
        pts.isEmpty ? nil : pts.map(\.value).reduce(0, +) / Double(pts.count)
    }

    private func yDomain(_ pts: [(day: Date, value: Double)]) -> ClosedRange<Double> {
        switch metric {
        case .mood, .fatigue, .body: return 0...5
        default:
            let v = pts.map(\.value); let lo = v.min() ?? 0, hi = v.max() ?? 1
            let pad = max((hi - lo) * 0.2, 1)
            return max(0, lo - pad)...(hi + pad)
        }
    }

    private func yFloor(_ pts: [(day: Date, value: Double)]) -> Double { yDomain(pts).lowerBound }

    // MARK: - 평소와 다른 점

    @ViewBuilder
    private var unusualCard: some View {
        let lines = ConditionTrack.unusual(days, now: Date())
        if !lines.isEmpty {
            Card(tint: Theme.warningSoft) {
                CardHeader(title: "평소와 다른 점", systemImage: "exclamationmark.bubble")
                ForEach(lines, id: \.self) { Text("• \($0)").font(.subheadline).foregroundStyle(Theme.title) }
                Text("최근 7일을 그 앞 4주와 견준 거야. 왜 그런지는 내가 제일 잘 알아.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    // MARK: - 오늘 몸 상태

    private var todayCheck: BodyCheck? { checks.first { cal.isDateInToday($0.day) } }

    @ViewBuilder
    private var todayBodyCard: some View {
        if ConditionPrefs.isOn(.body) {
            Card {
                CardHeader(title: "오늘 몸 상태", systemImage: "figure.stand", trailing: todayCheck.map { BodyWords.text($0.value) })
                BodyCheckRow(value: todayCheck?.value) { v in
                    BodyCheckStore.set(v, context: context)
                }
                Text("하키 안 탄 날도 남겨. 1은 많이 처짐, 5는 아주 좋음.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    // MARK: - 날마다 한 줄

    private var listCard: some View {
        let recent = Array(shown.sorted { $0.day > $1.day }.prefix(14))
        return Card {
            CardHeader(title: "날마다", systemImage: "list.bullet.rectangle")
            if recent.isEmpty {
                EmptyHint(text: "아직 보여줄 날이 없어.")
            }
            ForEach(recent, id: \.day) { d in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(d.day.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated))).font(.subheadline.bold()).foregroundStyle(Theme.title)
                        if d.skated { Image(systemName: "figure.hockey").font(.caption).foregroundStyle(Theme.neonPink) }
                        if cycleOn && d.period { Image(systemName: "drop.fill").font(.caption2).foregroundStyle(Theme.neonPink.opacity(0.6)) }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        ForEach(enabledMetrics, id: \.self) { m in
                            if let v = m.value(d) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(m.title).font(.caption2).foregroundStyle(Theme.inkSecondary)
                                    Text(m == .mood ? Mood.face(Int(v)) : (m == .body ? BodyWords.short(Int(v)) : (m == .fatigue ? "\(Int(v))/5" : m.text(v))))
                                        .font(.caption.bold()).foregroundStyle(Theme.title)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    // MARK: - 항목 고르기

    private var settingsCard: some View {
        Card {
            CardHeader(title: "항목 고르기", systemImage: "slider.horizontal.3")
            ForEach(ConditionMetric.allCases, id: \.self) { m in
                Toggle(isOn: Binding(get: { ConditionPrefs.isOn(m) }, set: { on in toggle(m, on) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.title).font(.subheadline)
                        Text(m.help).font(.caption2).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            if !healthOn {
                NavigationLink { HealthConnectView() } label: {
                    Label("Apple 건강 연결하기 (잔 시간·심박용)", systemImage: "heart.text.square.fill")
                }
            } else {
                CycleConsentToggle()
            }
            if let errorText { Text(errorText).font(.footnote).foregroundStyle(Theme.danger) }
        }
    }

    private func toggle(_ m: ConditionMetric, _ on: Bool) {
        if on && [.restingHR, .hrv].contains(m) && healthOn {
            Task {
                do { try await HealthService.shared.requestConditionAccess(); ConditionPrefs.set(m, true) }
                catch { errorText = "권한 화면을 열지 못했어." }
                prefsTick += 1
            }
        } else {
            ConditionPrefs.set(m, on); prefsTick += 1
        }
        if !on, metric == m, let first = ConditionPrefs.enabledMetrics.first { metric = first }
    }

    // MARK: - 읽기

    private func load() async {
        loading = true; defer { loading = false }
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -95, to: today)!   // 평소(4주) 비교까지 되게 넉넉히
        var map: [Date: ConditionDay] = [:]
        func at(_ d: Date) -> ConditionDay { map[d] ?? ConditionDay(day: d) }

        for s in sessions where s.startsAt >= from {
            let d = cal.startOfDay(for: s.startsAt); var c = at(d)
            c.skated = true
            if c.mood == nil { c.mood = s.moodAfter }
            if let f = s.fatigue { c.fatigue = max(c.fatigue ?? 0, f) }
            map[d] = c
        }
        for j in journals where j.entryDate >= from {
            let d = cal.startOfDay(for: j.entryDate); var c = at(d)
            if c.mood == nil { c.mood = j.mood }
            map[d] = c
        }
        for b in checks where b.day >= from {
            var c = at(cal.startOfDay(for: b.day)); c.body = b.value; map[c.day] = c
        }
        if healthOn && HealthService.shared.isAvailable {
            errorText = nil
            if ConditionPrefs.isOn(.sleep), let segs = try? await HealthService.shared.sleepSegments(from: from.addingTimeInterval(-12 * 3600), to: Date()) {
                for (d, m) in ConditionTrack.sleepByWakeDay(segs) where d >= from { var c = at(d); c.sleepMinutes = m; map[d] = c }
            }
            if ConditionPrefs.isOn(.restingHR), let hr = try? await HealthService.shared.dailyRestingHR(from: from, to: Date()) {
                for (d, v) in hr { var c = at(d); c.restingHR = v; map[d] = c }
            }
            if ConditionPrefs.isOn(.hrv), let hrv = try? await HealthService.shared.dailyHRV(from: from, to: Date()) {
                for (d, v) in hrv { var c = at(d); c.hrv = v; map[d] = c }
            }
            if cycleOn, let pd = try? await HealthService.shared.menstrualDays(from: from, to: Date()) {
                for d in pd { var c = at(d); c.period = true; map[d] = c }
            }
        }
        days = map.values.sorted { $0.day < $1.day }
    }
}

/// '오늘 몸 상태' 1~5 말.
enum BodyWords {
    static let words = ["많이 처짐", "조금 처짐", "보통", "좋음", "아주 좋음"]
    static func text(_ v: Int) -> String { words[max(1, min(v, 5)) - 1] }
    static func short(_ v: Int) -> String { ["처짐", "약간", "보통", "좋음", "최고"][max(1, min(v, 5)) - 1] }
}

/// 1~5 버튼 한 줄. 같은 값을 다시 누르면 지운다.
struct BodyCheckRow: View {
    var value: Int?
    var onPick: (Int?) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { v in
                let on = value == v
                Button { onPick(on ? nil : v) } label: {
                    VStack(spacing: 2) {
                        Text("\(v)").font(.headline)
                        Text(BodyWords.short(v)).font(.caption2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(on ? .white : Theme.title)
                    .background(on ? Theme.cobalt : Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("몸 상태 \(BodyWords.text(v))")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

enum BodyCheckStore {
    /// 오늘 값을 바꾸거나(nil이면 지움) 새로 만든다. 하루에 하나.
    @MainActor
    static func set(_ value: Int?, on day: Date = Date(), context: ModelContext) {
        let d = Calendar.current.startOfDay(for: day)
        let all = (try? context.fetch(FetchDescriptor<BodyCheck>())) ?? []
        let mine = all.filter { Calendar.current.isDate($0.day, inSameDayAs: d) }
        if let v = value {
            if let first = mine.first { first.value = v; mine.dropFirst().forEach(context.delete) }
            else { context.insert(BodyCheck(day: d, value: v)) }
        } else {
            mine.forEach(context.delete)
        }
        context.saveOrReport()
    }
}

/// 생리 주기 토글(건강 연결 뒤). 컨디션 화면과 건강 화면이 같이 쓴다.
struct CycleConsentToggle: View {
    @AppStorage(HealthPrefs.cycleKey) private var cycleEnabled = false
    @State private var errorText: String?

    var body: some View {
        Toggle(isOn: Binding(get: { cycleEnabled }, set: { on in
            if on {
                Task {
                    do { try await HealthService.shared.requestCycleAccess(); cycleEnabled = true }
                    catch { errorText = "권한 화면을 열지 못했어." }
                }
            } else { cycleEnabled = false }
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("생리 기간 같이 보기").font(.subheadline)
                Text("그래프에 옅은 띠로만 표시해. 리포트·공유·AI 요약엔 절대 안 넣어.").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
        if let errorText { Text(errorText).font(.footnote).foregroundStyle(Theme.danger) }
    }
}
