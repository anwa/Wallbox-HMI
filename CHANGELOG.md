# Changelog

User-visible changes are recorded here in English, newest release first. Release dates use YYYY-MM-DD. Version numbers and tags identify source states, not successful firmware builds or hardware tests.

## Unreleased

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
