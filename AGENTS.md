## Meine Regeln

- Antworte mir immer auf Deutsch. Code, Code-Kommentare und Commits bleiben englisch.
- Deutsche Texte in der App immer mit echten Umlauten: ä, ö, ü, ß. Nie ae, oe, ue oder ss als Ersatz.
- Lokale Commits nur auf ausdrücklichen Auftrag, im Format `feat: ...`, `fix: ...` oder `docs: ...`. Niemals pushen. GitHub und GitHub-Integrationen nur lesend verwenden; keine Remote-Änderungen vornehmen.
- Tests, Konfigurationsvalidierung und Kompilierung übernimmt bis auf Weiteres der Nutzer. Nicht eigenständig ausführen oder dafür Toolchains installieren; nur auf ausdrückliche Aufforderung. Die lokale ESP-Desktop-Software wird später besprochen.

# Project context

- The development PC is not the target PC; do not assume local tools or services are available on the target PC. Node.js v26.13.0 and npm 11.20.0 are installed on the development PC, but this is not a Node project.
- The display is intended to control the user's Heidelberg Energy Control Wallbox (11 kW, 7.5 m charging cable).
- `wallbox-entities.json` lists all wallbox entities from the user's Home Assistant installation; use it as the reference for entity IDs rather than guessing them.
- The display GUI must use LVGL through ESPHome.
- GUI reference project: `D:\Workspace\esphome-r4875g1-3phase-charger`. This is outside the repository; obtain permission before accessing it, as required by `opencode.json`.

# Development and documentation

- Comment/documentation-only tasks must not change IDs, values, timing, entities or control flow. Report functional defects separately rather than silently fixing them.
- Extend the existing hardware, HA-import, presentation and command boundaries instead of adding competing implementations. The reference project's dual-target architecture is not a requirement for this single-target HMI.
- YAML comments stay English and explain non-obvious hardware dependencies, timing, failure behavior and implementation choices. Small include fragments should document their required substitution variables; C++ lambda comments use `//`, not YAML separators.
- Keep comments and file references aligned with the implementation in the same change. README content explains setup, operation and limitations; implementation-local details belong beside the code. Distinguish working features from planned ones, and do not reformat unrelated documentation.

# Firmware

- Target hardware is the Waveshare **ESP32-S3-Touch-LCD-7** (touch model, not 7B/7C); see `README.md` and https://docs.waveshare.com/ESP32-S3-Touch-LCD-7 for wiring. Backlight and touch reset use the CH422G expander; USB and CAN share GPIO19/20 and are selected via CH422G EXIO5.
- `ng-eg-gang-wallbox-hmi.yaml` is the sole firmware entrypoint: ESPHome >=2026.10.2, ESP32-S3, ESP-IDF (recommended version), 16 MB QIO flash and octal PSRAM. There is no Node project or CI setup; the npm permissions in `opencode.json` are not project commands.
- Keep flash and PSRAM at 80 MHz. The YAML documents that 120 MHz octal PSRAM is unsupported by the current configuration; do not force experimental SDK options to enable it.
- All device-specific runtime files, including C++ headers, must live under `packages/<esphome.name>/` to avoid collisions with other devices in the same ESPHome installation. For this device use `packages/ng-eg-gang-wallbox-hmi/`: `homeassistant.yaml` owns entity imports, `display/` owns hardware, LVGL widgets and runtime. Transfer this complete device folder with the main YAML; `esphome.includes` paths remain relative to the main configuration.
- Trends use native LVGL 9.5 charts (`LV_USE_CHART=1`), not an ESPHome chart widget. `trend_buffer.h` owns a RAM-only 361-point/10-second history; `wallbox_ui.h` renders it. Missing readings must stay gaps. Use custom font glyphs for German text; built-in Montserrat lacks umlauts.
- Current requests go only through the existing HA input-select and require confirmation, live HA states and HA action permission. HA action success is not physical wallbox acknowledgement; do not add optimistic state updates or offline command replay.
- This HMI is not a safety controller or independent blackstart controller. Keep HA loss visible and remote controls disabled when required state is unavailable; never substitute snapshot values from `wallbox-entities.json` or fake healthy/zero readings for missing live data. Do not bypass the existing HA/wallbox command path or weaken safety constraints during refactors.
- Preserve `reboot_timeout: 0s` under both `api` and `wifi`, plus `wifi.power_save_mode: none`: local operation must survive Home Assistant and infrastructure Wi-Fi outages without timed reboots.
- Preserve the local web UI's offline assets (`local: true`), digest authentication, hidden internal entities, and disabled web firmware uploads; native ESPHome OTA is separate.
- `esphome.min_version` is the ESPHome toolchain requirement, not this project's firmware version. No project firmware-version scheme is established; do not introduce automatic version bumps. Any future canonical version file must stay inside the device package folder.

# Verification and secrets

- For user-run verification with the ESPHome CLI: `esphome config ng-eg-gang-wallbox-hmi.yaml` validates, then `esphome compile ng-eg-gang-wallbox-hmi.yaml` builds firmware. Neither command uploads firmware; agents must not run them without an explicit request.
- Both require a local, ignored `secrets.yaml` beside the firmware YAML with `web_server_username`, `web_server_password`, `api_encryption_key`, `wifi_ssid`, `wifi_password`, and `fallback_ap_password`. For isolated checks, copy only source files to a temporary directory and supply dummy secrets there; never flash that build.
- `python -m unittest discover -s tests -v` checks entity IDs, units and current options against the HA export (PyYAML comes with ESPHome). `tests/trend_buffer_test.cpp` tests history order, missing samples, ring wrap and clock rollover; see `README.md` for the host-compiler command. Schema validation alone does not compile C++ lambdas.
- `opencode.json` denies git pushes and reads of `.env`/`.env.*`; it does not protect `secrets.yaml`. Do not read or expose real secret values when investigating validation failures.
