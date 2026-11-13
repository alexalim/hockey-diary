import SwiftUI
import SwiftData
import HockeyCore

/// 하루 일기 (S05). 본문 또는 기분 중 하나만 있으면 저장된다. 기본 비공개.
/// 모양은 다이어리 속지(종이 카드·테이프·스티커, JournalParts.swift). 저장 모델은 그대로.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.startsAt, order: .reverse) private var sessions: [Session]

    private let journal: DailyJournal?

    @State private var entryDate: Date
    @State private var mood: Int?
    @State private var tags: [String]
    @State private var body_: String
    @State private var isPrivate: Bool
    @State private var linkedSessionID: UUID?
    @State private var customTag = ""
    @State private var removedPhotoIDs: Set<UUID> = []
    @State private var addedPhotos: [Data] = []
    @State private var confirmingDelete = false

    init(newDate: Date) {
        journal = nil
        _entryDate = State(initialValue: newDate)
        _mood = State(initialValue: nil)
        _tags = State(initialValue: [])
        _body_ = State(initialValue: "")
        _isPrivate = State(initialValue: true)
        _linkedSessionID = State(initialValue: nil)
    }

    init(journal: DailyJournal) {
        self.journal = journal
        _entryDate = State(initialValue: journal.entryDate)
        _mood = State(initialValue: journal.mood)
        _tags = State(initialValue: journal.tags)
        _body_ = State(initialValue: journal.body)
        _isPrivate = State(initialValue: journal.isPrivate)
        _linkedSessionID = State(initialValue: journal.linkedSessionID)
    }

    private var canSave: Bool {
        mood != nil || !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sameDaySessions: [Session] {
        sessions.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: entryDate) }
    }

    private var tagOptions: [String] {
        var out = JournalTag.defaults
        for t in tags where !out.contains(t) { out.append(t) }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dayCard
                lineCard
                stickerCard
                if !sameDaySessions.isEmpty { linkCard }
                PaperCard(tape: Theme.tapeMint, tapeAngle: 3) {
                    PaperTitle(text: "사진", systemImage: "camera")
                    PhotoPickerRow(existing: journal?.photos ?? [], removedIDs: $removedPhotoIDs, added: $addedPhotos)
                }
                shareCard
                if !canSave {
                    Label("기분 하나만 골라도, 한 줄만 써도 저장돼.", systemImage: "sparkles")
                        .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: save) {
                    Label(journal == nil ? "오늘 일기 붙이기" : "고친 일기 붙이기", systemImage: "heart.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
                .disabled(!canSave)
                if journal != nil {
                    Button("이 일기 지우기", role: .destructive) { confirmingDelete = true }
                        .font(.system(.subheadline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: Theme.touch)
                }
            }
            .padding(.horizontal, Theme.screenPadding).padding(.vertical, 12)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("이 일기를 지울까?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("지우기", role: .destructive, action: delete)
        } message: {
            Text("앱에 복사해 둔 사진도 같이 지워져. 사진 앱 원본은 그대로야.")
        }
        .navigationTitle(journal == nil ? "하루 일기" : "일기 고치기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") { save() }.disabled(!canSave).fontWeight(.semibold)
            }
        }
    }

    // MARK: 카드들

    /// 날짜 + 기분. 테이프는 고른 기분 색으로 바뀐다.
    private var dayCard: some View {
        PaperCard(tape: mood.map { Theme.moodFills[$0 - 1] } ?? Theme.tapePink, tapeAngle: -5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entryDate.formatted(.dateTime.month().day()))
                        .font(.system(.title, design: .rounded).bold()).foregroundStyle(Theme.paperInk)
                    Text(entryDate.formatted(.dateTime.weekday(.wide)) + (Calendar.current.isDateInToday(entryDate) ? " · 오늘" : ""))
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
                }
                Spacer()
                DatePicker("날짜", selection: $entryDate, displayedComponents: .date)
                    .labelsHidden().tint(Theme.accentText)
            }
            Text(mood.map { "오늘은 \(Mood.label($0))" } ?? "오늘 기분은 어때?")
                .font(.system(.headline, design: .rounded)).foregroundStyle(Theme.paperInk)
                .contentTransition(.numericText())
            MoodFaces(value: $mood)
        }
    }

    /// 한 줄 일기. 점 격자 종이 위에 둥근 글꼴.
    private var lineCard: some View {
        PaperCard(tape: Theme.tapeYellow, tapeAngle: 4, dotted: true) {
            PaperTitle(text: "한 줄 일기", systemImage: "pencil.line")
            TextField("오늘 하루 어땠어?", text: $body_, axis: .vertical)
                .lineLimit(4...12)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.paperInk)
                .tint(Theme.accentText)
                .padding(10)
                .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let linked = linkedSessionID, let s = sameDaySessions.first(where: { $0.id == linked }) {
                Label("\(s.title)랑 이어 붙였어", systemImage: "link")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
            }
        }
    }

    /// 태그 = 스티커. 직접 만든 스티커도 붙는다.
    private var stickerCard: some View {
        PaperCard(tape: Theme.tapePink, tapeAngle: -3) {
            PaperTitle(text: "스티커 붙이기", systemImage: "seal")
            StickerChips(options: tagOptions, selected: $tags)
                .padding(.vertical, 4)
            HStack(spacing: 8) {
                TextField("새 스티커 이름", text: $customTag)
                    .font(.system(.subheadline, design: .rounded))
                    .tint(Theme.accentText)
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .background(Theme.card.opacity(0.55), in: Capsule())
                Button {
                    let t = customTag.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty && !tags.contains(t) { tags.append(t) }
                    customTag = ""
                } label: {
                    Text("붙이기").font(.system(.subheadline, design: .rounded).bold())
                        .padding(.horizontal, 14).frame(minHeight: 40)
                }
                .buttonStyle(.borderedProminent).tint(Theme.neonPink).buttonBorderShape(.capsule)
                .disabled(customTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// 같은 날 하키 기록과 잇기.
    private var linkCard: some View {
        PaperCard(tape: Theme.tapeMint, tapeAngle: -2) {
            PaperTitle(text: "하키 기록이랑 잇기", systemImage: "link")
            ChoiceCards(options: [ChoiceOption(value: UUID?.none, title: "연결 안 함", art: .symbol("minus"))]
                          + sameDaySessions.map { s in
                              ChoiceOption(value: Optional(s.id), title: s.title, subtitle: s.startsAt.timeTitle, art: .symbol(s.type.systemImage))
                          },
                        selection: $linkedSessionID, columns: 2, minHeight: 72)
        }
    }

    /// 리포트 공유. 저장 값은 그대로 isPrivate이고 화면에서만 뒤집어 보여준다.
    private var shareCard: some View {
        PaperCard {
            Toggle(isOn: Binding(get: { !isPrivate }, set: { isPrivate = !$0 })) {
                PaperTitle(text: "리포트 공유", systemImage: "square.and.arrow.up")
            }
            .tint(Theme.neonPink)
            Text(isPrivate
                 ? "꺼져 있으면 이 일기는 어디에도 안 들어가. 내용을 따로 분석하지도 않아."
                 : "켜면 시즌 리포트 이미지에 이 일기 한 줄이 들어갈 수 있어. AI 요약에는 안 넣어.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.paperInkSoft)
        }
    }

    private func delete() {
        guard let journal else { return }
        let ctx = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for p in journal.photos { ctx.delete(p) }
            ctx.delete(journal)
            ctx.saveOrReport()
        }
    }

    private func save() {
        let target: DailyJournal
        if let journal {
            target = journal
        } else {
            target = DailyJournal(entryDate: entryDate)
            context.insert(target)
        }
        target.entryDate = entryDate
        target.mood = mood
        target.tags = tags
        target.body = body_.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isPrivate = isPrivate
        target.linkedSessionID = sameDaySessions.contains { $0.id == linkedSessionID } ? linkedSessionID : nil
        target.updatedAt = Date()
        for photo in target.photos where removedPhotoIDs.contains(photo.id) {
            context.delete(photo)
        }
        for data in addedPhotos {
            let p = PhotoAsset(imageData: data)
            context.insert(p)
            p.journal = target
        }
        context.saveOrReport()
        dismiss()
    }
}
