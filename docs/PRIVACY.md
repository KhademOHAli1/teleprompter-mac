# Privacy and data handling

## Local mode

**Mac · lokal** uses Apple's on-device German SpeechTranscriber. This app does not send the script or microphone audio to OpenAI in local mode. macOS may download German speech assets when they are not installed.

The application does not write microphone recordings to disk. Audio buffers, transcripts and recognition context are held in memory during a session. The operating system can have its own device, model-download and diagnostic behavior.

## OpenAI mode

**OpenAI · online** sends live microphone audio, a generic transcription prompt and up to 60 vocabulary hints taken from the script to OpenAI. Audio can reveal other sounds within microphone range. The provider's API terms, retention settings and billing apply.

This mode is explicitly selected by the user. Local is the initial default on a fresh preference domain. Pausing or closing the app stops its capture and connection; audio already sent is subject to provider policies.

## Local storage

- The script draft and reading preferences are saved in macOS UserDefaults under the app's bundle identifier.
- The app does not automatically erase a draft on quit.
- Recognized transcripts are not intentionally persisted by normal app use.
- The API key stays in memory unless the user explicitly saves it to Keychain.
- Keychain uses a service derived from the bundle identifier, ending in **.openai**, and the account **api-key**.
- Clearing the key field and saving removes the saved key. To erase the draft, clear it in the editor.
- Build artifacts and caches are local files in **dist/** and **.build/**; they contain compiled program code.

Changing the bundle identifier gives a fork its own preferences and Keychain service.

## Diagnostics and reports

The **--transcribe-file** diagnostic prints the selected recording's transcript to the terminal. Terminal logging or redirection can persist that text. The normal app does not include analytics, advertising, crash upload, or a project-operated backend.

The source archive includes only selected code, tests, documentation, workflow files and a neutral demo. It excludes local preferences, Keychain contents, private scripts, recordings, build output and Git metadata.

Before sharing a screenshot or issue, use a neutral script and remove credentials and identifying information.
