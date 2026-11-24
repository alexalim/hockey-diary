import Foundation
import SwiftData
import HockeyCore

/// 기록 템플릿: 자주 적는 기록의 종류·시간·장소를 저장해 두고 새 기록에 한 번에 채운다.
@Model
final class RecordTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = ActivityType.lesson.rawValue
    var minutes: Int = 60
    var rinkName: String = ""
    var surfaceRaw: String = SurfaceType.unknown.rawValue
    var createdAt: Date = Date()

    init(name: String, type: ActivityType, minutes: Int, rinkName: String, surface: SurfaceType) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.minutes = max(1, minutes)
        self.rinkName = rinkName
        self.surfaceRaw = surface.rawValue
        self.createdAt = Date()
    }

    var type: ActivityType { ActivityType(rawValue: typeRaw) ?? .lesson }
    var surface: SurfaceType { SurfaceType(rawValue: surfaceRaw) ?? .unknown }
    /// 목록에 보이는 한 줄 요약.
    var summary: String {
        ([type.title, minutesText(minutes)] + (rinkName.isEmpty ? [] : [rinkName])).joined(separator: " · ")
    }
}

enum RecordTemplateStore {
    /// 기록 하나에서 템플릿을 만든다. 이름이 비면 '종류 · 링크장'으로 짓는다.
    @discardableResult
    static func make(from session: Session, name: String, context: ModelContext) -> RecordTemplate {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let t = RecordTemplate(name: trimmed.isEmpty ? defaultName(for: session) : trimmed, type: session.type,
                               minutes: session.minutes, rinkName: session.rinkName, surface: session.surface)
        context.insert(t)
        context.saveOrReport()
        return t
    }

    static func defaultName(for session: Session) -> String {
        session.rinkName.isEmpty ? session.type.title : "\(session.type.title) · \(session.rinkName)"
    }
}
