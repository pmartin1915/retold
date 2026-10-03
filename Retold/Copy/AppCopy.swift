import Foundation

/// The user-facing strings PLAN already fixes, verbatim, so WellnessLint has real copy to
/// check before any string catalog exists. Not wired to any view in R3.
enum AppCopy {
    /// PLAN section 8: why suggestions are unavailable on a phone without Apple Intelligence.
    static let newerPhoneReason = "Suggestions need a newer iPhone; everything else works"
    /// PLAN section 8: why suggestions are unavailable while Apple Intelligence is off.
    static let appleIntelligenceOffReason = "Turn on Apple Intelligence in Settings to get suggested questions"
    /// PLAN section 8: why suggestions are unavailable while models are downloading.
    static let modelsDownloadingReason = "Suggestions will appear once your phone finishes downloading them"

    /// PLAN section 7: the line that reinstates an interrupted open question.
    static let reinstatement = "Take a second. Where were you, what time of year, who was around \u{2014} then talk."
    /// PLAN section 5.2: the nudge notification body.
    static let nudgeWaiting = "One question waiting"
    /// PLAN section 9: the fallback explanation for unsupported phones.
    static let fallback = "Suggested questions use Apple Intelligence on supported iPhones; recording, filing and browsing work on every iPhone running iOS 26."

    static let all: [String] = [
        newerPhoneReason,
        appleIntelligenceOffReason,
        modelsDownloadingReason,
        reinstatement,
        nudgeWaiting,
        fallback,
    ]
}
