import Foundation

/// The frozen transcript of one completed Capture, bound to that capture's id
/// (R4.5, Sol R2 finding 4). Only `Capture.completedTranscript` builds one.
struct CompletedTranscript: Equatable, Sendable {
    let captureID: UUID
    let segments: [TranscriptSegment]

    /// R1's word rule: the first 25 whitespace-separated words, in segment order.
    var excerpt: String {
        segments
            .flatMap { $0.text.split(whereSeparator: \.isWhitespace) }
            .prefix(25)
            .map { String($0) }
            .joined(separator: " ")
    }

    fileprivate init(captureID: UUID, segments: [TranscriptSegment]) {
        self.captureID = captureID
        self.segments = segments
    }

    /// The window over `segments[range]`, carrying this transcript's captureID.
    /// precondition: range.lowerBound >= 0 && range.upperBound <= segments.count.
    func window(_ range: Range<Int>) -> TranscriptWindow {
        precondition(range.lowerBound >= 0 && range.upperBound <= segments.count)
        return TranscriptWindow(captureID: captureID, segments: Array(segments[range]))
    }

    #if DEBUG
    static func fixture(captureID: UUID = UUID(), segments: [TranscriptSegment]) -> CompletedTranscript {
        CompletedTranscript(captureID: captureID, segments: segments)
    }
    #endif
}

/// The transcript segments of one capture that a single model call sees (PLAN section 6.3).
/// Only CompletedTranscript.window builds one, so its captureID is always the true one.
struct TranscriptWindow: Equatable, Sendable {
    let captureID: UUID
    let segments: [TranscriptSegment]

    fileprivate init(captureID: UUID, segments: [TranscriptSegment]) {
        self.captureID = captureID
        self.segments = segments
    }
}

extension Capture {
    /// The frozen transcript, or nil unless transcriptionStatus == .complete. .live and .fromFile
    /// are in-progress states (updateTranscript); completion goes only through completeTranscript.
    /// segments == transcript exactly: no isFinal filtering, no corrections applied.
    var completedTranscript: CompletedTranscript? {
        guard transcriptionStatus == .complete else { return nil }
        return CompletedTranscript(captureID: id, segments: transcript)
    }
}
