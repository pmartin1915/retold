import Foundation

/// Wellness copy lint (PLAN section 5.2, Rule 2: the app prompts; it does not assess). Any disease,
/// condition or measurement term takes the app out of the FDA general-wellness safe harbour.
enum CopyLint {
    private static let exactTerms: Set<String> = [
        "score", "scores", "scored", "scoring", "mci", "dementia", "screening", "cure", "cures", "cured",
        "curing", "ptsd", "adhd", "depression", "anxiety", "trauma", "therapy", "cognitive",
    ]
    private static let stems = [
        "cognitiv", "declin", "assess", "diagnos", "treat", "prevent", "sharpen", "alzheimer",
        "depress", "anxiet", "traum", "therap",
    ]
    private static let phrases = [" memory test ", " brain training "]
    private static let improveForms: Set<String> = ["improve", "improves", "improved", "improving"]
    private static let determiners: Set<String> = ["your", "the", "my", "their"]

    /// Every forbidden term found in `text`, in order of appearance. Empty means clean.
    static func violations(in text: String) -> [String] {
        let tokens = LintText.normalise(text).lowercased()
            .split(whereSeparator: { !$0.isLetter }).map(String.init)
        var found: [String] = []
        for (index, token) in tokens.enumerated() {
            if exactTerms.contains(token) || stems.contains(where: { token.hasPrefix($0) }) {
                found.append(token)
            }
            if improveForms.contains(token) {
                let next = index + 1 < tokens.count ? tokens[index + 1] : ""
                let afterNext = index + 2 < tokens.count ? tokens[index + 2] : ""
                if next == "memory" || (determiners.contains(next) && afterNext == "memory") {
                    found.append("\(token) memory")
                }
            }
        }
        let joined = " " + tokens.joined(separator: " ") + " "
        for phrase in phrases where joined.contains(phrase) {
            found.append(phrase.trimmingCharacters(in: .whitespaces))
        }
        return found
    }
}
