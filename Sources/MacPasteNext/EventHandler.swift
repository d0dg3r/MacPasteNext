import Foundation
import CoreGraphics
import AppKit

class EventHandler {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let settings: SettingsStore
    private let logStore: LogStore

    private var isDragging = false
    private var lastAutoCopyTriggerTime: TimeInterval = 0
    private let autoCopyDebounceSeconds: TimeInterval = 0.3

    // Linux-style PRIMARY selection buffer. Lives only in this process and
    // is NOT the system clipboard (Cmd+C content is preserved across captures).
    private var primaryBuffer: String = ""

    // Tracks which mouse-down events we swallowed so we can also swallow the
    // matching mouse-up. Without this, the OS would see an "up without down"
    // for the intercepted side button and might still react to it.
    private var swallowedDownButtons: Set<Int64> = []

    init(settings: SettingsStore, logStore: LogStore) {
        self.settings = settings
        self.logStore = logStore
    }

    func start() {
        if eventTap != nil {
            logStore.add("CGEventTap already running; start() ignored")
            return
        }
        logStore.add("Starting CGEventTap...")

        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: EventHandler.tapCallback,
            userInfo: userInfo
        ) else {
            logStore.add("ERROR: Failed to create CGEventTap. Accessibility permission missing?")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source

        logStore.add("CGEventTap installed successfully.")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        swallowedDownButtons.removeAll()
        isDragging = false
        logStore.add("CGEventTap removed.")
    }

    // C-compatible trampoline. Must not capture anything; we recover `self`
    // from the userInfo pointer we passed to tapCreate.
    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let handler = Unmanaged<EventHandler>.fromOpaque(userInfo).takeUnretainedValue()
        return handler.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logStore.add("CGEventTap disabled (type=\(type.rawValue)); re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard settings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDragged:
            isDragging = true
            return Unmanaged.passUnretained(event)

        case .leftMouseUp:
            let clickState = event.getIntegerValueField(.mouseEventClickState)
            let isMultiClick = clickState >= 2
            let triggerCopy = isDragging || isMultiClick
            isDragging = false

            if settings.autoCopyOnSelect && triggerCopy {
                let now = Date().timeIntervalSince1970
                if now - lastAutoCopyTriggerTime >= autoCopyDebounceSeconds {
                    lastAutoCopyTriggerTime = now
                    // Defer real work so the tap callback returns immediately
                    // and macOS does not disable the tap for "running too long".
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.logStore.add("Action: selection detected (clickState=\(clickState)), capturing to PRIMARY")
                        self.captureSelectionToPrimary()
                    }
                }
            }
            return Unmanaged.passUnretained(event)

        case .otherMouseDown:
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

            // Mic mute on the configured side button - intercept and swallow.
            if settings.enableMicMute && Int(buttonNumber) == settings.micMuteButton {
                swallowedDownButtons.insert(buttonNumber)
                DispatchQueue.main.async { [weak self] in
                    self?.logStore.add("Action: mic mute button \(buttonNumber) intercepted")
                    self?.toggleMicrophone()
                }
                return nil
            }

            // Middle-click paste: ONLY true middle button (== 2), never the
            // configured mic button. Do not swallow so the underlying app
            // can still react to middle-click (e.g. open link in new tab).
            if settings.middleClickPaste && buttonNumber == 2 && Int(buttonNumber) != settings.micMuteButton {
                DispatchQueue.main.async { [weak self] in
                    self?.logStore.add("Action: middle-click -> paste from PRIMARY")
                    self?.pasteFromPrimary()
                }
                return Unmanaged.passUnretained(event)
            }

            return Unmanaged.passUnretained(event)

        case .otherMouseUp:
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            if swallowedDownButtons.remove(buttonNumber) != nil {
                return nil
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Pasteboard snapshot / restore

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private func snapshotPasteboard() -> PasteboardSnapshot {
        let pb = NSPasteboard.general
        guard let items = pb.pasteboardItems else {
            return PasteboardSnapshot(items: [])
        }
        var collected: [[NSPasteboard.PasteboardType: Data]] = []
        for item in items {
            var bag: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    bag[type] = data
                }
            }
            if !bag.isEmpty {
                collected.append(bag)
            }
        }
        return PasteboardSnapshot(items: collected)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        guard !snapshot.items.isEmpty else { return }
        var rebuilt: [NSPasteboardItem] = []
        for bag in snapshot.items {
            let item = NSPasteboardItem()
            for (type, data) in bag {
                item.setData(data, forType: type)
            }
            rebuilt.append(item)
        }
        pb.writeObjects(rebuilt)
    }

    // MARK: - PRIMARY selection (Linux-style)

    func captureSelectionToPrimary() {
        let pb = NSPasteboard.general
        let snapshot = snapshotPasteboard()
        let initialChangeCount = pb.changeCount

        simulateCopy()
        pollClipboardForCapture(initialChangeCount: initialChangeCount, snapshot: snapshot, elapsedMs: 0)
    }

    private func pollClipboardForCapture(initialChangeCount: Int, snapshot: PasteboardSnapshot, elapsedMs: Int) {
        let pb = NSPasteboard.general
        let timeoutMs = 300
        let stepMs = 20

        if pb.changeCount != initialChangeCount {
            if let captured = pb.string(forType: .string), !captured.isEmpty {
                primaryBuffer = captured
                logStore.add("PRIMARY buffer updated (\(captured.count) chars)")
            } else {
                logStore.add("PRIMARY: clipboard changed but no string payload; buffer kept")
            }
            restorePasteboard(snapshot)
            return
        }

        if elapsedMs >= timeoutMs {
            logStore.add("PRIMARY: capture timed out, restoring clipboard")
            restorePasteboard(snapshot)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(stepMs)) { [weak self] in
            self?.pollClipboardForCapture(
                initialChangeCount: initialChangeCount,
                snapshot: snapshot,
                elapsedMs: elapsedMs + stepMs
            )
        }
    }

    func pasteFromPrimary() {
        guard !primaryBuffer.isEmpty else {
            logStore.add("PRIMARY paste skipped: buffer empty")
            return
        }

        let pb = NSPasteboard.general
        let snapshot = snapshotPasteboard()

        pb.clearContents()
        pb.setString(primaryBuffer, forType: .string)

        simulatePaste()

        // simulatePaste posts Cmd+V after pasteDelayMs. Give the receiving app
        // a small extra window to consume the paste before we restore.
        let restoreDelayMs = Int(settings.pasteDelayMs) + 250
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(restoreDelayMs)) { [weak self] in
            guard let self = self else { return }
            self.restorePasteboard(snapshot)
            self.logStore.add("PRIMARY: clipboard restored after paste")
        }
    }

    // MARK: - Microphone

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
            targetVol = (settings.lastMicVolume > 0) ? settings.lastMicVolume : 100
        } else {
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
                logStore.add("Mic toggled to: \(targetVol)% (saved previous: \(currentVol)%)")
            }
        }
    }

    // MARK: - Keyboard simulation

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
