# Changelog

## 1.4.0 — 2026-10-07

- Follow the platform language for the interface, with English, German, French and Spanish resources and English fallback.
- Select the script's speech language independently of the interface.
- Use locale-aware word segmentation, number normalization and right-to-left text direction.
- Pass the chosen language to speech recognition and OpenAI without translating the script.
- Add multilingual and localization regression checks.


## 1.3.0 — 2026-10-07

Initial standalone open-source source release.

- MIT license, English/German documentation, contribution guidance and privacy notes.
- Self-contained build and test scripts with ignored build output and caches.
- GitHub CI configuration and source-only packaging.
- Neutral example text; no user script, audio, keys or machine-specific paths.
- Bounded local audio stream and an explicit overload error.
- Empty recognition results clear stale match confidence.
- Pure OpenAI configuration with offline protocol regression checks.
- Bundle-specific Keychain service and checked key deletion.

## 1.2 — 2026-10-07

- Centered microphone reception meter with RMS/peak measurements, script-match feedback and neutral pauses.

## 1.1 — 2026-10-07

- Narrow centered column, adjustable width and visual word lead.
- More direct scrolling and small, unspoken bracketed stage directions.

## 1.0 — 2026-10-07

- Native German voice-following teleprompter with local and optional online recognition.
