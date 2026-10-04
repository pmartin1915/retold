import Foundation
import XCTest
@testable import Retold

@MainActor
final class ConfirmDraftTests: XCTestCase {
    private let captureID = UUID()

    private final class IDs {
        private var value = 0

        func next() -> UUID {
            value += 1
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
        }
    }

    private func span(_ text: String, start: TimeInterval = 0) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID, start: start, end: start + 1)
    }

    private func verified(_ seed: MergedExtract, periodTitles: [String]) -> MergedExtract {
        var spans = seed.people + seed.places + seed.timeCues + seed.referents.map(\.span)
        if let title = seed.titleSpan { spans.append(title) }
        var unique: [VerifiedSpan] = []
        for span in spans where !unique.contains(span) {
            unique.append(span)
        }
        let segments = unique.sorted {
            ($0.start, $0.end, $0.text) < ($1.start, $1.end, $1.text)
        }.map {
            TranscriptSegment(text: $0.text, start: $0.start, end: $0.end, isFinal: true)
        }
        let transcript = CompletedTranscript.fixture(captureID: captureID, segments: segments)
        let window = transcript.window(segments.indices)
        let extract = WindowExtract(
            periodName: seed.periodTitle,
            people: seed.people.map(\.text),
            places: seed.places.map(\.text),
            timeCues: seed.timeCues.map(\.text),
            referents: seed.referents.map { RawReferent(span: $0.span.text, kind: $0.kind) },
            titleSpan: seed.titleSpan?.text
        )
        return ExtractMerger.merge([(window, extract)], periodTitles: periodTitles)
    }

    private func makeDraft(
        merged: MergedExtract = MergedExtract(),
        periods: [PeriodRef] = [],
        people: [EntityRef] = [],
        places: [EntityRef] = []
    ) -> ConfirmDraft {
        let ids = IDs()
        let merged = verified(merged, periodTitles: periods.map(\.title))
        return ConfirmDraft.make(
            captureID: captureID,
            outcome: .proposal(merged, TemplateAssembler.followUps(from: merged)),
            periods: periods,
            people: people,
            places: places,
            makeID: ids.next
        )
    }

    func testNoOutcomeGivesWhenOpenAndBroadOnly() {
        let ids = IDs()
        let draft = ConfirmDraft.make(
            captureID: captureID,
            outcome: nil,
            periods: [],
            people: [],
            places: [],
            makeID: ids.next
        )

        XCTAssertNil(draft.titleChip)
        XCTAssertNil(draft.suggestedPeriod)
        XCTAssertTrue(draft.people.isEmpty)
        XCTAssertTrue(draft.places.isEmpty)
        XCTAssertEqual(draft.whenQuestion.templateID, FilingTemplates.when.id)
        XCTAssertEqual(draft.followUps.map(\.question.templateID), [FilingTemplates.broad.id])
    }

    func testNoModelOutcomeEqualsNoOutcome() {
        let nilIDs = IDs()
        let noModelIDs = IDs()
        let withoutOutcome = ConfirmDraft.make(
            captureID: captureID,
            outcome: nil,
            periods: [],
            people: [],
            places: [],
            makeID: nilIDs.next
        )
        let withoutModel = ConfirmDraft.make(
            captureID: captureID,
            outcome: .noModel(.other),
            periods: [],
            people: [],
            places: [],
            makeID: noModelIDs.next
        )

        XCTAssertEqual(withoutModel, withoutOutcome)
    }

    func testProposalSplitsWhenQuestionFromRows() {
        var merged = MergedExtract()
        merged.people = [span("Mara")]
        let draft = makeDraft(merged: merged)

        XCTAssertEqual(draft.whenQuestion.templateID, FilingTemplates.when.id)
        XCTAssertFalse(draft.followUps.contains { $0.question.templateID == FilingTemplates.when.id })
        XCTAssertEqual(
            draft.followUps.map(\.question.templateID),
            [FilingTemplates.broad.id, FilingTemplates.who.id]
        )
    }

    func testWhenCueChosenWhenTimeCueVerified() {
        var merged = MergedExtract()
        merged.timeCues = [span("the summer before eighth grade")]

        let draft = makeDraft(merged: merged)

        XCTAssertEqual(draft.whenQuestion.templateID, FilingTemplates.whenWithCue.id)
        XCTAssertEqual(draft.whenQuestion.slots, merged.timeCues)
    }

    func testFunctionWordCueFallsBackToWhenOpen() {
        var merged = MergedExtract()
        merged.timeCues = [span("then")]

        let draft = makeDraft(merged: merged)

        XCTAssertEqual(draft.whenQuestion.templateID, FilingTemplates.when.id)
        XCTAssertTrue(draft.whenQuestion.slots.isEmpty)
    }

    func testFunctionWordPersonSpanGivesNoChip() {
        var merged = MergedExtract()
        merged.people = [span("he")]

        XCTAssertTrue(makeDraft(merged: merged).people.isEmpty)
    }

    func testSuggestedPeriodResolvesByExactTitle() {
        var merged = MergedExtract()
        merged.periodTitle = "High school"
        let exact = PeriodRef(id: UUID(), title: "High school", sortOrder: 1)
        let differentCase = PeriodRef(id: UUID(), title: "HIGH SCHOOL", sortOrder: 0)
        let verified = verified(merged, periodTitles: [exact.title])
        let ids = IDs()

        let draft = ConfirmDraft.make(
            captureID: captureID,
            outcome: .proposal(verified, TemplateAssembler.followUps(from: verified)),
            periods: [differentCase, exact],
            people: [],
            places: [],
            makeID: ids.next
        )

        XCTAssertEqual(draft.suggestedPeriod, exact)
    }

    func testSuggestedPeriodIsNotPrePicked() {
        var merged = MergedExtract()
        merged.periodTitle = "High school"
        let period = PeriodRef(id: UUID(), title: "High school", sortOrder: 0)

        let draft = makeDraft(merged: merged, periods: [period])

        XCTAssertEqual(draft.periodSuggestionState, .suggested)
        XCTAssertEqual(draft.periodPick, .none)
    }

    func testAcceptSuggestedPeriodPicks() {
        var merged = MergedExtract()
        merged.periodTitle = "High school"
        let period = PeriodRef(id: UUID(), title: "High school", sortOrder: 0)
        var draft = makeDraft(merged: merged, periods: [period])

        draft.acceptSuggestedPeriod()

        XCTAssertEqual(draft.periodSuggestionState, .accepted)
        XCTAssertEqual(draft.periodPick, .existing(period.id))
    }

    func testPickingSuggestedIdAccepts() {
        var merged = MergedExtract()
        merged.periodTitle = "High school"
        let period = PeriodRef(id: UUID(), title: "High school", sortOrder: 0)
        var draft = makeDraft(merged: merged, periods: [period])

        draft.pick(.existing(period.id))

        XCTAssertEqual(draft.periodSuggestionState, .accepted)
        XCTAssertEqual(draft.periodPick, .existing(period.id))
    }

    func testPickingAnotherPeriodUnacceptsSuggestion() {
        var merged = MergedExtract()
        merged.periodTitle = "High school"
        let suggested = PeriodRef(id: UUID(), title: "High school", sortOrder: 0)
        let other = PeriodRef(id: UUID(), title: "Twenties", sortOrder: 1)
        var draft = makeDraft(merged: merged, periods: [suggested, other])
        draft.acceptSuggestedPeriod()

        draft.pick(.existing(other.id))

        XCTAssertEqual(draft.periodSuggestionState, .suggested)
        XCTAssertEqual(draft.periodPick, .existing(other.id))
    }

    func testRejectingSuggestedPeriodClearsPick() {
        var merged = MergedExtract()
        merged.periodTitle = "High school"
        let period = PeriodRef(id: UUID(), title: "High school", sortOrder: 0)
        var draft = makeDraft(merged: merged, periods: [period])
        draft.acceptSuggestedPeriod()

        draft.rejectSuggestedPeriod()

        XCTAssertEqual(draft.periodSuggestionState, .rejected)
        XCTAssertEqual(draft.periodPick, .none)
    }

    func testPersonMatchByName() {
        var merged = MergedExtract()
        merged.people = [span("Aunt Mara")]
        let person = EntityRef(id: UUID(), name: "aunt mara!")

        let draft = makeDraft(merged: merged, people: [person])

        XCTAssertEqual(draft.people.first?.match, person)
        XCTAssertEqual(draft.people.first?.useMatch, true)
    }

    func testSetUseMatch() throws {
        var merged = MergedExtract()
        merged.people = [span("Mara")]
        let person = EntityRef(id: UUID(), name: "Mara")
        var draft = makeDraft(merged: merged, people: [person])
        let chipID = try XCTUnwrap(draft.people.first?.id)

        draft.setUseMatch(chipID, false)

        XCTAssertEqual(draft.people.first?.useMatch, false)
    }

    func testPlaceAcceptIsSingleSelect() throws {
        var merged = MergedExtract()
        merged.places = [span("the lake"), span("the cabin", start: 2)]
        var draft = makeDraft(merged: merged)
        let first = try XCTUnwrap(draft.places.first?.id)
        let second = try XCTUnwrap(draft.places.last?.id)

        draft.setChip(first, .accepted)
        draft.setChip(second, .accepted)

        XCTAssertEqual(draft.places.map(\.state), [.suggested, .accepted])
    }

    func testTypedPlaceClearsAcceptedChip() throws {
        var merged = MergedExtract()
        merged.places = [span("the lake")]
        var draft = makeDraft(merged: merged)
        draft.setChip(try XCTUnwrap(draft.places.first?.id), .accepted)

        draft.setTypedPlace(.new("the dock"))

        XCTAssertEqual(draft.places.first?.state, .suggested)
        XCTAssertEqual(draft.typedPlace, .new("the dock"))
    }

    func testEmptyTypedPlaceIsNil() {
        var draft = makeDraft()
        draft.setTypedPlace(.new(" \n "))
        XCTAssertNil(draft.typedPlace)
    }

    func testTypedPersonDedup() {
        var draft = makeDraft()
        let existingID = UUID()

        draft.addTypedPerson(.existing(existingID))
        draft.addTypedPerson(.existing(existingID))
        draft.addTypedPerson(.new("Aunt Mara"))
        draft.addTypedPerson(.new(" aunt mara! "))

        XCTAssertEqual(draft.typedPeople, [.existing(existingID), .new("Aunt Mara")])
    }

    func testTypedPersonMatchingChipIgnored() throws {
        var merged = MergedExtract()
        merged.people = [span("Mara")]
        var draft = makeDraft(merged: merged)
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)

        draft.addTypedPerson(.new("mara!"))

        XCTAssertTrue(draft.typedPeople.isEmpty)
    }

    func testTypedPersonMatchingExistingNameIgnored() {
        let person = EntityRef(id: UUID(), name: "Mara")
        var draft = makeDraft(people: [person])

        draft.addTypedPerson(.new("mara!"))

        XCTAssertTrue(draft.typedPeople.isEmpty)
    }

    func testEmptyTypedPersonIgnored() {
        var draft = makeDraft()
        draft.addTypedPerson(.new(" \n "))
        XCTAssertTrue(draft.typedPeople.isEmpty)
    }

    func testRemoveTypedPerson() {
        var draft = makeDraft()
        draft.addTypedPerson(.new("Mara"))
        draft.addTypedPerson(.new("Luis"))

        draft.removeTypedPerson(at: 0)

        XCTAssertEqual(draft.typedPeople, [.new("Luis")])
        draft.removeTypedPerson(at: 5)
        XCTAssertEqual(draft.typedPeople, [.new("Luis")])
    }

    func testTypedTitleWinsOverChip() throws {
        var merged = MergedExtract()
        merged.titleSpan = span("The lake summer")
        var draft = makeDraft(merged: merged)
        draft.acceptTitle()
        draft.typedTitle = "  My title \n"

        XCTAssertEqual(draft.resolvedTitle, .typed("My title"))
    }

    func testWhitespaceTitleCannotFile() {
        var draft = makeDraft()
        draft.typedTitle = " \n "
        XCTAssertFalse(draft.canFile)
    }

    func testSuggestedTitleCannotFile() {
        var merged = MergedExtract()
        merged.titleSpan = span("The lake summer")
        XCTAssertFalse(makeDraft(merged: merged).canFile)
    }

    func testWhenDefaultsToNotSure() {
        XCTAssertEqual(makeDraft().when, .notSure)
    }

    func testWhoRowLiveOnlyWithAcceptedPerson() throws {
        var merged = MergedExtract()
        merged.people = [span("Mara")]
        var draft = makeDraft(merged: merged)
        let row = try XCTUnwrap(draft.followUps.first {
            $0.question.templateID == FilingTemplates.who.id
        })
        XCTAssertFalse(draft.isLive(row))

        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)

        XCTAssertTrue(draft.isLive(row))
    }

    func testSensoryRowLiveOnlyWithAcceptedPlace() throws {
        var merged = MergedExtract()
        merged.places = [span("the lake")]
        var draft = makeDraft(merged: merged)
        let row = try XCTUnwrap(draft.followUps.first {
            $0.question.templateID == FilingTemplates.sensoryPlace.id
        })
        XCTAssertFalse(draft.isLive(row))

        draft.setChip(try XCTUnwrap(draft.places.first?.id), .accepted)

        XCTAssertTrue(draft.isLive(row))
    }
}
