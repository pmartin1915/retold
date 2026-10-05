import Foundation
import SwiftData
import XCTest
@testable import Retold

@MainActor
final class AnswerAttacherTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var captureAt: Date { now.addingTimeInterval(-100) }

    override func setUpWithError() throws {
        container = try RetoldSchema.makeInMemoryContainer()
        context = container.mainContext
    }

    // MARK: Fixtures

    private func words(_ text: String, start: TimeInterval = 0) -> [TranscriptSegment] {
        [TranscriptSegment(text: text, start: start, end: start + 3, isFinal: true)]
    }

    /// A filed episode with one completed first capture and its excerpt set.
    private func makeEpisode(first text: String = "we sat on the porch") throws -> Episode {
        let capture = Capture(audioFileName: "first.m4a", duration: 5, createdAt: captureAt)
        context.insert(capture)
        try capture.completeTranscript(words(text))
        let episode = Episode(typedTitle: "The porch", createdAt: captureAt)
        context.insert(episode)
        episode.captures.append(capture)
        if let transcript = capture.completedTranscript {
            episode.setExcerpt(from: transcript)
        }
        try context.save()
        return episode
    }

    private func deckQuestion(_ templateID: String, slots: [VerifiedSpan] = []) throws -> Question {
        let template = try XCTUnwrap(QuestionDeck.template(id: templateID))
        let question = try TemplateAssembler.assemble(template, slots: slots).question(createdAt: captureAt)
        context.insert(question)
        return question
    }

    private func episodeQuestion(_ episode: Episode, templateID: String = "event.else") throws -> Question {
        let question = try deckQuestion(templateID)
        episode.questions.append(question)
        try context.save()
        return question
    }

    private func answerCapture(
        to questionID: UUID?,
        duration: TimeInterval = 5,
        offset: TimeInterval = 50
    ) throws -> Capture {
        let capture = Capture(audioFileName: "answer.m4a", duration: duration,
                              createdAt: now.addingTimeInterval(offset))
        capture.answersQuestionID = questionID
        context.insert(capture)
        try context.save()
        return capture
    }

    // MARK: isAttachable

    func testIsAttachableRequiresEpisodeQuestion() {
        let id = UUID()
        XCTAssertTrue(AnswerAttacher.isAttachable(answersQuestionID: id, questionsWithEpisode: [id]))
        XCTAssertFalse(AnswerAttacher.isAttachable(answersQuestionID: id, questionsWithEpisode: [UUID()]))
        XCTAssertFalse(AnswerAttacher.isAttachable(answersQuestionID: id, questionsWithEpisode: []))
    }

    func testNilQuestionIDNotAttachable() {
        XCTAssertFalse(AnswerAttacher.isAttachable(answersQuestionID: nil, questionsWithEpisode: [UUID()]))
        XCTAssertFalse(AnswerAttacher.isAttachable(answersQuestionID: nil, questionsWithEpisode: []))
    }

    // MARK: attachPending

    func testAttachesToQuestionsEpisode() throws {
        let episode = try makeEpisode()
        let other = try makeEpisode(first: "a different story")
        let question = try episodeQuestion(episode)
        let capture = try answerCapture(to: question.id)

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [capture.id])
        XCTAssertEqual(capture.episode?.id, episode.id)
        XCTAssertTrue(episode.captures.contains { $0.id == capture.id })
        XCTAssertFalse(other.captures.contains { $0.id == capture.id })

        let reopened = ModelContext(container)
        let saved = try XCTUnwrap(
            try reopened.fetch(FetchDescriptor<Capture>()).first { $0.id == capture.id })
        XCTAssertEqual(saved.episode?.id, episode.id)
    }

    func testAttachRecordsAnswered() throws {
        let episode = try makeEpisode()
        let question = try episodeQuestion(episode)
        _ = try answerCapture(to: question.id, duration: 5)

        try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(question.status, .answered)
    }

    func testAttachLeavesExcerpt() throws {
        let episode = try makeEpisode(first: "we sat on the porch")
        XCTAssertEqual(episode.excerpt, "we sat on the porch")
        let question = try episodeQuestion(episode)
        let capture = try answerCapture(to: question.id)
        try capture.completeTranscript(words("and the dog was there too"))
        try context.save()

        try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(capture.episode?.id, episode.id)
        XCTAssertEqual(episode.excerpt, "we sat on the porch")
    }

    func testAttachIgnoresTranscriptionStatus() throws {
        let episode = try makeEpisode()
        let question = try episodeQuestion(episode)
        let capture = try answerCapture(to: question.id)
        XCTAssertEqual(capture.transcriptionStatus, .pending)

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [capture.id])
        XCTAssertEqual(capture.episode?.id, episode.id)
    }

    func testPeriodQuestionAnswerStaysUnfiled() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        let periodQuestion = try deckQuestion("period.else")
        periodQuestion.period = period
        try context.save()
        let capture = try answerCapture(to: periodQuestion.id)

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [])
        XCTAssertNil(capture.episode)
        XCTAssertEqual(periodQuestion.status, .open)
    }

    func testThemeQuestionAnswerStaysUnfiled() throws {
        let theme = try deckQuestion("theme.turningPoint")
        try context.save()
        let capture = try answerCapture(to: theme.id)

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [])
        XCTAssertNil(capture.episode)
        XCTAssertEqual(theme.status, .open)
    }

    func testUnknownQuestionStaysUnfiled() throws {
        _ = try makeEpisode()
        let capture = try answerCapture(to: UUID())

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [])
        XCTAssertNil(capture.episode)
    }

    func testFiledCaptureUntouched() throws {
        let home = try makeEpisode(first: "the first story")
        let target = try makeEpisode(first: "the second story")
        let question = try episodeQuestion(target)
        let capture = try answerCapture(to: question.id)
        home.captures.append(capture)
        try context.save()

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [])
        XCTAssertEqual(capture.episode?.id, home.id)
        XCTAssertEqual(question.status, .open)
    }

    func testNothingToAttachSavesNothing() throws {
        _ = try answerCapture(to: nil)
        XCTAssertFalse(context.hasChanges)

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [])
        XCTAssertFalse(context.hasChanges)
    }

    // MARK: answeredPeriodID

    func testAnsweredPeriodIDForPeriodQuestion() throws {
        let period = Period(title: "High school", sortOrder: 0, createdAt: now)
        context.insert(period)
        let question = try deckQuestion("period.else")
        question.period = period
        try context.save()
        let capture = try answerCapture(to: question.id)

        XCTAssertEqual(AnswerAttacher.answeredPeriodID(for: capture, in: context), period.id)
    }

    func testAnsweredPeriodIDNilForThemeAndEpisodeQuestions() throws {
        let theme = try deckQuestion("theme.work")
        let episode = try makeEpisode()
        let episodeQ = try episodeQuestion(episode)
        try context.save()

        let themeCapture = try answerCapture(to: theme.id)
        let episodeCapture = try answerCapture(to: episodeQ.id)
        let unknownCapture = try answerCapture(to: UUID())
        let noneCapture = try answerCapture(to: nil)

        XCTAssertNil(AnswerAttacher.answeredPeriodID(for: themeCapture, in: context))
        XCTAssertNil(AnswerAttacher.answeredPeriodID(for: episodeCapture, in: context))
        XCTAssertNil(AnswerAttacher.answeredPeriodID(for: unknownCapture, in: context))
        XCTAssertNil(AnswerAttacher.answeredPeriodID(for: noneCapture, in: context))
    }

    // MARK: Short answers, the opener, person questions

    func testShortAnswerAttachesButQuestionStaysOpen() throws {
        for duration in [1.5, 0] as [TimeInterval] {
            let episode = try makeEpisode(first: "story \(duration)")
            let question = try episodeQuestion(episode)
            let capture = try answerCapture(to: question.id, duration: duration)

            let attached = try AnswerAttacher.attachPending(in: context)

            XCTAssertEqual(attached, [capture.id], "duration \(duration)")
            XCTAssertEqual(capture.episode?.id, episode.id, "duration \(duration)")
            XCTAssertEqual(question.status, .open, "duration \(duration)")
        }
    }

    func testBroadOpenAnswerDoesNotRearmOpener() throws {
        let episode = try makeEpisode()
        let broad = try episodeQuestion(episode, templateID: "broad.open")
        let before = EpisodeState(episode: episode).latestCaptureAt
        XCTAssertEqual(before, captureAt)
        let capture = try answerCapture(to: broad.id)

        try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(capture.episode?.id, episode.id)
        XCTAssertEqual(broad.status, .answered)
        XCTAssertEqual(EpisodeState(episode: episode).latestCaptureAt, before)
    }

    func testPersonQuestionAnswerLandsOnSlotEpisode() throws {
        let episode = try makeEpisode()
        let slotCapture = try XCTUnwrap(episode.captures.first)
        let person = Person(name: "Aunt Rosa")
        context.insert(person)
        episode.people.append(person)
        let span = VerifiedSpan.fixture(text: "Aunt Rosa", captureID: slotCapture.id, start: 0, end: 1)
        let question = try deckQuestion("people.describe", slots: [span])
        episode.questions.append(question)
        question.person = person
        try context.save()
        let capture = try answerCapture(to: question.id)

        let attached = try AnswerAttacher.attachPending(in: context)

        XCTAssertEqual(attached, [capture.id])
        XCTAssertEqual(capture.episode?.id, episode.id)
        XCTAssertEqual(question.status, .answered)
    }

    // MARK: Two contexts

    func testAttachThenStaleFilePassSaveKeepsBoth() throws {
        let episode = try makeEpisode()
        let question = try episodeQuestion(episode)
        let capture = try answerCapture(to: question.id)
        let captureID = capture.id

        // 1. The file pass's scan sees the capture unattached, then transcribes (awaits).
        let scan = ModelContext(container)
        XCTAssertNil(try XCTUnwrap(try scan.fetch(FetchDescriptor<Capture>()).first { $0.id == captureID }).episode)

        // 2. Meanwhile the main context attaches and saves.
        try AnswerAttacher.attachPending(in: context)

        // 3. The file pass writes its result. A stale snapshot saved here wiped capture.episode
        //    (CI run 37249014918); the result is applied to a capture fetched fresh instead.
        CaptureCoordinator.applyFilePassResult(
            captureID: captureID, segments: words("and the dog was there too"), in: container)

        // 4. After a reopen, the capture has both.
        let reopened = ModelContext(container)
        let saved = try XCTUnwrap(
            try reopened.fetch(FetchDescriptor<Capture>()).first { $0.id == captureID })
        XCTAssertEqual(saved.episode?.id, episode.id)
        XCTAssertEqual(saved.transcriptionStatus, .complete)
        XCTAssertEqual(saved.transcript.map(\.text), ["and the dog was there too"])
    }

    // MARK: Theme answers go through the confirm flow

    func testThemeAnswerFiledLeavesThemeQueue() throws {
        let card = ThemeCards.all[0]
        let theme = try deckQuestion(card.templateIDs[0])
        try context.save()

        let capture = try answerCapture(to: theme.id)
        try capture.completeTranscript(words("the year everything changed"))
        try context.save()
        XCTAssertEqual(try AnswerAttacher.attachPending(in: context), [])

        var before = try context.fetch(FetchDescriptor<Question>())
        XCTAssertTrue(
            QuestionEngine.queue(for: card, state: ThemeState(card: card, questions: before))
                .contains { $0.question.templateID == card.templateIDs[0] })

        var draft = ConfirmDraft.make(
            captureID: capture.id, outcome: nil, periods: [], people: [], places: [])
        draft.typedTitle = "A memory"
        try ConfirmFiler.file(draft, capture: capture, in: context, now: now)

        before = try context.fetch(FetchDescriptor<Question>())
        let state = ThemeState(card: card, questions: before)
        XCTAssertEqual(state.asks.map(\.status), [.answered])
        XCTAssertFalse(
            QuestionEngine.queue(for: card, state: state)
                .contains { $0.question.templateID == card.templateIDs[0] })
    }
}
