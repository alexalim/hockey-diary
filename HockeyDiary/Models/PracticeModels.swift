import Foundation
import SwiftData
import HockeyCore

// 연습 드릴 기록과 루틴. 새 모델만 추가한다(기존 저장 구조는 그대로).

/// 드릴 한 번 한 기록.
@Model
final class DrillLog {
    var id: UUID = UUID()
    /// DrillCatalog 키. 직접 만든 드릴은 "custom".
    var drillKey: String = ""
    var title: String = ""
    /// 이어지는 기술 이름(SkillGuide 이름). 직접 만든 드릴은 비울 수 있다.
    var skillName: String = ""
    var unitRaw: String = DrillUnit.reps.rawValue
    var amount: Int = 0
    var at: Date = Date()
    var note: String = ""
    var offIce: Bool = false

    init(drill: Drill, amount: Int, at: Date = Date()) {
        self.id = UUID()
        self.drillKey = drill.key
        self.title = drill.title
        self.skillName = drill.skillName
        self.unitRaw = drill.unit.rawValue
        self.amount = amount
        self.at = at
        self.offIce = drill.offIce
    }

    init(customTitle: String, skillName: String, unit: DrillUnit, amount: Int, at: Date = Date()) {
        self.id = UUID()
        self.drillKey = "custom"
        self.title = customTitle
        self.skillName = skillName
        self.unitRaw = unit.rawValue
        self.amount = amount
        self.at = at
    }

    var unit: DrillUnit { DrillUnit(rawValue: unitRaw) ?? .reps }
    var amountText: String { "\(amount)\(unit.title)" }

    var entry: DrillStats.Entry? {
        guard !skillName.isEmpty else { return nil }
        return DrillStats.Entry(skillName: skillName, at: at, amount: amount, unit: unit)
    }
}

/// 내가 만든 루틴(드릴 순서와 목표량).
@Model
final class PracticeRoutine {
    var id: UUID = UUID()
    var name: String = ""
    var itemsJSON: String = "[]"
    var createdAt: Date = Date()
    var lastUsedAt: Date?

    init(name: String, items: [RoutineItem]) {
        self.id = UUID()
        self.name = name
        self.itemsJSON = RoutineItem.encode(items)
        self.createdAt = Date()
    }

    var items: [RoutineItem] {
        get { RoutineItem.decode(itemsJSON) }
        set { itemsJSON = RoutineItem.encode(newValue) }
    }
}

enum PracticeStore {
    static func logs(from: Date?, to: Date, context: ModelContext) -> [DrillLog] {
        let all = (try? context.fetch(FetchDescriptor<DrillLog>(sortBy: [SortDescriptor(\.at, order: .reverse)]))) ?? []
        return all.filter { (from == nil || $0.at >= from!) && $0.at <= to }
    }

    /// 기술별 연습량(기간 안).
    static func bySkill(from: Date?, to: Date, context: ModelContext) -> [String: DrillStats.SkillLine] {
        DrillStats.bySkill(logs(from: from, to: to, context: context).compactMap(\.entry))
    }

    /// 템플릿을 내 루틴으로 복사한다. 같은 이름이 이미 있으면 만들지 않고 그 루틴을 돌려준다.
    @discardableResult
    static func importTemplate(_ template: StarterRoutine, context: ModelContext) -> PracticeRoutine {
        let mine = (try? context.fetch(FetchDescriptor<PracticeRoutine>())) ?? []
        // 예전 이름(분 수가 붙어 있던 때)으로 이미 가져온 루틴도 같은 것으로 본다. 두 번 생기지 않게.
        let legacy = ["자유 연습 기본": "자유 연습 30분", "스케이팅 기본기": "스케이팅 기본기 20분"][template.name]
        if let same = mine.first(where: { $0.name == template.name || $0.name == legacy }) { return same }
        let r = PracticeRoutine(name: template.name, items: template.items)
        context.insert(r)
        context.saveOrReport()
        return r
    }

    /// 처음 한 번, 기본 루틴 두 개를 내 루틴으로 넣어준다.
    static func seedRoutinesIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<PracticeRoutine>())) ?? 0
        guard count == 0, !UserDefaults.standard.bool(forKey: "routinesSeeded") else { return }
        for r in StarterRoutine.all { context.insert(PracticeRoutine(name: r.name, items: r.items)) }
        UserDefaults.standard.set(true, forKey: "routinesSeeded")
        context.saveOrReport()
    }
}
