import Foundation

public struct LyricsPlaybackState: Equatable, Sendable {
    public let current: LyricLine?
    public let next: LyricLine?
    public let progress: Double

    public init(current: LyricLine?, next: LyricLine?, progress: Double) {
        self.current = current
        self.next = next
        self.progress = progress
    }
}

public struct LyricsSynchronizer: Sendable {
    private let lines: [LyricLine]
    private let offset: TimeInterval

    public init(lines: [LyricLine], offset: TimeInterval = 0) {
        self.lines = lines.sorted { $0.time < $1.time }
        self.offset = offset
    }

    public func state(at position: TimeInterval) -> LyricsPlaybackState {
        guard !lines.isEmpty else {
            return LyricsPlaybackState(current: nil, next: nil, progress: 0)
        }

        let adjusted = position + offset
        let index = activeIndex(at: adjusted)

        guard let index else {
            return LyricsPlaybackState(current: nil, next: lines.first, progress: 0)
        }

        let current = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1] : nil
        return LyricsPlaybackState(
            current: current,
            next: next,
            progress: progressBetween(current: current, next: next, position: adjusted)
        )
    }

    private func activeIndex(at position: TimeInterval) -> Int? {
        var low = 0
        var high = lines.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    private func progressBetween(current: LyricLine, next: LyricLine?, position: TimeInterval) -> Double {
        guard let next, next.time > current.time else {
            return 1
        }

        let raw = (position - current.time) / (next.time - current.time)
        return min(max(raw, 0), 1)
    }
}
