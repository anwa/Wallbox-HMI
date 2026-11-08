## Meine Regeln

- Antworte mir immer auf Deutsch. Code, Code-Kommentare und Commits bleiben englisch.
- Deutsche Texte in der App immer mit echten Umlauten: ä, ö, ü, ß. Nie ae, oe, ue oder ss als Ersatz.
- Commits im Format `feat: ...` oder `fix: ...`. Niemals pushen.

# Firmware

- `ng-eg-wallbox-hmi.yaml` is the sole firmware entrypoint: ESPHome >=2026.10.2, ESP32-S3, ESP-IDF (recommended version), 16 MB QIO flash and octal PSRAM. There is no Node project or automated test/CI setup; the npm permissions in `opencode.json` are not project commands.
- Keep flash and PSRAM at 80 MHz. The YAML documents that 120 MHz octal PSRAM is unsupported by the current configuration; do not force experimental SDK options to enable it.
- Comments are partly ahead of implementation: `display/header.yaml` and `shared/local-diagnostics.yaml` do not exist, and no display/LVGL components are configured. Verify actual YAML before relying on these claims.
- Preserve `reboot_timeout: 0s` under both `api` and `wifi`, plus `wifi.power_save_mode: none`: local operation must survive Home Assistant and infrastructure Wi-Fi outages without timed reboots.
- Preserve the local web UI's offline assets (`local: true`), digest authentication, hidden internal entities, and disabled web firmware uploads; native ESPHome OTA is separate.

# Verification and secrets

- With the ESPHome CLI installed, run `esphome config ng-eg-wallbox-hmi.yaml` for validation, then `esphome compile ng-eg-wallbox-hmi.yaml` for a firmware build. Neither command uploads firmware.
- Both require a local, untracked `secrets.yaml` beside the firmware YAML with `web_server_username`, `web_server_password`, `api_encryption_key`, `wifi_ssid`, `wifi_password`, and `fallback_ap_password`. This file is not supplied, and there is currently no `.gitignore`; do not commit credentials or generated build files.
- `opencode.json` denies git pushes and reads of `.env`/`.env.*`; it does not protect `secrets.yaml`. Do not read or expose real secret values when investigating validation failures.
