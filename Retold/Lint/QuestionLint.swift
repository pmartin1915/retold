import Foundation

/// Leading-question lint (PLAN section 7). Deterministic and lexical: it lints a template's literal
/// text, with every `{slot}` masked, because slot content is a verified transcript span and so the
/// user's own words. Slots get their own guard (`SlotGuard`).
enum LintRule: String, Hashable, Sendable, CaseIterable {
    case properNoun, numeral, emotion, ordinal, bareDefinite, intensifier, alternative
    case unmentionedChannel, degenerateSlot
}

struct LintViolation: Equatable, Sendable {
    let rule: LintRule
    let evidence: String
}

enum SensoryChannel: String, Hashable, Sendable, CaseIterable {
    case sight, sound, smell, taste, touch, weather, clothing

    private static let words: [String: SensoryChannel] = [
        "light": .sight, "see": .sight, "saw": .sight, "seen": .sight, "look": .sight, "looked": .sight,
        "color": .sight, "colors": .sight, "colour": .sight, "colours": .sight,
        "sound": .sound, "sounds": .sound, "noise": .sound, "noises": .sound, "hear": .sound,
        "heard": .sound, "music": .sound,
        "smell": .smell, "smelled": .smell, "smelt": .smell, "scent": .smell, "scents": .smell,
        "taste": .taste, "tasted": .taste, "flavor": .taste, "flavour": .taste,
        "touch": .touch, "touched": .touch, "texture": .touch,
        "weather": .weather, "rain": .weather, "raining": .weather, "snow": .weather,
        "temperature": .weather, "hot": .weather, "cold": .weather, "warm": .weather,
        "wearing": .clothing, "wore": .clothing, "wear": .clothing, "dressed": .clothing, "clothes": .clothing,
    ]

    static func channel(of word: String) -> SensoryChannel? { words[word] }

    /// The channels a transcript mentions, for `LintContext.mentionedChannels`.
    static func mentioned(in transcript: String) -> Set<SensoryChannel> {
        var found = Set<SensoryChannel>()
        for word in LintText.words(transcript) {
            if let channel = channel(of: word.core.lowercased()) { found.insert(channel) }
        }
        return found
    }
}

/// The facts a caller may legitimately rely on. The authored-deck tests use the empty context.
struct LintContext: Sendable {
    var allowedNames: Set<String> = []
    var allowedDefinites: Set<String> = []
    var mentionedChannels: Set<SensoryChannel> = []
}

/// An audited exception: one template, one rule, a written reason. Pinned by a test.
struct LintExemption: Equatable, Sendable {
    let templateID: String
    let rule: LintRule
    let reason: String
}

enum LintText {
    static let slotMask = "\u{25CA}"

    struct Word {
        let raw: String
        let core: String
        let startsSentence: Bool
    }

    static func normalise(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
    }

    /// The word with leading and trailing non-alphanumerics removed (inner apostrophes kept).
    static func core(_ raw: String) -> String {
        let scalars = Array(raw.unicodeScalars)
        var low = 0
        var high = scalars.count
        while low < high, !CharacterSet.alphanumerics.contains(scalars[low]) { low += 1 }
        while high > low, !CharacterSet.alphanumerics.contains(scalars[high - 1]) { high -= 1 }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[low..<high])
        return String(view)
    }

    static func words(_ text: String) -> [Word] {
        var out: [Word] = []
        var previousEndsSentence = true
        for piece in normalise(text).split(whereSeparator: { $0.isWhitespace }) {
            let raw = String(piece)
            out.append(Word(raw: raw, core: core(raw), startsSentence: previousEndsSentence))
            previousEndsSentence = raw.hasSuffix(".") || raw.hasSuffix("?") || raw.hasSuffix("!")
        }
        return out
    }
}

enum QuestionLint {
    static let exemptions: [LintExemption] = [
        LintExemption(
            templateID: "when.open", rule: .alternative,
            reason: "\"a year, or how old you were\" offers two units for a date, not two contents for the memory."),
    ]

    private static let spelledNumbers: Set<String> = [
        "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
        "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
        "hundred", "thousand",
    ]
    private static let emotionWords: Set<String> = [
        "sad", "sadly", "sadder", "saddest", "sadness", "happy", "happier", "happiest", "happily",
        "happiness", "angry", "angrier", "angriest", "angrily", "anger", "mad", "afraid", "fear",
        "fearful", "scared", "scary", "annoyed", "annoying", "upset", "hurt", "proud", "pride",
        "guilty", "guilt", "ashamed", "shame", "lonely", "jealous", "furious", "joy", "joyful",
        "miserable", "sorrow", "grief", "bored", "calm", "safe",
    ]
    private static let emotionStems = [
        "anxi", "nervous", "worr", "embarrass", "excit", "terrif", "frighten", "annoy", "resent",
        "stress", "overwhelm", "depress", "grie",
    ]
    private static let ordinalWords: Set<String> = [
        "next", "first", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "last", "most", "always", "never", "usually", "often", "every", "again", "finally",
        "continue", "continued", "continues", "continuing", "still",
    ]
    private static let intensifierWords: Set<String> = [
        "vividly", "clearly", "distinctly", "especially", "particularly", "really", "definitely",
        "obviously", "surely",
    ]
    private static let tagEndings = [
        ", right?", "isn't it", "wasn't it", "didn't it", "didn't you", "weren't you", "wasn't there",
    ]
    private static let channelNouns: Set<String> = [
        "light", "sounds", "sound", "noise", "noises", "smell", "smells", "scent", "taste", "weather",
        "temperature", "colors", "colours", "music", "clothes",
    ]

    /// Lints a pattern that may contain `{slot}` markers. Slot content is not linted here.
    static func literalViolations(in pattern: String, context: LintContext = LintContext()) -> [LintViolation] {
        let masked = pattern.replacingOccurrences(of: QuestionTemplate.slotMarker, with: LintText.slotMask)
        let words = LintText.words(masked)
        let lowered = words.map { $0.core.lowercased() }
        var found: [LintViolation] = []
        func add(_ rule: LintRule, _ evidence: String) { found.append(LintViolation(rule: rule, evidence: evidence)) }

        let channels = Set(lowered.compactMap { SensoryChannel.channel(of: $0) })
        let reportEverything = channels.count >= 2

        for (index, word) in words.enumerated() where !word.core.isEmpty {
            let lower = lowered[index]
            if let first = word.core.first, first.isUppercase, !word.startsSentence,
               word.core != "I", !word.core.hasPrefix("I'"), !context.allowedNames.contains(lower) {
                add(.properNoun, word.core)
            }
            if word.core.contains(where: { $0.isNumber }) || spelledNumbers.contains(lower) {
                add(.numeral, word.core)
            }
            if emotionWords.contains(lower) || emotionStems.contains(where: { lower.hasPrefix($0) }) {
                add(.emotion, word.core)
            }
            if ordinalWords.contains(lower) { add(.ordinal, word.core) }
            if intensifierWords.contains(lower) { add(.intensifier, word.core) }
            if lower == "or" { add(.alternative, word.core) }
            if lower == "the", index + 1 < words.count {
                let next = lowered[index + 1]
                let allowed = next.isEmpty
                    || context.allowedDefinites.contains(next)
                    || (reportEverything && channelNouns.contains(next))
                if !allowed { add(.bareDefinite, "the \(next)") }
            }
        }

        let joined = " " + lowered.filter { !$0.isEmpty }.joined(separator: " ") + " "
        if joined.contains(" stand out ") || joined.contains(" stands out ") { add(.intensifier, "stand out") }
        let flat = LintText.normalise(masked).lowercased()
        for tag in tagEndings where flat.contains(tag) { add(.alternative, tag) }

        // One channel named, in any question form (yes/no is the most leading): it must be one the
        // transcript mentioned. Two or more is the report-everything form and is allowed.
        if channels.count == 1, let channel = channels.first, !context.mentionedChannels.contains(channel) {
            add(.unmentionedChannel, channel.rawValue)
        }
        return found
    }

    /// Template-level lint: the literal text, minus audited exemptions.
    static func violations(in template: QuestionTemplate, context: LintContext = LintContext()) -> [LintViolation] {
        literalViolations(in: template.pattern, context: context).filter { violation in
            !exemptions.contains { $0.templateID == template.id && $0.rule == violation.rule }
        }
    }

    static func slotViolations(_ slots: [VerifiedSpan]) -> [LintViolation] {
        slots.filter { SlotGuard.isDegenerate($0.text) }.map { LintViolation(rule: .degenerateSlot, evidence: $0.text) }
    }

    /// Belt and braces on slot-filled output: the template's literal text plus the slot guard.
    static func violations(
        in question: AssembledQuestion, template: QuestionTemplate, context: LintContext = LintContext()
    ) -> [LintViolation] {
        violations(in: template, context: context) + slotViolations(question.slots)
    }
}
