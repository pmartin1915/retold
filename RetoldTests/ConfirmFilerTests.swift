import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class ConfirmFilerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    private final class IDs {
        private var value = 100

        func next() -> UUID {
            value += 1
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
        }
    }

    private func span(
        _ text: String,
        captureID: UUID,
        start: TimeInterval = 0
    ) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID, start: start, end: start + 1)
    }

    private func makeCapture(
        words: String? = "one two three",
        failed: Bool = false
    ) throws -> Capture {
        let capture = Capture(audioFileName: "memory.m4a", duration: 3, createdAt: now)
        context.insert(capture)
        if failed {
            try capture.updateTranscript([], status: .failed)
        } else if let words {
            try capture.completeTranscript([
                TranscriptSegment(text: words, start: 0, end: 3, isFinal: true),
            ])
        }
        try context.save()
        return capture
    }

    private func makeDraft(
        capture: Capture,
        merged: MergedExtract = MergedExtract(),
        periods: [PeriodRef] = [],
        people: [EntityRef] = [],
        places: [EntityRef] = [],
        typedTitle: String? = "A memory"
    ) -> ConfirmDraft {
        let ids = IDs()
        let merged = verified(
            merged,
            captureID: capture.id,
            periodTitles: periods.map(\.title)
        )
        var draft = ConfirmDraft.make(
            captureID: capture.id,
            outcome: .proposal(merged, TemplateAssembler.followUps(from: merged)),
            periods: periods,
            people: people,
            places: places,
            makeID: ids.next
        )
        if let typedTitle {
            draft.typedTitle = typedTitle
        }
        return draft
    }

    private func verified(
        _ seed: MergedExtract,
        captureID: UUID,
        periodTitles: [String]
    ) -> MergedExtract {
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

    private func episodeCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Episode>())
    }

    private func assertThrowsBeforeWrites(
        _ expected: ConfirmFilerError,
        draft: ConfirmDraft,
        capture: Capture,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let before = try episodeCount()
        XCTAssertThrowsError(
            try ConfirmFiler.file(draft, capture: capture, in: context, now: now),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? ConfirmFilerError, expected, file: file, line: line)
        }
        XCTAssertEqual(try episodeCount(), before, file: file, line: line)
    }

    func testWrongCaptureThrowsBeforeWrites() throws {
        let capture = try makeCapture()
        let other = Capture(audioFileName: "other.m4a", duration: 1)
        var draft = makeDraft(capture: capture)
        let ids = IDs()
        draft = ConfirmDraft.make(
            captureID: other.id,
            outcome: nil,
            periods: [],
            people: [],
            places: [],
            makeID: ids.next
        )
        draft.typedTitle = "Wrong capture"

        try assertThrowsBeforeWrites(.wrongCapture, draft: draft, capture: capture)
    }

    func testQuoteSpanFromOtherCaptureThrows() throws {
        let capture = try makeCapture()
        let foreignSpan = span("another memory", captureID: UUID())
        var merged = MergedExtract()
        merged.titleSpan = foreignSpan
        var draft = makeDraft(capture: capture, merged: merged, typedTitle: nil)
        let chipID = try XCTUnwrap(draft.titleChip?.id)
        draft.titleChip = SpanChip(
            id: chipID,
            span: foreignSpan,
            state: .accepted,
            match: nil
        )

        try assertThrowsBeforeWrites(.wrongCapture, draft: draft, capture: capture)
    }

    func testAlreadyFiledThrows() throws {
        let capture = try makeCapture()
        let filed = Episode(typedTitle: "Already filed", createdAt: now)
        context.insert(filed)
        filed.captures.append(capture)
        try context.save()

        try assertThrowsBeforeWrites(
            .alreadyFiled,
            draft: makeDraft(capture: capture),
            capture: capture
        )
    }

    func testCannotFileThrows() throws {
        let capture = try makeCapture()
        let draft = makeDraft(capture: capture, typedTitle: nil)

        try assertThrowsBeforeWrites(.cannotFile, draft: draft, capture: capture)
    }

    func testQuoteTitleIsConfirmedTranscriptQuote() throws {
        let capture = try makeCapture(words: "The lake summer")
        let title = span("The lake summer", captureID: capture.id, start: 2)
        var merged = MergedExtract()
        merged.titleSpan = title
        var draft = makeDraft(capture: capture, merged: merged, typedTitle: nil)
        draft.acceptTitle()

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.title.value, title.text)
        XCTAssertEqual(episode.title.status, .confirmed)
        XCTAssertEqual(
            episode.title.provenance,
            .transcriptQuote(captureID: capture.id, start: title.start, end: title.end)
        )
    }

    func testTypedTitleIsUserTypedAndTrimmed() throws {
        let capture = try makeCapture()
        let draft = makeDraft(capture: capture, typedTitle: "  My memory \n")

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.title.value, "My memory")
        XCTAssertEqual(episode.title.status, .confirmed)
        XCTAssertEqual(episode.title.provenance, .userTyped)
    }

    func testExcerptSetFromCapture() throws {
        let words = (1...30).map { "word\($0)" }
        let capture = try makeCapture(words: words.joined(separator: " "))

        let episode = try ConfirmFiler.file(
            makeDraft(capture: capture),
            capture: capture,
            in: context,
            now: now
        ).episode

        XCTAssertEqual(episode.excerpt, words.prefix(25).joined(separator: " "))
    }

    func testFailedCaptureFilesWithEmptyExcerpt() throws {
        let capture = try makeCapture(words: nil, failed: true)

        let episode = try ConfirmFiler.file(
            makeDraft(capture: capture),
            capture: capture,
            in: context,
            now: now
        ).episode

        XCTAssertEqual(episode.excerpt, "")
    }

    func testNewPeriodAppendsSortOrder() throws {
        context.insert(Period(title: "First", sortOrder: 3, createdAt: now))
        context.insert(Period(title: "Second", sortOrder: 8, createdAt: now))
        try context.save()
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.pick(.new("  Later years \n"))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.period?.title, "Later years")
        XCTAssertEqual(episode.period?.sortOrder, 9)
        XCTAssertEqual(episode.period?.createdAt, now)
    }

    func testEmptyNewPeriodIsNone() throws {
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.pick(.new(" \n "))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertNil(episode.period)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 0)
    }

    func testExistingPeriodAttached() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.pick(.existing(period.id))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.period?.id, period.id)
    }

    func testDeletedPeriodLeavesNone() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()
        let periodID = period.id
        context.delete(period)
        try context.save()
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.pick(.existing(periodID))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertNil(episode.period)
    }

    func testWhenYearAnswersWhenQuestion() throws {
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.setWhen(.year(1987))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.approxYear?.value, 1987)
        XCTAssertEqual(episode.approxYear?.provenance, .userTyped)
        XCTAssertEqual(episode.whenQuestion?.status, .answered)
    }

    func testWhenAgeAnswersWhenQuestion() throws {
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.setWhen(.age(12))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.approxAge?.value, 12)
        XCTAssertEqual(episode.approxAge?.provenance, .userTyped)
        XCTAssertEqual(episode.whenQuestion?.status, .answered)
    }

    func testNotSureLeavesWhenOpen() throws {
        let capture = try makeCapture()

        let episode = try ConfirmFiler.file(
            makeDraft(capture: capture),
            capture: capture,
            in: context,
            now: now
        ).episode

        XCTAssertNil(episode.approxYear)
        XCTAssertNil(episode.approxAge)
        XCTAssertEqual(episode.whenQuestion?.status, .open)
    }

    func testAcceptedPersonNewUsesSpanText() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Aunt Mara", captureID: capture.id)]
        var draft = makeDraft(capture: capture, merged: merged)
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.people.map(\.name), ["Aunt Mara"])
    }

    func testMatchedPersonReused() throws {
        let existing = Person(name: "Aunt Mara")
        context.insert(existing)
        try context.save()
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("aunt mara!", captureID: capture.id)]
        var draft = makeDraft(
            capture: capture,
            merged: merged,
            people: [EntityRef(id: existing.id, name: existing.name)]
        )
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)
        let before = try context.fetchCount(FetchDescriptor<Person>())

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.people.first?.id, existing.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), before)
    }

    func testMatchDeclinedMakesNewPerson() throws {
        let existing = Person(name: "Mara")
        context.insert(existing)
        try context.save()
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Mara", captureID: capture.id)]
        var draft = makeDraft(
            capture: capture,
            merged: merged,
            people: [EntityRef(id: existing.id, name: existing.name)]
        )
        let chipID = try XCTUnwrap(draft.people.first?.id)
        draft.setChip(chipID, .accepted)
        draft.setUseMatch(chipID, false)

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertNotEqual(episode.people.first?.id, existing.id)
        XCTAssertEqual(episode.people.first?.name, "Mara")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), 2)
    }

    func testTypedExistingAndNewPeople() throws {
        let existing = Person(name: "Luis")
        context.insert(existing)
        try context.save()
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.addTypedPerson(.existing(existing.id))
        draft.addTypedPerson(.new("  Mara \n"))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(Set(episode.people.map(\.name)), Set(["Luis", "Mara"]))
    }

    func testTypedNewReusesSameNamedPerson() throws {
        let existing = Person(name: "Mara")
        context.insert(existing)
        try context.save()
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.typedPeople = [.new(" mara! ")]

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.people.first?.id, existing.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), 1)
    }

    func testSamePersonNotDuplicated() throws {
        let existing = Person(name: "Mara")
        context.insert(existing)
        try context.save()
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Mara", captureID: capture.id)]
        var draft = makeDraft(
            capture: capture,
            merged: merged,
            people: [EntityRef(id: existing.id, name: existing.name)]
        )
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)
        draft.addTypedPerson(.existing(existing.id))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.people.map(\.id), [existing.id])
    }

    func testAcceptedPlaceAttached() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.places = [span("the lake", captureID: capture.id)]
        var draft = makeDraft(capture: capture, merged: merged)
        draft.setChip(try XCTUnwrap(draft.places.first?.id), .accepted)

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.place?.name, "the lake")
    }

    func testTypedPlaceAttached() throws {
        let capture = try makeCapture()
        var draft = makeDraft(capture: capture)
        draft.setTypedPlace(.new("  the dock \n"))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertEqual(episode.place?.name, "the dock")
    }

    func testWhoQuestionLinkedToFiledPerson() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Mara", captureID: capture.id)]
        var draft = makeDraft(capture: capture, merged: merged)
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)
        let row = try XCTUnwrap(draft.followUps.first {
            $0.question.templateID == FilingTemplates.who.id
        })

        let result = try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        XCTAssertEqual(result.questionsByRowID[row.id]?.person?.id, result.episode.people.first?.id)
    }

    func testNotThisOneRetires() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.referents = [
            VerifiedReferent(span: span("the red canoe", captureID: capture.id), kind: .object),
        ]
        var draft = makeDraft(capture: capture, merged: merged)
        let row = try XCTUnwrap(draft.followUps.first {
            $0.question.templateID == FilingTemplates.referent.id
        })
        draft.setRow(row.id, .notThisOne)

        let result = try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        XCTAssertEqual(result.questionsByRowID[row.id]?.status, .retired)
    }

    func testNonLiveRowsNotWritten() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Mara", captureID: capture.id)]
        merged.places = [span("the lake", captureID: capture.id, start: 2)]
        let draft = makeDraft(capture: capture, merged: merged)

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertFalse(episode.questions.contains { $0.templateID == FilingTemplates.who.id })
        XCTAssertFalse(episode.questions.contains { $0.templateID == FilingTemplates.sensoryPlace.id })
    }

    func testAnsweredQuestionRecorded() throws {
        let assembled = try TemplateAssembler.assemble(FilingTemplates.broad, slots: [])
        let answered = assembled.question(createdAt: now.addingTimeInterval(-10))
        context.insert(answered)
        try context.save()
        let capture = try makeCapture()
        capture.answersQuestionID = answered.id
        try context.save()

        try ConfirmFiler.file(
            makeDraft(capture: capture),
            capture: capture,
            in: context,
            now: now
        )

        XCTAssertEqual(answered.status, .answered)
    }

    func testRejectedTitleLogged() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.titleSpan = span("The lake summer", captureID: capture.id)
        var draft = makeDraft(capture: capture, merged: merged)
        draft.rejectTitle()

        try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        XCTAssertEqual(capture.rejectedProposals.map(\.kind), [.title])
        XCTAssertEqual(capture.rejectedProposals.map(\.text), ["The lake summer"])
    }

    func testRejectedPeriodLogged() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.periodTitle = period.title
        var draft = makeDraft(
            capture: capture,
            merged: merged,
            periods: [PeriodRef(id: period.id, title: period.title, sortOrder: period.sortOrder)]
        )
        draft.rejectSuggestedPeriod()

        try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        XCTAssertEqual(capture.rejectedProposals.map(\.kind), [.period])
        XCTAssertEqual(capture.rejectedProposals.map(\.text), [period.title])
    }

    func testRejectedPersonLogged() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Mara", captureID: capture.id)]
        var draft = makeDraft(capture: capture, merged: merged)
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .rejected)

        try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        XCTAssertEqual(capture.rejectedProposals.map(\.kind), [.person])
        XCTAssertEqual(capture.rejectedProposals.map(\.text), ["Mara"])
    }

    func testRejectedPlaceLogged() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.places = [span("the lake", captureID: capture.id)]
        var draft = makeDraft(capture: capture, merged: merged)
        draft.setChip(try XCTUnwrap(draft.places.first?.id), .rejected)

        try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        XCTAssertEqual(capture.rejectedProposals.map(\.kind), [.place])
        XCTAssertEqual(capture.rejectedProposals.map(\.text), ["the lake"])
    }

    func testWall2SuggestedChipsNeitherFiledNorLogged() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        try context.save()
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.titleSpan = span("The lake summer", captureID: capture.id)
        merged.periodTitle = period.title
        merged.people = [span("Mara", captureID: capture.id)]
        merged.places = [span("the lake", captureID: capture.id, start: 2)]
        let draft = makeDraft(
            capture: capture,
            merged: merged,
            periods: [PeriodRef(id: period.id, title: period.title, sortOrder: period.sortOrder)]
        )

        // Non-vacuous: the chips and the period suggestion really were offered.
        XCTAssertNotNil(draft.titleChip)
        XCTAssertNotNil(draft.suggestedPeriod)
        XCTAssertFalse(draft.people.isEmpty)
        XCTAssertFalse(draft.places.isEmpty)
        let liveTemplateIDs = draft.followUps.filter { draft.isLive($0) }.map(\.question.templateID)
        XCTAssertFalse(liveTemplateIDs.contains(FilingTemplates.who.id))
        XCTAssertFalse(liveTemplateIDs.contains(FilingTemplates.sensoryPlace.id))

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertNil(episode.period)
        XCTAssertTrue(episode.people.isEmpty)
        XCTAssertNil(episode.place)
        XCTAssertTrue(capture.rejectedProposals.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Place>()), 0)
    }

    func testWall3EveryPersistedStringHasASource() throws {
        let existingPerson = Person(name: "Mara Existing")
        let existingPlace = Place(name: "Lake Existing")
        context.insert(existingPerson)
        context.insert(existingPlace)
        try context.save()
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.people = [span("Mara Existing", captureID: capture.id)]
        merged.places = [span("Lake Existing", captureID: capture.id, start: 2)]
        var draft = makeDraft(
            capture: capture,
            merged: merged,
            people: [EntityRef(id: existingPerson.id, name: existingPerson.name)],
            places: [EntityRef(id: existingPlace.id, name: existingPlace.name)],
            typedTitle: "  User title  "
        )
        draft.pick(.new("  New period  "))
        draft.setChip(try XCTUnwrap(draft.people.first?.id), .accepted)
        draft.setChip(try XCTUnwrap(draft.places.first?.id), .accepted)
        draft.typedPeople = [.new("  Typed person  ")]

        let result = try ConfirmFiler.file(draft, capture: capture, in: context, now: now)
        let allowed = Set(
            merged.people.map(\.text) +
                merged.places.map(\.text) +
                ["User title", "New period", "Typed person", existingPerson.name, existingPlace.name] +
                [draft.whenQuestion.text] + draft.followUps.map(\.question.text)
        )
        let persisted =
            (try context.fetch(FetchDescriptor<Person>())).map(\.name) +
            (try context.fetch(FetchDescriptor<Place>())).map(\.name) +
            (try context.fetch(FetchDescriptor<Period>())).map(\.title) +
            [result.episode.title.value] + result.episode.questions.map(\.text)

        for string in persisted {
            XCTAssertTrue(allowed.contains(string), "unexpected persisted string: \(string)")
        }
        // Exact rows: the matched chips reused the existing entities; only the typed person and the
        // typed period are new.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Place>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Period>()), 1)
        XCTAssertTrue(result.episode.people.contains { $0.id == existingPerson.id })
        XCTAssertEqual(result.episode.place?.id, existingPlace.id)
        // The excerpt is the transcript's own words; nothing was rejected, so nothing was logged.
        XCTAssertEqual(result.episode.excerpt, try XCTUnwrap(capture.completedTranscript).excerpt)
        XCTAssertTrue(capture.rejectedProposals.isEmpty)
    }

    func testWall4NothingProposedPersisted() throws {
        let capture = try makeCapture(words: "The lake summer")
        var merged = MergedExtract()
        merged.titleSpan = span("The lake summer", captureID: capture.id)
        var draft = makeDraft(capture: capture, merged: merged, typedTitle: nil)
        draft.acceptTitle()

        try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        let reopened = ModelContext(container)
        let episode = try XCTUnwrap(reopened.fetch(FetchDescriptor<Episode>()).first)
        XCTAssertEqual(episode.title.status, .confirmed)
    }

    func testWall5WheelDefaultFilesNoYear() throws {
        let capture = try makeCapture()
        let draft = makeDraft(capture: capture)

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode

        XCTAssertNil(episode.approxYear)
        XCTAssertNil(episode.approxAge)
        XCTAssertEqual(episode.whenQuestion?.status, .open)
    }

    func testWall6QuestionsAreDeckOrigin() throws {
        let capture = try makeCapture()
        var merged = MergedExtract()
        merged.referents = [
            VerifiedReferent(span: span("the red canoe", captureID: capture.id), kind: .object),
        ]
        let draft = makeDraft(capture: capture, merged: merged)

        let episode = try ConfirmFiler.file(draft, capture: capture, in: context, now: now).episode
        let deckIDs = Set(QuestionDeck.all.map(\.id))

        XCTAssertFalse(episode.questions.isEmpty)
        for question in episode.questions {
            XCTAssertEqual(question.origin, .deck)
            XCTAssertTrue(deckIDs.contains(question.templateID))
        }
    }
}
