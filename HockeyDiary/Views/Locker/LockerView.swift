import SwiftUI
import SwiftData
import HockeyCore

/// 나의 락커 (S08). 닫힌 문 → 열린 락커 → 장비 구역.
/// 동작 줄이기면 애니메이션 없이 바로 열고, 필수 기능은 텍스트 버튼으로도 들어갈 수 있다 (8.1.1).
struct LockerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lockerOpen") private var isOpen = false
    @State private var animating = false
    @State private var goToSkates = false

    @Query private var skates: [Skate]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    LockerInside(skateCount: skates.count) { goToSkates = true }
                        .opacity(isOpen ? 1 : 0)
                    LockerDoor()
                        .rotation3DEffect(.degrees(isOpen ? -100 : 0), axis: (x: 0, y: 1, z: 0),
                                          anchor: .leading, perspective: 0.5)
                        .opacity(isOpen ? 0 : 1)
                        .allowsHitTesting(!isOpen)
                        .onTapGesture(perform: toggle)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("닫힌 락커 문")
                        .accessibilityHint("두 번 탭하면 문이 열려")
                        .accessibilityAddTraits(.isButton)
                }
                .frame(height: 440)

                HStack(spacing: 8) {
                    Button(isOpen ? "문 닫기" : "문 열기", action: toggle)
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.touch)
                    Spacer()
                }

                Card {
                    CardHeader(title: "바로 가기", systemImage: "list.bullet")
                    NavigationLink { SkateListView() } label: { shortcut("스케이트", "shoeprints.fill", "\(skates.count)켤레") }
                    NavigationLink { RunnerListView() } label: { shortcut("러너", "minus", nil) }
                    NavigationLink { RunnerListView(focusSharpening: true) } label: { shortcut("연마", "wrench.and.screwdriver.fill", nil) }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("나의 락커")
        .navigationDestination(isPresented: $goToSkates) { SkateListView() }
    }

    private func shortcut(_ title: String, _ icon: String, _ trailing: String?) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(Theme.title)
            Spacer()
            if let trailing { Text(trailing).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: Theme.touch)
    }

    private func toggle() {
        // 애니메이션 중 중복 탭은 무시한다.
        guard !animating else { return }
        if reduceMotion {
            isOpen.toggle()
            return
        }
        animating = true
        withAnimation(.easeInOut(duration: 0.75)) { isOpen.toggle() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { animating = false }
    }
}

/// 코발트 금속 락커 문. 이름표·통풍구·손잡이.
struct LockerDoor: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [Theme.cobalt, Theme.deepNavy], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 2)
            )
            .overlay(alignment: .top) {
                VStack(spacing: 18) {
                    Text("MY LOCKER")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.deepNavy)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6))
                    VStack(spacing: 7) {
                        ForEach(0..<6, id: \.self) { _ in
                            Capsule().fill(.black.opacity(0.35)).frame(width: 140, height: 6)
                        }
                    }
                }
                .padding(.top, 36)
            }
            .overlay(alignment: .trailing) {
                Capsule().fill(.white.opacity(0.85)).frame(width: 12, height: 70).padding(.trailing, 22)
            }
            .overlay(alignment: .bottom) {
                Text("눌러서 열기").font(.caption).foregroundStyle(.white.opacity(0.7)).padding(.bottom, 20)
            }
    }
}

/// 열린 락커 안. 장비 구역 핫스팟.
struct LockerInside: View {
    var skateCount: Int
    var openSkates: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            zone("헬멧 · 장갑", "shield.lefthalf.filled", soon: true) {}
            zone("유니폼 · 보호대", "tshirt.fill", soon: true) {}
            zone(skateCount == 0 ? "스케이트 · 첫 장비 등록" : "스케이트 \(skateCount)켤레", "shoeprints.fill", soon: false, action: openSkates)
            zone("스틱 · 테이프", "line.diagonal", soon: true) {}
        }
        .padding(12)
        .background(Theme.deepNavy.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func zone(_ title: String, _ icon: String, soon: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.title2).frame(width: 40)
                Text(title).font(.headline)
                Spacer()
                Text(soon ? "곧 열려" : "열기").font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(soon ? Color.white.opacity(0.15) : Theme.neonPink, in: Capsule())
            }
            .foregroundStyle(.white.opacity(soon ? 0.6 : 1))
            .frame(maxWidth: .infinity, minHeight: 90)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(soon)
    }
}
