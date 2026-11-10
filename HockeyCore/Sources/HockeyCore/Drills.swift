import Foundation

/// 드릴을 세는 단위.
public enum DrillUnit: String, Codable, CaseIterable, Sendable {
    case reps, minutes

    public var title: String { self == .reps ? "번" : "분" }
}

/// 연습 드릴 하나. skillName은 SkillGuide의 기술 이름과 같아서 연습량이 기술 성장에 붙는다.
public struct Drill: Equatable, Sendable, Identifiable {
    public let key: String
    public let title: String
    public let skillName: String
    public let unit: DrillUnit
    public let defaultTarget: Int
    public let howTo: String
    public let offIce: Bool

    public var id: String { key }

    public func targetText(_ n: Int? = nil) -> String {
        let v = n ?? defaultTarget
        return unit == .reps ? "\(v)번" : "\(v)분"
    }
}

/// 드릴 사전(마하다 자체 구성). 정답 횟수는 없고, 처음 해볼 만한 양만 적어둔다.
public enum DrillCatalog {
    public static let all: [Drill] = [
        // 스케이팅
        Drill(key: "crossover-circle", title: "서클 크로스오버", skillName: "크로스오버", unit: .reps, defaultTarget: 10,
              howTo: "페이스오프 서클을 따라 돌아. 한 방향 5바퀴, 반대 방향 5바퀴. 바깥 발이 안쪽 발 앞을 완전히 넘어가게.", offIce: false),
        Drill(key: "edge-slalom", title: "엣지 슬라럼", skillName: "엣지 턴", unit: .minutes, defaultTarget: 3,
              howTo: "콘이나 퍽 네다섯 개를 한 줄로 놓고 S자로 지나가. 한 발 엣지로만 돌아보고, 무릎은 계속 굽혀.", offIce: false),
        Drill(key: "stop-lines", title: "라인 스톱", skillName: "하키 스톱", unit: .reps, defaultTarget: 10,
              howTo: "블루라인에서 출발해 레드라인에서 멈춰. 멈추는 쪽을 왼쪽·오른쪽 번갈아. 얼음이 긁히는 소리가 나야 해.", offIce: false),
        Drill(key: "backward-c", title: "백워드 C컷 왕복", skillName: "백워드 스케이팅", unit: .reps, defaultTarget: 6,
              howTo: "골라인에서 블루라인까지 뒤로 타. 발로 C자를 그리며 밀고, 고개는 들어서 앞을 봐.", offIce: false),
        Drill(key: "pivot-line", title: "피벗 왕복", skillName: "피벗", unit: .reps, defaultTarget: 6,
              howTo: "앞으로 타다가 레드라인에서 뒤로 돌아서고, 블루라인에서 다시 앞으로. 속도를 잃지 않는 게 목표야.", offIce: false),
        // 퍽 컨트롤
        Drill(key: "stickhandle-8", title: "8자 드리블", skillName: "퍽 드리블", unit: .minutes, defaultTarget: 2,
              howTo: "퍽 두 개를 한 스틱 거리로 놓고 그 사이로 8자를 그려. 고개를 들고 퍽은 손 느낌으로.", offIce: false),
        Drill(key: "stickhandle-wide", title: "넓게·좁게 드리블", skillName: "퍽 드리블", unit: .minutes, defaultTarget: 2,
              howTo: "제자리에서 퍽을 최대한 넓게 10번, 좁고 빠르게 10번. 번갈아 반복해.", offIce: false),
        Drill(key: "wall-pass-fh", title: "포핸드 벽 패스", skillName: "포핸드 패스", unit: .reps, defaultTarget: 50,
              howTo: "보드에 패스하고 돌아오는 퍽을 받아. 받을 때 블레이드를 살짝 눕혀 퍽이 튀지 않게.", offIce: false),
        Drill(key: "wall-pass-bh", title: "백핸드 벽 패스", skillName: "백핸드 패스", unit: .reps, defaultTarget: 30,
              howTo: "같은 벽 패스를 백핸드로. 처음엔 가까이서, 익숙해지면 조금씩 멀리.", offIce: false),
        // 슈팅
        Drill(key: "wrist-target", title: "리스트 샷 네 모서리", skillName: "리스트 샷", unit: .reps, defaultTarget: 25,
              howTo: "골대 네 모서리를 차례로 노려. 들어갔는지보다 노린 곳에 갔는지를 봐.", offIce: false),
        Drill(key: "snap-quick", title: "받자마자 스냅 샷", skillName: "스냅 샷", unit: .reps, defaultTarget: 20,
              howTo: "벽이나 친구에게 패스 받자마자 멈추지 말고 바로 쏴. 준비 동작을 줄이는 연습이야.", offIce: false),
        Drill(key: "slap-form", title: "슬랩 샷 폼", skillName: "슬랩 샷", unit: .reps, defaultTarget: 15,
              howTo: "세게 치기보다 퍽 바로 뒤 얼음을 먼저 치는 감각에 집중해. 스틱이 휘었다 펴지는 느낌을 찾아.", offIce: false),
        // 게임 운영
        Drill(key: "faceoff-reps", title: "페이스오프 드롭", skillName: "페이스오프", unit: .reps, defaultTarget: 15,
              howTo: "친구가 퍽을 떨어뜨려 주면 뒤로 빼 오기. 스틱을 먼저 얼음에 대고, 떨어지는 순간만 봐.", offIce: false),
        // 오프아이스(집·공원)
        Drill(key: "office-ball", title: "스틱핸들링 볼 (집)", skillName: "퍽 드리블", unit: .minutes, defaultTarget: 5,
              howTo: "바닥에서 스틱핸들링 볼로 앞·옆·8자. TV 보면서 해도 돼. 고개 들기가 핵심.", offIce: true),
        Drill(key: "office-shoot", title: "슈팅 패드 슛 (집)", skillName: "리스트 샷", unit: .reps, defaultTarget: 30,
              howTo: "슈팅 패드 위에서 리스트 샷. 손목을 감아 올리는 마지막 동작에 집중해. 이웃을 생각해서 타깃에 담요를.", offIce: true),
        Drill(key: "office-balance", title: "한 발 균형 (집)", skillName: "엣지 턴", unit: .minutes, defaultTarget: 3,
              howTo: "한 발로 서서 무릎을 굽히고 30초. 발 바꿔서 30초. 엣지 턴에 필요한 발목 힘이 늘어.", offIce: true),
    ]

    public static func drill(_ key: String) -> Drill? { all.first { $0.key == key } }

    public static var onIce: [Drill] { all.filter { !$0.offIce } }
    public static var offIce: [Drill] { all.filter(\.offIce) }
}

/// 루틴 안의 드릴 하나와 목표량.
public struct RoutineItem: Codable, Equatable, Sendable {
    public var drillKey: String
    public var target: Int

    public init(drillKey: String, target: Int) {
        self.drillKey = drillKey
        self.target = max(1, target)
    }

    public static func encode(_ items: [RoutineItem]) -> String {
        (try? String(data: JSONEncoder().encode(items), encoding: .utf8)) ?? "[]"
    }

    public static func decode(_ json: String) -> [RoutineItem] {
        (try? JSONDecoder().decode([RoutineItem].self, from: Data(json.utf8))) ?? []
    }
}

/// 처음 쓰라고 넣어둔 루틴.
public struct StarterRoutine: Sendable {
    public let name: String
    public let items: [RoutineItem]

    public static let all: [StarterRoutine] = [
        StarterRoutine(name: "링크 가기 전 10분 (집에서)", items: [
            RoutineItem(drillKey: "office-ball", target: 5),
            RoutineItem(drillKey: "office-balance", target: 3),
            RoutineItem(drillKey: "office-shoot", target: 20),
        ]),
        StarterRoutine(name: "자유 연습 30분", items: [
            RoutineItem(drillKey: "stop-lines", target: 10),
            RoutineItem(drillKey: "crossover-circle", target: 10),
            RoutineItem(drillKey: "stickhandle-8", target: 3),
            RoutineItem(drillKey: "wall-pass-fh", target: 50),
            RoutineItem(drillKey: "wrist-target", target: 25),
        ]),
    ]

    /// 루틴에 걸리는 시간(분). 횟수 드릴은 1번당 약 6초로 어림한다.
    public static func estimatedMinutes(_ items: [RoutineItem]) -> Int {
        items.reduce(0) { sum, it in
            guard let d = DrillCatalog.drill(it.drillKey) else { return sum }
            return sum + (d.unit == .minutes ? it.target : max(1, Int((Double(it.target) * 6 / 60).rounded(.up))))
        }
    }
}

/// 연습 기록 통계.
public enum DrillStats {
    public struct Entry: Sendable {
        public let skillName: String
        public let at: Date
        public let amount: Int
        public let unit: DrillUnit
        public init(skillName: String, at: Date, amount: Int, unit: DrillUnit) {
            self.skillName = skillName; self.at = at; self.amount = amount; self.unit = unit
        }
    }

    public struct SkillLine: Equatable, Sendable {
        public var sessions: Int = 0
        public var reps: Int = 0
        public var minutes: Int = 0

        public var text: String {
            var parts: [String] = []
            if minutes > 0 { parts.append("\(minutes)분") }
            if reps > 0 { parts.append("\(reps)번") }
            return parts.isEmpty ? "\(sessions)회" : "\(sessions)회 · " + parts.joined(separator: " · ")
        }
    }

    /// 기술별 연습 횟수·양.
    public static func bySkill(_ entries: [Entry]) -> [String: SkillLine] {
        var out: [String: SkillLine] = [:]
        for e in entries {
            out[e.skillName, default: SkillLine()].sessions += 1
            if e.unit == .reps { out[e.skillName, default: SkillLine()].reps += e.amount }
            else { out[e.skillName, default: SkillLine()].minutes += e.amount }
        }
        return out
    }

    /// 날짜 기준 연습한 날 수(같은 날 여러 드릴은 하루).
    public static func practiceDays(_ entries: [Entry], calendar: Calendar = .current) -> Int {
        Set(entries.map { calendar.startOfDay(for: $0.at) }).count
    }
}
