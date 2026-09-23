import Foundation
import XCTest
@testable import Retold

@MainActor
final class EntityRuleTests: XCTestCase {
    private func makeQuestion(_ text: String, origin: Origin = .deck) -> Question {
        Question(text: text, templateID: "template.\(text)", slots: [], cue: .event, origin: origin)
    }

    func testAnswerWhenYearIsUserTypedAndAnswersQuestion() {
        let episode = Episode(title: Confirmable.userTyped("The lake trip"))
        let question = makeQuestion("Roughly when was this?")
        episode.setWhenQuestion(question)

        episode.answerWhen(year: 1987)

        let year = episode.approxYear
        XCTAssertEqual(year?.value, 1987)
        XCTAssertEqual(year?.status, .confirmed)
        XCTAssertEqual(year?.provenance, .userTyped)
        XCTAssertEqual(episode.whenQuestion?.status, .answered)
    }

    func testAnswerWhenWithoutQuestionStillSetsValue() {
        let episode = Episode(title: Confirmable.userTyped("Unfiled"))
        episode.answerWhen(age: 7)

        let age = episode.approxAge
        XCTAssertEqual(age?.value, 7)
        XCTAssertEqual(age?.status, .confirmed)
        XCTAssertEqual(age?.provenance, .userTyped)
        XCTAssertNil(episode.whenQuestion)
    }

    func testWhenQuestionPicksByID() {
        let episode = Episode(title: Confirmable.userTyped("Trip"))
        let first = makeQuestion("first")
        let second = makeQuestion("second")
        let third = makeQuestion("third", origin: .user)
        episode.questions.append(contentsOf: [first, second, third])

        episode.setWhenQuestion(second)

        XCTAssertEqual(episode.questions.count, 3)
        XCTAssertEqual(episode.whenQuestion?.id, second.id)
        XCTAssertEqual(episode.whenQuestionID, second.id)

        episode.answerWhen(age: 12)

        XCTAssertEqual(first.status, .open)
        XCTAssertEqual(second.status, .answered)
        XCTAssertEqual(third.status, .open)
        XCTAssertEqual(episode.whenQuestion?.id, second.id)
    }

    func testSetExcerptIsVerbatimFirst25Words() {
        let words = (1...40).map { "w\($0)" }
        let segments = [
            TranscriptSegment(text: words[0..<15].joined(separator: " "), start: 0, end: 5, isFinal: true),
            TranscriptSegment(text: words[15..<30].joined(separator: " "), start: 5, end: 10, isFinal: true),
            TranscriptSegment(text: words[30..<40].joined(separator: " "), start: 10, end: 14, isFinal: false),
        ]
        let episode = Episode(title: Confirmable.userTyped("E"))
        episode.setExcerpt(from: segments)
        XCTAssertEqual(episode.excerpt, words[0..<25].joined(separator: " "))

        let short = [TranscriptSegment(text: words[0..<10].joined(separator: " "), start: 0, end: 4, isFinal: true)]
        let shortEpisode = Episode(title: Confirmable.userTyped("S"))
        shortEpisode.setExcerpt(from: short)
        XCTAssertEqual(shortEpisode.excerpt, words[0..<10].joined(separator: " "))
    }

    func testUpdateTranscriptRejectsCompleteArgument() {
        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        let segments = [TranscriptSegment(text: "hello", start: 0, end: 1, isFinal: true)]
        XCTAssertThrowsError(try capture.updateTranscript(segments, status: .complete)) { error in
            XCTAssertEqual(error as? CaptureError, .useCompleteTranscript)
        }
        XCTAssertEqual(capture.transcriptionStatus, .pending)
        XCTAssertTrue(capture.transcript.isEmpty)
    }

    func testDetailInitializersNeverModel() {
        let span = VerifiedSpan(text: "the smell of pine", captureID: UUID(), start: 1, end: 2)
        let quote = Detail(quote: span, kind: .sensory)
        XCTAssertEqual(quote.text, "the smell of pine")
        XCTAssertEqual(quote.provenance, StoredProvenance(.transcriptQuote(captureID: span.captureID, start: 1, end: 2)))

        let typed = Detail(typed: "It rained.", kind: .emotion)
        XCTAssertEqual(typed.text, "It rained.")
        XCTAssertEqual(typed.provenance, StoredProvenance(.userTyped))
    }

    func testTranscriptUpdatableUntilComplete() throws {
        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        let live1 = [TranscriptSegment(text: "one", start: 0, end: 1, isFinal: false)]
        let live2 = [TranscriptSegment(text: "one two", start: 0, end: 2, isFinal: true)]
        try capture.updateTranscript(live1, status: .live)
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, live1)

        try capture.updateTranscript(live2, status: .live)
        XCTAssertEqual(capture.transcriptionStatus, .live)
        XCTAssertEqual(capture.transcript, live2)

        let final = [TranscriptSegment(text: "one two three", start: 0, end: 3, isFinal: true)]
        try capture.completeTranscript(final)
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(capture.transcript, final)
    }

    func testCompletedTranscriptRejectsRewrite() throws {
        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        let final = [TranscriptSegment(text: "done", start: 0, end: 1, isFinal: true)]
        try capture.completeTranscript(final)

        let rewrite = [TranscriptSegment(text: "rewritten", start: 0, end: 1, isFinal: true)]
        XCTAssertThrowsError(try capture.updateTranscript(rewrite, status: .live)) { error in
            XCTAssertEqual(error as? CaptureError, .transcriptAlreadyComplete)
        }
        XCTAssertThrowsError(try capture.completeTranscript(rewrite)) { error in
            XCTAssertEqual(error as? CaptureError, .transcriptAlreadyComplete)
        }
        XCTAssertEqual(capture.transcriptionStatus, .complete)
        XCTAssertEqual(capture.transcript, final)
    }

    func testCorrectionLeavesTranscriptUnchanged() throws {
        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        let segments = [
            TranscriptSegment(text: "alpha beta", start: 0, end: 1, isFinal: true),
            TranscriptSegment(text: "gamma", start: 1, end: 2, isFinal: true),
        ]
        try capture.completeTranscript(segments)
        let at = Date(timeIntervalSince1970: 1_700_000_000)

        try capture.addCorrection(segmentIndex: 1, correctedText: "delta", at: at)

        XCTAssertEqual(capture.corrections.count, 1)
        let correction = capture.corrections[0]
        XCTAssertEqual(correction.segmentIndex, 1)
        XCTAssertEqual(correction.originalText, "gamma")
        XCTAssertEqual(correction.correctedText, "delta")
        XCTAssertEqual(correction.createdAt.timeIntervalSince1970, at.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(capture.transcript, segments)
    }

    func testCorrectionOutOfRangeThrows() throws {
        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        let segments = [TranscriptSegment(text: "only", start: 0, end: 1, isFinal: true)]
        try capture.completeTranscript(segments)

        XCTAssertThrowsError(try capture.addCorrection(segmentIndex: 1, correctedText: "x")) { error in
            XCTAssertEqual(error as? CaptureError, .segmentIndexOutOfRange)
        }
        XCTAssertTrue(capture.corrections.isEmpty)
    }

    func testLogRejectedAppends() {
        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Date(timeIntervalSince1970: 1_700_000_500)

        capture.logRejected(.person, text: "Sara", at: first)
        capture.logRejected(.place, text: "the dock", at: second)

        XCTAssertEqual(capture.rejectedProposals.count, 2)
        XCTAssertEqual(capture.rejectedProposals[0].kind, .person)
        XCTAssertEqual(capture.rejectedProposals[0].text, "Sara")
        XCTAssertEqual(capture.rejectedProposals[0].rejectedAt.timeIntervalSince1970, first.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(capture.rejectedProposals[1].kind, .place)
        XCTAssertEqual(capture.rejectedProposals[1].text, "the dock")
        XCTAssertEqual(capture.rejectedProposals[1].rejectedAt.timeIntervalSince1970, second.timeIntervalSince1970, accuracy: 0.001)
    }
}
