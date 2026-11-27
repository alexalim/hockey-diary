import Foundation

/// 코치·감독용 도구: 명단 붙여 넣기, 매주 반복 일정, 지난 라인업 이어 쓰기.
public enum CoachTools {
    /// 붙여 넣은 명단 한 줄.
    public struct RosterLine: Equatable, Sendable {
        public var name: String
        public var number: String
        public var position: Position
    }

    /// 단톡방 명단을 그대로 붙여 넣으면 한 줄에 한 명씩 읽는다.
    /// "9 민수", "#17 지훈 D", "골리킴 30 (G)", "민수, 지훈" 같은 모양을 받는다. 번호·포지션은 있으면 읽고 없으면 비운다.
    public static func parseRoster(_ text: String) -> [RosterLine] {
        let rows = text
            .replacingOccurrences(of: ",", with: "\n")
            .replacingOccurrences(of: "/", with: "\n")
            .split(whereSeparator: \.isNewline)
        var seen = Set<String>()
        var out: [RosterLine] = []
        for row in rows {
            // 줄 맨 앞의 순번("1." "2)")은 등번호가 아니다. 먼저 뗀다.
            let raw = row.replacingOccurrences(of: #"^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
            var tokens = raw
                .replacingOccurrences(of: "(", with: " ").replacingOccurrences(of: ")", with: " ")
                .replacingOccurrences(of: "[", with: " ").replacingOccurrences(of: "]", with: " ")
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
                .map(String.init)
            // 번호와 포지션을 떼어 내고 남은 것이 이름.
            var number = ""
            var position = Position.any
            tokens.removeAll { t in
                let digits = t.hasPrefix("#") ? String(t.dropFirst()) : t
                if !digits.isEmpty, digits.allSatisfy(\.isNumber), digits.count <= 3 {
                    if number.isEmpty { number = digits }
                    return true
                }
                if let p = positionWord(t) { position = p; return true }
                return false
            }
            let name = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            out.append(RosterLine(name: name, number: number, position: position))
        }
        return out
    }

    private static func positionWord(_ token: String) -> Position? {
        switch token.uppercased() {
        case "G", "GK", "골리", "골키퍼": return .goalie
        case "D", "DF", "수비", "수비수": return .defense
        case "F", "FW", "C", "LW", "RW", "W", "공격", "포워드", "센터", "윙": return .forward
        default: return nil
        }
    }

    /// 매주 반복: 처음 일정 포함 `weeks`번, 7일 간격. 1이면 그 날 하나.
    public static func weeklyDates(from start: Date, weeks: Int, calendar: Calendar = .current) -> [Date] {
        (0..<max(1, weeks)).compactMap { calendar.date(byAdding: .day, value: 7 * $0, to: start) }
    }

    /// 지난 라인업을 이번 경기로 가져온다. 이번에 불참이라고 한 사람과 명단에서 빠진 사람은 비운다.
    public static func carryOver(_ lineup: Lineup, attendance: AttendanceSheet, activeMembers: Set<UUID>) -> Lineup {
        var out = lineup
        for (slot, member) in lineup.assignments where !activeMembers.contains(member) || attendance[member] == .notGoing {
            out.assignments[slot] = nil
        }
        return out
    }
}
