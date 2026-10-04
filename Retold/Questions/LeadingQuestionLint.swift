import Foundation

/// The ten leading-question rules of PLAN section 7. The lint runs on a template pattern
/// with its `{slot}` markers in place: a slot is a verified span or a confirmed entity, so it
/// is never itself checked — a slot token matches no list and is never a proper noun, and a
/// verified span may legitimately be "the summer of '98".
enum LeadingRule: String, CaseIterable, Sendable {
    case properNoun, numeral, emotionWord, presupposingSequence, bareDefinite,
         intensifier, alternativeQuestion, tagQuestion, closedQuestion, unmentionedChannel
}

struct LeadingViolation: Equatable, Sendable {
    let rule: LeadingRule
    let match: String
}

enum LeadingQuestionLint {
    private struct Token {
        let surface: String
        let key: String
    }

    private static let slotKey = QuestionTemplate.slotMarker

    // Fixed word lists (PLAN section 7); not configurable.
    private static let wh: Set<String> = ["what", "which", "how", "where", "who", "whom", "whose", "when", "why"]
    private static let aux: Set<String> = ["is", "are", "was", "were", "did", "do", "does", "have", "has", "had", "can", "could", "would", "will"]
    private static let openWords: Set<String> = ["anything", "anyone", "anywhere", "anybody"]
    private static let pronounI: Set<String> = ["i", "i'm", "i've", "i'd"]
    private static let emotionWords: Set<String> = ["afraid", "scared", "frightened", "happy", "happier", "sad", "sadder", "angry", "mad", "annoyed", "upset", "proud", "ashamed", "embarrassed", "excited", "nervous", "worried", "lonely", "hurt", "jealous", "guilty", "grateful", "disappointed", "relieved", "furious", "bitter", "heartbroken", "miserable", "joy", "joyful", "fear", "grief", "shame", "regret", "feel", "felt", "feeling", "feelings"]
    private static let sequencePhrases = ["the next", "the first time", "the last time", "most days", "every time", "before that", "after that"]
    private static let sequenceWords: Set<String> = ["always", "again", "finally", "continue", "continued", "still", "end", "ended", "ending", "afterwards"]
    private static let intensifierPhrases = ["stands out", "stand out"]
    private static let intensifierWords: Set<String> = ["most", "vivid", "clearest", "best", "worst", "favorite", "favourite"]
    /// Trigger word -> its channel: R3's 28 words plus seven inflections R3 missed
    /// (hearing, smells, smelling, tastes, tasting, seeing, looking).
    private static let channelWords: [String: SensoryChannel] = [
        "sound": .sound, "sounded": .sound, "sounds": .sound, "hear": .sound, "heard": .sound,
        "hearing": .sound, "music": .sound, "playing": .sound, "song": .sound,
        "smell": .smell, "smelled": .smell, "smelt": .smell, "smells": .smell, "smelling": .smell,
        "taste": .taste, "tasted": .taste, "tastes": .taste, "tasting": .taste,
        "see": .sight, "saw": .sight, "seeing": .sight, "look": .sight, "looked": .sight,
        "looking": .sight, "colour": .sight, "color": .sight, "light": .sight,
        "wear": .clothing, "wearing": .clothing, "wore": .clothing,
        "weather": .weather, "temperature": .weather, "cold": .weather, "warm": .weather, "hot": .weather,
    ]
    /// Channel nouns whose `the` is allowed inside a report-everything sentence.
    private static let channelNouns: Set<String> = ["light", "sounds", "sound", "weather", "smell", "smells", "air", "colours", "colors", "voices", "place", "wearing", "temperature", "music"]
    private static let tagPattern = ",\\s*(is|are|was|were|did|do|does|have|has|had|can|could|would|will)(n't|nt)?\\s+(it|you|he|she|they|we|there|that)\\s*$"

    /// Every violation in `pattern`, in pattern order. Sentences split on `.?!`, clauses on the
    /// em dash; `bareDefinite` and the report-everything test work per sentence, the other
    /// rules per clause.
    static func violations(in pattern: String) -> [LeadingViolation] {
        violations(in: pattern, mentionedChannels: [])
    }

    /// As `violations(in:)`, but transcript-aware: `unmentionedChannel` fires only for a
    /// channel the episode's transcript does not mention (PLAN section 7: a wh-question on
    /// a channel is allowed only when the channel appears in the transcript). With an empty
    /// set this is the rule's R3 form plus the seven new inflections.
    static func violations(in pattern: String, mentionedChannels: Set<SensoryChannel>) -> [LeadingViolation] {
        var out: [LeadingViolation] = []
        for rawSentence in pattern.components(separatedBy: CharacterSet(charactersIn: ".?!")) {
            let sentence = rawSentence.trimmingCharacters(in: .whitespaces)
            guard !sentence.isEmpty else { continue }
            let sentenceTokens = tokens(of: sentence)
            appendBareDefiniteViolations(sentenceTokens, to: &out)
            for rawClause in sentence.components(separatedBy: "\u{2014}") {
                let clause = rawClause.trimmingCharacters(in: .whitespaces)
                guard !clause.isEmpty else { continue }
                appendClauseViolations(clause, mentionedChannels: mentionedChannels, to: &out)
            }
        }
        return out
    }

    /// A token whose raw text contains `{slot}` is a slot token, detected before keying
    /// because `SpanVerifier.key` strips braces as edge punctuation. Every other token's key
    /// is `SpanVerifier.key(_:)`; empty keys are dropped.
    private static func tokens(of text: String) -> [Token] {
        text.split(whereSeparator: \.isWhitespace).compactMap { piece in
            let raw = String(piece)
            if raw.contains(slotKey) { return Token(surface: raw, key: slotKey) }
            let key = SpanVerifier.key(raw)
            return key.isEmpty ? nil : Token(surface: raw, key: key)
        }
    }

    /// A report-everything sentence (PLAN section 7 item 3) opens on `anything` and names at
    /// least two distinct channel nouns. Only inside one is `the` before a channel noun
    /// allowed; a single-channel invitation gets no exemption, and neither does any `wh` opener.
    private static func isReportEverything(_ keys: [String]) -> Bool {
        guard keys.first == "anything" else { return false }
        return Set(keys.filter { channelNouns.contains($0) }).count >= 2
    }

    private static func appendBareDefiniteViolations(_ sentenceTokens: [Token], to out: inout [LeadingViolation]) {
        let keys = sentenceTokens.map(\.key)
        let exempt = isReportEverything(keys)
        for index in keys.indices where keys[index] == "the" {
            // "the {slot}" always fails: the deck may not add a definite to a spoken phrase.
            guard index + 1 < keys.count,
                  !(exempt && channelNouns.contains(keys[index + 1]))
            else { continue }
            out.append(LeadingViolation(
                rule: .bareDefinite,
                match: sentenceTokens[index].surface + " " + sentenceTokens[index + 1].surface))
        }
    }

    private static func appendClauseViolations(
        _ clause: String,
        mentionedChannels: Set<SensoryChannel>,
        to out: inout [LeadingViolation]
    ) {
        let clauseTokens = tokens(of: clause)
        guard let opener = clauseTokens.first?.key else { return }
        let keys = clauseTokens.map(\.key)

        // Any capitalised token except the clause opener, the pronoun I, and slots.
        for token in clauseTokens.dropFirst()
        where token.key != slotKey && !pronounI.contains(token.key) && token.surface.first?.isUppercase == true {
            out.append(LeadingViolation(rule: .properNoun, match: token.surface))
        }

        for token in clauseTokens
        where token.key != slotKey && token.surface.contains(where: { $0.isASCII && $0.isNumber }) {
            out.append(LeadingViolation(rule: .numeral, match: token.surface))
        }

        for token in clauseTokens where token.key != slotKey && emotionWords.contains(token.key) {
            out.append(LeadingViolation(rule: .emotionWord, match: token.surface))
        }

        for match in listMatches(in: clauseTokens, phrases: sequencePhrases, words: sequenceWords) {
            out.append(LeadingViolation(rule: .presupposingSequence, match: match))
        }

        for match in listMatches(in: clauseTokens, phrases: intensifierPhrases, words: intensifierWords) {
            out.append(LeadingViolation(rule: .intensifier, match: match))
        }

        if aux.contains(opener) && keys.contains("or") {
            out.append(LeadingViolation(rule: .alternativeQuestion, match: clause))
        }

        if let regex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]) {
            let range = NSRange(clause.startIndex..., in: clause)
            if let match = regex.firstMatch(in: clause, options: [], range: range),
               let matchRange = Range(match.range, in: clause) {
                out.append(LeadingViolation(rule: .tagQuestion, match: String(clause[matchRange])))
            }
        }

        if aux.contains(opener) && !containsOpenWord(keys) {
            out.append(LeadingViolation(rule: .closedQuestion, match: clause))
        }

        if wh.contains(opener) {
            // The first trigger whose channel the transcript does NOT mention: "What did
            // you hear and smell?" with [.sound] fails on `smell`, not `hear`.
            let hit = clauseTokens.first { token in
                guard token.key != slotKey, let channel = channelWords[token.key] else { return false }
                return !mentionedChannels.contains(channel)
            }
            if let hit {
                out.append(LeadingViolation(rule: .unmentionedChannel, match: hit.surface))
            }
        }
    }

    private static func containsOpenWord(_ keys: [String]) -> Bool {
        if keys.contains(where: { openWords.contains($0) }) { return true }
        for index in keys.indices.dropLast() where keys[index] == "something" && keys[index + 1] == "else" {
            return true
        }
        return false
    }

    /// Keys in `words`, or consecutive-key runs matching a `phrases` entry (longest first),
    /// returned as their raw surfaces joined by single spaces.
    private static func listMatches(in tokens: [Token], phrases: [String], words: Set<String>) -> [String] {
        let keys = tokens.map(\.key)
        let orderedPhrases = phrases.sorted {
            $0.components(separatedBy: " ").count > $1.components(separatedBy: " ").count
        }
        var matches: [String] = []
        var index = keys.startIndex
        while index < keys.endIndex {
            defer { index += 1 }
            guard keys[index] != slotKey else { continue }
            var consumed = false
            for phrase in orderedPhrases {
                let parts = phrase.components(separatedBy: " ")
                guard index + parts.count <= keys.endIndex else { continue }
                var ok = true
                for offset in 0..<parts.count where keys[index + offset] != parts[offset] {
                    ok = false
                    break
                }
                if ok {
                    matches.append(tokens[index..<(index + parts.count)].map(\.surface).joined(separator: " "))
                    index += parts.count - 1
                    consumed = true
                    break
                }
            }
            if consumed { continue }
            if words.contains(keys[index]) {
                matches.append(tokens[index].surface)
            }
        }
        return matches
    }
}
