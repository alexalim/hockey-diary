import SwiftUI
import SwiftData
import HockeyCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// AI 요약 (P2). 명시적으로 켠 사람만, 고른 기간의 하키 기록만 기기 안 모델로 요약한다.
/// 하루 일기·건강 데이터는 넘기지 않고, 아무것도 기기 밖으로 보내지 않는다.
struct AISummaryView: View {
    @Query(sort: \Session.startsAt) private var sessions: [Session]
    @AppStorage("aiSummaryEnabled") private var enabled = false
    @AppStorage("aiSummaryIncludeNotes") private var includeNotes = true
    @State private var period: Period = .month
    @State private var summary: String?
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                Toggle("AI 요약 쓰기", isOn: $enabled)
                if enabled {
                    Toggle("수업·경기 메모도 넣기", isOn: $includeNotes)
                }
            } footer: {
                Text("켜면 고른 기간의 하키 기록(활동, 배운·써본 기술\(includeNotes ? ", 수업·경기 메모" : ""))만 아이폰 안의 Apple Intelligence로 요약해요. 일기와 건강 데이터는 안 넣어요. 어디에도 안 보내요.")
            }
            if enabled {
                Section {
                    Picker("기간", selection: $period) {
                        ForEach(Period.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button {
                        run()
                    } label: {
                        Label(working ? "요약하는 중…" : "돌아보기 만들기", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .disabled(working || facts.isEmpty)
                    if facts.isEmpty { Text("이 기간엔 하키 기록이 없어요.").font(.footnote).foregroundStyle(Theme.inkSecondary) }
                }
                if let summary {
                    Section {
                        Text(summary).font(.body)
                    } header: {
                        Text("\(period.longTitle) 돌아보기")
                    } footer: {
                        Text("AI가 쓴 거라 틀릴 수 있어요. 기록 \(facts.count)건으로 만들었어요. 실력이나 몸 상태를 판단하는 건 아니에요.")
                    }
                }
                if let errorText { Section { Text(errorText).foregroundStyle(Theme.danger) } }
            }
        }
        .navigationTitle("AI 돌아보기")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var facts: [SummaryFacts.SessionFact] {
        let from = period.start(from: Date())
        return sessions.filter { from == nil || $0.startsAt >= from! }.map { s in
            SummaryFacts.SessionFact(
                at: s.startsAt, type: s.type, minutes: s.minutes,
                learned: s.learnings.compactMap { $0.skill?.name },
                tried: s.attempts.filter(\.tried).compactMap { a in a.skill.map { (skill: $0.name, outcome: a.outcome) } },
                untried: s.attempts.filter { !$0.tried }.compactMap { $0.skill?.name },
                notes: [s.learnedToday, s.coachNotes, s.review, s.nextGoal].filter { !$0.isEmpty }.joined(separator: " "))
        }
    }

    private func run() {
        let input = SummaryFacts.text(periodTitle: period.longTitle, sessions: facts, includeNotes: includeNotes)
        working = true
        errorText = nil
        Task {
            defer { working = false }
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                switch SystemLanguageModel.default.availability {
                case .available:
                    do {
                        let session = LanguageModelSession(instructions: SummaryFacts.instructions)
                        summary = SummaryFacts.clean(try await session.respond(to: "사실:\n\(input)").content)
                    } catch {
                        errorText = "요약을 만들지 못했어요. 잠시 뒤 다시 해 주세요."
                    }
                case .unavailable(let reason):
                    switch reason {
                    case .deviceNotEligible: errorText = "이 아이폰은 Apple Intelligence가 안 돼서 AI 요약을 쓸 수 없어요."
                    case .appleIntelligenceNotEnabled: errorText = "설정 → Apple Intelligence 및 Siri에서 Apple Intelligence를 켜 주세요."
                    case .modelNotReady: errorText = "AI 모델을 준비하는 중이에요. 잠시 뒤 다시 해 주세요."
                    @unknown default: errorText = "지금은 AI 요약을 쓸 수 없어요."
                    }
                }
                return
            }
            #endif
            errorText = "AI 요약은 iOS 26 이상이고 Apple Intelligence가 되는 아이폰에서만 돼요."
        }
    }
}
