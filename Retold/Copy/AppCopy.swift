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

    /// R7b: title shown for an episode whose title is not confirmed.
    static let untitled = "Untitled"
    /// R7b: title of the Places list.
    static let placesTitle = "Places"
    /// R7b: title of the Themes page.
    static let themesTitle = "Themes"
    /// R7b: title of the Periods page.
    static let periodsTitle = "Periods"
    /// R7b: action for adding a period.
    static let addPeriod = "Add a period"
    /// R7b: action for renaming a period.
    static let renamePeriod = "Rename"
    /// R7b: footnote shown when a period title is a duplicate.
    static let duplicatePeriod = "There is already a period with that name."
    /// R7b: save action in the period sheet.
    static let saveButton = "Save"
    /// R7b: cancel action in the period sheet.
    static let cancelButton = "Cancel"
    /// R7b: heading for the open questions on a page.
    static let questionsHeader = "Questions"
    /// R7b: action for answering a question by recording.
    static let answerNow = "Answer now"
    /// R7b: heading for an episode's recordings.
    static let recordingsHeader = "Recordings"
    /// R7b: state shown when a recording has no transcript.
    static let noTranscript = "No transcript"
    /// R7b: state shown when a recording's audio file is gone.
    static let audioMissing = "The recording file is missing."
    /// R7b: play action.
    static let playButton = "Play"
    /// R7b: pause action.
    static let pauseButton = "Pause"
    /// R7b: recorder label while a capture answers a question.
    static let answeringLabel = "Answering"
    /// R7b: settings action that builds the export.
    static let exportButton = "Export everything"
    /// R7b: fixed line shown beside the export action.
    static let exportNote = "Recordings may name other people."
    /// R7b: progress copy while the export is built.
    static let preparingExport = "Preparing the export…"
    /// R7b: footnote shown when the export fails.
    static let exportFailed = "The export could not be made. Try again."
    /// R7b: label of the share link for a finished export.
    static let shareExport = "Share the export"
    /// R7c: swipe action that deletes an unfiled recording.
    static let deleteAction = "Delete"
    /// R7c: title of the delete confirmation.
    static let deleteRecordingTitle = "Delete this recording?"
    /// R7c: message of the delete confirmation.
    static let deleteRecordingMessage = "The recording and its transcript will be removed from this phone. This can't be undone."
    /// R7c: label of the confirming delete button.
    static let deleteRecordingConfirm = "Delete recording"
    /// R7c: alert shown when a delete fails.
    static let deleteFailed = "The recording couldn't be deleted. Try again."

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
        untitled,
        placesTitle,
        themesTitle,
        periodsTitle,
        addPeriod,
        renamePeriod,
        duplicatePeriod,
        saveButton,
        cancelButton,
        questionsHeader,
        answerNow,
        recordingsHeader,
        noTranscript,
        audioMissing,
        playButton,
        pauseButton,
        answeringLabel,
        exportButton,
        exportNote,
        preparingExport,
        exportFailed,
        shareExport,
        deleteAction,
        deleteRecordingTitle,
        deleteRecordingMessage,
        deleteRecordingConfirm,
        deleteFailed,
    ]
}
