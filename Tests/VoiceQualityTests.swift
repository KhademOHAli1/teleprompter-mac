// SPDX-License-Identifier: MIT
import Foundation

@main struct VoiceQualityTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if !condition() { print("FAIL: \(name)"); exit(1) }
        print("PASS: \(name)")
    }
    static func metrics(_ samples: [Float]) -> AudioMetrics {
        samples.withUnsafeBufferPointer { AudioMetrics(samples: $0, sampleRate: 48000) }
    }
    static func main() {
        let silent = metrics([0, 0, 0, 0])
        expect(silent.rms == 0 && silent.peak == 0 && silent.clippedFraction == 0,
               "Silence produces no signal or clipping")
        let known = metrics([0.1, -0.1, 0.1, -0.1])
        expect(abs(known.rms - 0.1) < 0.000001 && abs(known.peak - 0.1) < 0.000001,
               "RMS and peak use normalized sample amplitude")
        expect(abs(known.duration - 4.0 / 48000) < 0.000001, "Buffer duration")
        let clipped = metrics([1, -1, 0.2, -0.2])
        expect(clipped.peak == 1 && clipped.clippedFraction == 0.5, "Clipped sample proportion")
        expect(metrics([]).rms == 0 && metrics([]).duration == 0, "Empty buffer is safe")
        expect(metrics([.nan, .infinity, -.infinity]).rms == 0, "Invalid samples cannot make a healthy signal")

        var monitor = VoiceQualityMonitor()
        let normal = AudioMetrics(rms: 0.08, peak: 0.4)
        monitor.consumeAudio(normal, at: 0)
        expect(monitor.reading(at: 0) == .inactive, "Inactive microphone ignores callbacks")
        monitor.start()
        expect(monitor.reading(at: 0).state == .waiting, "Starting does not claim good reception")
        monitor.consumeAudio(normal, at: 0)
        expect(monitor.reading(at: 0).state == .pending, "Good volume alone is not green recognition")
        monitor.consumeRecognition(confidence: 0.9, at: 0.1)
        expect(monitor.reading(at: 0.1).state == .good, "Recent script match and target volume are green")
        monitor.consumeRecognition(confidence: 0, at: 0.2)
        expect(monitor.reading(at: 0.2).state == .good, "Brief partial corrections do not flicker")
        monitor.consumeAudio(normal, at: 1.2)
        expect(monitor.reading(at: 1.2).state == .unclear, "Persistent mismatch becomes uncertain")
        monitor.consumeRecognition(confidence: 0.9, at: 1.3)
        expect(monitor.reading(at: 1.3).state == .good, "Matching text recovers")
        monitor.consumeAudio(silent, at: 2.2)
        expect(monitor.reading(at: 2.2).state == .pause && monitor.reading(at: 2.2).position == nil,
               "A speaking pause is neutral despite previous good recognition")
        monitor.consumeAudio(normal, at: 4)
        expect(monitor.reading(at: 4).state == .unclear, "Old match cannot stay green indefinitely")
        expect(monitor.reading(at: 5).state == .waiting, "Missing audio callbacks cannot stay green")
        monitor.stop()
        monitor.consumeRecognition(confidence: 1, at: 5)
        expect(monitor.reading(at: 5) == .inactive, "Stopping clears the meter and delayed results")
        monitor.start()
        monitor.consumeAudio(normal, at: 6)
        expect(monitor.reading(at: 6).state == .pending, "Restart forgets prior recognition")

        var quiet = VoiceQualityMonitor(); quiet.start()
        quiet.consumeAudio(AudioMetrics(rms: 0.005, peak: 0.02), at: 0)
        quiet.consumeRecognition(confidence: 1, at: 0)
        expect(quiet.reading(at: 0).state == .quiet, "Quiet input warns even when words match")
        var loud = VoiceQualityMonitor(); loud.start()
        loud.consumeAudio(AudioMetrics(rms: 0.4, peak: 0.8), at: 0)
        loud.consumeRecognition(confidence: 1, at: 0)
        expect(loud.reading(at: 0).state == .loud, "Loud input warns even when words match")
        var peaks = VoiceQualityMonitor(); peaks.start()
        peaks.consumeAudio(AudioMetrics(rms: 0.08, peak: 1, clippedFraction: 0.004), at: 0)
        peaks.consumeRecognition(confidence: 1, at: 0)
        expect(peaks.reading(at: 0).state == .clipping, "Peak warning overrides target average volume")
        peaks.consumeAudio(normal, at: 0.2)
        expect(peaks.reading(at: 0.2).state == .clipping, "Peak warning remains visible briefly")
        peaks.consumeAudio(normal, at: 0.8)
        expect(peaks.reading(at: 0.8).state == .good, "Peak warning clears after healthy audio")
        var initialSilence = VoiceQualityMonitor(); initialSilence.start()
        initialSilence.consumeAudio(silent, at: 0)
        initialSilence.consumeRecognition(confidence: 1, at: 0)
        expect(initialSilence.reading(at: 0).state == .waiting, "Recognition cannot turn silence green")

        expect(abs(VoiceQualityMonitor.position(decibels: -34) - 0.35) < 0.000001 &&
               abs(VoiceQualityMonitor.position(decibels: -12) - 0.65) < 0.000001,
               "Target volume maps to the middle green zone")
        expect(abs(VoiceQualityMonitor.position(decibels: -23) - 0.5) < 0.000001,
               "Target midpoint is centered")
        expect(VoiceQualityMonitor.position(decibels: -100) == 0 &&
               VoiceQualityMonitor.position(decibels: 10) == 1 &&
               VoiceQualityMonitor.position(decibels: .nan) == 0, "Pointer is bounded")
        print("\(checks) voice-quality checks passed.")
    }
}
