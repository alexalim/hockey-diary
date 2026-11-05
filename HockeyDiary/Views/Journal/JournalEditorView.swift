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
                    Picker("이날 활동", selection: $linkedSessionID) {
                        Text("연결 안 함").tag(UUID?.none)
                        ForEach(sameDaySessions) { s in
                            Text("\(s.startsAt.timeTitle) \(s.title)").tag(Optional(s.id))
                        }
                    }
                }
            }
            Section("사진") {
                PhotoPickerRow(existing: journal?.photos ?? [], removedIDs: $removedPhotoIDs, added: $addedPhotos)
            }
            Section {
                Toggle("비공개", isOn: $isPrivate)
            } footer: {
                Text(isPrivate
                     ? "비공개 일기는 하키 리포트나 공유에 들어가지 않아. 일기 내용을 자동으로 분석하지도 않아."
                     : "공개로 바꿔도 공유할 때마다 한 번 더 물어볼게.")
            }
            if !canSave {
                Section { Text("기분을 고르거나 한 줄만 써도 저장돼.").font(.footnote).foregroundStyle(.secondary) }
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
            Text("앱 안에 담은 사진 사본도 함께 지워져. 사진 앱의 원본은 그대로야.")
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
        for p in journal.photos { context.delete(p) }
        context.delete(journal)
        context.saveOrReport()
        dismiss()
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
