import AppKit
import SwiftUI
import AppleMusicLyricsCore

@MainActor
final class LyricsOverlayController {
    private var window: NSPanel?
    private var preferences: LyricsPreferences

    init(preferences: LyricsPreferences) {
        self.preferences = preferences
    }

    func show(current: String, next: String) {
        let panel = ensureWindow()
        panel.contentView = NSHostingView(rootView: LyricsOverlayView(
            currentLine: current,
            nextLine: next,
            preferences: preferences
        ))
        panel.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func updatePreferences(_ preferences: LyricsPreferences) {
        self.preferences = preferences
        window?.ignoresMouseEvents = preferences.isLocked
        window?.alphaValue = preferences.opacity
        if let window {
            let width = max(360, min(preferences.overlayWidth, 1800))
            var frame = window.frame
            if abs(frame.size.width - width) > 0.5 {
                frame.size.width = width
                window.setFrame(frame, display: true)
            }
        }
        if let origin = preferences.windowOrigin {
            window?.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
        }
    }

    func setLocked(_ locked: Bool) {
        preferences.isLocked = locked
        window?.ignoresMouseEvents = locked
        window?.isMovableByWindowBackground = !locked
        window?.styleMask = locked
            ? [.borderless, .nonactivatingPanel]
            : [.borderless, .nonactivatingPanel, .resizable]
    }

    func currentWindowOrigin() -> CodablePoint? {
        guard let window else { return nil }
        let origin = window.frame.origin
        return CodablePoint(x: origin.x, y: origin.y)
    }

    func currentWindowWidth() -> Double? {
        guard let window else { return nil }
        return window.frame.width
    }

    private func ensureWindow() -> NSPanel {
        if let window {
            return window
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let configuredWidth = max(360, min(preferences.overlayWidth, 1800))
        let size = NSSize(width: min(configuredWidth, screenFrame.width - 80), height: 118)
        let origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.minY + 120)
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: preferences.isLocked
                ? [.borderless, .nonactivatingPanel]
                : [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = preferences.isLocked
        panel.isMovableByWindowBackground = !preferences.isLocked
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.alphaValue = preferences.opacity

        self.window = panel
        return panel
    }
}
