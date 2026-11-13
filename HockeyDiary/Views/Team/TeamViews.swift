import SwiftUI
import SwiftData
import HockeyCore

/// 우리 팀 홈: 팀 이름, 다음 일정, 명단. 모든 것은 이 아이폰 안에만 있고, 공유는 이미지·글로 한다.
struct TeamView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Team.createdAt) private var teams: [Team]
    @Query(sort: \TeamMember.createdAt) private var allMembers: [TeamMember]
    @Query(sort: \TeamEvent.at) private var allEvents: [TeamEvent]

    @State private var newTeamName = ""
    @State private var editingMember: TeamMember?
    @State private var addingMember = false
    @State private var addingEvent = false
    @State private var renaming = false

    private var team: Team? { teams.first }
    private var members: [TeamMember] { allMembers.filter { $0.teamID == team?.id && $0.isActive } }
    private var events: [TeamEvent] { allEvents.filter { $0.teamID == team?.id } }
    private var upcoming: [TeamEvent] { events.filter { $0.at >= Calendar.current.startOfDay(for: Date()) } }
    private var past: [TeamEvent] { events.filter { $0.at < Calendar.current.startOfDay(for: Date()) }.reversed() }

    var body: some View {
        Group {
            if let team {
                teamBody(team)
            } else {
                createBody
            }
        }
        .screenBackground()
        .navigationTitle(team?.name ?? "우리 팀")
    }

    private var createBody: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card(tint: Theme.cobalt) {
                    Text("우리 팀 만들기").font(.title3.bold()).foregroundStyle(.white)
                    Text("경기 일정과 참석, 라인업을 정리해서 카톡에 이미지나 글로 올릴 수 있어요. 팀 정보는 이 아이폰에만 저장돼요.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                Card {
                    TextField("팀 이름 (예: 목동 펭귄스)", text: $newTeamName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let t = Team(name: newTeamName.trimmingCharacters(in: .whitespaces))
                        context.insert(t)
                        context.saveOrReport()
                    } label: { Text("만들기").frame(maxWidth: .infinity, minHeight: Theme.touch) }
                        .buttonStyle(PinkButtonStyle())
                        .disabled(newTeamName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
        }
    }

    private func teamBody(_ team: Team) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Card {
                    CardHeader(title: "다음 일정", systemImage: "calendar", trailing: upcoming.isEmpty ? nil : "\(upcoming.count)개")
                    if upcoming.isEmpty {
                        EmptyHint(text: "다음 경기나 연습 일정을 넣어 보세요. 일정마다 참석 체크와 라인업을 짤 수 있어요.", systemImage: "calendar.badge.plus")
                    }
                    ForEach(upcoming) { e in
                        NavigationLink { TeamEventView(event: e, team: team) } label: { eventRow(e) }.buttonStyle(.plain)
                    }
                    Button { addingEvent = true } label: { Label("일정 추가", icon: "plus") }
                }
                Card {
                    CardHeader(title: "명단", systemImage: "person.3.fill", trailing: "\(members.count)명")
                    if members.isEmpty {
                        EmptyHint(text: "팀원을 넣어두면 참석 체크와 라인업에서 바로 고를 수 있어요. 용병도 넣을 수 있어요.")
                    }
                    ForEach(members) { m in
                        Button { editingMember = m } label: {
                            HStack {
                                Text(m.position.short).font(.caption.bold()).foregroundStyle(.white)
                                    .frame(width: 26, height: 26).background(m.position == .goalie ? Theme.neonPink : Theme.cobalt, in: Circle())
                                Text(m.display).foregroundStyle(Theme.title)
                                if m.isGuest { StatusTag(text: "용병") }
                                Spacer()
                                AppIcon("chevron.right").font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                            .frame(minHeight: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { addingMember = true } label: { Label("팀원 추가", icon: "person.badge.plus") }
                }
                if !past.isEmpty {
                    Card {
                        CardHeader(title: "지난 일정", systemImage: "clock.arrow.circlepath")
                        ForEach(past.prefix(10)) { e in
                            NavigationLink { TeamEventView(event: e, team: team) } label: { eventRow(e) }.buttonStyle(.plain)
                        }
                    }
                }
                Text("팀 정보는 이 아이폰에만 있어요. 공유하려면 일정 화면에서 이미지나 글로 올려요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("이름") { newTeamName = team.name; renaming = true } } }
        .alert("팀 이름", isPresented: $renaming) {
            TextField("팀 이름", text: $newTeamName)
            Button("저장") { team.name = newTeamName.trimmingCharacters(in: .whitespaces); context.saveOrReport() }
            Button("취소", role: .cancel) {}
        }
        .sheet(isPresented: $addingMember) { NavigationStack { TeamMemberEditor(team: team, member: nil) } }
        .sheet(item: $editingMember) { m in NavigationStack { TeamMemberEditor(team: team, member: m) } }
        .sheet(isPresented: $addingEvent) { NavigationStack { TeamEventEditor(team: team, event: nil) } }
    }

    private func eventRow(_ e: TeamEvent) -> some View {
        let going = e.attendance.count(.going, among: members.map(\.id))
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(e.at.formatted(.dateTime.day())).font(.title3.bold()).foregroundStyle(Theme.title)
                Text(e.at.formatted(.dateTime.weekday(.abbreviated))).font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text("\(e.at.formatted(.dateTime.month().hour().minute()))\(e.rinkName.isEmpty ? "" : " · \(e.rinkName)")").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if !members.isEmpty {
                StatusTag(text: "참석 \(going)", kind: going >= 10 ? .success : .neutral)
            }
            AppIcon("chevron.right").font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .frame(minHeight: Theme.touch)
    }
}

/// 팀원 추가·수정.
struct TeamMemberEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let team: Team
    let member: TeamMember?

    @State private var name = ""
    @State private var number = ""
    @State private var position: Position = .any
    @State private var isGuest = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextField("이름 또는 별명", text: $name)
                TextField("등번호", text: $number).keyboardType(.numberPad)
                LabeledChoice(title: "포지션", options: Position.allCases.map { ChoiceOption(value: $0, title: $0.title, art: .symbol($0 == .goalie ? "figure.hockey" : ($0 == .defense ? "shield.lefthalf.filled" : ($0 == .forward ? "bolt.fill" : "person")))) },
                              selection: $position, columns: 4, minHeight: 64)
                Toggle("용병", isOn: $isGuest)
            } footer: {
                Text("이름은 이 아이폰에만 저장돼요. 공유 이미지에 들어가니 본인이 괜찮아하는 이름으로 적어 주세요.")
            }
            if let member {
                Section {
                    Button("명단에서 빼기", role: .destructive) {
                        member.isActive = false
                        context.saveOrReport()
                        dismiss()
                    }
                } footer: { Text("지난 일정의 참석·라인업 기록은 그대로 남아요.") }
            }
        }
        .navigationTitle(member == nil ? "팀원 추가" : "팀원")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("저장", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .onAppear {
            guard !loaded, let member else { return }
            loaded = true
            name = member.name; number = member.number; position = member.position; isGuest = member.isGuest
        }
    }

    private func save() {
        let target = member ?? { let m = TeamMember(teamID: team.id, name: ""); context.insert(m); return m }()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.number = number.filter(\.isNumber)
        target.position = position
        target.isGuest = isGuest
        context.saveOrReport()
        dismiss()
    }
}

/// 일정 추가·수정.
struct TeamEventEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let team: Team
    let event: TeamEvent?

    @State private var at = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var minutes = 90
    @State private var kind: ActivityType = .regularGame
    @State private var rinkName = ""
    @State private var opponent = ""
    @State private var memo = ""
    @State private var loaded = false
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                LabeledChoice(title: "종류",
                              options: [ActivityType.regularGame, .miniGame, .freePractice, .lesson].map { ChoiceOption(value: $0, title: $0.title, art: .symbol($0.systemImage)) },
                              selection: $kind, columns: 4, minHeight: 64)
                DatePicker("언제", selection: $at)
                Stepper("예정 시간 \(minutesText(minutes))", value: $minutes, in: 30...240, step: 15)
            }
            Section("어디서") { RinkNameField(text: $rinkName) }
            if kind.isGame { Section("상대") { TextField("상대 팀", text: $opponent) } }
            Section("메모") { TextField("저지 색, 회비, 집합 시간…", text: $memo, axis: .vertical) }
            if event != nil {
                Section { Button("이 일정 지우기", role: .destructive) { confirmingDelete = true } }
            }
        }
        .navigationTitle(event == nil ? "일정 추가" : "일정 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
        }
        .confirmationDialog("이 일정을 지울까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("지우기", role: .destructive) {
                if let event { let ctx = context; dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { ctx.delete(event); ctx.saveOrReport() } }
            }
        }
        .onAppear {
            guard !loaded, let event else { return }
            loaded = true
            at = event.at; minutes = event.minutes; kind = event.kind; rinkName = event.rinkName; opponent = event.opponent; memo = event.memo
        }
    }

    private func save() {
        let target = event ?? { let e = TeamEvent(teamID: team.id, at: at); context.insert(e); return e }()
        target.at = at; target.minutes = minutes; target.kind = kind
        target.rinkName = rinkName.trimmingCharacters(in: .whitespaces); target.opponent = opponent.trimmingCharacters(in: .whitespaces); target.memo = memo
        if !target.rinkName.isEmpty { RinkStore.touch(name: target.rinkName, context: context) }
        context.saveOrReport()
        dismiss()
    }
}
