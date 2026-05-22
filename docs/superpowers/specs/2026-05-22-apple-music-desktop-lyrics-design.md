# Apple Music Desktop Lyrics Design

## Goal

Build a lightweight macOS menu bar app that shows synced desktop lyrics for the currently playing Apple Music track. The first shippable version should feel native, start quickly, and provide the core controls users expect from desktop lyrics: show/hide, lock/unlock, drag positioning, color/font customization, and quit.

## Product Scope

### MVP

- Detect the current Apple Music track with title, artist, album, duration, playback state, and playback position.
- Match synced lyrics from a free online lyrics source, starting with LRCLIB.
- Render a floating desktop lyrics window with current and next line display.
- Support two interaction modes:
  - Unlocked: window floats above normal windows and can be dragged.
  - Locked: window ignores mouse events so clicks pass through to content behind it.
- Provide a status bar icon with show/hide lyrics, lock/unlock, preferences, refresh lyrics, and quit.
- Provide a compact preferences window for font, lyric color, gradient colors, opacity, and window position reset.
- Cache matched lyrics locally to reduce network use and improve startup behavior.
- Package the app as a versioned `.app` and distributable `.dmg`.

### Out of Scope for MVP

- Word-by-word karaoke timing. LRCLIB generally provides line-level synced LRC.
- Paid lyrics providers.
- App Store distribution.
- Cross-platform support.
- Reading official Apple Music lyrics from private APIs. This is not treated as a stable MVP dependency.

## Technical Approach

### Recommended Stack

- Swift 6 with AppKit and SwiftUI.
- `NSStatusItem` for the menu bar icon.
- `NSPanel` or borderless `NSWindow` for the floating lyrics overlay.
- `UserDefaults` for user preferences.
- Local file cache under `Application Support`.
- `URLSession` for lyrics API calls.
- Swift Package Manager as the initial project format, with packaging scripts for `.app` and `.dmg`.

This keeps the app smaller and more native than Electron. It also maps cleanly to macOS features such as click-through windows, status items, system fonts, color pickers, and app sandbox/permission messaging.

## Track Detection

Use a two-layer detector:

1. AppleScript polling every 0.5-1.0 seconds to read Music app state:
   - player state
   - player position
   - current track name
   - artist
   - album
   - duration
   - persistent ID when available

2. Distributed notification observation for faster updates when Apple Music changes playback state or track. Apple Music has historically emitted player info notifications, but notification payload stability is not guaranteed, so polling remains the source of truth.

Expected permissions:

- macOS may ask for Automation permission when the app sends Apple Events to Music.
- If process detection or click-through setup needs broader access on the user's machine, the app should show a clear permission help screen instead of silently failing.

Failure behavior:

- If Music is not running: show "Apple Music 未运行" only in the settings/status menu, hide overlay by default.
- If Music is paused: keep the current lyric line visible but stop advancing.
- If metadata is incomplete: search with the fields available and lower the match confidence.
- If AppleScript access is denied: menu bar item shows a warning state and preferences displays repair steps.

## Lyrics Source Strategy

Primary free source: LRCLIB.

- Use `GET /api/search` with `track_name`, `artist_name`, `album_name`, and duration when available.
- Prefer results with `syncedLyrics`.
- Rank candidates by exact normalized title/artist match, duration closeness, album match, and synced lyrics availability.
- Cache the selected result by a stable key derived from track title, artist, album, and rounded duration.

Fallbacks:

1. Local cached lyrics from previous successful match.
2. User-imported `.lrc` file for the current track.
3. Plain lyrics display if synced lyrics are unavailable.
4. Ask the user before adding a paid API provider.

Apple Music official APIs are not the primary route. Apple's MusicKit documentation describes catalog, library, playback, recommendations, and user music data APIs, but does not present public lyrics retrieval as a stable feature for this use case. The app should not depend on private Apple endpoints.

References:

- LRCLIB API and service: https://lrclib.net
- Apple Music / MusicKit overview: https://developer.apple.com/musickit/

## Lyrics Sync Model

Parse LRC into timestamped lines:

```swift
struct LyricLine: Equatable {
    let time: TimeInterval
    let text: String
}
```

At each playback tick:

- Read playback position from the track detector.
- Binary-search the active line by timestamp.
- Publish `currentLine`, `nextLine`, and progress to the overlay view model.
- Apply a small configurable offset internally, defaulting to `0.0` seconds. Offset UI can be added after MVP if real-world matching shows frequent drift.

## UI Design

### Floating Lyrics Window

Visual direction:

- Borderless transparent overlay.
- Large centered current lyric line.
- Smaller next lyric line below it.
- Optional subtle text shadow for readability.
- Gradient-filled text option using two or three user-selected colors.
- No heavy chrome, cards, or decorative backgrounds.

Window behavior:

- Unlocked mode:
  - Floating level above standard windows.
  - Mouse accepts drag.
  - Cursor indicates movement on hover.

- Locked mode:
  - `ignoresMouseEvents = true`.
  - Window remains visible but cannot be dragged.
  - Clicks pass through to apps behind it.

### Menu Bar

Menu entries:

- Show/Hide Lyrics
- Lock/Unlock Position
- Refresh Lyrics
- Preferences...
- About
- Quit

Menu icon:

- Use an SF Symbol-style glyph such as music note plus text lines.
- Show a warning variant when permissions or lyrics lookup fail.

### Preferences

Keep preferences in a compact native SwiftUI window:

- Lyrics toggle.
- Lock toggle.
- Font picker using macOS font panel or a focused font menu.
- Current line color.
- Gradient enable toggle.
- Gradient start/end colors.
- Text size slider.
- Opacity slider.
- Reset position button.
- Cache clear button.

The interface should follow Apple-style spacing, native controls, restrained color, and clear labels.

## Architecture

### Modules

- `AppCoordinator`: starts services, owns app lifecycle, wires menu and windows.
- `MusicTrackDetector`: reads Apple Music state and emits `TrackSnapshot`.
- `LyricsProvider`: protocol for lyrics lookup.
- `LRCLIBLyricsProvider`: free online lyrics implementation.
- `LyricsCache`: stores and retrieves cached lyrics.
- `LRCParser`: parses synced LRC text into `LyricLine` values.
- `LyricsSynchronizer`: maps playback position to current/next lyric lines.
- `LyricsOverlayController`: owns the floating window and lock/drag behavior.
- `PreferencesStore`: persists settings.
- `StatusMenuController`: builds menu bar controls.

### Core Models

```swift
struct TrackSnapshot: Equatable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
    let position: TimeInterval
    let isPlaying: Bool
    let persistentID: String?
}

struct LyricsResult: Equatable {
    let source: LyricsSource
    let syncedLines: [LyricLine]
    let plainText: String?
    let confidence: Double
}

enum LyricsSource: String, Codable {
    case lrclib
    case localCache
    case importedLRC
}
```

## Packaging And Versioning

- Use SemVer, starting at `0.1.0`.
- Store app version in one source of truth used by the bundle metadata and release scripts.
- Build `.app` locally first.
- Package `.dmg` for sharing.
- Keep notarization and Sparkle auto-update support as post-MVP tasks, because they require Apple Developer account setup and signing decisions.

## Testing Strategy

- Unit test LRC parsing with multiple timestamp formats.
- Unit test candidate ranking for LRCLIB search results.
- Unit test lyric synchronization around boundary timestamps.
- Unit test cache key generation and cache round-trip.
- Manual test Apple Music detection on a local Mac because it depends on the user's app permissions and installed Music app behavior.
- Manual visual QA for locked/unlocked window behavior.

## Risks And Mitigations

- Apple Music scripting access can be denied by macOS permissions.
  - Mitigation: visible status warning and repair instructions.

- Free lyrics matching may be imperfect.
  - Mitigation: duration-aware ranking, cache, refresh command, and local `.lrc` fallback.

- Apple Music official lyrics are not publicly exposed for this desktop overlay use case.
  - Mitigation: avoid private APIs in MVP; consider paid licensed APIs only after testing free matching quality.

- Packaging without full Xcode may be limited in this environment.
  - Mitigation: build a SwiftPM-first app structure, then document Xcode/notarization requirements for release builds.

## Acceptance Criteria

- Launching the app creates a menu bar icon and no Dock icon.
- When Apple Music plays a track, the app detects metadata and position within about one second.
- A matching LRCLIB synced lyric displays in the floating window.
- Current lyric advances while playback continues and pauses when playback pauses.
- The menu can show/hide lyrics, lock/unlock the overlay, open preferences, refresh lyrics, and quit.
- Locked overlay does not intercept clicks.
- Preferences persist across app launches.
- A versioned app bundle can be built and packaged for local sharing.

