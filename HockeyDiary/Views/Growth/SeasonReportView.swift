import SwiftUI
import SwiftData
import HockeyCore

/// 시즌 리포트 (P1). 하키 숫자와 기술 이름만 담은 이미지를 만들어 저장·공유한다.
/// 일기·건강·사진·위치는 리포트 타입에 칸이 없어 들어갈 수 없다 (T09).
struct SeasonReportView: View {
    @Query(sort: \Session.startsAt) private var sessions: [Session]
    @Query private var learnings: [SkillLearning]
    @Query private var attempts: [SkillAttempt]
    @Environment(\.displayScale) private var displayScale

    enum Range: String, CaseIterable { case season, year, quarter, all
        var title: String {
            switch self { case .season: return "이번 시즌"; case .year: return "올해"; case .quarter: return "최근 90일"; case .all: return "전체" }
        }
    }
    @State private var range: Range = .season

    private var bounds: (Date?, Date) {
        let cal = Calendar.current, now = Date()
        switch range {
        case .season:
            // 9월에 시작하는 시즌(9월~이듬해 8월)으로 본다.
            let y = cal.component(.year, from: now), m = cal.component(.month, from: now)
            let start = cal.date(from: DateComponents(year: m >= 9 ? y : y - 1, month: 9, day: 1))
            return (start, now)
        case .year: return (cal.date(from: DateComponents(year: cal.component(.year, from: now), month: 1, day: 1)), now)
        case .quarter: return (Period.quarter.start(from: now), now)
        case .all: return (nil, now)
        }
    }

    private var report: SeasonReport {
        let (from, to) = bounds
        let events = learnings.compactMap { l -> SeasonReport.SkillEvent? in
            guard let n = l.skill?.name, let at = l.session?.startsAt else { return nil }
            return .init(skill: n, at: at, lesson: true, tried: false)
        } + attempts.compactMap { a -> SeasonReport.SkillEvent? in
            guard let n = a.skill?.name, let at = a.session?.startsAt else { return nil }
            return .init(skill: n, at: at, lesson: false, tried: a.tried)
        }
        return SeasonReport.make(title: range.title, from: from, to: to, samples: sessions.map(\.sample), skillEvents: events)
    }

    var body: some View {
        let r = report
        ScrollView {
            VStack(spacing: 16) {
                Picker("기간", selection: $range) {
                    ForEach(Range.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ReportCard(report: r)
                    .frame(width: 330, height: 412)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                if r.sessions == 0 {
                    EmptyHint(text: "이 기간엔 활동 기록이 없어. 기록이 쌓이면 리포트가 채워져.")
                } else if let image = render(r) {
                    ShareLink(item: image, preview: SharePreview("마하다 \(r.title) 리포트", image: image)) {
                        Label("이미지 저장·공유", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PinkButtonStyle())
                }
                Text("리포트에는 활동 횟수·시간·기술 이름만 들어가. 하루 일기, 기분 메모, 수면·심박, 사진, 장소 위치는 넣지 않아.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("시즌 리포트")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func render(_ r: SeasonReport) -> Image? {
        let renderer = ImageRenderer(content: ReportCard(report: r).frame(width: 360, height: 450))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}

/// 리포트 카드 그림(화면과 이미지에 같이 쓴다). 색은 라이트·다크와 무관하게 고정.
struct ReportCard: View {
    let report: SeasonReport

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0047AB), Color(hex: 0x152B4F)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("마하다").font(.system(.headline, design: .rounded).weight(.heavy))
                    Spacer()
                    Text(report.title).font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color(hex: 0xFF2D95), in: Capsule())
                }
                Text(rangeText).font(.caption).opacity(0.8)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(report.sessions)").font(.system(size: 54, weight: .black, design: .rounded))
                    Text("번 빙판에 섰어").font(.headline)
                }
                Text("얼음 위 \(minutesText(report.minutes))").font(.title3.bold())
                HStack(spacing: 8) {
                    stat("수업", report.byType[.lesson] ?? 0)
                    stat("경기", (report.byType[.miniGame] ?? 0) + (report.byType[.regularGame] ?? 0))
                    stat("자유 연습", report.byType[.freePractice] ?? 0)
                }
                if !report.topSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("많이 만난 기술").font(.caption.bold()).opacity(0.8)
                        ForEach(report.topSkills, id: \.name) { s in
                            Text("· \(s.name)  수업 \(s.lessons) · 경기에서 써봄 \(s.tried)").font(.subheadline)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    if (report.bySurface[.pond] ?? 0) > 0 { Label("폰드 \(report.bySurface[.pond]!)번", systemImage: "water.waves").font(.caption) }
                    if report.bestDays > 0 { Label("최고의 날 \(report.bestDays)번", systemImage: "heart.fill").font(.caption) }
                    Spacer()
                    Image(systemName: "hockey.puck.fill").opacity(0.6)
                }
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }

    private var rangeText: String {
        let f = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return report.from.map { "\($0.formatted(f)) ~ \(report.to.formatted(f))" } ?? "처음부터 \(report.to.formatted(f))까지"
    }

    private func stat(_ title: String, _ n: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.title2.bold())
            Text(title).font(.caption2).opacity(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
