import Foundation
import XCTest
@testable import Retold

final class WindowChunkerTests: XCTestCase {
    private let captureID = UUID()
    private let counter = WordTokenCounter()

    /// `sizes[i]` words in segment i; text is "s<i>w<j>" so every word is unique.
    private func segments(_ sizes: [Int]) -> [TranscriptSegment] {
        sizes.enumerated().map { index, size in
            TranscriptSegment(
                text: (0..<size).map { "s\(index)w\($0)" }.joined(separator: " "),
                start: Double(index), end: Double(index + 1), isFinal: true)
        }
    }

    private func windows(_ sizes: [Int], max: Int, overlap: Int) -> [TranscriptWindow] {
        WindowChunker.windows(
            captureID: captureID, segments: segments(sizes), maxTokens: max, overlapTokens: overlap, counter: counter)
    }

    func testEmptyTranscriptHasNoWindows() {
        XCTAssertTrue(windows([], max: 10, overlap: 2).isEmpty)
    }

    func testShortTranscriptIsOneWindow() {
        let result = windows([3, 3], max: 10, overlap: 2)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].segments.count, 2)
        XCTAssertEqual(result[0].captureID, captureID)
    }

    func testEverySegmentIsCoveredAndWindowsRespectTheBudget() {
        let sizes = [4, 5, 3, 6, 2, 5, 4, 3, 6, 5]
        let result = windows(sizes, max: 12, overlap: 4)
        let covered = Set(result.flatMap { $0.segments.map(\.start) })
        XCTAssertEqual(covered, Set(sizes.indices.map(Double.init)))
        for window in result {
            let total = window.segments.map { counter.count($0.text) }.reduce(0, +)
            XCTAssertLessThanOrEqual(total, 12)
        }
    }

    func testConsecutiveWindowsOverlapWithinTheOverlapBudgetAndAdvance() {
        let result = windows([4, 4, 4, 4, 4, 4], max: 12, overlap: 4)
        XCTAssertGreaterThan(result.count, 1)
        for (previous, next) in zip(result, result.dropFirst()) {
            XCTAssertGreaterThan(next.segments.last!.start, previous.segments.last!.start, "must reach a new segment")
            XCTAssertGreaterThan(next.segments.first!.start, previous.segments.first!.start, "must advance")
            let shared = next.segments.filter { segment in previous.segments.contains(segment) }
            let sharedTokens = shared.map { counter.count($0.text) }.reduce(0, +)
            XCTAssertLessThanOrEqual(sharedTokens, 4)
        }
    }

    func testOversizeSegmentGetsItsOwnWindowAndTerminates() {
        let result = windows([3, 30, 3], max: 10, overlap: 4)
        XCTAssertTrue(result.contains { $0.segments.count == 1 && counter.count($0.segments[0].text) == 30 })
        let covered = Set(result.flatMap { $0.segments.map(\.start) })
        XCTAssertEqual(covered, [0, 1, 2])
    }

    func testZeroOverlapPartitionsTheTranscript() {
        let result = windows([5, 5, 5, 5], max: 10, overlap: 0)
        XCTAssertEqual(result.map { $0.segments.count }, [2, 2])
    }
}
