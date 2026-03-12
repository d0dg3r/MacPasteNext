# Changelog

All notable changes to this project are documented in this file.

The format is inspired by Keep a Changelog and semantic versioning style releases.

## [Unreleased]

- Added

- Project governance and health docs (`CODE_OF_CONDUCT`, `SECURITY`, `PRIVACY`, `ROADMAP`)
- GitHub issue and pull request templates
- Funding metadata for GitHub Sponsors

## [v1.12.15] - 2026-03-12

- Added

- New workflow `Capture macOS Screenshots` to produce real app screenshots on macOS runners
- New script `scripts/capture-screenshots-macos.sh` for dark/light screenshot automation

- Changed

- README now links screenshot refresh process to the workflow
- App launch supports `MACPASTE_FORCE_SHOW_WINDOW=1` to enable automated screenshot capture

## [v1.12.14] - 2026-03-12

- Changed

- Added release quality gates for tag builds (required files + required changelog entry)
- Extended smoke tests to validate resources and bundle version metadata
- Added dark and light documentation screenshots shown side by side in README
- Added workflow support for capturing real macOS screenshots
- Persisted main window size/position for a more stable desktop UX between launches
- Added contributor Definition of Done checklist

- Fixed

- Resolved CI build type mismatch in window width calculation (`CGFloat` vs `Int`)

## [v1.12.13] - 2026-03-12

- Changed

- Added release quality gates for tag builds (required files + required changelog entry)
- Extended smoke tests to validate resources and bundle version metadata
- Added dark and light documentation screenshots shown side by side in README
- Persisted main window size/position for a more stable desktop UX between launches

## [v1.12.12] - 2026-03-12

- Added

- Automated GitHub release notes generation from tag-specific CHANGELOG entries

## [v1.12.10] - 2026-03-12

- Changed

- Reordered status menu actions for better UX
- Added direct permission refresh action in the menu
- Kept About dialog centered with larger banner presentation

## [v1.12.9] - 2026-03-12

- Changed

- Rendered banner in About dialog icon slot

## [v1.12.8] - 2026-03-12

- Fixed

- About dialog modal response handling for CI/macOS build compatibility

## [v1.12.6] - 2026-03-12

- Added

- Banner displayed in About dialog

## [v1.12.5] - 2026-03-12

- Added

- About and Help sections in status menu
- Repo/issue/release/sponsor links and build info copy action

## [v1.12.4] - 2026-03-12

- Fixed

- Startup window cleanup limited to settings window only

## [v1.12.3] - 2026-03-11

- Changed

- Improved startup UX and permission refresh flow

## [v1.12.2] - 2026-03-11

- Changed

- Switched in-app logo usage to banner
- Fixed startup window/log sizing behavior

## [v1.12.1] - 2026-03-11

- Changed

- Dynamic GUI version label from bundle metadata
- New app icon assets and release pipeline updates

## [v1.12.0] - 2026-03-11

- Added

- Self-signed macOS release pipeline with smoke checks
