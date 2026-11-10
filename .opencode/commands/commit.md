---
description: Änderungen committen und bei Codeänderungen die Patch-Version erhöhen
---

Schau dir mit git status und git diff die aktuellen Änderungen an.
Vor jeder neuen Aufgabe einen eigenen, nach der Aufgabe benannten Branch mit englischem Namen anlegen. Niemals auf main arbeiten oder committen. Stehst du auf main oder auf keinem Branch (detached HEAD), wechsle vor Änderungen und vor dem Commit auf einen neuen Aufgabenbranch. Bei Fortsetzung derselben Aufgabe den bestehenden Aufgabenbranch verwenden. Nicht nach main mergen.
Fasse die Änderungen in einem Commit zusammen. Die Nachricht ist englisch, im Format "feat: ...", "fix: ..." oder "docs: ...".

Jeder Commit, der Code ändert, erhält genau eine Patch-Erhöhung der Projektversion (MAJOR.MINOR.PATCH -> MAJOR.MINOR.(PATCH+1)). Dazu zählen Änderungen an C/C++-, Python- und PowerShell-Code, Tests sowie funktionale Änderungen an ESPHome-YAML und buildrelevanter Konfiguration. Reine Dokumentations-, Kommentar- und Formatierungsänderungen sowie OpenCode-Command-/Regel-Markdown benötigen keine Patch-Erhöhung. Ein gemischter Commit mit Code und Dokumentation erhält genau eine Erhöhung, nicht eine pro Datei.

Lies die Ausgangsversion aus `packages/ng-eg-gang-wallbox-hmi/version.yaml` im letzten Commit des aktuellen Branches (HEAD), nicht aus main oder einem bereits bearbeiteten Arbeitsstand. Erhöhe nur `substitutions.firmware_version`; `esphome.min_version` und unabhängig davon verwaltete Tool-Versionen bleiben unverändert. Ist im Arbeitsverzeichnis bereits genau diese neue Patch-Version vorbereitet, übernimm sie ohne weitere Erhöhung. Bei fehlender, ungültiger oder abweichend vorbereiteter Version nachfragen, statt sie zu überschreiben. Ein Wiederholungsversuch nach fehlgeschlagenem Commit darf keine zusätzliche Erhöhung verursachen.

Nimm die Versionsdatei zusammen mit den zugehörigen Codeänderungen in denselben Commit auf, ohne separaten Versions-Commit. Pflege die zugehörigen Änderungen in `CHANGELOG.md` unter `Unreleased`. Bei einem reinen Versions-/Release-Vorbereitungscommit keine rekursive zusätzliche Patch-Erhöhung durchführen. Keine rückwirkenden Versionsänderungen oder Amend-Commits erzeugen.

Der `/commit`-Aufruf erlaubt die beschriebene Patch-Erhöhung ausdrücklich, aber keine Tests, Validierung, Kompilierung, Deployment oder Flashen. Keine Tags erzeugen und nicht nach main mergen; Release-Tags bleiben dem ausdrücklichen `/merge`-Aufruf vorbehalten. Berichte abschließend auch die resultierende Version beziehungsweise, warum kein Versionsschritt nötig war.

Committe nur Dateien, die zur Änderung gehören. Pushe niemals.
