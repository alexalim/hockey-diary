import SwiftUI
import SwiftData
import HockeyCore
import UIKit

/// 일정 하나: 참석 체크, 라인업, 공유(이미지·글), 경기 기록 만들기.
struct TeamEventView: View {
    @Environment(\.modelContext) private var context
    @Bindable var event: TeamEvent
    let team: Team
    @Query(sort: \TeamMember.createdAt) private var allMembers: [TeamMember]

    @State private var editing = false
    @State private var editingLineup = false
    @State private var toast: String?
    @State private var openSession: Session?

    private var members: [TeamMember] {
        // 명단에서 뺀 사람도 이 일정에 이미 들어가 있으면 보여준다.
        let active = allMembers.filter { $0.teamID == team.id && $0.isActive }
        let used = Set(event.attendance.marks.keys).union(event.lineup.assignedMembers)
        return active + allMembers.filter { !$0.isActive && used.contains($0.id) }
    }
    private var names: [UUID: String] { Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) }) }
    private var ids: [UUID] { members.map(\.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text(event.title).font(.title3.bold()).foregroundStyle(.white)
                    Text(event.whenText + (event.rinkName.isEmpty ? "" : " · \(event.rinkName)")).font(.subheadline).foregroundStyle(.white.opacity(0.9))
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
                EmptyHint(text: "우리 팀 화면에서 팀원을 먼저 넣어 주세요.")
            }
            ForEach(members) { m in
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
                Text("카톡 답을 보고 체크해요. 한 번 더 누르면 '답 없음'으로 돌아가요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    // MARK: - 라인업

    private var lineupCard: some View {
        let text = event.lineup.text(names: names)
        return Card {
            CardHeader(title: "라인업", systemImage: "rectangle.split.3x3")
            if text.isEmpty {
                EmptyHint(text: "포워드 3라인, 수비 3조, 골리를 자리에 넣어 보세요. 참석한 사람만 골라도 돼요.", systemImage: "rectangle.split.3x3")
            } else {
                LineupBoard(lineup: event.lineup, names: names)
            }
            Button { editingLineup = true } label: {
                Label(text.isEmpty ? "라인업 짜기" : "라인업 고치기", systemImage: "pencil").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
            .disabled(members.filter(\.isActive).isEmpty)
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
                        Label("이미지로", systemImage: "photo").frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.cobalt)
                }
                Button {
                    UIPasteboard.general.string = shareText
                    toast = "글을 복사했어요. 카톡에 붙여 넣으세요."
                } label: {
                    Label("글로 복사", systemImage: "doc.on.doc").frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .buttonStyle(.bordered)
            }
            Text("이미지에는 일정, 참석 인원, 라인업 이름이 들어가요. 일기나 개인 기록은 안 들어가요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
    }

    @MainActor
    private func renderImage() -> Image? {
        let sheet = event.attendance
        let card = TeamShareCard(teamName: team.name, title: event.title, when: event.whenText, rink: event.rinkName,
                                 opponent: event.opponent, memo: event.memo,
                                 going: sheet.count(.going, among: ids), maybe: sheet.count(.maybe, among: ids), total: ids.count,
                                 lineup: event.lineup, names: names)
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
                Text("경기가 끝나면 이 일정으로 기록을 만들어 보세요. 상대·링크장·시간이 미리 채워져요.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            Button {
                openSession = TeamStore.makeSession(for: event, context: context)
            } label: {
                Label(event.sessionID == nil ? "이 일정으로 기록 만들기" : "기록 보기", systemImage: "square.and.pencil").frame(maxWidth: .infinity, minHeight: Theme.touch)
            }
            .buttonStyle(.bordered)
        }
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
                                    if lineup.assignedMembers.contains(m.id) { Text("배정됨").font(.caption2).foregroundStyle(Theme.inkSecondary) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(teamName).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                Spacer()
                Text("마하다").font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
            Text(title).font(.title.bold()).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Label(when, systemImage: "clock")
                if !rink.isEmpty { Label(rink, systemImage: "mappin") }
                if !opponent.isEmpty { Label("vs \(opponent)", systemImage: "flag") }
                if !memo.isEmpty { Label(memo, systemImage: "note.text") }
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
