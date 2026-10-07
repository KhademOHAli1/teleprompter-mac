// SPDX-License-Identifier: MIT
import Foundation
import Speech
import AVFoundation

@main struct Launcher {
    static func main() async {
        if CommandLine.arguments.contains("--prepare-model") {
            do {
                let localeIndex = CommandLine.arguments.firstIndex(of: "--locale")
                let language = localeIndex.flatMap { CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil } ?? "system"
                let transcriber = try await LocalSpeechSession.makeTranscriber(locale: SpeechLanguage.locale(language))
                try await LocalSpeechSession.ensureAssets(transcriber) { print($0) }
                print(L10n.text("Speech model ready."))
            } catch { print(L10n.text("Error: {0}", error.localizedDescription)); exit(1) }
        } else if let index = CommandLine.arguments.firstIndex(of: "--transcribe-file"),
                  CommandLine.arguments.count > index + 1 {
            do {
                let localeIndex = CommandLine.arguments.firstIndex(of: "--locale")
                let language = localeIndex.flatMap { CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil } ?? "system"
                let transcriber = try await LocalSpeechSession.makeTranscriber(locale: SpeechLanguage.locale(language))
                try await LocalSpeechSession.ensureAssets(transcriber) { print($0) }
                let file = try AVAudioFile(forReading: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                let analyzer = SpeechAnalyzer(modules: [transcriber])
                let consumer = Task {
                    for try await result in transcriber.results {
                        print("\(result.isFinal ? "FINAL" : "PARTIAL") \(String(format: "%.3f", CMTimeGetSeconds(result.range.start))) \(String(result.text.characters))")
                    }
                }
                _ = try await analyzer.analyzeSequence(from: file)
                try await analyzer.finalizeAndFinishThroughEndOfInput()
                try await consumer.value
            } catch { print(L10n.text("Error: {0}", error.localizedDescription)); exit(1) }
        } else {
            TeleprompterApp.main()
        }
    }
}
