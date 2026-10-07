// SPDX-License-Identifier: MIT
import Foundation
import AVFoundation
import Speech
import Security

enum PrompterError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

/// Audio work stays off the UI and audio render threads.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "de.local.teleprompter.audio", qos: .userInteractive)
    private var running = false
    private var configurationObserver: NSObjectProtocol?

    func start(format: AVAudioFormat, bufferSize: AVAudioFrameCount = 256,
               onBuffer: @escaping (AVAudioPCMBuffer, AudioMetrics) -> Void,
               onFailure: @escaping (String) -> Void) throws {
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let converter = AVAudioConverter(from: source, to: format) else {
            throw PrompterError.message(L10n.text("No microphone available. Check sound input in System Settings."))
        }
        converter.primeMethod = .none
        running = true
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { _ in onFailure(L10n.text("The microphone changed. Restart recognition.")) }
        input.installTap(onBus: 0, bufferSize: bufferSize, format: source) { [weak self] buffer, _ in
            guard let self, let copy = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: buffer.frameLength) else { return }
            copy.frameLength = buffer.frameLength
            let from = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            let to = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for i in 0..<from.count {
                if let src = from[i].mData, let dst = to[i].mData {
                    memcpy(dst, src, Int(from[i].mDataByteSize))
                }
            }
            self.queue.async {
                guard self.running else { return }
                let capacity = AVAudioFrameCount(ceil(Double(copy.frameLength) * format.sampleRate / source.sampleRate)) + 64
                guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
                var supplied = false
                var error: NSError?
                let status = converter.convert(to: output, error: &error) { _, state in
                    if supplied { state.pointee = .noDataNow; return nil }
                    supplied = true
                    state.pointee = .haveData
                    return copy
                }
                if status == .error {
                    onFailure(error?.localizedDescription ?? L10n.text("Microphone audio could not be processed."))
                    return
                }
                guard output.frameLength > 0 else { return }
                var metrics = AudioMetrics(rms: 0, peak: 0)
                if let samples = copy.floatChannelData?[0] {
                    metrics = AudioMetrics(samples: UnsafeBufferPointer(start: samples, count: Int(copy.frameLength)),
                                           sampleRate: source.sampleRate)
                }
                onBuffer(output, metrics)
            }
        }
        engine.prepare()
        do { try engine.start() }
        catch { stop(); throw error }
    }

    func stop() {
        engine.stop()
        if running { engine.inputNode.removeTap(onBus: 0) }
        queue.sync { running = false }
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
    }

    deinit { stop() }
}

@MainActor
final class LocalSpeechSession {
    private var capture: AudioCapture?
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    static func makeTranscriber(locale requestedLocale: Locale = SpeechLanguage.locale("system")) async throws -> SpeechTranscriber {
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw PrompterError.message(L10n.text("Local recognition is unavailable for {0}. Choose another speech language or OpenAI.", SpeechLanguage.name(requestedLocale.identifier)))
        }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                 reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
    }

    static func ensureAssets(_ transcriber: SpeechTranscriber,
                             status: @escaping @MainActor (String) -> Void) async throws {
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            status(L10n.text("Downloading speech model …"))
            let progressTask = Task { @MainActor in
                while !Task.isCancelled {
                    let percent = Int(installation.progress.fractionCompleted * 100)
                    status(L10n.text("Downloading speech model · {0}%", L10n.number(percent)))
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
            defer { progressTask.cancel() }
            try await installation.downloadAndInstall()
        }
        try Task.checkCancellation()
    }

    func start(script: PromptScript, onText: @escaping @MainActor (String, String) -> Void,
               onStatus: @escaping @MainActor (String) -> Void,
               onLevel: @escaping @MainActor (AudioMetrics) -> Void,
               onFailure: @escaping @MainActor (String) -> Void) async throws {
        let transcriber = try await Self.makeTranscriber(locale: script.locale)
        try await Self.ensureAssets(transcriber, status: onStatus)
        onStatus(L10n.text("Preparing local recognition …"))
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw PrompterError.message(L10n.text("No compatible audio format for the speech model."))
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber],
                                      options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        self.analyzer = analyzer
        let context = AnalysisContext()
        context.contextualStrings[.general] = Array(Set(script.words.map(\.text).filter {
            $0.count >= 5 && $0.first?.isUppercase == true
        })).sorted().prefix(80).map { $0 }
        try await analyzer.setContext(context)
        try await analyzer.prepareToAnalyze(in: format)
        try Task.checkCancellation()
        // Stop on overload rather than retain an unlimited backlog of voice data.
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingOldest(80))
        self.continuation = continuation
        resultTask = Task { @MainActor in
            do {
                for try await result in transcriber.results {
                    guard !Task.isCancelled else { return }
                    let text = String(result.text.characters)
                    // Revisions of a result use the same audio start time.
                    let id = String(format: "%.4f", CMTimeGetSeconds(result.range.start))
                    onText(text, id)
                }
            } catch {
                if !Task.isCancelled { onFailure(error.localizedDescription) }
            }
        }
        try await analyzer.start(inputSequence: stream)
        try Task.checkCancellation()
        let capture = AudioCapture()
        self.capture = capture
        try capture.start(format: format, onBuffer: { buffer, metrics in
            if case .dropped = continuation.yield(AnalyzerInput(buffer: buffer)) {
                Task { @MainActor in onFailure(L10n.text("Local recognition cannot keep up. Restart it.")) }
            }
            Task { @MainActor in onLevel(metrics) }
        }, onFailure: { message in Task { @MainActor in onFailure(message) } })
        onStatus(L10n.text("Listening · {0} · {1}", SpeechLanguage.name(script.locale.identifier), L10n.text("local")))
    }

    func stop() async {
        capture?.stop(); capture = nil
        continuation?.finish(); continuation = nil
        resultTask?.cancel(); resultTask = nil
        progressTask?.cancel(); progressTask = nil
        let previous = analyzer
        analyzer = nil
        await previous?.cancelAndFinishNow()
    }
}

enum APIKeyStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "de.local.teleprompter") + ".openai"
    static func load() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "api-key",
                                   kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "api-key"]
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw PrompterError.message(L10n.text("Could not remove the key ({0}).", String(status)))
            }
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: Data(trimmed.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes, uniquingKeysWith: { _, new in new }) as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw PrompterError.message(L10n.text("Could not save the key in macOS Keychain ({0}).", String(status)))
        }
    }
}

/// Serialized socket sends preserve audio order; slow connections never build
/// an unbounded queue. Each ASR item retains its own cumulative transcript.
@MainActor
final class OpenAISpeechSession {
    private var socket: URLSessionWebSocketTask?
    private var capture: AudioCapture?
    private var receiverTask: Task<Void, Never>?
    private var senderTask: Task<Void, Never>?
    private var continuation: AsyncStream<Data>.Continuation?
    private var transcripts: [String: String] = [:]
    private var ready = false
    private var errorMessage: String?

    static func configuration(script: PromptScript, delay: String) -> [String: Any] {
        RealtimeConfiguration.session(script: script, delay: delay)
    }

    func start(key: String, script: PromptScript, delay: String,
               onText: @escaping @MainActor (String, String) -> Void,
               onStatus: @escaping @MainActor (String) -> Void,
               onLevel: @escaping @MainActor (AudioMetrics) -> Void,
               onFailure: @escaping @MainActor (String) -> Void) async throws {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PrompterError.message(L10n.text("Enter an OpenAI API key or select local recognition."))
        }
        onStatus(L10n.text("Connecting to OpenAI …"))
        var request = URLRequest(url: URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!)
        request.setValue("Bearer \(key.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()
        receiverTask = Task { @MainActor in
            do {
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    let data: Data
                    switch message {
                    case .string(let text): data = Data(text.utf8)
                    case .data(let value): data = value
                    @unknown default: continue
                    }
                    guard let event = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = event["type"] as? String else { continue }
                    switch type {
                    case "session.updated", "transcription_session.updated": self.ready = true
                    case "error", "conversation.item.input_audio_transcription.failed":
                        let error = event["error"] as? [String: Any]
                        let message = error?["message"] as? String ?? "OpenAI konnte das Audio nicht transkribieren."
                        self.errorMessage = message
                        onFailure(message)
                        return
                    case "conversation.item.input_audio_transcription.delta":
                        let id = event["item_id"] as? String ?? "current"
                        self.transcripts[id, default: ""] += event["delta"] as? String ?? ""
                        onText(self.transcripts[id] ?? "", id)
                    case "conversation.item.input_audio_transcription.completed":
                        let id = event["item_id"] as? String ?? "current"
                        let text = event["transcript"] as? String ?? self.transcripts[id] ?? ""
                        onText(text, id)
                        self.transcripts.removeValue(forKey: id)
                    default: break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "OpenAI-Verbindung unterbrochen: \(error.localizedDescription)"
                    onFailure(self.errorMessage!)
                }
            }
        }
        try await send(Self.configuration(script: script, delay: delay), socket: socket)
        for _ in 0..<150 {
            if ready { break }
            if let errorMessage { throw PrompterError.message(errorMessage) }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard ready else { throw PrompterError.message(L10n.text("OpenAI is not responding. Check the key, model access and internet connection.")) }
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingOldest(80))
        self.continuation = continuation
        senderTask = Task { @MainActor in
            do {
                var framesSinceCommit = 0
                for await data in stream {
                    try Task.checkCancellation()
                    try await send(["type": "input_audio_buffer.append", "audio": data.base64EncodedString()], socket: socket)
                    framesSinceCommit += data.count / 2
                    // Live deltas arrive before commit. Periodic commits keep items bounded
                    // during uninterrupted long reads without depending on server VAD.
                    if framesSinceCommit >= RealtimeConfiguration.sampleRate * 10 {
                        try await send(["type": "input_audio_buffer.commit"], socket: socket)
                        framesSinceCommit = 0
                    }
                }
            } catch {
                if !Task.isCancelled { onFailure(L10n.text("Could not send OpenAI audio: {0}", error.localizedDescription)) }
            }
        }
        let capture = AudioCapture()
        self.capture = capture
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(RealtimeConfiguration.sampleRate),
                                  channels: 1, interleaved: true)!
        try capture.start(format: format, bufferSize: 1024, onBuffer: { buffer, metrics in
            let audio = buffer.audioBufferList.pointee.mBuffers
            guard let pointer = audio.mData else { return }
            let data = Data(bytes: pointer, count: Int(audio.mDataByteSize))
            if case .dropped = continuation.yield(data) {
                Task { @MainActor in onFailure(L10n.text("The connection is too slow. Restart or choose local recognition.")) }
            }
            Task { @MainActor in onLevel(metrics) }
        }, onFailure: { message in Task { @MainActor in onFailure(message) } })
        onStatus(L10n.text("Listening · {0} · {1}", SpeechLanguage.name(script.locale.identifier), "OpenAI"))
    }

    private func send(_ value: [String: Any], socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: value)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    func stop() {
        capture?.stop(); capture = nil
        continuation?.finish(); continuation = nil
        senderTask?.cancel(); senderTask = nil
        receiverTask?.cancel(); receiverTask = nil
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil
        transcripts.removeAll(); ready = false
    }
}
