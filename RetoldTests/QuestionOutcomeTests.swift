import Foundation
import XCTest
@testable import Retold

@MainActor
final class QuestionOutcomeTests: XCTestCase {
    private func question(_ templateID: String = "event.else", status: QuestionStatus = .open) -> Question {
        let question = Question(text: "Is there anything else about that?", templateID: templateID,
                                slots: [], cue: .event, origin: .deck)
        question.status = status
        return question
    }

    func testOpenTransitions() {
        let answered = question()
        XCTAssertTrue(answered.record(.answered))
        XCTAssertEqual(answered.status, .answered)

        let forgotten = question()
        XCTAssertTrue(forgotten.record(.dontRemember))
        XCTAssertEqual(forgotten.status, .retired)

        let skipped = question()
        XCTAssertTrue(skipped.record(.skipped))
        XCTAssertEqual(skipped.status, .skipped)
    }

    func testSkippedTransitions() {
        let answered = question(status: .skipped)
        XCTAssertTrue(answered.record(.answered))
        XCTAssertEqual(answered.status, .answered)

        let forgotten = question(status: .skipped)
        XCTAssertTrue(forgotten.record(.dontRemember))
        XCTAssertEqual(forgotten.status, .retired)

        let skippedAgain = question(status: .skipped)
        XCTAssertTrue(skippedAgain.record(.skipped))
        XCTAssertEqual(skippedAgain.status, .retired)
    }

    func testAnsweredAndRetiredAreFinal() {
        for status in [QuestionStatus.answered, .retired] {
            for outcome in [QuestionOutcome.answered, .dontRemember, .skipped] {
                let done = question(status: status)
                XCTAssertFalse(done.record(outcome), "\(status) \(outcome)")
                XCTAssertEqual(done.status, status, "\(status) \(outcome)")
            }
        }
    }

    func testSkipTwiceRetires() {
        let q = question()
        q.record(.skipped)
        q.record(.skipped)
        XCTAssertEqual(q.status, .retired)
    }

    func testSkipThenAnswerIsAnswered() {
        let q = question()
        q.record(.skipped)
        q.record(.answered)
        XCTAssertEqual(q.status, .answered)
    }

    func testBroadOpenIsNeverRetired() {
        let skipped = question("broad.open")
        XCTAssertTrue(skipped.record(.skipped))
        XCTAssertTrue(skipped.record(.skipped))
        XCTAssertEqual(skipped.status, .open)

        let forgotten = question("broad.open")
        XCTAssertTrue(forgotten.record(.dontRemember))
        XCTAssertEqual(forgotten.status, .open)

        let answered = question("broad.open")
        XCTAssertTrue(answered.record(.answered))
        XCTAssertEqual(answered.status, .answered)
    }

    func testMarkShownCountsAndStamps() {
        let q = question()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Date(timeIntervalSince1970: 1_700_000_500)
        q.markShown(at: first)
        XCTAssertEqual(q.askedCount, 1)
        XCTAssertEqual(q.lastAskedAt, first)
        q.markShown(at: second)
        XCTAssertEqual(q.askedCount, 2)
        XCTAssertEqual(q.lastAskedAt, second)
        XCTAssertEqual(q.status, .open)
    }
}
