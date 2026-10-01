import Foundation
import XCTest
@testable import Retold

private actor CallLog {
    private(set) var windows: [TranscriptWindow] = []
    func record(_ window: TranscriptWindow) -> Int {
        windows.append(window)
        return windows.count
    }
}

/// Implant fixtures: a synthetic transcript and a model that tries to author memory content.
/// Everything here is invented for the tests; no real memory text is ever used.
final class FilingPipelineTests: XCTestCase {
    private let captureID = UUID()
    private let periods = ["Primary school", "Junior high"]

    private var transcript: [TranscriptSegment] {
        [
            TranscriptSegment(text: "The summer before eighth grade we went to Camp Lakeview.", start: 0, end: 5, isFinal: true),
            TranscriptSegment(text: "My counselor Dan let us paddle the green canoe at dawn.", start: 5, end: 10, isFinal: true),
            TranscriptSegment(text: "I remember the smell of pine and the cold water.", start: 10, end: 15, isFinal: true),
        ]
    }

    private func pipeline(_ handler: @escaping @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract,
                          maxTokens: Int = 1_600) -> FilingPipeline {
        FilingPipeline(model: MockFilingModel(handler: handler), counter: WordTokenCounter(),
                       maxWindowTokens: maxTokens, overlapTokens: 0)
    }

    /// A model that invents: paraphrases, adds a name, an emotion, a year, and a role.
    private let implanting: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { _, _ in
        WindowExtract(
            periodName: "Junior high",
            people: ["Dan", "Marcus", "his father"],
            places: ["Camp Lakeview", "the old quarry"],
            timeCues: ["the summer before eighth grade", "the summer of 1994"],
            referents: [
                RawReferent(span: "the green canoe", kind: .object),
                RawReferent(span: "scared of the dark water", kind: .sensory),
                RawReferent(span: "smell of pine", kind: .sensory),
            ],
            titleSpan: "my happiest summer")
    }

    func testImplantedStringsNeverReachTheOutput() async {
        let outcome = await pipeline(implanting).file(captureID: captureID, segments: transcript, periodTitles: periods)
        guard case let .proposal(merged, questions) = outcome else { return XCTFail("expected a proposal") }

        XCTAssertEqual(merged.people.map(\.text), ["Dan"])
        XCTAssertEqual(merged.places.map(\.text), ["Camp Lakeview"])
        XCTAssertEqual(merged.timeCues.map(\.text), ["The summer before eighth grade"])
        XCTAssertEqual(merged.referents.map(\.span.text), ["the green canoe", "smell of pine"])
        XCTAssertNil(merged.titleSpan)
        XCTAssertEqual(merged.periodTitle, "Junior high")

        let spoken = transcript.map(\.text).joined(separator: " ")
        let allSpans = merged.people + merged.places + merged.timeCues + merged.referents.map(\.span)
        for span in allSpans {
            XCTAssertTrue(spoken.contains(span.text), "not a contiguous transcript quotation: \(span.text)")
        }
        let everything = questions.map(\.text).joined(separator: " ")
        for invented in ["Marcus", "father", "quarry", "1994", "scared", "happiest"] {
            XCTAssertFalse(everything.contains(invented), invented)
        }
    }

    func testEveryQuestionSlotIsAVerifiedSpanOfTheTranscript() async {
        let outcome = await pipeline(implanting).file(captureID: captureID, segments: transcript, periodTitles: periods)
        guard case let .proposal(_, questions) = outcome else { return XCTFail("expected a proposal") }
        let spoken = transcript.map(\.text).joined(separator: " ")
        XCTAssertFalse(questions.isEmpty)
        for question in questions {
            for slot in question.slots {
                XCTAssertTrue(spoken.contains(slot.text), slot.text)
                XCTAssertEqual(slot.captureID, captureID)
                XCTAssertLessThanOrEqual(slot.start, slot.end)
            }
        }
    }

    func testEachWindowGetsItsOwnCallAndSeesOnlyItsOwnSegments() async {
        let log = CallLog()
        let model: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { window, _ in
            _ = await log.record(window)
            return WindowExtract()
        }
        // 10, 11 and 10 words per segment: a 12-token budget forces one segment per window.
        let outcome = await pipeline(model, maxTokens: 12).file(captureID: captureID, segments: transcript, periodTitles: periods)
        guard case .proposal = outcome else { return XCTFail("expected a proposal") }
        let windows = await log.windows
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows.map { $0.segments.count }, [1, 1, 1])
    }

    func testPeriodTitlesAreSuppliedToEveryCall() async {
        let log = CallLog()
        let model: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { window, titles in
            XCTAssertEqual(titles, ["Primary school", "Junior high"])
            _ = await log.record(window)
            return WindowExtract()
        }
        _ = await pipeline(model).file(captureID: captureID, segments: transcript, periodTitles: periods)
        let count = await log.windows.count
        XCTAssertEqual(count, 1)
    }

    func testAnyModelErrorSendsTheWholeCaptureToNoModel() async {
        let cases: [FilingModelError] = [
            .refused, .assetsNotReady, .unsupportedLocale, .decodingFailure,
            .contextExceeded, .rateLimited, .timeout, .cancelled, .other,
        ]
        for error in cases {
            let model: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { _, _ in throw error }
            let outcome = await pipeline(model).file(captureID: captureID, segments: transcript, periodTitles: periods)
            XCTAssertEqual(outcome, .noModel(error))
        }
    }

    func testFailureInALaterWindowDiscardsEarlierWindows() async {
        let log = CallLog()
        let model: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { window, _ in
            let n = await log.record(window)
            if n == 2 { throw FilingModelError.refused }
            return WindowExtract(people: ["Dan"])
        }
        let outcome = await pipeline(model, maxTokens: 12).file(captureID: captureID, segments: transcript, periodTitles: periods)
        XCTAssertEqual(outcome, .noModel(.refused))
    }

    func testUnknownAndCancellationErrorsAreMapped() async {
        struct Boom: Error {}
        let unknown: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { _, _ in throw Boom() }
        let cancelled: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { _, _ in throw CancellationError() }
        let a = await pipeline(unknown).file(captureID: captureID, segments: transcript, periodTitles: periods)
        let b = await pipeline(cancelled).file(captureID: captureID, segments: transcript, periodTitles: periods)
        XCTAssertEqual(a, .noModel(.other))
        XCTAssertEqual(b, .noModel(.cancelled))
    }

    func testEmptyTranscriptIsNoModelAndNeverCallsTheModel() async {
        let log = CallLog()
        let model: @Sendable (TranscriptWindow, [String]) async throws -> WindowExtract = { window, _ in
            _ = await log.record(window)
            return WindowExtract()
        }
        let outcome = await pipeline(model).file(captureID: captureID, segments: [], periodTitles: periods)
        XCTAssertEqual(outcome, .noModel(.other))
        let count = await log.windows.count
        XCTAssertEqual(count, 0)
    }
}
