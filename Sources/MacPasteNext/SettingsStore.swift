import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    private static func inferredDefaultLanguage() -> String {
        let systemLang = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if systemLang.hasPrefix("de") {
            return "de"
        }
        // Fallback to English for unknown/unsupported locales.
        return "en"
    }

    @AppStorage("autoCopyOnSelect") var autoCopyOnSelect: Bool = true
    @AppStorage("middleClickPaste") var middleClickPaste: Bool = true
    @AppStorage("pasteDelayMs") var pasteDelayMs: Double = 100.0 // delay in ms
    @AppStorage("isEnabled") var isEnabled: Bool = true
    
    // Microphone Settings
    @AppStorage("enableMicMute") var enableMicMute: Bool = false
    @AppStorage("micMuteButton") var micMuteButton: Int = 3 // 3=Thumb Back, 4=Thumb Forward
    @AppStorage("lastMicVolume") var lastMicVolume: Int = 100
    
    // UI Settings
    @AppStorage("language") var language: String = inferredDefaultLanguage() // "de" or "en"
    @AppStorage("showLogs") var showLogs: Bool = false
    @AppStorage("windowWidth") var windowWidth: Double = 420
    @AppStorage("windowHeight") var windowHeight: Double = 760
    @AppStorage("windowPosX") var windowPosX: Double = 0
    @AppStorage("windowPosY") var windowPosY: Double = 0
    @AppStorage("hasSavedWindowPosition") var hasSavedWindowPosition: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
}
