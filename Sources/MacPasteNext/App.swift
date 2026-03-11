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

class MacPasteAppDelegate: NSObject, NSApplicationDelegate {
    var settings = SettingsStore()
    var logStore = LogStore()
    var eventHandler: EventHandler?
    var statusItem: NSStatusItem?
    var window: NSWindow!
    var micStatusTimer: Timer?
    @Published var isMicMuted: Bool = false
    
    @Published var isAccessibilityGranted: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logStore.add("Application did finish launching")
        NSApp.setActivationPolicy(.accessory) // Show in menu bar, allow windows
        
        checkAccessibility()
        setupMenuBar()
        createAndShowWindow()
        
        if settings.isEnabled && isAccessibilityGranted {
            logStore.add("Starting service during launch")
            startService()
        }
        
        startMicStatusPolling()
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
    
    func createAndShowWindow() {
        let contentView = ContentView(
            settings: settings,
            logStore: logStore,
            appDelegate: self,
            isAccessibilityGranted: isAccessibilityGranted
        )
        // Allow the hosting view to compute its natural height but constrain it
        let hostingView = NSHostingView(rootView: contentView.fixedSize(horizontal: true, vertical: true))
        let targetSize = hostingView.fittingSize
        
        // Define a reasonable max height so it doesn't run off screen
        let maxHeight: CGFloat = 800
        let finalHeight = min(targetSize.height + 40, maxHeight) // add a tiny bit of padding
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: targetSize.width, height: finalHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.center()
        window.title = Translator.get("status_title", lang: settings.language)
        
        // Now wrap the content without fixedSize so it can pad normally inside the window
        let finalHostingView = NSHostingView(rootView: contentView)
        window.contentView = finalHostingView
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
        menu.addItem(NSMenuItem(title: "MacPasteNext v1.11", action: #selector(showWindow), keyEquivalent: ""))
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
        
        statusItem?.menu = menu
        updateMenu()
        logStore.add("NSStatusItem setup complete.")
    }
    
    @objc func menuBarClicked() { }
    
    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        if let menu = statusItem?.menu {
            let l = settings.language
            let toggleItem = menu.item(at: 2) // Toggle button
            toggleItem?.title = Translator.get(settings.isEnabled ? "menu_deactivate" : "menu_activate", lang: l)
            
            if menu.items.count > 4 {
                let micItem = menu.item(at: 4)
                micItem?.title = Translator.get(settings.enableMicMute ? "menu_mic_off" : "menu_mic_on", lang: l)
            }
            if menu.items.count > 5 {
                let quitItem = menu.item(at: 5)
                quitItem?.title = Translator.get("menu_quit", lang: l)
            }
            
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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Side: Controls
            VStack(spacing: 20) {
                Image(systemName: "ladybug.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.orange)
                
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
                        
                        Divider()
                        
                        Button(Translator.get("update_status", lang: settings.language)) {
                            appDelegate.checkAccessibility()
                            isAccessibilityGranted = appDelegate.isAccessibilityGranted
                            appDelegate.updateMenu()
                            if isAccessibilityGranted && settings.isEnabled {
                                appDelegate.startService()
                            }
                        }
                        
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
                .frame(maxWidth: .infinity)
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
