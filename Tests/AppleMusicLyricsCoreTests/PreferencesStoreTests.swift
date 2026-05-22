import Foundation
import Testing
@testable import AppleMusicLyricsCore

@Test func defaultPreferencesMatchMVP() {
    let preferences = LyricsPreferences.default

    #expect(preferences.isOverlayVisible)
    #expect(!preferences.isLocked)
    #expect(preferences.fontName == "SF Pro Display")
    #expect(preferences.fontSize == 32)
    #expect(preferences.isGradientEnabled)
}

@Test func storesPreferencesInUserDefaults() throws {
    let defaults = UserDefaults(suiteName: "PreferencesStoreTests-\(UUID().uuidString)")!
    let store = PreferencesStore(defaults: defaults)

    var preferences = LyricsPreferences.default
    preferences.isLocked = true
    preferences.fontSize = 40

    try store.save(preferences)
    #expect(try store.load() == preferences)
}
