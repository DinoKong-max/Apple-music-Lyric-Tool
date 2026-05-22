import Foundation
import Testing
@testable import AppleMusicLyricsCore

@Test func decodesSearchResponse() throws {
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
    #expect(response.first?.trackName == "Yellow")
    #expect(response.first?.syncedLyrics == "[00:33.42] Look at the stars")
}

@Test func ranksExactSyncedDurationMatchHighest() {
    let track = TrackSnapshot(
        title: "Yellow",
        artist: "Coldplay",
        album: "Parachutes",
        duration: 267,
        position: 0,
        isPlaying: true,
        persistentID: nil
    )
    let exact = LRCLIBSearchResult(
        id: 1,
        trackName: "Yellow",
        artistName: "Coldplay",
        albumName: "Parachutes",
        duration: 267,
        instrumental: false,
        plainLyrics: "plain",
        syncedLyrics: "[00:01.00] line"
    )
    let wrongArtist = LRCLIBSearchResult(
        id: 2,
        trackName: "Yellow",
        artistName: "Other",
        albumName: "Parachutes",
        duration: 267,
        instrumental: false,
        plainLyrics: "plain",
        syncedLyrics: "[00:01.00] line"
    )
    let plainOnly = LRCLIBSearchResult(
        id: 3,
        trackName: "Yellow",
        artistName: "Coldplay",
        albumName: "Parachutes",
        duration: 267,
        instrumental: false,
        plainLyrics: "plain",
        syncedLyrics: nil
    )

    let ranked = LRCLIBRanker.rank([wrongArtist, plainOnly, exact], for: track)

    #expect(ranked.first?.result.id == exact.id)
    #expect(ranked[0].score > ranked[1].score)
    #expect(ranked[1].score > ranked[2].score)
}
