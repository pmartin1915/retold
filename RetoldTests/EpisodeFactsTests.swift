import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class EpisodeFactsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    private func quoteEpisode(_ text: String = "the summer we moved") -> Episode {
        let span = VerifiedSpan.fixture(text: text, captureID: UUID(), start: 0, end: 1)
        let episode = Episode(titleQuote: span, createdAt: now)
        context.insert(episode)
        return episode
    }

    func testWall1ProposedTitleIsNil() {
        let episode = quoteEpisode()
        XCTAssertEqual(episode.title.status, .proposed)
        XCTAssertNil(EpisodeFacts(episode: episode).title)

        episode.rejectTitle()
        XCTAssertNil(EpisodeFacts(episode: episode).title)
    }

    func testConfirmedQuoteTitleShown() {
        let episode = quoteEpisode("the summer we moved")
        episode.confirmTitle()
        XCTAssertEqual(EpisodeFacts(episode: episode).title, "the summer we moved")
    }

    func testTypedTitleShown() {
        let episode = Episode(typedTitle: "Grandma's kitchen", createdAt: now)
        context.insert(episode)
        XCTAssertEqual(EpisodeFacts(episode: episode).title, "Grandma's kitchen")
    }

    func testWhenYearAndAgeShown() {
        let episode = Episode(typedTitle: "A memory", createdAt: now)
        context.insert(episode)
        var facts = EpisodeFacts(episode: episode)
        XCTAssertNil(facts.year)
        XCTAssertNil(facts.age)
        XCTAssertNil(facts.whenDisplay)

        episode.answerWhen(year: 1998)
        facts = EpisodeFacts(episode: episode)
        XCTAssertEqual(facts.year, 1998)
        XCTAssertEqual(facts.whenDisplay, "1998")

        episode.answerWhen(age: 12)
        facts = EpisodeFacts(episode: episode)
        XCTAssertEqual(facts.age, 12)
        XCTAssertEqual(facts.whenDisplay, "1998 \u{00B7} Age 12")

        let ageOnly = Episode(typedTitle: "Another", createdAt: now)
        context.insert(ageOnly)
        ageOnly.answerWhen(age: 12)
        XCTAssertEqual(EpisodeFacts(episode: ageOnly).whenDisplay, "Age 12")
    }

    func testPeopleSortedByName() {
        let episode = Episode(typedTitle: "A memory", createdAt: now)
        context.insert(episode)
        for name in ["Zed", "Alice", "Maria"] {
            let person = Person(name: name)
            context.insert(person)
            episode.people.append(person)
        }
        XCTAssertEqual(EpisodeFacts(episode: episode).people.map(\.name), ["Alice", "Maria", "Zed"])
    }

    func testPlaceAndPeriodShown() {
        let episode = Episode(typedTitle: "A memory", createdAt: now)
        context.insert(episode)
        let place = Place(name: "The cabin")
        context.insert(place)
        episode.place = place
        let period = Period(title: "High school", sortOrder: 3, createdAt: now)
        context.insert(period)
        episode.period = period

        let facts = EpisodeFacts(episode: episode)
        XCTAssertEqual(facts.place, EntityRef(id: place.id, name: "The cabin"))
        XCTAssertEqual(facts.period, PeriodRef(id: period.id, title: "High school", sortOrder: 3))
    }

    func testTranscriptStateMapping() {
        let segments = [TranscriptSegment(text: "hello there", start: 0, end: 1, isFinal: true)]
        for status in [TranscriptionStatus.pending, .live, .fromFile] {
            XCTAssertEqual(CaptureTranscriptState.of(status: status, segments: []), .transcribing)
            XCTAssertEqual(CaptureTranscriptState.of(status: status, segments: segments), .transcribing)
        }
        XCTAssertEqual(CaptureTranscriptState.of(status: .complete, segments: segments), .segments(segments))
        XCTAssertEqual(CaptureTranscriptState.of(status: .complete, segments: []), CaptureTranscriptState.none)
        XCTAssertEqual(CaptureTranscriptState.of(status: .failed, segments: []), CaptureTranscriptState.none)
        // A failed capture with a partial transcript shows none, the same reading as R7a's Unfiled row.
        XCTAssertEqual(CaptureTranscriptState.of(status: .failed, segments: segments), CaptureTranscriptState.none)
    }
}
