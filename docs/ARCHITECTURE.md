# Architecture

## Script and alignment

**PromptScript** uses NaturalLanguage sentence tokenization and Foundation regular expressions to create UTF-16 text ranges. Bracketed stage directions remain visible but are excluded from the spoken-word list. Spoken sentence indexes are remapped after removing directions.

**WordNormalizer** uses locale-aware case mapping, Latin diacritics, sharp S and platform integer spell-outs below one million. Hyphenated text can become multiple tokens. Date abbreviations can produce short sentence boundaries.

**WordTracker** uses bounded local sequence alignment against the last 32 recognized tokens. Utterance identities hold fixed anchors, so revised or replayed partial results do not repeatedly consume the same phrase. Fuzzy matches, fillers, skipped words and joined/split compounds are supported. Large position jumps require multiple exact matches. The cursor moves forward until an explicit seek or reset.

The reported match ratio is an application alignment measure, not speech-model confidence.

## Audio and providers

**AudioCapture** copies microphone buffers, converts formats on a serial queue, and calculates RMS/peak measurements from the first input channel. The app uses the system's default input device. The capture path expects the normal AVAudioEngine floating-point microphone format. A device change stops recognition and asks for a restart.

The local provider uses SpeechTranscriber in the selected locale with volatile/fast results and no word-timestamp attributes. A result's audio start time identifies its utterance. The analyzer stream has an 80-buffer limit and stops on overflow.

The online provider uses URLSession WebSocket, **gpt-live-transcribe**, selected-language hints and up to 60 unique capitalized script terms. It sends PCM16 mono at 24 kHz through a serialized 80-buffer stream. Slow delivery stops the session instead of silently dropping audio. Audio is committed every ten seconds to bound transcript items. Client-side VAD, automatic reconnect and session resume are not implemented.

The app never records microphone audio to a file. The explicit CLI file diagnostic prints recognized text to stdout.

## Lifecycle and rendering

**PrompterModel** owns microphone permission, provider sessions, cancellation and a generation identifier. Callbacks from an old generation cannot update a new session. Seek restarts a running stream with fresh anchors.

SwiftUI owns the controls. An AppKit NSTextView highlights the next word and active sentence. A 60 Hz timer eases scrolling toward the reading line at 38% of the viewport height. Visual word lead follows matches; completion still uses the confirmed tracker cursor.

## Voice meter

RMS energy is smoothed over 120 ms. Near-full-scale peaks are held for 750 ms. The heuristic average-level target is -34 to -12 dBFS, mapped to the middle green band. The scale is deliberately nonlinear so the target remains centered.

A green feedback label requires a recent script match of at least 0.65. A 900 ms grace period reduces flicker from volatile corrections; a match cannot remain green beyond two seconds without refresh. A pause after 850 ms without signal is neutral. Missing audio callbacks, silence, inactive capture and empty recognition do not claim healthy reception.

Neither peak detection nor the script-match ratio certifies intelligibility or pronunciation quality. Noise, reverberation, gain control, accent and delayed recognition can affect the hint.

## Locale handling

See [localization](LOCALIZATION.md) for platform language negotiation, separate
speech-language selection, multilingual tokenization and provider limits.
