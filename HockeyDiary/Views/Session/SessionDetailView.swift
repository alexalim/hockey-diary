import SwiftUI
import SwiftData
import HockeyCore

/// 활동 상세. 수업·경기 정보와 기술, 장소, 장비, 사진을 한 화면에.
struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var skates: [Skate]
    @Query private var runners: [RunnerSet]
    @Query private var allShots: [ShotMark]

    let session: Session

    @State private var editing = false
    @State private var confirmingDelete = false

    var body: some View {
        // 지운 직후 화면이 닫히는 동안 삭제된 기록을 읽지 않게 한다.
        if session.isDeleted || session.modelContext == nil {
            Color.clear
        } else {
            detail
        }
    }

    private var detail: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                if !session.learnings.isEmpty { learningsCard }
                if !session.attempts.isEmpty { attemptsCard }
                if let g = session.goalieStats { goalieCard(g) }
                if !shots.isEmpty { shotsCard }
                if hasMood { moodCard }
                if hasNotes { notesCard }
                placeCard
                SessionHealthCard(start: session.startsAt, end: session.endsAt)
                if !effort.lines.isEmpty { effortCard }
                if let usage = session.usages.first { equipmentCard(usage) }
                if !session.photos.isEmpty { photosCard }
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("이 기록 지우기", systemImage: "trash").frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(session.type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("고치기") { editing = true } }
        }
        .sheet(isPresented: $editing) {
            NavigationStack { SessionEditorView(session: session) }
        }
        .confirmationDialog("이 기록을 지울까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("지우기", role: .destructive) { delete() }
        } message: {
            Text("이 기록의 기술과 장비 시간도 같이 지워져요. 사진 앱 원본은 그대로예요.")
        }
    }

    private var hasMood: Bool { session.moodBefore != nil || session.moodAfter != nil || session.fatigue != nil }
    private var shots: [ShotPoint] {
        allShots.filter { $0.sessionID == session.id }.sorted { $0.createdAt < $1.createdAt }.map(\.point)
    }

    private var shotsCard: some View {
        let st = ShotStats.compute(shots)
        return Card {
            CardHeader(title: "슛 차트", systemImage: "scope", trailing: shotSummaryText(st))
            ShotChartCanvas(shots: shots)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(shotSummaryText(st))
            ShotLegend()
            if let s = st.sentence() { Text(s).font(.subheadline) }
        }
    }

    private func goalieCard(_ g: GoalieStats) -> some View {
        Card(tint: Theme.iceBlue) {
            CardHeader(title: "골리로 뛴 날", systemImage: "figure.hockey")
            HStack(spacing: 8) {
                StatTile(title: "세이브", value: "\(g.saves)", tint: Theme.success)
                StatTile(title: "실점", value: "\(g.goalsAgainst)", tint: Theme.danger)
                StatTile(title: "세이브율", value: g.savePctText)
            }
        }
    }

    private var effort: EffortSummary {
        EffortSummary(shifts: session.shifts, onIceMinutes: session.onIceMinutes, distanceMeters: session.distanceMeters)
    }

    /// 워치에서 직접 누른 쉬프트·얼음 위 시간·GPS 총거리.
    private var effortCard: some View {
        Card {
            CardHeader(title: "워치로 잰 운동량", systemImage: "applewatch")
            HStack(spacing: 10) {
                ForEach(effort.lines, id: \.self) { line in
                    Text(line).font(.subheadline.bold()).foregroundStyle(Theme.title)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.cobaltSoft, in: Capsule())
                }
            }
            if session.distanceMeters != nil {
                Text("거리는 야외·폰드에서 GPS로 잰 총거리예요. 어디를 지났는지는 남기지 않았어요.").font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var hasNotes: Bool {
        ![session.learnedToday, session.coachNotes, session.nextGoal, session.review].allSatisfy(\.isEmpty)
            || session.scoreFor != nil || session.goals != nil || session.assists != nil
            || session.plusMinus != nil || session.penaltyMinutes != nil || session.shifts != nil
    }

    private var header: some View {
        Card(tint: session.type.color) {
            HStack {
                Image(systemName: session.type.systemImage).font(.title)
                VStack(alignment: .leading) {
                    Text(session.title).font(.title3.bold())
                    Text("\(session.startsAt.dayTitle) \(session.startsAt.timeTitle) · \(minutesText(session.minutes))")
                        .font(.subheadline).opacity(0.85)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var learningsCard: some View {
        Card {
            CardHeader(title: "배운 기술", systemImage: "graduationcap")
            ForEach(session.learnings) { l in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(l.skill?.name ?? "알 수 없는 기술").font(.subheadline.bold())
                        Spacer()
                        if let d = l.difficulty { Text("난도 \(d)").font(.caption).foregroundStyle(Theme.inkSecondary) }
                    }
                    if !l.feedback.isEmpty { Text(l.feedback).font(.subheadline).foregroundStyle(Theme.inkSecondary) }
                }
            }
        }
    }

    private var attemptsCard: some View {
        Card {
            CardHeader(title: "기술 적용", systemImage: "figure.hockey")
            ForEach(session.attempts) { a in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(a.skill?.name ?? "알 수 없는 기술").font(.subheadline.bold())
                        Spacer()
                        Text(a.tried ? (a.outcome?.title ?? "써봤어요") : "못 써봄")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(a.tried ? Theme.cobaltSoft : Theme.inkTertiary.opacity(0.12), in: Capsule())
                    }
                    if let c = a.count { Text("시도 \(c)번").font(.caption).foregroundStyle(Theme.inkSecondary) }
                    if !a.notes.isEmpty { Text(a.notes).font(.subheadline).foregroundStyle(Theme.inkSecondary) }
                }
            }
        }
    }

    private var moodCard: some View {
        Card {
            CardHeader(title: "기분·컨디션", systemImage: "face.smiling")
            HStack(spacing: 20) {
                moodItem("운동 전", session.moodBefore)
                Image(systemName: "arrow.right").foregroundStyle(Theme.inkSecondary)
                moodItem("운동 후", session.moodAfter)
                Spacer()
                if let f = session.fatigue {
                    VStack { Text("\(f)").font(.title2.bold()); Text("피로도").font(.caption).foregroundStyle(Theme.inkSecondary) }
                }
            }
        }
    }

    private func moodItem(_ title: String, _ value: Int?) -> some View {
        VStack {
            if let value {
                MoodFace(level: value, size: 34)
            } else {
                Text("–").font(.title).foregroundStyle(Theme.inkTertiary).frame(height: 34)
            }
            Text(title).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value.map(Mood.label) ?? "기록 없음")")
    }

    private var notesCard: some View {
        Card {
            CardHeader(title: "메모", systemImage: "note.text")
            if session.type.showsGameStats, let f = session.scoreFor, let a = session.scoreAgainst {
                Text("스코어 \(f) : \(a)").font(.headline)
            }
            if session.plusMinus != nil || session.penaltyMinutes != nil || session.shifts != nil {
                Text([session.plusMinus.map { "+/- \($0 > 0 ? "+" : "")\($0)" }, session.penaltyMinutes.map { "페널티 \($0)분" }, session.shifts.map { "쉬프트 \($0)번" }]
                    .compactMap { $0 }.joined(separator: " · ")).font(.subheadline)
            }
            if session.goals != nil || session.assists != nil {
                Text("골 \(session.goals ?? 0) · 어시스트 \(session.assists ?? 0)\(session.position.isEmpty ? "" : " · \(session.position)")")
                    .font(.subheadline)
            }
            labeled("오늘의 배움", session.learnedToday)
            labeled("코치 메모", session.coachNotes)
            labeled("경기 회고", session.review)
            labeled("다음 목표", session.nextGoal)
        }
    }

    @ViewBuilder
    private func labeled(_ title: String, _ text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(Theme.inkSecondary)
                Text(text).font(.subheadline)
            }
        }
    }

    private var placeCard: some View {
        Card(tint: Theme.iceBlue) {
            HStack {
                Label(title: { Text("장소") }, icon: { Image(systemName: session.surface.systemImage).foregroundStyle(session.surface.color) })
                    .font(.headline).foregroundStyle(Theme.title)
                Spacer()
            }
            Text(session.surface.title + (session.rinkName.isEmpty ? "" : " · \(session.rinkName)")).font(.subheadline)
            if let feel = session.iceFeel { Text("체감 빙질: \(feel.title)").font(.caption).foregroundStyle(Theme.inkSecondary) }
            if !session.weatherMemo.isEmpty { Text(session.weatherMemo).font(.caption).foregroundStyle(Theme.inkSecondary) }
        }
    }

    private func equipmentCard(_ usage: EquipmentUsage) -> some View {
        Card {
            CardHeader(title: "장비", systemImage: "shoeprints.fill")
            let skate = skates.first { $0.id == usage.skateID }
            let runner = runners.first { $0.id == usage.runnerID }
            Text([skate?.name, runner.map { "러너 \($0.name)" }].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
            Text("탄 시간 \(minutesText(usage.iceMinutes))").font(.caption).foregroundStyle(Theme.inkSecondary)
        }
    }

    private var photosCard: some View {
        Card {
            CardHeader(title: "사진", systemImage: "photo.on.rectangle")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(session.photos) { p in PhotoThumb(data: p.imageData, size: 110) }
                }
            }
        }
    }

    private func delete() {
        // 화면을 먼저 닫고, 닫힌 뒤에 지운다(지운 기록을 다시 그리다 멈추는 것 방지).
        let target = session, ctx = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for p in target.photos { ctx.delete(p) }
            DiaryStore.deleteShots(for: target.id, context: ctx)
            ctx.delete(target)
            ctx.saveOrReport()
        }
    }
}

/// 목록 한 줄.
struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type.systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(session.type.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text("\(session.startsAt.dayTitle) · \(minutesText(session.minutes)) · \(session.surface.title)")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if let after = session.moodAfter { MoodFace(level: after, size: 24, label: "끝나고 기분 \(Mood.label(after))") }
        }
        .frame(minHeight: Theme.touch)
        .accessibilityElement(children: .combine)
    }
}
