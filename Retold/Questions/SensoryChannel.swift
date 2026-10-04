import Foundation

/// A sensory channel the user's own words can mention (PLAN section 7).
enum SensoryChannel: String, CaseIterable, Sendable {
    case sound, smell, taste, sight, clothing, weather
}

extension SensoryChannel {
    /// Words whose presence in the user's transcript marks the channel as mentioned.
    /// Deliberately narrower than the lint's trigger list: "you see", "I heard he left",
    /// "kids playing" and "I caught a cold" are not the user describing a sense, so
    /// `see`/`saw`/`heard`/`look`/`looked`/`looking`/`playing`/`cold`/`hot` are not here.
    private static let mentionWords: [SensoryChannel: Set<String>] = [
        .sound: ["sound", "sounds", "sounded", "hear", "hearing", "noise", "noises",
                 "noisy", "loud", "music", "song", "songs", "singing", "voice", "voices"],
        .smell: ["smell", "smells", "smelled", "smelt", "smelling", "scent"],
        .taste: ["taste", "tastes", "tasted", "tasting", "flavour", "flavor"],
        .sight: ["seeing", "light", "colour", "color", "colours", "colors"],
        .clothing: ["wear", "wearing", "wore", "clothes", "dress", "dressed"],
        .weather: ["weather", "temperature", "warm", "rain", "raining", "snow",
                   "snowing", "sunny", "wind", "windy"],
    ]

    /// Channels the user's own words mention. Keys by SpanVerifier.key; a word counts once.
    static func mentioned(in texts: [String]) -> Set<SensoryChannel> {
        var mentioned: Set<SensoryChannel> = []
        for text in texts {
            for piece in text.split(whereSeparator: \.isWhitespace) {
                let key = SpanVerifier.key(String(piece))
                guard !key.isEmpty else { continue }
                for (channel, words) in mentionWords where words.contains(key) {
                    mentioned.insert(channel)
                }
            }
        }
        return mentioned
    }
}
