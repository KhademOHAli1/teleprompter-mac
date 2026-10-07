// SPDX-License-Identifier: MIT
import Foundation

enum L10n {
    static func text(_ key: String, _ arguments: String...) -> String {
        let format = NSLocalizedString(key, bundle: .main, value: key, comment: "")
        return arguments.enumerated().reduce(format) { value, item in
            value.replacingOccurrences(of: "{\(item.offset)}", with: item.element)
        }
    }

    static func number(_ value: Int) -> String { value.formatted(.number.locale(.current)) }
}

enum SpeechLanguage {
    static let common = ["en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "es-MX", "pt-BR", "pt-PT", "it-IT", "nl-NL", "da-DK", "sv-SE", "nb-NO", "fi-FI", "pl-PL", "cs-CZ", "sk-SK", "hu-HU", "ro-RO", "el-GR", "tr-TR", "ru-RU", "uk-UA", "ar-SA", "he-IL", "fa-IR", "hi-IN", "bn-IN", "ta-IN", "te-IN", "id-ID", "ms-MY", "vi-VN", "th-TH", "ja-JP", "ko-KR", "zh-CN", "zh-TW", "zh-HK"]

    static var systemIdentifier: String {
        Locale.preferredLanguages.first ?? Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }
    static func locale(_ selection: String) -> Locale {
        Locale(identifier: selection == "system" ? systemIdentifier : selection)
    }
    static func name(_ identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }
    static func apiCode(_ locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        if language == "zh", let region = locale.region?.identifier, ["CN", "TW", "HK"].contains(region) {
            return "zh-" + region.lowercased()
        }
        return language
    }
    static func demo(_ locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let sample = ["en", "de", "fr", "es"].contains(language) ? language : "en"
        guard let path = Bundle.main.path(forResource: "Demo", ofType: "txt", inDirectory: nil, forLocalization: sample),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "Welcome. This teleprompter follows my voice. I can pause and continue at my own pace."
        }
        return text
    }
}
