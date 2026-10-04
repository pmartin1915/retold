import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class QuestionEngineTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
    private let fixtureCaptureID = UUID()

    private func span(_ text: String, captureID: UUID? = nil) -> VerifiedSpan {
        VerifiedSpan.fixture(text: text, captureID: captureID ?? fixtureCaptureID, start: 0, end: 1)
    }

    private func askRecord(
        _ templateID: String,
        _ cue: CueKind,
        slotKey: String = "",
        status: QuestionStatus = .open,
        lastAskedAt: Date? = nil,
        id: UUID = UUID()
    ) -> AskRecord {
        AskRecord(questionID: id, templateID: templateID, cue: cue, slotKey: slotKey,
                  status: status, lastAskedAt: lastAskedAt)
    }

    private struct Expectation: Equatable {
        let templateID: String
        let slot: String?
    }

    private func describe(_ offer: EngineOffer) -> Expectation {
        Expectation(templateID: offer.question.templateID, slot: offer.question.slots.first?.text)
    }

    /// Matches the spec's (c)/(d) loop bookkeeping: created if absent, else updated in
    /// place on (templateID, slotKey); every broad.open offer appends a new record.
    private func upsert(_ asks: inout [AskRecord], _ record: AskRecord) {
        if record.templateID == "broad.open" {
            asks.append(record)
            return
        }
        if let index = asks.firstIndex(
            where: { $0.templateID == record.templateID && $0.slotKey == record.slotKey }) {
            asks[index] = record
        } else {
            asks.append(record)
        }
    }

    /// The ask an offer would leave behind: date(t) is the show time.
    private func record(for offer: EngineOffer, shownAt: Date, status: QuestionStatus) -> AskRecord {
        AskRecord(
            questionID: offer.existingQuestionID ?? UUID(),
            templateID: offer.question.templateID,
            cue: offer.question.cue,
            slotKey: offer.question.slots.first.map { SpanVerifier.phraseKey($0.text) } ?? "",
            status: status,
            lastAskedAt: shownAt
        )
    }

    // MARK: (a) no capture

    func testNoCaptureMeansNoOffers() {
        let state = EpisodeState()
        XCTAssertTrue(QuestionEngine.queue(for: state).isEmpty)
        XCTAssertNil(QuestionEngine.next(for: state, recentChannels: []))
    }

    // MARK: (b) broad opener first, exempt from the cap

    func testBroadOpenerIsFirstAndExemptFromCap() {
        let fresh = EpisodeState(latestCaptureAt: fixedDate, transcriptTexts: [], asks: [])
        XCTAssertEqual(
            QuestionEngine.next(for: fresh, recentChannels: [])?.question.templateID,
            "broad.open"
        )

        let broadID = UUID()
        let withFiled = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            asks: [askRecord("broad.open", .event, status: .open, lastAskedAt: nil, id: broadID)]
        )
        let next = QuestionEngine.next(for: withFiled, recentChannels: [])
        XCTAssertEqual(next?.question.templateID, "broad.open")
        XCTAssertEqual(next?.existingQuestionID, broadID)

        // Even with two open-channel questions in a row, the opener comes first.
        XCTAssertEqual(
            QuestionEngine.next(for: withFiled, recentChannels: [.open, .open])?.question.templateID,
            "broad.open"
        )
    }

    // MARK: (c) scenario A, literal sequence

    func testScenarioAAnswersWalkTheDeck() {
        let reference = Date(timeIntervalSince1970: 1_800_000_000)
        func date(_ t: Int) -> Date { reference.addingTimeInterval(TimeInterval(t)) }

        let referents = [span("the pier"), span("the old boat"), span("the noise of the gulls")]
        let places = [span("the cabin")]
        let transcript = ["we wore our coats"]

        var asks: [AskRecord] = []
        var recent: [QuestionChannel] = []
        var latestCaptureAt: Date? = date(0)
        var t = 0
        var offered: [Expectation] = []
        for _ in 0..<20 {
            let state = EpisodeState(
                latestCaptureAt: latestCaptureAt,
                transcriptTexts: transcript,
                referentSpans: referents,
                placeSpans: places,
                asks: asks
            )
            guard let offer = QuestionEngine.next(for: state, recentChannels: recent) else { break }
            offered.append(describe(offer))

            t += 1
            upsert(&asks, record(for: offer, shownAt: date(t), status: .answered))
            if offer.question.templateID != "broad.open" {
                recent = Array((recent + [offer.channel]).suffix(2))
                t += 1
                latestCaptureAt = date(t)
            }
        }

        let expected: [Expectation] = [
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "referent.open", slot: "the pier"),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "referent.open", slot: "the old boat"),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "event.else", slot: nil),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "event.shape", slot: nil),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "event.anyone", slot: nil),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "sensory.mentioned", slot: "the noise of the gulls"),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "sensory.place", slot: "the cabin"),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "sequence.connect", slot: nil),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "sensory.everything", slot: nil),
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "sequence.otherTimes", slot: nil),
        ]
        XCTAssertEqual(offered, expected)
        XCTAssertEqual(offered.count, 20)
    }

    // MARK: (d) scenario C, skips retire

    func testScenarioCSkipsRetireAndThenOfferNothing() {
        let reference = Date(timeIntervalSince1970: 1_800_000_000)
        func date(_ t: Int) -> Date { reference.addingTimeInterval(TimeInterval(t)) }

        let referents = [span("the pier"), span("the old boat")]
        let places = [span("the cabin")]
        let transcript = ["we wore our coats"]

        var asks: [AskRecord] = []
        var recent: [QuestionChannel] = []
        let latestCaptureAt: Date? = date(0)
        var t = 0
        var offered: [Expectation] = []
        for _ in 0..<20 {
            let state = EpisodeState(
                latestCaptureAt: latestCaptureAt,
                transcriptTexts: transcript,
                referentSpans: referents,
                placeSpans: places,
                asks: asks
            )
            guard let offer = QuestionEngine.next(for: state, recentChannels: recent) else { break }
            offered.append(describe(offer))

            t += 1
            // The status the question itself would hold after this outcome: the broad
            // opener is never retired (docs/R4-ENGINE-SPEC.md section 4).
            // A second skip retires (section 4); read the previous status off the ask.
            let previous = asks.last {
                $0.templateID == offer.question.templateID
                    && $0.slotKey == (offer.question.slots.first.map { SpanVerifier.phraseKey($0.text) } ?? "")
            }?.status
            let status: QuestionStatus = offer.question.templateID == "broad.open"
                ? .open
                : (previous == .skipped ? .retired : .skipped)
            upsert(&asks, record(for: offer, shownAt: date(t), status: status))
            if offer.question.templateID != "broad.open" {
                recent = Array((recent + [offer.channel]).suffix(2))
            }
        }

        let expected: [Expectation] = [
            Expectation(templateID: "broad.open", slot: nil),
            Expectation(templateID: "referent.open", slot: "the pier"),
            Expectation(templateID: "referent.open", slot: "the old boat"),
            Expectation(templateID: "event.else", slot: nil),
            Expectation(templateID: "event.shape", slot: nil),
            Expectation(templateID: "event.anyone", slot: nil),
            Expectation(templateID: "sensory.place", slot: "the cabin"),
            Expectation(templateID: "sensory.everything", slot: nil),
            Expectation(templateID: "referent.open", slot: "the pier"),
            Expectation(templateID: "referent.open", slot: "the old boat"),
            Expectation(templateID: "event.else", slot: nil),
            Expectation(templateID: "sensory.place", slot: "the cabin"),
            Expectation(templateID: "sensory.everything", slot: nil),
        ]
        XCTAssertEqual(offered, expected)
        // The 14th call offered nothing: everything is retired or suppressed.
        XCTAssertEqual(offered.count, 13)
    }

    // MARK: (e) the cap

    func testCapDefersAChannelOfferedTwiceInARow() {
        let broad = askRecord("broad.open", .event, status: .answered,
                              lastAskedAt: fixedDate.addingTimeInterval(1))
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            referentSpans: [span("the pier")],
            placeSpans: [],
            asks: [broad]
        )
        let next = QuestionEngine.next(for: state, recentChannels: [.referent, .referent])
        XCTAssertEqual(next?.question.templateID, "event.else")
    }

    func testCapReturnsNilWhenEverythingQueuedIsBlocked() {
        let broad = askRecord("broad.open", .event, status: .answered,
                              lastAskedAt: fixedDate.addingTimeInterval(1))
        let answered = ["event.else", "event.shape", "event.anyone",
                        "sensory.everything", "sequence.connect", "sequence.otherTimes"]
            .map { askRecord($0, .event, status: .answered, lastAskedAt: fixedDate.addingTimeInterval(2)) }
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            referentSpans: [span("the pier")],
            placeSpans: [],
            asks: [broad] + answered
        )
        // Referent offers are queued, but both recent channels are referent.
        XCTAssertFalse(QuestionEngine.queue(for: state).isEmpty)
        XCTAssertNil(QuestionEngine.next(for: state, recentChannels: [.referent, .referent]))
    }

    // MARK: (f) negatives are scoped by slot

    func testRetiredSlotAskSuppressesOnlyThatSlot() {
        let asks = [
            askRecord("broad.open", .event, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(1)),
            askRecord("referent.open", .event, slotKey: "the pier", status: .retired,
                      lastAskedAt: fixedDate.addingTimeInterval(2)),
            // The when question belongs to the confirm flow and silences nothing.
            askRecord("when.open", .event, status: .retired,
                      lastAskedAt: fixedDate.addingTimeInterval(3)),
        ]
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            referentSpans: [span("the pier"), span("the old boat")],
            placeSpans: [],
            asks: asks
        )
        let offered = QuestionEngine.queue(for: state).map(describe)
        XCTAssertTrue(offered.contains(Expectation(templateID: "event.else", slot: nil)))
        XCTAssertTrue(offered.contains(Expectation(templateID: "referent.open", slot: "the old boat")))
        XCTAssertFalse(offered.contains(Expectation(templateID: "referent.open", slot: "the pier")))
    }

    // MARK: (f2) the opener's pending rule

    func testWhenQuestionShownAfterCaptureDoesNotConsumeOpener() {
        let withWhen = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            asks: [askRecord("when.open", .event, status: .answered,
                             lastAskedAt: fixedDate.addingTimeInterval(1))]
        )
        XCTAssertEqual(
            QuestionEngine.next(for: withWhen, recentChannels: [])?.question.templateID,
            "broad.open"
        )

        let withBroad = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            asks: [askRecord("broad.open", .event, status: .open,
                             lastAskedAt: fixedDate.addingTimeInterval(1))]
        )
        XCTAssertEqual(
            QuestionEngine.next(for: withBroad, recentChannels: [])?.question.templateID,
            "event.else"
        )
    }

    // MARK: (g) sequence gate

    func testSequenceGateNeedsAUserInitiatedDetail() {
        let base = [
            askRecord("broad.open", .event, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(1)),
            askRecord("when.open", .event, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(2)),
        ]
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            asks: base
        )
        let ids = QuestionEngine.queue(for: state).map(\.question.templateID)
        XCTAssertFalse(ids.contains("sequence.connect"))
        XCTAssertFalse(ids.contains("sequence.otherTimes"))

        let withDetail = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            asks: base + [askRecord("event.else", .event, status: .answered,
                                   lastAskedAt: fixedDate.addingTimeInterval(3))]
        )
        let idsAfter = QuestionEngine.queue(for: withDetail).map(\.question.templateID)
        XCTAssertTrue(idsAfter.contains("sequence.connect"))
        XCTAssertTrue(idsAfter.contains("sequence.otherTimes"))
    }
}

// MARK: (h) same-slot rotation

extension QuestionEngineTests {
    func testQueueRotatesAwayFromTheSlotAskedMostRecently() {
        let loudPier = span("the loud pier")
        let asks = [
            askRecord("broad.open", .event, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(1)),
            askRecord("sensory.mentioned", .sensory, slotKey: "the loud pier", status: .open,
                      lastAskedAt: fixedDate.addingTimeInterval(2)),
        ]
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            referentSpans: [loudPier],
            placeSpans: [loudPier],
            asks: asks
        )
        let sensory = QuestionEngine.queue(for: state)
            .filter { $0.question.templateID.hasPrefix("sensory") }
            .map(\.question.templateID)
        // "the loud pier" was just asked about: the slotless everything question leads
        // the sensory level, ahead of the slotted place question on the same referent.
        XCTAssertEqual(sensory, ["sensory.everything", "sensory.mentioned", "sensory.place"])
    }
}

// MARK: (i) function-word slots

extension QuestionEngineTests {
    func testFunctionWordSpanProducesNoOffer() {
        let iSpan = span("I")
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            referentSpans: [iSpan],
            placeSpans: [],
            asks: []
        )
        let queue = QuestionEngine.queue(for: state)
        XCTAssertFalse(queue.contains { $0.question.slots.contains(iSpan) })
        XCTAssertTrue(queue.contains { $0.question.templateID == "event.else" })

        let aunt = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            referentSpans: [span("my aunt")],
            placeSpans: [],
            asks: []
        )
        XCTAssertTrue(QuestionEngine.queue(for: aunt).map(describe)
            .contains(Expectation(templateID: "referent.open", slot: "my aunt")))
    }
}

// MARK: (i2) the referent family split

extension QuestionEngineTests {
    func testFiledReferentAskIsReusedAndNeverOrphaned() {
        let gulls = span("the noise of the gulls")
        let filedID = UUID()
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            referentSpans: [gulls],
            placeSpans: [],
            asks: [askRecord("referent.open", .event, slotKey: "the noise of the gulls",
                             status: .open, lastAskedAt: nil, id: filedID)]
        )
        let queue = QuestionEngine.queue(for: state)
        let reuse = queue.first {
            $0.question.templateID == "referent.open"
                && $0.question.slots.first?.text == "the noise of the gulls"
        }
        XCTAssertEqual(reuse?.existingQuestionID, filedID)
        XCTAssertFalse(queue.contains {
            $0.question.templateID == "sensory.mentioned"
                && $0.question.slots.first?.text == "the noise of the gulls"
        })
    }

    func testUnfiledChannelMentionGoesToSensoryMentionedOnly() {
        let gulls = span("the noise of the gulls")
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            referentSpans: [gulls],
            placeSpans: [],
            asks: []
        )
        let queue = QuestionEngine.queue(for: state).map(describe)
        XCTAssertTrue(queue.contains(Expectation(templateID: "sensory.mentioned", slot: "the noise of the gulls")))
        XCTAssertFalse(queue.contains(Expectation(templateID: "referent.open", slot: "the noise of the gulls")))
    }
}

// MARK: (i3) slotted before slotless within a level

extension QuestionEngineTests {
    func testSlottedCandidatesSortBeforeSlotlessWithinALevel() {
        let templates = [
            QuestionDeck.template(id: "event.else"),
            QuestionDeck.template(id: "referent.open"),
        ].compactMap { $0 }
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: [],
            referentSpans: [span("my aunt")],
            placeSpans: [],
            asks: []
        )
        XCTAssertEqual(
            QuestionEngine.queue(for: state, templates: templates).map(\.question.templateID),
            ["broad.open", "referent.open", "event.else"]
        )

        let sensoryTemplates = [
            QuestionDeck.template(id: "sensory.everything"),
            QuestionDeck.template(id: "sensory.place"),
        ].compactMap { $0 }
        let withPlace = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            referentSpans: [],
            placeSpans: [span("the cabin")],
            asks: []
        )
        XCTAssertEqual(
            QuestionEngine.queue(for: withPlace, templates: sensoryTemplates).map(\.question.templateID),
            ["broad.open", "sensory.place", "sensory.everything"]
        )
    }
}

// MARK: (j) lint gate

extension QuestionEngineTests {
    func testTemplateFailingTheLintIsNotQueued() {
        let template = QuestionTemplate.fixture(
            id: "test.sounds",
            cue: .sensory,
            pattern: "What other sounds come back to you?"
        )
        let broad = askRecord("broad.open", .event, status: .answered,
                              lastAskedAt: fixedDate.addingTimeInterval(1))
        let unmentioned = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["We sat by the lake"],
            asks: [broad]
        )
        XCTAssertFalse(QuestionEngine.queue(for: unmentioned, templates: [template])
            .contains { $0.question.templateID == "test.sounds" })

        let mentioned = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["the noise of the boats"],
            asks: [broad]
        )
        XCTAssertTrue(QuestionEngine.queue(for: mentioned, templates: [template])
            .contains { $0.question.templateID == "test.sounds" })
    }
}

// MARK: (k) excluded templates

extension QuestionEngineTests {
    func testDeckWideQueueNeverOffersPeriodPeopleWhenOrThemeTemplates() {
        let answered = [
            askRecord("referent.open", .event, slotKey: "the pier", status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(2)),
            askRecord("event.else", .event, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(3)),
            askRecord("sensory.place", .sensory, slotKey: "the cabin", status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(4)),
            askRecord("sensory.everything", .sensory, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(5)),
            askRecord("sequence.connect", .sequence, status: .answered,
                      lastAskedAt: fixedDate.addingTimeInterval(6)),
        ]
        let state = EpisodeState(
            latestCaptureAt: fixedDate,
            transcriptTexts: ["we wore our coats"],
            referentSpans: [span("the pier")],
            placeSpans: [span("the cabin")],
            asks: [askRecord("broad.open", .event, status: .answered,
                             lastAskedAt: fixedDate.addingTimeInterval(1))] + answered
        )
        let queued = QuestionEngine.queue(for: state, templates: QuestionDeck.all)
        XCTAssertFalse(queued.isEmpty)
        for offer in queued {
            XCTAssertFalse([CueKind.period, .people].contains(offer.question.cue), offer.question.templateID)
            XCTAssertFalse(["when.open", "when.cue", "period.slot"].contains(offer.question.templateID),
                           offer.question.templateID)
            XCTAssertFalse(offer.question.templateID.hasPrefix("theme."), offer.question.templateID)
        }
    }
}

// MARK: (l) person queue

extension QuestionEngineTests {
    func testPersonQueueGateAndOrder() {
        // No spans: the gate fails.
        XCTAssertTrue(QuestionEngine.queue(for: PersonState(spans: [], episodeCount: 2, asks: [])).isEmpty)

        // Answered == episodeCount: the gate fails.
        let aunt = span("my aunt")
        let answered = askRecord("who.person", .people, slotKey: "my aunt", status: .answered,
                                 lastAskedAt: fixedDate.addingTimeInterval(1))
        XCTAssertTrue(QuestionEngine.queue(for: PersonState(spans: [aunt], episodeCount: 1, asks: [answered])).isEmpty)

        let state = PersonState(spans: [aunt], episodeCount: 2, asks: [])
        XCTAssertEqual(
            QuestionEngine.queue(for: state).map(\.question.templateID),
            ["who.person", "people.describe", "people.talk", "people.together"]
        )
        XCTAssertEqual(
            QuestionEngine.next(for: state, recentChannels: [.people])?.question.templateID,
            "who.person"
        )
        XCTAssertNil(QuestionEngine.next(for: state, recentChannels: [.people, .people]))
    }
}

// MARK: (m) period queue

extension QuestionEngineTests {
    func testPeriodQueueGateNegativesAndCap() {
        XCTAssertTrue(QuestionEngine.queue(for: PeriodState(episodeCount: 0, asks: [])).isEmpty)

        let state = PeriodState(episodeCount: 1, asks: [])
        XCTAssertEqual(
            QuestionEngine.queue(for: state).map(\.question.templateID),
            ["period.else", "period.who", "period.where"]
        )

        // A retired period.else is a negative on (period, ""): it quiets the other two.
        let retired = PeriodState(episodeCount: 1, asks: [
            askRecord("period.else", .period, status: .retired, lastAskedAt: fixedDate.addingTimeInterval(1)),
        ])
        XCTAssertTrue(QuestionEngine.queue(for: retired).isEmpty)

        // Two open-channel asks in a row defer period.else (channel .open), not period.who.
        let answered = PeriodState(episodeCount: 1, asks: [
            askRecord("period.else", .period, status: .answered, lastAskedAt: fixedDate.addingTimeInterval(1)),
        ])
        XCTAssertEqual(
            QuestionEngine.next(for: answered, recentChannels: [.open, .open])?.question.templateID,
            "period.who"
        )
    }
}

// MARK: (n) adapters against a real in-memory container

extension QuestionEngineTests {
    func testEpisodeStateAdapter() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let day: TimeInterval = 86_400
        let d0 = Date(timeIntervalSince1970: 1_800_000_000)
        let d1 = d0.addingTimeInterval(day)
        let d2 = d0.addingTimeInterval(2 * day)

        let capture1 = Capture(audioFileName: "a.m4a", duration: 10, createdAt: d1)
        try capture1.completeTranscript([
            TranscriptSegment(text: "we went down to the pier", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "and it smelled of salt", start: 2, end: 4, isFinal: true),
        ])
        try capture1.addCorrection(segmentIndex: 1, correctedText: "and it smelled of the sea", at: d1)
        let capture2 = Capture(audioFileName: "b.m4a", duration: 8, createdAt: d2)
        try capture2.completeTranscript([
            TranscriptSegment(text: "the old boat was still there", start: 0, end: 3, isFinal: true),
        ])

        let episode = Episode(typedTitle: "The pier", createdAt: d0)
        context.insert(episode)
        context.insert(capture1)
        context.insert(capture2)
        episode.captures.append(capture1)
        episode.captures.append(capture2)

        var merged = MergedExtract()
        let pierSpan = VerifiedSpan.fixture(text: "the pier", captureID: capture2.id, start: 4, end: 5)
        let cabinSpan = VerifiedSpan.fixture(text: "the cabin", captureID: capture2.id, start: 0, end: 1)
        merged.referents = [VerifiedReferent(span: pierSpan, kind: .object)]
        merged.places = [cabinSpan]
        for assembled in TemplateAssembler.followUps(from: merged) {
            episode.questions.append(assembled.question())
        }
        // The same span filed twice deduplicates to one (first by createdAt, id wins).
        let duplicate = Question.fixture(
            text: "You mentioned the pier. Is there anything else about that?",
            templateID: "referent.open",
            slots: [pierSpan],
            cue: .event,
            origin: .deck,
            createdAt: d0.addingTimeInterval(3 * day)
        )
        context.insert(duplicate)
        episode.questions.append(duplicate)
        try context.save()

        let state = EpisodeState(episode: episode)
        XCTAssertEqual(state.latestCaptureAt, d2)
        XCTAssertEqual(state.transcriptTexts, [
            "we went down to the pier",
            "and it smelled of salt",
            "and it smelled of the sea",
            "the old boat was still there",
        ])
        XCTAssertEqual(state.referentSpans, [pierSpan])
        XCTAssertEqual(state.placeSpans, [cabinSpan])
        XCTAssertEqual(state.asks.count, episode.questions.count)
    }

    func testEpisodeStateAdapterSkipsCapturesAnsweringTheBroadOpener() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let day: TimeInterval = 86_400
        let d0 = Date(timeIntervalSince1970: 1_800_000_000)

        let capture1 = Capture(audioFileName: "a.m4a", duration: 10, createdAt: d0.addingTimeInterval(day))
        try capture1.completeTranscript([
            TranscriptSegment(text: "first telling", start: 0, end: 2, isFinal: true),
        ])
        let capture2 = Capture(audioFileName: "b.m4a", duration: 8, createdAt: d0.addingTimeInterval(2 * day))
        try capture2.completeTranscript([
            TranscriptSegment(text: "the answer to anything else", start: 0, end: 3, isFinal: true),
        ])

        let episode = Episode(typedTitle: "E", createdAt: d0)
        context.insert(episode)
        context.insert(capture1)
        context.insert(capture2)
        episode.captures.append(capture1)
        episode.captures.append(capture2)

        let broad = Question.fixture(
            text: "Anything else at all, however small?",
            templateID: "broad.open",
            slots: [],
            cue: .event,
            origin: .deck,
            createdAt: d0
        )
        context.insert(broad)
        episode.questions.append(broad)
        capture2.answersQuestionID = broad.id
        try context.save()

        // The capture answering the opener must not re-arm it.
        XCTAssertEqual(EpisodeState(episode: episode).latestCaptureAt, d0.addingTimeInterval(day))
    }

    func testPersonStateAdapterKeepsOnlyUnpromptedSpans() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext

        let person = Person(name: "Ruth")
        let episode = Episode(typedTitle: "E")
        let otherEpisode = Episode(typedTitle: "Other")
        context.insert(person)
        context.insert(episode)
        context.insert(otherEpisode)
        episode.people.append(person)

        let capKept = Capture(audioFileName: "kept.m4a", duration: 5)
        let capAnyone = Capture(audioFileName: "anyone.m4a", duration: 5)
        let capUnresolved = Capture(audioFileName: "unresolved.m4a", duration: 5)
        let capOutside = Capture(audioFileName: "outside.m4a", duration: 5)
        for capture in [capKept, capAnyone, capUnresolved, capOutside] {
            context.insert(capture)
        }
        episode.captures.append(contentsOf: [capKept, capAnyone, capUnresolved])
        otherEpisode.captures.append(capOutside)

        // A capture answering an event.anyone question: promptable, so its span is dropped.
        let anyoneQuestion = Question.fixture(
            text: "Is there anyone you think of with this?",
            templateID: "event.anyone",
            slots: [],
            cue: .event,
            origin: .deck
        )
        context.insert(anyoneQuestion)
        episode.questions.append(anyoneQuestion)
        capAnyone.answersQuestionID = anyoneQuestion.id
        capUnresolved.answersQuestionID = UUID() // names no question anywhere: fail closed

        func whoQuestion(_ span: VerifiedSpan) -> Question {
            let question = Question.fixture(
                text: "Who was \(span.text) to you, back then?",
                templateID: "who.person",
                slots: [span],
                cue: .people,
                origin: .deck
            )
            question.person = person
            return question
        }
        let keptSpan = VerifiedSpan.fixture(text: "my aunt", captureID: capKept.id, start: 0, end: 1)
        let anyoneSpan = VerifiedSpan.fixture(text: "my cousin", captureID: capAnyone.id, start: 0, end: 1)
        let unresolvedSpan = VerifiedSpan.fixture(text: "my neighbour", captureID: capUnresolved.id, start: 0, end: 1)
        let outsideSpan = VerifiedSpan.fixture(text: "my barber", captureID: capOutside.id, start: 0, end: 1)
        for question in [whoQuestion(keptSpan), whoQuestion(anyoneSpan),
                         whoQuestion(unresolvedSpan), whoQuestion(outsideSpan)] {
            context.insert(question)
            episode.questions.append(question)
        }
        try context.save()

        let state = PersonState(person: person)
        XCTAssertEqual(state.spans, [keptSpan])
        XCTAssertEqual(state.episodeCount, 1)
        XCTAssertEqual(state.asks.count, 4)
    }

    func testAdaptersDropSpansInsideACorrectedSegment() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext

        let capture = Capture(audioFileName: "a.m4a", duration: 10)
        try capture.completeTranscript([
            TranscriptSegment(text: "we sailed with Dan", start: 0, end: 2, isFinal: true),
            TranscriptSegment(text: "past the lighthouse", start: 2, end: 4, isFinal: true),
        ])
        // The user corrects segment 0 ("Dan" was "Jan"); segment 1 is untouched.
        try capture.addCorrection(segmentIndex: 0, correctedText: "we sailed with Jan")

        let person = Person(name: "Jan")
        let episode = Episode(typedTitle: "Sailing")
        context.insert(person)
        context.insert(episode)
        context.insert(capture)
        episode.captures.append(capture)
        episode.people.append(person)

        let danSpan = VerifiedSpan.fixture(text: "Dan", captureID: capture.id, start: 0, end: 2)
        let boatSpan = VerifiedSpan.fixture(text: "sailed", captureID: capture.id, start: 0, end: 2)
        let lighthouseSpan = VerifiedSpan.fixture(text: "the lighthouse", captureID: capture.id, start: 2, end: 4)
        let who = Question.fixture(text: "Who was Dan to you, back then?", templateID: "who.person",
                                   slots: [danSpan], cue: .people, origin: .deck)
        who.person = person
        let staleReferent = Question.fixture(text: "You mentioned sailed. Is there anything else about that?",
                                             templateID: "referent.open", slots: [boatSpan], cue: .event, origin: .deck)
        let freshReferent = Question.fixture(text: "You mentioned the lighthouse. Is there anything else about that?",
                                             templateID: "referent.open", slots: [lighthouseSpan], cue: .event, origin: .deck)
        for question in [who, staleReferent, freshReferent] {
            context.insert(question)
            episode.questions.append(question)
        }
        try context.save()

        XCTAssertEqual(EpisodeState(episode: episode).referentSpans, [lighthouseSpan])
        XCTAssertEqual(PersonState(person: person).spans, [])
    }

    func testRecentChannelsFromQuestions() {
        func question(_ templateID: String, cue: CueKind, askedAt: Date?) -> Question {
            let question = Question.fixture(
                text: "t", templateID: templateID, slots: [], cue: cue, origin: .deck
            )
            question.lastAskedAt = askedAt
            return question
        }
        let questions = [
            question("event.else", cue: .event, askedAt: fixedDate),
            question("who.person", cue: .people, askedAt: fixedDate.addingTimeInterval(1)),
            question("broad.open", cue: .event, askedAt: fixedDate.addingTimeInterval(2)),
            question("sensory.place", cue: .sensory, askedAt: nil),
        ]
        XCTAssertEqual(QuestionEngine.recentChannels(from: questions), [.open, .people])
    }
}

// MARK: (o) the empty-period opener (R5)

@MainActor
extension QuestionEngineTests {
    func testEmptyPeriodOffersTitleOpener() {
        let state = PeriodState(episodeCount: 0, asks: [],
                                titleFill: PeriodTitleFill.fixture("High school"))
        let offers = QuestionEngine.queue(for: state)
        XCTAssertEqual(offers.count, 1)
        XCTAssertEqual(offers[0].question.templateID, "period.slot")
        XCTAssertTrue(offers[0].question.text.contains("High school"), offers[0].question.text)
        XCTAssertNil(offers[0].existingQuestionID)
    }

    func testEmptyPeriodWithoutFillOffersNothing() {
        let state = PeriodState(episodeCount: 0, asks: [])
        XCTAssertTrue(QuestionEngine.queue(for: state).isEmpty)
    }

    func testEmptyPeriodReusesExistingOpenOpener() {
        let openerID = UUID()
        let state = PeriodState(episodeCount: 0, asks: [
            askRecord("period.slot", .period, status: .open, id: openerID),
        ], titleFill: PeriodTitleFill.fixture("High school"))
        let offer = QuestionEngine.queue(for: state).first
        XCTAssertEqual(offer?.existingQuestionID, openerID)
    }

    func testAnsweredOpenerIsNotReoffered() {
        let state = PeriodState(episodeCount: 0, asks: [
            askRecord("period.slot", .period, status: .answered),
        ], titleFill: PeriodTitleFill.fixture("High school"))
        XCTAssertTrue(QuestionEngine.queue(for: state).isEmpty)
    }

    func testRetiredOpenerIsNotReoffered() {
        let state = PeriodState(episodeCount: 0, asks: [
            askRecord("period.slot", .period, status: .retired),
        ], titleFill: PeriodTitleFill.fixture("High school"))
        XCTAssertTrue(QuestionEngine.queue(for: state).isEmpty)
    }

    func testOpenerUsesCurrentTitle() {
        let openerID = UUID()
        let state = PeriodState(episodeCount: 0, asks: [
            askRecord("period.slot", .period, status: .open, id: openerID),
        ], titleFill: PeriodTitleFill.fixture("College"))
        let offer = QuestionEngine.queue(for: state).first
        XCTAssertTrue(offer?.question.text.contains("College") == true)
        XCTAssertEqual(offer?.existingQuestionID, openerID)
    }

    func testPeriodWithEpisodeDoesNotOfferOpener() {
        let state = PeriodState(episodeCount: 1, asks: [],
                                titleFill: PeriodTitleFill.fixture("High school"))
        XCTAssertEqual(
            QuestionEngine.queue(for: state).map(\.question.templateID),
            ["period.else", "period.who", "period.where"]
        )
    }

    func testRetiredOpenerDoesNotSilencePeriodCues() {
        let state = PeriodState(episodeCount: 1, asks: [
            askRecord("period.slot", .period, status: .retired),
        ], titleFill: PeriodTitleFill.fixture("High school"))
        XCTAssertEqual(
            QuestionEngine.queue(for: state).map(\.question.templateID),
            ["period.else", "period.who", "period.where"]
        )
    }

    func testPeriodStateAdapterCarriesTitleFill() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let period = Period(title: "High school", sortOrder: 0)
        context.insert(period)
        try context.save()

        let state = PeriodState(period: period, questions: [])
        XCTAssertEqual(state.titleFill?.text, "High school")
    }
}
