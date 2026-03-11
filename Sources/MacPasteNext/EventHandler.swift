import Foundation
import CoreGraphics
import AppKit

class EventHandler {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private let settings: SettingsStore
    private let logStore: LogStore
    
    private var isDragging = false
    private var lastClickTime: TimeInterval = 0
    private let doubleClickThreshold: TimeInterval = 0.5
    
    init(settings: SettingsStore, logStore: LogStore) {
        self.settings = settings
        self.logStore = logStore
    }
    
    func start() {
        logStore.add("Starting NSEvent Monitors...")
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged
        ]
        
        // Global monitor catches events OUTSIDE our app
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleNSEvent(event)
        }
        
        // Local monitor catches events INSIDE our app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }
        
        logStore.add("Event Monitors successfully installed.")
    }
    
    func stop() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        logStore.add("Event Monitors removed.")
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        guard settings.isEnabled else { return }
        
        switch event.type {
        case .leftMouseDown:
            logStore.add("Input: Left Mouse Down (App: \(event.window == nil ? "Outside" : "Inside"))")
            lastClickTime = Date().timeIntervalSince1970
            isDragging = false
            
        case .leftMouseDragged:
            isDragging = true
            
        case .leftMouseUp:
            let now = Date().timeIntervalSince1970
            let isDoubleClick = (now - lastClickTime) < doubleClickThreshold
            logStore.add("Input: Left Mouse Up (drag: \(isDragging), doubleClick: \(isDoubleClick))")
            
            if settings.autoCopyOnSelect && (isDragging || isDoubleClick) {
                logStore.add("Action: Conditions met, triggering Copy (Cmd+C)")
                simulateCopy()
            }
            isDragging = false
            
        case .otherMouseDown:
            let buttonNumber = event.buttonNumber
            logStore.add("Input: Other Mouse Down, Button: \(buttonNumber)")
            
            // Handle Middle Click Paste
            if settings.middleClickPaste && (buttonNumber == 2 || buttonNumber == 3) && buttonNumber != settings.micMuteButton {
                logStore.add("Action: Middle click detected, triggering Paste (Cmd+V)")
                simulatePaste()
            }
            
            // Handle Mic Mute
            let targetMicButton = settings.micMuteButton
            if settings.enableMicMute && buttonNumber == targetMicButton {
                logStore.add("Action: Mic Mute Button (\(targetMicButton)) pressed")
                toggleMicrophone()
            }
            
        default:
            break
        }
    }
    
    func toggleMicrophone() {
        let checkScript = "return (input volume of (get volume settings))"
        var error: NSDictionary?
        
        guard let checkAppleScript = NSAppleScript(source: checkScript) else { return }
        let currentVolResult = checkAppleScript.executeAndReturnError(&error)
        
        guard error == nil else {
            logStore.add("Error getting mic volume: \(String(describing: error))")
            return
        }
        
        let currentVol = Int(currentVolResult.int32Value)
        let targetVol: Int
        
        if currentVol == 0 {
            // Unmuting: Restore previous volume (fallback 100)
            targetVol = (settings.lastMicVolume > 0) ? settings.lastMicVolume : 100
        } else {
            // Muting: Save current volume first
            DispatchQueue.main.async { [weak self] in
                self?.settings.lastMicVolume = currentVol
            }
            targetVol = 0
        }
        
        let setScript = "set volume input volume \(targetVol)"
        if let setAppleScript = NSAppleScript(source: setScript) {
            setAppleScript.executeAndReturnError(&error)
            if let err = error {
                logStore.add("Error setting mic volume: \(err)")
            } else {
                logStore.add("Mic toggled to: \(targetVol)% (Saved previous: \(currentVol)%)")
            }
        }
    }
    
    func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let copyKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'C'
        let copyKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        copyKeyDown?.flags = .maskCommand
        copyKeyUp?.flags = .maskCommand
        
        copyKeyDown?.post(tap: .cgSessionEventTap)
        copyKeyUp?.post(tap: .cgSessionEventTap)
        logStore.add("System: Sent Cmd+C")
    }
    
    func simulatePaste(at location: CGPoint? = nil) {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(settings.pasteDelayMs))) {
            let pasteKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'V'
            let pasteKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            pasteKeyDown?.flags = .maskCommand
            pasteKeyUp?.flags = .maskCommand
            
            pasteKeyDown?.post(tap: .cgSessionEventTap)
            pasteKeyUp?.post(tap: .cgSessionEventTap)
            self.logStore.add("System: Sent Cmd+V")
        }
    }
}
