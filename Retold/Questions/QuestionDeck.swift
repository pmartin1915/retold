import Foundation

/// The seeded question deck (PLAN section 8): the six filing follow-ups first, then the 19
/// authored templates below, in this order. Every pattern must pass LeadingQuestionLint and
/// WellnessLint; a pattern that fails either lint is a spec conflict, not something to patch.
/// The theme ids follow Guided Autobiography's themes (PLAN section 8: themes usable, text not).
enum QuestionDeck {
    static let all: [QuestionTemplate] = FilingTemplates.all + [
        QuestionTemplate(
            id: "period.else", cue: .period,
            pattern: "What else comes to mind from that time?"),
        QuestionTemplate(
            id: "period.who", cue: .period,
            pattern: "Who do you think of when you think of that time?"),
        QuestionTemplate(
            id: "period.where", cue: .period,
            pattern: "Is there anywhere that comes to mind from that time?"),
        QuestionTemplate(
            id: "period.slot", cue: .period,
            pattern: "When you think of {slot}, what comes back first?"),
        QuestionTemplate(
            id: "event.else", cue: .event,
            pattern: "Is there anything else about that?"),
        QuestionTemplate(
            id: "event.shape", cue: .event,
            pattern: "How do you remember it \u{2014} one moment, a stretch of days, something else?"),
        QuestionTemplate(
            id: "event.anyone", cue: .event,
            pattern: "Is there anyone you think of with this?"),
        QuestionTemplate(
            id: "sensory.everything", cue: .sensory,
            pattern: "Anything about the place itself \u{2014} the light, the sounds, the weather, what you were wearing? However small."),
        QuestionTemplate(
            id: "sensory.mentioned", cue: .sensory,
            pattern: "You mentioned {slot} \u{2014} is there anything else you remember of it?"),
        QuestionTemplate(
            id: "people.describe", cue: .people,
            pattern: "How would you describe {slot}?"),
        QuestionTemplate(
            id: "people.talk", cue: .people,
            pattern: "Is there anything about how {slot} talked that stays with you?"),
        QuestionTemplate(
            id: "people.together", cue: .people,
            pattern: "Is there anything you remember doing with {slot}?"),
        QuestionTemplate(
            id: "sequence.connect", cue: .sequence,
            pattern: "Does this connect to anything else you've thought about since?"),
        QuestionTemplate(
            id: "sequence.otherTimes", cue: .sequence,
            pattern: "Has anything about this come back to you at other times?"),
        QuestionTemplate(
            id: "theme.turningPoint", cue: .period,
            pattern: "Is there anything you'd call a turning point?"),
        QuestionTemplate(
            id: "theme.family", cue: .period,
            pattern: "What comes to mind when you think of where your family comes from?"),
        QuestionTemplate(
            id: "theme.work", cue: .period,
            pattern: "What comes to mind when you think of work you've done?"),
        QuestionTemplate(
            id: "theme.body", cue: .period,
            pattern: "Is there anything about your health and your body, at any age, that comes to mind?"),
        QuestionTemplate(
            id: "theme.close", cue: .period,
            pattern: "Who comes to mind when you think of someone you've been close to?"),
    ]
}
