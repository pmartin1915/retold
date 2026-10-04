import Foundation
import XCTest
@testable import Retold

/// The transcription route's checked chain and its journal tag (docs/R6-RECORDER-SPEC.md §4.2).
final class TranscriptionRouteTests: XCTestCase {
    // MARK: - select

    func testSpeechWhenAllSpeechChecksPass() {
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: true, speechLocale: "en_US",
                                      speechAssetsInstalled: true,
                                      dictationLocale: "en_US", dictationAssetsInstalled: true),
            .speech(localeID: "en_US"))
    }

    func testDictationWhenSpeechModuleUnavailable() {
        // SpeechTranscriber is absent; DictationTranscriber's locale+assets are the gate.
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: false, speechLocale: nil,
                                      speechAssetsInstalled: false,
                                      dictationLocale: "en_US", dictationAssetsInstalled: true),
            .dictation(localeID: "en_US"))
    }

    func testDictationWhenSpeechAssetsMissing() {
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: true, speechLocale: "en_US",
                                      speechAssetsInstalled: false,
                                      dictationLocale: "fr_FR", dictationAssetsInstalled: true),
            .dictation(localeID: "fr_FR"))
    }

    func testAudioOnlyAssetsNotInstalled() {
        // Speech supported, assets missing, dictation not an option.
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: true, speechLocale: "en_US",
                                      speechAssetsInstalled: false,
                                      dictationLocale: nil, dictationAssetsInstalled: false),
            .audioOnly(.assetsNotInstalled))
        // Dictation supported, assets missing.
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: false, speechLocale: nil,
                                      speechAssetsInstalled: false,
                                      dictationLocale: "en_US", dictationAssetsInstalled: false),
            .audioOnly(.assetsNotInstalled))
    }

    func testAudioOnlyNoLocale() {
        // Speech module available but the locale is unsupported, nothing else to fall to.
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: true, speechLocale: nil,
                                      speechAssetsInstalled: false,
                                      dictationLocale: nil, dictationAssetsInstalled: false),
            .audioOnly(.noLocale))
    }

    func testAudioOnlyTranscriberUnavailable() {
        // No speech module and no dictation locale.
        XCTAssertEqual(
            TranscriptionRoute.select(speechModuleAvailable: false, speechLocale: nil,
                                      speechAssetsInstalled: false,
                                      dictationLocale: nil, dictationAssetsInstalled: false),
            .audioOnly(.transcriberUnavailable))
    }

    // MARK: - journal tag

    func testJournalTagRoundTrip() {
        let routes: [TranscriptionRoute] = [
            .speech(localeID: "en_US"),
            .speech(localeID: "fr_FR"),
            .dictation(localeID: "en_US"),
            .dictation(localeID: "de_DE"),
        ] + AudioOnlyReason.allCases.map { TranscriptionRoute.audioOnly($0) }

        for route in routes {
            XCTAssertEqual(TranscriptionRoute(journalTag: route.journalTag), route, route.journalTag)
        }
        XCTAssertEqual(TranscriptionRoute.audioOnly(.notChecked).journalTag, "audioOnly:notChecked")
        XCTAssertEqual(TranscriptionRoute.audioOnly(.noLocale).journalTag, "audioOnly:noLocale")
        XCTAssertEqual(TranscriptionRoute.audioOnly(.assetsNotInstalled).journalTag,
                       "audioOnly:assetsNotInstalled")
        XCTAssertEqual(TranscriptionRoute.audioOnly(.transcriberUnavailable).journalTag,
                       "audioOnly:transcriberUnavailable")
    }

    func testJournalTagRejectsGarbage() {
        for tag in ["", "speech:", "audioOnly:nope", "fax:en_US", "speech", "audioOnly"] {
            XCTAssertNil(TranscriptionRoute(journalTag: tag), tag)
        }
    }
}
