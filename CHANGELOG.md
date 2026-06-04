# Changelog

All notable changes to this project are documented in this file.

The format is inspired by Keep a Changelog and semantic versioning style releases.

## [Unreleased]

## [v1.0.1] - 2026-06-05

- Fixed

- Auto-update from `v1.0.0-beta.5` was sometimes reported as "you're up to date" even though `v1.0.0` was published. Root cause: the appcast generator stripped the `v` prefix from `<sparkle:version>` while `CFBundleVersion` in the installed bundle still carried it (`v1.0.0-beta.5` vs `1.0.0`). Sparkle's `SUStandardVersionComparator` tokenises by digit/non-digit boundaries and falls back to a heuristic when one side leads with a letter and the other with a digit, which produced unreliable "newer?" decisions on already-installed clients. `scripts/sparkle-publish-update.sh` now keeps the `v` prefix verbatim so every appcast entry matches the bundle format (`v1.0.X`).
- Backfilled the existing `v1.0.0` appcast on GitHub with the corrected format so installs that managed to reach the v-prefixed feed can finally see `v1.0.0` (and now `v1.0.1`) as newer than `v1.0.0-beta.5`.

## [v1.0.0] - 2026-06-05

First stable release. Distilled from the `v1.0.0-beta.{1..5}` series.

- Highlights

- Linux-style PRIMARY selection on macOS. Selecting text with the mouse (drag, double-click, triple-click) captures it into a private PRIMARY buffer that is independent from the `Cmd+C` clipboard; middle-click pastes the buffer wherever the cursor is.
- Active event interception via `CGEventTap` so MacPasteNext can swallow side-button / middle-click events instead of letting the OS or focused app react on top of our action (fixes Terminal.app double-paste, [#1](https://github.com/d0dg3r/MacPasteNext/issues/1)).
- Optional microphone mute on a configurable side button, with a visible Red/Green indicator in the menu bar.
- Built-in Sparkle 2 auto-updater. The app polls `https://github.com/d0dg3r/MacPasteNext/releases/latest/download/appcast.xml`, verifies every update ZIP with EdDSA, and installs in-place. Background checks are user-toggleable.
- Bilingual UI (English / Deutsch) with tooltips on every setting, an integrated debug console, and a one-click `tccutil reset` for stuck Accessibility prompts.

- Release infrastructure

- Self-signed release pipeline that produces a reproducible, identifier-stable `MacPasteNext-macos-arm64.zip` and a Sparkle-signed `appcast.xml` for every tag.
- All releases (including `-beta.N` channels) publish as non-prerelease GitHub releases and are promoted to `latest`, so the Sparkle feed URL always resolves.
- `scripts/sparkle-bootstrap.sh` for the one-time EdDSA keypair generation, `scripts/sparkle-publish-update.sh` for CI-side signing and appcast generation, and a smoke test that verifies framework embedding, Info.plist keys, and codesign on every build.

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
