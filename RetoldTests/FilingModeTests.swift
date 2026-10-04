import Foundation
import XCTest
@testable import Retold

final class FilingModeTests: XCTestCase {
    func testSuggestionsOffWinsOverAvailable() {
        XCTAssertEqual(FilingMode.select(availability: .available, suggestionsOn: false), .deck(.suggestionsOff))
    }

    func testSuggestionsOffWinsOverEveryAvailability() {
        let all: [ModelAvailability] = [
            .available, .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unknown,
        ]
        for availability in all {
            XCTAssertEqual(
                FilingMode.select(availability: availability, suggestionsOn: false),
                .deck(.suggestionsOff),
                "\(availability)"
            )
        }
    }

    func testAvailableSelectsModel() {
        XCTAssertEqual(FilingMode.select(availability: .available, suggestionsOn: true), .model)
    }

    func testEachUnavailableReasonMapsToItsDeckReason() {
        XCTAssertEqual(
            FilingMode.select(availability: .deviceNotEligible, suggestionsOn: true),
            .deck(.deviceNotEligible))
        XCTAssertEqual(
            FilingMode.select(availability: .appleIntelligenceNotEnabled, suggestionsOn: true),
            .deck(.appleIntelligenceNotEnabled))
        XCTAssertEqual(
            FilingMode.select(availability: .modelNotReady, suggestionsOn: true),
            .deck(.modelNotReady))
    }

    func testUnknownMapsToDeviceNotEligible() {
        XCTAssertEqual(FilingMode.select(availability: .unknown, suggestionsOn: true), .deck(.deviceNotEligible))
    }

    func testReasonCopyIsAppCopyVerbatim() {
        XCTAssertEqual(DeckReason.deviceNotEligible.copy, AppCopy.newerPhoneReason)
        XCTAssertEqual(DeckReason.appleIntelligenceNotEnabled.copy, AppCopy.appleIntelligenceOffReason)
        XCTAssertEqual(DeckReason.modelNotReady.copy, AppCopy.modelsDownloadingReason)
        XCTAssertNil(DeckReason.suggestionsOff.copy)
    }

    func testDeckModeReturnsDeckFilingModelWithoutCallingFoundation() {
        var foundationCalled = false
        let model = FilingMode.deck(.deviceNotEligible).filingModel {
            foundationCalled = true
            return MockFilingModel { _, _ in WindowExtract() }
        }
        XCTAssertFalse(foundationCalled)
        XCTAssertTrue(model is DeckFilingModel)
    }

    func testModelModeReturnsFoundation() {
        let model = FilingMode.model.filingModel {
            MockFilingModel { _, _ in WindowExtract(people: ["only this model sees the call"]) }
        }
        XCTAssertTrue(model is MockFilingModel)
    }

    func testDeckFilingModelPipelineProposesOnlyBroadAndWhen() async {
        let transcript = CompletedTranscript.fixture(captureID: UUID(), segments: [
            TranscriptSegment(text: "we went down to the pier", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "and it smelled of salt", start: 2, end: 4, isFinal: true),
        ])
        let pipeline = FilingPipeline(model: DeckFilingModel(), counter: WordTokenCounter())
        let outcome = await pipeline.file(transcript, periodTitles: [])
        guard case let .proposal(merged, questions) = outcome else {
            return XCTFail("expected a proposal, got \(outcome)")
        }
        XCTAssertEqual(merged, MergedExtract())
        XCTAssertEqual(questions.map(\.templateID), ["broad.open", "when.open"])
    }

    func testDeckFilingModelEmptyTranscriptIsNoModel() async {
        let pipeline = FilingPipeline(model: DeckFilingModel(), counter: WordTokenCounter())
        let outcome = await pipeline.file(CompletedTranscript.fixture(segments: []), periodTitles: [])
        XCTAssertEqual(outcome, .noModel(.other))
    }
}
