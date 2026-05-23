import AppKit
import SwiftUI
import AppleMusicLyricsCore

@MainActor
protocol PreferencesWindowDelegate: AnyObject {
    func preferencesWindowDidSave(_ preferences: LyricsPreferences)
    func preferencesWindowDidRequestResetPosition()
    func preferencesWindowDidRequestClearCache()
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var preferences: LyricsPreferences {
        didSet {
            delegate?.preferencesWindowDidSave(preferences)
        }
    }

    weak var delegate: PreferencesWindowDelegate?

    init(preferences: LyricsPreferences, delegate: PreferencesWindowDelegate?) {
        self.preferences = preferences
        self.delegate = delegate
    }

    func resetPosition() {
        delegate?.preferencesWindowDidRequestResetPosition()
    }

    func clearCache() {
        delegate?.preferencesWindowDidRequestClearCache()
    }
}

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    private var viewModel: PreferencesViewModel?
    weak var delegate: PreferencesWindowDelegate?

    func show(preferences: LyricsPreferences) {
        let model = PreferencesViewModel(preferences: preferences, delegate: delegate)
        viewModel = model
        let view = PreferencesView(viewModel: model)

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
