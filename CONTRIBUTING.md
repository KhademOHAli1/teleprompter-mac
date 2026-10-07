# Contributing

Small, focused fixes and improvements are welcome. Describe the user-visible problem, the resulting behavior, and how you verified it.

## Getting started

Use an Apple Silicon Mac with macOS 26+ and Xcode 26+. There is no dependency install step.

    ./test.command
    ./build.command
    python3 scripts/check-source.py

Build and test scripts work from any current directory. The core regression tests use neutral synthetic examples and do not start a microphone or contact OpenAI.

## Changes

- Keep the German interface clear and readable.
- Preserve pause behavior, stable partial-result anchors, and manual seek.
- Add a focused regression check when changing matching, meter logic or the API protocol.
- Use four-space indentation for Swift; keep comments in English.
- Keep credentials out of code, screenshots, fixtures, issue descriptions and logs.
- Describe live recognition evidence separately from deterministic test results.
- Include microphone/provider conditions when reporting latency or recognition quality.
- Avoid claiming that the meter objectively grades pronunciation.

Please use neutral reproduction scripts. Do not attach another person's voice recording or private text without permission.

Submit a pull request with a concise description and relevant validation. Changes submitted for inclusion are contributed under this project's MIT license.
