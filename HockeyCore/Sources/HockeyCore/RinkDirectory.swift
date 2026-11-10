import Foundation

/// 앱에 담아 두는 전국 실내 링크장 한 곳.
/// 지도 서비스가 못 찾는 곳(예: 상가 안 사설 링크)도 이름·동네로 바로 나오게 하려고 둔다.
public struct RinkEntry: Equatable, Sendable {
    public let name: String
    /// 줄임말·동네·역 이름. 검색 매칭용.
    public let aliases: [String]
    public let address: String
    public let latitude: Double?
    public let longitude: Double?
    /// 최근 1년 안에 운영 근거를 확인한 곳이면 true. false면 "있긴 한데 지금 하는지는 확인해줘".
    public let verified: Bool

    public init(name: String, aliases: [String], address: String, latitude: Double?, longitude: Double?, verified: Bool = true) {
        self.name = name
        self.aliases = aliases
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.verified = verified
    }
}

public enum RinkDirectory {
    /// "역삼 아이스링크"처럼 붙는 일반 명사. 검색어에서 빼고 남은 말로 찾는다.
    static let genericWords = ["아이스링크", "아이스 링크", "아이스하키", "아이스하키장", "빙상장", "빙상경기장", "스케이트장", "스케이트", "링크장", "링크", "아이스", "ice rink", "rink", "ice"]

    static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "")
    }

    /// 검색어에서 일반 명사를 뺀 토큰. 비면 "전부"라는 뜻.
    static func tokens(_ query: String) -> [String] {
        var q = query.lowercased()
        for w in genericWords.sorted(by: { $0.count > $1.count }) {
            q = q.replacingOccurrences(of: w, with: " ")
        }
        return q.split(whereSeparator: { $0.isWhitespace }).map { normalize(String($0)) }.filter { !$0.isEmpty }
    }

    /// 이름·별칭·주소로 찾는다. 토큰이 여러 개면 모두 맞아야 한다.
    /// 이름이 맞는 곳 → 별칭 → 주소 순으로 앞에 둔다. 토큰이 없으면(일반 명사만 쳤으면) 전부 돌려준다.
    public static func search(_ query: String, in entries: [RinkEntry] = RinkDirectory.all) -> [RinkEntry] {
        let toks = tokens(query)
        if toks.isEmpty {
            return query.trimmingCharacters(in: .whitespaces).isEmpty ? [] : entries
        }
        func score(_ e: RinkEntry) -> Int? {
            let name = normalize(e.name)
            let aliases = e.aliases.map(normalize)
            let address = normalize(e.address)
            var total = 0
            for t in toks {
                if name.contains(t) { total += 3 }
                else if aliases.contains(where: { $0.contains(t) }) { total += 2 }
                else if address.contains(t) { total += 1 }
                else { return nil }
            }
            return total
        }
        return entries.compactMap { e in score(e).map { (e, $0) } }
            .sorted { a, b in a.1 != b.1 ? a.1 > b.1 : a.0.name < b.0.name }
            .map(\.0)
    }

    /// 두 이름이 같은 곳을 가리키는지. 띄어쓰기·대소문자 무시, 한쪽이 다른 쪽을 품으면 같은 곳으로 본다.
    public static func sameRink(_ a: String, _ b: String) -> Bool {
        let x = normalize(a), y = normalize(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return x == y || x.contains(y) || y.contains(x)
    }
}
