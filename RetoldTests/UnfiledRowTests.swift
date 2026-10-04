import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class UnfiledRowTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    private func transcript(_ text: String) -> CompletedTranscript {
        CompletedTranscript.fixture(
            segments: [TranscriptSegment(text: text, start: 0, end: 1, isFinal: true)]
        )
    }

    func testInProgressStatusesAreTranscribing() {
        for status in [TranscriptionStatus.pending, .live, .fromFile] {
            XCTAssertEqual(
                ConfirmDraft.unfiledRow(status: status, transcript: transcript("some words")),
                .transcribing
            )
        }
    }

    func testCompleteWithWordsIsReady() {
        XCTAssertEqual(
            ConfirmDraft.unfiledRow(status: .complete, transcript: transcript("some words")),
            .ready(excerpt: "some words")
        )
    }

    func testCompleteSilenceIsNoTranscript() {
        XCTAssertEqual(
            ConfirmDraft.unfiledRow(status: .complete, transcript: transcript(" \n  \t")),
            .noTranscript
        )
        XCTAssertEqual(
            ConfirmDraft.unfiledRow(status: .complete, transcript: nil),
            .noTranscript
        )
    }

    func testFailedIsNoTranscript() {
        XCTAssertEqual(
            ConfirmDraft.unfiledRow(status: .failed, transcript: transcript("ignored words")),
            .noTranscript
        )
    }

    func testExcerptMatchesSetExcerptRule() throws {
        let words = (1...30).map { "word\($0)" }
        let segments = [
            TranscriptSegment(
                text: words[0..<15].joined(separator: " "),
                start: 0,
                end: 2,
                isFinal: true
            ),
            TranscriptSegment(
                text: words[15..<30].joined(separator: " "),
                start: 2,
                end: 4,
                isFinal: true
            ),
        ]
        let capture = Capture(audioFileName: "memory.m4a", duration: 4)
        context.insert(capture)
        try capture.completeTranscript(segments)
        let completed = try XCTUnwrap(capture.completedTranscript)
        let episode = Episode(typedTitle: "Memory")
        context.insert(episode)
        episode.captures.append(capture)

        XCTAssertTrue(episode.setExcerpt(from: completed))
        XCTAssertEqual(
            ConfirmDraft.unfiledRow(status: .complete, transcript: completed),
            .ready(excerpt: episode.excerpt)
        )
    }
}
