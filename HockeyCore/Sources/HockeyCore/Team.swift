import Foundation

/// 포지션.
public enum Position: String, CaseIterable, Codable, Sendable {
    case forward, defense, goalie, any

    public var title: String {
        switch self {
        case .forward: return "포워드"
        case .defense: return "수비수"
        case .goalie: return "골리"
        case .any: return "아무 데나"
        }
    }

    public var short: String {
        switch self {
        case .forward: return "F"
        case .defense: return "D"
        case .goalie: return "G"
        case .any: return "-"
        }
    }
}

/// 라인업 자리. 포워드 3라인, 수비 3조, 골리 2명.
public enum LineupSlot: String, CaseIterable, Codable, Sendable {
    case lw1, c1, rw1, lw2, c2, rw2, lw3, c3, rw3
    case ld1, rd1, ld2, rd2, ld3, rd3
    case g1, g2

    public var line: Int {
        switch self {
        case .lw1, .c1, .rw1, .ld1, .rd1, .g1: return 1
        case .lw2, .c2, .rw2, .ld2, .rd2, .g2: return 2
        case .lw3, .c3, .rw3, .ld3, .rd3: return 3
        }
    }

    public var position: Position {
        switch self {
        case .lw1, .c1, .rw1, .lw2, .c2, .rw2, .lw3, .c3, .rw3: return .forward
        case .ld1, .rd1, .ld2, .rd2, .ld3, .rd3: return .defense
        case .g1, .g2: return .goalie
        }
    }

    public var short: String {
        switch self {
        case .lw1, .lw2, .lw3: return "LW"
        case .c1, .c2, .c3: return "C"
        case .rw1, .rw2, .rw3: return "RW"
        case .ld1, .ld2, .ld3: return "LD"
        case .rd1, .rd2, .rd3: return "RD"
        case .g1: return "G"
        case .g2: return "G2"
        }
    }

    public var groupTitle: String {
        switch position {
        case .forward: return "\(line)라인"
        case .defense: return "수비 \(line)조"
        default: return "골리"
        }
    }

    public static var forwardLines: [[LineupSlot]] { [[.lw1, .c1, .rw1], [.lw2, .c2, .rw2], [.lw3, .c3, .rw3]] }
    public static var defensePairs: [[LineupSlot]] { [[.ld1, .rd1], [.ld2, .rd2], [.ld3, .rd3]] }
    public static var goalies: [LineupSlot] { [.g1, .g2] }
}

/// 라인업: 자리 → 팀원 id.
public struct Lineup: Codable, Equatable, Sendable {
    public var assignments: [String: UUID]

    public init(assignments: [String: UUID] = [:]) { self.assignments = assignments }

    public subscript(slot: LineupSlot) -> UUID? {
        get { assignments[slot.rawValue] }
        set { assignments[slot.rawValue] = newValue }
    }

    /// 한 사람은 한 자리에만. 다른 자리에 있던 사람은 그 자리에서 뺀다.
    public mutating func assign(_ member: UUID?, to slot: LineupSlot) {
        if let member {
            for (k, v) in assignments where v == member { assignments[k] = nil }
        }
        assignments[slot.rawValue] = member
    }

    public var assignedMembers: Set<UUID> { Set(assignments.values) }

    public func encode() -> String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{}" }
    public static func decode(_ json: String) -> Lineup { (try? JSONDecoder().decode(Lineup.self, from: Data(json.utf8))) ?? Lineup() }

    /// 카톡에 붙여 넣는 글.
    public func text(names: [UUID: String]) -> String {
        func name(_ s: LineupSlot) -> String { self[s].flatMap { names[$0] } ?? "—" }
        var lines: [String] = []
        for (i, line) in LineupSlot.forwardLines.enumerated() where line.contains(where: { self[$0] != nil }) {
            lines.append("\(i + 1)라인  \(line.map(name).joined(separator: " · "))")
        }
        for (i, pair) in LineupSlot.defensePairs.enumerated() where pair.contains(where: { self[$0] != nil }) {
            lines.append("수비 \(i + 1)조  \(pair.map(name).joined(separator: " · "))")
        }
        let gs = LineupSlot.goalies.filter { self[$0] != nil }
        if !gs.isEmpty { lines.append("골리  \(gs.map(name).joined(separator: " · "))") }
        return lines.joined(separator: "\n")
    }
}

/// 참석 여부(팀장이 카톡 답을 보고 체크).
public enum Attendance: String, CaseIterable, Codable, Sendable {
    case going, maybe, notGoing, unknown

    public var title: String {
        switch self {
        case .going: return "참석"
        case .maybe: return "미정"
        case .notGoing: return "불참"
        case .unknown: return "답 없음"
        }
    }
}

/// 일정 하나의 참석표: 팀원 id → 참석.
public struct AttendanceSheet: Codable, Equatable, Sendable {
    public var marks: [UUID: Attendance]

    public init(marks: [UUID: Attendance] = [:]) { self.marks = marks }

    public subscript(member: UUID) -> Attendance {
        get { marks[member] ?? .unknown }
        set { marks[member] = newValue == .unknown ? nil : newValue }
    }

    public func count(_ a: Attendance, among members: [UUID]) -> Int {
        members.filter { self[$0] == a }.count
    }

    public func encode() -> String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{}" }
    public static func decode(_ json: String) -> AttendanceSheet { (try? JSONDecoder().decode(AttendanceSheet.self, from: Data(json.utf8))) ?? AttendanceSheet() }
}

/// 일정 공유 글(카톡용).
public enum TeamText {
    public static func event(teamName: String, title: String, when: String, rink: String, opponent: String,
                             memo: String, going: Int, maybe: Int, total: Int, lineup: String) -> String {
        var lines = ["[\(teamName)] \(title)", "⏰ \(when)"]
        if !rink.isEmpty { lines.append("📍 \(rink)") }
        if !opponent.isEmpty { lines.append("🆚 \(opponent)") }
        if total > 0 { lines.append("✅ 참석 \(going)명 · 미정 \(maybe)명 (\(total)명 중)") }
        if !memo.isEmpty { lines.append("📝 \(memo)") }
        if !lineup.isEmpty { lines.append(""); lines.append("라인업"); lines.append(lineup) }
        return lines.joined(separator: "\n")
    }
}
