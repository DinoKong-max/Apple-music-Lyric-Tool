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
            .map { RankedLRCLIBResult(result: $0, score: score($0, for: track)) }
            .sorted { $0.score > $1.score }
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

    public init(
        baseURL: URL = URL(string: "https://lrclib.net")!,
        session: URLSession = .shared,
        parser: LRCParser = LRCParser()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.parser = parser
    }

    public func lyrics(for track: TrackSnapshot) async throws -> LyricsResult? {
        if let direct = try await fetchDirect(track: track) {
            return direct
        }

        let results = try await search(track: track)
        let fallbackResults = results.isEmpty ? (try await searchByQuery(track: track)) : []
        let candidates = results + fallbackResults
        guard let best = LRCLIBRanker.rank(candidates, for: track).first else {
            return nil
        }

        if let synced = best.result.syncedLyrics, !synced.isEmpty {
            let lines = try parser.parse(synced)
            return LyricsResult(
                source: .lrclib,
                syncedLines: lines,
                plainText: best.result.plainLyrics,
                confidence: min(best.score / 115.0, 1.0)
            )
        }

        if let plain = best.result.plainLyrics, !plain.isEmpty {
            return LyricsResult(
                source: .lrclib,
                syncedLines: [],
                plainText: plain,
                confidence: min(best.score / 115.0, 1.0)
            )
        }

        return nil
    }

    private func search(track: TrackSnapshot) async throws -> [LRCLIBSearchResult] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/search"),
            resolvingAgainstBaseURL: false
        )!
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

    private func searchByQuery(track: TrackSnapshot) async throws -> [LRCLIBSearchResult] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/search"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.title) \(track.artist)")
        ]

        let requestURL = components.url!
        let (data, response) = try await session.data(from: requestURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }

        return try JSONDecoder().decode([LRCLIBSearchResult].self, from: data)
    }

    private func fetchDirect(track: TrackSnapshot) async throws -> LyricsResult? {
        guard let duration = track.duration else {
            return nil
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/get"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album ?? ""),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded())))
        ]

        let requestURL = components.url!
        let (data, response) = try await session.data(from: requestURL)
        guard let http = response as? HTTPURLResponse else {
            return nil
        }
        guard http.statusCode == 200 else {
            return nil
        }

        let record = try JSONDecoder().decode(LRCLIBSearchResult.self, from: data)
        if let synced = record.syncedLyrics, !synced.isEmpty {
            let lines = try parser.parse(synced)
            return LyricsResult(source: .lrclib, syncedLines: lines, plainText: record.plainLyrics, confidence: 0.98)
        }
        if let plain = record.plainLyrics, !plain.isEmpty {
            return LyricsResult(source: .lrclib, syncedLines: [], plainText: plain, confidence: 0.8)
        }
        return nil
    }
}
