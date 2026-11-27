import SwiftUI
import SwiftData
import HockeyCore

/// 훈련 탭 드릴 갈래의 '하키 아카데미' 진입 타일 4개: 드릴 찾기 · 기술 도감 · 규칙·전술 · 링크장 찾기.
struct AcademyGrid: View {
    var onPickDrill: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            Button(action: onPickDrill) { tile("드릴 찾기", "스케이팅·슈팅", "scope") }.buttonStyle(.plain)
            NavigationLink { SkillGuideListView() } label: { tile("기술 도감", "복습과 시작 자료", "book.pages") }.buttonStyle(.plain)
            NavigationLink { ExploreView() } label: { tile("규칙·전술", "반칙·경기 구조", "flag.2.crossed") }.buttonStyle(.plain)
            NavigationLink { RinkFinderView() } label: { tile("링크장 찾기", "즐겨찾기·검색", "mappin.and.ellipse") }.buttonStyle(.plain)
        }
    }

    private func tile(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            AppIcon(symbol, size: 20.7).foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40).background(Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.title)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.inkSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.compactCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.compactCorner, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// 기술 도감: SkillGuide 설명을 갈래별로 모아 본다. 내 기록이 있는 기술은 성장의 기술 상세로 이어진다.
struct SkillGuideListView: View {
    @State private var search = ""
    @Query private var skills: [Skill]

    private var groups: [(String, [SkillGuide.Entry])] {
        let list = SkillGuide.entries.filter { SkillSearch.matches(search, names: [$0.name], texts: [$0.category, $0.summary]) }
        let dict = Dictionary(grouping: list, by: \.category)
        let order = ["스케이팅", "퍽 컨트롤", "슈팅", "게임 운영"]
        return order.compactMap { k in dict[k].map { (k, $0) } } + dict.keys.filter { !order.contains($0) }.sorted().map { ($0, dict[$0]!) }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.0) { name, items in
                Section(name) {
                    ForEach(items, id: \.name) { e in
                        if let s = skills.first(where: { $0.name == e.name }), !(s.learnings.isEmpty && s.attempts.isEmpty) {
                            NavigationLink { SkillDetailView(skill: s) } label: {
                                guideRow(e, records: s.learnings.count + s.attempts.count)
                            }
                        } else {
                            guideRow(e, records: 0)
                        }
                    }
                }
            }
            if groups.isEmpty {
                Text("'\(search)'에 맞는 기술이 없어요.").foregroundStyle(Theme.inkSecondary)
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "기술 이름으로 찾기")
        .navigationTitle("기술 도감")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideRow(_ e: SkillGuide.Entry, records: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(e.name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                if records > 0 { Text("내 기록 \(records)").font(.caption2.bold()).foregroundStyle(Theme.accentText) }
            }
            Text(e.summary).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 4)
    }
}
