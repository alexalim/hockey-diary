import Foundation
import SwiftData
import HockeyCore

/// 저장·조회 도우미. 화면은 여기를 거쳐 저장한다.
enum DiaryStore {
    /// 기본 기술 사전. 처음 실행할 때 한 번만 넣는다.
    static let defaultSkills: [(String, String)] = [
        ("크로스오버", "스케이팅"), ("엣지 턴", "스케이팅"), ("하키 스톱", "스케이팅"),
        ("백워드 스케이팅", "스케이팅"), ("피벗", "스케이팅"),
        ("포핸드 패스", "퍽 컨트롤"), ("백핸드 패스", "퍽 컨트롤"), ("퍽 드리블", "퍽 컨트롤"),
        ("리스트 샷", "슈팅"), ("스냅 샷", "슈팅"), ("슬랩 샷", "슈팅"),
        ("포지셔닝", "게임 운영"), ("페이스오프", "게임 운영"),
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Skill>())) ?? 0
        guard count == 0 else { return }
        for (name, category) in defaultSkills {
            context.insert(Skill(name: name, category: category))
        }
        context.saveOrReport()
    }

    // MARK: - 장비

    /// 활동에 쓴 장비를 연결한다. 활동 1건에 사용 기록 1개만 둔다 (FR-16).
    static func setUsage(for session: Session, skate: Skate?, runner: RunnerSet?, iceMinutes: Int, context: ModelContext) {
        if skate == nil && runner == nil {
            for u in session.usages { context.delete(u) }
            session.usages = []
            return
        }
        if let existing = session.usages.first {
            existing.skateID = skate?.id
            existing.runnerID = runner?.id
            existing.iceMinutes = max(0, iceMinutes)
            for extra in session.usages.dropFirst() { context.delete(extra) }
        } else {
            let usage = EquipmentUsage(skateID: skate?.id, runnerID: runner?.id, iceMinutes: max(0, iceMinutes))
            context.insert(usage)
            usage.session = session
        }
    }

    static func usageRecords(_ context: ModelContext) -> [UsageRecord] {
        let all = (try? context.fetch(FetchDescriptor<EquipmentUsage>())) ?? []
        return all.compactMap(\.record)
    }

    static func minutesSinceSharpening(_ runner: RunnerSet, context: ModelContext) -> Int {
        EquipmentMath.iceMinutesSinceSharpening(runnerID: runner.id, usages: usageRecords(context),
                                                lastSharpenedAt: runner.lastSharpening?.at)
    }

    /// 러너를 부츠에 단다. 같은 러너가 다른 부츠에 달려 있으면 먼저 떼고, 부츠에 있던 러너도 뗀다 (T14).
    @discardableResult
    static func install(_ runner: RunnerSet, on skate: Skate, at date: Date = Date(), context: ModelContext) -> InstallError? {
        let all = (try? context.fetch(FetchDescriptor<RunnerInstallation>())) ?? []
        let pairs = all.compactMap { inst in inst.span.map { (inst, $0) } }
        let spans = pairs.map(\.1)
        switch RunnerInstallation.swap(onto: skate.id, runnerID: runner.id, at: date, existing: spans) {
        case .failure(let e):
            return e
        case .success(let plan):
            for i in plan.closing { pairs[i].0.removedAt = date }
            let inst = RunnerInstallation(at: date)
            context.insert(inst)
            inst.runner = runner
            inst.skate = skate
            context.saveOrReport()
            return nil
        }
    }

    static func uninstall(_ runner: RunnerSet, at date: Date = Date(), context: ModelContext) {
        for inst in runner.installations where inst.removedAt == nil {
            inst.removedAt = max(date, inst.installedAt.addingTimeInterval(1))
        }
        context.saveOrReport()
    }

    /// 대표 스케이트는 한 켤레만.
    static func makePrimary(_ skate: Skate, context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Skate>())) ?? []
        for s in all { s.isPrimary = (s.id == skate.id) }
        if !skate.status.isActive { skate.status = .main }
        context.saveOrReport()
    }

    // MARK: - 기술

    static func skill(named raw: String, category: String = "내 기술", context: ModelContext) -> Skill? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let all = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        if let found = all.first(where: { $0.name == name }) { return found }
        let skill = Skill(name: name, category: category)
        context.insert(skill)
        return skill
    }

    /// 경기 시각 이전 최근 수업에서 배운 기술 (F-A03).
    static func recommendedSkills(before date: Date, context: ModelContext) -> [Skill] {
        let learnings = (try? context.fetch(FetchDescriptor<SkillLearning>())) ?? []
        let learned = learnings.compactMap { l -> SkillRecommender.Learned? in
            guard let sid = l.skill?.id, let at = l.session?.startsAt else { return nil }
            return SkillRecommender.Learned(skillID: sid, learnedAt: at)
        }
        let ids = SkillRecommender.recent(learned, before: date)
        let skills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        return ids.compactMap { id in skills.first { $0.id == id } }
    }
}

extension ModelContext {
    /// 저장하고, 실패하면 화면에 알릴 수 있게 표시만 남긴다.
    func saveOrReport() {
        do {
            try save()
            StoreHealth.shared.lastSaveFailed = false
        } catch {
            StoreHealth.shared.lastSaveFailed = true
        }
    }
}
