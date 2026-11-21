# Wallbox-HMI

Änderungen und Release-Historie stehen in [CHANGELOG.md](CHANGELOG.md). Neue Änderungen werden unter `Unreleased` gesammelt und beim versionierten `/merge` der neuen Version zugeordnet; bei `/merge none` bleiben sie unveröffentlicht.

## Lokaler Merge-/Release-Command

`/commit` erhöht bei jedem Commit mit Codeänderungen die Patch-Version genau einmal und nimmt die Versionsdatei in denselben Commit auf. Grundlage ist die bisherige Version auf dem jeweiligen Aufgabenbranch, nicht `main`. Reine Doku-/Kommentaränderungen bleiben ohne Versionsschritt. Changelog-Einträge bleiben zunächst unter `Unreleased`; `/commit` erzeugt keine Tags und führt keine Tests aus.

`/merge` führt den aktuellen, bereits committeten Aufgabenbranch per Fast-forward nach `main`, erhöht standardmäßig die Minor-Version, erstellt einen annotierten lokalen Tag `vX.Y.Z` und löscht danach genau diesen gemergten Aufgabenbranch. Alternativen: `/merge patch`, `/merge major`, `/merge 1.2.3` oder `/merge none` ohne Versionsänderung und Tag. Bei uncommitteten Änderungen oder nicht möglichem Fast-forward stoppt der Command. Er pusht nichts und führt keine Tests, Builds oder Deployments aus.

Die zentrale Projektversion steht in `packages/ng-eg-gang-wallbox-hmi/version.yaml` als `firmware_version` und wird über die Haupt-YAML in den ESPHome-Projektmetadaten von `wallbox.hmi` verwendet. `esphome.min_version` bleibt davon unabhängig. Die Versionsvorbereitung wird auf dem Aufgabenbranch committed, nicht auf `main`; ein Tag ist keine Bestätigung eines Hardwaretests.

Bereits durch `/commit` erzeugte Patch-Zwischenversionen werden beim Merge berücksichtigt: Ein Minor-Release wird weiterhin beispielsweise aus `0.2.x` zu `0.3.0`; `/merge patch` übernimmt eine bereits höhere Patch-Version derselben MAJOR.MINOR-Basis, statt sie zurückzusetzen oder nochmals zu erhöhen. Eine ausdrücklich angegebene Zielversion darf nicht unter der bereits committeten Branch-Version liegen.

## Zielhardware

**Waveshare ESP32-S3-Touch-LCD-7** (Touch-Version, nicht 7B oder 7C).

- ESP32-S3N16R8: Dual-Core bis 240 MHz, 16 MB Flash, 8 MB PSRAM.
- 7-Zoll-IPS-Display mit 800 × 480 Pixeln und RGB-Schnittstelle.
- Kapazitiver 5-Punkt-Touch über I²C.
- Stromversorgung über USB-C mit 5 V.

[Offizielle Hardware-Dokumentation mit Pinbelegung, Schaltplänen und Beispielen](https://docs.waveshare.com/ESP32-S3-Touch-LCD-7)

### Wichtige Hardware-Abhängigkeiten

- I²C auf GPIO8 (SDA) und GPIO9 (SCL) wird von Touch, CH422G-I/O-Expander und externen I²C-Geräten gemeinsam genutzt.
- Display-Hintergrundbeleuchtung (EXIO2) und Touch-Reset (EXIO1) werden über den CH422G gesteuert, nicht direkt über ESP32-GPIOs.
- USB und CAN teilen GPIO19/20; CH422G EXIO5 schaltet zwischen USB (Low) und CAN (High) um.

### Lokale HMI-Pufferbatterie

Die Titelzeile zeigt die Spannung der lokalen 1S-Pufferbatterie wie im Referenzprojekt als `HMI 4.12 V`. Die Batterie wird an J3 angeschlossen. Für die Messung muss **TP1 mit J8 Pin 3 / AD (GPIO6)** verbunden sein: Der vorhandene Spannungsteiler (200 kΩ / 100 kΩ) liefert dort ein Drittel der Batteriespannung. Die Batterie niemals direkt mit dem ADC-Eingang verbinden. Ohne diese Messverbindung ist der ADC-Wert nicht zuverlässig; die Software erkennt eine fehlende Batterie oder eine offene Messleitung nicht sicher.

Der ADC wird mit 6 dB Dämpfung alle 5 Sekunden gelesen; Faktor 3 stellt die Batteriespannung wieder her, ein gleitender Mittelwert glättet die letzten fünf Messungen. Wie im Referenzprojekt ist die Anzeige unter 3,50 V rot, von 3,50 bis unter 3,70 V gelb und ab 3,70 V grün. Vor dem ersten gültigen Messwert erscheint `HMI --.-- V` in Grau. Die Spannung wird außerdem als Diagnose-Sensor `HMI Battery Voltage` bereitgestellt. Die Anzeige funktioniert unabhängig von Home Assistant und ist nicht mit der Solar-Batteriebank auf der Hauptseite zu verwechseln. Die Messung am eigenen Aufbau mit einem Multimeter abgleichen; die Farbschwellen sind nur Hinweise, kein Batterie- oder Tiefentladeschutz.

## Shared Waveshare Base

Board, display, touch, backlight, LVGL, the local backup battery, fonts, theme, the persistent header and the navigation geometry come from the shared base [waveshare-esphome-base](https://github.com/anwa/waveshare-esphome-base). `waveshare_base_ref` in `ng-eg-gang-wallbox-hmi.yaml` pins the base release; `packages/ng-eg-gang-wallbox-hmi/waveshare-base.yaml` loads it. ESPHome downloads the base from GitHub at build time, also in the Home Assistant add-on; the tag must therefore be published.

The display turns its backlight off after 60 seconds without touch. The first touch on the dark display only wakes it and does not operate the control underneath.

To develop against a local working tree of the base, clone it next to this repository and run:

```powershell
..\waveshare-esphome-base\scripts\use-local-base.ps1 -Package packages/ng-eg-gang-wallbox-hmi/waveshare-base.yaml
esphome -s waveshare_base_package packages/ng-eg-gang-wallbox-hmi/waveshare-base.local.yaml compile ng-eg-gang-wallbox-hmi.yaml
```

The generated `*.local.yaml` file is ignored by Git and skipped by `deploy-ha.ps1`. Without `-s`, the build uses the pinned tag again.

## Erste GUI-Version

Die Firmware-Konfiguration liegt in `ng-eg-gang-wallbox-hmi.yaml`. Display und GT911-Touch
sind für das Waveshare-Board eingerichtet. Die Gestaltung orientiert sich am
Referenzprojekt `..\R4875G1-Charger\esphome-r4875g1-3phase-charger`.

Eine feste Titelzeile zeigt die Firmware-Version neben dem Titel, Uhrzeit, lokale HMI-Batteriespannung und HA-Verbindung; unten bleiben fünf
Navigationsbuttons auf allen Seiten sichtbar:

- **Übersicht:** Ladeleistung, Ladezustand mit HA-Statustext, geladene Energie,
  PCB-Temperatur und zurückgemeldete Stromvorgabe. Rechts zeigt die Karte
  **BATTERY BANK** den SOC, Leistung, Spannung, Strom, Temperatur und Betriebszustand
  der Solar-Batteriebank. Eine separate Battery-Unterseite gibt es nicht.
- **Phasen:** Spannung und Strom für L1, L2 und L3.
- **Trends:** umschaltbare Leistung, Spannung, Strom und PCB-Temperatur.
  Spannung/Strom enthalten jeweils drei farbige Phasenkurven.
- **Ladestrom:** bestätigte Anfragen für 0, 6, 10, 12 oder 16 A über den bestehenden
  HA-Helfer `input_select.wallbox_max_current_buttons`. Auswahl im Helfer und
  Wallbox-Rückmeldung werden getrennt dargestellt. Eine erfolgreiche HA-Anfrage
  bestätigt noch nicht, dass die Wallbox den Strom bereits übernommen hat.
- **System:** IP-Adresse, farbig bewertetes WLAN-Signal, Laufzeit, CPU-Temperatur,
  lokale Pufferbatterie mit geschätztem SOC, freier Heap, größter freier Heap-Block,
  freier PSRAM, maximale Loop-Zeit und CPU-Takt. Statt der Rectifier-Anzeigen des
  Referenzprojekts erscheinen HA-Verbindung, Wallbox-Zustand, Stromvorgabe und
  Neustartgrund des HMI. Die Seite enthält keine Neustart- oder Steuerungsbuttons.

Die Systemseite verwendet lokale ESPHome-Diagnosesensoren und wird nur bei geöffneter Seite im bestehenden 1-Sekunden-UI-Takt aktualisiert. Die Sensoren messen unabhängig davon weiter; Speicher-/Loop-Daten kommen vom vorhandenen 5-Sekunden-Debug-Takt, CPU-Temperatur, Laufzeit und WLAN-Signal werden alle 10 Sekunden erfasst. Lokale Diagnosen bleiben ohne HA verfügbar; nicht verfügbare Wallbox-Werte erscheinen als `--`. Die angezeigte lokale Batterie-SOC ist lediglich die aus dem Referenzprojekt übernommene Spannungsschätzung für eine 1S-Li-Ion-Zelle, keine präzise Ladungsmessung und kein Schutzmechanismus. Sie benötigt dieselbe TP1/GPIO6-Verbindung wie die Spannungsanzeige. Speicherwerte werden korrekt in KiB (1024 Byte) angezeigt. Die ESPHome-Version und die lokalen Diagnosewerte sind zusätzlich als Diagnose-Entities verfügbar.

Die Batteriebank nutzt die sechs aggregierten HA-Entities `sensor.solar_battery_bank_reported_bank_*` aus dem Referenzprojekt. Ihre Zuordnung steht als `battery_bank_*_entity`-Substitutionen in `packages/ng-eg-gang-wallbox-hmi/battery_bank.yaml` und kann bei Bedarf in der Haupt-YAML überschrieben werden. Die Quellleistung wird wie im Referenzprojekt von W nach kW umgerechnet (`battery_bank_power_scale_to_kw: "0.001"`). Diese Entities sind nicht Teil des ausschließlich wallboxbezogenen Exports `wallbox-entities.json`.

Die Batteriekarte ist rein lesend und beeinflusst keine Wallbox-Bedienfreigabe. Wie im Referenzprojekt werden ihre Werte nur bei vollständig verfügbaren Bankdaten angezeigt; andernfalls erscheinen `--` und „Keine Daten“ beziehungsweise „HA offline“. Ein HA-Ausfall verwirft zwischengespeicherte Batteriewerte, damit sie nach der Wiederverbindung nicht als neue Messwerte erscheinen.

Trends werden alle 10 Sekunden lokal im RAM aufgenommen (60 Minuten, 361 Punkte).
Sie beginnen nach jedem Neustart leer; es wird keine HA-Historie nachgeladen.
Offline-Zeiten und ungültige Messwerte bleiben Lücken. Aktuelle Werte erscheinen
ohne HA-Verbindung als `--`, und die Steuerung ist gesperrt. Solange HA verbunden
ist, werden die dort gemeldeten Zustände verwendet; ein Ausfall der vorgeschalteten
Wallbox-Abfrage muss von der HA-Integration als `unavailable` gemeldet werden.

### Einrichtung und Prüfung

Benötigt wird **ESPHome ab 2026.11.0**. Eine lokale, nicht versionierte
`secrets.yaml` neben der Hauptkonfiguration muss diese Schlüssel enthalten (`secrets.example.yaml` enthält Platzhalterwerte):

`wifi_ssid`, `wifi_password`, `fallback_ap_password`, `web_server_username`,
`web_server_password`, `api_encryption_key`.

```sh
esphome config ng-eg-gang-wallbox-hmi.yaml
esphome compile ng-eg-gang-wallbox-hmi.yaml
```

Beim Übertragen auf den Ziel-PC die Haupt-YAML und den gesamten Geräteordner
`packages/ng-eg-gang-wallbox-hmi/` einschließlich `wallbox_ui.h` zusammen
übernehmen. Unter `packages/` liegen gerätespezifische Dateien immer in einem
Unterordner mit exakt dem ESPHome-Gerätenamen, damit mehrere Geräte dieselbe
ESPHome-Installation konfliktfrei nutzen können. Schriftarten werden
beim Build heruntergeladen; im laufenden Betrieb benötigt die GUI kein Internet.
Die Weboberfläche und der lokale Bildschirm verwenden unterschiedliche Oberflächen.

### Quellen nach Home Assistant übertragen

`scripts/deploy-ha.ps1` ist die auf dieses Einzelgerät angepasste Variante des Deploy-Skripts aus dem Referenzprojekt. Es überträgt ausschließlich `ng-eg-gang-wallbox-hmi.yaml` und die Quelldateien in `packages/ng-eg-gang-wallbox-hmi/`, einschließlich der C++-Header. Die bereits gerätespezifischen Pfade bleiben unverändert; ein zweites Gerätenamen-Präfix wird nicht eingefügt. Andere Geräte, `secrets.yaml`, `.env`-Dateien, Tests, Entity-Exporte und Build-Verzeichnisse werden nicht übertragen. The shared Waveshare base is not copied either: ESPHome loads it from GitHub. The script skips generated `*.local.yaml` files and stops when `waveshare_base_ref` is not a published tag of the base.

Voraussetzung ist **PowerShell 7 oder neuer** (`pwsh`). Für die echte Übertragung werden außerdem `ssh` und `scp`, ein vorhandener SSH-Schlüssel mit Zugang zum HA-Host sowie dort eine POSIX-Shell und `sha256sum` benötigt. Wie im Referenzprojekt sind `10.10.80.9`, Benutzer `root`, Port `22`, Ziel `/config/esphome` und Schlüssel `$HOME/.ssh/ha_esphome_deploy` voreingestellt. Diese Werte lassen sich per Parameter überschreiben. Das Skript richtet keinen SSH-Zugang ein.

```powershell
# Nur die Dateizuordnung anzeigen; keine Netzwerkverbindung oder Übertragung.
pwsh -File .\scripts\deploy-ha.ps1 -DryRun

# Quellen mit den voreingestellten SSH-Daten übertragen.
pwsh -File .\scripts\deploy-ha.ps1

# Beispiel mit abweichendem Host, Benutzer und vorhandenem Schlüssel.
pwsh -File .\scripts\deploy-ha.ps1 -HaHost homeassistant.local -HaUser root -Port 22 -KeyPath "$HOME/.ssh/ha_esphome_deploy" -RemoteDir /config/esphome
```

Das Skript erstellt einen temporären Quellsnapshot, lädt ihn in ein isoliertes Staging-Verzeichnis und vergleicht SHA-256-Prüfsummen vor und nach dem Einspielen. Bestehende verwaltete Dateien werden standardmäßig unter `/config/esphome/.deploy-backups/ng-eg-gang-wallbox-hmi/<Lauf-ID>/` gesichert. `-NoBackup` schaltet diese Sicherung ausdrücklich ab. SSH-Aufrufe sind auf 30 Sekunden und SCP-Transfers auf 120 Sekunden je Versuch begrenzt; vorübergehende Netzwerkfehler werden bis zu dreimal versucht. Der SSH-MAC ist wie im Referenzprojekt voreingestellt und über `-MacAlgorithm` anpassbar; eine leere Zeichenfolge erlaubt die OpenSSH-Standardauswahl.

Vorhandene, inzwischen unbenutzte Paketdateien und ältere Backups werden nicht gelöscht. Die Installation ist nicht transaktional und hat keinen automatischen Rollback: Bei einem Abbruch nach Installationsbeginn Zielstand prüfen und bei Bedarf die gesicherten Dateien manuell zurückkopieren. Nicht parallel für dasselbe Gerät deployen. Das Skript entfernt nur sein eigenes temporäres Bundle und sein eigenes Staging-Verzeichnis.

**Der Deploy führt weder ESPHome-Validierung noch Kompilierung oder Flashen aus.** Die vorhandene `secrets.yaml` auf dem HA-Host bleibt unangetastet und muss separat eingerichtet sein. Nach der Übertragung entscheidest du selbst über die Prüfung und Installation im ESPHome-Add-on beziehungsweise über deine Desktop-Software.

Das Gerät muss in der ESPHome-Integration von Home Assistant registriert sein.
Für die Ladestrom-Buttons dort **„Dem Gerät erlauben, Home-Assistant-Aktionen
auszuführen“** aktivieren. Die vorhandene Automation
`automation.set_wallbox_max_current_from_buttons` muss ebenfalls aktiv sein.
Es gibt keine direkte Modbus-Steuerung durch dieses Display. **0 A ist kein Not-Aus.**

Die Entity-Zuordnung aus `wallbox-entities.json` lässt sich mit Python und dem mit
ESPHome installierten PyYAML prüfen:

```sh
python -m unittest discover -s tests -v
```

The host test of the trend buffer lives in the base repository.

Vor dem Einsatz auf dem Board prüfen: Touch-Ausrichtung, Seitenwechsel,
alle vier Trendansichten und Phasenfarben, HA-Ausfall über mindestens 15 Minuten
(keine Neustarts, keine Bedienanfragen), Wiederverbindung und bestätigte
Ladestrom-Anfragen mit tatsächlicher Wallbox-Rückmeldung. Diese Hardwaretests
ersetzen weder elektrische Schutzmaßnahmen noch einen Not-Aus.
