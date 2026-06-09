import AppKit
import SwiftUI
import AppleMusicLyricsCore

@MainActor
final class LyricsOverlayController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private var preferences: LyricsPreferences
    private var model: LyricsOverlayModel?
    private var hostingView: NSHostingView<LyricsOverlayView>?
    var onFrameChanged: (() -> Void)?

    init(preferences: LyricsPreferences) {
        self.preferences = preferences
        super.init()
    }

    func show(current: String, next: String) {
        let panel = ensureWindow()
        ensureHostingView(on: panel)
        model?.currentLine = current
        model?.nextLine = next
        model?.preferences = preferences
        panel.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func updatePreferences(_ preferences: LyricsPreferences) {
        self.preferences = preferences
        model?.preferences = preferences
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

    func windowDidMove(_ notification: Notification) {
        onFrameChanged?()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        onFrameChanged?()
    }

    private func ensureWindow() -> NSPanel {
        if let window {
            return window
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = OverlayWindowLayout.initialFrame(for: preferences, in: screenFrame)
        let panel = NSPanel(
            contentRect: frame,
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
        panel.minSize = NSSize(width: 360, height: 118)
        panel.maxSize = NSSize(width: 1800, height: 118)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.alphaValue = preferences.opacity
        panel.delegate = self
        panel.setFrame(frame, display: false)

        self.window = panel
        return panel
    }

    private func ensureHostingView(on panel: NSPanel) {
        if hostingView != nil {
            return
        }

        let initialModel = LyricsOverlayModel(
            currentLine: "等待 Apple Music 播放",
            nextLine: "",
            preferences: preferences
        )
        model = initialModel
        let view = LyricsOverlayView(model: initialModel)
        let host = NSHostingView(rootView: view)
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host
        hostingView = host
    }
}

enum OverlayWindowLayout {
    static func initialFrame(for preferences: LyricsPreferences, in screenFrame: NSRect) -> NSRect {
        let configuredWidth = max(360, min(preferences.overlayWidth, 1800))
        let width = min(configuredWidth, max(360, screenFrame.width - 80))
        let size = NSSize(width: width, height: 118)
        let proposedOrigin: NSPoint

        if let savedOrigin = preferences.windowOrigin {
            proposedOrigin = NSPoint(x: savedOrigin.x, y: savedOrigin.y)
        } else {
            proposedOrigin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.minY + 120)
        }

        let origin = clampedOrigin(proposedOrigin, size: size, in: screenFrame)
        return NSRect(origin: origin, size: size)
    }

    private static func clampedOrigin(_ origin: NSPoint, size: NSSize, in screenFrame: NSRect) -> NSPoint {
        let margin = 8.0
        let minX = screenFrame.minX + margin
        let maxX = max(minX, screenFrame.maxX - size.width - margin)
        let minY = screenFrame.minY + margin
        let maxY = max(minY, screenFrame.maxY - size.height - margin)

        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}
