import Foundation

/// AI 요약에 넘길 사실 목록. 사용자가 고른 기간의 하키 기록만 담는다.
/// 하루 일기·기분 메모·건강(수면·심박·생리)은 입력 타입에 없어서 넘길 수 없다 (11.2).
public enum SummaryFacts {
    public struct SessionFact: Sendable {
        public let at: Date
        public let type: ActivityType
        public let minutes: Int
        public let learned: [String]
        public let tried: [(skill: String, outcome: AttemptOutcome?)]
        public let untried: [String]
        public let notes: String

        public init(at: Date, type: ActivityType, minutes: Int, learned: [String],
                    tried: [(skill: String, outcome: AttemptOutcome?)], untried: [String], notes: String) {
            self.at = at; self.type = type; self.minutes = minutes; self.learned = learned
            self.tried = tried; self.untried = untried; self.notes = notes
        }
    }

    /// 모델 입력 길이를 줄이려고 최근 maxSessions개, 메모는 각 120자까지.
    public static func text(periodTitle: String, sessions: [SessionFact], includeNotes: Bool, maxSessions: Int = 20) -> String {
        let recent = sessions.sorted { $0.at > $1.at }.prefix(maxSessions).sorted { $0.at < $1.at }
        let f = Date.FormatStyle(date: .abbreviated, time: .omitted)
        var lines = ["기간: \(periodTitle)", "활동 \(sessions.count)회, 총 \(sessions.reduce(0) { $0 + $1.minutes })분"]
        for s in recent {
            var parts = ["\(s.at.formatted(f)) \(s.type.title) \(s.minutes)분"]
            if !s.learned.isEmpty { parts.append("배운 기술: \(s.learned.joined(separator: ", "))") }
            if !s.tried.isEmpty {
                parts.append("써본 기술: " + s.tried.map { "\($0.skill)(\($0.outcome?.title ?? "결과 미입력"))" }.joined(separator: ", "))
            }
            if !s.untried.isEmpty { parts.append("기회가 없어 못 써본 기술: \(s.untried.joined(separator: ", "))") }
            let note = s.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if includeNotes && !note.isEmpty { parts.append("메모: \(String(note.prefix(120)))") }
            lines.append("- " + parts.joined(separator: " / "))
        }
        return lines.joined(separator: "\n")
    }

    /// 모델 지시문. 사실만, 친구에게 말하는 반말, 기호 없이, 인과·예측·의료 조언 금지.
    public static let instructions = """
    너는 아이스하키 다이어리 앱 '마하다'의 회고 도우미다. 아래 사실만 근거로 3~4문장으로 돌아본다.
    친구에게 말하듯 반말로 쓴다. 문장 끝은 "~했어", "~야", "~해봐"처럼 쓰고, "~했다", "~이다"는 쓰지 않는다.
    문장은 짧게 끊는다. 별표(**), 샵(#), 하이픈 목록 같은 기호는 쓰지 않는다.
    잘한 점 하나와 다음에 연습해 볼 기술 하나를 짚는다. 숫자는 사실에 있는 것만 쓴다.
    못 써본 기술은 실패가 아니라 기회가 없었던 것으로 다룬다.
    원인을 단정하지 말고, 경기력을 예측하거나 몸 상태·의료에 대한 조언을 하지 않는다.
    예: "이번 달엔 수업 3번에 경기 1번 탔어. 크로스오버를 경기에서 써본 게 좋았어. 다음엔 하키 스톱을 더 연습해봐."
    """

    /// 모델이 기호를 섞어 내도 화면에는 깨끗한 문장만 보이게 한다.
    public static func clean(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        t = t.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            while l.hasPrefix("#") { l.removeFirst() }
            if l.hasPrefix("- ") || l.hasPrefix("* ") || l.hasPrefix("• ") { l.removeFirst(2) }
            return l.trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\n")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
