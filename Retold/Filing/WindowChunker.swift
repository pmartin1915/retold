import Foundation

/// Counts model tokens in a piece of text. The production implementation reads the SDK's
/// measured count on the device (PLAN section 6.3 item 1: measure, never estimate from elapsed
/// time); tests use a deterministic one.
protocol TokenCounter: Sendable {
    func count(_ text: String) -> Int
}

/// One token per whitespace-separated word. Deterministic; for tests and the no-SDK path only.
struct WordTokenCounter: TokenCounter {
    func count(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }
}

/// Splits a transcript into overlapping windows at segment boundaries (PLAN section 6.3 items 2-3).
enum WindowChunker {
    /// Greedy windows of at most `maxTokens` (a single segment larger than that gets its own
    /// window rather than being cut), each starting inside the previous window's tail so that
    /// about `overlapTokens` of context repeat. Every window starts at least one segment after the
    /// previous start, so this always terminates and covers every segment.
    static func windows(
        of transcript: CompletedTranscript,
        maxTokens: Int,
        overlapTokens: Int,
        counter: some TokenCounter
    ) -> [TranscriptWindow] {
        let segments = transcript.segments
        let counts = segments.map { counter.count($0.text) }
        var windows: [TranscriptWindow] = []
        var start = 0
        while start < segments.count {
            var end = start
            var total = 0
            while end < segments.count {
                if end > start && total + counts[end] > maxTokens { break }
                total += counts[end]
                end += 1
            }
            windows.append(transcript.window(start..<end))
            if end >= segments.count { break }

            var next = end
            var overlap = 0
            while next > start + 1 {
                // Stop at the overlap budget, and also when the tail plus the next segment
                // would no longer fit (a window must always reach a segment it has not seen).
                if overlap + counts[next - 1] > overlapTokens { break }
                if overlap + counts[next - 1] + counts[end] > maxTokens { break }
                overlap += counts[next - 1]
                next -= 1
            }
            start = next
        }
        return windows
    }
}
