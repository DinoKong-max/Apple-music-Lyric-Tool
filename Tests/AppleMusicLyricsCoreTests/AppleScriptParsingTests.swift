import Testing
@testable import AppleMusicLyricsCore

@Test func parsesTabSeparatedMusicSnapshot() throws {
    let parser = MusicSnapshotParser()
    let snapshot = try parser.parse("playing\tYellow\tColdplay\tParachutes\t267.0\t33.42\tABC123")

    #expect(snapshot.title == "Yellow")
    #expect(snapshot.artist == "Coldplay")
    #expect(snapshot.album == "Parachutes")
    #expect(snapshot.duration == 267)
    #expect(snapshot.position == 33.42)
    #expect(snapshot.isPlaying)
    #expect(snapshot.persistentID == "ABC123")
}

@Test func parsesPausedState() throws {
    let parser = MusicSnapshotParser()
    let snapshot = try parser.parse("paused\tYellow\tColdplay\t\t267.0\t33.42\t")

    #expect(!snapshot.isPlaying)
    #expect(snapshot.album == nil)
    #expect(snapshot.persistentID == nil)
}
