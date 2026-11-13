import AVFoundation

/// 연습 중 횟수·남은 시간을 소리로 알려준다. 장갑 끼고 화면을 안 봐도 되게.
/// 다른 앱 음악은 잠깐 줄였다가 돌려놓는다. 기기 안 음성 합성만 쓴다(네트워크 없음).
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = 0.52
        synth.speak(u)
    }

    /// 5의 배수와 목표 도달 때만 말한다. 매번 말하면 시끄럽다.
    static func repLine(count: Int, target: Int) -> String? {
        if count == target { return "\(count)번. 목표 다 했어요" }
        if count > 0 && count % 5 == 0 { return "\(count)번" }
        return nil
    }
}
