# Teleprompter for Mac

A native multilingual teleprompter that follows your voice. Paste a script, start the microphone, and read at your own pace. Speech pauses hold the reading position.

[Deutsch](README.de.md) · [Privacy](docs/PRIVACY.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Features

- On-device speech recognition using Apple's SpeechAnalyzer and the selected speech locale.
- Optional OpenAI live transcription with your own API key.
- Word tracking with partial-result revisions, repeated phrases, fillers, German compounds and spoken numbers.
- Centered text with adjustable width, font size and word lead.
- Click a word to resume there; move between sentences or return to the beginning.
- Small bracketed stage directions, excluded from spoken-word matching.
- Mirror mode, full screen and an always-on-top window.
- Local microphone level meter with a centered green target zone and recent script-match feedback.
- A locally saved script draft and optional Keychain storage for the API key.

## Languages

The interface follows the macOS app language or the MCP host/browser locale.
English, German, French and Spanish translations are included; other interface
languages fall back to English. The **Speech language** setting is independent
of the interface language and defaults to the system/host language.

The script is never translated. Select its language before starting to read.
Available recognition languages depend on the selected provider. Chinese and
Japanese use word segmentation; right-to-left scripts keep their text direction.
See [localization](docs/LOCALIZATION.md) for supported behavior and contribution instructions.

## Requirements

- Apple Silicon Mac, macOS 26 or newer.
- Xcode 26 or newer, selected as the active developer toolchain.
- A microphone and microphone permission to read aloud.
- Speech assets for the selected language, downloaded by macOS when needed.

There are no third-party package dependencies. Build and test scripts use Xcode's Swift compiler and Apple frameworks. They currently compile in Swift 5 language mode. Intel Macs and older macOS releases are outside the supported build target.

## Build and run

Download or clone the source, then run from the project directory:

    ./test.command
    ./build.command
    open dist/Teleprompter.app

You can also double-click **build.command**, **test.command** or **start.command** in Finder. **start.command** builds the app if needed, then opens it.

The build is ad-hoc signed for local use. It is not a Developer ID signed or notarized binary. Instructions for source releases and signed binary distribution are in [Releasing](docs/RELEASING.md).

Build products and compiler caches stay in **dist/** and **.build/**, both ignored by Git. The project can be built from a folder with spaces in its path.

Optional build settings:

    TELEPROMPTER_BUILD_DIR=/tmp/teleprompter-build ./build.command
    TELEPROMPTER_BUNDLE_ID=org.example.teleprompter ./build.command
    ./build.command /tmp/Teleprompter.app

A different bundle identifier gives a fork separate preferences and a separate Keychain service. The default is **de.local.teleprompter**.

## Use

1. Paste your text, or use [the neutral German demo](examples/demo-de.txt).
2. Select **Mac · lokal** for on-device recognition.
3. Click **Vorlesen starten** and grant microphone permission.
4. Read naturally; pause, repeat a word, or click a word to change the position.

Shortcuts:

| Shortcut | Action |
| --- | --- |
| ⌘R | Start / pause |
| ⌘E | Edit text |
| ⌘↑ / ⌘↓ | Previous / next sentence |
| ⌘0 | Return to the beginning |
| ⌃⌘F | Full screen |
| ⌘, | Reading settings |

The default column is 560 points wide, with one word of visual lead. Lead follows confirmed matches; it does not run on a clock. A long unscripted passage can hold the position until the recognizer finds the script again. Click a sentence's first word for a full sentence repetition.

### Voice meter

The pointer shows microphone level: quiet on the left, the target range in the middle, loud on the right. A green feedback label also requires a recent match between recognized speech and the script. Pauses and an inactive microphone are neutral.

This is an approximate reception hint. It does not grade pronunciation or accents, measure noise or reverberation, or certify intelligibility. See [Architecture](docs/ARCHITECTURE.md) for thresholds and timing.

### Optional OpenAI mode

Choose **OpenAI · online → OpenAI einrichten** and enter your own API key. Audio and script-derived vocabulary hints are transmitted to OpenAI while reading. API billing and account model access are required; a ChatGPT subscription is not an API key.

The integration uses **gpt-live-transcribe**, selected-language hints, 24 kHz PCM16 mono audio and configurable delay. Configuration follows the [official OpenAI Realtime transcription documentation](https://developers.openai.com/api/docs/guides/realtime-transcription), reviewed on 2026-10-07. The implementation commits audio every ten seconds; it does not implement client-side VAD.

The key remains in memory unless you explicitly save it to macOS Keychain. Clear the field and click the save button to remove a saved key. No key is included in this repository, and tests do not require one.

## Development and validation

    ./scripts/test.sh
    ./scripts/build.sh
    python3 scripts/check-source.py
    python3 scripts/archive-source.py

Python 3.9+ is needed only for the source hygiene and packaging tools. ShellCheck is optional for local shell linting.

The Swift test runner performs **91 deterministic checks**: 20 for localization and multilingual alignment, 33 for script alignment, 27 for voice-meter states and measurements, and 11 for the OpenAI session configuration. Eight additional Python tests cover source packaging and hygiene:

    python3 -m unittest discover -s Tests -p '*Tests.py'

The GitHub workflow runs both suites, builds an ad-hoc signed app, and checks source hygiene without microphone access or API credentials.

See [Validation](docs/VALIDATION.md) for the evidence and limits, and [GitHub Actions](https://github.com/KhademOHAli1/teleprompter-mac/actions/workflows/ci.yml) for hosted macOS 26 checks. Recognition latency, accuracy and long-session behavior must be measured with representative voices and microphones.

CLI diagnostics, kept separate from normal app use:

    dist/Teleprompter.app/Contents/MacOS/Teleprompter --prepare-model
    dist/Teleprompter.app/Contents/MacOS/Teleprompter --transcribe-file example.aiff

The file diagnostic prints transcripts to the terminal. Use non-sensitive recordings for bug reports.

## Project structure

| Path | Purpose |
| --- | --- |
| Sources/Alignment.swift | Script layout and bounded word alignment |
| Sources/SpeechSessions.swift | Microphone capture, speech backends and Keychain |
| Sources/RealtimeConfiguration.swift | Pure OpenAI session configuration |
| Sources/PrompterModel.swift | App state, cancellation, seek and resume |
| Sources/PrompterView.swift | Native text rendering and eased scrolling |
| Sources/VoiceQuality*.swift | Audio measurements, reception hints and meter |
| Sources/App.swift | Localized interface and shortcuts |
| Sources/Launcher.swift | App entry point and CLI diagnostics |
| Tests/ | Offline regression checks |
| scripts/ | Build, tests and source packaging |

## License and credits

The source code and included demo are available under the [MIT license](LICENSE). Apple's frameworks and speech assets, Xcode, and OpenAI's services/models are separate products governed by their providers.

The initial implementation was developed with AI assistance. Contributions are welcome through [issues and pull requests](CONTRIBUTING.md).
