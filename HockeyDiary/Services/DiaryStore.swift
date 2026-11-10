import Foundation
import SwiftData
import HockeyCore

/// 저장·조회 도우미. 화면은 여기를 거쳐 저장한다.
enum DiaryStore {
    /// 기본 기술 사전(이름·분류·설명은 SkillGuide 한곳). 처음 실행할 때 한 번만 넣는다.
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Skill>())) ?? 0
        guard count == 0 else { return }
        for entry in SkillGuide.entries {
            context.insert(Skill(name: entry.name, category: entry.category))
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

    static func sessionsSinceSharpening(_ runner: RunnerSet, context: ModelContext) -> Int {
        EquipmentMath.sessionsSinceSharpening(runnerID: runner.id, usages: usageRecords(context),
                                              lastSharpenedAt: runner.lastSharpening?.at)
    }

    /// 정해둔 점검 기준(시간 또는 횟수)에 닿았는지.
    static func needsCheck(_ runner: RunnerSet, context: ModelContext) -> Bool {
        EquipmentMath.needsCheck(minutesSince: minutesSinceSharpening(runner, context: context),
                                 sessionsSince: sessionsSinceSharpening(runner, context: context),
                                 thresholdMinutes: runner.checkThresholdMinutes,
                                 thresholdSessions: runner.checkThresholdSessions)
    }

    /// "연마한 지 5일 · 3번 탔어" 같은 한 줄 요약.
    static func sharpeningSummary(_ runner: RunnerSet, context: ModelContext) -> String {
        let n = sessionsSinceSharpening(runner, context: context)
        let ride = n == 0 ? "아직 안 탔어" : "\(n)번 탔어"
        guard let last = runner.lastSharpening else { return "연마 기록 없음 · \(ride)" }
        let ago = ElapsedText.since(last.at)
        let head = ago == "오늘" ? "오늘 연마" : (ago == "어제" ? "어제 연마" : "연마한 지 \(ago.replacingOccurrences(of: " 전", with: ""))")
        return "\(head) · \(ride)"
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
        switch InstallPlanner.swap(onto: skate.id, runnerID: runner.id, at: date, existing: spans) {
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

    // MARK: - 슛 차트

    static func shots(for sessionID: UUID, context: ModelContext) -> [ShotMark] {
        let all = (try? context.fetch(FetchDescriptor<ShotMark>())) ?? []
        return all.filter { $0.sessionID == sessionID }.sorted { $0.createdAt < $1.createdAt }
    }

    /// 활동의 슛 표시를 초안대로 다시 만든다.
    static func replaceShots(for sessionID: UUID, with points: [ShotPoint], context: ModelContext) {
        for old in shots(for: sessionID, context: context) { context.delete(old) }
        for p in points { context.insert(ShotMark(sessionID: sessionID, point: p)) }
    }

    static func deleteShots(for sessionID: UUID, context: ModelContext) {
        for old in shots(for: sessionID, context: context) { context.delete(old) }
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
