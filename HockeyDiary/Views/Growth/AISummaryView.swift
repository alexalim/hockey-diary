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
                        Label(working ? "요약하는 중…" : "돌아보기 만들기", icon: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: Theme.touch)
                    }
                    .disabled(working || facts.isEmpty)
                    if facts.isEmpty { Text("이 기간엔 하키 기록이 없어요.").font(.footnote).foregroundStyle(Theme.inkSecondary) }
                }
                // 요약하는 동안 움직임이 없으면 멈춘 것처럼 보였다(빌드 90 피드백). 반짝임·빛 훑기·도는 테두리로 일하는 중임을 보인다.
                if working {
                    Section { AIThinkingView() }
                        .listRowBackground(AIGlowBackground())
                }
                if let summary {
                    Section {
                        Text(summary).font(.body)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        // 화면 점검용: 시뮬레이터엔 Apple Intelligence가 없어 '요약 중' 모습을 볼 수 없다. 시험에서만 그 상태로 띄운다.
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-demoAIThinking") { enabled = true; working = true } }
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
                        let text = SummaryFacts.clean(try await session.respond(to: "사실:\n\(input)").content)
                        withAnimation(.easeOut(duration: 0.35)) { summary = text }
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

/// 요약 중: 반짝이는 별, 빛이 훑고 지나가는 자리 줄 세 개. '동작 줄이기'를 켠 사람에겐 움직이지 않는다.
struct AIThinkingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(LinearGradient(colors: [Theme.neonPink, Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.variableColor.iterative.reversing, isActive: !reduceMotion)
                Text("기록을 읽고 정리하는 중…").font(.subheadline.bold()).foregroundStyle(Theme.title)
            }
            ForEach([1.0, 0.85, 0.6], id: \.self) { w in
                GeometryReader { g in
                    Capsule().fill(Theme.cobaltSoft)
                        .overlay {
                            // 빛 한 줄기가 왼쪽에서 오른쪽으로 지나간다.
                            LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.35)
                                .offset(x: sweep ? g.size.width : -g.size.width * 0.35)
                        }
                        .clipShape(Capsule())
                        .frame(width: g.size.width * w)
                }
                .frame(height: 12)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("요약하는 중")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
}

/// 요약 중인 카드 둘레를 도는 분홍·파랑 빛(Apple Intelligence 느낌).
struct AIGlowBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AngularGradient(colors: [Theme.neonPink, Theme.accent, Color(hex: 0x7AA7FF), Theme.neonPink],
                                                  center: .center, angle: .degrees(spin ? 360 : 0)), lineWidth: 3)
                    .blur(radius: 1.5)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { spin = true }
            }
    }
}
