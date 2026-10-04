import Foundation
import XCTest
@testable import Retold

@MainActor
final class QuestionChannelTests: XCTestCase {
    func testEveryDeckIDMapsToItsChannel() {
        // Literal 25-row table (docs/R4-ENGINE-SPEC.md section 3).
        let table: [(id: String, channel: QuestionChannel)] = [
            ("broad.open", .open), ("period.else", .open), ("period.slot", .open), ("event.else", .open),
            ("when.open", .time), ("when.cue", .time), ("event.shape", .time),
            ("period.where", .place),
            ("who.person", .people), ("period.who", .people), ("event.anyone", .people),
            ("people.describe", .people), ("people.talk", .people), ("people.together", .people),
            ("sensory.place", .sensory), ("sensory.everything", .sensory), ("sensory.mentioned", .sensory),
            ("referent.open", .referent),
            ("sequence.connect", .sequence), ("sequence.otherTimes", .sequence),
            ("theme.turningPoint", .theme), ("theme.family", .theme), ("theme.work", .theme),
            ("theme.body", .theme), ("theme.close", .theme),
        ]
        XCTAssertEqual(table.count, 25)
        for row in table {
            XCTAssertEqual(
                QuestionChannel.of(templateID: row.id, cue: .event),
                row.channel,
                row.id
            )
        }
    }

    func testUnknownIDFallsBackByCue() {
        XCTAssertEqual(QuestionChannel.of(templateID: "x", cue: .period), .open)
        XCTAssertEqual(QuestionChannel.of(templateID: "x", cue: .event), .open)
        XCTAssertEqual(QuestionChannel.of(templateID: "x", cue: .sensory), .sensory)
        XCTAssertEqual(QuestionChannel.of(templateID: "x", cue: .people), .people)
        XCTAssertEqual(QuestionChannel.of(templateID: "x", cue: .sequence), .sequence)
    }

    func testDeckTemplateLookup() {
        let eventElse = QuestionDeck.template(id: "event.else")
        XCTAssertEqual(eventElse?.pattern, "Is there anything else about that?")
        XCTAssertEqual(eventElse?.cue, .event)
        XCTAssertEqual(QuestionDeck.template(id: "broad.open")?.cue, .event)
        XCTAssertNil(QuestionDeck.template(id: "no.such.template"))
    }

    func testEngineTemplateListsAreInSpecOrder() {
        XCTAssertEqual(QuestionEngine.episodeTemplates.map(\.id), [
            "referent.open", "event.else", "event.shape", "event.anyone",
            "sensory.mentioned", "sensory.place", "sensory.everything",
            "sequence.connect", "sequence.otherTimes",
        ])
        XCTAssertEqual(QuestionEngine.personTemplates.map(\.id), [
            "who.person", "people.describe", "people.talk", "people.together",
        ])
        XCTAssertEqual(QuestionEngine.periodTemplates.map(\.id), [
            "period.else", "period.who", "period.where",
        ])
    }
}
