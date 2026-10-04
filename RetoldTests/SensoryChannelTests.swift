import Foundation
import XCTest
@testable import Retold

@MainActor
final class SensoryChannelTests: XCTestCase {
    private func mentioned(_ text: String) -> Set<SensoryChannel> {
        SensoryChannel.mentioned(in: [text])
    }

    func testOneSentencePerChannel() {
        XCTAssertEqual(mentioned("The noise of the gulls"), [.sound])
        XCTAssertEqual(mentioned("It smelled of pine"), [.smell])
        XCTAssertEqual(mentioned("That flavour"), [.taste])
        XCTAssertEqual(mentioned("The light was orange"), [.sight])
        XCTAssertEqual(mentioned("I wore my coat"), [.clothing])
        XCTAssertEqual(mentioned("It was raining"), [.weather])
    }

    func testSeeingAndHearingAboutAreNotMentions() {
        // "you see", "look", "kids playing" — not the user describing a sense.
        XCTAssertEqual(mentioned("You see, look, the kids were playing"), [])
        // "I heard he left", "I saw my dad", "I caught a cold" — same.
        XCTAssertEqual(mentioned("I heard he left, I saw my dad, I caught a cold"), [])
    }

    func testPunctuationAndCase() {
        XCTAssertEqual(mentioned("SMELL,"), [.smell])
    }

    func testEmptyInputMentionsNothing() {
        XCTAssertEqual(SensoryChannel.mentioned(in: []), [])
        XCTAssertEqual(mentioned("   "), [])
    }

    func testTwoChannelsInOneText() {
        XCTAssertEqual(mentioned("The noise of the boats and the rain"), [.sound, .weather])
    }

    func testWordCountsOnceAcrossTexts() {
        XCTAssertEqual(SensoryChannel.mentioned(in: ["the song", "the song, the songs"]), [.sound])
    }
}
