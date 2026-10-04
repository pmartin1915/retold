import Foundation
import XCTest
@testable import Retold

final class SpanVerifierTests: XCTestCase {
    private let captureID = UUID()

    private func window(_ segments: [(String, TimeInterval, TimeInterval, Bool)]) -> TranscriptWindow {
        let segs = segments.map { TranscriptSegment(text: $0.0, start: $0.1, end: $0.2, isFinal: $0.3) }
        return CompletedTranscript.fixture(captureID: captureID, segments: segs).window(segs.indices)
    }

    private var sample: TranscriptWindow {
        window([
            ("We drove out to Camp Lakeview, the summer before eighth grade.", 0, 4, true),
            ("My counselor Dan didn\u{2019}t let us swim until noon.", 4, 8, true),
        ])
    }

    func testExactPhraseVerifiesWithTranscriptTextAndRange() {
        let span = SpanVerifier.verify("Camp Lakeview", in: sample)
        XCTAssertEqual(span?.text, "Camp Lakeview")
        XCTAssertEqual(span?.start, 0)
        XCTAssertEqual(span?.end, 4)
        XCTAssertEqual(span?.captureID, captureID)
    }

    func testMatchIsCaseAndEdgePunctuationInsensitiveButReturnsTranscriptSpelling() {
        let span = SpanVerifier.verify("camp lakeview,", in: sample)
        XCTAssertEqual(span?.text, "Camp Lakeview")
        let apostrophe = SpanVerifier.verify("didn't let us swim", in: sample)
        XCTAssertEqual(apostrophe?.text, "didn\u{2019}t let us swim")
    }

    func testSpanTextIsAlwaysAContiguousPieceOfTheTranscript() {
        let transcript = sample.segments.map(\.text).joined(separator: " ")
        for candidate in ["the summer before eighth grade", "My counselor Dan", "swim until noon"] {
            let span = SpanVerifier.verify(candidate, in: sample)
            XCTAssertNotNil(span, candidate)
            XCTAssertTrue(transcript.contains(span?.text ?? "\u{0}"), candidate)
        }
    }

    func testReorderedSkippedAndInventedWordsAreRejected() {
        XCTAssertNil(SpanVerifier.verify("Lakeview Camp", in: sample))
        XCTAssertNil(SpanVerifier.verify("drove to Camp Lakeview", in: sample))
        XCTAssertNil(SpanVerifier.verify("my friend Dan", in: sample))
        XCTAssertNil(SpanVerifier.verify("Marcus", in: sample))
    }

    func testPartialWordsDoNotMatch() {
        let w = window([("We stayed at the lakeview cabins with Danny.", 0, 3, true)])
        XCTAssertNil(SpanVerifier.verify("lake", in: w))
        XCTAssertNil(SpanVerifier.verify("Dan", in: w))
        XCTAssertNotNil(SpanVerifier.verify("Danny", in: w))
    }

    func testEmptyAndPunctuationOnlyCandidatesAreRejected() {
        XCTAssertNil(SpanVerifier.verify("", in: sample))
        XCTAssertNil(SpanVerifier.verify("   ", in: sample))
        XCTAssertNil(SpanVerifier.verify("\u{2014} ...", in: sample))
    }

    func testSpanMayCrossTwoFinalSegments() {
        let span = SpanVerifier.verify("eighth grade. My counselor", in: sample)
        XCTAssertEqual(span?.text, "eighth grade. My counselor")
        XCTAssertEqual(span?.start, 0)
        XCTAssertEqual(span?.end, 8)
    }

    func testSpanNeverCrossesANonFinalSegment() {
        let w = window([
            ("we went to the", 0, 2, true),
            ("big old", 2, 3, false),
            ("lake every day", 3, 5, true),
        ])
        XCTAssertNil(SpanVerifier.verify("the big old lake", in: w))
        XCTAssertNil(SpanVerifier.verify("big old", in: w))
        XCTAssertNotNil(SpanVerifier.verify("lake every day", in: w))
    }

    func testFirstOccurrenceWins() {
        let w = window([
            ("the dock", 0, 1, true),
            ("and then the dock again", 1, 3, true),
        ])
        let span = SpanVerifier.verify("the dock", in: w)
        XCTAssertEqual(span?.start, 0)
        XCTAssertEqual(span?.end, 1)
    }

    func testPhraseKeyNormalises() {
        XCTAssertEqual(SpanVerifier.phraseKey("  The Lake,  "), "the lake")
        XCTAssertEqual(SpanVerifier.phraseKey("Dan\u{2019}s"), "dan's")
        XCTAssertEqual(SpanVerifier.phraseKey("\u{2014}"), "")
    }
}
