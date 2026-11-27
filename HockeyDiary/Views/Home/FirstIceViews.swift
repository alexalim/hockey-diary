import SwiftUI
import HockeyCore

/// 입문 전 홈 맨 위 카드: '첫 빙판까지' 다섯 단계. 줄을 누르면 그 단계로 가고 체크된다. 동그라미만 눌러 체크를 풀 수도 있다.
struct FirstIceCard: View {
    @AppStorage(FirstIce.doneKey) private var doneRaw = ""
    var open: (FirstIce.Step) -> Void

    var body: some View {
        let done = FirstIce.done(doneRaw)
        let next = FirstIce.next(done)
        Card {
            HStack(alignment: .firstTextBaseline) {
                CardHeader(title: "첫 빙판까지", systemImage: "sparkles")
                Spacer()
                Text("\(done.count)/\(FirstIce.Step.allCases.count)").font(.caption.bold()).foregroundStyle(Theme.accentText)
            }
            Text("아직 안 타 봤어도 괜찮아요. 하나씩 해 보면 첫 수업이 덜 낯설어요.")
                .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            ProgressView(value: Double(done.count), total: Double(FirstIce.Step.allCases.count)).tint(Theme.neonPink)
            VStack(spacing: 0) {
                ForEach(FirstIce.Step.allCases, id: \.rawValue) { s in
                    row(s, done: done.contains(s), isNext: s == next)
                    if s != FirstIce.Step.allCases.last { Divider().padding(.leading, 40) }
                }
            }
        }
    }

    private func row(_ s: FirstIce.Step, done: Bool, isNext: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { doneRaw = FirstIce.toggling(doneRaw, s) } label: {
                AppIcon(done ? "checkmark.circle.fill" : "circle", size: 24)
                    .foregroundStyle(done ? Theme.neonPink : Theme.inkTertiary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "\(s.title) 했어요, 체크 풀기" : "\(s.title) 했다고 체크")
            Button {
                // 기록하기는 저장해야 끝난다(저장하면 이 카드 자체가 사라진다). 나머지는 가 보면 한 걸로 친다.
                if s != .firstSkate { doneRaw = FirstIce.marking(doneRaw, s) }
                open(s)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.title).font(.subheadline.bold())
                            .foregroundStyle(done ? Theme.inkSecondary : Theme.title)
                            .strikethrough(done, color: Theme.inkTertiary)
                        if isNext {
                            Text(s.detail).font(.caption).foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(s.action).font(.caption.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.neonPink, in: Capsule())
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                    AppIcon("chevron.right", size: 12).foregroundStyle(Theme.inkTertiary).padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(s.title), \(s.action)")
        }
        .padding(.vertical, 8)
    }
}

/// 처음 장비: 먼저 살 것 · 신어 보고 살 것 · 빌려도 되는 것 · 나중에. 준비한 건 체크해 둔다.
struct StarterGearView: View {
    @AppStorage(StarterGear.readyKey) private var readyRaw = ""

    var body: some View {
        let ready = StarterGear.ready(readyRaw)
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("처음부터 다 살 필요 없어요").font(.headline).foregroundStyle(Theme.title)
                    Text("첫 체험·강습은 대부분 빌려서 시작해요. 몸에 바로 닿는 것부터 하나씩 준비하면 돼요.")
                        .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    Text("준비됨 \(ready.count)/\(StarterGear.all.count)").font(.caption.bold()).foregroundStyle(Theme.accentText)
                }
                .padding(.vertical, 4)
            }
            ForEach(StarterGear.order, id: \.rawValue) { plan in
                Section(plan.title) {
                    ForEach(StarterGear.items(plan)) { item in
                        let on = ready.contains(item.key)
                        Button { readyRaw = StarterGear.toggling(readyRaw, item.key) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                AppIcon(on ? "checkmark.circle.fill" : "circle", size: 22)
                                    .foregroundStyle(on ? Theme.neonPink : Theme.inkTertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline.bold()).foregroundStyle(Theme.title)
                                    Text(item.why).font(.caption).foregroundStyle(Theme.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name), \(on ? "준비됨" : "아직")")
                        .accessibilityHint("두 번 탭하면 준비 표시를 바꿔요")
                    }
                }
            }
            Section {
                Text("강습처·링크장마다 빌려주는 게 달라요. 첫 수업 전에 무엇을 빌릴 수 있는지 물어보세요. 장비를 사면 락커에 등록해 두세요.")
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
            }
        }
        .navigationTitle("처음 장비")
        .navigationBarTitleDisplayMode(.inline)
    }
}
