import Foundation
import SwiftData
import HockeyCore

// SwiftData 모델. enum은 String rawValue로 저장하고, 계산·집계는 HockeyCore 순수 함수에 맡긴다.
// 관계는 항상 context.insert 뒤에 연결한다(삽입 전 연결은 iOS 17에서 불안정).
// #Predicate 안에서는 enum·옵셔널 체인을 쓰지 않고, 가져온 뒤 메모리에서 거른다.

/// 수업·미니게임·정규게임·자유 연습 공통 활동 (Session).
/// 활동 종류(typeRaw)와 빙판 유형(surfaceRaw)은 독립 필드다 (ICE-01).
@Model
final class Session {
    var id: UUID = UUID()
    var typeRaw: String = ActivityType.lesson.rawValue
    var startsAt: Date = Date()
    var endsAt: Date = Date()

    // 장소·환경 (S15)
    var surfaceRaw: String = SurfaceType.unknown.rawValue
    var rinkName: String = ""
    var iceFeelRaw: String?
    var weatherMemo: String = ""

    // 기분·컨디션. 입력하지 않아도 저장된다 (FR-06).
    var moodBefore: Int?
    var moodAfter: Int?
    var fatigue: Int?
    var learnedToday: String = ""

    // 수업 (LessonLog)
    var coachNotes: String = ""
    var selfRating: Int?
    var nextGoal: String = ""

    // 경기 (GameLog). 전부 선택 항목 (FR-02).
    var opponent: String = ""
    var scoreFor: Int?
    var scoreAgainst: Int?
    var position: String = ""
    var goals: Int?
    var assists: Int?
    var review: String = ""

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SkillLearning.session) var learnings: [SkillLearning] = []
    @Relationship(deleteRule: .cascade, inverse: \SkillAttempt.session) var attempts: [SkillAttempt] = []
    @Relationship(deleteRule: .cascade, inverse: \EquipmentUsage.session) var usages: [EquipmentUsage] = []
    @Relationship(deleteRule: .nullify, inverse: \PhotoAsset.session) var photos: [PhotoAsset] = []

    init(type: ActivityType, startsAt: Date = Date(), minutes: Int = 60) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.startsAt = startsAt
        self.endsAt = startsAt.addingTimeInterval(Double(minutes) * 60)
        self.createdAt = Date()
    }

    var type: ActivityType {
        get { ActivityType(rawValue: typeRaw) ?? .lesson }
        set { typeRaw = newValue.rawValue }
    }

    var surface: SurfaceType {
        get { SurfaceType(rawValue: surfaceRaw) ?? .unknown }
        set { surfaceRaw = newValue.rawValue }
    }

    var iceFeel: IceFeel? {
        get { iceFeelRaw.flatMap(IceFeel.init(rawValue:)) }
        set { iceFeelRaw = newValue?.rawValue }
    }

    var minutes: Int { max(0, Int(endsAt.timeIntervalSince(startsAt) / 60)) }

    var title: String {
        if type.isGame, !opponent.isEmpty { return "\(type.title) · vs \(opponent)" }
        return type.title
    }

    var sample: ActivitySample {
        ActivitySample(sessionID: id, at: startsAt, type: type, surface: surface, minutes: minutes,
                       moodBefore: moodBefore, moodAfter: moodAfter)
    }
}

/// 재사용 가능한 기술 사전.
@Model
final class Skill {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SkillLearning.skill) var learnings: [SkillLearning] = []
    @Relationship(deleteRule: .cascade, inverse: \SkillAttempt.skill) var attempts: [SkillAttempt] = []

    init(name: String, category: String) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.createdAt = Date()
    }

    var stats: SkillStats {
        SkillStats.compute(
            lessonSessionIDs: learnings.compactMap { $0.session?.id },
            attempts: attempts.compactMap { a in
                guard let sid = a.session?.id else { return nil }
                return AttemptRecord(sessionID: sid, tried: a.tried, outcome: a.outcome, count: a.count)
            })
    }
}

/// 수업에서 배운 기술 (수업 N:M 기술).
@Model
final class SkillLearning {
    var id: UUID = UUID()
    var session: Session?
    var skill: Skill?
    var feedback: String = ""
    /// 체감 난도 1~5
    var difficulty: Int?
    var goal: String = ""

    init() {
        self.id = UUID()
    }
}

/// 경기에서 기술을 적용한 기록. tried=false는 미시도 (FR-03).
@Model
final class SkillAttempt {
    var id: UUID = UUID()
    var session: Session?
    var skill: Skill?
    var tried: Bool = false
    var outcomeRaw: String?
    var count: Int?
    var notes: String = ""

    init() {
        self.id = UUID()
    }

    var outcome: AttemptOutcome? {
        get { outcomeRaw.flatMap(AttemptOutcome.init(rawValue:)) }
        set { outcomeRaw = newValue?.rawValue }
    }
}

/// 하루 일기. 하키 없는 날도 만들 수 있고 기본 비공개다 (FR-05).
@Model
final class DailyJournal {
    var id: UUID = UUID()
    var entryDate: Date = Date()
    var mood: Int?
    var tagsRaw: String = ""
    var body: String = ""
    var isPrivate: Bool = true
    var linkedSessionID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \PhotoAsset.journal) var photos: [PhotoAsset] = []

    init(entryDate: Date = Date()) {
        self.id = UUID()
        self.entryDate = entryDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var tags: [String] {
        get { JournalTag.parse(tagsRaw) }
        set { tagsRaw = JournalTag.join(newValue) }
    }
}

/// 앱 안에 복사해 둔 사진. 항목을 지워도 사진 앱의 원본은 건드리지 않는다 (FR-08).
@Model
final class PhotoAsset {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data = Data()
    var createdAt: Date = Date()
    var session: Session?
    var journal: DailyJournal?

    init(imageData: Data) {
        self.id = UUID()
        self.imageData = imageData
        self.createdAt = Date()
    }
}

/// 스케이트(부츠). 삭제 대신 사용 종료로 이력을 남긴다 (EQ-01·EQ-02).
@Model
final class Skate {
    var id: UUID = UUID()
    var brand: String = ""
    var model: String = ""
    var size: String = ""
    var fit: String = ""
    var statusRaw: String = SkateStatus.main.rawValue
    var isPrimary: Bool = false
    var purchasedAt: Date?
    var memo: String = ""
    @Attribute(.externalStorage) var coverPhoto: Data?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RunnerInstallation.skate) var installations: [RunnerInstallation] = []

    init(brand: String, model: String) {
        self.id = UUID()
        self.brand = brand
        self.model = model
        self.createdAt = Date()
    }

    var status: SkateStatus {
        get { SkateStatus(rawValue: statusRaw) ?? .main }
        set { statusRaw = newValue.rawValue }
    }

    var name: String {
        let n = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        return n.isEmpty ? "이름 없는 스케이트" : n
    }

    /// 지금 장착된 러너.
    var currentRunner: RunnerSet? {
        installations.first { $0.removedAt == nil }?.runner
    }
}

/// 러너(날) 세트. 부츠와 따로 관리하고 연마 이력을 독립으로 가진다 (EQ-03).
@Model
final class RunnerSet {
    var id: UUID = UUID()
    var name: String = ""
    var model: String = ""
    var currentHollow: String?
    /// 사용자가 정한 점검 기준(분). 없으면 알림 없음.
    var checkThresholdMinutes: Int?
    /// 횟수로 정한 점검 기준(번). 시간 기준과 둘 중 하나만 쓴다. 나중에 추가된 값이라 기본 nil.
    var checkThresholdSessions: Int?
    var memo: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RunnerInstallation.runner) var installations: [RunnerInstallation] = []
    @Relationship(deleteRule: .cascade, inverse: \SharpeningLog.runner) var sharpenings: [SharpeningLog] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    var lastSharpening: SharpeningLog? { sharpenings.max { $0.at < $1.at } }

    var installedSkate: Skate? { installations.first { $0.removedAt == nil }?.skate }
}

/// 러너 장착 이력. removedAt이 nil이면 지금 장착 중.
@Model
final class RunnerInstallation {
    var id: UUID = UUID()
    var runner: RunnerSet?
    var skate: Skate?
    var installedAt: Date = Date()
    var removedAt: Date?

    /// 관계(runner·skate)는 context.insert 뒤에 연결한다.
    init(at: Date) {
        self.id = UUID()
        self.installedAt = at
    }

    var span: InstallSpan? {
        guard let r = runner?.id, let s = skate?.id else { return nil }
        return InstallSpan(runnerID: r, skateID: s, from: installedAt, to: removedAt)
    }
}

/// 연마 기록. 원본 연마값은 바꾸지 않는다.
@Model
final class SharpeningLog {
    var id: UUID = UUID()
    var runner: RunnerSet?
    var at: Date = Date()
    var hollow: String = ""
    var shop: String = ""
    var grip: Int?
    var glide: Int?
    var stop: Int?
    var turn: Int?
    var memo: String = ""

    init(hollow: String, at: Date = Date()) {
        self.id = UUID()
        self.hollow = hollow
        self.at = at
    }
}

/// 활동에서 실제 쓴 장비와 얼음 위 시간 (EQ-05). 활동 1건에 1개.
@Model
final class EquipmentUsage {
    var id: UUID = UUID()
    var session: Session?
    var skateID: UUID?
    var runnerID: UUID?
    var iceMinutes: Int = 0

    init(skateID: UUID?, runnerID: UUID?, iceMinutes: Int) {
        self.id = UUID()
        self.skateID = skateID
        self.runnerID = runnerID
        self.iceMinutes = iceMinutes
    }

    var record: UsageRecord? {
        guard let s = session else { return nil }
        return UsageRecord(sessionID: s.id, at: s.startsAt, skateID: skateID, runnerID: runnerID, iceMinutes: iceMinutes)
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Session.self, Skill.self, SkillLearning.self, SkillAttempt.self,
        DailyJournal.self, PhotoAsset.self,
        Skate.self, RunnerSet.self, RunnerInstallation.self, SharpeningLog.self, EquipmentUsage.self,
        Rink.self,
        LockerProfile.self, StickerPlacement.self, EarnedSticker.self, GearItem.self,
    ]

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
