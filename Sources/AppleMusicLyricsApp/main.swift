import AppKit

@MainActor
final class BootstrapDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let alert = NSAlert()
        alert.messageText = "Apple Music Lyrics"
        alert.informativeText = "Scaffold running. The menu bar app will be wired in the next tasks."
        alert.runModal()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = BootstrapDelegate()
app.delegate = delegate
app.run()
