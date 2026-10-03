import Foundation

/// The wellness-copy lint (PLAN section 5.2, plus memory loss per report D section 6 and
/// brain per PLAN section 9). User-facing copy may never frame the app as testing, scoring,
/// diagnosing or treating memory; every term below is matched case-insensitively.
struct WellnessViolation: Equatable, Sendable {
    let term: String
    let match: String
}

enum WellnessLint {
    /// (label, regex) pairs, each anchored with `\b` at the start. Deliberate near-miss
    /// behavior: `screen` does not match `screenshot`, `cure` does not match `secure` or
    /// `curious`, `score` does not match `underscore`.
    private static let entries: [(term: String, pattern: String)] = [
        ("memory test", #"\bmemory tests?\b"#),
        ("memory loss", #"\bmemory loss\b"#),
        ("score", #"\bscor(e|es|ed|ing)\b"#),
        ("improve memory", #"\bimprov(e|es|ed|ing) (your |my )?memor(y|ies)\b"#),
        ("cognitive", #"\bcognitive\b"#),
        ("decline", #"\bdeclin(e|es|ed|ing)\b"#),
        ("assess", #"\bassess\w*"#),
        ("screen", #"\bscreen(s|ed|ing)?\b"#),
        ("MCI", #"\bmci\b"#),
        ("dementia", #"\bdementia\b"#),
        ("Alzheimer", #"\balzheimer\w*"#),
        ("diagnose", #"\bdiagnos\w*"#),
        ("treat", #"\btreat\w*"#),
        ("cure", #"\bcur(e|es|ed|ing)\b"#),
        ("prevent", #"\bprevent\w*"#),
        ("brain", #"\bbrain\w*"#),
        ("sharpen", #"\bsharpen\w*"#),
        ("PTSD", #"\bptsd\b"#),
        ("depression", #"\bdepress\w*"#),
        ("ADHD", #"\badhd\b"#),
        ("anxiety", #"\banxi(ety|eties|ous)\b"#),
        ("trauma", #"\btrauma\w*"#),
        ("therapy", #"\btherap\w*"#),
    ]

    static func violations(in text: String) -> [WellnessViolation] {
        var out: [WellnessViolation] = []
        let range = NSRange(text.startIndex..., in: text)
        for entry in entries {
            guard let regex = try? NSRegularExpression(pattern: entry.pattern, options: [.caseInsensitive])
            else { continue }
            for match in regex.matches(in: text, options: [], range: range) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                out.append(WellnessViolation(term: entry.term, match: String(text[matchRange])))
            }
        }
        return out
    }
}
