import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    @AppStorage("autoCopyOnSelect") var autoCopyOnSelect: Bool = true
    @AppStorage("middleClickPaste") var middleClickPaste: Bool = true
    @AppStorage("pasteDelayMs") var pasteDelayMs: Double = 100.0 // delay in ms
    @AppStorage("isEnabled") var isEnabled: Bool = true
    
    // Microphone Settings
    @AppStorage("enableMicMute") var enableMicMute: Bool = false
    @AppStorage("micMuteButton") var micMuteButton: Int = 3 // 3=Thumb Back, 4=Thumb Forward
    @AppStorage("lastMicVolume") var lastMicVolume: Int = 100
    
    // UI Settings
    @AppStorage("language") var language: String = "de" // "de" or "en"
    @AppStorage("showLogs") var showLogs: Bool = false
}
