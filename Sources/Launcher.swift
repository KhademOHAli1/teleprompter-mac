// SPDX-License-Identifier: MIT
import Foundation
import Speech
import AVFoundation

@main struct Launcher {
    static func main() async {
        if CommandLine.arguments.contains("--prepare-model") {
            do {
                let transcriber = try await LocalSpeechSession.makeTranscriber()
                try await LocalSpeechSession.ensureAssets(transcriber) { print($0) }
                print("Deutsches Sprachmodell bereit.")
            } catch { print("FEHLER: \(error.localizedDescription)"); exit(1) }
        } else if let index = CommandLine.arguments.firstIndex(of: "--transcribe-file"),
                  CommandLine.arguments.count > index + 1 {
            do {
                let transcriber = try await LocalSpeechSession.makeTranscriber()
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
            } catch { print("FEHLER: \(error.localizedDescription)"); exit(1) }
        } else {
            TeleprompterApp.main()
        }
    }
}
