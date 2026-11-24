import Foundation

/// '뭐할까' 탭: 지금 하면 좋은 것을 기록에서 골라 순서대로 내놓는다.
/// 규칙은 전부 여기 있고 화면은 보여 주기만 한다. 같은 사실이면 언제나 같은 답이 나온다.
public enum WhatNow {
    public enum Kind: String, Sendable {
        case rest, logEvent, prepareEvent, bodyCheck, quest, drill, routine, goal, sharpen, journal, firstIce
    }

    public struct Suggestion: Equatable, Identifiable, Sendable {
        public let kind: Kind
        public let title: String
        public let detail: String
        /// 버튼 글. 비어 있으면 버튼 없이 카드 안에서 바로 한다(몸 상태처럼).
        public let action: String
        /// 보조 값: 드릴 키, 퀘스트 종류, 일정 제목.
        public let key: String
        public var id: String { kind.rawValue + ":" + key }

        public init(kind: Kind, title: String, detail: String, action: String, key: String = "") {
            self.kind = kind; self.title = title; self.detail = detail; self.action = action; self.key = key
        }
    }

    public struct DrillFact: Equatable, Sendable {
        public var skillName: String
        public var at: Date
        public init(skillName: String, at: Date) { self.skillName = skillName; self.at = at }
    }

    /// 내 루틴 하나(이름과 걸리는 시간).
    public struct RoutineFact: Equatable, Sendable {
        public var name: String
        public var minutes: Int
        public init(name: String, minutes: Int) { self.name = name; self.minutes = minutes }
    }

    public struct Facts: Sendable {
        public var now: Date
        public var resting: Bool
        public var events: [HomePrompt.Event]
        /// 몸 상태 기능이 켜져 있고 오늘 아직 안 남겼는지 따로 본다.
        public var conditionOn: Bool
        public var bodyCheckedToday: Bool
        public var journaledToday: Bool
        public var quests: [QuestProgress]
        public var drills: [DrillFact]
        public var lastGoal: String?
        public var lastSessionAt: Date?
        public var sharpenDue: Bool
        public var hasTeam: Bool
        /// 오늘 남긴 몸 상태(1 처짐 ~ 5 최고). 안 남겼으면 nil.
        public var bodyToday: Int? = nil
        /// 지금 쓸 수 있는 시간(분). 고르지 않았으면 nil.
        public var minutesFree: Int? = nil
        public var routines: [RoutineFact] = []

        public init(now: Date, resting: Bool = false, events: [HomePrompt.Event] = [], conditionOn: Bool = true,
                    bodyCheckedToday: Bool = false, journaledToday: Bool = false, quests: [QuestProgress] = [],
                    drills: [DrillFact] = [], lastGoal: String? = nil, lastSessionAt: Date? = nil,
                    sharpenDue: Bool = false, hasTeam: Bool = false) {
            self.now = now; self.resting = resting; self.events = events; self.conditionOn = conditionOn
            self.bodyCheckedToday = bodyCheckedToday; self.journaledToday = journaledToday; self.quests = quests
            self.drills = drills; self.lastGoal = lastGoal; self.lastSessionAt = lastSessionAt
            self.sharpenDue = sharpenDue; self.hasTeam = hasTeam
        }
    }

    /// 한 화면에 보여 줄 최대 개수. 많으면 고르기가 일이 된다.
    public static let maxCount = 5
    /// 드릴을 고를 때 돌아보는 기간.
    public static let drillWindowDays = 14
    /// 이만큼 빙판을 안 탔으면 '첫 빙판' 카드를 낸다.
    public static let idleDays = 7

    public static func suggest(_ f: Facts, calendar: Calendar = .current) -> [Suggestion] {
        if f.resting {
            return [Suggestion(kind: .rest, title: "쉬는 중이에요", detail: "연속 기록과 목표는 멈춰 있어요. 돌아오면 이어서 세요.", action: "다시 탈래요")]
        }
        var out: [Suggestion] = []
        let hour = calendar.component(.hour, from: f.now)
        let today = calendar.startOfDay(for: f.now)

        // 1. 방금 끝난 팀 일정인데 기록이 없다.
        let todays = f.events.filter { calendar.isDate($0.start, inSameDayAs: f.now) }
        if let e = todays.filter({ !$0.logged }).first(where: {
            let end = $0.start.addingTimeInterval(Double($0.minutes) * 60)
            return end <= f.now && f.now.timeIntervalSince(end) <= 6 * 3600
        }) {
            out.append(Suggestion(kind: .logEvent, title: "\(e.title) 끝났죠? 바로 남겨요",
                                  detail: "시간과 장소는 팀 일정에서 가져와 미리 채워져요.", action: "기록하기", key: e.title))
        }

        // 2. 오늘 뒤에 있거나 사흘 안에 오는 일정.
        if let e = todays.filter({ $0.start > f.now }).min(by: { $0.start < $1.start }) {
            out.append(Suggestion(kind: .prepareEvent, title: "오늘 \(timeText(e.start, calendar)) \(e.title)",
                                  detail: "몸 상태 한 번 보고, 지난번 목표를 떠올려요.", action: "팀 일정 보기", key: e.title))
        } else if let e = f.events.filter({ $0.start > f.now && !calendar.isDate($0.start, inSameDayAs: f.now) })
            .min(by: { $0.start < $1.start }),
            let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: e.start)).day, days <= 3 {
            out.append(Suggestion(kind: .prepareEvent, title: "D-\(days) \(e.title)",
                                  detail: "전술 한 번 보고 장비도 점검해 둬요.", action: "팀 일정 보기", key: e.title))
        }

        // 3. 오늘 몸 상태.
        if f.conditionOn && !f.bodyCheckedToday {
            out.append(Suggestion(kind: .bodyCheck, title: "오늘 몸 상태 남기기",
                                  detail: "1초면 돼요. 쌓이면 경기 전 컨디션이 보여요.", action: ""))
        }

        // 4. 드릴 하나(이번 주 드릴 퀘스트도 이걸로 채운다).
        let drill = pickDrill(f.drills, now: f.now, calendar: calendar)
        let drillDetail: String
        if f.drills.isEmpty {
            drillDetail = "처음이라 집에서 할 수 있는 걸로 골랐어요. \(drill.targetText())부터요."
        } else if isNight(hour) {
            drillDetail = "늦은 시간이라 집에서 하는 걸로요. \(drill.targetText())."
        } else {
            drillDetail = "최근 \(drillWindowDays)일 \(drill.skillName) 연습이 제일 적었어요. \(drill.targetText())."
        }
        var drillCard = Suggestion(kind: .drill, title: "드릴 하나: \(drill.title)", detail: drillDetail, action: "지금 시작", key: drill.key)
        if let body = f.bodyToday, body <= lowBody, let light = DrillCatalog.drill(lightDrillKey) {
            // 몸이 무거운 날: 가장 가벼운 집 드릴 하나만. 쉬어도 된다고 먼저 말한다.
            drillCard = Suggestion(kind: .drill, title: "오늘은 가볍게: \(light.title)",
                                   detail: "몸이 무거운 날이에요. 쉬어도 돼요. 하고 싶으면 \(light.targetText())만요.", action: "지금 시작", key: light.key)
        } else if let free = f.minutesFree {
            if let r = f.routines.filter({ $0.minutes > 0 && $0.minutes <= free }).max(by: { $0.minutes < $1.minutes }), free >= routineMinMinutes {
                drillCard = Suggestion(kind: .routine, title: "루틴: \(r.name)",
                                       detail: "\(free)분이면 이 루틴이 딱 맞아요. 약 \(r.minutes)분 걸려요.", action: "지금 시작", key: r.name)
            } else {
                let fit = fits(drill, in: free) ? drill : (DrillCatalog.all.first { $0.offIce == drill.offIce && fits($0, in: free) } ?? drill)
                drillCard = Suggestion(kind: .drill, title: "드릴 하나: \(fit.title)",
                                       detail: "\(free)분 안에 끝나요. \(fit.targetText()).", action: "지금 시작", key: fit.key)
            }
        }

        // 5. 이번 주 퀘스트 중 가장 가까운 것. 다른 카드가 이미 덮는 종류는 뺀다.
        var covered: Set<QuestKind> = [.drills]
        if out.contains(where: { $0.kind == .bodyCheck }) { covered.insert(.conditions) }
        let journalCard = hour >= 20 && !f.journaledToday
        if journalCard { covered.insert(.journals) }
        if let q = f.quests.filter({ !$0.isDone && !covered.contains($0.quest.kind) })
            .min(by: { ($0.quest.target - $0.done) < ($1.quest.target - $1.done) }) {
            let left = q.quest.target - q.done
            out.append(Suggestion(kind: .quest, title: "이번 주 퀘스트: \(q.quest.title)",
                                  detail: "\(q.done)/\(q.quest.target)\(q.quest.unit) 했어요. \(left)\(q.quest.unit) 남았어요.",
                                  action: questAction(q.quest.kind), key: q.quest.kind.rawValue))
        }
        out.append(drillCard)

        // 6. 지난 수업의 다음 목표.
        if let g = f.lastGoal?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty {
            out.append(Suggestion(kind: .goal, title: "지난 목표 이어서", detail: g, action: "훈련 보기"))
        }

        // 7. 연마.
        if f.sharpenDue {
            out.append(Suggestion(kind: .sharpen, title: "연마 점검해 볼까요?",
                                  detail: "정해 둔 만큼 탔어요. 엣지가 밀리지 않으면 더 타도 돼요.", action: "락커 보기"))
        }

        // 8. 저녁 일기.
        if journalCard {
            out.append(Suggestion(kind: .journal, title: "오늘 어땠어요?", detail: "한 줄이면 돼요. 내일의 나한테 남기는 거예요.", action: "일기 쓰기"))
        }

        // 9. 빙판을 오래 안 탔다.
        let idle: Bool
        if let last = f.lastSessionAt {
            idle = (calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0) >= idleDays
        } else {
            idle = true
        }
        if idle {
            out.append(Suggestion(kind: .firstIce, title: "다음 빙판은 언제예요?",
                                  detail: f.hasTeam ? "팀 일정을 넣어 두면 전날 알려 드려요." : "링크장 자유 타기 시간이라도 하나 잡아 봐요.",
                                  action: f.hasTeam ? "팀 일정 넣기" : "링크장 찾기"))
        }

        return Array(out.prefix(maxCount))
    }

    /// 최근 2주 안에 가장 덜 한 기술의 드릴. 기록이 없으면 집에서 하는 첫 드릴, 밤이면 집 드릴만 고른다.
    public static func pickDrill(_ drills: [DrillFact], now: Date, calendar: Calendar = .current) -> Drill {
        let night = isNight(calendar.component(.hour, from: now))
        guard !drills.isEmpty, let first = DrillCatalog.offIce.first else {
            return DrillCatalog.offIce.first ?? DrillCatalog.all[0]
        }
        let pool = night ? DrillCatalog.offIce : DrillCatalog.onIce
        let since = calendar.date(byAdding: .day, value: -drillWindowDays, to: now) ?? now
        var counts: [String: Int] = [:]
        for d in drills where d.at >= since { counts[d.skillName, default: 0] += 1 }
        let skills = pool.map(\.skillName)
        let least = skills.min { (counts[$0] ?? 0, skills.firstIndex(of: $0) ?? 0) < (counts[$1] ?? 0, skills.firstIndex(of: $1) ?? 0) }
        return pool.first { $0.skillName == least } ?? first
    }

    static func isNight(_ hour: Int) -> Bool { hour >= 21 || hour < 6 }

    /// 몸 상태가 이 값 이하면 '가볍게' 카드를 낸다(1 처짐, 2 약간).
    public static let lowBody = 2
    static let lightDrillKey = "office-balance"
    /// 이만큼은 시간이 있어야 루틴을 권한다. 그보다 짧으면 드릴 하나.
    public static let routineMinMinutes = 10

    static func fits(_ d: Drill, in minutes: Int) -> Bool {
        StarterRoutine.estimatedMinutes([RoutineItem(drillKey: d.key, target: d.defaultTarget)]) <= minutes
    }

    static func questAction(_ k: QuestKind) -> String {
        switch k {
        case .sessions: return "기록하기"
        case .drills: return "드릴 시작"
        case .conditions: return "몸 상태 남기기"
        case .journals: return "일기 쓰기"
        case .minutes: return "훈련 보기"
        }
    }

    static func timeText(_ d: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
