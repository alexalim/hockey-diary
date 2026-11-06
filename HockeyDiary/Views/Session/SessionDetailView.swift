import SwiftUI
import SwiftData
import HockeyCore

/// 활동 상세. 수업·경기 정보와 기술, 장소, 장비, 사진을 한 화면에.
struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var skates: [Skate]
    @Query private var runners: [RunnerSet]

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
                if hasMood { moodCard }
                if hasNotes { notesCard }
                placeCard
                SessionHealthCard(start: session.startsAt, end: session.endsAt)
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
        .confirmationDialog("이 기록을 지울까?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("지우기", role: .destructive) { delete() }
        } message: {
            Text("이 기록의 기술과 장비 시간도 같이 지워져. 사진 앱 원본은 그대로야.")
        }
    }

    private var hasMood: Bool { session.moodBefore != nil || session.moodAfter != nil || session.fatigue != nil }
    private var hasNotes: Bool {
        ![session.learnedToday, session.coachNotes, session.nextGoal, session.review].allSatisfy(\.isEmpty)
            || session.scoreFor != nil || session.goals != nil || session.assists != nil
    }

    private var header: some View {
        Card(tint: Theme.cobalt) {
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
                        if let d = l.difficulty { Text("난도 \(d)").font(.caption).foregroundStyle(.secondary) }
                    }
                    if !l.feedback.isEmpty { Text(l.feedback).font(.subheadline).foregroundStyle(.secondary) }
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
                        Text(a.tried ? (a.outcome?.title ?? "써봤어") : "못 써봄")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(a.tried ? Theme.cobaltSoft : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    if let c = a.count { Text("시도 \(c)번").font(.caption).foregroundStyle(.secondary) }
                    if !a.notes.isEmpty { Text(a.notes).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var moodCard: some View {
        Card {
            CardHeader(title: "기분·컨디션", systemImage: "face.smiling")
            HStack(spacing: 20) {
                moodItem("운동 전", session.moodBefore)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                moodItem("운동 후", session.moodAfter)
                Spacer()
                if let f = session.fatigue {
                    VStack { Text("\(f)").font(.title2.bold()); Text("피로도").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func moodItem(_ title: String, _ value: Int?) -> some View {
        VStack {
            Text(value.map(Mood.face) ?? "–").font(.title)
            Text(title).font(.caption).foregroundStyle(.secondary)
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
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(text).font(.subheadline)
            }
        }
    }

    private var placeCard: some View {
        Card(tint: Theme.iceBlue) {
            CardHeader(title: "장소", systemImage: session.surface.systemImage)
            Text(session.surface.title + (session.rinkName.isEmpty ? "" : " · \(session.rinkName)")).font(.subheadline)
            if let feel = session.iceFeel { Text("체감 빙질: \(feel.title)").font(.caption).foregroundStyle(.secondary) }
            if !session.weatherMemo.isEmpty { Text(session.weatherMemo).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func equipmentCard(_ usage: EquipmentUsage) -> some View {
        Card {
            CardHeader(title: "장비", systemImage: "shoeprints.fill")
            let skate = skates.first { $0.id == usage.skateID }
            let runner = runners.first { $0.id == usage.runnerID }
            Text([skate?.name, runner.map { "러너 \($0.name)" }].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
            Text("탄 시간 \(minutesText(usage.iceMinutes))").font(.caption).foregroundStyle(.secondary)
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
                .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(.subheadline.bold()).foregroundStyle(Theme.title)
                Text("\(session.startsAt.dayTitle) · \(minutesText(session.minutes)) · \(session.surface.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let after = session.moodAfter { Text(Mood.face(after)).font(.title3) }
        }
        .frame(minHeight: Theme.touch)
        .accessibilityElement(children: .combine)
    }
}
