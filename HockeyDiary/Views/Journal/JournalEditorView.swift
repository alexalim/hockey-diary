import SwiftUI
import SwiftData
import HockeyCore

/// 하루 일기 (S05). 본문 또는 기분 중 하나만 있으면 저장된다. 기본 비공개.
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
        Form {
            Section {
                DatePicker("날짜", selection: $entryDate, displayedComponents: .date)
                MoodPicker(title: "오늘 기분", value: $mood)
            }
            Section("한 줄 일기") {
                TextField("오늘 하루 어땠어?", text: $body_, axis: .vertical)
                    .lineLimit(3...10)
            }
            Section {
                TagChips(options: tagOptions, selected: $tags)
                    .padding(.vertical, 4)
                HStack {
                    TextField("태그 직접 추가", text: $customTag)
                    Button("추가") {
                        let t = customTag.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty && !tags.contains(t) { tags.append(t) }
                        customTag = ""
                    }
                    .disabled(customTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("태그")
            }
            if !sameDaySessions.isEmpty {
                Section("하키 활동 연결") {
                    ChoiceCards(options: [ChoiceOption(value: UUID?.none, title: "연결 안 함", art: .symbol("minus"))]
                                  + sameDaySessions.map { s in
                                      ChoiceOption(value: Optional(s.id), title: s.title, subtitle: s.startsAt.timeTitle, art: .symbol(s.type.systemImage))
                                  },
                                selection: $linkedSessionID, columns: 2, minHeight: 72)
                }
            }
            Section("사진") {
                PhotoPickerRow(existing: journal?.photos ?? [], removedIDs: $removedPhotoIDs, added: $addedPhotos)
            }
            Section {
                // 저장 값은 그대로 isPrivate. 화면에서는 '리포트 공유'로 뒤집어 보여준다.
                Toggle("리포트 공유", isOn: Binding(get: { !isPrivate }, set: { isPrivate = !$0 }))
            } footer: {
                Text(isPrivate
                     ? "꺼져 있으면 이 일기는 어디에도 안 들어가. 내용을 따로 분석하지도 않아."
                     : "켜면 시즌 리포트 이미지에 이 일기 한 줄이 들어갈 수 있어. AI 요약에는 안 넣어.")
            }
            if !canSave {
                Section { Text("기분을 고르거나 한 줄만 써도 저장돼.").font(.footnote).foregroundStyle(Theme.inkSecondary) }
            }
            if journal != nil {
                Section {
                    Button("이 일기 지우기", role: .destructive) { confirmingDelete = true }
                }
            }
        }
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
