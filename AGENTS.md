# Agent Instructions

## Inherited Rules

This repository lives in a rule hierarchy. Apply these files in addition to the rules below, in this order of increasing precedence:

| Level | File |
|---|---|
| Global | `../../../AGENTS.md` |
| ESPHome | `../../AGENTS.md` and `../../rules/yaml-comments.md` |
| Waveshare | `../AGENTS.md` |

They define language, Git authority, branches, commits, versioning principles, documentation style, the ESPHome toolchain and validation, YAML comments and the Waveshare board, LVGL and UI conventions. This file contains only what is specific to this repository and takes precedence over the inherited files.

If the inherited files are not present, for example in a fresh clone: write all repository content in English, never commit secrets, and never push, tag or publish without the user's approval.

# Project context

- The development PC is not the target PC; do not assume local tools or services are available on the target PC. Node.js and npm are installed on the development PC, but this is not a Node project.
- The display is intended to control the user's Heidelberg Energy Control Wallbox (11 kW, 7.5 m charging cable).
- `wallbox-entities.json` lists all wallbox entities from the user's Home Assistant installation; use it as the reference for entity IDs rather than guessing them.
- The display GUI must use LVGL through ESPHome.
- GUI reference project: `..\R4875G1-Charger\esphome-r4875g1-3phase-charger` (sibling folder). For opencode it is outside the repository; obtain permission before accessing it, as required by `opencode.json`.
- Board, display, touch, backlight, LVGL, local backup battery, fonts, theme, header and navigation geometry come from the shared base `waveshare-esphome-base` (sibling folder `..\waveshare-esphome-base`, GitHub `anwa/waveshare-esphome-base`). Its README defines the provided IDs, styles, fonts and substitutions. Change shared behavior there, not with local overrides.

# Development and documentation

- Extend the existing hardware, HA-import, presentation and command boundaries instead of adding competing implementations. The reference project's dual-target architecture is not a requirement for this single-target HMI.
- README content explains setup, operation and limitations.
- Maintain `CHANGELOG.md` in English: add concise user-visible changes under `Unreleased` in the same change, grouped as Added/Changed/Fixed/Removed when applicable. `/merge` moves the changes shipped since main's previous release into the new version's dated section; `none` leaves them unreleased. Preserve historical entries.

# Firmware

- Target hardware and its wiring are defined by the inherited Waveshare rules and implemented by the shared base. `waveshare_base_ref` in the main YAML pins the base release; `packages/ng-eg-gang-wallbox-hmi/waveshare-base.yaml` is the only file that references the base. Commit only a published base tag. For development against a local base, run `..\waveshare-esphome-base\scripts\use-local-base.ps1 -Package packages/ng-eg-gang-wallbox-hmi/waveshare-base.yaml` and pass `-s waveshare_base_package packages/ng-eg-gang-wallbox-hmi/waveshare-base.local.yaml` to ESPHome; the generated file is ignored and never committed or deployed.
- The local backup-battery reading in the header stays independent of HA invalidation; an open measurement connection can still yield a finite ADC value.
- `local_diagnostics.yaml` owns local System-page sensors (using the root `debug` component); the backup-battery voltage and approximate SOC come from the base. `display/system.yaml` updates `display/pages/system.yaml` only for `active_page == 4`, through the existing UI refresh. Keep local diagnostics out of HA invalidation and command gating; `display/widgets/navigation.yaml` places the five footer buttons with the base's navigation geometry.
- `ng-eg-gang-wallbox-hmi.yaml` is the sole firmware entrypoint: ESPHome >=2026.11.0, ESP32-S3, ESP-IDF (recommended version). There is no Node project or CI setup; the npm permissions in `opencode.json` are not project commands.
- Device files live under `packages/ng-eg-gang-wallbox-hmi/`: `homeassistant.yaml` owns entity imports, `display/` owns hardware, LVGL widgets and runtime. Transfer this complete device folder with the main YAML; `esphome.includes` paths remain relative to the main configuration.
- `battery_bank.yaml` in the device package owns the read-only dashboard battery card's aggregate HA imports and rendering script. Its entity substitutions come from the reference project, not `wallbox-entities.json`; bank power is converted from W to kW. Keep battery availability independent of wallbox command eligibility; there is no Battery detail page.
- Trends use native LVGL charts. `wallbox_ui.h` keeps a RAM-only 361-point/10-second history in the base's `waveshare_ui::TrendBuffer` and renders it with `waveshare_ui::apply_chart_style()`.
- Current requests go only through the existing HA input-select and require confirmation, live HA states and HA action permission. HA action success is not physical wallbox acknowledgement.
- Never substitute snapshot values from `wallbox-entities.json` for missing live data. Do not bypass the existing HA/wallbox command path.
- Preserve `reboot_timeout: 0s` under both `api` and `wifi`, plus `wifi.power_save_mode: none`: local operation must survive Home Assistant and infrastructure Wi-Fi outages without timed reboots.
- Preserve the local web UI's offline assets (`local: true`), digest authentication, hidden internal entities, and disabled web firmware uploads; native ESPHome OTA is separate.
- The canonical project version is `substitutions.firmware_version` in `packages/ng-eg-gang-wallbox-hmi/version.yaml`, consumed by the main YAML's `esphome.project` metadata (`wallbox.hmi`). `/commit` makes exactly one PATCH increment for each code-changing commit, based on that branch's HEAD version and included in the same commit; documentation/comment-only changes do not bump it. No commit-time tags or recursive bumps for release preparation. `/merge` performs the local fast-forward release (minor by default), annotated tag and task-branch deletion, respecting intermediate commit-time patch increments. Neither command pushes; follow the respective `.opencode/commands/` instructions.

# Verification and secrets

- `scripts/deploy-ha.ps1` (PowerShell 7+) transfers only the main YAML and its existing device package namespace, with staging, SHA-256 checks and default backups. It skips `*.local.yaml` and refuses to deploy when `waveshare_base_ref` is not a published tag; do not rewrite paths or add a second node prefix. It never validates, builds or flashes. Running it follows the inherited ESPHome deployment rule.
- Validation: `esphome config ng-eg-gang-wallbox-hmi.yaml`, then `esphome compile ng-eg-gang-wallbox-hmi.yaml`. Neither command uploads firmware.
- Both require a local, ignored `secrets.yaml` beside the firmware YAML (`secrets.example.yaml` holds dummy values) with `web_server_username`, `web_server_password`, `api_encryption_key`, `wifi_ssid`, `wifi_password`, and `fallback_ap_password`. For isolated checks, copy only source files to a temporary directory and supply dummy secrets there; never flash that build.
- `python -m unittest discover -s tests -v` checks entity IDs, units and current options against the HA export (PyYAML comes with ESPHome). The trend buffer's host test lives in the base repository. Schema validation alone does not compile C++ lambdas.
- `opencode.json` denies git pushes and reads of `.env`/`.env.*`; it does not protect `secrets.yaml`.
