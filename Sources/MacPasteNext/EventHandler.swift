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

    // Click state captured on leftMouseDown. Some apps don't surface the
    // multi-click state reliably on the matching leftMouseUp, so we track it
    // ourselves from the down event.
    private var lastClickState: Int64 = 1

    // Each captureSelectionToPrimary call bumps this; pending captures check it
    // to bail out if a newer click (e.g. triple-click after double-click)
    // wants to overwrite the buffer.
    private var captureGeneration: Int = 0

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
            (1 << CGEventType.leftMouseDown.rawValue) |
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
                CFRunLoopSourceInvalidate(source)
            }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        swallowedDownButtons.removeAll()
        isDragging = false
        lastClickState = 1
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
        case .leftMouseDown:
            // Track the click state here: it is reliably set on mouse-down
            // across apps (the matching up event sometimes loses it).
            lastClickState = event.getIntegerValueField(.mouseEventClickState)
            isDragging = false
            return Unmanaged.passUnretained(event)

        case .leftMouseDragged:
            isDragging = true
            return Unmanaged.passUnretained(event)

        case .leftMouseUp:
            let isMultiClick = lastClickState >= 2
            let wasDragging = isDragging
            let triggerCopy = wasDragging || isMultiClick
            isDragging = false

            if settings.autoCopyOnSelect && triggerCopy {
                let now = Date().timeIntervalSince1970
                let withinDebounce = (now - lastAutoCopyTriggerTime) < autoCopyDebounceSeconds
                // Drags are debounced; multi-clicks always go through so
                // triple-click can overwrite a pending double-click capture.
                if !withinDebounce || isMultiClick {
                    lastAutoCopyTriggerTime = now
                    let clickStateForLog = lastClickState
                    // Defer real work so the tap callback returns immediately
                    // and macOS does not disable the tap for "running too long".
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.logStore.add("Action: selection detected (clickState=\(clickStateForLog), drag=\(wasDragging)), capturing to PRIMARY")
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
            // configured mic button. We MUST swallow the event so apps with
            // their own middle-click paste (Terminal.app with the middle
            // paste pref enabled, X11-aware apps, etc.) do not paste a second
            // time on top of our Cmd+V (issue #1).
            if settings.middleClickPaste && buttonNumber == 2 && Int(buttonNumber) != settings.micMuteButton {
                swallowedDownButtons.insert(buttonNumber)
                DispatchQueue.main.async { [weak self] in
                    self?.logStore.add("Action: middle-click intercepted -> paste from PRIMARY")
                    self?.pasteFromPrimary()
                }
                return nil
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
        captureGeneration += 1
        let myGen = captureGeneration
        // Give the host app a few frames to finalize the selection.
        // Double-click word selection (and triple-click line selection) often
        // only completes a tick AFTER mouseUp, so sending Cmd+C immediately
        // can land before the selection exists.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self] in
            guard let self = self else { return }
            // A newer capture (e.g. triple-click after this double-click)
            // already supersedes us; let it do the work.
            if myGen != self.captureGeneration {
                self.logStore.add("PRIMARY: capture #\(myGen) superseded by #\(self.captureGeneration), skipping")
                return
            }
            let pb = NSPasteboard.general
            let snapshot = self.snapshotPasteboard()
            let initialChangeCount = pb.changeCount
            self.simulateCopy()
            self.pollClipboardForCapture(
                generation: myGen,
                initialChangeCount: initialChangeCount,
                snapshot: snapshot,
                elapsedMs: 0
            )
        }
    }

    private func pollClipboardForCapture(generation: Int, initialChangeCount: Int, snapshot: PasteboardSnapshot, elapsedMs: Int) {
        // A newer capture took over; the newer poll will perform its own
        // restore, so just stop polling here.
        if generation != captureGeneration {
            return
        }
        let pb = NSPasteboard.general
        let timeoutMs = 300
        let stepMs = 20

        if pb.changeCount != initialChangeCount {
            // Read the string and the change count back-to-back so the
            // restore-guard below can detect if anything else writes to the
            // pasteboard between our capture and our restore.
            let captured = pb.string(forType: .string)
            let postCopyChangeCount = pb.changeCount
            if let s = captured, !s.isEmpty {
                primaryBuffer = s
                logStore.add("PRIMARY buffer updated (\(s.count) chars)")
            } else {
                logStore.add("PRIMARY: clipboard changed but no string payload; buffer kept")
            }
            // If something else wrote to the pasteboard between us reading
            // and us restoring, don't clobber that newer content with our
            // pre-capture snapshot.
            if pb.changeCount == postCopyChangeCount {
                restorePasteboard(snapshot)
            } else {
                logStore.add("PRIMARY: clipboard changed externally during capture, restore skipped")
            }
            return
        }

        if elapsedMs >= timeoutMs {
            logStore.add("PRIMARY: capture timed out, restoring clipboard")
            restorePasteboard(snapshot)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(stepMs)) { [weak self] in
            self?.pollClipboardForCapture(
                generation: generation,
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
        // Snapshot the change count AFTER we wrote our primaryBuffer. If
        // anyone (user via Cmd+C, another app) writes to the pasteboard
        // between now and the restore below, we must not overwrite their
        // newer content with our pre-paste snapshot.
        let postSetChangeCount = pb.changeCount

        simulatePaste()

        // simulatePaste posts Cmd+V after pasteDelayMs. Give the receiving app
        // a small extra window to consume the paste before we restore.
        let restoreDelayMs = Int(settings.pasteDelayMs) + 250
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(restoreDelayMs)) { [weak self] in
            guard let self = self else { return }
            let currentChangeCount = NSPasteboard.general.changeCount
            if currentChangeCount == postSetChangeCount {
                self.restorePasteboard(snapshot)
                self.logStore.add("PRIMARY: clipboard restored after paste")
            } else {
                self.logStore.add("PRIMARY: clipboard changed externally during paste, restore skipped")
            }
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
