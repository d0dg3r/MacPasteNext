import SwiftUI
import OSLog
import AppKit

let appLogger = Logger(subsystem: "io.github.joemild.macpastenext", category: "App")

struct Translator {
    static let strings: [String: [String: String]] = [
        "status_title": ["en": "MacPasteNext Status", "de": "MacPasteNext Status"],
        "acc_req": ["en": "Accessibility Access Required", "de": "Bedienungshilfen-Zugriff erforderlich"],
        "acc_desc": ["en": "MacPasteNext requires this access to detect mouse clicks and simulate key presses.", "de": "MacPasteNext benötigt diesen Zugriff, um Mausklicks zu erkennen und Tastendrücke zu simulieren."],
        "open_sys_prefs": ["en": "Open System Settings", "de": "Systemeinstellungen öffnen"],
        "request_again": ["en": "Request Permission Again (tccutil reset)", "de": "Erneut Berechtigung anfragen (tccutil reset)"],
        "acc_granted": ["en": "Permissions granted ✓", "de": "Berechtigungen erteilt ✓"],
        "status_active": ["en": "Status: ACTIVE", "de": "Status: AKTIV"],
        "status_inactive": ["en": "Status: INACTIVE", "de": "Status: INAKTIV"],
        "features": ["en": "Features", "de": "Features"],
        "auto_copy": ["en": "Auto-copy on selection", "de": "Auto-copy bei Auswahl"],
        "mid_paste": ["en": "Middle click paste", "de": "Mittelklick Paste"],
        "mic_mute": ["en": "Microphone Mute via Mouse", "de": "Mikrofon Stumm via Maustaste"],
        "mouse_btn": ["en": "Mouse Button", "de": "Maustaste"],
        "btn_2": ["en": "Button 2 (Middle)", "de": "Taste 2 (Mitte)"],
        "btn_3": ["en": "Button 3 (Thumb Back)", "de": "Taste 3 (Daumen Zurück)"],
        "btn_4": ["en": "Button 4 (Thumb Forward)", "de": "Taste 4 (Daumen Vor)"],
        "btn_5": ["en": "Button 5", "de": "Taste 5"],
        "update_status": ["en": "Refresh Permission Status", "de": "Berechtigungsstatus aktualisieren"],
        "sim_copy": ["en": "Simulate Copy", "de": "Kopie simulieren"],
        "sim_paste": ["en": "Simulate Paste", "de": "Paste simulieren"],
        "live_debug": ["en": "Live Debug Console", "de": "Live Debug Console"],
        "clear_logs": ["en": "Clear logs", "de": "Logs leeren"],
        "lang_lbl": ["en": "Language", "de": "Sprache"],
        "lang_en": ["en": "English", "de": "Englisch"],
        "lang_de": ["en": "German", "de": "Deutsch"],
        "show_logs": ["en": "Show Debug Logs", "de": "Debug-Logs anzeigen"],
        "menu_deactivate": ["en": "Deactivate", "de": "Deaktivieren"],
        "menu_activate": ["en": "Activate", "de": "Aktivieren"],
        "menu_mic_off": ["en": "Mic Feature Off", "de": "Mic-Feature aus"],
        "menu_mic_on": ["en": "Mic Feature On", "de": "Mic-Feature an"],
        "menu_quit": ["en": "Quit", "de": "Beenden"],
        "creator_credit": [
            "en": "Created by Joe Mild. Because in 2026, he was still absolutely sick of macOS being too stupid for basic Linux copy & paste. Sometimes you just have to fix this shit yourself.",
            "de": "Erschaffen von Joe Mild. Weil er 2026 immer noch die Schnauze voll davon hatte, dass macOS zu dumm für simples Linux-Copy&Paste ist. Manchmal muss man den Kram einfach selbst fixen."
        ]
    ]
    
    static func get(_ key: String, lang: String) -> String {
        return strings[key]?[lang] ?? key
    }
}

class LogStore: ObservableObject {
    @Published var logs: [String] = []
    
    func add(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let time = formatter.string(from: Date())
        let combined = "[\(time)] \(message)"
        appLogger.log("\(message)") // System log fallback
        
        DispatchQueue.main.async {
            self.logs.append(combined)
            if self.logs.count > 200 {
                self.logs.removeFirst()
            }
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}

struct AppLogoView: View {
    var body: some View {
        if let path = Bundle.main.path(forResource: "banner", ofType: "png"),
           let banner = NSImage(contentsOfFile: path) {
            Image(nsImage: banner)
                .resizable()
                .scaledToFit()
        } else if let path = Bundle.main.path(forResource: "appicon", ofType: "png"),
                  let icon = NSImage(contentsOfFile: path) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "mouse.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.green)
        }
    }
}

class MacPasteAppDelegate: NSObject, NSApplicationDelegate {
    private let repoWebURL = URL(string: "https://github.com/d0dg3r/MacPasteNext")!
    private let issuesWebURL = URL(string: "https://github.com/d0dg3r/MacPasteNext/issues")!
    private let releasesWebURL = URL(string: "https://github.com/d0dg3r/MacPasteNext/releases")!
    private let discussionsWebURL = URL(string: "https://github.com/d0dg3r/MacPasteNext/discussions")!
    private let sponsorsWebURL = URL(string: "https://github.com/sponsors/d0dg3r")!
    private let repoApiURL = URL(string: "https://api.github.com/repos/d0dg3r/MacPasteNext")!

    var settings = SettingsStore()
    var logStore = LogStore()
    var eventHandler: EventHandler?
    var statusItem: NSStatusItem?
    var window: NSWindow!
    var micStatusTimer: Timer?
    var toggleMenuItem: NSMenuItem?
    var micMuteMenuItem: NSMenuItem?
    var quitMenuItem: NSMenuItem?
    var discussionsMenuItem: NSMenuItem?
    var hasDiscussionsEnabled: Bool = false
    @Published var isMicMuted: Bool = false
    
    @Published var isAccessibilityGranted: Bool = false

    private var appVersionTitle: String {
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let resolved = bundleVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (resolved?.isEmpty == false) ? resolved! : "dev"
        let normalized = value.hasPrefix("v") ? value : "v\(value)"
        return "MacPasteNext \(normalized)"
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logStore.add("Application did finish launching")
        NSApp.setActivationPolicy(.accessory) // Show in menu bar, allow windows
        
        checkAccessibility()
        setupMenuBar()
        refreshRepositoryMetadata()
        createMainWindow()
        closeUnexpectedStartupWindows()
        
        if settings.isEnabled && isAccessibilityGranted {
            logStore.add("Starting service during launch")
            startService()
        }
        
        startMicStatusPolling()
    }

    private func closeUnexpectedStartupWindows() {
        let cleanupDelays: [TimeInterval] = [0.0, 0.25, 0.75]
        for delay in cleanupDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                for candidate in NSApp.windows where candidate != self.window {
                    let title = candidate.title.lowercased()
                    // Only close the auto-created empty SwiftUI Settings window.
                    // Never touch other system/app windows to avoid breaking status item interactions.
                    if title.contains("settings") {
                        candidate.orderOut(nil)
                        candidate.close()
                    }
                }
            }
        }
    }
    
    func startMicStatusPolling() {
        micStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkMicStatus()
        }
        checkMicStatus() // Initial check
    }
    
    func checkMicStatus() {
        let script = "return (input volume of (get volume settings))"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                let vol = result.int32Value
                let currentlyMuted = (vol == 0)
                if currentlyMuted != self.isMicMuted {
                    self.isMicMuted = currentlyMuted
                    DispatchQueue.main.async {
                        self.updateMenu()
                    }
                }
            }
        }
    }
    
    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
        logStore.add("Accessibility Status: \(self.isAccessibilityGranted)")
    }
    
    func updateWindowLayout() {
        guard let window else { return }
        let width: CGFloat = settings.showLogs ? 980 : 420
        let height: CGFloat = 760
        window.setContentSize(NSSize(width: width, height: height))
    }

    func createMainWindow() {
        let contentView = ContentView(
            settings: settings,
            logStore: logStore,
            appDelegate: self,
            isAccessibilityGranted: isAccessibilityGranted
        )
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.center()
        window.title = Translator.get("status_title", lang: settings.language)
        window.minSize = NSSize(width: 420, height: 620)
        
        let finalHostingView = NSHostingView(rootView: contentView)
        window.contentView = finalHostingView
        updateWindowLayout()
    }

    func createAndShowWindow() {
        if window == nil {
            createMainWindow()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupMenuBar() {
        logStore.add("Setting up NSStatusItem manually...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.action = #selector(menuBarClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: appVersionTitle, action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About MacPasteNext...", action: #selector(showAbout), keyEquivalent: ""))

        let helpItem = NSMenuItem(title: "Hilfe", action: nil, keyEquivalent: "")
        let helpMenu = NSMenu()
        helpMenu.addItem(NSMenuItem(title: "Projekt-Repo öffnen", action: #selector(openProjectRepo), keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "Issue melden", action: #selector(openIssues), keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "Releases", action: #selector(openReleases), keyEquivalent: ""))
        let discussionsItem = NSMenuItem(title: "Discussions", action: #selector(openDiscussions), keyEquivalent: "")
        discussionsItem.isHidden = !hasDiscussionsEnabled
        helpMenu.addItem(discussionsItem)
        helpMenu.addItem(NSMenuItem(title: "Version/Build-ID kopieren", action: #selector(copyVersionInfo), keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(NSMenuItem(title: "GitHub Sponsors", action: #selector(openSponsors), keyEquivalent: ""))
        for item in helpMenu.items {
            item.target = self
        }
        helpItem.submenu = helpMenu
        menu.addItem(helpItem)
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let micMuteItem = NSMenuItem(title: "", action: #selector(toggleMicMute), keyEquivalent: "")
        micMuteItem.target = self
        menu.addItem(micMuteItem)
        
        let quitItem = NSMenuItem(title: "", action: #selector(terminate), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        toggleMenuItem = toggleItem
        micMuteMenuItem = micMuteItem
        quitMenuItem = quitItem
        discussionsMenuItem = discussionsItem
        statusItem?.menu = menu
        updateMenu()
        logStore.add("NSStatusItem setup complete.")
    }
    
    @objc func menuBarClicked() { }
    
    @objc func showWindow() {
        createAndShowWindow()
        updateWindowLayout()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MacPasteNext \(appVersionTitle.replacingOccurrences(of: "MacPasteNext ", with: ""))"
        alert.informativeText = """
        Linux-style middle-click paste for macOS plus microphone toggle.
        Linux-Mittelklick-Paste fuer macOS plus Mikrofon-Toggle.

        Created by Joe Mild.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "GitHub Repository")
        alert.addButton(withTitle: "GitHub Sponsors")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(repoWebURL)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(sponsorsWebURL)
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(releasesWebURL)
        default:
            break
        }
    }

    @objc func openProjectRepo() {
        NSWorkspace.shared.open(repoWebURL)
    }

    @objc func openIssues() {
        NSWorkspace.shared.open(issuesWebURL)
    }

    @objc func openReleases() {
        NSWorkspace.shared.open(releasesWebURL)
    }

    @objc func openDiscussions() {
        NSWorkspace.shared.open(discussionsWebURL)
    }

    @objc func openSponsors() {
        NSWorkspace.shared.open(sponsorsWebURL)
    }

    @objc func copyVersionInfo() {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown.bundle"
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? short
        let payload = "MacPasteNext \(short) (\(build)) | \(bundleId) | git@github.com:d0dg3r/MacPasteNext.git"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        logStore.add("Copied version/build info to clipboard")
    }
    
    @objc func toggleEnabled() {
        settings.isEnabled.toggle()
        updateMenu()
        if settings.isEnabled && isAccessibilityGranted {
            startService()
        } else {
            eventHandler?.stop()
        }
    }
    
    @objc func toggleMicMute() {
        settings.enableMicMute.toggle()
        updateMenu()
    }
    
    @objc func terminate() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateMenu() {
        if statusItem?.menu != nil {
            let l = settings.language
            toggleMenuItem?.title = Translator.get(settings.isEnabled ? "menu_deactivate" : "menu_activate", lang: l)
            micMuteMenuItem?.title = Translator.get(settings.enableMicMute ? "menu_mic_off" : "menu_mic_on", lang: l)
            quitMenuItem?.title = Translator.get("menu_quit", lang: l)
            discussionsMenuItem?.isHidden = !hasDiscussionsEnabled
            
            if let button = statusItem?.button {
                let isMutedEnabled = isMicMuted && settings.enableMicMute
                
                if !settings.isEnabled || !isAccessibilityGranted {
                    button.image = NSImage(systemSymbolName: "cursorarrow.slash", accessibilityDescription: "Disabled")
                } else if settings.enableMicMute {
                    if isMutedEnabled {
                        button.image = createConfiguredIcon(symbolName: "mic.slash.fill", backgroundColor: .systemRed, iconColor: .white)
                    } else {
                        button.image = createConfiguredIcon(symbolName: "mic.fill", backgroundColor: .systemGreen, iconColor: .white)
                    }
                } else {
                    button.image = NSImage(systemSymbolName: "cursorarrow.and.square.on.square.fill", accessibilityDescription: "MacPasteNext")
                }
            }
        }
    }

    private func refreshRepositoryMetadata() {
        var request = URLRequest(url: repoApiURL)
        request.timeoutInterval = 6
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else {
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            let hasDiscussions = (json["has_discussions"] as? Bool) ?? false
            if hasDiscussions != self.hasDiscussionsEnabled {
                DispatchQueue.main.async {
                    self.hasDiscussionsEnabled = hasDiscussions
                    self.updateMenu()
                }
            }
        }.resume()
    }
    
    // Helper to draw a colored background and a symbol on top
    func createConfiguredIcon(symbolName: String, backgroundColor: NSColor, iconColor: NSColor) -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw background circle or rounded rect
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        backgroundColor.setFill()
        path.fill()
        
        // Draw symbol
        if let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                .applying(.init(paletteColors: [iconColor]))
            let coloredSymbol = symbolImage.withSymbolConfiguration(config)
            
            // Center the symbol
            if let drawnSymbol = coloredSymbol {
                // To tint properly without template
                drawnSymbol.isTemplate = false
                let drawRect = NSRect(
                    x: (size.width - drawnSymbol.size.width) / 2,
                    y: (size.height - drawnSymbol.size.height) / 2,
                    width: drawnSymbol.size.width,
                    height: drawnSymbol.size.height
                )
                drawnSymbol.draw(in: drawRect)
            }
        }
        
        image.unlockFocus()
        image.isTemplate = false // Prevent macOS from making it monochrome
        
        return image
    }
    
    func startService() {
        logStore.add("startService() called in AppDelegate")
        if eventHandler == nil {
            logStore.add("Creating new EventHandler instance")
            eventHandler = EventHandler(settings: settings, logStore: logStore)
        }
        logStore.add("Activating Event Handler...")
        eventHandler?.start()
    }
}

struct ContentView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var logStore: LogStore
    var appDelegate: MacPasteAppDelegate
    @State var isAccessibilityGranted: Bool

    private func refreshAccessibilityStatus() {
        appDelegate.checkAccessibility()
        isAccessibilityGranted = appDelegate.isAccessibilityGranted
        appDelegate.updateMenu()
        if isAccessibilityGranted && settings.isEnabled {
            appDelegate.startService()
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Side: Controls
            VStack(spacing: 20) {
                AppLogoView()
                    .frame(width: 240, height: 120)
                
                Text(Translator.get("status_title", lang: settings.language))
                    .font(.title)
                
                if !isAccessibilityGranted {
                    VStack {
                        Text(Translator.get("acc_req", lang: settings.language))
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(Translator.get("acc_desc", lang: settings.language))
                            .multilineTextAlignment(.center)
                            .padding()
                        Button(Translator.get("open_sys_prefs", lang: settings.language)) {
                            let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                            if let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(Translator.get("update_status", lang: settings.language)) {
                            refreshAccessibilityStatus()
                        }
                        .buttonStyle(.bordered)
                        
                        Divider()
                        
                        Button(Translator.get("request_again", lang: settings.language)) {
                            let task = Process()
                            task.launchPath = "/usr/bin/tccutil"
                            task.arguments = ["reset", "Accessibility", "io.github.joemild.macpastenext"]
                            task.launch()
                            task.waitUntilExit()
                            appDelegate.checkAccessibility()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                } else {
                    Text(Translator.get("acc_granted", lang: settings.language))
                        .foregroundColor(.green)
                    Text(Translator.get(settings.isEnabled ? "status_active" : "status_inactive", lang: settings.language))

                    Button(Translator.get("update_status", lang: settings.language)) {
                        refreshAccessibilityStatus()
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text(Translator.get("features", lang: settings.language)).font(.headline)
                        
                        Toggle(Translator.get("auto_copy", lang: settings.language), isOn: $settings.autoCopyOnSelect)
                        Toggle(Translator.get("mid_paste", lang: settings.language), isOn: $settings.middleClickPaste)
                        
                        Toggle(Translator.get("mic_mute", lang: settings.language), isOn: $settings.enableMicMute)
                        if settings.enableMicMute {
                            Picker(Translator.get("mouse_btn", lang: settings.language), selection: $settings.micMuteButton) {
                                Text(Translator.get("btn_2", lang: settings.language)).tag(2)
                                Text(Translator.get("btn_3", lang: settings.language)).tag(3)
                                Text(Translator.get("btn_4", lang: settings.language)).tag(4)
                                Text(Translator.get("btn_5", lang: settings.language)).tag(5)
                            }
                        }
                        
                        Divider()
                        Text("UI & Logs").font(.headline)
                        
                        Picker(Translator.get("lang_lbl", lang: settings.language), selection: $settings.language) {
                            Text("English").tag("en")
                            Text("Deutsch").tag("de")
                        }
                        .onChange(of: settings.language) { _ in
                            appDelegate.updateMenu()
                        }
                        
                        Toggle(Translator.get("show_logs", lang: settings.language), isOn: $settings.showLogs)
                            .onChange(of: settings.showLogs) { _ in
                                appDelegate.updateWindowLayout()
                            }
                        
                        Divider()
                        
                        HStack {
                            Button(Translator.get("sim_copy", lang: settings.language)) {
                                appDelegate.eventHandler?.simulateCopy()
                            }
                            Button(Translator.get("sim_paste", lang: settings.language)) {
                                appDelegate.eventHandler?.simulatePaste(at: NSEvent.mouseLocation)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        Text(Translator.get("creator_credit", lang: settings.language))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                    }
                    .padding(.horizontal)
                }
            }
            .frame(width: 320)
            .padding()
            
            // Right Side: Live Log
            if settings.showLogs {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Text(Translator.get("live_debug", lang: settings.language))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(Translator.get("clear_logs", lang: settings.language)) {
                            logStore.clear()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(0..<logStore.logs.count, id: \.self) { index in
                                    Text(logStore.logs[index])
                                        .font(.system(size: 11, design: .monospaced))
                                        .id(index)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .onChange(of: logStore.logs.count) { _ in
                                if logStore.logs.count > 0 {
                                    proxy.scrollTo(logStore.logs.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                }
                .frame(minWidth: 520, maxWidth: .infinity)
            }
        }
    }
}

@main
struct MacPasteNextApp: App {
    @NSApplicationDelegateAdaptor(MacPasteAppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() } // Dummy scene to satisfy SwiftUI
    }
}
