// SPDX-License-Identifier: MIT
import Foundation
import NaturalLanguage

struct ScriptWord: Equatable {
    let text: String
    let normalized: String
    let range: NSRange
    let sentence: Int
}

struct PromptScript: Equatable {
    let text: String
    let locale: Locale
    let words: [ScriptWord]
    let sentenceStarts: [Int]
    let stageDirections: [NSRange]

    init(_ source: String, locale: Locale = .current) {
        self.locale = locale
        let language = NLLanguage(rawValue: locale.language.languageCode?.identifier ?? "en")
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = source
        tokenizer.setLanguage(language)
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: source.startIndex..<source.endIndex) { range, _ in
            let sentence = source[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        if sentences.isEmpty && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sentences = [source]
        }
        var rendered = ""
        var tokens: [ScriptWord] = []
        for (sentenceID, sentence) in sentences.enumerated() {
            if !rendered.isEmpty { rendered += "\n\n" }
            let offset = (rendered as NSString).length
            for match in WordNormalizer.matches(sentence, locale: locale) {
                let word = (sentence as NSString).substring(with: match)
                tokens.append(ScriptWord(text: word, normalized: WordNormalizer.normalize(word, locale: locale),
                                         range: NSRange(location: offset + match.location,
                                                        length: match.length), sentence: sentenceID))
            }
            rendered += sentence
        }
        text = rendered
        let cueExpression = try! NSRegularExpression(pattern: #"\[[^\]]*\]"#)
        let cues = cueExpression.matches(in: rendered,
                                        range: NSRange(location: 0, length: (rendered as NSString).length)).map(\.range)
        stageDirections = cues
        let spoken = tokens.filter { word in
            !cues.contains { NSIntersectionRange($0, word.range).length > 0 }
        }
        var spokenWords: [ScriptWord] = []
        var spokenStarts: [Int] = []
        var previousSentence = -1
        for word in spoken {
            if word.sentence != previousSentence {
                spokenStarts.append(spokenWords.count)
                previousSentence = word.sentence
            }
            spokenWords.append(ScriptWord(text: word.text, normalized: word.normalized,
                                          range: word.range, sentence: spokenStarts.count - 1))
        }
        words = spokenWords
        sentenceStarts = spokenStarts
    }

    func sentence(at word: Int) -> Int {
        guard !words.isEmpty else { return 0 }
        return words[max(0, min(word, words.count - 1))].sentence
    }
}

enum WordNormalizer {
    static func matches(_ text: String, locale: Locale = .current) -> [NSRange] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(NLLanguage(rawValue: locale.language.languageCode?.identifier ?? "en"))
        var ranges: [NSRange] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if text[range].contains(where: { $0.isLetter || $0.isNumber }) { ranges.append(NSRange(range, in: text)) }
            return true
        }
        return ranges
    }

    static func normalize(_ word: String, locale: Locale = .current) -> String {
        var value = word.lowercased(with: locale).replacingOccurrences(of: "ß", with: "ss")
        if let number = Int(value), number >= 0, number < 1_000_000 {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .spellOut
            if let spoken = formatter.string(from: NSNumber(value: number)) { value = spoken }
        }
        // Strip optional Latin accents, preserving meaningful marks in other scripts.
        if value.range(of: #"\p{Latin}"#, options: .regularExpression) != nil {
            value = value.folding(options: [.diacriticInsensitive], locale: locale)
        }
        return value.filter { $0.isLetter || $0.isNumber || $0.unicodeScalars.contains { CharacterSet.nonBaseCharacters.contains($0) } }
    }

    static func tokens(_ text: String, locale: Locale = .current) -> [String] {
        matches(text, locale: locale).map { normalize((text as NSString).substring(with: $0), locale: locale) }.filter { !$0.isEmpty }
    }

    static func similarity(_ left: String, _ right: String) -> Double {
        if left == right { return 1 }
        guard min(left.count, right.count) >= 5 else { return 0 }
        let a = Array(left), b = Array(right)
        guard abs(a.count - b.count) <= max(2, max(a.count, b.count) / 4) else { return 0 }
        var previous = Array(0...b.count)
        for (i, character) in a.enumerated() {
            var row = [i + 1]
            for j in 0..<b.count {
                row.append(min(row[j] + 1, previous[j + 1] + 1,
                               previous[j] + (character == b[j] ? 0 : 1)))
            }
            previous = row
        }
        let similarity = 1 - Double(previous.last!) / Double(max(a.count, b.count))
        return similarity >= 0.78 ? similarity : 0
    }
}

/// Bounded sequence alignment. Partial revisions share a fixed utterance anchor,
/// so replaying a growing ASR result cannot consume the same phrase twice.
struct WordTracker {
    struct Utterance {
        let anchor: Int
        var lastTokens: [String] = []
    }
    struct Cell {
        var score: Double = 0
        var matches = 0
        var exact = 0
        var start = -1
        var lastHeard = -1
        var lastScript = -1
    }
    private(set) var cursor = -1
    private(set) var confidence: Double = 0
    private var utterances: [String: Utterance] = [:]
    private var order: [String] = []
    private var script: PromptScript

    init(script: PromptScript) { self.script = script }

    mutating func seek(nextWord: Int) {
        cursor = max(-1, min(nextWord - 1, script.words.count - 1))
        confidence = 0
        utterances.removeAll()
        order.removeAll()
    }

    @discardableResult
    mutating func consume(_ transcript: String, utterance id: String) -> Int? {
        let allHeard = WordNormalizer.tokens(transcript, locale: script.locale)
        guard !allHeard.isEmpty, !script.words.isEmpty else {
            confidence = 0
            return nil
        }
        if utterances[id] == nil {
            utterances[id] = Utterance(anchor: cursor + 1)
            order.append(id)
            if order.count > 80 { utterances.removeValue(forKey: order.removeFirst()) }
        }
        var utterance = utterances[id]!
        guard utterance.lastTokens != allHeard else { return nil }
        utterance.lastTokens = allHeard
        utterances[id] = utterance
        let heard = Array(allHeard.suffix(32))
        let expectedEnd = min(script.words.count - 1, utterance.anchor + allHeard.count - 1)
        let start = max(0, min(cursor - 18, expectedEnd - heard.count - 12))
        let end = min(script.words.count, max(cursor + 72, expectedEnd + 32))
        guard end > start else { return nil }
        let referenceWords = script.words[start..<end]
        let reference = referenceWords.map(\.normalized)
        let numerals = referenceWords.map { $0.text.allSatisfy(\.isNumber) }
        let english = script.locale.language.languageCode?.identifier == "en"
        let n = heard.count, m = reference.count
        var table = Array(repeating: Array(repeating: Cell(), count: m + 1), count: n + 1)
        for i in 1...n {
            for j in 1...m {
                var choices = [Cell()]
                let similarity = WordNormalizer.similarity(heard[i - 1], reference[j - 1])
                var diagonal = table[i - 1][j - 1]
                diagonal.score += similarity > 0 ? 3 * similarity : -2.4
                if similarity > 0 {
                    diagonal.matches += 1
                    if similarity == 1 { diagonal.exact += 1 }
                    if diagonal.start < 0 { diagonal.start = j - 1 }
                    diagonal.lastHeard = i - 1
                    diagonal.lastScript = j - 1
                }
                choices.append(diagonal)
                var filler = table[i - 1][j]; filler.score -= 1.2; choices.append(filler)
                var skipped = table[i][j - 1]; skipped.score -= 1.7; choices.append(skipped)
                // Match bounded joined/split words and multi-word spoken numerals.
                if i >= 2 {
                    for length in 2...min(8, i) {
                        let span = heard[(i - length)..<i]
                        let joined = span.joined()
                        let numeral = numerals[j - 1]
                        let englishNumber = numeral && english && span.filter { $0 != "and" }.joined() == reference[j - 1]
                        guard joined == reference[j - 1] || englishNumber else { continue }
                        var merged = table[i - length][j - 1]
                        merged.score += Double(length) * 3 - 1
                        merged.matches += length; merged.exact += length
                        if merged.start < 0 { merged.start = j - 1 }
                        merged.lastHeard = i - 1; merged.lastScript = j - 1
                        choices.append(merged)
                    }
                }
                if j >= 2 {
                    for length in 2...min(8, j) where reference[(j - length)..<j].joined() == heard[i - 1] {
                        var merged = table[i - 1][j - length]
                        merged.score += Double(length) + 2
                        merged.matches += 1; merged.exact += 1
                        if merged.start < 0 { merged.start = j - length }
                        merged.lastHeard = i - 1; merged.lastScript = j - 1
                        choices.append(merged)
                    }
                }
                table[i][j] = choices.max(by: { $0.score < $1.score })!
            }
        }
        var best: (index: Int, quality: Double, rank: Double)?
        for j in 1...m {
            let cell = table[n][j]
            let candidate = start + cell.lastScript
            guard cell.lastScript == j - 1, cell.lastHeard >= n - 2,
                  cell.matches > 0, candidate >= cursor else { continue }
            let quality = Double(cell.matches) / Double(n)
            let jump = candidate - cursor
            guard quality >= 0.48 else { continue }
            if jump > 3 && cell.exact < 2 { continue }
            if jump > 12 && cell.exact < 3 { continue }
            if jump > 35 && cell.exact < 5 { continue }
            if n == 1 && jump > 2 { continue }
            // Prefer the expected occurrence when the script repeats a phrase.
            let rank = cell.score - 0.12 * Double(abs(candidate - expectedEnd))
            if best == nil || rank > best!.rank {
                best = (candidate, quality, rank)
            }
        }
        guard let best else { confidence = 0; return nil }
        confidence = min(1, best.quality)
        guard best.index > cursor else { return nil }
        cursor = best.index
        return cursor
    }
}
