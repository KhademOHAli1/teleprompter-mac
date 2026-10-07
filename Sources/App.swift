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
                    model.pinWindow()
                    NSApp.windows.first?.backgroundColor = NSColor(canvas)
                }
        }
        .defaultSize(width: 1120, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Teleprompter") {
                Button("Start / Pause") { model.toggle() }.keyboardShortcut("r")
                Button("Text bearbeiten") { model.edit() }.keyboardShortcut("e")
                Button("Vorheriger Satz") { model.moveSentence(-1) }.keyboardShortcut(.upArrow, modifiers: .command)
                Button("Nächster Satz") { model.moveSentence(1) }.keyboardShortcut(.downArrow, modifiers: .command)
                Button("Zum Anfang") { model.seek(0) }.keyboardShortcut("0")
                Divider()
                Button("Vollbild") { model.fullscreen() }.keyboardShortcut("f", modifiers: [.command, .control])
                Button("Einstellungen") { model.showSettings = true }.keyboardShortcut(",")
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: PrompterModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.05))
            if model.editing { editor }
            else { reading }
            footer
        }
        .background(canvas)
        .tint(mint)
        .sheet(isPresented: $model.showSettings) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Leseansicht").font(.title2.bold())
                    Spacer()
                    Button("Fertig") { model.showSettings = false }.keyboardShortcut(.defaultAction)
                }
                controls
            }
            .padding(28).frame(width: 410)
        }
        .sheet(isPresented: $model.showOpenAI) { openAISettings }
        .onChange(of: model.draft) { _, _ in model.saveDraft() }
        .onChange(of: model.fontSize) { _, value in UserDefaults.standard.set(value, forKey: "fontSize") }
        .onChange(of: model.columnWidth) { _, value in UserDefaults.standard.set(value, forKey: "columnWidth") }
        .onChange(of: model.lookAhead) { _, value in UserDefaults.standard.set(value, forKey: "lookAhead") }
        .onChange(of: model.delay) { _, value in UserDefaults.standard.set(value, forKey: "delay") }
        .onChange(of: model.provider) { _, value in UserDefaults.standard.set(value, forKey: "provider") }
        .onChange(of: model.mirrored) { _, value in UserDefaults.standard.set(value, forKey: "mirrored") }
        .onChange(of: model.floating) { _, value in
            UserDefaults.standard.set(value, forKey: "floating")
            model.pinWindow()
        }
        .alert("Spracherkennung angehalten", isPresented: Binding(
            get: { model.failure != nil }, set: { if !$0 { model.failure = nil } }
        )) {
            Button("OK") { model.failure = nil }
            if model.failure?.contains("Mikrofon") == true {
                Button("Mikrofon-Einstellungen") { model.microphoneSettings(); model.failure = nil }
            }
        } message: { Text(model.failure ?? "") }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform").font(.system(size: 25, weight: .medium)).foregroundStyle(mint)
            VStack(alignment: .leading, spacing: 3) {
                Text("Teleprompter").font(.system(size: 19, weight: .bold))
                Text("DEUTSCH · FOLGT DEINER STIMME")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.3).foregroundStyle(.secondary)
            }
            Spacer()
            if !model.editing {
                Button { model.edit() } label: { Label("Text", systemImage: "square.and.pencil") }
                    .help("Text bearbeiten · ⌘E")
                Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .help("Schriftgröße und Leseansicht")
                Button { model.mirrored.toggle() } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                    .tint(model.mirrored ? mint : .white).help("Horizontal spiegeln")
                Button { model.floating.toggle() } label: { Image(systemName: model.floating ? "pin.fill" : "pin") }
                    .help("Fenster im Vordergrund halten")
            }
            Button { model.fullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .help("Vollbild")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 19)
    }

    private var editor: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dein Text. Dein Tempo.").font(.system(size: 27, weight: .bold))
                        Text("Einfügen, starten und ganz natürlich vorlesen.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Beispieltext") { model.loadExample() }.buttonStyle(.borderless)
                }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.035))
                    TextEditor(text: $model.draft)
                        .font(.system(size: 18)).lineSpacing(7)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .accessibilityLabel("Dein Teleprompter-Text")
                    if model.draft.isEmpty {
                        Text("Deinen Text hier einfügen …\n\n⌘V fügt Text aus der Zwischenablage ein.")
                            .font(.system(size: 18)).foregroundStyle(.white.opacity(0.3))
                            .lineSpacing(12).padding(20).allowsHitTesting(false)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
                HStack {
                    Text("\(PromptScript(model.draft).words.count) Wörter")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Leseansicht öffnen") { model.readPreview() }
                        .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                controls
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Label("Stoppt bei Sprechpausen", systemImage: "pause.circle")
                    Label("Vorlauf für flüssiges Lesen", systemImage: "text.cursor")
                    Label("Klick setzt die Leseposition", systemImage: "cursorarrow")
                }
                .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                startButton
                Text("⌘R  Start / Pause")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 255)
        }
        .padding(28)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                Text("SPRACHERKENNUNG").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                Picker("Erkennung", selection: $model.provider) {
                    Text("Mac · lokal").tag("local")
                    Text("OpenAI · online").tag("openai")
                }.labelsHidden().pickerStyle(.segmented)
                    .disabled(model.listening || model.preparing || model.stopping)
                if model.provider == "local" {
                    Text("Deutsch · ohne API-Schlüssel.\nBeim ersten Start wird das Sprachmodell geladen.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                } else {
                    Button("OpenAI einrichten …") {
                        model.apiKey = APIKeyStore.load()
                        model.showSettings = false
                        model.showOpenAI = true
                    }
                    Text("Live-Audio wird an OpenAI gesendet.\nAPI-Schlüssel und API-Guthaben erforderlich.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SCHRIFTGRÖSSE").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.fontSize))").font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $model.fontSize, in: 28...86, step: 2)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TEXTBREITE").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.columnWidth))").font(.system(size: 12, design: .monospaced))
                }
                Slider(value: $model.columnWidth, in: 380...900, step: 20)
                Text("Schmale Spalte für kurze Blickwege.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Text("Vorlauf")
                Spacer()
                Picker("Vorlauf", selection: $model.lookAhead) {
                    Text("Aus").tag(0)
                    Text("1 Wort").tag(1)
                    Text("2 Wörter").tag(2)
                    Text("3 Wörter").tag(3)
                }.labelsHidden().frame(width: 115)
            }
            Toggle("Text spiegeln", isOn: $model.mirrored).toggleStyle(.switch)
            Toggle("Immer im Vordergrund", isOn: $model.floating).toggleStyle(.switch)
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
                Button { model.moveSentence(-1) } label: { Image(systemName: "backward.end") }.help("Vorheriger Satz")
                Button { model.seek(0) } label: { Image(systemName: "arrow.counterclockwise") }.help("Zum Anfang")
                Button { model.moveSentence(1) } label: { Image(systemName: "forward.end") }.help("Nächster Satz")
                Text("Satz \(model.sentence + 1) / \(model.script.sentenceStarts.count)")
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
                        model.listening ? "Pausieren" : model.cursor >= 0 && !model.finished ? "Weiterlesen" : "Vorlesen starten")
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .foregroundStyle(canvas)
            .background(mint, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).disabled(model.stopping)
        .accessibilityLabel(model.listening ? "Vorlesen pausieren" : "Vorlesen starten")
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
                            .help("Zuletzt erkannter Text")
                    } else {
                        Text("DE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(mint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 28).padding(.vertical, 13)
        }
    }

    private var openAISettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("OpenAI Live-Transkription").font(.title2.bold())
            Text("Dein Mikrofon-Audio wird während des Vorlesens an OpenAI gesendet. Es fallen API-Kosten an. Der Schlüssel wird auf Wunsch im macOS-Schlüsselbund gespeichert.")
                .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
            SecureField("OpenAI API-Schlüssel", text: $model.apiKey).textFieldStyle(.roundedBorder)
                .accessibilityLabel("OpenAI API-Schlüssel")
            Picker("Reaktionszeit", selection: $model.delay) {
                Text("Sehr schnell").tag("minimal")
                Text("Schnell").tag("low")
                Text("Mehr Kontext").tag("medium")
            }
            HStack {
                Button("Im Schlüsselbund speichern") { model.saveKey() }
                Text(model.keyNotice).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Link("API-Schlüssel verwalten", destination: URL(string: "https://platform.openai.com/api-keys")!)
            HStack {
                Text("Modell: gpt-live-transcribe").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button("Fertig") { model.showOpenAI = false }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(width: 530)
    }
}
