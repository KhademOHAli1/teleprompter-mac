// SPDX-License-Identifier: MIT
import Foundation

/// Pure configuration, so schema checks never need a key or a network request.
enum RealtimeConfiguration {
    static let model = "gpt-live-transcribe"
    static let sampleRate = 24000
    static let keywordLimit = 60
    static let supportedDelays: Set<String> = ["minimal", "low", "medium", "high", "xhigh"]

    static func session(script: PromptScript, delay: String) -> [String: Any] {
        let keywords = Array(Set(script.words.map(\.text).filter {
            $0.count >= 5 && $0.first?.isUppercase == true
        })).sorted().prefix(keywordLimit).map { $0 }
        return ["type": "session.update", "session": [
            "type": "transcription", "audio": ["input": [
                "format": ["type": "audio/pcm", "rate": sampleRate],
                "transcription": [
                    "model": model, "languages": [SpeechLanguage.apiCode(script.locale)],
                    "delay": supportedDelays.contains(delay) ? delay : "minimal",
                    "prompt": "A person is reading a teleprompter script in its original language. Transcribe without translating.",
                    "keywords": keywords
                ],
                "turn_detection": NSNull()
            ]]
        ]]
    }
}
