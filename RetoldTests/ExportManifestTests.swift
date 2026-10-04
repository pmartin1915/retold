import Foundation
import SwiftData
import XCTest
@testable import Retold

final class ExportManifestTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let exportedAt = Date(timeIntervalSince1970: 1_773_569_100)   // 2026-03-15 10:05 UTC

    // Fixed ids so the golden strings are stable.
    private let periodAID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let periodBID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let ep1ID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let ep2ID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private let ep3ID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    private let cap1ID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    private let capUnfiledID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    private let qPeriodID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    private let qThemeID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    private let qEpisodeID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    private let detailSensoryID = UUID(uuidString: "31313131-3131-3131-3131-313131313131")!
    private let detailEmotionID = UUID(uuidString: "14141414-1414-1414-1414-141414141414")!
    private let capAID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let capBID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let quietCapID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    // Fixed dates (UTC): readable in the golden strings.
    private let pADate = Date(timeIntervalSince1970: 1_767_268_800)       // 2026-01-01 12:00
    private let pBDate = Date(timeIntervalSince1970: 1_767_355_200)       // 2026-01-02 12:00
    private let ep1Date = Date(timeIntervalSince1970: 1_767_601_800)      // 2026-01-05 08:30
    private let ep2Date = Date(timeIntervalSince1970: 1_767_690_000)      // 2026-01-06 09:00
    private let ep3Date = Date(timeIntervalSince1970: 1_767_800_700)      // 2026-01-07 15:45
    private let capUnfiledDate = Date(timeIntervalSince1970: 1_767_856_500) // 2026-01-08 07:15

    // MARK: Fixture library (value snapshots, built straight from section 4.1 shapes)

    private var questionPeriod: ExportQuestion {
        ExportQuestion(id: qPeriodID, text: "Who else comes to mind from that time?",
                       createdAt: pADate.addingTimeInterval(3_600))
    }

    private var questionTheme: ExportQuestion {
        ExportQuestion(id: qThemeID, text: "Is there anything you'd call a turning point?",
                       createdAt: pBDate.addingTimeInterval(3_600))
    }

    private var questionEpisode: ExportQuestion {
        ExportQuestion(id: qEpisodeID, text: "Where did you keep the canoe that winter?",
                       createdAt: ep1Date.addingTimeInterval(7_200))
    }

    private var periodA: ExportPeriod {
        ExportPeriod(id: periodAID, title: "Early childhood", startAge: 12, endAge: 14,
                     sortOrder: 0, createdAt: pADate, openQuestions: [questionPeriod])
    }

    private var periodB: ExportPeriod {
        ExportPeriod(id: periodBID, title: "Primary school", startAge: nil, endAge: nil,
                     sortOrder: 1, createdAt: pBDate, openQuestions: [])
    }

    private var episodeFull: ExportEpisode {
        ExportEpisode(
            id: ep1ID, confirmedTitle: "The lake summer",
            excerpt: "The summer before eighth grade we went to Camp Lakeview and the days were long",
            periodID: periodAID, approxYear: 1998, approxAge: 12,
            place: "Camp Lakeview", people: ["Ruth", "Dan"],
            details: [
                ExportDetail(id: detailSensoryID, text: "cold water", kind: .sensory),
                ExportDetail(id: detailEmotionID, text: "the smell of pine", kind: .emotion),
            ],
            openQuestions: [questionEpisode],
            createdAt: ep1Date)
    }

    private var episodeBare: ExportEpisode {
        ExportEpisode(id: ep2ID, confirmedTitle: nil, excerpt: "", periodID: periodBID,
                      approxYear: nil, approxAge: nil, place: nil, people: [],
                      details: [], openQuestions: [], createdAt: ep2Date)
    }

    private var episodeLoose: ExportEpisode {
        ExportEpisode(id: ep3ID, confirmedTitle: "The move",
                      excerpt: "We packed the car before dawn",
                      periodID: nil, approxYear: nil, approxAge: nil, place: nil, people: [],
                      details: [], openQuestions: [], createdAt: ep3Date)
    }

    private var captureFiled: ExportCapture {
        ExportCapture(id: cap1ID, audioFileName: "lake.m4a", duration: 61.9, createdAt: ep1Date,
                      status: .complete, segments: [], corrections: [], episodeID: ep1ID)
    }

    private var captureUnfiled: ExportCapture {
        ExportCapture(id: capUnfiledID, audioFileName: "unfiled.m4a", duration: 3725,
                      createdAt: capUnfiledDate, status: .pending, segments: [], corrections: [],
                      episodeID: nil)
    }

    private func goldenLibrary() -> ExportLibrary {
        ExportLibrary(
            periods: [periodA, periodB],
            episodes: [episodeFull, episodeBare, episodeLoose],
            captures: [captureFiled, captureUnfiled],
            otherOpenQuestions: [questionTheme])
    }

    private func manifest(_ library: ExportLibrary) -> ExportManifest {
        ExportManifest.build(library, exportedAt: exportedAt, timeZone: utc)
    }

    private func indexText(_ library: ExportLibrary) -> String {
        guard case .text(let string) = manifest(library).files[0].content else {
            XCTFail("index.md is not a text file")
            return ""
        }
        return string
    }

    private func transcriptText(_ library: ExportLibrary, path: String) -> String {
        guard let file = manifest(library).files.first(where: { $0.path == path }),
              case .text(let string) = file.content else {
            XCTFail("missing transcript \(path)")
            return ""
        }
        return string
    }

    // MARK: Goldens

    func testIndexGolden() {
        let expected = [
            "# Retold export",
            "",
            "Exported 2026-03-15 10:05",
            "Recordings may name other people.",
            "",
            "## Early childhood",
            "Ages 12\u{2013}14",
            "",
            "### The lake summer",
            "> The summer before eighth grade we went to Camp Lakeview and the days were long",
            "- When: 1998; age 12",
            "- Place: Camp Lakeview",
            "- People: Dan, Ruth",
            "- Details:",
            "  - \"the smell of pine\" (emotion)",
            "  - \"cold water\" (sensory)",
            "- Captures:",
            "  - 2026-01-05 08:30 \u{00B7} 1:01 \u{00B7} [transcript](transcripts/66666666-6666-6666-6666-666666666666.md) \u{00B7} [audio](audio/66666666-6666-6666-6666-666666666666.m4a)",
            "- Open questions:",
            "  - Where did you keep the canoe that winter?",
            "",
            "Open questions for this period:",
            "- Who else comes to mind from that time?",
            "",
            "## Primary school",
            "",
            "### Untitled",
            "",
            "## Not in a period",
            "",
            "### The move",
            "> We packed the car before dawn",
            "",
            "## Unfiled captures",
            "- 2026-01-08 07:15 \u{00B7} 1:02:05 \u{00B7} [transcript](transcripts/77777777-7777-7777-7777-777777777777.md) \u{00B7} [audio](audio/77777777-7777-7777-7777-777777777777.m4a)",
            "",
            "## Other open questions",
            "- Is there anything you'd call a turning point?",
        ].joined(separator: "\n") + "\n"
        XCTAssertEqual(indexText(goldenLibrary()), expected)
    }

    func testTranscriptGolden() {
        let correction = UserCorrection(
            id: UUID(), segmentIndex: 1,
            originalText: "and it smelled of salt",
            correctedText: "and it smelled of the sea",
            createdAt: ep1Date.addingTimeInterval(300))   // 2026-01-05 08:35
        let capture = ExportCapture(
            id: cap1ID, audioFileName: "lake.m4a", duration: 61.9, createdAt: ep1Date,
            status: .complete,
            segments: [
                TranscriptSegment(text: "We went down to the pier", start: 0, end: 5, isFinal: true),
                TranscriptSegment(text: "and it smelled of salt", start: 5, end: 9, isFinal: true),
                TranscriptSegment(text: "the old boat", start: 9, end: 12, isFinal: false),
            ],
            corrections: [correction],
            episodeID: ep1ID)
        let library = ExportLibrary(periods: [], episodes: [], captures: [capture],
                                    otherOpenQuestions: [])

        let expected = [
            "# Capture 66666666-6666-6666-6666-666666666666",
            "",
            "Recorded 2026-01-05 08:30 \u{00B7} 1:01 \u{00B7} transcript complete",
            "Audio: ../audio/66666666-6666-6666-6666-666666666666.m4a",
            "",
            "[0:00\u{2013}0:05] We went down to the pier",
            "[0:05\u{2013}0:09] and it smelled of salt",
            "[0:09\u{2013}0:12] the old boat",
            "",
            "## Corrections",
            "",
            "- [0:05\u{2013}0:09] \"and it smelled of salt\" \u{2192} \"and it smelled of the sea\" (2026-01-05 08:35)",
        ].joined(separator: "\n") + "\n"
        XCTAssertEqual(transcriptText(library, path: "transcripts/\(cap1ID.uuidString).md"), expected)
    }

    func testEmptyTranscriptLine() {
        let capture = ExportCapture(id: quietCapID, audioFileName: "quiet.m4a", duration: 0,
                                    createdAt: ep1Date, status: .pending, segments: [],
                                    corrections: [], episodeID: nil)
        let library = ExportLibrary(periods: [], episodes: [], captures: [capture],
                                    otherOpenQuestions: [])
        let expected = [
            "# Capture CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
            "",
            "Recorded 2026-01-05 08:30 \u{00B7} 0:00 \u{00B7} transcript pending",
            "Audio: ../audio/CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC.m4a",
            "",
            "(no transcript)",
        ].joined(separator: "\n") + "\n"
        XCTAssertEqual(transcriptText(library, path: "transcripts/\(quietCapID.uuidString).md"), expected)
    }

    func testUntitledWhenTitleNotConfirmed() {
        XCTAssertTrue(indexText(goldenLibrary()).contains("### Untitled"))
    }

    func testFileOrderAndPaths() {
        let capA = ExportCapture(id: capAID, audioFileName: "a.caf", duration: 5,
                                 createdAt: ep1Date, status: .complete, segments: [],
                                 corrections: [], episodeID: nil)
        let capB = ExportCapture(id: capBID, audioFileName: "b", duration: 5,
                                 createdAt: ep2Date, status: .complete, segments: [],
                                 corrections: [], episodeID: nil)
        let built = manifest(ExportLibrary(periods: [], episodes: [], captures: [capB, capA],
                                           otherOpenQuestions: []))
        XCTAssertEqual(built.files.map(\.path), [
            "index.md",
            "transcripts/\(capAID.uuidString).md",
            "audio/\(capAID.uuidString).caf",
            "transcripts/\(capBID.uuidString).md",
            "audio/\(capBID.uuidString).m4a",
        ])
    }

    func testTimeFormats() {
        func unfiled(_ id: UUID, _ duration: TimeInterval, _ createdAt: Date) -> ExportCapture {
            ExportCapture(id: id, audioFileName: "x.m4a", duration: duration, createdAt: createdAt,
                          status: .complete, segments: [], corrections: [], episodeID: nil)
        }
        let library = ExportLibrary(
            periods: [], episodes: [],
            captures: [
                unfiled(capAID, 61.9, ep1Date),
                unfiled(capBID, 3725, ep2Date),
                unfiled(quietCapID, 0, ep3Date),
            ],
            otherOpenQuestions: [])
        let index = indexText(library)
        XCTAssertTrue(index.contains("\u{00B7} 1:01 \u{00B7}"), index)
        XCTAssertTrue(index.contains("\u{00B7} 1:02:05 \u{00B7}"), index)
        XCTAssertTrue(index.contains("\u{00B7} 0:00 \u{00B7}"), index)
    }

    func testOutputIndependentOfInputOrder() {
        let forward = manifest(goldenLibrary())
        let reversedLibrary = ExportLibrary(
            periods: [periodB, periodA],
            episodes: [
                ExportEpisode(id: ep3ID, confirmedTitle: "The move",
                              excerpt: "We packed the car before dawn",
                              periodID: nil, approxYear: nil, approxAge: nil, place: nil, people: [],
                              details: [], openQuestions: [], createdAt: ep3Date),
                episodeBare,
                ExportEpisode(
                    id: ep1ID, confirmedTitle: "The lake summer",
                    excerpt: "The summer before eighth grade we went to Camp Lakeview and the days were long",
                    periodID: periodAID, approxYear: 1998, approxAge: 12,
                    place: "Camp Lakeview", people: ["Dan", "Ruth"],
                    details: [
                        ExportDetail(id: detailEmotionID, text: "the smell of pine", kind: .emotion),
                        ExportDetail(id: detailSensoryID, text: "cold water", kind: .sensory),
                    ],
                    openQuestions: [questionEpisode],
                    createdAt: ep1Date),
            ],
            captures: [captureUnfiled, captureFiled],
            otherOpenQuestions: [questionTheme])
        XCTAssertEqual(manifest(reversedLibrary), forward)
    }

    func testNewlinesInTitlesBecomeSpaces() {
        let period = ExportPeriod(id: periodAID, title: "Early\nchildhood", startAge: nil,
                                  endAge: nil, sortOrder: 0, createdAt: pADate, openQuestions: [])
        let library = ExportLibrary(periods: [period], episodes: [], captures: [],
                                    otherOpenQuestions: [])
        XCTAssertTrue(indexText(library).contains("## Early childhood"))
    }

    func testEmptyLibraryIndex() {
        let library = ExportLibrary(periods: [], episodes: [], captures: [], otherOpenQuestions: [])
        XCTAssertEqual(indexText(library),
                       "# Retold export\n\nExported 2026-03-15 10:05\nRecordings may name other people.\n")
    }

    func testYearPrintsWithoutGrouping() {
        let episode = ExportEpisode(id: ep1ID, confirmedTitle: nil, excerpt: "", periodID: nil,
                                    approxYear: 1998, approxAge: nil, place: nil, people: [],
                                    details: [], openQuestions: [], createdAt: ep1Date)
        let library = ExportLibrary(periods: [], episodes: [episode], captures: [],
                                    otherOpenQuestions: [])
        XCTAssertTrue(indexText(library).contains("- When: 1998"))
    }

    // MARK: The SwiftData adapter

    @MainActor
    func testAdapterPrintsOnlyConfirmedFacts() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let capture = Capture(audioFileName: "a.m4a", duration: 5, createdAt: ep1Date)
        capture.logRejected(.title, text: "UNIQUE-REJECTED-TITLE")
        let span = VerifiedSpan.fixture(text: "UNIQUE-PROPOSED-TITLE", captureID: capture.id,
                                        start: 0, end: 1)
        let episode = Episode(titleQuote: span, createdAt: ep2Date)
        context.insert(capture)
        context.insert(episode)
        try context.save()

        let library = ExportLibrary(periods: [], episodes: [episode], captures: [capture],
                                    questions: [])
        let index = indexText(library)
        XCTAssertTrue(index.contains("Untitled"))
        XCTAssertFalse(index.contains("UNIQUE-PROPOSED-TITLE"))
        XCTAssertFalse(index.contains("UNIQUE-REJECTED-TITLE"))
    }

    @MainActor
    func testAdapterRoutesQuestions() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let period = Period(title: "Early childhood", sortOrder: 0, createdAt: pADate)
        let episode = Episode(typedTitle: "The lake summer", createdAt: ep1Date)
        context.insert(period)
        context.insert(episode)
        episode.period = period

        func question(_ text: String, _ templateID: String, _ createdAt: Date) -> Question {
            Question.fixture(text: text, templateID: templateID, slots: [], cue: .period,
                             origin: .deck, createdAt: createdAt)
        }
        let open = question("Open on the episode", "event.else", ep1Date)
        let skipped = question("Skipped on the episode", "period.who", ep1Date.addingTimeInterval(60))
        let answered = question("Answered on the episode", "sensory.place", ep1Date.addingTimeInterval(120))
        answered.status = .answered
        skipped.status = .skipped
        let broad = question("Anything else at all, however small?", "broad.open", ep1Date.addingTimeInterval(180))
        let periodQuestion = question("Who else comes to mind from that time?", "period.else", pADate)
        let themeQuestion = question("What comes to mind when you think of work you've done?",
                                     "theme.work", pBDate)
        for item in [open, skipped, answered, broad] {
            context.insert(item)
            episode.questions.append(item)
        }
        context.insert(periodQuestion)
        periodQuestion.period = period
        context.insert(themeQuestion)
        try context.save()

        let library = ExportLibrary(periods: [period], episodes: [episode], captures: [],
                                    questions: [open, skipped, answered, broad, periodQuestion, themeQuestion])
        let exportedEpisode = try XCTUnwrap(library.episodes.first { $0.id == episode.id })
        XCTAssertEqual(exportedEpisode.openQuestions.map(\.id), [open.id, skipped.id])
        let exportedPeriod = try XCTUnwrap(library.periods.first { $0.id == period.id })
        XCTAssertEqual(exportedPeriod.openQuestions.map(\.id), [periodQuestion.id])
        XCTAssertEqual(library.otherOpenQuestions.map(\.id), [themeQuestion.id])
    }

    @MainActor
    func testAdapterExportsCurrentPeriodTitleInOpener() throws {
        let container = try RetoldSchema.makeInMemoryContainer()
        let context = container.mainContext
        let period = Period(title: "Junior high", sortOrder: 0, createdAt: pADate)
        context.insert(period)

        let template = try XCTUnwrap(QuestionDeck.template(id: "period.slot"))
        let assembled = try TemplateAssembler.assemble(template, periodTitle: period.titleFill)
        let question = assembled.question(createdAt: pADate)
        question.period = period
        context.insert(question)
        try context.save()

        // The user renames the period after the question was persisted.
        period.title = "Middle school"
        try context.save()

        let library = ExportLibrary(periods: [period], episodes: [], captures: [],
                                    questions: [question])
        let exportedPeriod = try XCTUnwrap(library.periods.first)
        XCTAssertEqual(exportedPeriod.openQuestions.first?.text,
                       "When you think of Middle school, what comes back first?")
    }
}
