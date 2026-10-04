import Foundation
import XCTest
@testable import Retold

final class CompletedTranscriptTests: XCTestCase {
    func testWindowCarriesTheTranscriptsCaptureIDAndSlice() {
        let captureID = UUID()
        let segs = (0..<4).map { index in
            TranscriptSegment(text: "s\(index)", start: Double(index), end: Double(index + 1), isFinal: true)
        }
        let transcript = CompletedTranscript.fixture(captureID: captureID, segments: segs)

        let slice = transcript.window(1..<3)
        XCTAssertEqual(slice.captureID, captureID)
        XCTAssertEqual(slice.segments, Array(segs[1..<3]))
        XCTAssertEqual(transcript.window(segs.indices).segments, segs)
    }
}
