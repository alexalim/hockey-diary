import Foundation

/// 기록 하나를 개인 최고와 견주기 위한 숫자 모음. 모르는 값은 nil.
public struct BestInput: Equatable, Sendable {
    public var type: ActivityType
    public var minutes: Int
    public var goals: Int?
    public var assists: Int?
    public var saves: Int?
    public var shots: Int?

    public init(type: ActivityType, minutes: Int, goals: Int? = nil, assists: Int? = nil, saves: Int? = nil, shots: Int? = nil) {
        self.type = type
        self.minutes = minutes
        self.goals = goals
        self.assists = assists
        self.saves = saves
        self.shots = shots
    }
}

/// 새로 세운 개인 최고. 저장 직후 완료 화면에서 배지로 보여준다.
public struct PersonalBest: Equatable, Sendable {
    public let title: String
    public let value: Int
    public let previous: Int

    /// 이번 기록이 지난 기록들보다 커진 항목만 돌려준다.
    /// 지난 기록에 그 항목이 한 번도 없으면(비교할 게 없으면) 배지를 주지 않는다. 0도 배지 없음.
    public static func check(_ current: BestInput, history: [BestInput]) -> [PersonalBest] {
        var out: [PersonalBest] = []
        func compare(_ title: String, _ value: Int?, _ past: [Int?]) {
            guard let v = value, v > 0 else { return }
            let known = past.compactMap { $0 }
            guard let best = known.max(), v > best else { return }
            out.append(PersonalBest(title: title, value: v, previous: best))
        }
        if current.type.isGame {
            let games = history.filter { $0.type.isGame }
            compare("한 경기 최다 골", current.goals, games.map(\.goals))
            compare("한 경기 최다 어시스트", current.assists, games.map(\.assists))
            compare("한 경기 최다 세이브", current.saves, games.map(\.saves))
            compare("한 경기 최다 슛", current.shots, games.map(\.shots))
        }
        let sameType = history.filter { $0.type == current.type }
        compare("가장 오래 탄 \(current.type.title)", current.minutes, sameType.map { Optional($0.minutes) })
        return out
    }
}
