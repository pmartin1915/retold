import Foundation

/// PLAN section 7 / R2 known gap: a one-word span such as "I" is verbatim, so it verifies, but it
/// cannot carry a question ("Who was I to you, back then?"). A span is degenerate when every one of
/// its words is a pronoun or function word, or it is a single letter.
enum SlotGuard {
    private static let stopwords: Set<String> = [
        "i", "i'm", "i'd", "i'll", "i've", "me", "my", "mine", "myself", "you", "your", "yours",
        "he", "him", "his", "she", "her", "hers", "it", "its", "we", "us", "our", "they", "them", "their",
        "a", "an", "the", "and", "but", "or", "so", "of", "to", "in", "on", "at", "by", "for", "with",
        "is", "was", "were", "be", "been", "am", "are", "that", "this", "there", "here", "what", "who",
    ]

    static func isDegenerate(_ text: String) -> Bool {
        let cores = LintText.words(text).map { $0.core.lowercased() }.filter { !$0.isEmpty }
        if cores.isEmpty { return true }
        if cores.allSatisfy({ stopwords.contains($0) }) { return true }
        return cores.count == 1 && cores[0].count < 2
    }
}
