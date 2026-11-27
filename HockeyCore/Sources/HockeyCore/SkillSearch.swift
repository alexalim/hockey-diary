import Foundation

/// 앱 검색 창 공통 규칙. 띄어쓰기·대소문자를 무시하고, 이름 칸은 한글 초성만 쳐도 찾는다("ㅋㄹㅅ" → 크로스오버).
/// 기술 고르기·드릴 찾기·기술 도감·링크장·기록 검색이 같이 쓴다.
public enum SkillSearch {
    /// names: 이름처럼 짧은 칸(초성 검색 허용). texts: 설명·본문처럼 긴 칸(글자 그대로만).
    public static func matches(_ query: String, names: [String], texts: [String] = []) -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return true }
        let initialsQuery = q.allSatisfy { initials.contains($0) }
        for n in names {
            let t = normalized(n)
            if t.contains(q) || (initialsQuery && initialsOf(t).contains(q)) { return true }
        }
        return texts.contains { normalized($0).contains(q) }
    }

    private static let initials: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")

    /// 이름이나 분류가 검색어에 맞는가. 빈 검색어는 모두 맞다.
    public static func matches(_ query: String, name: String, category: String = "") -> Bool {
        matches(query, names: [name, category])
    }

    /// 이름이 검색어에 얼마나 잘 맞는가. 작을수록 위. 이름에 안 맞으면 nil.
    /// 0 같음 · 1 이름이 검색어로 시작 · 2 단어 하나가 검색어로 시작("하키 스톱"의 '스톱') · 3 이름 중간에 들어 있음.
    /// 초성 검색도 같은 단계로 센다(초성은 이름에만, 분류에는 쓰지 않는다: 'ㅅㅌ'가 분류 '슈팅'에 걸려 슈팅 기술이 다 나왔다).
    public static func rank(_ query: String, name: String) -> Int? {
        let q = normalized(query)
        guard !q.isEmpty else { return 0 }
        let full = normalized(name)
        let words = name.split(whereSeparator: { $0.isWhitespace }).map { normalized(String($0)) }
        let ini = q.allSatisfy { initials.contains($0) }
        func key(_ t: String) -> String { ini ? initialsOf(t) : t }
        if key(full) == q { return 0 }
        if key(full).hasPrefix(q) { return 1 }
        if words.contains(where: { key($0).hasPrefix(q) }) { return 2 }
        if key(full).contains(q) { return 3 }
        return nil
    }

    /// 초성만 친 검색어인가("ㅋㄹㅅ"). 이건 찾는 중이지 새 기술 이름이 아니다.
    public static func isInitialsOnly(_ query: String) -> Bool {
        let q = normalized(query)
        return !q.isEmpty && q.allSatisfy { initials.contains($0) }
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
