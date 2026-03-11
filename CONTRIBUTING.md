# Contributing to MacPasteNext

First off, thanks for taking the time to contribute! MacPasteNext exists because macOS lacks some basic common sense features, and community contributions help make things right.

## How to Contribute
1. **Fork the Repository** and clone your fork down to your local machine.
2. **Create a Branch** for your feature or bugfix (`git checkout -b feature/my-cool-feature`).
3. **Commit your changes**. Keep your commit messages clear and descriptive.
4. **Test your code**. Ensure that `swift build` finishes successfully and the `MacPasteNext.app` runs locally without crashing. Make sure both English and German localizations are updated if UI text was changed.
5. **Push to your Fork** and open a **Pull Request**.

## Environment Setup
MacPasteNext is entirely built using Swift and SwiftUI for the UI. You do not need Xcode necessarily, the Swift CLI is enough:

```bash
swift build
```

The application logic resides in `Sources/MacPasteNext/EventHandler.swift` (global click/keyboard listeners) and `App.swift` (UI, Menu Bar, AppDelegate).

## Bug Reports
If you find a bug, please search existing issues to see if it has been reported before submitting a new one. Provide exact steps yielding the bug. If it relates to copying/pasting, make sure you mention which external app the focus was on (e.g. VS Code, Chrome, etc. can behave non-standardly!).
