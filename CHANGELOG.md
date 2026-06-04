# Changelog

All notable changes to this project are documented in this file.

The format is inspired by Keep a Changelog and semantic versioning style releases.

## [Unreleased]

- Changed

- Reset release strategy to start at `v1.0.0-beta.N` with clear pre-release/final separation.

## [v1.0.0-beta.5] - 2026-06-04

- Added

- New "Updates" section in the settings panel with a toggle to enable or disable Sparkle's background update checks. The previously menu-only "Check for Updates..." action is now also available as a button next to the toggle.
- Tooltips on every settings toggle and picker (auto-copy, middle-click paste, mic mute, mouse-button picker, language, log console). Hover over an option to learn what it does.
- About dialog now shows the configured Sparkle update feed URL so users can verify which channel they are pulling updates from.
- PRIMARY capture log entries include a short, sanitized preview of the captured text (newlines / tabs rendered as visible markers, truncated at 30 chars) instead of just the length.

- Changed

- `MacPasteAppDelegate.applyAutoUpdatePreference()` keeps `SPUUpdater.automaticallyChecksForUpdates` in sync with the new `autoUpdateEnabled` setting on launch and whenever the user flips the toggle.

- Internal

- Removed `@Published` from properties on `MacPasteAppDelegate`, which is not an `ObservableObject`; the annotations were no-ops and just added noise to the API surface.

## [v1.0.0-beta.4] - 2026-06-04

- Added

- Sparkle 2 in-app auto-updater. The app now embeds `Sparkle.framework`, exposes a "Check for Updates..." menu item, and polls `https://github.com/d0dg3r/MacPasteNext/releases/latest/download/appcast.xml` for new releases. Every update ZIP is signed with EdDSA and verified before installation, replacing the manual download/`xattr`/unzip dance.
- New `scripts/sparkle-bootstrap.sh` for the one-time EdDSA keypair generation, and `scripts/sparkle-publish-update.sh` for CI-side `sign_update` + appcast generation.

- Fixed

- `EventHandler.stop()` now invalidates both the `CFMachPort` and its `CFRunLoopSource` in addition to removing the source, preventing leaks when the event tap is toggled repeatedly.
- Auto-copy capture no longer clobbers an external clipboard write: the change count captured right after reading the selection is compared against the current change count, and the pre-capture pasteboard snapshot is only restored if nothing else wrote to the clipboard in the meantime.
- Middle-click paste applies the same guard: the change count snapshotted right after writing `primaryBuffer` is compared before the post-paste restore, so a user `Cmd+C` (or another app's clipboard write) during the paste window is preserved.

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
