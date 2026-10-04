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

    /// R6b: first-run microphone prompt.
    static let micPrompt = "Retold records your voice while you talk through a memory."
    /// R6b: first-run grant button.
    static let micAllow = "Allow microphone"
    /// R6b: shown when the microphone grant is denied.
    static let micDenied = "Microphone access is off. Turn it on in Settings to record."
    /// R6b: home screen record button.
    static let recordButton = "Record a memory"
    /// R6b: recorder stop button.
    static let stopButton = "Stop"
    /// R6b: recorder resume button while interrupted.
    static let resumeButton = "Resume"
    /// R6b: recorder state label while recording.
    static let recordingLabel = "Recording"
    /// R6b: recorder state label while interrupted.
    static let pausedLabel = "Paused"
    /// R6b: the store failed to open at launch.
    static let startupFailed = "Retold could not open its storage. Restart the app to try again."
    /// R6b: home screen title (the week-0 scaffold's, moved here so views carry no literals).
    static let homeTitle = "Retold"
    /// R6b: home screen placeholder (the week-0 scaffold's, moved here so views carry no literals).
    static let homePlaceholder = "Week 0 scaffold -- recorder lands in week 1 (docs/PLAN.md section 12)"
    /// R6b spec 7a: the recorder banner after 20 minutes of recording.
    static let lengthWarning = "Retold stops this recording at 30 minutes."

    static let all: [String] = [
        newerPhoneReason,
        appleIntelligenceOffReason,
        modelsDownloadingReason,
        reinstatement,
        nudgeWaiting,
        fallback,
        micPrompt,
        micAllow,
        micDenied,
        recordButton,
        stopButton,
        resumeButton,
        recordingLabel,
        pausedLabel,
        startupFailed,
        homeTitle,
        homePlaceholder,
        lengthWarning,
    ]
}
