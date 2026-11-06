import Foundation
import MapKit
import SwiftData
import UIKit

/// 링크장. 사용자가 고르거나 직접 확인한 값만 저장한다(시설 정보를 지어내지 않는다).
@Model
final class Rink {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    var isFavorite: Bool = false
    var lastUsedAt: Date = Date()
    /// 사용자가 확인한 시설 정보. nil이면 모름.
    var hasParking: Bool?
    var hasShower: Bool?
    var hasSharpening: Bool?
    var officialURL: String = ""
    var memo: String = ""
    /// 시설 정보를 마지막으로 확인한 날 (8.3).
    var verifiedAt: Date?

    init(name: String, address: String) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.lastUsedAt = Date()
    }

    func openInMaps() {
        let item: MKMapItem
        if let lat = latitude, let lon = longitude {
            item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        } else {
            item = MKMapItem()
        }
        item.name = name
        if latitude == nil, let url = URL(string: "maps://?q=\((name + " " + address).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        } else {
            item.openInMaps()
        }
    }
}

/// Apple 지도 자동완성. 위치 권한 없이 한국 범위에서만 찾는다. 검색어는 Apple 지도로 전송된다.
@MainActor
final class RinkSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var failed = false
    private let completer = MKLocalSearchCompleter()

    static let korea = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 36.4, longitude: 127.8),
                                          span: MKCoordinateSpan(latitudeDelta: 6.5, longitudeDelta: 6.5))

    override init() {
        super.init()
        completer.delegate = self
        completer.region = Self.korea
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func update(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.count < 1 {
            results = []
            completer.cancel()
            return
        }
        completer.queryFragment = q
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // 부제(주소)에 한글이 있거나 비어 있는 것만: 일본·중국 주소가 섞여 오는 것을 거른다.
        let r = Array(completer.results.filter { c in
            c.subtitle.isEmpty || c.subtitle.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
        }.prefix(8))
        Task { @MainActor in
            self.results = r
            self.failed = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.failed = true }
    }

    /// 한국 범위에서 장소를 바로 찾는다(링크장 둘러보기용).
    /// 지도 데이터가 검색어마다 다르게 걸려서 비슷한 말 몇 개로 같이 찾고 합친다.
    /// 한국 밖은 뺀다. 이름에 빙상 관련 말이 있는 곳을 먼저, 하나도 없으면 한국 결과를 그대로 보여준다.
    func places(_ text: String) async -> [RinkPlace] {
        let queries = [text, "아이스링크", "빙상장", "스케이트장", "ice rink"].reduce(into: [String]()) { acc, q in
            if !acc.contains(q) { acc.append(q) }
        }
        var all: [RinkPlace] = []
        var anySucceeded = false
        for q in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = q
            request.region = Self.korea
            request.resultTypes = .pointOfInterest
            guard let items = try? await MKLocalSearch(request: request).start().mapItems else { continue }
            anySucceeded = true
            for item in items where item.placemark.isoCountryCode == "KR" {
                guard let name = item.name, !all.contains(where: { $0.name == name }) else { continue }
                let pm = item.placemark
                let address = [pm.administrativeArea, pm.locality, pm.subLocality, pm.thoroughfare].compactMap { $0 }.joined(separator: " ")
                all.append(RinkPlace(name: name, address: address, coordinate: pm.coordinate))
            }
        }
        failed = !anySucceeded
        let keywords = ["아이스", "링크", "빙상", "스케이트", "얼음", "하키", "ice", "rink", "skat", "hockey"]
        let matched = all.filter { p in keywords.contains { p.name.localizedCaseInsensitiveContains($0) } }
        return matched.isEmpty ? Array(all.prefix(15)) : matched
    }

    /// 자동완성 항목을 실제 장소(이름·주소·좌표)로 바꾼다. 실패하면 제목·부제만 쓴다.
    func resolve(_ completion: MKLocalSearchCompletion) async -> (name: String, address: String, lat: Double?, lon: Double?) {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = Self.korea
        if let item = try? await MKLocalSearch(request: request).start().mapItems.first {
            let pm = item.placemark
            let address = [pm.administrativeArea, pm.locality, pm.subLocality, pm.thoroughfare, pm.subThoroughfare]
                .compactMap { $0 }.joined(separator: " ")
            return (item.name ?? completion.title, address.isEmpty ? completion.subtitle : address,
                    pm.coordinate.latitude, pm.coordinate.longitude)
        }
        return (completion.title, completion.subtitle, nil, nil)
    }
}

/// 지도에서 찾은 장소 하나(저장 전).
struct RinkPlace: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D?
}

enum RinkStore {
    /// 같은 이름은 하나로 모으고 최근 사용 시각을 갱신한다.
    @discardableResult
    static func upsert(name: String, address: String, lat: Double?, lon: Double?, context: ModelContext) -> Rink {
        let all = (try? context.fetch(FetchDescriptor<Rink>())) ?? []
        if let found = all.first(where: { $0.name == name }) {
            if found.address.isEmpty { found.address = address }
            if found.latitude == nil { found.latitude = lat; found.longitude = lon }
            found.lastUsedAt = Date()
            return found
        }
        let r = Rink(name: name, address: address)
        r.latitude = lat
        r.longitude = lon
        context.insert(r)
        return r
    }

    /// 직접 입력한 이름도 최근 목록에 남긴다.
    static func touch(name: String, context: ModelContext) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        upsert(name: n, address: "", lat: nil, lon: nil, context: context)
    }
}
