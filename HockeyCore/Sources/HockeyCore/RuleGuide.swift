import Foundation

/// 규칙 도감 (8.2). IIHF Official Rule Book 2026/27(Version 1.0, 2026-06)과 대조해 확인한 내용만 자체 문구로 적는다.
/// 국내 대회·동호회마다 적용이 다를 수 있다.
public struct RuleQuiz: Equatable, Sendable {
    public let question: String
    public let options: [String]
    public let answer: Int
    public let explain: String
}

public struct RuleTopic: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let symbol: String
    public let summary: String
    public let points: [String]
    public let reference: String
    public let quiz: RuleQuiz
}

public enum RuleGuide {
    public static let source = "IIHF Official Rule Book 2026/27"

    public static let topics: [RuleTopic] = [
        RuleTopic(
            id: "offside", title: "오프사이드", symbol: "flag.fill",
            summary: "공격팀 선수가 퍽보다 먼저 상대 블루라인 안(공격 지역)에 들어가면 오프사이드야.",
            points: [
                "판단 기준은 스틱이 아니라 스케이트 날이야. 퍽이 블루라인을 완전히 넘는 순간 두 스케이트가 모두 라인을 넘어 있으면 오프사이드.",
                "한 발이라도 블루라인에 닿아 있거나 자기 쪽에 있으면 온사이드야.",
                "퍽을 스틱으로 컨트롤하며 몰고 들어가면 몸이 먼저 넘어가도 오프사이드가 아니야.",
                "수비팀이 퍽을 바로 걷어낼 수 있으면 선심이 '딜레이드 오프사이드'로 지켜봐. 공격팀이 모두 존 밖으로 나가 블루라인을 밟으면 다시 들어갈 수 있어.",
                "걸리면 보통 중립 지역 블루라인 가까운 점에서 페이스오프해. 슛이나 패스로 넘긴 경우엔 퍽이 출발한 지역의 가까운 점에서 할 수 있어.",
            ],
            reference: "Rule 83",
            quiz: RuleQuiz(question: "퍽이 블루라인을 넘는 순간, 내 한쪽 스케이트가 블루라인 위에 닿아 있었어. 오프사이드일까?",
                           options: ["오프사이드야", "온사이드야"], answer: 1,
                           explain: "한 발이라도 라인에 닿아 있으면 온사이드야.")),
        RuleTopic(
            id: "icing", title: "아이싱", symbol: "snowflake",
            summary: "자기 진영(센터 레드라인 뒤)에서 친 퍽이 아무도 안 건드리고 상대 골라인을 넘어가면 아이싱이야.",
            points: [
                "인원이 같거나 더 많은 팀에만 적용돼. 페널티로 한 명 적은(숏핸디드) 팀은 멀리 걷어내도 아이싱이 아니야.",
                "퍽을 스틱에 붙인 채로 센터 레드라인에 닿게 한 다음 치면 아이싱이 아니야.",
                "선심은 퍽을 향한 경주를 봐. 첫 선수가 엔드존 페이스오프 점에 닿을 때까지 누가 먼저 퍽을 만질지 판단하고, 너무 비슷하면 아이싱이야.",
                "골키퍼가 퍽을 처리하러 나오는 시늉만 해도 아이싱은 불지 않아.",
                "걸리면 아이싱한 팀의 수비 지역에서 페이스오프하고, 상대팀이 양쪽 점 중 하나를 골라. 아이싱한 팀은 그 전에 선수 교체를 못 해.",
            ],
            reference: "Rule 81",
            quiz: RuleQuiz(question: "우리 팀이 페널티로 한 명 적을 때, 우리 지역에서 퍽을 멀리 걷어내 상대 골라인을 넘겼어. 아이싱일까?",
                           options: ["아이싱이야", "아이싱이 아니야"], answer: 1,
                           explain: "숏핸디드인 팀에는 아이싱이 적용되지 않아.")),
        RuleTopic(
            id: "faceoff", title: "페이스오프", symbol: "circle.circle",
            summary: "심판이 마주 선 두 선수의 스틱 사이에 퍽을 떨어뜨려 경기를 시작하거나 다시 여는 거야.",
            points: [
                "두 센터는 상대 진영 쪽을 똑바로 보고, 스틱 하나 정도 떨어져서 블레이드를 정해진 흰 구역 얼음 위에 둬.",
                "엔드존·중립 지역 점에서는 수비 선수가 먼저 스틱을 두고, 센터 점에서는 원정팀이 먼저 둬.",
                "휘슬이 울리면 5초 안에 자리를 잡아야 해.",
                "퍽이 떨어지기 전에 움직이거나 스틱을 안 대는 등 위반하면 그 센터는 다른 선수로 바뀌어.",
                "같은 페이스오프에서 같은 팀이 두 번 위반하면 벤치 마이너 페널티야.",
            ],
            reference: "Rule 76",
            quiz: RuleQuiz(question: "센터 아이스 점에서 페이스오프할 때 스틱을 먼저 얼음에 두는 쪽은?",
                           options: ["홈팀", "원정팀"], answer: 1,
                           explain: "센터 점에서는 원정팀이 먼저 두고, 다른 점에서는 수비 선수가 먼저 둬.")),
        RuleTopic(
            id: "linechange", title: "라인체인지", symbol: "arrow.left.arrow.right",
            summary: "경기가 진행되는 중에도 벤치에서 선수를 바꿀 수 있어(온 더 플라이).",
            points: [
                "나가는 선수가 벤치 1.5m 안에 들어와 플레이에서 빠진 다음에 새 선수가 들어가야 해.",
                "교체하는 중에 들어오는 선수나 나가는 선수가 퍽을 건드리거나 상대와 부딪치면 '투 매니 플레이어'로 벤치 마이너 페널티야.",
                "경기가 멈추면 원정팀이 먼저 선수를 내보내고, 그다음 홈팀이 교체할 수 있어.",
                "아이싱한 팀은 다음 페이스오프 전까지 교체할 수 없어.",
            ],
            reference: "Rule 74 · Rule 82",
            quiz: RuleQuiz(question: "나가는 선수가 벤치에서 몇 m 안에 들어와야 새 선수가 들어갈 수 있을까?",
                           options: ["1.5m", "3m", "5m"], answer: 0,
                           explain: "벤치 1.5m 안에 들어와 플레이에서 빠져야 해.")),
        RuleTopic(
            id: "penalties", title: "주요 페널티", symbol: "exclamationmark.octagon",
            summary: "반칙을 하면 정해진 시간 동안 페널티 박스에 앉아 있어야 해.",
            points: [
                "마이너 2분: 대신 들어올 선수가 없어서 팀이 한 명 적게 뛰어(숏핸디드). 그동안 상대가 골을 넣으면 마이너는 바로 끝나.",
                "메이저 5분: 역시 한 명 적게 뛰고, 상대가 골을 넣어도 5분을 다 채워야 나올 수 있어.",
                "미스컨덕트 10분: 그 선수는 빠지지만 다른 선수가 바로 대신 들어올 수 있어. 한 경기에서 두 번째 미스컨덕트면 자동으로 게임 미스컨덕트야.",
                "게임 미스컨덕트: 그 경기 남은 시간 동안 퇴장이야. 다른 선수가 대신 들어올 수 있어(기록상 20분).",
            ],
            reference: "Rule 16 · 20 · 22 · 23",
            quiz: RuleQuiz(question: "우리 팀이 마이너 페널티로 한 명 적을 때 상대가 골을 넣으면?",
                           options: ["페널티 시간이 그대로 남아", "그 마이너 페널티가 바로 끝나"], answer: 1,
                           explain: "숏핸디드일 때 실점하면 남은 시간이 가장 짧은 마이너 페널티가 끝나.")),
        RuleTopic(
            id: "positions", title: "포지션", symbol: "person.3.fill",
            summary: "정상 인원일 때 한 팀은 골키퍼 1명과 스케이터 5명, 모두 6명이 얼음 위에서 뛰어.",
            points: [
                "규정상 한 팀 명단은 최대 22명(스케이터 20명, 골키퍼 2명)이고, 경기를 시작하려면 스케이터 5명과 골키퍼 1명이 있어야 해.",
                "스케이터는 보통 공격수 3명(센터 1명, 양쪽 윙 2명)과 수비수 2명으로 나눠. 이 이름은 흔히 쓰는 하키 용어야.",
                "센터는 페이스오프를 맡고 공격과 수비를 이어 줘. 윙은 측면에서 공격하고, 수비수는 블루라인 근처에서 우리 골문 앞을 지켜.",
                "골키퍼는 골문을 지켜. 공격 막판에 골키퍼를 빼고 스케이터를 한 명 더 넣기도 해.",
            ],
            reference: "Rule 5",
            quiz: RuleQuiz(question: "정상 인원일 때 한 팀은 얼음 위에 모두 몇 명이 뛸까?",
                           options: ["5명", "6명", "7명"], answer: 1,
                           explain: "골키퍼 1명과 스케이터 5명, 모두 6명이야.")),
    ]
}
