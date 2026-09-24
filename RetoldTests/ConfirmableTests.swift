import Foundation
import XCTest
@testable import Retold

@MainActor
final class ConfirmableTests: XCTestCase {
    private func makeSpan() -> VerifiedSpan {
        VerifiedSpan(text: "the lake", captureID: UUID(), start: 1.5, end: 3.0)
    }

    func testFactoriesSetStatusAndProvenance() {
        let span = makeSpan()
        let byModel = Confirmable<String>.proposedByModel("M")
        XCTAssertEqual(byModel.value, "M")
        XCTAssertEqual(byModel.status, .proposed)
        XCTAssertEqual(byModel.provenance, .model)

        let byDeck = Confirmable<String>.proposedByDeck("D", promptID: "deck.1")
        XCTAssertEqual(byDeck.status, .proposed)
        XCTAssertEqual(byDeck.provenance, .deck(promptID: "deck.1"))

        let quote = Confirmable<String>.proposedQuote("Q", span: span)
        XCTAssertEqual(quote.status, .proposed)
        XCTAssertEqual(
            quote.provenance,
            .transcriptQuote(captureID: span.captureID, start: span.start, end: span.end)
        )

        let typed = Confirmable<String>.userTyped("T")
        XCTAssertEqual(typed.status, .confirmed)
        XCTAssertEqual(typed.provenance, .userTyped)
    }

    func testConfirmModelProposalBecomesUserConfirmed() {
        var byModel = Confirmable<Int>.proposedByModel(42)
        XCTAssertTrue(byModel.confirm())
        XCTAssertEqual(byModel.status, .confirmed)
        XCTAssertEqual(byModel.provenance, .userConfirmed(proposedBy: .model))

        var byDeck = Confirmable<Int>.proposedByDeck(7, promptID: "deck.when")
        XCTAssertTrue(byDeck.confirm())
        XCTAssertEqual(byDeck.status, .confirmed)
        XCTAssertEqual(byDeck.provenance, .userConfirmed(proposedBy: .deck))
    }

    func testConfirmQuoteKeepsQuoteProvenance() {
        let span = makeSpan()
        var quote = Confirmable<String>.proposedQuote("Q", span: span)
        XCTAssertTrue(quote.confirm())
        XCTAssertEqual(quote.status, .confirmed)
        XCTAssertEqual(
            quote.provenance,
            .transcriptQuote(captureID: span.captureID, start: span.start, end: span.end)
        )
    }

    func testConfirmAndRejectOnlyFromProposed() {
        var confirmed = Confirmable<String>.userTyped("C")
        let confirmedBefore = confirmed
        XCTAssertFalse(confirmed.confirm())
        XCTAssertEqual(confirmed, confirmedBefore)
        XCTAssertFalse(confirmed.reject())
        XCTAssertEqual(confirmed, confirmedBefore)

        var rejected = Confirmable<String>.proposedByModel("R")
        XCTAssertTrue(rejected.reject())
        XCTAssertEqual(rejected.status, .rejected)
        let rejectedBefore = rejected
        XCTAssertFalse(rejected.confirm())
        XCTAssertEqual(rejected, rejectedBefore)
        XCTAssertFalse(rejected.reject())
        XCTAssertEqual(rejected, rejectedBefore)
    }

    func testReplaceByUserFromEveryState() {
        let proposed = Confirmable<String>.proposedByModel("v")
        var confirmed = Confirmable<String>.proposedByModel("v")
        XCTAssertTrue(confirmed.confirm())
        var rejected = Confirmable<String>.proposedByModel("v")
        XCTAssertTrue(rejected.reject())

        var states = [proposed, confirmed, rejected]
        for index in states.indices {
            states[index].replaceByUser("typed")
            XCTAssertEqual(states[index].value, "typed")
            XCTAssertEqual(states[index].status, .confirmed)
            XCTAssertEqual(states[index].provenance, .userTyped)
        }
    }

    func testNoReachableStateIsConfirmedModel() {
        let span = makeSpan()
        let factories: [() -> Confirmable<String>] = [
            { .proposedByModel("v") },
            { .proposedByDeck("v", promptID: "p") },
            { .proposedQuote("v", span: span) },
            { .userTyped("v") },
        ]
        let operations: [(inout Confirmable<String>) -> Void] = [
            { $0.confirm() },
            { $0.reject() },
            { $0.replaceByUser("u") },
        ]
        for make in factories {
            for op1 in operations {
                for op2 in operations {
                    for op3 in operations {
                        var c = make()
                        op1(&c)
                        op2(&c)
                        op3(&c)
                        XCTAssertTrue(
                            Confirmable<String>.isValid(status: c.status, provenance: c.provenance),
                            "factory loop reached invalid state"
                        )
                        XCTAssertFalse(
                            c.status == .confirmed && c.provenance == .model,
                            "reached .confirmed with .model provenance"
                        )
                    }
                }
            }
        }
    }

    func testDecodingConfirmedModelThrows() throws {
        let json = """
            {"value": 3, "status": "confirmed", "stored": {"kind": "model"}}
            """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Confirmable<Int>.self, from: json)) { error in
            XCTAssertEqual(error as? ConfirmableDecodingError, .invalidStatusProvenance)
        }
    }

    func testDecodingMalformedProvenanceThrows() throws {
        let missingPromptID = """
            {"value": 3, "status": "proposed", "stored": {"kind": "deck"}}
            """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Confirmable<Int>.self, from: missingPromptID)) { error in
            XCTAssertEqual(error as? ConfirmableDecodingError, .malformedProvenance)
        }

        let missingProposedBy = """
            {"value": 3, "status": "proposed", "stored": {"kind": "userConfirmed"}}
            """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Confirmable<Int>.self, from: missingProposedBy)) { error in
            XCTAssertEqual(error as? ConfirmableDecodingError, .malformedProvenance)
        }
    }

    func testDecodingConfirmedDeckProposalThrows() throws {
        let json = """
            {"value": "x", "status": "confirmed", "stored": {"kind": "deck", "promptID": "p"}}
            """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Confirmable<String>.self, from: json)) { error in
            XCTAssertEqual(error as? ConfirmableDecodingError, .invalidStatusProvenance)
        }
    }

    func testIsValidMatchesTable() {
        let quote = Provenance.transcriptQuote(captureID: UUID(), start: 0, end: 1)
        let deck = Provenance.deck(promptID: "p")
        let confirmedByModel = Provenance.userConfirmed(proposedBy: .model)
        let confirmedByDeck = Provenance.userConfirmed(proposedBy: .deck)

        // .proposed and .reject allow .model/.deck/.transcriptQuote only.
        for provenance in [Provenance.model, deck, quote] {
            XCTAssertTrue(Confirmable<Int>.isValid(status: .proposed, provenance: provenance))
            XCTAssertTrue(Confirmable<Int>.isValid(status: .rejected, provenance: provenance))
        }
        for provenance in [Provenance.userTyped, confirmedByModel, confirmedByDeck] {
            XCTAssertFalse(Confirmable<Int>.isValid(status: .proposed, provenance: provenance))
            XCTAssertFalse(Confirmable<Int>.isValid(status: .rejected, provenance: provenance))
        }

        // .confirmed allows .userTyped/.userConfirmed/.transcriptQuote only.
        for provenance in [Provenance.userTyped, confirmedByModel, confirmedByDeck, quote] {
            XCTAssertTrue(Confirmable<Int>.isValid(status: .confirmed, provenance: provenance))
        }
        for provenance in [Provenance.model, deck] {
            XCTAssertFalse(Confirmable<Int>.isValid(status: .confirmed, provenance: provenance))
        }
    }

    func testStoredProvenanceRoundTripsEveryCase() {
        let captureID = UUID()
        let cases: [Provenance] = [
            .userTyped,
            .userConfirmed(proposedBy: .model),
            .userConfirmed(proposedBy: .deck),
            .transcriptQuote(captureID: captureID, start: 1.25, end: 4.5),
            .model,
            .deck(promptID: "deck.title"),
        ]
        for p in cases {
            XCTAssertEqual(StoredProvenance(p).provenance, p)
        }
    }
}
