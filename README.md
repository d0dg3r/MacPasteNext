# MacPasteNext

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
3. Build the backend using Swift:
   ```bash
   swift build -c release
   ```
4. Copy the executable into the actual app bundle, and sign it:
   ```bash
   cp .build/release/MacPasteNext MacPasteNext.app/Contents/MacOS/MacPasteNext
   codesign --force --deep --sign - MacPasteNext.app
   ```
5. Move `MacPasteNext.app` to your `/Applications/` folder and launch it.

## Permissions Required
Because MacPasteNext needs to monitor your global mouse clicks and natively simulate keypresses (Cmd+C / Cmd+V) to trick macOS into pasting text, the operating system requires you to grant it **Accessibility** permissions. 
If things get stuck with the permissions cache (as macOS often does), there's a handy `tccutil reset` button built directly into the UI to reset it and prompt again.

## Contributing
Community contributions to deal with macOS quirks are welcome. See `CONTRIBUTING.md` for our contribution guidelines.

## License
Provided under the MIT License. See `LICENSE` for more information.
