import Foundation
import Testing
@testable import AppleMusicLyricsCore

@Test func cacheKeyNormalizesTrackFields() {
    let key = LyricsCacheKey(track: TrackSnapshot(
        title: " Yellow ",
        artist: "Coldplay",
        album: "Parachutes",
        duration: 267.4,
        position: 0,
        isPlaying: true,
        persistentID: nil
    ))

    #expect(key.rawValue == "coldplay-yellow-parachutes-267")
}

@Test func storesAndLoadsLyricsResult() throws {
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
    #expect(try cache.load(for: key) == result)
}
