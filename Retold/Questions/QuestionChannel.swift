import Foundation

/// The channel a question is on, for the "never more than two in a row" rule (PLAN
/// section 7: the cap is on channel, not merely on cue level).
enum QuestionChannel: String, CaseIterable, Sendable {
    case open, time, place, people, sensory, referent, sequence, theme

    /// The fixed lookup for the 25 deck template ids.
    private static let table: [String: QuestionChannel] = [
        "broad.open": .open, "period.else": .open, "period.slot": .open, "event.else": .open,
        "when.open": .time, "when.cue": .time, "event.shape": .time,
        "period.where": .place,
        "who.person": .people, "period.who": .people, "event.anyone": .people,
        "people.describe": .people, "people.talk": .people, "people.together": .people,
        "sensory.place": .sensory, "sensory.everything": .sensory, "sensory.mentioned": .sensory,
        "referent.open": .referent,
        "sequence.connect": .sequence, "sequence.otherTimes": .sequence,
        "theme.turningPoint": .theme, "theme.family": .theme, "theme.work": .theme,
        "theme.body": .theme, "theme.close": .theme,
    ]

    /// The channel a question is on. An id outside the fixed table falls back by cue.
    static func of(templateID: String, cue: CueKind) -> QuestionChannel {
        if let channel = table[templateID] { return channel }
        switch cue {
        case .period, .event: return .open
        case .sensory: return .sensory
        case .people: return .people
        case .sequence: return .sequence
        }
    }
}
