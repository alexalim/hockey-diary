import SwiftUI
import SwiftData
import HockeyCore
import UIKit

/// 일정 하나: 참석 체크, 라인업, 공유(이미지·글), 경기 기록 만들기.
struct TeamEventView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppJumper.self) private var jumper: AppJumper?
    @Bindable var event: TeamEvent
    let team: Team
    @Query(sort: \TeamMember.createdAt) private var allMembers: [TeamMember]

    @State private var editing = false
    @State private var editingLineup = false
    @State private var toast: String?
    @State private var openSession: Session?
    /// 참석 목록에서 볼 상태. nil이면 전체.
    @State private var attendanceFilter: Attendance?
    /// 라인업을 표로 볼지 링크 모양으로 볼지(다음에 열어도 그대로).
    @AppStorage("lineupAsRink") private var lineupAsRink = false

    private var members: [TeamMember] {
        // 명단에서 뺀 사람도 이 일정에 이미 들어가 있으면 보여준다.
        let active = allMembers.filter { $0.teamID == team.id && $0.isActive }
        let used = Set(event.attendance.marks.keys).union(event.lineup.assignedMembers)
        return active + allMembers.filter { !$0.isActive && used.contains($0.id) }
    }
    private var names: [UUID: String] { Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) }) }
    private var ids: [UUID] { members.map(\.id) }

    var body: some View {
        // 일정이나 팀이 지워졌으면(다른 탭에서 지운 경우 포함) 빈 화면으로 남지 않게 닫는다.
        if event.isDeleted || event.modelContext == nil {
            Color.clear.onAppear { dismiss() }
        } else {
            detail
        }
    }

    private var detail: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text(event.matchTitle(teamName: team.name)).font(.title3.bold()).foregroundStyle(.white)
                    Text((event.opponent.isEmpty ? "" : "\(event.kind.title) · ") + event.whenText + (event.rinkName.isEmpty ? "" : " · \(event.rinkName)")).font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    if !event.memo.isEmpty { Text(event.memo).font(.subheadline).foregroundStyle(.white.opacity(0.85)) }
                }
                attendanceCard
                lineupCard
                shareCard
                sessionCard
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("일정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("고치기") { editing = true } } }
        .sheet(isPresented: $editing) { NavigationStack { TeamEventEditor(team: team, event: event) } }
        .sheet(isPresented: $editingLineup) { NavigationStack { LineupEditor(event: event, members: members.filter(\.isActive)) } }
        .navigationDestination(item: $openSession) { s in SessionDetailView(session: s) }
        .toast($toast)
    }

    // MARK: - 참석

    private var attendanceCard: some View {
        let sheet = event.attendance
        return Card {
            CardHeader(title: "참석", systemImage: "checkmark.circle",
                       trailing: members.isEmpty ? nil : "참석 \(sheet.count(.going, among: ids)) · 미정 \(sheet.count(.maybe, among: ids)) · 불참 \(sheet.count(.notGoing, among: ids))")
            if members.isEmpty {
                EmptyHint(text: "우리 팀 화면에서 팀원을 먼저 넣어 주세요.", link: EmptyLink("우리 팀으로") { TeamView() })
            }
            if members.count > 1 { attendanceTools(sheet) }
            ForEach(members.filter { attendanceFilter == nil || sheet[$0.id] == attendanceFilter }) { m in
                HStack(spacing: 8) {
                    Text(m.display).font(.subheadline).foregroundStyle(Theme.title).lineLimit(1)
                        .frame(minWidth: 72, alignment: .leading)
                    Spacer(minLength: 4)
                    ForEach([Attendance.going, .maybe, .notGoing], id: \.self) { a in
                        let on = sheet[m.id] == a
                        Button {
                            var s = event.attendance
                            s[m.id] = on ? .unknown : a
                            event.attendance = s
                            context.saveOrReport()
                        } label: {
                            Text(a.title).font(.caption.bold())
                                .frame(width: 48, height: 34)
                                .foregroundStyle(on ? .white : Theme.title)
                                .background(on ? a.color : Theme.cobaltSoft,
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(m.name) \(a.title)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .frame(minHeight: Theme.touch)
            }
            if !members.isEmpty {
                Text("카톡 답을 보고 체크해요. 한 번 더 누르면 '답 없음'으로 돌아가요.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    /// 상태별로 골라 보기와, 답 없는 사람 한꺼번에 채우기.
    private func attendanceTools(_ sheet: AttendanceSheet) -> some View {
        let unanswered = sheet.count(.unknown, among: ids)
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip("전체 \(ids.count)", nil)
                    ForEach([Attendance.going, .maybe, .notGoing, .unknown], id: \.self) { a in
                        filterChip("\(a.title) \(sheet.count(a, among: ids))", a)
                    }
                }
            }
            if unanswered > 0 {
                Menu {
                    Button("답 없는 \(unanswered)명 모두 참석") { fillUnanswered(.going) }
                    Button("답 없는 \(unanswered)명 모두 불참") { fillUnanswered(.notGoing) }
                } label: {
                    Label("답 없는 사람 한꺼번에", icon: "checklist").font(.subheadline)
                }
            }
        }
    }

    private func filterChip(_ text: String, _ a: Attendance?) -> some View {
        let on = attendanceFilter == a
        return Button { attendanceFilter = a } label: {
            Text(text).font(.caption.bold())
                .padding(.horizontal, 10).frame(minHeight: 32)
                .foregroundStyle(on ? Color.white : Theme.cobalt)
                .background(on ? Theme.cobalt : Theme.cobaltSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("보기 \(text)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func fillUnanswered(_ a: Attendance) {
        var s = event.attendance
        let n = s.fillUnanswered(with: a, among: ids)
        event.attendance = s
        context.saveOrReport()
        toast = "\(n)명을 \(a.title)으로 바꿨어요."
    }

    // MARK: - 라인업

    private var lineupCard: some View {
        let text = event.lineup.text(names: names)
        return Card {
            CardHeader(title: "라인업", systemImage: "rectangle.split.3x3")
            if text.isEmpty {
                EmptyHint(text: "포워드 3라인, 수비 3조, 골리를 자리에 넣어 보세요. 참석한 사람만 골라도 돼요.", systemImage: "rectangle.split.3x3")
            } else {
                Picker("라인업 모양", selection: $lineupAsRink) {
                    Text("표").tag(false)
                    Text("링크장").tag(true)
                }
                .pickerStyle(.segmented)
                if lineupAsRink {
                    LineupRink(lineup: event.lineup, names: names)
                } else {
                    LineupBoard(lineup: event.lineup, names: names)
                }
            }
            Button { editingLineup = true } label: {
                Label(text.isEmpty ? "라인업 짜기" : "라인업 고치기", icon: "pencil").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
            .disabled(members.filter(\.isActive).isEmpty)
            if members.filter(\.isActive).isEmpty {
                Text("팀원을 먼저 추가하면 라인업을 짤 수 있어요.").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    // MARK: - 공유

    private var shareText: String {
        let sheet = event.attendance
        return TeamText.event(teamName: team.name, title: event.title, when: event.whenText, rink: event.rinkName,
                              opponent: event.opponent, memo: event.memo,
                              going: sheet.count(.going, among: ids), maybe: sheet.count(.maybe, among: ids), total: ids.count,
                              lineup: event.lineup.text(names: names))
    }

    private var shareCard: some View {
        Card(tint: Theme.iceBlue) {
            CardHeader(title: "카톡에 올리기", systemImage: "square.and.arrow.up")
            HStack(spacing: 10) {
                if let image = renderImage() {
                    ShareLink(item: image, preview: SharePreview("\(team.name) \(event.title)", image: image)) {
                        Label("이미지로", icon: "photo").frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.cobalt)
                }
                Button {
                    UIPasteboard.general.string = shareText
                    toast = "글을 복사했어요. 카톡에 붙여 넣으세요."
                } label: {
                    Label("글로 복사", icon: "doc.on.doc").frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.bordered)
            }
            Text("이미지에는 팀 로고, 일정, 참석 인원, 라인업 이름이 들어가요. 일기나 개인 기록은 안 들어가요.").font(.caption).foregroundStyle(Theme.inkSecondary)
        }
    }

    @MainActor
    private func renderImage() -> Image? {
        let sheet = event.attendance
        let card = TeamShareCard(teamName: team.name, title: event.title, when: event.whenText, rink: event.rinkName,
                                 opponent: event.opponent, memo: event.memo,
                                 going: sheet.count(.going, among: ids), maybe: sheet.count(.maybe, among: ids), total: ids.count,
                                 lineup: event.lineup, names: names, logo: team.logoData)
        // 공유 이미지는 항상 라이트 색으로 그린다(다크 모드에서 흰 바탕에 밝은 글자가 되지 않게).
        let renderer = ImageRenderer(content: card.frame(width: 390).environment(\.colorScheme, .light))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }

    // MARK: - 경기 기록

    private var sessionCard: some View {
        Card {
            CardHeader(title: "경기 기록", systemImage: "figure.hockey")
            if event.sessionID != nil {
                Text("이 일정으로 만든 기록이 있어요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            } else {
                Text("경기가 끝나면 이 일정으로 바로 기록해 보세요. 상대·링크장·시간은 미리 채워 둘게요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            Button {
                // 예전엔 누르자마자 빈 기록을 저장하고 읽기 화면을 열어, 그냥 나가도 빈 기록이 주간 횟수에 잡혔다.
                if event.sessionID != nil {
                    openSession = TeamStore.makeSession(for: event, context: context)
                } else {
                    jumper?.go(.entry(.event(event.id)))
                }
            } label: {
                Label(event.sessionID == nil ? "이 일정으로 기록 만들기" : "기록 보기", icon: "square.and.pencil").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// 링크 모양 라인업. 고른 라인의 공격 셋·수비 둘·골리를 실제 서는 자리에 놓는다(위가 상대 골대 쪽).
struct LineupRink: View {
    let lineup: Lineup
    let names: [UUID: String]
    @State private var line = 0

    /// 누가 한 명이라도 들어 있는 라인만 고르게 한다. 1라인은 늘 보인다.
    private var lines: [Int] {
        (0..<3).filter { i in
            i == 0 || (LineupSlot.forwardLines[i] + LineupSlot.defensePairs[i]).contains { lineup[$0] != nil }
        }
    }

    var body: some View {
        let fw = LineupSlot.forwardLines[line], df = LineupSlot.defensePairs[line]
        VStack(spacing: 8) {
            if lines.count > 1 {
                Picker("라인", selection: $line) {
                    ForEach(lines, id: \.self) { Text("\($0 + 1)라인").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            VStack(spacing: 16) {
                HStack(spacing: 8) { ForEach(fw, id: \.self) { spot($0) } }
                HStack(spacing: 8) { ForEach(df, id: \.self) { spot($0) } }.padding(.horizontal, 36)
                spot(.g1).frame(maxWidth: 130)
            }
            .padding(.horizontal, 12).padding(.top, 26).padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background { rink }
        }
    }

    /// 수비 지역 쪽 반 링크: 위에 빨간 중앙선, 가운데 파란 선, 아래 골 크리스.
    private var rink: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.cobaltSoft.opacity(0.55))
                RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.cobalt.opacity(0.35), lineWidth: 2)
                Rectangle().fill(Theme.danger.opacity(0.55)).frame(width: w - 4, height: 3).position(x: w / 2, y: 10)
                Rectangle().fill(Theme.cobalt.opacity(0.45)).frame(width: w - 4, height: 3).position(x: w / 2, y: h * 0.44)
                Circle().trim(from: 0.5, to: 1).stroke(Theme.danger.opacity(0.5), lineWidth: 2)
                    .frame(width: 96, height: 96).position(x: w / 2, y: h - 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func spot(_ s: LineupSlot) -> some View {
        let name = lineup[s].flatMap { names[$0] }
        return VStack(spacing: 2) {
            Text(s.short.replacingOccurrences(of: "G2", with: "G")).font(.caption2.bold())
                .foregroundStyle(s.position == .goalie ? Theme.neonPink : Theme.accent)
            Text(name ?? "—").font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(name == nil ? Theme.inkTertiary : Theme.title)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(s.position == .goalie ? Theme.neonPink.opacity(0.5) : Theme.cobalt.opacity(0.25)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.short) \(name ?? "비어 있음")")
    }
}

/// 라인업 보드(화면·이미지 공용).
struct LineupBoard: View {
    let lineup: Lineup
    let names: [UUID: String]
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            ForEach(Array(LineupSlot.forwardLines.enumerated()), id: \.offset) { i, line in
                if line.contains(where: { lineup[$0] != nil }) { row("\(i + 1)라인", line) }
            }
            ForEach(Array(LineupSlot.defensePairs.enumerated()), id: \.offset) { i, pair in
                if pair.contains(where: { lineup[$0] != nil }) { row("수비 \(i + 1)조", pair) }
            }
            if LineupSlot.goalies.contains(where: { lineup[$0] != nil }) { row("골리", LineupSlot.goalies) }
        }
    }

    private func row(_ label: String, _ slots: [LineupSlot]) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption.bold()).foregroundStyle(Theme.inkSecondary).frame(width: 52, alignment: .leading)
            ForEach(slots, id: \.self) { s in
                Text(lineup[s].flatMap { names[$0] } ?? "—")
                    .font(compact ? .caption : .subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: compact ? 26 : 34)
                    .foregroundStyle(lineup[s] == nil ? Theme.inkTertiary : Theme.title)
                    .background(s.position == .goalie ? Theme.neonPink.opacity(0.15) : Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

/// 자리를 누르고 팀원을 고른다.
struct LineupEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var event: TeamEvent
    let members: [TeamMember]

    @State private var lineup = Lineup()
    @State private var picking: LineupSlot?
    @State private var loaded = false

    private var names: [UUID: String] { Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) }) }

    var body: some View {
        Form {
            group("포워드", LineupSlot.forwardLines)
            group("수비", LineupSlot.defensePairs)
            group("골리", [LineupSlot.goalies])
            Section {
                Button("라인업 비우기", role: .destructive) { lineup = Lineup() }
            } footer: {
                Text("참석으로 체크한 사람이 위에 먼저 나와요. 한 사람은 한 자리에만 들어가요.")
            }
        }
        .navigationTitle("라인업")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("저장") { event.lineup = lineup; context.saveOrReport(); dismiss() } }
        }
        .onAppear { if !loaded { loaded = true; lineup = event.lineup } }
        .sheet(item: $picking) { slot in
            NavigationStack {
                List {
                    Section {
                        Button("비우기") { lineup.assign(nil, to: slot); picking = nil }
                    }
                    Section("\(slot.groupTitle) \(slot.short)") {
                        ForEach(sortedForPick(slot)) { m in
                            Button {
                                lineup.assign(m.id, to: slot)
                                picking = nil
                            } label: {
                                HStack {
                                    Text(m.position.short).font(.caption.bold()).foregroundStyle(Theme.inkSecondary).frame(width: 20)
                                    Text(m.display).foregroundStyle(.primary)
                                    Spacer()
                                    if event.attendance[m.id] == .going { StatusTag(text: "참석", kind: .success) }
                                    if lineup.assignedMembers.contains(m.id) { Text("배정됨").font(.caption).foregroundStyle(Theme.inkSecondary) }
                                }
                                .frame(minHeight: Theme.touch)
                            }
                        }
                    }
                }
                .navigationTitle("누구?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { picking = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func sortedForPick(_ slot: LineupSlot) -> [TeamMember] {
        members.sorted { a, b in
            let ga = event.attendance[a.id] == .going, gb = event.attendance[b.id] == .going
            if ga != gb { return ga }
            let pa = a.position == slot.position, pb = b.position == slot.position
            if pa != pb { return pa }
            return a.createdAt < b.createdAt
        }
    }

    private func group(_ title: String, _ lines: [[LineupSlot]]) -> some View {
        Section(title) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, slots in
                HStack(spacing: 6) {
                    ForEach(slots, id: \.self) { s in
                        Button { picking = s } label: {
                            VStack(spacing: 2) {
                                Text(s.short).font(.caption2.bold()).foregroundStyle(Theme.inkSecondary)
                                Text(lineup[s].flatMap { names[$0] } ?? "비어 있음")
                                    .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                                    .foregroundStyle(lineup[s] == nil ? Theme.inkTertiary : Theme.title)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(lineup[s] == nil ? Theme.card : Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.inkTertiary.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

extension LineupSlot: Identifiable { public var id: String { rawValue } }

/// 카톡용 공유 이미지. 색은 라이트·다크와 무관하게 고정.
struct TeamShareCard: View {
    let teamName: String, title: String, when: String, rink: String, opponent: String, memo: String
    let going: Int, maybe: Int, total: Int
    let lineup: Lineup
    let names: [UUID: String]
    var logo: Data? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let logo { PhotoThumb(data: logo, size: 28, corner: 14) }
                Text(teamName).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                Spacer()
                Text("마하다").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            Text(title).font(.title.bold()).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Label(when, icon: "clock")
                if !rink.isEmpty { Label(rink, icon: "mappin") }
                if !opponent.isEmpty { Label("vs \(opponent)", icon: "flag") }
                if !memo.isEmpty { Label(memo, icon: "note.text") }
            }
            .font(.subheadline).foregroundStyle(.white)
            if total > 0 {
                HStack(spacing: 8) {
                    pill("참석 \(going)", Theme.success)
                    pill("미정 \(maybe)", Theme.warningFill)
                    pill("\(total)명 중", Color.white.opacity(0.2))
                }
            }
            if !lineup.assignments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("라인업").font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                    LineupBoard(lineup: lineup, names: names, compact: true)
                        .padding(10)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(22)
        .background(Theme.heroGradient)
    }

    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5).background(c, in: Capsule())
    }
}
