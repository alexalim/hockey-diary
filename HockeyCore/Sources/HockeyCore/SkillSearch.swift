import Foundation

/// 기술 고르기 검색. 띄어쓰기·대소문자를 무시하고, 한글 초성만 쳐도 찾는다("ㅋㄹㅅ" → 크로스오버).
public enum SkillSearch {
    private static let initials: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")

    /// 이름이나 분류가 검색어에 맞는가. 빈 검색어는 모두 맞다.
    public static func matches(_ query: String, name: String, category: String = "") -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return true }
        for text in [name, category] {
            let t = normalized(text)
            if t.contains(q) { return true }
            // 검색어가 초성으로만 되어 있으면 초성끼리 비교한다.
            if q.allSatisfy({ initials.contains($0) }), initialsOf(t).contains(q) { return true }
        }
        return false
    }

    /// 검색어와 이름이 사실상 같은가(새 기술 추가 버튼을 숨길지 판단).
    public static func isSame(_ query: String, _ name: String) -> Bool { normalized(query) == normalized(name) }

    static func normalized(_ s: String) -> String {
        String(s.lowercased().filter { !$0.isWhitespace })
    }

    /// 한글 음절은 초성으로, 나머지는 그대로.
    static func initialsOf(_ s: String) -> String {
        String(s.map { ch -> Character in
            guard let v = ch.unicodeScalars.first?.value, ch.unicodeScalars.count == 1, (0xAC00...0xD7A3).contains(v) else { return ch }
            return initials[Int((v - 0xAC00) / 588)]
        })
    }
}
