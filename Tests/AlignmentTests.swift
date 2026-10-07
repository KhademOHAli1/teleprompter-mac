// SPDX-License-Identifier: MIT
import Foundation

@main struct AlignmentTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if !condition() { print("FAIL: \(name)"); exit(1) }
        print("PASS: \(name)")
    }
    static func germanScript(_ text: String) -> PromptScript { PromptScript(text, locale: Locale(identifier: "de-DE")) }
    static func main() {
        let repeated = germanScript("Hallo Welt. Hallo Welt. Heute geht es weiter.")
        var tracker = WordTracker(script: repeated)
        expect(tracker.consume("Hallo", utterance: "a") == 0, "First word")
        expect(tracker.consume("Hallo Welt", utterance: "a") == 1, "Growing partial")
        expect(tracker.consume("Hallo Welt", utterance: "a") == nil && tracker.cursor == 1, "Final replay does not advance")
        expect(tracker.consume("Hallo", utterance: "b") == 2, "Repeated phrase uses next utterance")
        expect(tracker.consume("Hallo Welt", utterance: "b") == 3, "Second repeated phrase")
        expect(tracker.consume("Hallo", utterance: "a") == nil && tracker.cursor == 3, "Late revision does not rewind")
        expect(tracker.consume("Heute geht es weiter", utterance: "c") == repeated.words.count - 1, "Sentence transition")

        var fillers = WordTracker(script: germanScript("Wir brauchen heute mehr Sicherheit und echte Chancen."))
        expect(fillers.consume("Wir brauchen heute äh mehr Sicherheit", utterance: "1") == 4, "Spoken filler")
        expect(fillers.consume("Wir brauchen heute äh mehr Sicherheit und Chancen", utterance: "1") == 7, "Skipped script word")
        let saved = fillers.cursor
        expect(fillers.consume("Das Wetter im Oktober ist regnerisch", utterance: "2") == nil && fillers.cursor == saved, "Unrelated speech holds position")

        var corrected = WordTracker(script: germanScript("Die Gleichstellung braucht bessere Bedingungen für alle Menschen."))
        expect(corrected.consume("Die Gleichstelung braucht", utterance: "1") == 2, "German recognition typo")
        expect(corrected.consume("Die Gleichstellung braucht", utterance: "1") == nil && corrected.cursor == 2, "Corrected partial stays stable")
        expect(corrected.consume("Die Gleichstellung braucht bessere Bedingungen für alle Menschen", utterance: "1") == 7, "Correction continues")

        var compounds = WordTracker(script: germanScript("Wir wollen mehr Geschlechtergerechtigkeit im Aufenthaltsrecht."))
        expect(compounds.consume("Wir wollen mehr Geschlechter Gerechtigkeit im Aufenthaltsrecht", utterance: "1") == 5, "Split German compound")
        var joins = WordTracker(script: germanScript("Dieser Tele Prompter folgt meiner Stimme."))
        expect(joins.consume("Dieser Teleprompter folgt meiner Stimme", utterance: "1") == 5, "Joined German compound")
        var numbers = WordTracker(script: germanScript("Im Jahr 2026 brauchen wir 25 neue Wohnungen."))
        expect(numbers.consume("Im Jahr zweitausendsechsundzwanzig brauchen wir fünfundzwanzig neue Wohnungen", utterance: "1") == 7, "German spoken numbers")
        expect(WordNormalizer.normalize("Straße") == WordNormalizer.normalize("Strasse"), "Sharp S normalization")
        expect(WordNormalizer.normalize("für") == WordNormalizer.normalize("fur"), "Umlaut normalization")

        var seek = WordTracker(script: repeated)
        seek.seek(nextWord: 4)
        expect(seek.cursor == 3, "Manual seek")
        expect(seek.consume("Heute geht", utterance: "new") == 5, "Recognition after manual seek")
        seek.seek(nextWord: 0)
        expect(seek.consume("Hallo Welt", utterance: "again") == 1, "Restart from beginning")

        var isolated = WordTracker(script: germanScript("Wir sprechen heute über Wohnungen und neue Chancen für alle Menschen."))
        expect(isolated.consume("Menschen", utterance: "1") == nil, "Single distant word cannot jump")
        var long = WordTracker(script: germanScript((0..<100).map { "Wort\($0)" }.joined(separator: " ")))
        for end in 1...100 {
            let spoken = (0..<end).map { "Wort\($0)" }.joined(separator: " ")
            _ = long.consume(spoken, utterance: "long")
        }
        expect(long.cursor == 99, "Long cumulative partial stream")
        let unicode = germanScript("„Grüße“, sagt sie. Danach: Straße, Größe und Möglichkeiten.")
        expect(unicode.words.allSatisfy { (unicode.text as NSString).substring(with: $0.range) == $0.text }, "Unicode highlight ranges")
        expect(unicode.sentenceStarts.count == 2, "German sentence boundaries")
        expect(germanScript("   \n").words.isEmpty, "Empty script")
        expect(tracker.consume("", utterance: "empty") == nil, "Empty transcript")
        expect(tracker.confidence == 0, "Empty transcript clears stale match confidence")
        let cues = germanScript("[LANGSAM. BLICK NACH VORN.]\nHallo Welt.\n[PAUSE 1 SEK.]\nHeute geht es weiter.")
        expect(cues.words.count == 6 && cues.words.first?.text == "Hallo", "Stage directions are not spoken words")
        expect(cues.stageDirections.count == 2, "Multi-sentence stage direction ranges")
        expect(cues.sentenceStarts == [0, 2] && cues.sentence(at: 2) == 1, "Sentence navigation skips stage directions")
        var cuedTracker = WordTracker(script: cues)
        expect(cuedTracker.consume("Hallo", utterance: "a") == 0, "First spoken word follows immediately after cue")
        expect(cuedTracker.consume("Hallo Welt", utterance: "a") == 1 &&
               cuedTracker.consume("Heute geht es weiter", utterance: "b") == 5, "Recognition crosses unspoken pause cue")
        print("\(checks) checks passed.")
    }
}
