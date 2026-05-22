import Foundation

public enum MusicSnapshotParserError: Error, Equatable {
    case malformedOutput(String)
}

public struct MusicSnapshotParser: Sendable {
    public init() {}

    public func parse(_ output: String) throws -> TrackSnapshot {
        let parts = output.trimmingCharacters(in: .newlines).components(separatedBy: "\t")
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
