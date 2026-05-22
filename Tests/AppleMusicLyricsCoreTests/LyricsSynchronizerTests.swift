import Testing
@testable import AppleMusicLyricsCore

private let sampleLines = [
    LyricLine(time: 10, text: "First"),
    LyricLine(time: 20, text: "Second"),
    LyricLine(time: 35, text: "Third")
]

@Test func returnsNoCurrentLineBeforeFirstTimestamp() {
    let sync = LyricsSynchronizer(lines: sampleLines)
    let state = sync.state(at: 5)

    #expect(state.current == nil)
    #expect(state.next == sampleLines[0])
    #expect(state.progress == 0)
}

@Test func returnsCurrentAndNextLineAtBoundary() {
    let sync = LyricsSynchronizer(lines: sampleLines)
    let state = sync.state(at: 20)

    #expect(state.current == sampleLines[1])
    #expect(state.next == sampleLines[2])
    #expect(state.progress == 0)
}

@Test func computesProgressBetweenLines() {
    let sync = LyricsSynchronizer(lines: sampleLines)
    let state = sync.state(at: 27.5)

    #expect(state.current == sampleLines[1])
    #expect(state.next == sampleLines[2])
    #expect(abs(state.progress - 0.5) < 0.001)
}

@Test func appliesOffset() {
    let sync = LyricsSynchronizer(lines: sampleLines, offset: 2)
    let state = sync.state(at: 18)

    #expect(state.current == sampleLines[1])
}
