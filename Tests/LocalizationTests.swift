// SPDX-License-Identifier: MIT
import Foundation

@main struct LocalizationTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if !condition() { print("FAIL: \(name)"); exit(1) }
        print("PASS: \(name)")
    }
    static func main() {
        let examples = [
            ("en-GB", "We need 135 new ideas.", "We need one hundred and thirty five new ideas"),
            ("fr-FR", "Nous avons 25 nouvelles idées.", "Nous avons vingt cinq nouvelles idées"),
            ("es-ES", "Tenemos 32 ideas nuevas.", "Tenemos treinta y dos ideas nuevas")
        ]
        for (locale, text, spoken) in examples {
            let script = PromptScript(text, locale: Locale(identifier: locale))
            var tracker = WordTracker(script: script)
            expect(tracker.consume(spoken, utterance: "a") == script.words.count - 1, "Spoken numerals in \(locale)")
        }
        for (locale, text) in [("zh-CN", "[停顿]你好世界。今天我们一起阅读。"), ("ja-JP", "こんにちは世界。今日は一緒に読みます。"), ("ar-SA", "مرحباً بالعالم. نحن نقرأ هذا النص.")] {
            let script = PromptScript(text, locale: Locale(identifier: locale))
            expect(script.words.count > 3, "Word segmentation in \(locale)")
            expect(script.words.allSatisfy { (script.text as NSString).substring(with: $0.range) == $0.text }, "UTF-16 ranges in \(locale)")
            var tracker = WordTracker(script: script)
            expect(tracker.consume(script.words.map(\.text).joined(separator: " "), utterance: "a") == script.words.count - 1, "Tracking in \(locale)")
        }
        expect(WordNormalizer.normalize("कला", locale: Locale(identifier: "hi")) != WordNormalizer.normalize("कल", locale: Locale(identifier: "hi")), "Preserve meaningful non-Latin marks")
        expect(WordNormalizer.normalize("İstanbul", locale: Locale(identifier: "tr-TR")) == WordNormalizer.normalize("istanbul", locale: Locale(identifier: "tr-TR")), "Turkish case mapping")
        expect(SpeechLanguage.apiCode(Locale(identifier: "en-GB")) == "en", "English API hint")
        expect(SpeechLanguage.apiCode(Locale(identifier: "zh-TW")) == "zh-tw", "Chinese regional API hint")
        let root = CommandLine.arguments[1]
        for (language, expected) in [("en", "Start reading"), ("de", "Vorlesen starten"), ("fr", "Commencer la lecture"), ("es", "Iniciar lectura")] {
            let bundle = Bundle(path: root + "/" + language + ".lproj")
            expect(bundle?.localizedString(forKey: "Start reading", value: nil, table: nil) == expected, "Platform string bundle \(language)")
        }
        print("\(checks) localization checks passed.")
    }
}
