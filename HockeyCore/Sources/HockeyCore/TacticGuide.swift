import Foundation

/// 전술 노트. 동호회 경기에서 자주 쓰는 기본 움직임을 쉽게 풀어 쓴다.
/// 규칙과 달리 정답이 없고 팀·코치마다 다르게 쓴다.
public struct TacticTopic: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let tag: String
    public let summary: String
    public let points: [String]
    public let when: String
    public let practice: String
}

public enum TacticGuide {
    public static let topics: [TacticTopic] = [
        TacticTopic(
            id: "forecheck-121", title: "1-2-1 포어체크", tag: "포어체크",
            summary: "한 명은 깊이 들어가 퍽을 쫓고, 두 명은 양옆, 한 명은 뒤에 남는 배치야.",
            points: [
                "첫 번째 선수(F1)는 퍽 가진 상대에게 곧장 붙어. 한쪽 보드로 몰아.",
                "두 번째 줄 두 명은 양쪽 보드 쪽에 서서 위로 가는 패스를 막아.",
                "마지막 한 명은 블루라인 근처에서 뒤를 지켜. 퍽이 빠지면 바로 내려와.",
            ],
            when: "점수를 따라가야 할 때, 상대 수비가 퍽 다루는 게 서툴 때.",
            practice: "F1은 퍽이 아니라 몸 쪽으로 각을 잡고 들어가봐. 보드 쪽으로만 몰면 반은 성공이야."),
        TacticTopic(
            id: "forecheck-122", title: "1-2-2 포어체크", tag: "포어체크",
            summary: "한 명만 들어가 방향을 정하고, 나머지는 자리를 지키며 기다려.",
            points: [
                "F1은 깊이 들어가되 무리하게 뺏지 않아. 퍽을 한쪽으로 보내는 게 목표야.",
                "F2·F3는 원 위쪽에서 패스 길을 읽어. 퍽이 오는 쪽 선수가 붙어.",
                "수비 두 명은 블루라인을 지켜. 상대가 빠르게 넘어오지 못하게 해.",
            ],
            when: "앞서고 있을 때, 체력을 아껴야 할 때, 상대가 빠를 때.",
            practice: "퍽이 보드로 가는 순간 그쪽 F2가 바로 붙는 타이밍을 맞춰봐."),
        TacticTopic(
            id: "breakout", title: "브레이크아웃", tag: "수비 지역",
            summary: "우리 지역에서 퍽을 되찾은 뒤 윙에게 연결해 밖으로 몰고 나가는 첫 패스야.",
            points: [
                "수비수가 골대 뒤에서 퍽을 잡아. 고개를 들고 압박이 어디서 오는지 봐.",
                "윙은 보드 쪽 해시마크 근처로 내려와서 패스를 받아.",
                "센터는 가운데 낮게 받쳐줘. 윙이 막히면 센터가 받아서 나가.",
                "반대쪽 수비수는 골대 앞을 지키다가 따라 올라가.",
            ],
            when: "우리 진영에서 퍽을 되찾았을 때마다.",
            practice: "윙은 보드에 등을 붙이고 받는 연습부터. 받자마자 블루라인 쪽으로 첫발을 떼봐."),
        TacticTopic(
            id: "board-house", title: "보드 리턴 후 골대 앞", tag: "공격",
            summary: "보드를 맞혀 동료에게 주고, 곧장 골대 앞 슬롯으로 파고들어 다시 받아.",
            points: [
                "슬롯은 골대 바로 앞, 두 페이스오프 점 사이야. 슛이 가장 잘 들어가는 자리야.",
                "퍽을 가진 선수는 보드를 이용해 뒤쪽 동료에게 퍽을 보내.",
                "패스를 준 선수는 멈추지 말고 바로 슬롯으로 들어가. 받자마자 쏠 수 있게 스틱을 얼음에 대고 있어.",
            ],
            when: "공격 지역에서 수비가 보드 쪽으로 쏠렸을 때.",
            practice: "패스 주고 멈추지 말기. 주고-들어가기를 한 동작처럼 이어서 연습해봐."),
        TacticTopic(
            id: "cycle", title: "사이클", tag: "공격",
            summary: "코너에서 퍽을 지키며 동료에게 넘기고, 돌고 돌면서 빈틈을 기다려.",
            points: [
                "퍽을 가진 선수는 몸으로 퍽을 가리며 보드를 따라 내려가.",
                "뒤따라오는 동료에게 보드 쪽으로 퍽을 남겨두고 빠져.",
                "빠진 선수는 위로 돌아 다시 받을 자리를 잡아. 이렇게 계속 돌려.",
                "수비가 따라오다 벌어지면 그때 골대 앞으로 패스해.",
            ],
            when: "공격 지역에서 오래 퍽을 갖고 상대를 지치게 하고 싶을 때.",
            practice: "두 명이 한 코너에서 퍽 남기고 빠지기를 반복해봐. 고개 들기가 핵심이야."),
    ]
}
