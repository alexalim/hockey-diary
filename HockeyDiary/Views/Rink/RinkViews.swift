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
                    Text(search.failed ? "지금은 지도 검색이 안 돼. 이름만 적어도 저장돼." : "찾는 중이거나 결과가 없어. 그냥 적어도 저장돼.")
                        .font(.caption).foregroundStyle(.secondary)
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
                    if !subtitle.isEmpty { Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
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
struct RinkFinderView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Rink.lastUsedAt, order: .reverse) private var rinks: [Rink]
    @StateObject private var search = RinkSearch()
    @State private var query = ""

    var body: some View {
        List {
            if !query.isEmpty {
                Section("Apple 지도 검색") {
                    if search.results.isEmpty {
                        Text(search.failed ? "지금은 지도 검색이 안 돼." : "결과가 없어. 동네 이름을 붙여서 찾아봐. 예: 목동 아이스링크")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(search.results, id: \.self) { c in
                        Button {
                            Task {
                                let p = await search.resolve(c)
                                RinkStore.upsert(name: p.name, address: p.address, lat: p.lat, lon: p.lon, context: context)
                                context.saveOrReport()
                                query = ""
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(c.title).foregroundStyle(.primary)
                                Text(c.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            let favorites = rinks.filter(\.isFavorite)
            if !favorites.isEmpty {
                Section("즐겨찾기") { ForEach(favorites) { r in NavigationLink { RinkDetailView(rink: r) } label: { RinkRow(rink: r) } } }
            }
            let others = rinks.filter { !$0.isFavorite }
            Section("내 링크장") {
                if others.isEmpty && favorites.isEmpty {
                    Text("위에서 찾아서 넣어봐. 기록할 때 고른 링크장도 여기 모여.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(others) { r in NavigationLink { RinkDetailView(rink: r) } label: { RinkRow(rink: r) } }
            }
            Section {
                Text("검색어는 Apple 지도로 가. 내 위치는 쓰지 않아. 운영 시간과 대관은 자주 바뀌니 공식 안내를 확인해줘.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .searchable(text: $query, prompt: "링크장·지역 찾기")
        .onChange(of: query) { _, q in search.update(q) }
        .navigationTitle("링크장 찾기")
    }
}

struct RinkRow: View {
    let rink: Rink
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rink.name).font(.subheadline.bold())
            if !rink.address.isEmpty { Text(rink.address).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(minHeight: Theme.touch, alignment: .leading)
    }
}

/// 링크장 상세. 시설 정보는 사용자가 확인해서 표시하고, 바꾸면 마지막 확인일이 갱신된다.
struct RinkDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var rink: Rink

    var body: some View {
        Form {
            Section {
                Text(rink.name).font(.title3.bold())
                if !rink.address.isEmpty { Text(rink.address).foregroundStyle(.secondary) }
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
                Text(rink.verifiedAt.map { "\($0.formatted(date: .abbreviated, time: .omitted))에 확인했어. 그 뒤로 바뀌었을 수 있어." }
                     ?? "아직 확인한 게 없어. 직접 본 것만 골라줘.")
            }
        }
        .navigationTitle("링크장")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { context.saveOrReport() }
    }

    private func facility(_ title: String, _ value: Binding<Bool?>) -> some View {
        Picker(title, selection: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; rink.verifiedAt = Date() })) {
            Text("모름").tag(Bool?.none)
            Text("있음").tag(Optional(true))
            Text("없음").tag(Optional(false))
        }
    }
}
