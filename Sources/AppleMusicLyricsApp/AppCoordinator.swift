import AppKit
import AppleMusicLyricsCore

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?
    private let detector = MusicTrackDetector()
    private let provider = LRCLIBLyricsProvider()
    private let preferencesStore = PreferencesStore()
    private let preferencesWindowController = PreferencesWindowController()
    private var pollTimer: Timer?
    private var latestSnapshot: TrackSnapshot?
    private var preferences = LyricsPreferences.default
    private var overlayController: LyricsOverlayController?
    private var overlayVisible = true
    private var synchronizer: LyricsSynchronizer?
    private var cache: LyricsCache?
    private var activeTrackKey: LyricsCacheKey?
    private var loadingTrackKey: LyricsCacheKey?
    private var activeLyrics: LyricsResult?

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = (try? preferencesStore.load()) ?? .default
        overlayVisible = preferences.isOverlayVisible
        overlayController = LyricsOverlayController(preferences: preferences)
        overlayController?.onFrameChanged = { [weak self] in
            self?.saveOverlayOriginIfNeeded()
        }
        preferencesWindowController.delegate = self
        if let cacheDirectory = try? LyricsCache.defaultDirectory() {
            cache = LyricsCache(directory: cacheDirectory)
        }

        statusMenuController = StatusMenuController(
            actions: StatusMenuActions(
                toggleOverlay: { [weak self] in self?.toggleOverlay() },
                toggleLock: { [weak self] in self?.toggleLock() },
                refreshLyrics: { [weak self] in self?.refreshLyrics() },
                openPreferences: { [weak self] in self?.openPreferences() },
                showAbout: { [weak self] in self?.showAbout() },
                quit: { NSApp.terminate(nil) }
            ),
            version: AppVersion.display
        )
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollMusic()
            }
        }
        pollMusic()
    }

    private func pollMusic() {
        do {
            let snapshot = try detector.currentSnapshot()
            latestSnapshot = snapshot
            statusMenuController?.setStatus(snapshot.isPlaying ? "正在播放：\(snapshot.title)" : "已暂停：\(snapshot.title)")
            Task { await ensureLyricsLoaded(for: snapshot) }
            updateOverlay(for: snapshot)
        } catch MusicTrackDetectorError.musicNotRunning {
            latestSnapshot = nil
            statusMenuController?.setStatus("Apple Music 未运行")
            overlayController?.hide()
        } catch {
            latestSnapshot = nil
            statusMenuController?.setStatus("需要 Music 自动化权限")
        }
    }

    private func ensureLyricsLoaded(for snapshot: TrackSnapshot) async {
        let key = LyricsCacheKey(track: snapshot)
        if key == activeTrackKey, activeLyrics != nil {
            return
        }
        if loadingTrackKey == key {
            return
        }
        loadingTrackKey = key
        defer { loadingTrackKey = nil }

        // 先用 Apple Music 内置歌词兜底，尤其是中文曲目可显著提高可用性。
        if let localLyrics = detector.currentTrackLyrics(),
           !(activeLyrics?.source == .appleMusic && activeTrackKey == key) {
            activeLyrics = LyricsResult(
                source: .appleMusic,
                syncedLines: [],
                plainText: localLyrics,
                confidence: 0.72
            )
            synchronizer = nil
            activeTrackKey = key
            statusMenuController?.setStatus("优先使用 Apple Music 内置歌词")
            if let latestSnapshot,
               latestSnapshot.title == snapshot.title,
               latestSnapshot.artist == snapshot.artist {
                updateOverlay(for: latestSnapshot)
            }
        }

        if let cached = (try? cache?.load(for: key)) ?? nil {
            activeLyrics = cached
            synchronizer = LyricsSynchronizer(lines: cached.syncedLines)
            activeTrackKey = key
            statusMenuController?.setStatus("已命中缓存歌词：\(snapshot.title)")
            if let latestSnapshot, latestSnapshot.title == snapshot.title, latestSnapshot.artist == snapshot.artist {
                updateOverlay(for: latestSnapshot)
            }
            return
        }

        do {
            if let result = try await provider.lyrics(for: snapshot) {
                activeLyrics = result
                synchronizer = LyricsSynchronizer(lines: result.syncedLines)
                try? cache?.store(result, for: key)
                activeTrackKey = key
                statusMenuController?.setStatus("已匹配在线歌词：\(snapshot.title)")
                if let latestSnapshot, latestSnapshot.title == snapshot.title, latestSnapshot.artist == snapshot.artist {
                    updateOverlay(for: latestSnapshot)
                }
            } else {
                if let localLyrics = detector.currentTrackLyrics() {
                    activeLyrics = LyricsResult(
                        source: .appleMusic,
                        syncedLines: [],
                        plainText: localLyrics,
                        confidence: 0.7
                    )
                    synchronizer = nil
                    activeTrackKey = key
                    statusMenuController?.setStatus("使用 Apple Music 内置歌词：\(snapshot.title)")
                } else {
                    activeLyrics = nil
                    synchronizer = nil
                    activeTrackKey = nil
                    statusMenuController?.setStatus("未匹配到歌词：\(snapshot.title)")
                }
                if let latestSnapshot, latestSnapshot.title == snapshot.title, latestSnapshot.artist == snapshot.artist {
                    updateOverlay(for: latestSnapshot)
                }
            }
        } catch {
            if let localLyrics = detector.currentTrackLyrics() {
                activeLyrics = LyricsResult(
                    source: .appleMusic,
                    syncedLines: [],
                    plainText: localLyrics,
                    confidence: 0.7
                )
                synchronizer = nil
                activeTrackKey = key
                statusMenuController?.setStatus("网络失败，使用 Apple Music 内置歌词")
            } else {
                activeLyrics = nil
                synchronizer = nil
                activeTrackKey = nil
                statusMenuController?.setStatus("歌词请求失败，稍后重试")
            }
            if let latestSnapshot, latestSnapshot.title == snapshot.title, latestSnapshot.artist == snapshot.artist {
                updateOverlay(for: latestSnapshot)
            }
        }
    }

    private func firstDisplayLine(from plainText: String) -> String {
        plainText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func secondDisplayLine(from plainText: String) -> String {
        plainText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .dropFirst()
            .first ?? "未找到同步歌词"
    }

    private func updateOverlay(for snapshot: TrackSnapshot) {
        guard overlayVisible else {
            overlayController?.hide()
            return
        }

        if let synchronizer, snapshot.isPlaying || activeLyrics != nil {
            let state = synchronizer.state(at: snapshot.position)
            overlayController?.show(
                current: state.current?.text.isEmpty == false ? state.current!.text : snapshot.title,
                next: state.next?.text ?? ""
            )
            saveOverlayOriginIfNeeded()
            return
        }

        if let plainText = activeLyrics?.plainText {
            let firstLine = firstDisplayLine(from: plainText)
            let secondLine = secondDisplayLine(from: plainText)
            overlayController?.show(
                current: firstLine.isEmpty ? snapshot.title : firstLine,
                next: secondLine
            )
            saveOverlayOriginIfNeeded()
            return
        }

        overlayController?.show(current: "正在查找歌词", next: "\(snapshot.artist) - \(snapshot.title)")
        saveOverlayOriginIfNeeded()
    }

    private func toggleOverlay() {
        overlayVisible.toggle()
        preferences.isOverlayVisible = overlayVisible
        try? preferencesStore.save(preferences)
        if overlayVisible {
            overlayController?.show(current: "等待 Apple Music 播放", next: "")
        } else {
            overlayController?.hide()
        }
    }

    private func toggleLock() {
        saveOverlayOriginIfNeeded(force: true)
        preferences.isLocked.toggle()
        try? preferencesStore.save(preferences)
        overlayController?.setLocked(preferences.isLocked)
        statusMenuController?.setStatus(preferences.isLocked ? "歌词已锁定" : "歌词可拖动")
    }

    private func refreshLyrics() {
        guard let snapshot = latestSnapshot else {
            statusMenuController?.setStatus("没有可刷新的曲目")
            return
        }

        activeTrackKey = nil
        activeLyrics = nil
        synchronizer = nil
        statusMenuController?.setStatus("正在刷新歌词")
        Task { await ensureLyricsLoaded(for: snapshot) }
    }

    private func openPreferences() {
        preferencesWindowController.show(preferences: preferences)
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Apple Music Lyrics"
        alert.informativeText = "轻量桌面悬浮歌词工具\n版本：\(AppVersion.display)"
        alert.runModal()
    }

    private func saveOverlayOriginIfNeeded(force: Bool = false) {
        guard (force || !preferences.isLocked),
              let origin = overlayController?.currentWindowOrigin() else {
            return
        }
        let width = overlayController?.currentWindowWidth()
        var changed = false
        if preferences.windowOrigin != origin {
            preferences.windowOrigin = origin
            changed = true
        }
        if let width, abs(preferences.overlayWidth - width) > 1 {
            preferences.overlayWidth = width
            changed = true
        }
        if changed {
            try? preferencesStore.save(preferences)
        }
    }
}

extension AppCoordinator: PreferencesWindowDelegate {
    func preferencesWindowDidSave(_ updated: LyricsPreferences) {
        var merged = updated
        if let origin = overlayController?.currentWindowOrigin() {
            merged.windowOrigin = origin
        }
        if let width = overlayController?.currentWindowWidth() {
            merged.overlayWidth = width
        }
        preferences = merged
        try? preferencesStore.save(merged)
        overlayVisible = merged.isOverlayVisible
        overlayController?.updatePreferences(merged)
        if !merged.isOverlayVisible {
            overlayController?.hide()
        }
    }

    func preferencesWindowDidRequestResetPosition() {
        preferences.windowOrigin = nil
        try? preferencesStore.save(preferences)
        overlayController?.updatePreferences(preferences)
    }

    func preferencesWindowDidRequestClearCache() {
        try? cache?.clear()
        statusMenuController?.setStatus("歌词缓存已清理")
    }
}
