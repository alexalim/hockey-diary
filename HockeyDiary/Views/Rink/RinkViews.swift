import HockeyCore
import SwiftUI
import SwiftData
import MapKit

/// 링크장 이름 입력 + 자동완성. 칸을 누르면 최근·즐겨찾기 링크장이 먼저 뜨고, 타이핑하면 Apple 지도 후보가 붙는다.
struct RinkNameField: View {
    @Environment(\.modelContext) private var context
    @Binding var text: String
    var placeholder: String = "링크장 이름"

    @Query(sort: \Rink.lastUsedAt, order: .reverse) private var rinks: [Rink]
    @StateObject private var search = RinkSearch()
    @FocusState private var focused: Bool
    @State private var picking = false

    private var localMatches: [Rink] {
        let q = text.trimmingCharacters(in: .whitespaces)
        let sorted = rinks.sorted { ($0.isFavorite ? 1 : 0, $0.lastUsedAt) > ($1.isFavorite ? 1 : 0, $1.lastUsedAt) }
        let list = q.isEmpty ? sorted : sorted.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.address.localizedCaseInsensitiveContains(q) }
        return Array(list.filter { $0.name != q }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onChange(of: text) { _, new in if focused && !picking { search.update(new) } }
            if focused {
                ForEach(localMatches) { r in
                    suggestion(r.name, r.address, icon: r.isFavorite ? "star.fill" : "clock.arrow.circlepath") {
                        text = r.name
                        r.lastUsedAt = Date()
                        focused = false
                    }
                }
                ForEach(search.results.filter { c in !localMatches.contains { $0.name == c.title } }, id: \.self) { c in
                    suggestion(c.title, c.subtitle, icon: "mappin.circle") { pick(c) }
                }
                if !text.isEmpty && search.results.isEmpty && localMatches.isEmpty {
                    Text(search.failed ? "지금은 지도 검색이 안 돼요. 이름만 적어도 저장돼요." : "찾는 중이거나 결과가 없어요. 그냥 적어도 저장돼요.")
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private func suggestion(_ title: String, _ subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline).foregroundStyle(.primary)
                    if !subtitle.isEmpty { Text(subtitle).font(.caption2).foregroundStyle(Theme.inkSecondary).lineLimit(1) }
                }
                Spacer()
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func pick(_ c: MKLocalSearchCompletion) {
        picking = true
        text = c.title
        focused = false
        Task {
            let place = await search.resolve(c)
            RinkStore.upsert(name: place.name, address: place.address, lat: place.lat, lon: place.lon, context: context)
            text = place.name
            context.saveOrReport()
            picking = false
        }
    }
}

/// 탐색 탭: 링크장 찾기 (S10). 지역명·이름 검색, 즐겨찾기, 내가 확인한 시설 정보.
/// 탐색 탭: 링크장 찾기 (S10). 들어오자마자 전국 아이스링크를 지도와 목록으로 보여주고,
/// 이름·지역으로 찾고, 고른 곳은 '내 링크장'에 모은다. 위치 권한은 쓰지 않는다.
struct RinkFinderView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Rink.lastUsedAt, order: .reverse) private var rinks: [Rink]
    @StateObject private var search = RinkSearch()
    @State private var query = ""
    @State private var browse: [RinkPlace] = []
    @State private var browseQuery = "아이스링크"
    @State private var browsing = false
    @State private var opened: Rink?
    @State private var found: [RinkPlace] = []
    @State private var finding = false
    @State private var findTask: Task<Void, Never>?
    @State private var addManually = false
    @State private var manualName = ""

    private let quick = ["아이스링크", "아이스하키", "빙상장"]

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    Map(initialPosition: .region(RinkSearch.korea)) {
                        ForEach(browse) { p in
                            if let c = p.coordinate { Marker(p.name, systemImage: "figure.hockey", coordinate: c).tint(Theme.cobalt) }
                        }
                        ForEach(rinks.filter { $0.latitude != nil }) { r in
                            Marker(r.name, systemImage: r.isFavorite ? "star.fill" : "mappin",
                                   coordinate: CLLocationCoordinate2D(latitude: r.latitude!, longitude: r.longitude!)).tint(Theme.neonPink)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    ChoiceCards(options: quick.map { ChoiceOption(value: $0, title: $0, art: .symbol("magnifyingglass")) },
                                selection: Binding(get: { browseQuery }, set: { browseQuery = $0; Task { await loadBrowse() } }),
                                columns: 3, minHeight: 52)
                } footer: {
                    Text("핑크는 내 링크장, 파랑은 찾은 곳이에요.")
                }
            }

            if !query.isEmpty {
                Section {
                    if finding && found.isEmpty {
                        HStack { ProgressView(); Text("찾는 중…").foregroundStyle(Theme.inkSecondary) }
                    } else if found.isEmpty {
                        Text(search.failed ? "앱에 든 목록에는 없고, 지금은 지도 검색도 안 돼요. 인터넷이 연결돼 있는지 봐 주세요."
                             : "'\(query)'로는 못 찾았어요. 링크장 이름이나 구·동 이름으로 다시 찾아보거나 직접 추가해 보세요.")
                            .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        otherMapLinks(for: query)
                        Button { addManually = true } label: { Label("링크장 직접 추가", systemImage: "plus.circle") }
                    }
                    ForEach(found) { p in
                        Button {
                            open(RinkStore.upsert(name: p.name, address: p.address, lat: p.coordinate?.latitude, lon: p.coordinate?.longitude, context: context))
                            query = ""
                        } label: { placeRow(p.name, p.address, saved: rinks.contains { $0.name == p.name }, needsCheck: p.needsCheck) }
                    }
                } header: {
                    Text("'\(query)' 검색 결과")
                } footer: {
                    Text("동네나 역 이름만 쳐도 돼요. 전국 실내 링크장 목록이 앱에 들어 있어요.")
                }
            }

            let favorites = rinks.filter(\.isFavorite)
            if !favorites.isEmpty {
                Section("즐겨찾기") { ForEach(favorites) { r in myRinkRow(r) } }
            }
            let others = rinks.filter { !$0.isFavorite }
            if !others.isEmpty {
                Section {
                    ForEach(others) { r in myRinkRow(r) }
                } header: {
                    Text("내 링크장")
                } footer: {
                    Text("왼쪽으로 밀면 뺄 수 있어요. 기록에 적힌 링크장 이름은 그대로 남아요.")
                }
            }

            if query.isEmpty {
                Section {
                    if browsing && browse.isEmpty {
                        HStack { ProgressView(); Text("찾는 중…").foregroundStyle(Theme.inkSecondary) }
                    } else if browse.isEmpty {
                        Text(search.failed ? "지금은 지도 검색이 안 돼요. 인터넷이 연결돼 있는지 봐 주세요." : "찾은 곳이 없어요. 위 검색창에 이름이나 동네를 적어 보세요.")
                            .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        otherMapLinks(for: browseQuery)
                    }
                    ForEach(browse) { p in
                        Button {
                            open(RinkStore.upsert(name: p.name, address: p.address, lat: p.coordinate?.latitude, lon: p.coordinate?.longitude, context: context))
                        } label: { placeRow(p.name, p.address, saved: rinks.contains { $0.name == p.name }, needsCheck: p.needsCheck) }
                    }
                } header: {
                    Text("'\(browseQuery)' 찾은 곳")
                } footer: {
                    Text("누르면 내 링크장에 담기고 자세히 볼 수 있어요.")
                }
            }

            Section {
                Text("앱에 든 전국 링크장 목록에서 먼저 찾고, 없으면 Apple 지도에서도 찾아요. 내 위치는 쓰지 않아요. 운영 시간과 대관은 자주 바뀌니 공식 안내를 한 번 더 봐 주세요.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "링크장 이름이나 동네")
        .onChange(of: query) { _, q in
            // 글자를 치는 동안엔 기다렸다가, 0.4초 멈추면 찾는다.
            findTask?.cancel()
            let text = q.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { found = []; finding = false; return }
            finding = true
            findTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                let r = await search.findRinks(text)
                guard !Task.isCancelled else { return }
                found = r
                finding = false
            }
        }
        .navigationTitle("링크장 찾기")
        .navigationDestination(item: $opened) { r in RinkDetailView(rink: r) }
        .alert("링크장 직접 추가", isPresented: $addManually) {
            TextField("링크장 이름", text: $manualName)
            Button("추가") {
                let name = manualName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                open(RinkStore.upsert(name: name, address: "", lat: nil, lon: nil, context: context))
                manualName = ""
                query = ""
            }
            Button("취소", role: .cancel) { manualName = "" }
        } message: {
            Text("지도에 없는 곳도 이름만 적으면 기록할 때 고를 수 있어요. 주소와 시설 정보는 다음 화면에서 적어요.")
        }
        .task { if browse.isEmpty { await loadBrowse() } }
    }

    /// 내 링크장 한 줄. 왼쪽으로 밀어 뺀다(기록의 링크장 이름은 문자열이라 영향 없음).
    private func myRinkRow(_ r: Rink) -> some View {
        NavigationLink { RinkDetailView(rink: r) } label: { RinkRow(rink: r) }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    context.delete(r)
                    context.saveOrReport()
                } label: { Label("빼기", systemImage: "trash") }
                .tint(Theme.danger)   // 앱 전체 tint(파랑)가 이기지 않게 빨강을 못 박는다.
            }
    }

    private func placeRow(_ title: String, _ subtitle: String, saved: Bool, needsCheck: Bool = false) -> some View {
        HStack {
            Image(systemName: "figure.hockey").foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1) }
                if needsCheck { Text("운영 중인지 가기 전에 확인해 주세요").font(.caption2).foregroundStyle(Theme.warning) }
            }
            Spacer()
            Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle").foregroundStyle(saved ? Theme.neonPink : Theme.accent)
        }
        .frame(minHeight: Theme.touch)
    }

    /// Apple 지도에 없는 곳을 찾을 수 있게 다른 지도 검색으로 넘겨준다.
    private func otherMapLinks(for text: String) -> some View {
        let term = Self.rinkWordsIn(text) ? text : "\(text) 아이스링크"
        let enc = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return Group {
            if let u = URL(string: "https://map.naver.com/p/search/\(enc)") {
                Link(destination: u) { Label("네이버 지도에서 '\(term)' 찾기", systemImage: "map") }
            }
            if let u = URL(string: "https://map.kakao.com/?q=\(enc)") {
                Link(destination: u) { Label("카카오맵에서 찾기", systemImage: "map") }
            }
        }
    }

    private static func rinkWordsIn(_ text: String) -> Bool {
        RinkSearch.rinkWords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func open(_ rink: Rink) {
        context.saveOrReport()
        opened = rink
    }

    private func loadBrowse() async {
        browsing = true
        // 앱에 담긴 목록은 바로 보여주고, 지도 결과는 오는 대로 뒤에 붙인다.
        browse = RinkDirectory.search(browseQuery).map(RinkPlace.init)
        browse = await search.places(browseQuery)
        browsing = false
    }
}

struct RinkRow: View {
    let rink: Rink
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rink.name).font(.subheadline.bold())
            if !rink.address.isEmpty { Text(rink.address).font(.caption).foregroundStyle(Theme.inkSecondary) }
        }
        .frame(minHeight: Theme.touch, alignment: .leading)
    }
}

/// 링크장 상세. 시설 정보는 사용자가 확인해서 표시하고, 바꾸면 마지막 확인일이 갱신된다.
struct RinkDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var rink: Rink
    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section {
                TextField("링크장 이름", text: $rink.name).font(.title3.bold())
                TextField("주소", text: $rink.address).foregroundStyle(Theme.inkSecondary)
                Toggle("즐겨찾기", isOn: $rink.isFavorite)
                Button { rink.openInMaps() } label: { Label("지도에서 보기", systemImage: "map") }
                if let url = URL(string: rink.officialURL), !rink.officialURL.isEmpty, url.scheme?.hasPrefix("http") == true {
                    Link(destination: url) { Label("공식 안내", systemImage: "safari") }
                }
            }
            Section {
                facility("주차", $rink.hasParking)
                facility("샤워실", $rink.hasShower)
                facility("연마하는 곳", $rink.hasSharpening)
                TextField("공식 안내 주소 (https://…)", text: $rink.officialURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("메모 (대중교통·대관 팁 등)", text: $rink.memo, axis: .vertical)
            } header: {
                Text("내가 확인한 정보")
            } footer: {
                Text(rink.verifiedAt.map { "\($0.formatted(date: .abbreviated, time: .omitted))에 확인했어요. 그 뒤로 바뀌었을 수 있어요." }
                     ?? "아직 확인한 게 없어요. 직접 본 것만 골라 주세요.")
            }
            Section {
                Button(role: .destructive) { confirmRemove = true } label: {
                    Label("내 링크장에서 빼기", systemImage: "trash").foregroundStyle(Theme.danger)
                }
            } footer: {
                Text("기록에 적힌 링크장 이름은 그대로 남아요. 다시 찾아서 담을 수 있어요.")
            }
        }
        .navigationTitle("링크장")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { context.saveOrReport() }
        .confirmationDialog("'\(rink.name)'을 내 링크장에서 뺄까요?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("빼기", role: .destructive) {
                // 먼저 화면을 닫고, 닫힌 뒤 지운다(지운 객체를 화면이 붙들고 있으면 멈춤).
                dismiss()
                let target = rink
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    context.delete(target)
                    context.saveOrReport()
                }
            }
            Button("그대로 두기", role: .cancel) {}
        }
    }

    private func facility(_ title: String, _ value: Binding<Bool?>) -> some View {
        LabeledChoice(title: title, options: [
            ChoiceOption(value: Bool?.none, title: "모름", art: .symbol("questionmark")),
            ChoiceOption(value: Optional(true), title: "있어요", art: .symbol("checkmark")),
            ChoiceOption(value: Optional(false), title: "없어요", art: .symbol("xmark")),
        ], selection: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; rink.verifiedAt = Date() }),
        columns: 3, minHeight: 56)
    }
}
