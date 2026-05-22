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
    case appleMusic
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
