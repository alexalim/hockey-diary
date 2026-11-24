import Foundation

/// 나에 대한 설정(닉네임). 이 아이폰의 설정 저장소에만 둔다.
enum MyPrefs {
    static let nicknameKey = "myNickname"
    static let maxLength = 10

    /// 줄바꿈을 없애고 앞 공백을 떼고 길이를 제한한다(홈 제목 한두 줄에 들어가게).
    static func clean(_ raw: String) -> String {
        let oneLine = raw.replacingOccurrences(of: "\n", with: " ")
        return String(oneLine.drop { $0 == " " }.prefix(maxLength))
    }
}
