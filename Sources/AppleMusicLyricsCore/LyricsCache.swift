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
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
