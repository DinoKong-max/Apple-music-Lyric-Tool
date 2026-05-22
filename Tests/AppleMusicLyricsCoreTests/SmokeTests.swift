import Testing
@testable import AppleMusicLyricsCore

@Test func trackSnapshotStoresMetadata() {
    let snapshot = TrackSnapshot(
        title: "Yellow",
        artist: "Coldplay",
        album: "Parachutes",
        duration: 267,
        position: 33.4,
        isPlaying: true,
        persistentID: "123"
    )

    #expect(snapshot.title == "Yellow")
    #expect(snapshot.artist == "Coldplay")
    #expect(snapshot.album == "Parachutes")
    #expect(snapshot.duration == 267)
    #expect(snapshot.isPlaying)
}
