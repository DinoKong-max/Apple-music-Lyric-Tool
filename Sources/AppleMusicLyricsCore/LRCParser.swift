import Foundation

public enum LRCParserError: Error, Equatable {
    case noTimedLines
}

public struct LRCParser: Sendable {
    public init() {}

    public func parse(_ text: String) throws -> [LyricLine] {
        var parsed: [LyricLine] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let timestamps = extractTimestamps(from: line)
            guard !timestamps.isEmpty else {
                continue
            }

            let lyricText = removeTimestampPrefixes(from: line)
                .trimmingCharacters(in: .whitespaces)
            for timestamp in timestamps {
                parsed.append(LyricLine(time: timestamp, text: lyricText))
            }
        }

        let sorted = parsed.sorted { lhs, rhs in
            if lhs.time == rhs.time {
                return lhs.text < rhs.text
            }
            return lhs.time < rhs.time
        }

        guard !sorted.isEmpty else {
            throw LRCParserError.noTimedLines
        }

        return sorted
    }

    private func extractTimestamps(from line: String) -> [TimeInterval] {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard
                let minuteRange = Range(match.range(at: 1), in: line),
                let secondRange = Range(match.range(at: 2), in: line),
                let minutes = Double(line[minuteRange]),
                let seconds = Double(line[secondRange])
            else {
                return nil
            }

            var fractional = 0.0
            if match.range(at: 3).location != NSNotFound,
               let fractionRange = Range(match.range(at: 3), in: line) {
                let fractionText = String(line[fractionRange])
                let padded = fractionText.padding(toLength: 3, withPad: "0", startingAt: 0)
                fractional = (Double(padded) ?? 0.0) / 1000.0
            }

            return minutes * 60.0 + seconds + fractional
        }
    }

    private func removeTimestampPrefixes(from line: String) -> String {
        let pattern = #"^(?:\[\d{1,2}:\d{2}(?:\.\d{1,3})?\])+"#
        return line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
