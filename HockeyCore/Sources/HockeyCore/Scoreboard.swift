import Foundation

/// 경기 중 벤치에서 쓰는 점수판. 끝내면 경기 리뷰 칸(점수·내 골·어시)을 채운다.
/// 앱이 꺼져도 이어지게 통째로 저장할 수 있다(Codable).
public struct Scoreboard: Codable, Hashable, Sendable {
    public enum Side: String, Codable, Sendable { case us, them }
    /// 우리 골이면 누가 넣었는지. 묻고 답 안 하면 other.
    public enum Credit: String, Codable, Sendable { case myGoal, myAssist, other }

    public struct Goal: Codable, Hashable, Sendable {
        public var side: Side
        public var period: Int
        public var at: Date
        public var credit: Credit
    }

    public var teamName: String
    public var opponent: String
    public var startedAt: Date
    /// 1·2·3, 4는 연장.
    public private(set) var period: Int = 1
    public private(set) var goals: [Goal] = []
    /// 팀 일정에서 열었으면 그 일정. 끝낼 때 기록과 잇는다.
    public var eventID: UUID?
    /// 정규게임·미니게임. 끝내면 이 종류로 경기 리뷰를 연다.
    public var kind: ActivityType = .regularGame

    public static let lastPeriod = 4

    public init(teamName: String, opponent: String, startedAt: Date, eventID: UUID? = nil, kind: ActivityType = .regularGame) {
        self.teamName = teamName
        self.opponent = opponent
        self.startedAt = startedAt
        self.eventID = eventID
        self.kind = kind.isGame ? kind : .regularGame
    }

    public var us: Int { goals.filter { $0.side == .us }.count }
    public var them: Int { goals.filter { $0.side == .them }.count }
    public var myGoals: Int { goals.filter { $0.credit == .myGoal }.count }
    public var myAssists: Int { goals.filter { $0.credit == .myAssist }.count }

    public static func periodTitle(_ p: Int) -> String { p >= lastPeriod ? "연장" : "\(p)P" }
    public var periodTitle: String { Self.periodTitle(period) }

    public mutating func score(_ side: Side, at: Date, credit: Credit = .other) {
        goals.append(Goal(side: side, period: period, at: at, credit: side == .them ? .other : credit))
    }

    /// 방금 넣은 우리 골에 누가 넣었는지 붙인다(골 다음에 묻는다).
    public mutating func creditLastGoal(_ credit: Credit) {
        guard let i = goals.lastIndex(where: { $0.side == .us }) else { return }
        goals[i].credit = credit
    }

    /// 잘못 누른 것 되돌리기: 그 편의 가장 최근 골을 뺀다. 없으면 그대로.
    public mutating func undo(_ side: Side) {
        guard let i = goals.lastIndex(where: { $0.side == side }) else { return }
        goals.remove(at: i)
    }

    public mutating func setPeriod(_ p: Int) { period = min(max(p, 1), Self.lastPeriod) }

    /// 경기 리뷰에 넣을 시간(분). 시작부터 끝낸 때까지, 최소 1분.
    public func minutes(until end: Date) -> Int { max(1, Int((end.timeIntervalSince(startedAt) / 60).rounded())) }

    /// 잠금 화면·공유용 한 줄. "펭귄스 3 : 2 베어스 · 2P"
    public var line: String {
        "\(teamName.isEmpty ? "우리" : teamName) \(us) : \(them) \(opponent.isEmpty ? "상대" : opponent) · \(periodTitle)"
    }
}
