---
description: Aufgabenbranch lokal nach main mergen, versionieren, taggen und aufräumen
---

Führe den folgenden lokalen Merge-/Release-Ablauf für den aktuellen Aufgabenbranch aus. Dieser Aufruf erlaubt ausdrücklich den Merge nach main, den beschriebenen Versions-Commit auf dem Aufgabenbranch, einen lokalen Release-Tag und das Löschen genau dieses vollständig gemergten Aufgabenbranches. Niemals pushen, Remote-Änderungen vornehmen oder Tests, Validierung, Kompilierung, Deployment oder Flashen ausführen.

Versionsargument: $ARGUMENTS

## Argumente

- Ohne Argument gilt `minor`.
- `minor`: MAJOR.MINOR.PATCH -> MAJOR.(MINOR+1).0.
- `patch`: MAJOR.MINOR.PATCH -> MAJOR.MINOR.(PATCH+1).
- `major`: MAJOR.MINOR.PATCH -> (MAJOR+1).0.0.
- `X.Y.Z` oder `vX.Y.Z`: genau diese neue Version, ohne führende Nullen, größer als die bisherige Version.
- `none`: nur Merge und Branch-Cleanup, ohne Versionsänderung oder Tag.
- Bei anderen oder widersprüchlichen Angaben nachfragen, statt eine Version zu erraten. Argumente nicht ungeprüft in Shell-Befehle einsetzen.

## Vorprüfung

1. Lies die aktuellen Repository-Regeln. Prüfe `git status --short --branch`, `git diff` und `git diff --cached`. Bei uncommitteten, vorgemerkten oder unversionierten Änderungen abbrechen und um einen vorherigen Commit bitten; nichts automatisch committen, stashen, löschen oder verwerfen.
2. Ermittle den aktuellen Branch. Auf main oder bei detached HEAD abbrechen: Es muss ein vorhandener Aufgabenbranch als Merge-Quelle ausgewählt sein. Dies ist die Fortsetzung seiner Aufgabe; keinen neuen Branch anlegen.
3. Prüfe, dass der lokale Branch main existiert, keine laufende Merge-/Rebase-Operation vorliegt und main ein Vorfahr des Aufgabenbranches ist. Andernfalls abbrechen und die notwendige Aktualisierung des Aufgabenbranches melden; nicht eigenständig rebasen, Konflikte auflösen oder einen Merge-Commit auf main erstellen.
4. Zeige die ausstehenden Commits (`main..Aufgabenbranch`) und die zusammengefassten Änderungen (`main...Aufgabenbranch`). Berücksichtige dabei auch mitgeführte Commits früherer Aufgabenbranches. Bei erkennbar sachfremden Änderungen nachfragen. Ohne ausstehende Commits keinen neuen Release erzeugen.

## Version vorbereiten – nur wenn nicht `none`

5. Die zentrale Projektversion liegt in `packages/ng-eg-gang-wallbox-hmi/version.yaml` als `substitutions.firmware_version`. Die bisherige Version ist der Stand dieser Datei auf dem lokalen main, nicht eine bereits auf dem Aufgabenbranch vorbereitete Erhöhung. `esphome.min_version` ist keine Projektversion und darf dafür nicht geändert werden.
6. Fehlt die Versionsdatei auf main, verwende den numerisch höchsten erreichbaren Tag im exakten Format `vMAJOR.MINOR.PATCH` auf main. Gibt es weder Datei noch solche Tags, verwende `0.0.0` als Ausgangspunkt: Der erste Standardlauf ergibt somit `0.1.0`. Bei widersprüchlichen Versionsdateien oder neueren erreichbaren Release-Tags nicht raten, sondern nachfragen.
7. Berechne die neue Version entsprechend dem Argument. Prüfe vor Dateiänderungen, dass der geplante Tag `vX.Y.Z` im gesamten lokalen Repository noch nicht existiert. Vorhandene Tags niemals überschreiben, verschieben oder löschen.
8. Bereite die Versionsänderung ausschließlich auf dem Aufgabenbranch vor. Existiert dort bereits eine abweichende vorbereitete Version, verwende sie nur, wenn sie genau der berechneten Zielversion entspricht; andernfalls nachfragen, statt sie stillschweigend zu ersetzen oder doppelt zu erhöhen.
9. Falls die Projektversionierung noch fehlt, lege die zentrale Datei mit folgendem Inhalt für die berechnete Version an:

   ```yaml
   substitutions:
     firmware_version: "X.Y.Z"
   ```

   Binde sie in `ng-eg-gang-wallbox-hmi.yaml` unter `packages` ein:

   ```yaml
   project_version: !include packages/ng-eg-gang-wallbox-hmi/version.yaml
   ```

   Setze unter dem bestehenden `esphome`-Block die Projektmetadaten, ohne Gerätekennung, friendly_name oder Mindestversion zu verändern:

   ```yaml
   project:
     name: wallbox.hmi
     version: "${firmware_version}"
   ```

   Ist bereits ein Projektname vorhanden, behalte ihn bei. Bestehende Projektmetadaten nicht überschreiben. Die aktuelle Firmware-Version nicht zusätzlich als unabhängigen Wert in anderen Dateien pflegen.
10. Committe nur tatsächlich notwendige Versions-/Metadatenänderungen auf dem Aufgabenbranch, mit englischer Nachricht `feat: prepare release vX.Y.Z`. Ist diese Zielversion bereits vollständig eingebunden und committed, keinen leeren Versions-Commit erstellen. Bei der ersten Einführung die Aussagen zur noch fehlenden Versionierung in AGENTS.md/README.md gezielt aktualisieren und diese Änderungen demselben Vorbereitungs-Commit zuordnen.

## Merge, Tag und Cleanup

11. Prüfe erneut, dass das Arbeitsverzeichnis sauber ist. Wechsle auf main und merge ausschließlich mit `git merge --ff-only Aufgabenbranch`. Bei einem Fehler sofort stoppen, nicht auf einen erzwungenen Merge, Reset oder Rebase ausweichen.
12. Bei einer Versionserhöhung erzeuge auf dem neuen main-HEAD einen annotierten lokalen Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`. Prüfe, dass der Tag auf denselben Commit wie main zeigt. Ein Tag bezeichnet hier einen vom Nutzer angeforderten Versionsstand, nicht automatisch getestete Firmware. Schlägt das Taggen fehl, den Aufgabenbranch behalten und den Teilstand melden.
13. Erst nach erfolgreichem Merge und gegebenenfalls Taggen den ursprünglichen Aufgabenbranch mit `git branch -d Aufgabenbranch` löschen. Keine anderen Branches, Remote-Branches, Dateien, Backups oder Worktrees entfernen. Schlägt das sichere Löschen fehl, nicht `-D` verwenden, sondern den Grund melden.
14. Abschließend Branch, Arbeitsverzeichnis, Commit und gegebenenfalls Tag prüfen. Kurz auf Deutsch berichten: gemergter Branch, neue Version/Tag oder bewusst ausgelassener Versionsschritt, Cleanup und verbleibende lokale Änderungen. Ausdrücklich erwähnen: keine Tests ausgeführt, nichts gepusht. Für eine spätere neue Entwicklungsaufgabe wieder einen eigenen Aufgabenbranch anlegen.
