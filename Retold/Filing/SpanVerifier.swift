import Foundation

/// An exact transcript quotation with its audio range (PLAN section 5.1 item 3).
///
/// Rule 1 depends on "verified" meaning verified, so the designated initializer is
/// `fileprivate`: the only production producer is `SpanVerifier.verify` below, in this file.
/// (Decoding a stored span uses the synthesized `init(from:)`, which is how persistence works.)
/// Tests build spans with `VerifiedSpan.fixture`, which exists only in Debug builds.
struct VerifiedSpan: Codable, Hashable, Sendable {
    let text: String
    let captureID: UUID
    let start: TimeInterval
    let end: TimeInterval

    /// Never traps, even on a decoded value whose start > end.
    var range: ClosedRange<TimeInterval> { min(start, end)...max(start, end) }

    fileprivate init(text: String, captureID: UUID, start: TimeInterval, end: TimeInterval) {
        precondition(start <= end)
        self.text = text
        self.captureID = captureID
        self.start = start
        self.end = end
    }

    #if DEBUG
    static func fixture(text: String, captureID: UUID, start: TimeInterval, end: TimeInterval) -> VerifiedSpan {
        VerifiedSpan(text: text, captureID: captureID, start: start, end: end)
    }
    #endif
}

/// The transcript segments of one capture that a single model call sees (PLAN section 6.3).
struct TranscriptWindow: Equatable, Sendable {
    let captureID: UUID
    let segments: [TranscriptSegment]
}

/// Locates a model-returned string in a transcript window. A string that is not a contiguous
/// quotation is dropped, never rephrased (PLAN section 6.2): nil here means "say nothing".
enum SpanVerifier {
    private static let edgeCharacters = CharacterSet.punctuationCharacters.union(.symbols)

    /// Comparison key for one word: lowercased, curly apostrophes straightened, edge punctuation
    /// and symbols removed. Inner punctuation (the apostrophe in "didn't") is kept.
    static func key(_ raw: String) -> String {
        let straight = raw.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        return straight.trimmingCharacters(in: edgeCharacters)
    }

    /// The key of a whole phrase: its words' keys (empty keys dropped) joined by single spaces.
    static func phraseKey(_ phrase: String) -> String {
        phrase.split(whereSeparator: \.isWhitespace)
            .map { key(String($0)) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private struct Word {
        let surface: String
        let key: String
        let start: TimeInterval
        let end: TimeInterval
    }

    /// The first contiguous, case- and edge-punctuation-insensitive, whole-word occurrence of
    /// `candidate` in `window`, or nil. The span's text is the TRANSCRIPT's own words (edges
    /// trimmed), never the candidate's spelling. A span may cross two final segments but never a
    /// non-final one (volatile text is not stable). Its range is the covered segments' range.
    static func verify(_ candidate: String, in window: TranscriptWindow) -> VerifiedSpan? {
        let wanted = candidate.split(whereSeparator: \.isWhitespace)
            .map { key(String($0)) }
            .filter { !$0.isEmpty }
        guard !wanted.isEmpty else { return nil }

        for run in finalRuns(window.segments) {
            // Keep every original word so the surface text stays verbatim, and index the
            // ones that carry a comparable key.
            var words: [Word] = []
            for segment in run {
                for piece in segment.text.split(whereSeparator: \.isWhitespace) {
                    let surface = String(piece)
                    words.append(Word(surface: surface, key: key(surface), start: segment.start, end: segment.end))
                }
            }
            let keyed = words.indices.filter { !words[$0].key.isEmpty }
            guard keyed.count >= wanted.count else { continue }

            for first in 0...(keyed.count - wanted.count) {
                var matches = true
                for offset in 0..<wanted.count where words[keyed[first + offset]].key != wanted[offset] {
                    matches = false
                    break
                }
                guard matches else { continue }

                let from = keyed[first]
                let to = keyed[first + wanted.count - 1]
                let covered = words[from...to]
                let text = covered.map(\.surface).joined(separator: " ").trimmingCharacters(in: edgeCharacters)
                guard !text.isEmpty,
                      let start = covered.map(\.start).min(),
                      let end = covered.map(\.end).max(),
                      start <= end
                else { continue }
                return VerifiedSpan(text: text, captureID: window.captureID, start: start, end: end)
            }
        }
        return nil
    }

    /// Maximal runs of consecutive `isFinal` segments.
    private static func finalRuns(_ segments: [TranscriptSegment]) -> [[TranscriptSegment]] {
        var runs: [[TranscriptSegment]] = []
        var current: [TranscriptSegment] = []
        for segment in segments {
            if segment.isFinal {
                current.append(segment)
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }
}
