# Changelog

All notable changes to this project are documented in this file.

The format is inspired by Keep a Changelog and semantic versioning style releases.

## [Unreleased]

- Changed

- Reset release strategy to start at `v1.0.0-beta.N` with clear pre-release/final separation.

## [v1.0.0-beta.1] - 2026-03-12

- Added

- Robust settings reopen lifecycle handling to avoid intermittent reopen crashes.
- Context-aware permission panel visibility in settings (shown only when needed).
- Status bar icon fallback for `Mic Feature Off` so menu access remains visible.

- Changed

- New release policy: beta tags (`v1.0.0-beta.N`) publish as pre-releases.
- Post-release screenshot automation now runs automatically after successful release workflow completion.
- Settings UI now hides `Simulate Copy/Paste` when debug logs are disabled.
- Settings window sizing now stays compact without logs and expands dynamically when logs are enabled.
- About/settings copy and support metadata links were polished.

- Fixed

- Self-signed CI guard now verifies certificate presence robustly on macOS runners.
