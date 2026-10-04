import Foundation
import FoundationModels
import XCTest
@testable import Retold

/// R7 spec section 8.5: SystemLanguageModel.Availability -> ModelAvailability (PLAN section 8).
final class FoundationAvailabilityTests: XCTestCase {
    func testAvailableMapsToAvailable() {
        XCTAssertEqual(ModelAvailability(.available), .available)
    }

    func testEachUnavailableReasonMaps() {
        XCTAssertEqual(ModelAvailability(.unavailable(.deviceNotEligible)), .deviceNotEligible)
        XCTAssertEqual(ModelAvailability(.unavailable(.appleIntelligenceNotEnabled)), .appleIntelligenceNotEnabled)
        XCTAssertEqual(ModelAvailability(.unavailable(.modelNotReady)), .modelNotReady)
    }

    func testPromptKeepsOnlyFinalSegments() {
        let transcript = CompletedTranscript.fixture(segments: [
            TranscriptSegment(text: "We drove to the lake.", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "volatile words", start: 2, end: 3, isFinal: false),
            TranscriptSegment(text: "Dan came too.", start: 3, end: 5, isFinal: true),
        ])
        let prompt = FoundationFilingModel.prompt(
            for: transcript.window(0..<3), periodTitles: ["High school", "Twenties"])
        XCTAssertEqual(prompt, "Periods: High school | Twenties\n\nTranscript:\nWe drove to the lake. Dan came too.")
    }
}
