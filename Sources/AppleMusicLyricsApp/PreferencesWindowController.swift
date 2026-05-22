import AppKit
import SwiftUI
import AppleMusicLyricsCore

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?

    func show(
        preferences: LyricsPreferences,
        onSave: @escaping (LyricsPreferences) -> Void,
        onResetPosition: @escaping () -> Void,
        onClearCache: @escaping () -> Void
    ) {
        let view = PreferencesView(
            preferences: preferences,
            onSave: onSave,
            onResetPosition: onResetPosition,
            onClearCache: onClearCache
        )

        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Apple Music Lyrics 偏好设置"
            window?.center()
        }

        window?.contentView = NSHostingView(rootView: view)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
