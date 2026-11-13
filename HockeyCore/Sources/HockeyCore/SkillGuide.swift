import Foundation

/// 기본 기술 사전: 이름·분류·짧은 설명. 처음 실행할 때 넣는 기술 목록도 여기서 나온다.
/// 설명은 이름으로 찾으므로 저장 구조를 바꾸지 않는다. 사용자가 만든 기술은 설명이 없다.
public enum SkillGuide {
    public struct Entry: Equatable, Sendable {
        public let name: String
        public let category: String
        public let summary: String
    }

    public static let entries: [Entry] = [
        Entry(name: "크로스오버", category: "스케이팅",
              summary: "코너를 돌 때 바깥 발을 안쪽 발 앞으로 넘기며 미는 기술이에요. 돌면서도 속도가 줄지 않고 오히려 붙어요."),
        Entry(name: "엣지 턴", category: "스케이팅",
              summary: "날 엣지에 무게를 싣고 몸을 기울여 도는 턴이에요. 무릎을 굽히고, 가려는 쪽을 먼저 봐요."),
        Entry(name: "하키 스톱", category: "스케이팅",
              summary: "두 날을 옆으로 틀어 얼음을 긁으며 멈추는 기술이에요. 두 발 스톱부터 익히고, 한 발 스톱은 그다음이에요."),
        Entry(name: "백워드 스케이팅", category: "스케이팅",
              summary: "뒤로 타는 기술이에요. 발로 C자를 그리듯 밀어내요. 수비할 때 상대를 보면서 따라가려면 꼭 필요해요."),
        Entry(name: "피벗", category: "스케이팅",
              summary: "앞으로 타다 뒤로, 뒤로 타다 앞으로 몸을 돌리는 동작이에요. 속도를 잃지 않고 공수를 바꿀 때 써요."),
        Entry(name: "포핸드 패스", category: "퍽 컨트롤",
              summary: "스틱 블레이드 앞면으로 주는 패스예요. 퍽을 블레이드 가운데 두고 받을 사람 쪽으로 밀어 줘요."),
        Entry(name: "백핸드 패스", category: "퍽 컨트롤",
              summary: "블레이드 뒷면으로 주는 패스예요. 포핸드보다 어렵지만, 몸 반대쪽 동료에게 빨리 줄 때 필요해요."),
        Entry(name: "퍽 드리블", category: "퍽 컨트롤",
              summary: "스틱으로 퍽을 좌우로 옮기며 몰고 가는 기술이에요. 스틱핸들링이라고도 해요. 고개를 들고, 퍽은 손으로 느끼는 게 목표예요."),
        Entry(name: "리스트 샷", category: "슈팅",
              summary: "손목을 감아 올리며 퍽을 쓸듯이 쏘는 슛이에요. 동작이 짧고 정확해서 보통 가장 먼저 배워요."),
        Entry(name: "스냅 샷", category: "슈팅",
              summary: "스틱을 살짝 뺐다가 손목을 튕겨 빠르게 쏘는 슛이에요. 리스트 샷보다 빠르고, 슬랩 샷보다 준비가 짧아요."),
        Entry(name: "슬랩 샷", category: "슈팅",
              summary: "스틱을 크게 들었다가 퍽 바로 뒤 얼음부터 치며 세게 때리는 슛이에요. 가장 세지만 동작이 커서 막히기 쉬워요."),
        Entry(name: "포지셔닝", category: "게임 운영",
              summary: "퍽 위치에 맞춰 내가 설 자리를 잡는 거예요. 공격 땐 패스 받을 빈자리, 수비 땐 상대와 우리 골문 사이."),
        Entry(name: "페이스오프", category: "게임 운영",
              summary: "심판이 떨어뜨린 퍽을 두 선수가 다투며 경기를 시작하거나 다시 여는 거예요. 퍽을 우리 편 쪽으로 빼 오는 게 목표예요."),
    ]

    /// 이름(앞뒤 공백 무시)으로 설명을 찾는다. 없으면 nil.
    public static func summary(for name: String) -> String? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.first { $0.name == key }?.summary
    }
}
