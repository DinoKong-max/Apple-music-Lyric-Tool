# Apple Music Desktop Lyrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS menu bar app that detects Apple Music playback, fetches free synced lyrics, and displays a lockable desktop lyrics overlay.

**Architecture:** Use a Swift Package with a testable `AppleMusicLyricsCore` library target and an `AppleMusicLyricsApp` executable target. Core owns models, LRC parsing, synchronization, LRCLIB matching, cache, and preferences; the app target owns AppKit/SwiftUI lifecycle, menu bar, overlay window, and Apple Music scripting.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, AppKit, SwiftUI, XCTest, AppleScript via `NSAppleScript`, LRCLIB via `URLSession`.

---

## File Structure

- Create `Package.swift`: SwiftPM package with `AppleMusicLyricsCore`, `AppleMusicLyricsApp`, and tests.
- Create `Sources/AppleMusicLyricsCore/Models.swift`: shared value types and errors.
- Create `Sources/AppleMusicLyricsCore/LRCParser.swift`: parses synced LRC into timestamped lines.
- Create `Sources/AppleMusicLyricsCore/LyricsSynchronizer.swift`: maps playback position to current/next lines.
- Create `Sources/AppleMusicLyricsCore/LyricsCache.swift`: local JSON cache and stable cache keys.
- Create `Sources/AppleMusicLyricsCore/LRCLIBLyricsProvider.swift`: LRCLIB search, decoding, ranking, and result selection.
- Create `Sources/AppleMusicLyricsCore/PreferencesStore.swift`: Codable preferences model plus UserDefaults-backed store.
- Create `Sources/AppleMusicLyricsApp/main.swift`: `NSApplication` entrypoint without Dock icon.
- Create `Sources/AppleMusicLyricsApp/AppCoordinator.swift`: wires services, polling, menu, overlay, preferences.
- Create `Sources/AppleMusicLyricsApp/MusicTrackDetector.swift`: AppleScript polling and permission-aware errors.
- Create `Sources/AppleMusicLyricsApp/StatusMenuController.swift`: status item and menu actions.
- Create `Sources/AppleMusicLyricsApp/LyricsOverlayController.swift`: borderless floating/click-through window.
- Create `Sources/AppleMusicLyricsApp/LyricsOverlayView.swift`: SwiftUI current/next lyric view.
- Create `Sources/AppleMusicLyricsApp/PreferencesWindowController.swift`: hosts preferences UI.
- Create `Sources/AppleMusicLyricsApp/PreferencesView.swift`: SwiftUI settings controls.
- Create `Resources/Info.plist`: bundle metadata for packaged `.app`.
- Create `scripts/build_app.sh`: builds release binary and creates `.app`.
- Create `scripts/package_dmg.sh`: creates a versioned `.dmg`.
- Create tests under `Tests/AppleMusicLyricsCoreTests/`.

---

### Task 1: Swift Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/AppleMusicLyricsCore/Models.swift`
- Create: `Sources/AppleMusicLyricsApp/main.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/SmokeTests.swift`

- [ ] **Step 1: Write the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleMusicLyrics",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleMusicLyricsCore", targets: ["AppleMusicLyricsCore"]),
        .executable(name: "AppleMusicLyrics", targets: ["AppleMusicLyricsApp"])
    ],
    targets: [
        .target(
            name: "AppleMusicLyricsCore"
        ),
        .executableTarget(
            name: "AppleMusicLyricsApp",
            dependencies: ["AppleMusicLyricsCore"],
            path: "Sources/AppleMusicLyricsApp"
        ),
        .testTarget(
            name: "AppleMusicLyricsCoreTests",
            dependencies: ["AppleMusicLyricsCore"]
        )
    ]
)
```

- [ ] **Step 2: Add initial core models**

Create `Sources/AppleMusicLyricsCore/Models.swift`:

```swift
import Foundation

public struct TrackSnapshot: Equatable, Codable, Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval?
    public let position: TimeInterval
    public let isPlaying: Bool
    public let persistentID: String?

    public init(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval?,
        position: TimeInterval,
        isPlaying: Bool,
        persistentID: String?
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
        self.persistentID = persistentID
    }
}

public struct LyricLine: Equatable, Codable, Sendable {
    public let time: TimeInterval
    public let text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public enum LyricsSource: String, Codable, Sendable {
    case lrclib
    case localCache
    case importedLRC
}

public struct LyricsResult: Equatable, Codable, Sendable {
    public let source: LyricsSource
    public let syncedLines: [LyricLine]
    public let plainText: String?
    public let confidence: Double

    public init(source: LyricsSource, syncedLines: [LyricLine], plainText: String?, confidence: Double) {
        self.source = source
        self.syncedLines = syncedLines
        self.plainText = plainText
        self.confidence = confidence
    }
}
```

- [ ] **Step 3: Add a minimal app entrypoint**

Create `Sources/AppleMusicLyricsApp/main.swift`:

```swift
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
```

- [ ] **Step 4: Add smoke test**

Create `Tests/AppleMusicLyricsCoreTests/SmokeTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class SmokeTests: XCTestCase {
    func testTrackSnapshotStoresMetadata() {
        let snapshot = TrackSnapshot(
            title: "Yellow",
            artist: "Coldplay",
            album: "Parachutes",
            duration: 267,
            position: 33.4,
            isPlaying: true,
            persistentID: "123"
        )

        XCTAssertEqual(snapshot.title, "Yellow")
        XCTAssertEqual(snapshot.artist, "Coldplay")
        XCTAssertEqual(snapshot.album, "Parachutes")
        XCTAssertEqual(snapshot.duration, 267)
        XCTAssertTrue(snapshot.isPlaying)
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test`

Expected: `Build complete!` followed by the smoke test passing.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold swift package"
```

---

### Task 2: LRC Parser

**Files:**
- Create: `Sources/AppleMusicLyricsCore/LRCParser.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/LRCParserTests.swift`

- [ ] **Step 1: Write failing parser tests**

Create `Tests/AppleMusicLyricsCoreTests/LRCParserTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class LRCParserTests: XCTestCase {
    func testParsesMinuteSecondCentisecondTimestamps() throws {
        let parser = LRCParser()
        let lines = try parser.parse("""
        [00:33.42] Look at the stars
        [01:04.10] And it was called Yellow
        """)

        XCTAssertEqual(lines, [
            LyricLine(time: 33.42, text: "Look at the stars"),
            LyricLine(time: 64.10, text: "And it was called Yellow")
        ])
    }

    func testParsesMultipleTimestampsOnOneLine() throws {
        let parser = LRCParser()
        let lines = try parser.parse("[00:10.00][00:20.00] Repeated line")

        XCTAssertEqual(lines, [
            LyricLine(time: 10.0, text: "Repeated line"),
            LyricLine(time: 20.0, text: "Repeated line")
        ])
    }

    func testSortsLinesAndKeepsBlankLyricText() throws {
        let parser = LRCParser()
        let lines = try parser.parse("""
        [00:20.00] Second
        [00:10.00]
        [00:15.50] First
        """)

        XCTAssertEqual(lines, [
            LyricLine(time: 10.0, text: ""),
            LyricLine(time: 15.5, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])
    }

    func testIgnoresMetadataAndUntimedLines() throws {
        let parser = LRCParser()
        let lines = try parser.parse("""
        [ar:Coldplay]
        This line has no timestamp
        [00:01.00] Timed
        """)

        XCTAssertEqual(lines, [
            LyricLine(time: 1.0, text: "Timed")
        ])
    }
}
```

- [ ] **Step 2: Run failing test**

Run: `swift test --filter LRCParserTests`

Expected: FAIL because `LRCParser` is not defined.

- [ ] **Step 3: Implement parser**

Create `Sources/AppleMusicLyricsCore/LRCParser.swift`:

```swift
import Foundation

public enum LRCParserError: Error, Equatable {
    case noTimedLines
}

public struct LRCParser: Sendable {
    public init() {}

    public func parse(_ text: String) throws -> [LyricLine] {
        var parsed: [LyricLine] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let timestamps = extractTimestamps(from: line)

            guard !timestamps.isEmpty else {
                continue
            }

            let lyricText = removeTimestampPrefixes(from: line)
            for timestamp in timestamps {
                parsed.append(LyricLine(time: timestamp, text: lyricText))
            }
        }

        let sorted = parsed.sorted { lhs, rhs in
            if lhs.time == rhs.time {
                return lhs.text < rhs.text
            }
            return lhs.time < rhs.time
        }

        guard !sorted.isEmpty else {
            throw LRCParserError.noTimedLines
        }

        return sorted
    }

    private func extractTimestamps(from line: String) -> [TimeInterval] {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard
                let minuteRange = Range(match.range(at: 1), in: line),
                let secondRange = Range(match.range(at: 2), in: line),
                let minutes = Double(line[minuteRange]),
                let seconds = Double(line[secondRange])
            else {
                return nil
            }

            var fractional = 0.0
            if match.range(at: 3).location != NSNotFound,
               let fractionRange = Range(match.range(at: 3), in: line) {
                let fractionText = String(line[fractionRange])
                let padded = fractionText.padding(toLength: 3, withPad: "0", startingAt: 0)
                fractional = (Double(padded) ?? 0) / 1000.0
            }

            return minutes * 60.0 + seconds + fractional
        }
    }

    private func removeTimestampPrefixes(from line: String) -> String {
        let pattern = #"^(?:\[\d{1,2}:\d{2}(?:\.\d{1,3})?\])+"#
        return line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
```

- [ ] **Step 4: Run parser tests**

Run: `swift test --filter LRCParserTests`

Expected: all `LRCParserTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppleMusicLyricsCore/LRCParser.swift Tests/AppleMusicLyricsCoreTests/LRCParserTests.swift
git commit -m "feat: parse synced lrc lyrics"
```

---

### Task 3: Lyrics Synchronizer

**Files:**
- Create: `Sources/AppleMusicLyricsCore/LyricsSynchronizer.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/LyricsSynchronizerTests.swift`

- [ ] **Step 1: Write failing synchronizer tests**

Create `Tests/AppleMusicLyricsCoreTests/LyricsSynchronizerTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class LyricsSynchronizerTests: XCTestCase {
    private let lines = [
        LyricLine(time: 10, text: "First"),
        LyricLine(time: 20, text: "Second"),
        LyricLine(time: 35, text: "Third")
    ]

    func testReturnsNoCurrentLineBeforeFirstTimestamp() {
        let sync = LyricsSynchronizer(lines: lines)
        let state = sync.state(at: 5)

        XCTAssertNil(state.current)
        XCTAssertEqual(state.next, lines[0])
        XCTAssertEqual(state.progress, 0)
    }

    func testReturnsCurrentAndNextLineAtBoundary() {
        let sync = LyricsSynchronizer(lines: lines)
        let state = sync.state(at: 20)

        XCTAssertEqual(state.current, lines[1])
        XCTAssertEqual(state.next, lines[2])
        XCTAssertEqual(state.progress, 0)
    }

    func testComputesProgressBetweenLines() {
        let sync = LyricsSynchronizer(lines: lines)
        let state = sync.state(at: 27.5)

        XCTAssertEqual(state.current, lines[1])
        XCTAssertEqual(state.next, lines[2])
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    func testAppliesOffset() {
        let sync = LyricsSynchronizer(lines: lines, offset: 2)
        let state = sync.state(at: 18)

        XCTAssertEqual(state.current, lines[1])
    }
}
```

- [ ] **Step 2: Run failing test**

Run: `swift test --filter LyricsSynchronizerTests`

Expected: FAIL because `LyricsSynchronizer` is not defined.

- [ ] **Step 3: Implement synchronizer**

Create `Sources/AppleMusicLyricsCore/LyricsSynchronizer.swift`:

```swift
import Foundation

public struct LyricsPlaybackState: Equatable, Sendable {
    public let current: LyricLine?
    public let next: LyricLine?
    public let progress: Double

    public init(current: LyricLine?, next: LyricLine?, progress: Double) {
        self.current = current
        self.next = next
        self.progress = progress
    }
}

public struct LyricsSynchronizer: Sendable {
    private let lines: [LyricLine]
    private let offset: TimeInterval

    public init(lines: [LyricLine], offset: TimeInterval = 0) {
        self.lines = lines.sorted { $0.time < $1.time }
        self.offset = offset
    }

    public func state(at position: TimeInterval) -> LyricsPlaybackState {
        guard !lines.isEmpty else {
            return LyricsPlaybackState(current: nil, next: nil, progress: 0)
        }

        let adjusted = position + offset
        let index = activeIndex(at: adjusted)

        guard let index else {
            return LyricsPlaybackState(current: nil, next: lines.first, progress: 0)
        }

        let current = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1] : nil
        let progress = progressBetween(current: current, next: next, position: adjusted)
        return LyricsPlaybackState(current: current, next: next, progress: progress)
    }

    private func activeIndex(at position: TimeInterval) -> Int? {
        var low = 0
        var high = lines.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    private func progressBetween(current: LyricLine, next: LyricLine?, position: TimeInterval) -> Double {
        guard let next, next.time > current.time else {
            return 1
        }

        let raw = (position - current.time) / (next.time - current.time)
        return min(max(raw, 0), 1)
    }
}
```

- [ ] **Step 4: Run synchronizer tests**

Run: `swift test --filter LyricsSynchronizerTests`

Expected: all `LyricsSynchronizerTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppleMusicLyricsCore/LyricsSynchronizer.swift Tests/AppleMusicLyricsCoreTests/LyricsSynchronizerTests.swift
git commit -m "feat: sync lyrics to playback position"
```

---

### Task 4: Cache And Preferences Core

**Files:**
- Create: `Sources/AppleMusicLyricsCore/LyricsCache.swift`
- Create: `Sources/AppleMusicLyricsCore/PreferencesStore.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/LyricsCacheTests.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Write cache tests**

Create `Tests/AppleMusicLyricsCoreTests/LyricsCacheTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class LyricsCacheTests: XCTestCase {
    func testCacheKeyNormalizesTrackFields() {
        let key = LyricsCacheKey(track: TrackSnapshot(
            title: " Yellow ",
            artist: "Coldplay",
            album: "Parachutes",
            duration: 267.4,
            position: 0,
            isPlaying: true,
            persistentID: nil
        ))

        XCTAssertEqual(key.rawValue, "coldplay-yellow-parachutes-267")
    }

    func testStoresAndLoadsLyricsResult() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = LyricsCache(directory: directory)
        let key = LyricsCacheKey(rawValue: "coldplay-yellow-parachutes-267")
        let result = LyricsResult(
            source: .lrclib,
            syncedLines: [LyricLine(time: 1, text: "Line")],
            plainText: "Line",
            confidence: 0.95
        )

        try cache.store(result, for: key)
        XCTAssertEqual(try cache.load(for: key), result)
    }
}
```

- [ ] **Step 2: Write preferences tests**

Create `Tests/AppleMusicLyricsCoreTests/PreferencesStoreTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class PreferencesStoreTests: XCTestCase {
    func testDefaultPreferencesMatchMVP() {
        let preferences = LyricsPreferences.default

        XCTAssertTrue(preferences.isOverlayVisible)
        XCTAssertFalse(preferences.isLocked)
        XCTAssertEqual(preferences.fontName, "SF Pro Display")
        XCTAssertEqual(preferences.fontSize, 32)
        XCTAssertTrue(preferences.isGradientEnabled)
    }

    func testStoresPreferencesInUserDefaults() throws {
        let defaults = UserDefaults(suiteName: "PreferencesStoreTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)

        var preferences = LyricsPreferences.default
        preferences.isLocked = true
        preferences.fontSize = 40

        try store.save(preferences)
        XCTAssertEqual(try store.load(), preferences)
    }
}
```

- [ ] **Step 3: Run failing tests**

Run: `swift test --filter LyricsCacheTests && swift test --filter PreferencesStoreTests`

Expected: FAIL because cache and preferences types are not defined.

- [ ] **Step 4: Implement cache**

Create `Sources/AppleMusicLyricsCore/LyricsCache.swift`:

```swift
import Foundation

public struct LyricsCacheKey: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(track: TrackSnapshot) {
        let duration = track.duration.map { String(Int($0.rounded())) } ?? "unknown"
        self.rawValue = [
            track.artist,
            track.title,
            track.album ?? "unknown",
            duration
        ]
        .map(Self.normalize)
        .joined(separator: "-")
    }

    private static func normalize(_ value: String) -> String {
        let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        return String(allowed)
            .split(separator: "-")
            .joined(separator: "-")
    }
}

public struct LyricsCache: Sendable {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("AppleMusicLyrics/LyricsCache", isDirectory: true)
    }

    public func store(_ result: LyricsResult, for key: LyricsCacheKey) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(result)
        try data.write(to: url(for: key), options: [.atomic])
    }

    public func load(for key: LyricsCacheKey) throws -> LyricsResult? {
        let fileURL = url(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(LyricsResult.self, from: data)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.removeItem(at: directory)
    }

    private func url(for key: LyricsCacheKey) -> URL {
        directory.appendingPathComponent(key.rawValue).appendingPathExtension("json")
    }
}
```

- [ ] **Step 5: Implement preferences**

Create `Sources/AppleMusicLyricsCore/PreferencesStore.swift`:

```swift
import Foundation

public struct CodableColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct CodablePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct LyricsPreferences: Codable, Equatable, Sendable {
    public var isOverlayVisible: Bool
    public var isLocked: Bool
    public var fontName: String
    public var fontSize: Double
    public var primaryColor: CodableColor
    public var gradientStartColor: CodableColor
    public var gradientEndColor: CodableColor
    public var isGradientEnabled: Bool
    public var opacity: Double
    public var windowOrigin: CodablePoint?

    public static let `default` = LyricsPreferences(
        isOverlayVisible: true,
        isLocked: false,
        fontName: "SF Pro Display",
        fontSize: 32,
        primaryColor: CodableColor(red: 1, green: 1, blue: 1),
        gradientStartColor: CodableColor(red: 1.0, green: 0.47, blue: 0.10),
        gradientEndColor: CodableColor(red: 0.35, green: 0.48, blue: 1.0),
        isGradientEnabled: true,
        opacity: 1,
        windowOrigin: nil
    )
}

public struct PreferencesStore {
    private let defaults: UserDefaults
    private let key = "lyricsPreferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() throws -> LyricsPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        return try decoder.decode(LyricsPreferences.self, from: data)
    }

    public func save(_ preferences: LyricsPreferences) throws {
        let data = try encoder.encode(preferences)
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 6: Run cache and preferences tests**

Run: `swift test --filter LyricsCacheTests && swift test --filter PreferencesStoreTests`

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/AppleMusicLyricsCore/LyricsCache.swift Sources/AppleMusicLyricsCore/PreferencesStore.swift Tests/AppleMusicLyricsCoreTests/LyricsCacheTests.swift Tests/AppleMusicLyricsCoreTests/PreferencesStoreTests.swift
git commit -m "feat: add lyrics cache and preferences"
```

---

### Task 5: LRCLIB Provider

**Files:**
- Create: `Sources/AppleMusicLyricsCore/LRCLIBLyricsProvider.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/LRCLIBLyricsProviderTests.swift`

- [ ] **Step 1: Write provider ranking and decoding tests**

Create `Tests/AppleMusicLyricsCoreTests/LRCLIBLyricsProviderTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class LRCLIBLyricsProviderTests: XCTestCase {
    func testDecodesSearchResponse() throws {
        let data = """
        [{
          "id": 16233,
          "trackName": "Yellow",
          "artistName": "Coldplay",
          "albumName": "Parachutes",
          "duration": 267,
          "instrumental": false,
          "plainLyrics": "Look at the stars",
          "syncedLyrics": "[00:33.42] Look at the stars"
        }]
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode([LRCLIBSearchResult].self, from: data)

        XCTAssertEqual(response.first?.trackName, "Yellow")
        XCTAssertEqual(response.first?.syncedLyrics, "[00:33.42] Look at the stars")
    }

    func testRanksExactSyncedDurationMatchHighest() throws {
        let track = TrackSnapshot(
            title: "Yellow",
            artist: "Coldplay",
            album: "Parachutes",
            duration: 267,
            position: 0,
            isPlaying: true,
            persistentID: nil
        )
        let exact = LRCLIBSearchResult(id: 1, trackName: "Yellow", artistName: "Coldplay", albumName: "Parachutes", duration: 267, instrumental: false, plainLyrics: "plain", syncedLyrics: "[00:01.00] line")
        let wrongArtist = LRCLIBSearchResult(id: 2, trackName: "Yellow", artistName: "Other", albumName: "Parachutes", duration: 267, instrumental: false, plainLyrics: "plain", syncedLyrics: "[00:01.00] line")
        let plainOnly = LRCLIBSearchResult(id: 3, trackName: "Yellow", artistName: "Coldplay", albumName: "Parachutes", duration: 267, instrumental: false, plainLyrics: "plain", syncedLyrics: nil)

        let ranked = LRCLIBRanker.rank([wrongArtist, plainOnly, exact], for: track)

        XCTAssertEqual(ranked.first?.result.id, exact.id)
        XCTAssertGreaterThan(ranked[0].score, ranked[1].score)
        XCTAssertGreaterThan(ranked[1].score, ranked[2].score)
    }
}
```

- [ ] **Step 2: Run failing tests**

Run: `swift test --filter LRCLIBLyricsProviderTests`

Expected: FAIL because LRCLIB types are not defined.

- [ ] **Step 3: Implement LRCLIB provider and ranker**

Create `Sources/AppleMusicLyricsCore/LRCLIBLyricsProvider.swift`:

```swift
import Foundation

public protocol LyricsProvider: Sendable {
    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult?
}

public struct LRCLIBSearchResult: Codable, Equatable, Sendable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let albumName: String?
    public let duration: TimeInterval?
    public let instrumental: Bool
    public let plainLyrics: String?
    public let syncedLyrics: String?

    public init(
        id: Int,
        trackName: String,
        artistName: String,
        albumName: String?,
        duration: TimeInterval?,
        instrumental: Bool,
        plainLyrics: String?,
        syncedLyrics: String?
    ) {
        self.id = id
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }
}

public struct RankedLRCLIBResult: Equatable, Sendable {
    public let result: LRCLIBSearchResult
    public let score: Double
}

public enum LRCLIBRanker {
    public static func rank(_ results: [LRCLIBSearchResult], for track: TrackSnapshot) -> [RankedLRCLIBResult] {
        results
            .map { result in RankedLRCLIBResult(result: result, score: score(result, for: track)) }
            .sorted { lhs, rhs in lhs.score > rhs.score }
    }

    private static func score(_ result: LRCLIBSearchResult, for track: TrackSnapshot) -> Double {
        var score = 0.0

        if normalize(result.trackName) == normalize(track.title) {
            score += 40
        }
        if normalize(result.artistName) == normalize(track.artist) {
            score += 35
        }
        if let album = track.album, let resultAlbum = result.albumName, normalize(album) == normalize(resultAlbum) {
            score += 10
        }
        if let targetDuration = track.duration, let resultDuration = result.duration {
            let delta = abs(targetDuration - resultDuration)
            score += max(0, 10 - delta)
        }
        if result.syncedLyrics?.isEmpty == false {
            score += 20
        } else if result.plainLyrics?.isEmpty == false {
            score += 5
        }
        if result.instrumental {
            score -= 20
        }

        return score
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
    }
}

public struct LRCLIBLyricsProvider: LyricsProvider {
    private let baseURL: URL
    private let session: URLSession
    private let parser: LRCParser

    public init(baseURL: URL = URL(string: "https://lrclib.net")!, session: URLSession = .shared, parser: LRCParser = LRCParser()) {
        self.baseURL = baseURL
        self.session = session
        self.parser = parser
    }

    public func lyrics(for track: TrackSnapshot) async throws -> LyricsResult? {
        let results = try await search(track: track)
        guard let best = LRCLIBRanker.rank(results, for: track).first else {
            return nil
        }

        if let syncedLyrics = best.result.syncedLyrics, !syncedLyrics.isEmpty {
            let lines = try parser.parse(syncedLyrics)
            return LyricsResult(source: .lrclib, syncedLines: lines, plainText: best.result.plainLyrics, confidence: min(best.score / 115.0, 1.0))
        }

        if let plainLyrics = best.result.plainLyrics, !plainLyrics.isEmpty {
            return LyricsResult(source: .lrclib, syncedLines: [], plainText: plainLyrics, confidence: min(best.score / 115.0, 1.0))
        }

        return nil
    }

    private func search(track: TrackSnapshot) async throws -> [LRCLIBSearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album)
        ].filter { $0.value?.isEmpty == false }

        let requestURL = components.url!
        let (data, response) = try await session.data(from: requestURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        return try JSONDecoder().decode([LRCLIBSearchResult].self, from: data)
    }
}
```

- [ ] **Step 4: Run provider tests**

Run: `swift test --filter LRCLIBLyricsProviderTests`

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/AppleMusicLyricsCore/LRCLIBLyricsProvider.swift Tests/AppleMusicLyricsCoreTests/LRCLIBLyricsProviderTests.swift
git commit -m "feat: add lrclib lyrics provider"
```

---

### Task 6: Apple Music Track Detector

**Files:**
- Create: `Sources/AppleMusicLyricsApp/MusicTrackDetector.swift`
- Create: `Tests/AppleMusicLyricsCoreTests/AppleScriptParsingTests.swift`
- Modify: `Sources/AppleMusicLyricsCore/Models.swift`

- [ ] **Step 1: Add parser test for AppleScript output**

Create `Tests/AppleMusicLyricsCoreTests/AppleScriptParsingTests.swift`:

```swift
import XCTest
@testable import AppleMusicLyricsCore

final class AppleScriptParsingTests: XCTestCase {
    func testParsesTabSeparatedMusicSnapshot() throws {
        let parser = MusicSnapshotParser()
        let snapshot = try parser.parse("playing\tYellow\tColdplay\tParachutes\t267.0\t33.42\tABC123")

        XCTAssertEqual(snapshot.title, "Yellow")
        XCTAssertEqual(snapshot.artist, "Coldplay")
        XCTAssertEqual(snapshot.album, "Parachutes")
        XCTAssertEqual(snapshot.duration, 267)
        XCTAssertEqual(snapshot.position, 33.42)
        XCTAssertTrue(snapshot.isPlaying)
        XCTAssertEqual(snapshot.persistentID, "ABC123")
    }

    func testParsesPausedState() throws {
        let parser = MusicSnapshotParser()
        let snapshot = try parser.parse("paused\tYellow\tColdplay\t\t267.0\t33.42\t")

        XCTAssertFalse(snapshot.isPlaying)
        XCTAssertNil(snapshot.album)
        XCTAssertNil(snapshot.persistentID)
    }
}
```

- [ ] **Step 2: Add parser to core models**

Append to `Sources/AppleMusicLyricsCore/Models.swift`:

```swift
public enum MusicSnapshotParserError: Error, Equatable {
    case malformedOutput(String)
}

public struct MusicSnapshotParser: Sendable {
    public init() {}

    public func parse(_ output: String) throws -> TrackSnapshot {
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
        guard parts.count == 7 else {
            throw MusicSnapshotParserError.malformedOutput(output)
        }

        return TrackSnapshot(
            title: parts[1],
            artist: parts[2],
            album: parts[3].isEmpty ? nil : parts[3],
            duration: TimeInterval(parts[4]),
            position: TimeInterval(parts[5]) ?? 0,
            isPlaying: parts[0] == "playing",
            persistentID: parts[6].isEmpty ? nil : parts[6]
        )
    }
}
```

- [ ] **Step 3: Run parser tests**

Run: `swift test --filter AppleScriptParsingTests`

Expected: tests pass.

- [ ] **Step 4: Implement AppleScript detector**

Create `Sources/AppleMusicLyricsApp/MusicTrackDetector.swift`:

```swift
import Foundation
import AppleMusicLyricsCore

enum MusicTrackDetectorError: Error {
    case musicNotRunning
    case scriptFailed(String)
    case noDescriptor
}

final class MusicTrackDetector {
    private let parser = MusicSnapshotParser()

    func currentSnapshot() throws -> TrackSnapshot {
        let source = """
        tell application "System Events"
            set musicIsRunning to exists process "Music"
        end tell
        if musicIsRunning is false then
            return "not_running"
        end if
        tell application "Music"
            set stateText to player state as string
            set currentName to name of current track
            set currentArtist to artist of current track
            set currentAlbum to album of current track
            set currentDuration to duration of current track
            set currentPosition to player position
            try
                set currentPersistentID to persistent ID of current track
            on error
                set currentPersistentID to ""
            end try
            return stateText & tab & currentName & tab & currentArtist & tab & currentAlbum & tab & currentDuration & tab & currentPosition & tab & currentPersistentID
        end tell
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw MusicTrackDetectorError.scriptFailed("Unable to compile AppleScript")
        }
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            throw MusicTrackDetectorError.scriptFailed(error.description)
        }
        guard let output = descriptor.stringValue else {
            throw MusicTrackDetectorError.noDescriptor
        }
        if output == "not_running" {
            throw MusicTrackDetectorError.musicNotRunning
        }
        return try parser.parse(output)
    }
}
```

- [ ] **Step 5: Run all tests**

Run: `swift test`

Expected: all core tests pass. App target should build on macOS.

- [ ] **Step 6: Commit**

```bash
git add Sources/AppleMusicLyricsCore/Models.swift Sources/AppleMusicLyricsApp/MusicTrackDetector.swift Tests/AppleMusicLyricsCoreTests/AppleScriptParsingTests.swift
git commit -m "feat: detect apple music track snapshots"
```

---

### Task 7: Menu Bar App Coordinator

**Files:**
- Modify: `Sources/AppleMusicLyricsApp/main.swift`
- Create: `Sources/AppleMusicLyricsApp/AppCoordinator.swift`
- Create: `Sources/AppleMusicLyricsApp/StatusMenuController.swift`

- [ ] **Step 1: Replace bootstrap entrypoint**

Replace `Sources/AppleMusicLyricsApp/main.swift` with:

```swift
import AppKit

let app = NSApplication.shared
let coordinator = AppCoordinator()
app.delegate = coordinator
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Implement coordinator skeleton**

Create `Sources/AppleMusicLyricsApp/AppCoordinator.swift`:

```swift
import AppKit
import AppleMusicLyricsCore

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?
    private let detector = MusicTrackDetector()
    private var pollTimer: Timer?
    private var latestSnapshot: TrackSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController = StatusMenuController(
            actions: StatusMenuActions(
                toggleOverlay: { [weak self] in self?.toggleOverlay() },
                toggleLock: { [weak self] in self?.toggleLock() },
                refreshLyrics: { [weak self] in self?.refreshLyrics() },
                openPreferences: { [weak self] in self?.openPreferences() },
                quit: { NSApp.terminate(nil) }
            )
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
            latestSnapshot = try detector.currentSnapshot()
            statusMenuController?.setStatus("Apple Music 已连接")
        } catch MusicTrackDetectorError.musicNotRunning {
            latestSnapshot = nil
            statusMenuController?.setStatus("Apple Music 未运行")
        } catch {
            latestSnapshot = nil
            statusMenuController?.setStatus("需要 Music 自动化权限")
        }
    }

    private func toggleOverlay() {
        statusMenuController?.setStatus("歌词显示开关已触发")
    }

    private func toggleLock() {
        statusMenuController?.setStatus("锁定开关已触发")
    }

    private func refreshLyrics() {
        statusMenuController?.setStatus("正在刷新歌词")
    }

    private func openPreferences() {
        statusMenuController?.setStatus("偏好设置待打开")
    }
}
```

- [ ] **Step 3: Implement status menu**

Create `Sources/AppleMusicLyricsApp/StatusMenuController.swift`:

```swift
import AppKit

struct StatusMenuActions {
    let toggleOverlay: () -> Void
    let toggleLock: () -> Void
    let refreshLyrics: () -> Void
    let openPreferences: () -> Void
    let quit: () -> Void
}

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let statusItemText = NSMenuItem(title: "正在启动", action: nil, keyEquivalent: "")
    private let actions: StatusMenuActions

    init(actions: StatusMenuActions) {
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        configureMenu()
    }

    func setStatus(_ status: String) {
        statusItemText.title = status
    }

    private func configureButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Apple Music Lyrics")
        }
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(statusItemText)
        menu.addItem(.separator())
        menu.addItem(item("显示/隐藏歌词", #selector(toggleOverlay)))
        menu.addItem(item("锁定/解锁位置", #selector(toggleLock)))
        menu.addItem(item("刷新歌词", #selector(refreshLyrics)))
        menu.addItem(.separator())
        menu.addItem(item("偏好设置...", #selector(openPreferences)))
        menu.addItem(.separator())
        menu.addItem(item("退出", #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func toggleOverlay() {
        actions.toggleOverlay()
    }

    @objc private func toggleLock() {
        actions.toggleLock()
    }

    @objc private func refreshLyrics() {
        actions.refreshLyrics()
    }

    @objc private func openPreferences() {
        actions.openPreferences()
    }

    @objc private func quit() {
        actions.quit()
    }
}
```

- [ ] **Step 4: Build app target**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 5: Manual menu smoke test**

Run: `swift run AppleMusicLyrics`

Expected: a menu bar icon appears, the Dock icon is hidden, and menu items are visible. Quit from the menu after checking.

- [ ] **Step 6: Commit**

```bash
git add Sources/AppleMusicLyricsApp/main.swift Sources/AppleMusicLyricsApp/AppCoordinator.swift Sources/AppleMusicLyricsApp/StatusMenuController.swift
git commit -m "feat: add menu bar app shell"
```

---

### Task 8: Floating Lyrics Overlay

**Files:**
- Create: `Sources/AppleMusicLyricsApp/LyricsOverlayController.swift`
- Create: `Sources/AppleMusicLyricsApp/LyricsOverlayView.swift`
- Modify: `Sources/AppleMusicLyricsApp/AppCoordinator.swift`

- [ ] **Step 1: Implement overlay SwiftUI view**

Create `Sources/AppleMusicLyricsApp/LyricsOverlayView.swift`:

```swift
import SwiftUI
import AppleMusicLyricsCore

struct LyricsOverlayView: View {
    let currentLine: String
    let nextLine: String
    let preferences: LyricsPreferences

    var body: some View {
        VStack(spacing: 10) {
            lyricText(currentLine, size: preferences.fontSize, opacity: preferences.opacity)
                .fontWeight(.bold)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
            Text(nextLine)
                .font(.custom(preferences.fontName, size: max(preferences.fontSize * 0.52, 14)))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Color.clear)
    }

    @ViewBuilder
    private func lyricText(_ text: String, size: Double, opacity: Double) -> some View {
        let font = Font.custom(preferences.fontName, size: size)
        if preferences.isGradientEnabled {
            Text(text)
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(preferences.gradientStartColor),
                            Color(preferences.gradientEndColor)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(opacity)
                )
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(Color(preferences.primaryColor).opacity(opacity))
        }
    }
}

private extension Color {
    init(_ color: CodableColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}
```

- [ ] **Step 2: Implement overlay controller**

Create `Sources/AppleMusicLyricsApp/LyricsOverlayController.swift`:

```swift
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
        if let origin = preferences.windowOrigin {
            window?.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
        }
    }

    func setLocked(_ locked: Bool) {
        preferences.isLocked = locked
        window?.ignoresMouseEvents = locked
        window?.isMovableByWindowBackground = !locked
    }

    private func ensureWindow() -> NSPanel {
        if let window {
            return window
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: min(920, screenFrame.width - 80), height: 150)
        let origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.minY + 120)
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
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
```

- [ ] **Step 3: Wire overlay into coordinator**

Modify `Sources/AppleMusicLyricsApp/AppCoordinator.swift` so it owns preferences and overlay:

```swift
private let preferencesStore = PreferencesStore()
private var preferences = LyricsPreferences.default
private var overlayController: LyricsOverlayController?
private var overlayVisible = true
private var synchronizer: LyricsSynchronizer?
```

In `applicationDidFinishLaunching`, before `startPolling()`:

```swift
preferences = (try? preferencesStore.load()) ?? .default
overlayVisible = preferences.isOverlayVisible
overlayController = LyricsOverlayController(preferences: preferences)
```

Replace `toggleOverlay()` with:

```swift
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
```

Replace `toggleLock()` with:

```swift
private func toggleLock() {
    preferences.isLocked.toggle()
    try? preferencesStore.save(preferences)
    overlayController?.setLocked(preferences.isLocked)
    statusMenuController?.setStatus(preferences.isLocked ? "歌词已锁定" : "歌词可拖动")
}
```

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 5: Manual overlay test**

Run: `swift run AppleMusicLyrics`

Expected: menu item can show/hide the overlay, and lock/unlock toggles click-through behavior.

- [ ] **Step 6: Commit**

```bash
git add Sources/AppleMusicLyricsApp/LyricsOverlayController.swift Sources/AppleMusicLyricsApp/LyricsOverlayView.swift Sources/AppleMusicLyricsApp/AppCoordinator.swift
git commit -m "feat: add floating lyrics overlay"
```

---

### Task 9: Lyrics Fetching And Playback Sync Wiring

**Files:**
- Modify: `Sources/AppleMusicLyricsApp/AppCoordinator.swift`

- [ ] **Step 1: Add provider, cache, and state properties**

Add to `AppCoordinator`:

```swift
private let provider = LRCLIBLyricsProvider()
private var cache: LyricsCache?
private var activeTrackKey: LyricsCacheKey?
private var activeLyrics: LyricsResult?
```

In `applicationDidFinishLaunching`, after loading preferences:

```swift
if let cacheDirectory = try? LyricsCache.defaultDirectory() {
    cache = LyricsCache(directory: cacheDirectory)
}
```

- [ ] **Step 2: Replace polling body with track and lyric sync**

Replace `pollMusic()` with:

```swift
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
```

- [ ] **Step 3: Add lyric loading method**

Add to `AppCoordinator`:

```swift
private func ensureLyricsLoaded(for snapshot: TrackSnapshot) async {
    let key = LyricsCacheKey(track: snapshot)
    guard key != activeTrackKey else {
        return
    }

    activeTrackKey = key

    if let cached = try? cache?.load(for: key), let cached {
        activeLyrics = cached
        synchronizer = LyricsSynchronizer(lines: cached.syncedLines)
        return
    }

    do {
        if let result = try await provider.lyrics(for: snapshot) {
            activeLyrics = result
            synchronizer = LyricsSynchronizer(lines: result.syncedLines)
            try? cache?.store(result, for: key)
        } else {
            activeLyrics = nil
            synchronizer = nil
        }
    } catch {
        activeLyrics = nil
        synchronizer = nil
    }
}
```

- [ ] **Step 4: Add overlay update method**

Add to `AppCoordinator`:

```swift
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
        return
    }

    if let plainText = activeLyrics?.plainText {
        let firstLine = plainText.split(separator: "\n").first.map(String.init) ?? snapshot.title
        overlayController?.show(current: firstLine, next: "未找到同步歌词")
        return
    }

    overlayController?.show(current: "正在查找歌词", next: "\(snapshot.artist) - \(snapshot.title)")
}
```

- [ ] **Step 5: Implement refresh action**

Replace `refreshLyrics()` with:

```swift
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
```

- [ ] **Step 6: Build and run tests**

Run: `swift test && swift build`

Expected: tests and build pass.

- [ ] **Step 7: Manual end-to-end check**

Run: `swift run AppleMusicLyrics`, start a known Apple Music track such as "Yellow" by Coldplay, and confirm the overlay changes from "正在查找歌词" to synced lyric text if LRCLIB returns a match.

- [ ] **Step 8: Commit**

```bash
git add Sources/AppleMusicLyricsApp/AppCoordinator.swift
git commit -m "feat: sync apple music playback with lyrics"
```

---

### Task 10: Preferences Window

**Files:**
- Create: `Sources/AppleMusicLyricsApp/PreferencesWindowController.swift`
- Create: `Sources/AppleMusicLyricsApp/PreferencesView.swift`
- Modify: `Sources/AppleMusicLyricsApp/AppCoordinator.swift`

- [ ] **Step 1: Implement preferences SwiftUI view**

Create `Sources/AppleMusicLyricsApp/PreferencesView.swift`:

```swift
import SwiftUI
import AppleMusicLyricsCore

struct PreferencesView: View {
    @State var preferences: LyricsPreferences
    let onSave: (LyricsPreferences) -> Void
    let onResetPosition: () -> Void
    let onClearCache: () -> Void

    var body: some View {
        Form {
            Toggle("显示歌词", isOn: binding(\.isOverlayVisible))
            Toggle("锁定位置", isOn: binding(\.isLocked))

            Picker("字体", selection: binding(\.fontName)) {
                Text("SF Pro Display").tag("SF Pro Display")
                Text("PingFang SC").tag("PingFang SC")
                Text("Helvetica Neue").tag("Helvetica Neue")
                Text("Avenir Next").tag("Avenir Next")
            }

            Slider(value: binding(\.fontSize), in: 18...64, step: 1) {
                Text("字号")
            }
            Slider(value: binding(\.opacity), in: 0.35...1, step: 0.05) {
                Text("透明度")
            }

            Toggle("启用渐变", isOn: binding(\.isGradientEnabled))

            HStack {
                Button("重置位置") {
                    onResetPosition()
                }
                Button("清理缓存") {
                    onClearCache()
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LyricsPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { newValue in
                preferences[keyPath: keyPath] = newValue
                onSave(preferences)
            }
        )
    }
}
```

- [ ] **Step 2: Implement window controller**

Create `Sources/AppleMusicLyricsApp/PreferencesWindowController.swift`:

```swift
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
```

- [ ] **Step 3: Wire preferences into coordinator**

Add property to `AppCoordinator`:

```swift
private let preferencesWindowController = PreferencesWindowController()
```

Replace `openPreferences()`:

```swift
private func openPreferences() {
    preferencesWindowController.show(
        preferences: preferences,
        onSave: { [weak self] updated in
            guard let self else { return }
            self.preferences = updated
            try? self.preferencesStore.save(updated)
            self.overlayVisible = updated.isOverlayVisible
            self.overlayController?.updatePreferences(updated)
            if !updated.isOverlayVisible {
                self.overlayController?.hide()
            }
        },
        onResetPosition: { [weak self] in
            guard let self else { return }
            self.preferences.windowOrigin = nil
            try? self.preferencesStore.save(self.preferences)
            self.overlayController?.updatePreferences(self.preferences)
        },
        onClearCache: { [weak self] in
            try? self?.cache?.clear()
            self?.statusMenuController?.setStatus("歌词缓存已清理")
        }
    )
}
```

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 5: Manual preferences test**

Run: `swift run AppleMusicLyrics`, open Preferences from the menu, adjust font size/opacity/lock, close and reopen app, and confirm settings persist.

- [ ] **Step 6: Commit**

```bash
git add Sources/AppleMusicLyricsApp/PreferencesWindowController.swift Sources/AppleMusicLyricsApp/PreferencesView.swift Sources/AppleMusicLyricsApp/AppCoordinator.swift
git commit -m "feat: add preferences window"
```

---

### Task 11: App Bundle And DMG Packaging

**Files:**
- Create: `Resources/Info.plist`
- Create: `scripts/build_app.sh`
- Create: `scripts/package_dmg.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Add Info.plist**

Create `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>AppleMusicLyrics</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.applemusiclyrics</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Apple Music Lyrics</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>需要读取 Apple Music 当前播放歌曲，用于匹配并显示桌面同步歌词。</string>
</dict>
</plist>
```

- [ ] **Step 2: Add app build script**

Create `scripts/build_app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Apple Music Lyrics"
BINARY_NAME="AppleMusicLyrics"
VERSION="0.1.0"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$BINARY_NAME" "$MACOS_DIR/$BINARY_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"

echo "Built $APP_DIR"
```

- [ ] **Step 3: Add DMG packaging script**

Create `scripts/package_dmg.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Apple Music Lyrics"
VERSION="0.1.0"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/AppleMusicLyrics-$VERSION.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"

"$ROOT_DIR/scripts/build_app.sh"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Packaged $DMG_PATH"
```

- [ ] **Step 4: Make scripts executable and ignore dist**

Run:

```bash
chmod +x scripts/build_app.sh scripts/package_dmg.sh
```

Append to `.gitignore`:

```gitignore
dist/
```

- [ ] **Step 5: Build app bundle**

Run: `scripts/build_app.sh`

Expected: `dist/Apple Music Lyrics.app` exists and contains `Contents/MacOS/AppleMusicLyrics`.

- [ ] **Step 6: Package DMG**

Run: `scripts/package_dmg.sh`

Expected: `dist/AppleMusicLyrics-0.1.0.dmg` exists.

- [ ] **Step 7: Commit**

```bash
git add Resources/Info.plist scripts/build_app.sh scripts/package_dmg.sh .gitignore
git commit -m "build: add app and dmg packaging"
```

---

### Task 12: Final Verification And Release Notes

**Files:**
- Create: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Add README**

Create `README.md`:

```markdown
# Apple Music Lyrics

Apple Music Lyrics 是一个轻量 macOS 菜单栏应用，用于给 Apple Music 当前播放歌曲显示桌面悬浮同步歌词。

## 功能

- Apple Music 当前曲目识别
- LRCLIB 免费同步歌词匹配
- 桌面悬浮歌词窗口
- 锁定后点击穿透
- 字体、字号、颜色、渐变、透明度设置
- 歌词缓存
- `.app` 和 `.dmg` 打包

## 开发

```bash
swift test
swift run AppleMusicLyrics
```

## 打包

```bash
scripts/build_app.sh
scripts/package_dmg.sh
```

## 权限

首次读取 Apple Music 当前播放信息时，macOS 可能会要求授权自动化权限。请允许本应用访问 Music，否则无法识别当前播放歌曲。
```

- [ ] **Step 2: Add changelog**

Create `CHANGELOG.md`:

```markdown
# Changelog

## 0.1.0

- Added native macOS menu bar app shell.
- Added Apple Music track detection through AppleScript.
- Added LRCLIB synced lyrics lookup.
- Added LRC parser and playback synchronizer.
- Added floating desktop lyrics overlay with lock/click-through behavior.
- Added preferences for visibility, lock state, font, size, gradient, and opacity.
- Added local lyrics cache.
- Added `.app` and `.dmg` packaging scripts.
```

- [ ] **Step 3: Run full automated verification**

Run:

```bash
swift test
swift build
scripts/build_app.sh
```

Expected: all tests pass, app builds, and `dist/Apple Music Lyrics.app` is created.

- [ ] **Step 4: Run manual verification checklist**

Run: `swift run AppleMusicLyrics`

Check:

- Menu bar icon appears and no Dock icon appears.
- Menu has show/hide, lock/unlock, refresh, preferences, quit.
- Apple Music playing track updates status within about one second.
- Lyrics appear for a known LRCLIB track.
- Pausing Apple Music stops lyric advancement.
- Lock mode allows clicks through the overlay.
- Preferences persist after relaunch.

- [ ] **Step 5: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: add usage and release notes"
```

---

## Self-Review

- Spec coverage: the plan covers Apple Music detection, LRCLIB lookup, LRC parsing, lyric sync, overlay lock/drag behavior, menu bar controls, preferences, cache, versioned app packaging, and DMG creation.
- Empty-slot scan: no blank implementation steps or undefined follow-up instructions are present.
- Type consistency: model names match across tasks: `TrackSnapshot`, `LyricLine`, `LyricsResult`, `LyricsSource`, `LyricsSynchronizer`, `LyricsCache`, `LyricsPreferences`.
- Risk note: final signing, notarization, and Sparkle update support are intentionally outside MVP and are not needed for local `.app`/`.dmg` sharing.
