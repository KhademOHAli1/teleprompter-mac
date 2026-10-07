// SPDX-License-Identifier: MIT
import Foundation

/// Signal measurements, computed locally from the same audio sent to ASR.
/// These are neither a noise estimate nor an objective pronunciation score.
struct AudioMetrics: Sendable {
    let rms: Double
    let peak: Double
    let clippedFraction: Double
    let duration: TimeInterval

    init(rms: Double, peak: Double, clippedFraction: Double = 0, duration: TimeInterval = 0.02) {
        self.rms = rms.isFinite ? max(0, rms) : 0
        self.peak = peak.isFinite ? max(0, peak) : 0
        self.clippedFraction = clippedFraction.isFinite ? min(1, max(0, clippedFraction)) : 0
        self.duration = duration.isFinite ? max(0, duration) : 0
    }

    init(samples: UnsafeBufferPointer<Float>, sampleRate: Double) {
        var energy = 0.0
        var peak = 0.0
        var clipped = 0
        for sample in samples {
            let value = sample.isFinite ? Double(sample) : 0
            energy += value * value
            peak = max(peak, abs(value))
            if abs(value) >= 0.995 { clipped += 1 }
        }
        let count = Double(samples.count)
        self.init(rms: count > 0 ? sqrt(energy / count) : 0, peak: peak,
                  clippedFraction: count > 0 ? Double(clipped) / count : 0,
                  duration: sampleRate.isFinite && sampleRate > 0 ? count / sampleRate : 0)
    }
}

enum VoiceQualityState: Equatable, Sendable {
    case inactive, waiting, pause, quiet, pending, good, unclear, loud, clipping

    var label: String {
        switch self {
        case .inactive: return "Stimm-Check · Mikrofon aus"
        case .waiting: return "Warte auf deine Stimme"
        case .pause: return "Sprechpause"
        case .quiet: return "Zu leise · näher ans Mikrofon"
        case .pending: return "Pegel gut · warte auf Erkennung"
        case .good: return "Gut hörbar · Text erkannt"
        case .unclear: return "Textzuordnung unsicher"
        case .loud: return "Zu laut · etwas leiser"
        case .clipping: return "Pegelspitzen · leiser sprechen"
        }
    }
}

struct VoiceQualityReading: Equatable, Sendable {
    let state: VoiceQualityState
    let position: Double?
    static let inactive = Self(state: .inactive, position: nil)
}

/// A conservative reception hint: target audio level + recent script match.
/// Fast partial-result corrections get a short grace period. Silence is neutral.
struct VoiceQualityMonitor {
    private var active = false
    private var smoothedEnergy: Double?
    private var lastAudio: TimeInterval?
    private var lastSignal: TimeInterval?
    private var lastClip: TimeInterval?
    private var lastRecognition: TimeInterval?
    private var lastGoodMatch: TimeInterval?
    private var confidence = 0.0

    mutating func start() {
        self = Self()
        active = true
    }

    mutating func stop() { self = Self() }

    mutating func consumeAudio(_ metrics: AudioMetrics, at time: TimeInterval) {
        guard active else { return }
        let elapsed = max(0.001, min(0.5, lastAudio.map { time - $0 } ?? metrics.duration))
        let energy = metrics.rms * metrics.rms
        // Time-based smoothing behaves consistently for local and cloud buffer sizes.
        let alpha = 1 - exp(-elapsed / 0.12)
        smoothedEnergy = smoothedEnergy.map { $0 + alpha * (energy - $0) } ?? energy
        lastAudio = time
        if metrics.rms >= 0.003 { lastSignal = time }
        if metrics.peak >= 1 || metrics.clippedFraction >= 0.003 { lastClip = time }
    }

    mutating func consumeRecognition(confidence: Double, at time: TimeInterval) {
        guard active else { return }
        self.confidence = confidence.isFinite ? min(1, max(0, confidence)) : 0
        lastRecognition = time
        if self.confidence >= 0.65 { lastGoodMatch = time }
    }

    func reading(at time: TimeInterval) -> VoiceQualityReading {
        guard active else { return .inactive }
        guard let lastAudio, time - lastAudio < 0.85 else {
            return .init(state: .waiting, position: nil)
        }
        guard let lastSignal else { return .init(state: .waiting, position: nil) }
        guard time - lastSignal < 0.85 else { return .init(state: .pause, position: nil) }
        let db = 10 * log10(max(smoothedEnergy ?? 0, 0.000001))
        let position = Self.position(decibels: db)
        let state: VoiceQualityState
        if let lastClip, time - lastClip < 0.75 { state = .clipping }
        else if db < -34 { state = .quiet }
        else if db > -12 { state = .loud }
        else if let lastGoodMatch, time - lastGoodMatch < 2,
                confidence >= 0.65 || time - lastGoodMatch < 0.9 { state = .good }
        else if lastRecognition != nil { state = .unclear }
        else { state = .pending }
        return .init(state: state, position: position)
    }

    /// The heuristic target (-34…-12 dBFS RMS) occupies the middle green zone.
    static func position(decibels: Double) -> Double {
        let stops: [(Double, Double)] = [(-60, 0), (-50, 0.10), (-42, 0.20),
                                        (-34, 0.35), (-12, 0.65), (-6, 0.80),
                                        (-3, 0.90), (0, 1)]
        guard decibels.isFinite else { return 0 }
        for index in 1..<stops.count where decibels <= stops[index].0 {
            let left = stops[index - 1], right = stops[index]
            return max(0, left.1 + (decibels - left.0) / (right.0 - left.0) * (right.1 - left.1))
        }
        return 1
    }
}
