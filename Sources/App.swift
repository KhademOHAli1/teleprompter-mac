// SPDX-License-Identifier: MIT
import SwiftUI
import AppKit

let mint = Color(red: 0.48, green: 0.94, blue: 0.76)
let canvas = Color(red: 0.045, green: 0.06, blue: 0.07)

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct TeleprompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = PrompterModel()

    var body: some Scene {
        WindowGroup("Teleprompter") {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    model.prepareScript()
                    model.refreshSpeechLanguages()
                    model.pinWindow()
                    NSApp.windows.first?.backgroundColor = NSColor(canvas)
                }
        }
        .defaultSize(width: 1120, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Teleprompter") {
                Button(L10n.text("Start / Pause")) { model.toggle() }.keyboardShortcut("r")
                Button(L10n.text("Edit text")) { model.edit() }.keyboardShortcut("e")
                Button(L10n.text("Previous sentence")) { model.moveSentence(-1) }.keyboardShortcut(.upArrow, modifiers: .command)
                Button(L10n.text("Next sentence")) { model.moveSentence(1) }.keyboardShortcut(.downArrow, modifiers: .command)
                Button(L10n.text("Back to start")) { model.seek(0) }.keyboardShortcut("0")
                Divider()
                Button(L10n.text("Full screen")) { model.fullscreen() }.keyboardShortcut("f", modifiers: [.command, .control])
                Button(L10n.text("Settings")) { model.showSettings = true }.keyboardShortcut(",")
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: PrompterModel

    var body: some View {
        providerPreferences
            .onChange(of: model.mirrored) { _, value in UserDefaults.standard.set(value, forKey: "mirrored") }
            .onChange(of: model.floating) { _, value in
                UserDefaults.standard.set(value, forKey: "floating")
                model.pinWindow()
            }
            .alert(L10n.text("Speech recognition paused"), isPresented: failurePresented) {
                Button(L10n.text("OK")) { model.failure = nil }
                if model.microphonePermissionDenied {
                    Button(L10n.text("Microphone settings")) { model.microphoneSettings(); model.failure = nil }
                }
            } message: { Text(model.failure ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.05))
            if model.editing { editor }
            else { reading }
            footer
        }
        .background(canvas)
        .tint(mint)
    }

    private var settingsSheets: some View {
        content
            .sheet(isPresented: $model.showSettings) { readingSettingsSheet }
            .sheet(isPresented: $model.showOpenAI) { openAISettings }
    }

    private var readingSettingsSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(L10n.text("Reading view")).font(.title2.bold())
                Spacer()
                Button(L10n.text("Done")) { model.showSettings = false }.keyboardShortcut(.defaultAction)
            }
            controls
        }
        .padding(28).frame(width: 410)
    }

    private var readingPreferences: some View {
        settingsSheets
            .onChange(of: model.draft) { _, _ in model.saveDraft() }
            .onChange(of: model.fontSize) { _, value in UserDefaults.standard.set(value, forKey: "fontSize") }
            .onChange(of: model.columnWidth) { _, value in UserDefaults.standard.set(value, forKey: "columnWidth") }
            .onChange(of: model.lookAhead) { _, value in UserDefaults.standard.set(value, forKey: "lookAhead") }
    }

    private var providerPreferences: some View {
        readingPreferences
            .onChange(of: model.delay) { _, value in UserDefaults.standard.set(value, forKey: "delay") }
            .onChange(of: model.speechLanguage) { _, _ in model.changeSpeechLanguage() }
            .onChange(of: model.provider) { _, value in UserDefaults.standard.set(value, forKey: "provider") }
    }

    private var failurePresented: Binding<Bool> {
        Binding<Bool>(
            get: { model.failure != nil },
            set: { isPresented in
                if !isPresented { model.failure = nil }
            }
        )
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform").font(.system(size: 25, weight: .medium)).foregroundStyle(mint)
            VStack(alignment: .leading, spacing: 3) {
                Text("Teleprompter").font(.system(size: 19, weight: .bold))
                Text(L10n.text("FOLLOWS YOUR VOICE"))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.3).foregroundStyle(.secondary)
            }
            Spacer()
            if !model.editing {
                Button { model.edit() } label: { Label(L10n.text("Text"), systemImage: "square.and.pencil") }
                    .help(L10n.text("Edit text · ⌘E"))
                Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .help(L10n.text("Font size and reading view"))
                Button { model.mirrored.toggle() } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                    .tint(model.mirrored ? mint : .white).help(L10n.text("Mirror horizontally"))
                Button { model.floating.toggle() } label: { Image(systemName: model.floating ? "pin.fill" : "pin") }
                    .help(L10n.text("Keep window on top"))
            }
            Button { model.fullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .help(L10n.text("Full screen"))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 19)
    }

    private var editor: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("Your text. Your pace.")).font(.system(size: 27, weight: .bold))
                        Text(L10n.text("Paste, start and read naturally."))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Example text")) { model.loadExample() }.buttonStyle(.borderless)
                }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.035))
                    TextEditor(text: $model.draft)
                        .font(.system(size: 18)).lineSpacing(7)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .accessibilityLabel(L10n.text("Your teleprompter text"))
                    if model.draft.isEmpty {
                        Text(L10n.text("Paste your text here …\n\n⌘V pastes from the clipboard."))
                            .font(.system(size: 18)).foregroundStyle(.white.opacity(0.3))
                            .lineSpacing(12).padding(20).allowsHitTesting(false)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
                HStack {
                    Text(L10n.text("Words: {0}", L10n.number(PromptScript(model.draft, locale: model.speechLocale).words.count)))
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.text("Open reading view")) { model.readPreview() }
                        .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                controls
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.text("Pauses when you pause"), systemImage: "pause.circle")
                    Label(L10n.text("Word lead for smooth reading"), systemImage: "text.cursor")
                    Label(L10n.text("Click to set reading position"), systemImage: "cursorarrow")
                }
                .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                startButton
                Text(L10n.text("⌘R  Start / Pause"))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 255)
        }
        .padding(28)
    }

    private var speechLanguageControl: some View {
        Picker(L10n.text("Speech language"), selection: $model.speechLanguage) {
            Text(L10n.text("System language · {0}", SpeechLanguage.name(SpeechLanguage.systemIdentifier))).tag("system")
            ForEach(model.speechLanguages, id: \.self) { identifier in
                Text(SpeechLanguage.name(identifier)).tag(identifier)
            }
        }
        .disabled(model.listening || model.preparing || model.stopping)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                Text(L10n.text("SPEECH RECOGNITION")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                speechLanguageControl
                Picker(L10n.text("Recognition"), selection: $model.provider) {
                    Text(L10n.text("Mac · local")).tag("local")
                    Text(L10n.text("OpenAI · online")).tag("openai")
                }.labelsHidden().pickerStyle(.segmented)
                    .disabled(model.listening || model.preparing || model.stopping)
                if model.provider == "local" {
                    Text(L10n.text("On device · no API key.\nSpeech assets download on first use."))
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                } else {
                    Button(L10n.text("Set up OpenAI …")) {
                        model.apiKey = APIKeyStore.load()
                        model.showSettings = false
                        model.showOpenAI = true
                    }
                    Text(L10n.text("Live audio is sent to OpenAI.\nAn API key and API credit are required."))
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.text("FONT SIZE")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.fontSize))").font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $model.fontSize, in: 28...86, step: 2)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.text("TEXT WIDTH")).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.columnWidth))").font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $model.columnWidth, in: 380...900, step: 20)
                Text(L10n.text("Narrow column for shorter eye movements."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Text(L10n.text("Word lead"))
                Spacer()
                Picker(L10n.text("Word lead"), selection: $model.lookAhead) {
                    Text(L10n.text("Off")).tag(0)
                    Text(L10n.text("1 word")).tag(1)
                    Text(L10n.text("2 words")).tag(2)
                    Text(L10n.text("3 words")).tag(3)
                }.labelsHidden().frame(width: 115)
            }
            Toggle(L10n.text("Mirror text"), isOn: $model.mirrored).toggleStyle(.switch)
            Toggle(L10n.text("Always on top"), isOn: $model.floating).toggleStyle(.switch)
        }
        .font(.system(size: 12))
    }

    private var reading: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                PrompterView(script: model.script, cursor: model.readingCursor, fontSize: model.fontSize,
                             columnWidth: model.columnWidth) { model.seek($0) }
                    .scaleEffect(x: model.mirrored ? -1 : 1, y: 1)
                GeometryReader { geometry in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(mint)
                        .position(x: max(18, (geometry.size.width - model.columnWidth) / 2 - 24),
                                  y: geometry.size.height * 0.38 + model.fontSize * 0.65)
                }.allowsHitTesting(false)
                VStack {
                    LinearGradient(colors: [canvas, canvas.opacity(0)], startPoint: .top, endPoint: .bottom).frame(height: 50)
                    Spacer()
                    LinearGradient(colors: [canvas.opacity(0), canvas], startPoint: .top, endPoint: .bottom).frame(height: 60)
                }.allowsHitTesting(false)
            }
            HStack(spacing: 16) {
                Button { model.moveSentence(-1) } label: { Image(systemName: "backward.end") }.help(L10n.text("Previous sentence"))
                Button { model.seek(0) } label: { Image(systemName: "arrow.counterclockwise") }.help(L10n.text("Back to start"))
                Button { model.moveSentence(1) } label: { Image(systemName: "forward.end") }.help(L10n.text("Next sentence"))
                Text(L10n.text("Sentence {0} / {1}", L10n.number(model.sentence + 1), L10n.number(model.script.sentenceStarts.count)))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                startButton.frame(width: 210)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 28).padding(.vertical, 15)
        }
    }

    private var startButton: some View {
        Button { model.toggle() } label: {
            HStack(spacing: 9) {
                if model.preparing || model.stopping { ProgressView().controlSize(.small).tint(canvas) }
                else { Image(systemName: model.listening ? "pause.fill" : "mic.fill") }
                Text(model.preparing ? "Vorbereitung stoppen" :
                        model.listening ? "Pausieren" : model.cursor >= 0 && !model.finished ? "Weiterlesen" : L10n.text("Start reading"))
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .foregroundStyle(canvas)
            .background(mint, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).disabled(model.stopping)
        .accessibilityLabel(model.listening ? L10n.text("Pause reading") : L10n.text("Start reading"))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if !model.editing {
                GeometryReader { geometry in
                    Rectangle().fill(mint.opacity(0.65)).frame(width: geometry.size.width * model.progress)
                }.frame(height: 2).background(.white.opacity(0.07))
            } else { Divider() }
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(model.listening ? mint : .gray).frame(width: 6, height: 6)
                    Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VoiceQualityView(reading: model.voiceQuality)
                HStack {
                    Spacer(minLength: 0)
                    if !model.transcript.isEmpty && !model.editing {
                        Text(model.transcript).font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1).truncationMode(.head)
                            .help(L10n.text("Last recognized text"))
                    } else {
                        Text(SpeechLanguage.apiCode(model.speechLocale).uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(mint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 28).padding(.vertical, 13)
        }
    }

    private var openAISettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L10n.text("OpenAI live transcription")).font(.title2.bold())
            Text(L10n.text("Microphone audio is sent to OpenAI while reading. API charges apply. You can save the key in macOS Keychain."))
                .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
            SecureField(L10n.text("OpenAI API key"), text: $model.apiKey).textFieldStyle(.roundedBorder)
                .accessibilityLabel(L10n.text("OpenAI API key"))
            Picker(L10n.text("Response time"), selection: $model.delay) {
                Text(L10n.text("Very fast")).tag("minimal")
                Text(L10n.text("Fast")).tag("low")
                Text(L10n.text("More context")).tag("medium")
            }
            HStack {
                Button(L10n.text("Save in Keychain")) { model.saveKey() }
                Text(model.keyNotice).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Link(L10n.text("Manage API keys"), destination: URL(string: "https://platform.openai.com/api-keys")!)
            HStack {
                Text(L10n.text("Model: gpt-live-transcribe")).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Done")) { model.showOpenAI = false }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(width: 530)
    }
}
