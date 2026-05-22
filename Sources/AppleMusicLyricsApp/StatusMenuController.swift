import AppKit

struct StatusMenuActions {
    let toggleOverlay: () -> Void
    let toggleLock: () -> Void
    let refreshLyrics: () -> Void
    let openPreferences: () -> Void
    let showAbout: () -> Void
    let quit: () -> Void
}

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let statusItemText = NSMenuItem(title: "正在启动", action: nil, keyEquivalent: "")
    private let versionItem: NSMenuItem
    private let actions: StatusMenuActions

    init(actions: StatusMenuActions, version: String) {
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.versionItem = NSMenuItem(title: "版本：\(version)", action: nil, keyEquivalent: "")
        super.init()
        configureButton()
        configureMenu()
    }

    func setStatus(_ status: String) {
        statusItemText.title = status
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Apple Music Lyrics")
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(statusItemText)
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(item("显示/隐藏歌词", #selector(toggleOverlay)))
        menu.addItem(item("锁定/解锁位置", #selector(toggleLock)))
        menu.addItem(item("刷新歌词", #selector(refreshLyrics)))
        menu.addItem(.separator())
        menu.addItem(item("偏好设置...", #selector(openPreferences)))
        menu.addItem(item("关于", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("退出", #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func toggleOverlay() { actions.toggleOverlay() }
    @objc private func toggleLock() { actions.toggleLock() }
    @objc private func refreshLyrics() { actions.refreshLyrics() }
    @objc private func openPreferences() { actions.openPreferences() }
    @objc private func showAbout() { actions.showAbout() }
    @objc private func quit() { actions.quit() }
}
