import Foundation
import SwiftData

/// Attaches a capture that answers an episode's question straight to that episode (R7b section 5).
/// The answer never runs the filing pipeline and never shows in Unfiled.
@MainActor
enum AnswerAttacher {
    /// A shorter capture still attaches, but leaves its question open: `.answered` is terminal, and
    /// a tap on Answer now followed by an immediate Stop is not an answer.
    static let minimumAnswerDuration: TimeInterval = 2

    /// Pure. True iff `answersQuestionID` is non-nil and in `questionsWithEpisode`. Transcription
    /// status is deliberately not an input: a pending answer attaches at once and never shows in Unfiled.
    nonisolated static func isAttachable(answersQuestionID: UUID?, questionsWithEpisode: Set<UUID>) -> Bool {
        guard let answersQuestionID else { return false }
        return questionsWithEpisode.contains(answersQuestionID)
    }

    /// Attaches every attachable unfiled capture. Returns the attached capture ids.
    @discardableResult
    static func attachPending(in context: ModelContext) throws -> [UUID] {
        let unfiled = try context.fetch(
            FetchDescriptor<Capture>(predicate: #Predicate<Capture> { $0.episode == nil })
        )
        let questions = try context.fetch(FetchDescriptor<Question>())
        // Built in memory: no enum or optional chain goes in a #Predicate.
        var byID: [UUID: (question: Question, episode: Episode)] = [:]
        for question in questions {
            if let episode = question.episode {
                byID[question.id] = (question, episode)
            }
        }
        let attachableIDs = Set(byID.keys)

        var attached: [UUID] = []
        for capture in unfiled {
            guard isAttachable(answersQuestionID: capture.answersQuestionID, questionsWithEpisode: attachableIDs),
                  let questionID = capture.answersQuestionID,
                  let pair = byID[questionID]
            else { continue }
            pair.episode.captures.append(capture)
            if capture.duration >= minimumAnswerDuration {
                pair.question.record(.answered)
            }
            // setExcerpt is not called: the excerpt is the first telling's.
            attached.append(capture.id)
        }

        if !attached.isEmpty {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
        return attached
    }

    /// For a capture that will go through the confirm flow: its question's period id, if the
    /// question has a period and no episode. nil otherwise (theme, unknown, none).
    static func answeredPeriodID(for capture: Capture, in context: ModelContext) -> UUID? {
        guard let questionID = capture.answersQuestionID,
              let questions = try? context.fetch(FetchDescriptor<Question>()),
              let question = questions.first(where: { $0.id == questionID }),
              question.episode == nil
        else { return nil }
        return question.period?.id
    }
}
