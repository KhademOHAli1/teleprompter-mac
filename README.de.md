# Teleprompter für Mac

Ein nativer deutscher Teleprompter, der deiner Stimme folgt. Du fügst deinen Text ein und liest in deinem Tempo. Bei Sprechpausen bleibt die Leseposition stehen.

[English](README.md) · [Datenschutz](docs/PRIVACY.md) · [MIT-Lizenz](LICENSE)

## Voraussetzungen

- Mac mit Apple Silicon und macOS 26 oder neuer.
- Xcode 26 oder neuer als aktive Entwicklerwerkzeuge.
- Mikrofonzugriff und deutsches Sprachmodell von macOS.

Es gibt keine externen Paketabhängigkeiten. Intel-Macs und ältere macOS-Versionen werden derzeit nicht als Build-Ziel unterstützt.

## Bauen und starten

Im Projektordner ausführen:

    ./test.command
    ./build.command
    open dist/Teleprompter.app

Alternativ **start.command** doppelklicken. Das Skript baut die App bei Bedarf und öffnet sie anschließend. Die erzeugte App ist für lokale Nutzung ad-hoc signiert. Für signierte und notarisierte Veröffentlichungen siehe [Releasing](docs/RELEASING.md).

## Vorlesen

1. Deinen Text einfügen oder den [neutralen Beispieltext](examples/demo-de.txt) verwenden.
2. **Mac · lokal** wählen und **Vorlesen starten** anklicken.
3. Mikrofonzugriff erlauben und in der ausgewählten Skriptsprache vorlesen.

Textbreite, Schriftgröße und Wortvorlauf lassen sich einstellen. Die schmale Textspalte ist mittig angeordnet. Regiehinweise wie **[PAUSE]** erscheinen kleiner und werden beim Wortabgleich übersprungen.

**⌘R** startet oder pausiert. **⌘E** öffnet den Editor. **⌘↑ / ⌘↓** wechseln den Satz. Ein Klick auf ein Wort setzt die Leseposition.

## Stimm-Check

Unten mittig zeigt ein Barometer den Mikrofonpegel. Links ist leise, in der grünen Mitte liegt der Zielbereich, rechts ist laut. Ein grüner Hinweis bedeutet zusätzlich, dass erkannte Wörter aktuell zum Skript passen. Sprechpausen und ein ausgeschaltetes Mikrofon bleiben neutral.

Die Anzeige bietet eine Näherung für Audioaufnahme und Texterkennung. Sie ist kein objektiver Aussprache-, Akzent- oder Verständlichkeitstest.

## OpenAI optional

Unter **OpenAI · online → OpenAI einrichten** kannst du deinen eigenen API-Schlüssel eintragen. Während des Vorlesens werden Mikrofon-Audio und Begriffshinweise aus deinem Text an OpenAI gesendet. Es entstehen API-Kosten. Die Integration verwendet **gpt-live-transcribe**.

Der Schlüssel bleibt zunächst im Arbeitsspeicher. Nur über den Speicherbutton wird er im macOS-Schlüsselbund abgelegt. Ein leeres Feld und derselbe Button entfernen den gespeicherten Schlüssel.

Im lokalen Modus sendet die App Audio und Skript nicht an OpenAI. Das deutsche Modell wird bei Bedarf von macOS geladen. Dein Text wird lokal in den App-Einstellungen gespeichert. Das Quellpaket enthält ausschließlich Code, Dokumentation, Tests und einen neutralen Beispieltext.

## Entwicklung

    ./test.command
    ./build.command
    python3 scripts/check-source.py
    python3 scripts/archive-source.py

Python 3.9+ wird nur für Paketprüfung und Quellcode-ZIP benötigt. Es gibt **91 Swift-Prüfungen und acht Python-Tests für die Paketprüfung**. Build und Tests sind lokal überprüfbar; der vorbereitete GitHub-Workflow benötigt keine Schlüssel und keinen Mikrofonzugriff.

Details: [Architektur](docs/ARCHITECTURE.md), [Prüfnachweise](docs/VALIDATION.md), [Mitwirken](CONTRIBUTING.md) und [Veröffentlichung](docs/RELEASING.md).

## Sprachen

Die Oberfläche folgt der App-Sprache in macOS beziehungsweise der Sprache des
MCP-Hosts oder Browsers. Englisch, Deutsch, Französisch und Spanisch sind
enthalten; für andere Oberflächensprachen wird Englisch verwendet. Die
Skriptsprache lässt sich unabhängig davon auswählen. Der Text wird nicht
übersetzt. Die verfügbaren Erkennungssprachen hängen vom Anbieter ab.
Weitere Informationen: [Lokalisierung](docs/LOCALIZATION.md).
