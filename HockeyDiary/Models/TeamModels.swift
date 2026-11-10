import Foundation
import SwiftData
import HockeyCore

// 우리 팀(아이폰 안에만 저장). 일정·명단·라인업을 적고 이미지·글로 공유한다. 서버 없음.

@Model
final class Team {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

@Model
final class TeamMember {
    var id: UUID = UUID()
    var teamID: UUID = UUID()
    var name: String = ""
    var number: String = ""
    var positionRaw: String = Position.any.rawValue
    /// 용병(정식 팀원 아님).
    var isGuest: Bool = false
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(teamID: UUID, name: String) {
        self.id = UUID()
        self.teamID = teamID
        self.name = name
        self.createdAt = Date()
    }

    var position: Position {
        get { Position(rawValue: positionRaw) ?? .any }
        set { positionRaw = newValue.rawValue }
    }

    var display: String { number.isEmpty ? name : "\(number) \(name)" }
}

@Model
final class TeamEvent {
    var id: UUID = UUID()
    var teamID: UUID = UUID()
    var at: Date = Date()
    var minutes: Int = 90
    var kindRaw: String = ActivityType.regularGame.rawValue
    var rinkName: String = ""
    var opponent: String = ""
    var memo: String = ""
    var lineupJSON: String = "{}"
    var attendanceJSON: String = "{}"
    /// 이 일정으로 만든 경기 기록.
    var sessionID: UUID?
    var createdAt: Date = Date()

    init(teamID: UUID, at: Date) {
        self.id = UUID()
        self.teamID = teamID
        self.at = at
        self.createdAt = Date()
    }

    var kind: ActivityType {
        get { ActivityType(rawValue: kindRaw) ?? .regularGame }
        set { kindRaw = newValue.rawValue }
    }

    var lineup: Lineup {
        get { Lineup.decode(lineupJSON) }
        set { lineupJSON = newValue.encode() }
    }

    var attendance: AttendanceSheet {
        get { AttendanceSheet.decode(attendanceJSON) }
        set { attendanceJSON = newValue.encode() }
    }

    var title: String { kind.title + (opponent.isEmpty ? "" : " vs \(opponent)") }
    var whenText: String { at.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute()) }
}

enum TeamStore {
    static func team(_ context: ModelContext) -> Team? {
        try? context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.createdAt)])).first
    }

    static func members(of team: Team, context: ModelContext) -> [TeamMember] {
        let all = (try? context.fetch(FetchDescriptor<TeamMember>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return all.filter { $0.teamID == team.id && $0.isActive }
    }

    static func events(of team: Team, context: ModelContext) -> [TeamEvent] {
        let all = (try? context.fetch(FetchDescriptor<TeamEvent>(sortBy: [SortDescriptor(\.at)]))) ?? []
        return all.filter { $0.teamID == team.id }
    }

    /// 일정으로 경기 기록을 만든다(상대·링크장·날짜 미리 채움). 이미 만들었으면 그 기록.
    @MainActor
    static func makeSession(for event: TeamEvent, context: ModelContext) -> Session {
        if let id = event.sessionID,
           let found = (try? context.fetch(FetchDescriptor<Session>()))?.first(where: { $0.id == id }) {
            return found
        }
        let s = Session(type: event.kind, startsAt: event.at, minutes: event.minutes)
        s.opponent = event.opponent
        s.rinkName = event.rinkName
        s.surface = event.rinkName.isEmpty ? .unknown : .indoorRink
        context.insert(s)
        event.sessionID = s.id
        context.saveOrReport()
        return s
    }
}
