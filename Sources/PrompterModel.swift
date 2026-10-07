// SPDX-License-Identifier: MIT
import SwiftUI
import AppKit
import AVFoundation

@MainActor
final class PrompterModel: ObservableObject {
    @Published var draft = UserDefaults.standard.string(forKey: "script") ?? ""
    @Published var script = PromptScript("")
    @Published var cursor = -1
    @Published var editing = true
    @Published var listening = false
    @Published var preparing = false
    @Published var stopping = false
    @Published var status = "Text einfügen und starten"
    @Published var failure: String?
    @Published var transcript = ""
    @Published var voiceQuality = VoiceQualityReading.inactive
    @Published var fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 48
    @Published var columnWidth = UserDefaults.standard.object(forKey: "columnWidth") as? Double ?? 560
    @Published var lookAhead = UserDefaults.standard.object(forKey: "lookAhead") as? Int ?? 1
    @Published var mirrored = UserDefaults.standard.bool(forKey: "mirrored")
    @Published var floating = UserDefaults.standard.bool(forKey: "floating")
    @Published var provider = UserDefaults.standard.string(forKey: "provider") ?? "local"
    @Published var delay = UserDefaults.standard.string(forKey: "delay") ?? "minimal"
    @Published var showSettings = false
    @Published var showOpenAI = false
    @Published var apiKey = ""
    @Published var keyNotice = ""

    private var tracker = WordTracker(script: PromptScript(""))
    private var local: LocalSpeechSession?
    private var cloud: OpenAISpeechSession?
    private var startupTask: Task<Void, Never>?
    private var generation = UUID()
    private var activityTimer: Timer?
    private var lastSound = Date.distantPast
    private var lastMatch = Date.distantPast
    private var lastMeterUpdate = Date.distantPast
    private var voiceMonitor = VoiceQualityMonitor()

    var nextWord: Int { max(0, min(cursor + 1, max(0, script.words.count - 1))) }
    var sentence: Int { script.sentence(at: nextWord) }
    var progress: Double { script.words.isEmpty ? 0 : Double(cursor + 1) / Double(script.words.count) }
    var finished: Bool { !script.words.isEmpty && cursor >= script.words.count - 1 }
    // Lead only follows confirmed voice matches. Silence cannot advance it.
    var readingCursor: Int {
        guard cursor >= 0, !finished else { return cursor }
        return min(cursor + lookAhead, max(-1, script.words.count - 2))
    }

    func saveDraft() { UserDefaults.standard.set(draft, forKey: "script") }

    func prepareScript() {
        saveDraft()
        let next = PromptScript(draft)
        if next != script {
            script = next
            tracker = WordTracker(script: next)
            cursor = -1
            transcript = ""
        }
    }

    func readPreview() {
        prepareScript()
        guard !script.words.isEmpty else { status = "Füge zuerst deinen Text ein."; return }
        editing = false
    }

    func toggle() {
        if listening || preparing { stop() } else { start() }
    }

    func start() {
        guard !preparing, !listening, !stopping else { return }
        prepareScript()
        guard !script.words.isEmpty else { failure = "Füge zuerst einen Text ein."; return }
        if finished { tracker.seek(nextWord: 0); cursor = -1 }
        // A fresh ASR stream needs fresh anchors, preserving the chosen position.
        tracker.seek(nextWord: cursor + 1)
        editing = false; preparing = true; failure = nil
        transcript = ""; status = "Mikrofon wird vorbereitet …"
        voiceMonitor.start()
        voiceQuality = voiceMonitor.reading(at: Date.timeIntervalSinceReferenceDate)
        lastMeterUpdate = .distantPast
        let id = UUID(); generation = id
        startupTask = Task { @MainActor [self] in
            do {
                let permission = await AVCaptureDevice.requestAccess(for: .audio)
                try Task.checkCancellation()
                guard permission else {
                    throw PrompterError.message("Mikrofonzugriff fehlt. Erlaube Teleprompter unter Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon.")
                }
                let onText: @MainActor (String, String) -> Void = { [weak self] text, utterance in
                    guard let self, self.generation == id else { return }
                    self.transcript = text
                    let match = self.tracker.consume(text, utterance: utterance)
                    self.voiceMonitor.consumeRecognition(confidence: self.tracker.confidence,
                                                         at: Date.timeIntervalSinceReferenceDate)
                    self.voiceQuality = self.voiceMonitor.reading(at: Date.timeIntervalSinceReferenceDate)
                    if let index = match {
                        self.cursor = index
                        self.lastMatch = Date()
                        if self.finished {
                            self.stop()
                            self.status = "Text vollständig gelesen"
                        }
                    }
                }
                let onStatus: @MainActor (String) -> Void = { [weak self] text in
                    guard let self, self.generation == id else { return }
                    self.status = text
                }
                let onLevel: @MainActor (AudioMetrics) -> Void = { [weak self] metrics in
                    guard let self, self.generation == id else { return }
                    self.voiceMonitor.consumeAudio(metrics, at: Date.timeIntervalSinceReferenceDate)
                    if metrics.rms > 0.012 { self.lastSound = Date() }
                    guard Date().timeIntervalSince(self.lastMeterUpdate) > 0.06 else { return }
                    self.lastMeterUpdate = Date()
                    self.voiceQuality = self.voiceMonitor.reading(at: Date.timeIntervalSinceReferenceDate)
                }
                let onFailure: @MainActor (String) -> Void = { [weak self] message in
                    guard let self, self.generation == id else { return }
                    self.failure = message
                    self.stop()
                }
                if self.provider == "local" {
                    let session = LocalSpeechSession(); self.local = session
                    try await session.start(script: self.script, onText: onText, onStatus: onStatus,
                                            onLevel: onLevel, onFailure: onFailure)
                } else {
                    let session = OpenAISpeechSession(); self.cloud = session
                    let key = self.apiKey.isEmpty ? APIKeyStore.load() : self.apiKey
                    try await session.start(key: key, script: self.script, delay: self.delay,
                                            onText: onText, onStatus: onStatus, onLevel: onLevel, onFailure: onFailure)
                }
                guard self.generation == id, !Task.isCancelled else { return }
                self.preparing = false; self.listening = true
                self.lastSound = Date(); self.lastMatch = Date()
                self.activityTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.updateActivity() }
                }
            } catch {
                guard self.generation == id else { return }
                if !(error is CancellationError) { self.failure = error.localizedDescription }
                self.stop()
            }
        }
    }

    private func updateActivity() {
        guard listening else { return }
        voiceQuality = voiceMonitor.reading(at: Date.timeIntervalSinceReferenceDate)
        if Date().timeIntervalSince(lastSound) > 0.85 { status = "Sprechpause · Position bleibt stehen" }
        else if Date().timeIntervalSince(lastMatch) > 3 && !transcript.isEmpty {
            status = "Suche Textstelle · bei Bedarf ein Wort anklicken"
        } else { status = "Folgt deiner Stimme · \(provider == "local" ? "lokal" : "OpenAI")" }
    }

    func stop(restart: Bool = false) {
        let id = UUID(); generation = id
        startupTask?.cancel(); startupTask = nil
        activityTimer?.invalidate(); activityTimer = nil
        listening = false; preparing = false; stopping = true
        voiceMonitor.stop(); voiceQuality = .inactive
        status = failure == nil ? "Pausiert · bereit zum Fortsetzen" : "Erkennung angehalten"
        let localSession = local; local = nil
        let cloudSession = cloud; cloud = nil
        cloudSession?.stop()
        Task { @MainActor in
            await localSession?.stop()
            guard generation == id else { return }
            stopping = false
            if restart { start() }
        }
    }

    func seek(_ word: Int) {
        let resume = listening
        tracker.seek(nextWord: word); cursor = tracker.cursor
        transcript = ""
        if listening || preparing { stop(restart: resume) }
        else { status = "Leseposition gesetzt" }
    }

    func moveSentence(_ direction: Int) {
        guard !script.sentenceStarts.isEmpty else { return }
        let target = max(0, min(sentence + direction, script.sentenceStarts.count - 1))
        seek(script.sentenceStarts[target])
    }

    func edit() {
        if listening || preparing { stop() }
        editing = true
    }

    func fullscreen() { NSApp.keyWindow?.toggleFullScreen(nil) }
    func pinWindow() { NSApp.keyWindow?.level = floating ? .floating : .normal }
    func microphoneSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    func saveKey() {
        do { try APIKeyStore.save(apiKey); keyNotice = apiKey.isEmpty ? "Schlüssel entfernt." : "Im macOS-Schlüsselbund gespeichert." }
        catch { keyNotice = error.localizedDescription }
    }

    func loadExample() {
        draft = """
        Guten Tag und herzlich willkommen.

        Dieser Teleprompter folgt meiner Stimme. Wenn ich schneller spreche, geht der Text schneller weiter. Wenn ich eine Pause mache, bleibt er stehen.

        Ich kann auch ein Wort wiederholen oder einen kurzen Gedanken ergänzen. Danach finde ich zurück zu meinem Text.

        Jetzt spreche ich ganz bewusst etwas langsamer. Jedes Wort soll gut zu lesen sein.

        Vielen Dank fürs Zuhören.
        """
        prepareScript()
    }
}
