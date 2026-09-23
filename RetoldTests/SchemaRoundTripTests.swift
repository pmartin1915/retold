import Foundation
import SwiftData
import XCTest
@testable import Retold

/// The R1 spike: persist every entity and every provenance case through in-memory and
/// on-disk ModelContainers, reopen the on-disk store in a fresh container, and compare
/// field by field (docs/R1-DATAMODEL-SPEC.md sections 3-4).
@MainActor
final class SchemaRoundTripTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    /// The all-entities fixture's title: a verified quote, never model text (Rule 1).
    private let titleSpan = VerifiedSpan(
        text: "The last day of camp",
        captureID: UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE") ?? UUID(),
        start: 2,
        end: 4
    )

    // No setUp/tearDown overrides: a @MainActor test class can't override XCTest's
    // nonisolated synchronous ones in Swift 6. Each test gets its own directory here, and a
    // teardown block (URL is Sendable) removes it.
    private func storeURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("r1.store")
    }

    // MARK: - Fixtures

    private var transcriptWords: [String] { (1...40).map { "w\($0)" } }

    private var expectedExcerpt: String { transcriptWords[0..<25].joined(separator: " ") }

    private func makeTranscript() -> [TranscriptSegment] {
        let words = transcriptWords
        return [
            TranscriptSegment(text: words[0..<15].joined(separator: " "), start: 0, end: 5, isFinal: true),
            TranscriptSegment(text: words[15..<30].joined(separator: " "), start: 5, end: 10, isFinal: true),
            TranscriptSegment(text: words[30..<40].joined(separator: " "), start: 10, end: 14, isFinal: false),
        ]
    }

    private struct GraphIDs {
        let periodID: UUID
        let episodeID: UUID
        let person1ID: UUID
        let person2ID: UUID
        let placeID: UUID
        let captureID: UUID
        let detailQuoteID: UUID
        let detailTypedID: UUID
        let whenQuestionID: UUID
        let followUpQuestionID: UUID
    }

    /// Builds the fully populated graph from the OWNING sides of the relationships only,
    /// then saves. Returns plain ids so the caller (or a later phase) can re-fetch.
    @discardableResult
    private func makeFullGraph(context: ModelContext) throws -> GraphIDs {
        let transcript = makeTranscript()

        let period = Period(title: "Camp Lakeview summers", sortOrder: 2, createdAt: fixedDate)
        period.approxStartAge = Confirmable.userTyped(9)
        period.approxEndAge = Confirmable.proposedByModel(14)
        context.insert(period)

        let person1 = Person(name: "Dan")
        person1.aliases = ["Danny", "Daniel"]
        person1.note = "Met at camp"
        let person2 = Person(name: "Ruth")
        context.insert(person1)
        context.insert(person2)

        let place = Place(name: "Lakeview dock")
        context.insert(place)

        let episode = Episode(titleQuote: titleSpan, createdAt: fixedDate)
        episode.people.append(person1)
        episode.people.append(person2)
        episode.place = place
        context.insert(episode)
        period.episodes.append(episode)

        let capture = Capture(audioFileName: "recordings/2026/camp-last-day.m4a", duration: 42.5, createdAt: fixedDate)
        try capture.updateTranscript(transcript, status: .live)
        try capture.completeTranscript(transcript)
        try capture.addCorrection(segmentIndex: 0, correctedText: "w1 fixed", at: Date(timeIntervalSince1970: 1_700_000_100))
        capture.logRejected(.person, text: "Sara", at: Date(timeIntervalSince1970: 1_700_000_200))
        episode.captures.append(capture)
        episode.setExcerpt(from: transcript)

        let quoteSpan = VerifiedSpan(text: "w3 w4", captureID: capture.id, start: 0.5, end: 1.5)
        let detailQuote = Detail(quote: quoteSpan, kind: .sensory)
        let detailTyped = Detail(typed: "It rained that afternoon.", kind: .emotion)
        context.insert(detailQuote)
        context.insert(detailTyped)
        episode.details.append(detailQuote)
        episode.details.append(detailTyped)

        let whenQuestion = Question(
            text: "Roughly when was this — a year, or how old you were?",
            templateID: "deck.when.v1",
            slots: [],
            cue: .event,
            origin: .deck,
            createdAt: fixedDate
        )
        let followUp = Question(
            text: "You said 'w3 w4' — anything else about that?",
            templateID: "deck.referent.v1",
            slots: [quoteSpan],
            cue: .event,
            origin: .deck,
            createdAt: fixedDate
        )
        context.insert(whenQuestion)
        context.insert(followUp)
        episode.questions.append(whenQuestion)
        episode.questions.append(followUp)
        episode.setWhenQuestion(whenQuestion)
        episode.answerWhen(year: 1998)
        episode.answerWhen(age: 13)

        // One-way Question refs (no inverse) and Capture's question back-reference.
        whenQuestion.period = period
        followUp.person = person1
        capture.answersQuestionID = followUp.id

        try context.save()
        return GraphIDs(
            periodID: period.id,
            episodeID: episode.id,
            person1ID: person1.id,
            person2ID: person2.id,
            placeID: place.id,
            captureID: capture.id,
            detailQuoteID: detailQuote.id,
            detailTypedID: detailTyped.id,
            whenQuestionID: whenQuestion.id,
            followUpQuestionID: followUp.id
        )
    }

    // MARK: - Fetch helpers

    private func fetchPeriod(id: UUID, in context: ModelContext) throws -> Period {
        let results = try context.fetch(FetchDescriptor<Period>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    private func fetchEpisode(id: UUID, in context: ModelContext) throws -> Episode {
        let results = try context.fetch(FetchDescriptor<Episode>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    private func fetchDetail(id: UUID, in context: ModelContext) throws -> Detail {
        let results = try context.fetch(FetchDescriptor<Detail>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    private func fetchPerson(id: UUID, in context: ModelContext) throws -> Person {
        let results = try context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    private func fetchPlace(id: UUID, in context: ModelContext) throws -> Place {
        let results = try context.fetch(FetchDescriptor<Place>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    private func fetchCapture(id: UUID, in context: ModelContext) throws -> Capture {
        let results = try context.fetch(FetchDescriptor<Capture>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    private func fetchQuestion(id: UUID, in context: ModelContext) throws -> Question {
        let results = try context.fetch(FetchDescriptor<Question>(predicate: #Predicate { $0.id == id }))
        XCTAssertEqual(results.count, 1)
        return results[0]
    }

    // MARK: - Comparison helpers

    private func assertDatesEqual(
        _ a: Date, _ b: Date, _ message: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a.timeIntervalSince1970, b.timeIntervalSince1970, accuracy: 0.001, message, file: file, line: line)
    }

    private func assertConfirmableEqual<T: Codable & Hashable & Sendable>(
        _ a: Confirmable<T>?, _ b: Confirmable<T>?, _ message: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        switch (a, b) {
        case (.none, .none):
            break
        case (.some(let x), .some(let y)):
            XCTAssertEqual(x.value, y.value, message, file: file, line: line)
            XCTAssertEqual(x.status, y.status, message, file: file, line: line)
            XCTAssertEqual(x.provenance, y.provenance, message, file: file, line: line)
        default:
            XCTFail("\(message): one nil, one non-nil", file: file, line: line)
        }
    }

    /// Compares the fully populated graph against the constants used to build it.
    private func assertFullGraph(
        context: ModelContext, ids: GraphIDs,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let period = try fetchPeriod(id: ids.periodID, in: context)
        XCTAssertEqual(period.title, "Camp Lakeview summers", file: file, line: line)
        assertConfirmableEqual(period.approxStartAge, Confirmable.userTyped(9), "period.approxStartAge", file: file, line: line)
        assertConfirmableEqual(period.approxEndAge, Confirmable.proposedByModel(14), "period.approxEndAge", file: file, line: line)
        XCTAssertEqual(period.sortOrder, 2, file: file, line: line)
        assertDatesEqual(period.createdAt, fixedDate, "period.createdAt", file: file, line: line)
        XCTAssertEqual(Set(period.episodes.map(\.id)), [ids.episodeID], file: file, line: line)

        let episode = try fetchEpisode(id: ids.episodeID, in: context)
        assertConfirmableEqual(
            episode.title, Confirmable.proposedQuote(span: titleSpan), "episode.title",
            file: file, line: line
        )
        XCTAssertEqual(episode.whenQuestionID, ids.whenQuestionID, file: file, line: line)
        assertConfirmableEqual(episode.approxYear, Confirmable.userTyped(1998), "episode.approxYear", file: file, line: line)
        assertConfirmableEqual(episode.approxAge, Confirmable.userTyped(13), "episode.approxAge", file: file, line: line)
        XCTAssertEqual(episode.period?.id, ids.periodID, file: file, line: line)
        XCTAssertEqual(episode.place?.id, ids.placeID, file: file, line: line)
        XCTAssertEqual(Set(episode.people.map(\.id)), [ids.person1ID, ids.person2ID], file: file, line: line)
        XCTAssertEqual(Set(episode.captures.map(\.id)), [ids.captureID], file: file, line: line)
        XCTAssertEqual(Set(episode.details.map(\.id)), [ids.detailQuoteID, ids.detailTypedID], file: file, line: line)
        XCTAssertEqual(Set(episode.questions.map(\.id)), [ids.whenQuestionID, ids.followUpQuestionID], file: file, line: line)
        XCTAssertEqual(episode.excerpt, expectedExcerpt, file: file, line: line)
        assertDatesEqual(episode.createdAt, fixedDate, "episode.createdAt", file: file, line: line)

        let capture = try fetchCapture(id: ids.captureID, in: context)
        XCTAssertEqual(capture.audioFileName, "recordings/2026/camp-last-day.m4a", file: file, line: line)
        XCTAssertEqual(capture.duration, 42.5, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(capture.transcript, makeTranscript(), file: file, line: line)
        XCTAssertEqual(capture.transcriptionStatus, .complete, file: file, line: line)
        XCTAssertEqual(capture.corrections.count, 1, file: file, line: line)
        XCTAssertEqual(capture.corrections[0].segmentIndex, 0, file: file, line: line)
        XCTAssertEqual(capture.corrections[0].originalText, transcriptWords[0..<15].joined(separator: " "), file: file, line: line)
        XCTAssertEqual(capture.corrections[0].correctedText, "w1 fixed", file: file, line: line)
        assertDatesEqual(capture.corrections[0].createdAt, Date(timeIntervalSince1970: 1_700_000_100), "correction.createdAt", file: file, line: line)
        XCTAssertEqual(capture.rejectedProposals.count, 1, file: file, line: line)
        XCTAssertEqual(capture.rejectedProposals[0].kind, .person, file: file, line: line)
        XCTAssertEqual(capture.rejectedProposals[0].text, "Sara", file: file, line: line)
        assertDatesEqual(capture.rejectedProposals[0].rejectedAt, Date(timeIntervalSince1970: 1_700_000_200), "rejectedAt", file: file, line: line)
        XCTAssertEqual(capture.answersQuestionID, ids.followUpQuestionID, file: file, line: line)
        XCTAssertEqual(capture.episode?.id, ids.episodeID, file: file, line: line)
        assertDatesEqual(capture.createdAt, fixedDate, "capture.createdAt", file: file, line: line)

        let detailQuote = try fetchDetail(id: ids.detailQuoteID, in: context)
        XCTAssertEqual(detailQuote.text, "w3 w4", file: file, line: line)
        XCTAssertEqual(detailQuote.kind, .sensory, file: file, line: line)
        XCTAssertEqual(
            detailQuote.provenance,
            StoredProvenance(.transcriptQuote(captureID: ids.captureID, start: 0.5, end: 1.5)),
            file: file, line: line
        )
        XCTAssertEqual(detailQuote.episode?.id, ids.episodeID, file: file, line: line)

        let detailTyped = try fetchDetail(id: ids.detailTypedID, in: context)
        XCTAssertEqual(detailTyped.text, "It rained that afternoon.", file: file, line: line)
        XCTAssertEqual(detailTyped.kind, .emotion, file: file, line: line)
        XCTAssertEqual(detailTyped.provenance, StoredProvenance(.userTyped), file: file, line: line)

        let whenQuestion = try fetchQuestion(id: ids.whenQuestionID, in: context)
        XCTAssertEqual(whenQuestion.text, "Roughly when was this — a year, or how old you were?", file: file, line: line)
        XCTAssertEqual(whenQuestion.templateID, "deck.when.v1", file: file, line: line)
        XCTAssertEqual(whenQuestion.slots, [], file: file, line: line)
        XCTAssertEqual(whenQuestion.cue, .event, file: file, line: line)
        XCTAssertEqual(whenQuestion.origin, .deck, file: file, line: line)
        XCTAssertEqual(whenQuestion.status, .answered, file: file, line: line)
        XCTAssertEqual(whenQuestion.episode?.id, ids.episodeID, file: file, line: line)
        XCTAssertEqual(whenQuestion.period?.id, ids.periodID, file: file, line: line)
        XCTAssertNil(whenQuestion.person, file: file, line: line)
        XCTAssertEqual(whenQuestion.askedCount, 0, file: file, line: line)
        XCTAssertNil(whenQuestion.lastAskedAt, file: file, line: line)
        assertDatesEqual(whenQuestion.createdAt, fixedDate, "whenQuestion.createdAt", file: file, line: line)

        let followUp = try fetchQuestion(id: ids.followUpQuestionID, in: context)
        XCTAssertEqual(followUp.templateID, "deck.referent.v1", file: file, line: line)
        XCTAssertEqual(
            followUp.slots,
            [VerifiedSpan(text: "w3 w4", captureID: ids.captureID, start: 0.5, end: 1.5)],
            file: file, line: line
        )
        XCTAssertEqual(followUp.status, .open, file: file, line: line)
        XCTAssertEqual(followUp.episode?.id, ids.episodeID, file: file, line: line)
        XCTAssertNil(followUp.period, file: file, line: line)
        XCTAssertEqual(followUp.person?.id, ids.person1ID, file: file, line: line)

        let person1 = try fetchPerson(id: ids.person1ID, in: context)
        XCTAssertEqual(person1.name, "Dan", file: file, line: line)
        XCTAssertEqual(person1.aliases, ["Danny", "Daniel"], file: file, line: line)
        XCTAssertEqual(person1.note, "Met at camp", file: file, line: line)
        XCTAssertEqual(Set(person1.episodes.map(\.id)), [ids.episodeID], file: file, line: line)

        let person2 = try fetchPerson(id: ids.person2ID, in: context)
        XCTAssertEqual(person2.name, "Ruth", file: file, line: line)
        XCTAssertEqual(person2.aliases, [], file: file, line: line)
        XCTAssertNil(person2.note, file: file, line: line)

        let place = try fetchPlace(id: ids.placeID, in: context)
        XCTAssertEqual(place.name, "Lakeview dock", file: file, line: line)
        XCTAssertEqual(Set(place.episodes.map(\.id)), [ids.episodeID], file: file, line: line)
    }
}

// MARK: - The spike tests
extension SchemaRoundTripTests {
    /// The non-generic signal: flat StoredProvenance persists with no generic in the path.
    func testDetailStoredProvenanceSurvivesReopen() throws {
        let url = storeURL()
        let seeded = try seedDetails(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let quote = try fetchDetail(id: seeded.detailIDs[0], in: context)
        XCTAssertEqual(quote.text, "the smell of pine")
        XCTAssertEqual(quote.kind, .sensory)
        XCTAssertEqual(
            quote.provenance,
            StoredProvenance(.transcriptQuote(captureID: seeded.captureID, start: 1.25, end: 3.75))
        )

        let typed = try fetchDetail(id: seeded.detailIDs[1], in: context)
        XCTAssertEqual(typed.text, "We hiked before breakfast.")
        XCTAssertEqual(typed.kind, .sequence)
        XCTAssertEqual(typed.provenance, StoredProvenance(.userTyped))
    }

    private struct SeededDetails {
        let detailIDs: [UUID]
        let captureID: UUID
    }

    /// Phase 1: builds the container, inserts, saves, returns ids — the container and every
    /// model object are out of scope when it returns.
    private func seedDetails(url: URL) throws -> SeededDetails {
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext
        let captureID = UUID()
        let span = VerifiedSpan(text: "the smell of pine", captureID: captureID, start: 1.25, end: 3.75)
        let quote = Detail(quote: span, kind: .sensory)
        let typed = Detail(typed: "We hiked before breakfast.", kind: .sequence)
        context.insert(quote)
        context.insert(typed)
        try context.save()
        return SeededDetails(detailIDs: [quote.id, typed.id], captureID: captureID)
    }

    /// The single-generic signal: one Confirmable<Int> on a Period.
    func testConfirmableIntSurvivesReopen() throws {
        let url = storeURL()
        let periodID = try seedPeriod(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let period = try fetchPeriod(id: periodID, in: context)
        XCTAssertEqual(period.title, "Junior high")
        XCTAssertEqual(period.sortOrder, 1)
        assertConfirmableEqual(period.approxStartAge, Confirmable.userTyped(12), "approxStartAge")
        XCTAssertNil(period.approxEndAge)
        assertDatesEqual(period.createdAt, fixedDate, "period.createdAt")
    }

    private func seedPeriod(url: URL) throws -> UUID {
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext
        let period = Period(title: "Junior high", sortOrder: 1, createdAt: fixedDate)
        period.approxStartAge = Confirmable.userTyped(12)
        context.insert(period)
        try context.save()
        return period.id
    }

    func testInMemoryRoundTripAllEntities() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let ids = try makeFullGraph(context: context)
        try assertFullGraph(context: context, ids: ids)
    }

    func testOnDiskRoundTripAllEntities() throws {
        let url = storeURL()
        let ids = try seedFullGraph(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        try assertFullGraph(context: container.mainContext, ids: ids)
    }

    private func seedFullGraph(url: URL) throws -> GraphIDs {
        let container = try RetoldSchema.makeContainer(url: url)
        return try makeFullGraph(context: container.mainContext)
    }

    func testEveryProvenanceCaseSurvivesReopen() throws {
        let url = storeURL()
        let seeded = try seedProvenancePeriods(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let expectations: [(ConfirmStatus, Provenance)] = [
            (.confirmed, .userTyped),
            (.confirmed, .userConfirmed(proposedBy: .model)),
            (.confirmed, .userConfirmed(proposedBy: .deck)),
            (.confirmed, .transcriptQuote(captureID: seeded.captureID, start: 2, end: 4)),
            (.proposed, .model),
        ]
        XCTAssertEqual(seeded.periodIDs.count, expectations.count)
        for (periodID, expected) in zip(seeded.periodIDs, expectations) {
            let period = try fetchPeriod(id: periodID, in: context)
            let age = period.approxStartAge
            XCTAssertNotNil(age, "period \(period.title) lost approxStartAge")
            XCTAssertEqual(age?.status, expected.0, "period \(period.title) status")
            XCTAssertEqual(age?.provenance, expected.1, "period \(period.title) provenance")
        }
    }

    private struct SeededProvenancePeriods {
        let periodIDs: [UUID]
        let captureID: UUID
    }

    private func seedProvenancePeriods(url: URL) throws -> SeededProvenancePeriods {
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext
        let captureID = UUID()
        let span = VerifiedSpan(text: "cue", captureID: captureID, start: 2, end: 4)

        let userTyped = Period(title: "userTyped", sortOrder: 1)
        userTyped.approxStartAge = Confirmable.userTyped(1)

        var confirmedModel = Confirmable<Int>.proposedByModel(2)
        XCTAssertTrue(confirmedModel.confirm())
        let confirmedModelPeriod = Period(title: "confirmedModel", sortOrder: 2)
        confirmedModelPeriod.approxStartAge = confirmedModel

        var confirmedDeck = Confirmable<Int>.proposedByDeck(3, promptID: "deck.when")
        XCTAssertTrue(confirmedDeck.confirm())
        let confirmedDeckPeriod = Period(title: "confirmedDeck", sortOrder: 3)
        confirmedDeckPeriod.approxStartAge = confirmedDeck

        var confirmedQuote = Confirmable<Int>.proposedQuote(4, span: span)
        XCTAssertTrue(confirmedQuote.confirm())
        let confirmedQuotePeriod = Period(title: "confirmedQuote", sortOrder: 4)
        confirmedQuotePeriod.approxStartAge = confirmedQuote

        let proposedModel = Period(title: "proposedModel", sortOrder: 5)
        proposedModel.approxStartAge = Confirmable.proposedByModel(5)

        for period in [userTyped, confirmedModelPeriod, confirmedDeckPeriod, confirmedQuotePeriod, proposedModel] {
            context.insert(period)
        }
        try context.save()
        return SeededProvenancePeriods(
            periodIDs: [userTyped, confirmedModelPeriod, confirmedDeckPeriod, confirmedQuotePeriod, proposedModel].map(\.id),
            captureID: captureID
        )
    }

    func testConfirmableStringSurvivesReopen() throws {
        let url = storeURL()
        let seeded = try seedStringEpisodes(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let proposed = try fetchEpisode(id: seeded.episodeIDs[0], in: context)
        assertConfirmableEqual(
            proposed.title,
            Confirmable.proposedQuote("The last day", span: seeded.span),
            "proposed quote title"
        )

        let confirmed = try fetchEpisode(id: seeded.episodeIDs[1], in: context)
        var expectedConfirmed = Confirmable<String>.proposedQuote("The last day", span: seeded.span)
        XCTAssertTrue(expectedConfirmed.confirm())
        assertConfirmableEqual(confirmed.title, expectedConfirmed, "confirmed quote title")

        let typed = try fetchEpisode(id: seeded.episodeIDs[2], in: context)
        assertConfirmableEqual(typed.title, Confirmable.userTyped("User's own title"), "user-typed title")
    }

    private struct SeededStringEpisodes {
        let episodeIDs: [UUID]
        let span: VerifiedSpan
    }

    private func seedStringEpisodes(url: URL) throws -> SeededStringEpisodes {
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext
        let span = VerifiedSpan(text: "The last day", captureID: UUID(), start: 0, end: 1.5)

        let proposed = Episode(titleQuote: span)
        let confirmed = Episode(titleQuote: span)
        XCTAssertTrue(confirmed.confirmTitle())
        let typed = Episode(typedTitle: "User's own title")

        for episode in [proposed, confirmed, typed] {
            context.insert(episode)
        }
        try context.save()
        return SeededStringEpisodes(episodeIDs: [proposed, confirmed, typed].map(\.id), span: span)
    }

    func testCodableArraysSurviveReopen() throws {
        let url = storeURL()
        let seeded = try seedCodableArrays(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let capture = try fetchCapture(id: seeded.captureID, in: context)
        XCTAssertEqual(
            capture.transcript,
            [
                TranscriptSegment(text: "alpha", start: 0, end: 0.5, isFinal: false),
                TranscriptSegment(text: "beta", start: 0.5, end: 1, isFinal: true),
                TranscriptSegment(text: "gamma", start: 1, end: 2, isFinal: true),
            ]
        )
        XCTAssertEqual(capture.corrections.count, 2)
        XCTAssertEqual(capture.corrections.map(\.correctedText), ["alpha-fix", "gamma-fix"])
        XCTAssertEqual(
            capture.rejectedProposals.map(\.text),
            ["Sara", "the dock"],
            "rejected proposals keep order"
        )

        let person = try fetchPerson(id: seeded.personID, in: context)
        XCTAssertEqual(person.aliases, ["bee", "ay", "cee"], "aliases keep order")

        let question = try fetchQuestion(id: seeded.questionID, in: context)
        XCTAssertEqual(
            question.slots,
            [
                VerifiedSpan(text: "alpha", captureID: seeded.captureID, start: 0, end: 0.5),
                VerifiedSpan(text: "gamma", captureID: seeded.captureID, start: 1, end: 2),
            ],
            "slots keep order"
        )
    }

    private struct SeededCodableArrays {
        let captureID: UUID
        let personID: UUID
        let questionID: UUID
    }

    private func seedCodableArrays(url: URL) throws -> SeededCodableArrays {
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let capture = Capture(audioFileName: "b.m4a", duration: 2)
        try capture.completeTranscript([
            TranscriptSegment(text: "alpha", start: 0, end: 0.5, isFinal: false),
            TranscriptSegment(text: "beta", start: 0.5, end: 1, isFinal: true),
            TranscriptSegment(text: "gamma", start: 1, end: 2, isFinal: true),
        ])
        try capture.addCorrection(segmentIndex: 0, correctedText: "alpha-fix", at: fixedDate)
        try capture.addCorrection(segmentIndex: 2, correctedText: "gamma-fix", at: fixedDate)
        capture.logRejected(.person, text: "Sara", at: fixedDate)
        capture.logRejected(.place, text: "the dock", at: fixedDate)

        let person = Person(name: "Bee")
        person.aliases = ["bee", "ay", "cee"]

        let question = Question(
            text: "q",
            templateID: "t",
            slots: [
                VerifiedSpan(text: "alpha", captureID: capture.id, start: 0, end: 0.5),
                VerifiedSpan(text: "gamma", captureID: capture.id, start: 1, end: 2),
            ],
            cue: .sensory,
            origin: .user
        )

        context.insert(capture)
        context.insert(person)
        context.insert(question)
        try context.save()
        return SeededCodableArrays(captureID: capture.id, personID: person.id, questionID: question.id)
    }

    func testManyToManyPeopleSurvivesReopen() throws {
        let url = storeURL()
        let seeded = try seedManyToMany(url: url)
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let episode1 = try fetchEpisode(id: seeded.episode1ID, in: context)
        let episode2 = try fetchEpisode(id: seeded.episode2ID, in: context)
        XCTAssertEqual(Set(episode1.people.map(\.id)), [seeded.person1ID, seeded.person2ID])
        XCTAssertEqual(Set(episode2.people.map(\.id)), [seeded.person1ID, seeded.person2ID])

        let person1 = try fetchPerson(id: seeded.person1ID, in: context)
        let person2 = try fetchPerson(id: seeded.person2ID, in: context)
        XCTAssertEqual(Set(person1.episodes.map(\.id)), [seeded.episode1ID, seeded.episode2ID])
        XCTAssertEqual(Set(person2.episodes.map(\.id)), [seeded.episode1ID, seeded.episode2ID])
    }

    private struct SeededManyToMany {
        let episode1ID: UUID
        let episode2ID: UUID
        let person1ID: UUID
        let person2ID: UUID
    }

    private func seedManyToMany(url: URL) throws -> SeededManyToMany {
        let container = try RetoldSchema.makeContainer(url: url)
        let context = container.mainContext

        let person1 = Person(name: "Dan")
        let person2 = Person(name: "Ruth")
        let episode1 = Episode(typedTitle: "One")
        let episode2 = Episode(typedTitle: "Two")

        // Owning side: Episode.people.
        episode1.people.append(person1)
        episode1.people.append(person2)
        episode2.people.append(person1)
        episode2.people.append(person2)

        // One insert per object: a mixed [Person, Episode] literal infers [Any], which
        // ModelContext.insert can't take.
        context.insert(person1)
        context.insert(person2)
        context.insert(episode1)
        context.insert(episode2)
        try context.save()
        return SeededManyToMany(
            episode1ID: episode1.id,
            episode2ID: episode2.id,
            person1ID: person1.id,
            person2ID: person2.id
        )
    }

    func testDeleteEpisodeCascades() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let ids = try makeFullGraph(context: context)

        let episode = try fetchEpisode(id: ids.episodeID, in: context)
        context.delete(episode)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Capture>()).count, 0, "captures cascade")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Detail>()).count, 0, "details cascade")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Question>()).count, 0, "questions cascade")

        XCTAssertEqual(try context.fetch(FetchDescriptor<Person>()).count, 2, "people remain")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Place>()).count, 1, "place remains")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Period>()).count, 1, "period remains")
    }

    func testDeletePeriodNullifiesEpisodes() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext

        let period = Period(title: "Camp", sortOrder: 1)
        let episode = Episode(typedTitle: "E")
        context.insert(period)
        context.insert(episode)
        period.episodes.append(episode)
        try context.save()

        context.delete(period)
        try context.save()

        let fetched = try fetchEpisode(id: episode.id, in: context)
        XCTAssertNil(fetched.period)
    }
}
