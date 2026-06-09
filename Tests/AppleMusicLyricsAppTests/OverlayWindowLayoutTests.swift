import AppKit
import Testing
import AppleMusicLyricsCore
@testable import AppleMusicLyricsApp

@Test func initialFrameUsesSavedOriginAndClampedWidth() {
    let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    var preferences = LyricsPreferences.default
    preferences.overlayWidth = 2200
    preferences.windowOrigin = CodablePoint(x: 88, y: 166)

    let frame = OverlayWindowLayout.initialFrame(for: preferences, in: screenFrame)

    #expect(frame.origin.x == 72)
    #expect(frame.origin.y == 166)
    #expect(frame.width == 1360)
    #expect(frame.height == 118)
}

@Test func initialFrameUsesDefaultOriginWithoutSavedPosition() {
    let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    var preferences = LyricsPreferences.default
    preferences.overlayWidth = 800
    preferences.windowOrigin = nil

    let frame = OverlayWindowLayout.initialFrame(for: preferences, in: screenFrame)

    #expect(frame.origin.x == 320)
    #expect(frame.origin.y == 120)
    #expect(frame.width == 800)
    #expect(frame.height == 118)
}

@Test func initialFrameClampsSavedOriginToVisibleScreen() {
    let screenFrame = NSRect(x: 0, y: 0, width: 900, height: 600)
    var preferences = LyricsPreferences.default
    preferences.overlayWidth = 500
    preferences.windowOrigin = CodablePoint(x: 760, y: -80)

    let frame = OverlayWindowLayout.initialFrame(for: preferences, in: screenFrame)

    #expect(frame.origin.x == 392)
    #expect(frame.origin.y == 8)
    #expect(frame.width == 500)
    #expect(frame.height == 118)
}
