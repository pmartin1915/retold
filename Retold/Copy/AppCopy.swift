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
    /// R6b spec 7a: the recorder banner after 20 minutes of recording.
    static let lengthWarning = "Retold stops this recording at 30 minutes."

    /// R7a: heading for captures that have not been filed.
    static let unfiledHeader = "Unfiled"
    /// R7a: heading for filed episodes.
    static let filedHeader = "Filed"
    /// R7a: state shown while a capture is being transcribed.
    static let transcribingLabel = "Transcribing…"
    /// R7a: state shown when a capture has no transcript.
    static let noTranscriptLabel = "No transcript — you can still file it"
    /// R7a: confirm-flow filing action.
    static let fileButton = "File it"
    /// R7a: label for an unaccepted suggestion.
    static let suggestedLabel = "suggested"
    /// R7a: accepts a suggested value.
    static let acceptButton = "Use this"
    /// R7a: rejects a suggested value.
    static let rejectButton = "Not this"
    /// R7a: confirm-flow title section.
    static let titleHeader = "Title"
    /// R7a: prompt for a user-authored title.
    static let titlePlaceholder = "Type a title"
    /// R7a: confirm-flow period section.
    static let periodHeader = "Period"
    /// R7a: period picker option for no period.
    static let noPeriod = "Not in a period"
    /// R7a: period picker option for a new period.
    static let newPeriod = "New period…"
    /// R7a: prompt for a new period title.
    static let newPeriodPlaceholder = "Name the period"
    /// R7a: confirm-flow when section.
    static let whenHeader = "When"
    /// R7a: year mode for the when answer.
    static let whenYear = "Year"
    /// R7a: age mode for the when answer.
    static let whenAge = "Age"
    /// R7a: action for leaving the when answer open.
    static let notSure = "Not sure"
    /// R7a: confirm-flow people section.
    static let peopleHeader = "People"
    /// R7a: confirm-flow place section.
    static let placesHeader = "Place"
    /// R7a: action for adding a person.
    static let addPerson = "Add a person"
    /// R7a: action for adding a place.
    static let addPlace = "Add a place"
    /// R7a: prefix for reusing an existing entity.
    static let sameAs = "Same as"
    /// R7a: option for creating a person.
    static let newPerson = "New person"
    /// R7a: option for creating a place.
    static let newPlace = "New place"
    /// R7a: confirm-flow follow-up section.
    static let followUpsHeader = "Questions for later"
    /// R7a: keeps a follow-up question open.
    static let later = "Later"
    /// R7a: retires a follow-up question.
    static let notThisOne = "Not this one"
    /// R7a: progress copy while suggestions are generated.
    static let findingSuggestions = "Looking for names and places…"
    /// R7a: action for cancelling suggestion generation.
    static let skipSuggestions = "Skip suggestions"
    /// R7a: settings screen title.
    static let settingsTitle = "Settings"
    /// R7a: setting that enables filing suggestions.
    static let suggestionsToggle = "Suggestions"
    /// R7a: explanation of where suggestions are generated.
    static let suggestionsFootnote = "Suggestions are made on this iPhone."

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
        lengthWarning,
        unfiledHeader,
        filedHeader,
        transcribingLabel,
        noTranscriptLabel,
        fileButton,
        suggestedLabel,
        acceptButton,
        rejectButton,
        titleHeader,
        titlePlaceholder,
        periodHeader,
        noPeriod,
        newPeriod,
        newPeriodPlaceholder,
        whenHeader,
        whenYear,
        whenAge,
        notSure,
        peopleHeader,
        placesHeader,
        addPerson,
        addPlace,
        sameAs,
        newPerson,
        newPlace,
        followUpsHeader,
        later,
        notThisOne,
        findingSuggestions,
        skipSuggestions,
        settingsTitle,
        suggestionsToggle,
        suggestionsFootnote,
    ]
}
