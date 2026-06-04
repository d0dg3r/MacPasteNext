# MacPasteNext

![MacPasteNext Logo](assets/banner.png)

> Created by **Joe Mild**. Because in 2026, he was still absolutely sick of macOS being too stupid for basic Linux copy & paste. Sometimes you just have to fix this shit yourself.

## What is this?

**MacPasteNext** is a lightweight, background macOS application that finally brings the beloved Linux X11-style middle-click copy-paste functionality to your Mac. In addition, it packs an elegant system-wide microphone mute toggle mapped directly to your mouse buttons, complete with colorized visual feedback in your menu bar.

MacPasteNext. Because middle-click just makes sense.

## Install (Apple Silicon, macOS 13+)

The app is distributed as a signed ZIP on the [Releases](https://github.com/d0dg3r/MacPasteNext/releases) page. The build is self-signed (no Apple Developer Program subscription), so macOS quarantines it on first launch — you only have to clear that once, and Sparkle handles every update from then on.

### Option A — One-line installer (recommended)

Open Terminal and paste:

```bash
curl -fsSL https://github.com/d0dg3r/MacPasteNext/releases/latest/download/MacPasteNext-macos-arm64.zip -o /tmp/MacPasteNext.zip \
  && unzip -oq /tmp/MacPasteNext.zip -d /Applications \
  && xattr -dr com.apple.quarantine /Applications/MacPasteNext.app \
  && open /Applications/MacPasteNext.app
```

This downloads the latest signed build, drops it into `/Applications`, removes the Gatekeeper quarantine flag, and launches the app.

### Option B — Manual install

1. Download `MacPasteNext-macos-arm64.zip` from the [latest release](https://github.com/d0dg3r/MacPasteNext/releases/latest).
2. Double-click the ZIP to unpack `MacPasteNext.app`.
3. Move `MacPasteNext.app` into `/Applications`.
4. Clear the Gatekeeper quarantine (otherwise macOS will refuse to launch a self-signed app):

   ```bash
   xattr -dr com.apple.quarantine /Applications/MacPasteNext.app
   ```

5. Launch the app from Launchpad or Spotlight.

### First launch — grant Accessibility

On first start MacPasteNext asks for **Accessibility** access. This is the macOS permission that lets the app:

- observe global mouse clicks (so it can detect selections and middle-clicks), and
- simulate `Cmd+C` / `Cmd+V` (so it can paste into any focused app).

Allow it in *System Settings → Privacy & Security → Accessibility*, then click *"Refresh Permission Status"* in the app window. If macOS gets stuck and stops prompting, the settings panel has a built-in `tccutil reset` button that gives it a fresh start.

### Updates are automatic

The app embeds [Sparkle](https://sparkle-project.org/) and checks the signed `appcast.xml` from the latest GitHub release in the background. When a newer build is available, you get a small update prompt right inside MacPasteNext — no more re-running the install commands. Every update ZIP is verified with an EdDSA signature before installation. You can disable background checks in *Settings → Updates* or trigger a check on demand from there or from the menu bar.

## Features

- 🖱 **Auto-Copy on Selection**: Highlight text in *any* app, and it is instantly captured into an internal Linux-style PRIMARY buffer. Your regular `Cmd+C` clipboard is preserved.
- 🖱 **Middle-Click Paste**: Click your middle mouse button to paste your PRIMARY buffer instantly.
- 🎤 **Global Microphone Mute**: Toggle your system microphone on/off using a side mouse button. It remembers your previous volume level and displays a distinct Red/Green indicator in the macOS Menu Bar.
- ♻️ **Auto-Updates**: Powered by [Sparkle](https://sparkle-project.org/). The app checks for new releases in the background and offers one-click updates. EdDSA signatures verify every download.
- 🌍 **Localization**: Fluent in both English and German.
- 🐞 **Debug Friendly**: Fully integrated real-time logging console visible directly in the app.

## Screenshots

| Dark Mode | Light Mode |
| --- | --- |
| ![MacPasteNext Dark Mode](assets/screenshot-dark.png) | ![MacPasteNext Light Mode](assets/screenshot-light.png) |

These screenshots can be refreshed using the GitHub Actions workflow:

- `Capture macOS Screenshots` (`.github/workflows/screenshots.yml`)
- The workflow creates real macOS screenshots and commits updates to:
  - `assets/screenshot-dark.png`
  - `assets/screenshot-light.png`

## Build from source

If you want to hack on MacPasteNext or build it yourself instead of using the prebuilt release:

1. Clone this repository.
2. Open a terminal in the cloned directory.
3. Build a release app bundle:

   ```bash
   chmod +x scripts/build-release.sh
   ./scripts/build-release.sh
   ```

4. Self-sign locally for quick tests:

   ```bash
   codesign --force --deep --sign - dist/MacPasteNext.app
   ```

5. Move `dist/MacPasteNext.app` to `/Applications/` and launch it.

The build expects Swift 5.9+ and uses Apple's `sips`, `iconutil`, `codesign`, and `security` toolchain, so it must run on macOS.

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

### One-time Sparkle EdDSA setup (auto-updates)

Sparkle signs every update with EdDSA so the app can verify the download
even without Apple notarization. You generate the keypair once on macOS,
add the private key as a GitHub secret, and the public key as a GitHub
Actions variable that gets embedded into every build.

1. On your Mac, run:

   ```bash
   ./scripts/sparkle-bootstrap.sh
   ```

   The script downloads the matching Sparkle release, runs `generate_keys`,
   stores the private key in your Keychain, and prints both keys with copy
   instructions.

2. Open `Settings -> Secrets and variables -> Actions` and add:

   - **Variable** `SPARKLE_PUBLIC_ED_KEY` -> the public key from step 1
     (safe to commit-visible; it ends up in the app's `Info.plist`)
   - **Secret** `SPARKLE_ED_PRIVATE_KEY` -> the private key from step 1
     (the release workflow uses it to sign the update ZIP)

3. The next tag push will sign the update with Sparkle, generate an
   `appcast.xml` referencing the embedded public key, and upload both the
   ZIP and the appcast as release assets. Installed apps poll
   `https://github.com/d0dg3r/MacPasteNext/releases/latest/download/appcast.xml`
   for new versions.

If the secret/variable are missing the workflow still builds and uploads
the ZIP, just without auto-update metadata, and emits a warning.

### Triggering releases

- Final/stable tags use: `v1.0.0`, `v1.0.1`, ...
- Beta tags use: `v1.0.0-beta.1`, `v1.0.0-beta.2`, ... (the `-beta.N` suffix communicates the channel; the tag name is the source of truth).
- Every tag is published as a normal (non-prerelease) GitHub release and explicitly promoted to `latest` so Sparkle's poll URL `https://github.com/d0dg3r/MacPasteNext/releases/latest/download/appcast.xml` always resolves. GitHub refuses to set a prerelease as "latest", which would break the auto-updater for all installs.
- Each release builds, signs, runs smoke tests, uploads `MacPasteNext-macos-arm64.zip` + `appcast.xml`, and then triggers screenshot refresh automation.

### Local preflight checks before CI

These checks are safe on Linux and help catch obvious issues before pushing:

```bash
# Shell syntax checks
bash -n scripts/build-release.sh
bash -n scripts/sign-selfsigned.sh
bash -n scripts/smoke-test-macos.sh
bash -n scripts/validate-release-inputs.sh
bash -n scripts/sparkle-bootstrap.sh
bash -n scripts/sparkle-publish-update.sh

# Changelog extraction sanity check (replace tag as needed)
./scripts/extract-changelog.sh v1.0.0-beta.1 CHANGELOG.md /tmp/release-notes.md allow-missing
```

Full app build/sign/smoke requires macOS because it depends on Apple tooling (`sips`, `iconutil`, `codesign`, `security`, `spctl`).

## Troubleshooting

- **"App is damaged and can't be opened"** — Gatekeeper still sees the download as quarantined. Run `xattr -dr com.apple.quarantine /Applications/MacPasteNext.app` once and try again. The installer one-liner in [Install](#install-apple-silicon-macos-13) does this for you.
- **Accessibility permission stuck / not prompting** — open the app, switch to *Settings* and use the *"Request Permission Again (tccutil reset)"* button. macOS occasionally caches a stale `denied` decision; the button clears it via `tccutil reset Accessibility io.github.joemild.macpastenext`.
- **Middle-click is doing the wrong thing** — toggle *Middle-Click Paste* in the settings; if you map the mic-mute feature to button 2 it will take precedence over the paste action.
- **Update check fails** — open *Settings → Updates* and click *Check for Updates*. If you see a feed error, the path is shown in the *About* dialog so you can verify it matches `https://github.com/d0dg3r/MacPasteNext/releases/latest/download/appcast.xml`.

## Contributing

Community contributions to deal with macOS quirks are welcome. See `CONTRIBUTING.md` for our contribution guidelines.

## Support and Reporting

- Usage/setup questions: [GitHub Discussions](https://github.com/d0dg3r/MacPasteNext/discussions)
- Bug reports: [GitHub Issues](https://github.com/d0dg3r/MacPasteNext/issues)
- Security vulnerabilities: [GitHub Security Advisory](https://github.com/d0dg3r/MacPasteNext/security/advisories/new) (private)
- Code of Conduct concerns: [Maintainer profile](https://github.com/d0dg3r)

## Project Health

- Roadmap: `ROADMAP.md`
- Changelog: `CHANGELOG.md`
- Code of Conduct: `CODE_OF_CONDUCT.md`
- Security Policy: `SECURITY.md`
- Privacy Policy: `PRIVACY.md`

## License

Provided under the MIT License. See `LICENSE` for more information.
