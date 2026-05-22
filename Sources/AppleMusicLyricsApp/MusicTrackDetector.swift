import AppKit
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

    func currentTrackLyrics() -> String? {
        let source = """
        tell application "System Events"
            set musicIsRunning to exists process "Music"
        end tell
        if musicIsRunning is false then
            return ""
        end if
        tell application "Music"
            try
                return lyrics of current track
            on error
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        let descriptor = script.executeAndReturnError(&error)
        if error != nil {
            return nil
        }

        let text = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}
