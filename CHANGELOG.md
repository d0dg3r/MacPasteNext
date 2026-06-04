# Changelog

All notable changes to this project are documented in this file.

The format is inspired by Keep a Changelog and semantic versioning style releases.

## [Unreleased]

- Changed

- Reset release strategy to start at `v1.0.0-beta.N` with clear pre-release/final separation.

## [v1.0.0-beta.3] - 2026-06-04

- Fixed

- Double-click word selection (and triple-click line selection) is now captured into the PRIMARY buffer reliably. The click state is tracked from `leftMouseDown` (more reliable than from the up event), and the Cmd+C is delayed by 50 ms so the host app has time to finalize the selection.
- Triple-click no longer loses to a stale double-click capture: multi-click captures bypass the auto-copy debounce, and a generation counter cancels superseded captures so the most recent click wins.

## [v1.0.0-beta.2] - 2026-06-04

- Fixed

- Side mouse buttons (4/5) no longer double-trigger: the EventHandler now uses an active `CGEventTap` instead of a passive `NSEvent` global monitor, so the configured mic-mute button is fully intercepted (no more browser Back/Forward firing alongside the mic toggle).
- Middle-click paste no longer mis-fires on the thumb-back button: paste is restricted to the true middle button (`buttonNumber == 2`) instead of the previous `2 || 3` check.
- No more double-paste in apps with their own middle-click paste (Terminal.app with the middle-click paste preference enabled, X11-aware apps): the middle-click event is now swallowed when `middleClickPaste` is active, so only our paste fires (resolves #1).

- Added

- Linux-style PRIMARY selection: selections are stored in an internal `primaryBuffer` while the system pasteboard is snapshotted and restored, so the regular `Cmd+C` clipboard is preserved across auto-copy events. Middle-click pastes from `primaryBuffer` and restores the prior clipboard afterwards.

- Changed

- Double-/triple-click detection switched from a manual time threshold to `CGEventField.mouseEventClickState`, matching the OS click classifier.
- Heavy work (clipboard change-count polling, AppleScript mic toggle, paste restore) is dispatched off the tap callback to avoid macOS disabling the tap for running too long.

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
