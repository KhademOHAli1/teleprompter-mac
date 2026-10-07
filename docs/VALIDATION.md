# Validation

Source version: **1.4.0**, prepared on **2026-10-07**.

## Automated evidence

- **33 alignment checks:** growing/replayed partials, corrections, repeated phrases, fillers, skipped words, joined/split German compounds, spoken numbers, Unicode ranges, seek, long cumulative results, stage directions and empty-result confidence.
- **27 voice-quality checks:** normalized RMS/peak measurements, clipping, silence, target scale, recent/stale matches, partial-correction grace, pauses and restart.
- **11 OpenAI configuration checks:** transcription session type, PCM rate, model, plural language hint, disabled server VAD, delay validation, bounded vocabulary, JSON serialization and absence of credentials.
- **6 source packaging tests:** generated/private file exclusion, required files, symlinks, recordings inside source trees, credential/home-path detection and safe text.

Run with **./test.command** and **python3 -m unittest discover -s Tests -p '*Tests.py'**. These are offline checks, not recognition benchmarks.

The source checker reads only selected project text files. It detects several common secret/path patterns and validates script modes, relative documentation links and SPDX identifiers. It is not a complete secret scanner or a security audit.

## Local build

The standalone source was built on an Apple Silicon Mac with macOS 26, Swift 6.4 and macOS SDK 27, using Swift 5 language mode and warnings treated as errors. The build signs and strictly verifies a plain staging bundle before copying it to the destination app.

The source ZIP was extracted into a fresh directory with spaces in its path. All 71 Swift checks and six packaging tests for the earlier 1.3.0 source passed there, and a complete app build succeeded without files from the original workspace. Shell scripts passed Bash syntax checks and ShellCheck; Info.plist passed validation. Git staging and whitespace checks in that extracted copy excluded generated build output.

The archive's 41 selected text files were checked for integrity, executable script modes and absence of generated/private directories. A separate bundle identifier was used to launch the freshly built app: its editor started empty with the local provider selected. Loading the neutral built-in demo and opening the reading view visibly showed centered text and the inactive voice meter. No microphone or OpenAI session was started during this UI smoke check.

Workflow YAML parsed successfully; read-only permissions and the selected macOS runner were checked.

## Hosted GitHub checks

[GitHub Actions](https://github.com/KhademOHAli1/teleprompter-mac/actions/workflows/ci.yml)
runs the offline suites, source hygiene checks, app build with ad-hoc signature
verification and source packaging on macOS 26. The workflow page reports each
commit's result. The SwiftUI layout, sheets, preference handlers and alert use
separate view expressions and an explicitly typed alert binding to reduce
type inference work on the hosted compiler.

## Recognition evidence and limits

Earlier local versions were observed recognizing a neutral German audio file, including spoken numbers, and following a user-read script through the microphone. A user-started session with OpenAI selected also visibly advanced the script before this source preparation.

Those observations do not establish a word error rate, fixed latency, dialect coverage, comparative provider accuracy, or long-session reliability for this release. Online configuration regression checks do not authenticate a live OpenAI account.

A fresh-Mac compatibility matrix, signed/notarized binary release and extended microphone acceptance run remain separate release work.

## Multilingual update

The interface uses platform locale negotiation, with four complete 196-key
catalogues and localized permission strings in the native app. Language-specific
regression checks cover English/French/Spanish spoken numerals, Chinese/Japanese
word boundaries, Arabic tracking, Turkish case mapping, Hindi combining marks
and UTF-16 highlight offsets. Native validation includes 91 Swift checks and
eight Python tests; the MCP app includes 46 tests. Real microphone acceptance
for every added language remains separate from these deterministic tests.
