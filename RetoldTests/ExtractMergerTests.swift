import Foundation
import XCTest
@testable import Retold

final class ExtractMergerTests: XCTestCase {
    private let captureID = UUID()

    private func window(_ segments: [(String, TimeInterval, TimeInterval)]) -> TranscriptWindow {
        let segs = segments.map { TranscriptSegment(text: $0.0, start: $0.1, end: $0.2, isFinal: true) }
        return CompletedTranscript.fixture(captureID: captureID, segments: segs).window(segs.indices)
    }

    private let periods = ["Primary school", "Junior high"]

    func testUnverifiableStringsAreDroppedWithNoTrace() {
        let w = window([("I swam at the lake with Dan.", 0, 3)])
        let extract = WindowExtract(
            periodName: nil,
            people: ["Dan", "Marcus"],
            places: ["the lake", "the old quarry"],
            timeCues: ["the summer of 1994"],
            referents: [RawReferent(span: "swam at the lake", kind: .activity),
                        RawReferent(span: "a red canoe", kind: .object)],
            titleSpan: "my best summer")
        let merged = ExtractMerger.merge([(w, extract)], periodTitles: periods)
        XCTAssertEqual(merged.people.map(\.text), ["Dan"])
        XCTAssertEqual(merged.places.map(\.text), ["the lake"])
        XCTAssertTrue(merged.timeCues.isEmpty)
        XCTAssertEqual(merged.referents.map(\.span.text), ["swam at the lake"])
        XCTAssertNil(merged.titleSpan)
    }

    func testSameQuotationInOverlappingWindowsAppearsOnce() {
        let shared = ("Dan taught me to swim.", 4.0, 7.0)
        let w1 = window([("It was camp.", 0, 4), shared])
        let w2 = window([shared, ("We ate late.", 7, 9)])
        let one = WindowExtract(people: ["Dan"])
        let merged = ExtractMerger.merge([(w1, one), (w2, one)], periodTitles: periods)
        XCTAssertEqual(merged.people.count, 1)
    }

    func testResultsAreOrderedByAudioStart() {
        let w = window([("Zed came first.", 0, 2), ("Amy came second.", 2, 4)])
        let merged = ExtractMerger.merge(
            [(w, WindowExtract(people: ["Amy", "Zed"]))], periodTitles: periods)
        XCTAssertEqual(merged.people.map(\.text), ["Zed", "Amy"])
    }

    func testPeriodNameMustBeInTheUsersListAndIsReturnedSpelledAsTheirs() {
        let w = window([("Anything.", 0, 1)])
        let invented = ExtractMerger.merge(
            [(w, WindowExtract(periodName: "College years"))], periodTitles: periods)
        XCTAssertNil(invented.periodTitle)
        let recased = ExtractMerger.merge(
            [(w, WindowExtract(periodName: "junior HIGH"))], periodTitles: periods)
        XCTAssertEqual(recased.periodTitle, "Junior high")
    }

    func testPeriodIsMajorityVoteWithTheEarliestWindowBreakingTies() {
        let w = window([("Anything.", 0, 1)])
        func pick(_ names: [String?]) -> String? {
            let results = names.map { (window: w, extract: WindowExtract(periodName: $0)) }
            return ExtractMerger.merge(results, periodTitles: periods).periodTitle
        }
        XCTAssertEqual(pick(["Junior high", "Primary school", "Primary school"]), "Primary school")
        XCTAssertEqual(pick(["Junior high", "Primary school"]), "Junior high")
        XCTAssertEqual(pick([nil, "Primary school", "Junior high"]), "Primary school")
        XCTAssertNil(pick([nil, nil]))
    }

    func testTitleSpanIsTheFirstVerifiedOneAndAtMostEightWords() {
        let w1 = window([("one two three four five six seven eight nine ten.", 0, 5)])
        let w2 = window([("The lake house.", 5, 7)])
        let merged = ExtractMerger.merge(
            [(w1, WindowExtract(titleSpan: "one two three four five six seven eight nine")),
             (w2, WindowExtract(titleSpan: "The lake house"))],
            periodTitles: periods)
        XCTAssertEqual(merged.titleSpan?.text, "The lake house")
    }
}
