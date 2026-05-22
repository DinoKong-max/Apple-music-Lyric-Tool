import Testing
@testable import AppleMusicLyricsCore

@Test func parsesMinuteSecondCentisecondTimestamps() throws {
    let parser = LRCParser()
    let lines = try parser.parse("""
    [00:33.42] Look at the stars
    [01:04.10] And it was called Yellow
    """)

    #expect(lines == [
        LyricLine(time: 33.42, text: "Look at the stars"),
        LyricLine(time: 64.10, text: "And it was called Yellow")
    ])
}

@Test func parsesMultipleTimestampsOnOneLine() throws {
    let parser = LRCParser()
    let lines = try parser.parse("[00:10.00][00:20.00] Repeated line")

    #expect(lines == [
        LyricLine(time: 10.0, text: "Repeated line"),
        LyricLine(time: 20.0, text: "Repeated line")
    ])
}

@Test func sortsLinesAndKeepsBlankLyricText() throws {
    let parser = LRCParser()
    let lines = try parser.parse("""
    [00:20.00] Second
    [00:10.00]
    [00:15.50] First
    """)

    #expect(lines == [
        LyricLine(time: 10.0, text: ""),
        LyricLine(time: 15.5, text: "First"),
        LyricLine(time: 20.0, text: "Second")
    ])
}

@Test func ignoresMetadataAndUntimedLines() throws {
    let parser = LRCParser()
    let lines = try parser.parse("""
    [ar:Coldplay]
    This line has no timestamp
    [00:01.00] Timed
    """)

    #expect(lines == [
        LyricLine(time: 1.0, text: "Timed")
    ])
}
