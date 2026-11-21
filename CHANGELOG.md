# Changelog

User-visible changes are recorded here in English, newest release first. Release dates use YYYY-MM-DD. Version numbers and tags identify source states, not successful firmware builds or hardware tests.

## Unreleased

## [0.4.0] - 2026-11-21

### Changed

- Build on the shared Waveshare base [waveshare-esphome-base](https://github.com/anwa/waveshare-esphome-base), pinned to a release tag; board, display, LVGL, backup battery, fonts, theme, header and navigation geometry come from the base.
- Adopt the shared palette: cards `0x171D23`, buttons `0x202830`, borders `0x303A44`/`0x3B4652`, labels `0x8B96A0` and values `0xFFFFFF`.
- Mark the active navigation button and selected trend or current button in the shared selected style (`0x36505A` with green text) instead of turquoise.
- Show the confirmation dialog with the shared dark overlay and dialog panel; its buttons use the shared dialog-button style with 16 px text.
- Use the shared header layout: 20 px title, version at x 180, battery reading beside a 130 px Home Assistant status slot; the clock refreshes every 10 seconds.
- Place the five navigation buttons with the shared geometry: 146 × 58 px at y 410 instead of 148 × 54 px at y 416.
- Add the `mdi:battery` icon to the `HMI Battery State of Charge` entity; entity names and IDs are unchanged.
- Require ESPHome 2026.11.0.

### Added

- Turn the backlight off after 60 seconds without touch; the first touch on the dark display only wakes it and does not operate the control underneath.
- Add `secrets.example.yaml` with dummy values for local validation.

### Removed

- Remove the device copies of the trend buffer and its host test; the history uses the base's `waveshare_ui::TrendBuffer`.

## [0.3.0] - 2026-11-10

### Changed

- Increment the project patch version once per code-changing `/commit`, include it in the same commit and preserve intermediate patch versions during release preparation; documentation-only commits do not bump the version or create tags.

### Added

- Add a read-only System page adapted from the reference project, with local network, uptime, CPU temperature, memory, loop-time and CPU-frequency diagnostics plus the HMI reset reason.
- Show local backup-battery voltage and an explicitly approximate voltage-based SOC on the System page; local diagnostics remain available without Home Assistant.
- Replace reference rectifier lifecycle rows with HA connectivity, wallbox state and current-command feedback; add a fifth persistent navigation button.

### Fixed

- Set System-page text colors explicitly to match the reference: light-gray headings and captions, white ordinary values and unchanged meaningful status colors, without relying on theme inheritance through transparent containers.

## [0.2.0] - 2026-11-10

### Added

- Show the firmware version beside the title in the persistent header, using the same central version substitution as the ESPHome project metadata.

## [0.1.1] - 2026-11-10

### Added

- Maintain this changelog alongside changes and include release notes in the local `/merge` workflow.

## [0.1.0] - 2026-11-10

### Added

- Measure the local HMI backup-battery voltage on GPIO6 every five seconds, using the onboard 1:3 divider and a five-sample moving average.
- Show `HMI 4.12 V` in the persistent header independently of Home Assistant, with red below 3.50 V, amber below 3.70 V and green at or above 3.70 V.
- Expose the voltage as the diagnostic sensor `HMI Battery Voltage` and document the required TP1-to-J8 AD/GPIO6 connection.

## [0.0.1] - 2026-11-08

### Added

- Initial ESPHome/LVGL interface for the Waveshare ESP32-S3-Touch-LCD-7, with persistent clock, HA connection status and navigation.
- Overview, per-phase measurements, local 60-minute trends and confirmed charging-current requests through the existing Home Assistant input-select.
- Read-only solar battery-bank card on the overview, without a Battery detail page.
- HA-disconnection handling that hides unavailable live readings and disables remote charging-current requests.
- Device-scoped deployment script with SSH/SCP transfer, staging, SHA-256 verification and default backups, without automatic compilation or flashing.
- Central firmware version and ESPHome project metadata, plus a local merge/release command with version tags and task-branch cleanup.

### Changed

- Name the device `ng-eg-gang-wallbox-hmi` and keep its runtime packages and C++ headers under `packages/ng-eg-gang-wallbox-hmi/`.

### Fixed

- Allow header-clock formatting with ESPHome's non-const `ESPTime::strftime()` method.
