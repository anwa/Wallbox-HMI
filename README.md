# Wallbox-HMI

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

## Erste GUI-Version

Die Firmware-Konfiguration liegt in `ng-eg-gang-wallbox-hmi.yaml`. Display und GT911-Touch
sind für das Waveshare-Board eingerichtet. Die Gestaltung orientiert sich am
Referenzprojekt `D:\Workspace\esphome-r4875g1-3phase-charger`.

Eine feste Titelzeile zeigt Uhrzeit und HA-Verbindung; unten bleiben vier
Navigationsbuttons auf allen Seiten sichtbar:

- **Übersicht:** Ladeleistung, Ladezustand mit HA-Statustext, geladene Energie,
  PCB-Temperatur und zurückgemeldete Stromvorgabe.
- **Phasen:** Spannung und Strom für L1, L2 und L3.
- **Trends:** umschaltbare Leistung, Spannung, Strom und PCB-Temperatur.
  Spannung/Strom enthalten jeweils drei farbige Phasenkurven.
- **Ladestrom:** bestätigte Anfragen für 0, 6, 10, 12 oder 16 A über den bestehenden
  HA-Helfer `input_select.wallbox_max_current_buttons`. Auswahl im Helfer und
  Wallbox-Rückmeldung werden getrennt dargestellt. Eine erfolgreiche HA-Anfrage
  bestätigt noch nicht, dass die Wallbox den Strom bereits übernommen hat.

Trends werden alle 10 Sekunden lokal im RAM aufgenommen (60 Minuten, 361 Punkte).
Sie beginnen nach jedem Neustart leer; es wird keine HA-Historie nachgeladen.
Offline-Zeiten und ungültige Messwerte bleiben Lücken. Aktuelle Werte erscheinen
ohne HA-Verbindung als `--`, und die Steuerung ist gesperrt. Solange HA verbunden
ist, werden die dort gemeldeten Zustände verwendet; ein Ausfall der vorgeschalteten
Wallbox-Abfrage muss von der HA-Integration als `unavailable` gemeldet werden.

### Einrichtung und Prüfung

Benötigt wird **ESPHome ab 2026.10.2**. Eine lokale, nicht versionierte
`secrets.yaml` neben der Hauptkonfiguration muss diese Schlüssel enthalten:

`wifi_ssid`, `wifi_password`, `fallback_ap_password`, `web_server_username`,
`web_server_password`, `api_encryption_key`.

```sh
esphome config ng-eg-gang-wallbox-hmi.yaml
esphome compile ng-eg-gang-wallbox-hmi.yaml
```

Beim Übertragen auf den Ziel-PC die Haupt-YAML und den gesamten Geräteordner
`packages/ng-eg-gang-wallbox-hmi/` einschließlich beider C++-Header zusammen
übernehmen. Unter `packages/` liegen gerätespezifische Dateien immer in einem
Unterordner mit exakt dem ESPHome-Gerätenamen, damit mehrere Geräte dieselbe
ESPHome-Installation konfliktfrei nutzen können. Schriftarten werden
beim Build heruntergeladen; im laufenden Betrieb benötigt die GUI kein Internet.
Die Weboberfläche und der lokale Bildschirm verwenden unterschiedliche Oberflächen.

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

Der Trendpuffer hat unabhängige C++-Tests (C++17-Compiler erforderlich). Beispiel
für PowerShell mit GCC; die Testdatei bleibt außerhalb des Repositorys:

```powershell
g++ -std=c++17 -Ipackages/ng-eg-gang-wallbox-hmi tests/trend_buffer_test.cpp -o "$env:TEMP/wallbox-trend-test.exe"
& "$env:TEMP/wallbox-trend-test.exe"
```

Vor dem Einsatz auf dem Board prüfen: Touch-Ausrichtung, Seitenwechsel,
alle vier Trendansichten und Phasenfarben, HA-Ausfall über mindestens 15 Minuten
(keine Neustarts, keine Bedienanfragen), Wiederverbindung und bestätigte
Ladestrom-Anfragen mit tatsächlicher Wallbox-Rückmeldung. Diese Hardwaretests
ersetzen weder elektrische Schutzmaßnahmen noch einen Not-Aus.
