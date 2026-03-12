# MacPasteNext

![MacPasteNext Logo](assets/banner.png)

> Created by **Joe Mild**. Because in 2026, he was still absolutely sick of macOS being too stupid for basic Linux copy & paste. Sometimes you just have to fix this shit yourself.

## What is this?

**MacPasteNext** is a lightweight, background macOS application that finally brings the beloved Linux X11-style middle-click copy-paste functionality to your Mac. In addition, it packs an elegant system-wide microphone mute toggle mapped directly to your mouse buttons, complete with colorized visual feedback in your menu bar.

## Features

- 🖱 **Auto-Copy on Selection**: Highlight text in *any* app, and it is instantly copied to your clipboard.
- 🖱 **Middle-Click Paste**: Click your middle mouse button to paste your clipboard instantaneously.
- 🎤 **Global Microphone Mute**: Toggle your system microphone on/off using a side mouse button. It remembers your previous volume level and displays a distinct Red/Green indicator in the macOS Menu Bar.
- 🌍 **Localization**: Fluent in both English and German.
- 🐞 **Debug Friendly**: Fully integrated real-time logging console visible directly in the app.

## Installation

Currently you must build the app from source:

1. Clone this repository.
2. Open terminal in the cloned directory.
3. Build a release app bundle:

   ```bash
   chmod +x scripts/build-release.sh
   ./scripts/build-release.sh
   ```

4. Self-sign locally (optional for quick local tests):

   ```bash
   codesign --force --deep --sign - dist/MacPasteNext.app
   ```

5. Move `dist/MacPasteNext.app` to your `/Applications/` folder and launch it.

## Release pipeline (No Apple Developer subscription)

This project supports a GitHub Actions macOS ARM release pipeline using one persistent self-signed certificate. This keeps app identity stable across releases for sideloading:

- Constant bundle id: `io.github.joemild.macpastenext`
- Always sign with the same certificate identity
- Run smoke checks on each release build

Workflow file:

- `.github/workflows/release.yml`

Scripts:

- `scripts/build-release.sh`
- `scripts/sign-selfsigned.sh`
- `scripts/smoke-test-macos.sh`

### One-time self-signed certificate setup

Run these steps on a macOS machine once, then reuse the same cert for all future releases.

1. Create a self-signed code-signing certificate in Keychain Access
   - Keychain Access -> Certificate Assistant -> Create a Certificate
   - Name example: `MacPasteNext Self Signed`
   - Identity Type: `Self Signed Root`
   - Certificate Type: `Code Signing`
2. Export as `.p12` (with password).
3. Convert for GitHub secret:

   ```bash
   base64 -i MacPasteNext-selfsigned.p12 | pbcopy
   ```

4. Add GitHub repository secrets:

   - `MAC_CERT_P12_BASE64`: base64 of the exported `.p12`
   - `MAC_CERT_P12_PASSWORD`: password used during export
   - `MAC_CERT_IDENTITY`: exact certificate name (for example `MacPasteNext Self Signed`)

### Required variables

Set these in GitHub (`Settings -> Secrets and variables -> Actions -> New repository secret`):

- `MAC_CERT_P12_BASE64`
- `MAC_CERT_P12_PASSWORD`
- `MAC_CERT_IDENTITY`

Local equivalents for manual test runs:

```bash
export MAC_CERT_P12_BASE64="<base64_of_p12>"
export MAC_CERT_P12_PASSWORD="<your_p12_password>"
export MAC_CERT_IDENTITY="MacPasteNext Self Signed"
```

### Triggering a release

- Push a tag like `v1.12.0` to run release pipeline.
- The workflow builds, signs, runs smoke tests, and uploads `MacPasteNext-macos-arm64.zip`.

## Permissions Required

Because MacPasteNext needs to monitor your global mouse clicks and natively simulate keypresses (Cmd+C / Cmd+V) to trick macOS into pasting text, the operating system requires you to grant it **Accessibility** permissions.
If things get stuck with the permissions cache (as macOS often does), there's a handy `tccutil reset` button built directly into the UI to reset it and prompt again.

## Sideload notes (self-signed builds)

Without Apple notarization, first launch may be blocked by Gatekeeper. Typical user flow:

1. Right-click app -> Open.
2. Confirm Open in the warning dialog.

If app is quarantined after download, advanced users can remove quarantine manually:

```bash
xattr -dr com.apple.quarantine /Applications/MacPasteNext.app
```

## Contributing

Community contributions to deal with macOS quirks are welcome. See `CONTRIBUTING.md` for our contribution guidelines.

## Project Health

- Roadmap: `ROADMAP.md`
- Changelog: `CHANGELOG.md`
- Code of Conduct: `CODE_OF_CONDUCT.md`
- Security Policy: `SECURITY.md`
- Privacy Policy: `PRIVACY.md`

## License

Provided under the MIT License. See `LICENSE` for more information.
