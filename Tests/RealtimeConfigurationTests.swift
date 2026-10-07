// SPDX-License-Identifier: MIT
import Foundation

@main struct RealtimeConfigurationTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if !condition() { print("FAIL: \(name)"); exit(1) }
        print("PASS: \(name)")
    }
    static func germanScript(_ text: String) -> PromptScript { PromptScript(text, locale: Locale(identifier: "de-DE")) }
    static func main() throws {
        let script = germanScript("[PAUSE] Willkommen Willkommen im Testprogramm.")
        let event = RealtimeConfiguration.session(script: script, delay: "low")
        let session = event["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let format = input["format"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        expect(event["type"] as? String == "session.update" && session["type"] as? String == "transcription",
               "Dedicated transcription session")
        expect(format["type"] as? String == "audio/pcm" && format["rate"] as? Int == 24000,
               "Realtime PCM sample rate")
        expect(transcription["model"] as? String == "gpt-live-transcribe", "Explicit live model")
        expect(transcription["languages"] as? [String] == ["de"] && transcription["language"] == nil,
               "Plural German language hint")
        expect(input["turn_detection"] is NSNull, "Live model does not use server VAD")
        expect(transcription["delay"] as? String == "low", "Supported delay is preserved")
        let keywords = transcription["keywords"] as! [String]
        expect(keywords == ["Testprogramm", "Willkommen"], "Keywords are unique, sorted and exclude cues")
        expect(event["key"] == nil && session["api_key"] == nil, "Configuration contains no credential")
        expect((try? JSONSerialization.data(withJSONObject: event)) != nil, "Configuration serializes as JSON")
        let many = germanScript((0..<100).map { "Begriff\($0)" }.joined(separator: " "))
        let manySession = RealtimeConfiguration.session(script: many, delay: "unsupported")["session"] as! [String: Any]
        let manyAudio = manySession["audio"] as! [String: Any]
        let manyInput = manyAudio["input"] as! [String: Any]
        let manyTranscription = manyInput["transcription"] as! [String: Any]
        expect((manyTranscription["keywords"] as! [String]).count == 60, "Vocabulary hints are bounded")
        expect(manyTranscription["delay"] as? String == "minimal", "Invalid delay falls back safely")
        print("\(checks) realtime configuration checks passed.")
    }
}
