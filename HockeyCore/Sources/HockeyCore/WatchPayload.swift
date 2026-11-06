import Foundation

/// 워치에서 끝낸 활동을 아이폰으로 보내는 형식(WatchConnectivity userInfo).
/// id는 아이폰 Session.id로 그대로 쓰여, 같은 전달이 두 번 와도 한 건만 저장된다.
public struct WatchWorkoutPayload: Equatable, Sendable {
    public var id: UUID
    public var type: ActivityType
    public var start: Date
    public var end: Date
    public var moodBefore: Int?
    public var moodAfter: Int?
    /// 건강 앱에 저장된 워치 운동이 있으면 true(아니면 타이머만 쓴 기록).
    public var savedToHealth: Bool

    public init(id: UUID = UUID(), type: ActivityType, start: Date, end: Date,
                moodBefore: Int? = nil, moodAfter: Int? = nil, savedToHealth: Bool = false) {
        self.id = id; self.type = type; self.start = start; self.end = end
        self.moodBefore = moodBefore; self.moodAfter = moodAfter; self.savedToHealth = savedToHealth
    }

    public var dictionary: [String: Any] {
        var d: [String: Any] = [
            "kind": "workout", "id": id.uuidString, "type": type.rawValue,
            "start": start.timeIntervalSince1970, "end": end.timeIntervalSince1970, "health": savedToHealth,
        ]
        if let moodBefore { d["moodBefore"] = moodBefore }
        if let moodAfter { d["moodAfter"] = moodAfter }
        return d
    }

    /// 형식이 맞지 않거나 시간이 거꾸로면 nil.
    public init?(dictionary d: [String: Any]) {
        guard d["kind"] as? String == "workout",
              let idText = d["id"] as? String, let id = UUID(uuidString: idText),
              let typeRaw = d["type"] as? String, let type = ActivityType(rawValue: typeRaw),
              let s = d["start"] as? Double, let e = d["end"] as? Double, e > s else { return nil }
        self.init(id: id, type: type, start: Date(timeIntervalSince1970: s), end: Date(timeIntervalSince1970: e),
                  moodBefore: Mood.clamp(d["moodBefore"] as? Int), moodAfter: Mood.clamp(d["moodAfter"] as? Int),
                  savedToHealth: d["health"] as? Bool ?? false)
    }
}
