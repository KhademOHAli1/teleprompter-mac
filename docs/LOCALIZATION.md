# Localization

The interface and script language are independent. Choosing English speech on
a German system leaves the interface German and transcribes English.

Included interface translations: English, German, French and Spanish. This is
localization with shipped resources, not automatic translation of arbitrary UI
strings. Unsupported interface languages use English. Scripts are preserved.
Samples are included in these four languages; other selected speech languages
receive the English sample. Paste a sample in the selected language instead.

Recognition support is provider-dependent; it is not implied by UI translation.
OpenAI receives a selected input-language hint using the [official Realtime
transcription language format](https://developers.openai.com/api/docs/guides/realtime-transcription).
Unsupported API languages can be rejected by the provider. Real microphone
accuracy and latency have not been measured for every language.

## Native platform behavior

`NSLocalizedString` and `Bundle` load `Resources/<language>.lproj/Localizable.strings`
using macOS app language preferences. `CFBundleDevelopmentRegion` is English.
Microphone and speech permission messages use `InfoPlist.strings`. There is no
app-specific interface-language override; use macOS Language & Region/app language.

Speech defaults to `Locale.preferredLanguages`, with an independent saved
selection. Local language options come from `SpeechTranscriber.supportedLocales`
at runtime. A missing local locale reports an error rather than silently using
German. The OpenAI provider offers common locale choices. `NLTokenizer` uses the
script locale for sentence/word boundaries. `NumberFormatter` spells out numbers
in that locale. Joined spoken numerals are bounded to eight tokens.

For a diagnostic, use `--prepare-model --locale en-US` or
`--transcribe-file example.aiff --locale fr-FR`.

## Add a translation

Copy `en.lproj` to a new language's `.lproj` folder. Translate values in both
`.strings` files and `Demo.txt`; preserve keys and `{0}`/`{1}` placeholders.
Add the language to `CFBundleLocalizations` and localization resource tests.
The build and source archive include `.lproj` resources automatically.

Run `./test.command`, the Python suites and `./build.command`. Inspect long
labels and permission text in the target macOS app language before publishing.
