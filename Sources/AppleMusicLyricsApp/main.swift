import AppKit

let app = NSApplication.shared
let coordinator = AppCoordinator()
app.delegate = coordinator
app.setActivationPolicy(.accessory)
app.run()
