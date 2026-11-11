| Dimension | Score | Assessment |
|---|---:|---|
| 1. Motion and fluidity | 2/4 | Good interaction feedback; unstable row identity and abrupt loading replacement remain. |
| 2. State clarity | 3/4 | Clear recorder phases and errors; accepted suggestions lack a clear persistent state. |
| 3. Input and recording robustness | 2/4 | Permission and interruption UI exists. Recovery after kill and low-storage behavior are not in packet. |
| 4. Accessibility | 2/4 | Useful labels and playback adaptation; confirmation controls need an accessibility layout. |
| 5. Visual system | 2/4 | Consistent terracotta and native chrome; hierarchy still feels like an undifferentiated form. |
| 6. Performance | 1/4 | Growing live-text work runs on the main actor. M7 confirms fluidity remains unmeasured. |
| 7. Copy | 3/4 | Mostly plain and specific; recording failure exposes technical detail. |
| 8. Layout resilience | 2/4 | Native scrolling helps; dense story metadata and rigid action rows remain. |
| 9. Android parity | N/A | iOS only. |

Scores reflect this packet, not device verification. Screenshots establish appearance, not animation quality or transcription latency. No blocker is demonstrated. HOUSE-STYLE contrast numbers, AX5 behavior, dark mode, and foldable-hazard checks cannot be verified from these screenshots and excerpts.

FINDING 1
- dimension: 6
- severity: should
- target: Retold/Capture/CaptureCoordinator.swift:241 quote: "let joined = journaledFinalTexts.joined(separator: \" \")"
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:110 quote: "const followUpQuestions = useMemo(() => {"
- evidence: The coordinator is "@MainActor @Observable" at line 19. Every volatile result calls "rebuildLiveText()" at line 139, which rejoins all finalized text and constructs the complete display string. RecorderView:66 renders that complete string. Work therefore grows with recording length; this is a plausible contributor to reported lag, not proof of its cause.
- fix: Apply the veteran's derived-work caching pattern: maintain a finalized display prefix incrementally, then coalesce volatile display updates at a bounded cadence. Isolate transcript observation in a child view. Preserve every final event and its exact words; do not throttle persistence or modify the audio engine.

FINDING 2
- dimension: 1
- severity: should
- target: Retold/Screens/HomeView.swift:65 quote: "ForEach(Array(sections.enumerated()), id: \.offset) { _, section in"
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:124 quote: "challengeAttemptIdRef.current !== attempt.attemptId"
- evidence: Home identifies sections by position, while the veteran explicitly associates retained state with a domain identity. Inserting or removing a timeline section changes the positional identity of subsequent sections, undermining continuity during filing and list updates. 01-home shows the affected multi-section timeline; a still image cannot demonstrate the resulting motion.
- fix: Give TimelineSection a stable identity based on its period ID, with a stable sentinel for the no-period section. Use that identity in ForEach so SwiftUI can track the same section through insertions and removals.

FINDING 3
- dimension: 2
- severity: should
- target: Retold/Screens/ConfirmView.swift:333 quote: "suggestionRow(text: chip.span.text, isSuggested: chip.state == .suggested, accept: accept, reject: reject)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:35 quote: "? \"border-brand-600 bg-brand-50 dark:bg-brand-950\""
- evidence: The suggestion renderer receives only whether the chip is suggested. It always renders both action buttons; accepting removes the "suggested" label but supplies no accepted styling or persistent accepted marker. In 03-confirm, the unaccepted "Use this" button already has a checkmark and accent fill, which can resemble an accepted state.
- fix: Pass the full suggestion state into the renderer. Show an explicit accepted label or selected treatment after acceptance, including an accessibility value or trait. Keep the initial action visually distinct from the resulting state and retain an obvious way to change the choice.

FINDING 4
- dimension: 8
- severity: should
- target: Retold/Screens/ConfirmView.swift:354 quote: "HStack(spacing: DesignTokens.Spacing.s) {"
- veteran counterpart: storycue/StoryCue/Views/RecorderView.swift:328 quote: "if dynamicTypeSize.isAccessibilitySize {"
- evidence: Both suggestion actions remain side by side at every text size, and the text plus "suggested" badge also uses a fixed HStack. In 03-confirm, these controls already consume substantial width at the supplied size. There is no adaptive branch in this renderer; clipping at AX5 is a risk, not a demonstrated screenshot failure.
- fix: Translate the sibling's explicit accessibility layout adaptation into a vertical action stack at accessibility sizes, or use ViewThatFits. Let the suggestion badge move below the text. Verify the resulting controls have at least 44x44 pt hit regions without capping text size.

FINDING 5
- dimension: 8
- severity: should
- target: Retold/Screens/EpisodeView.swift:20 quote: "factRows(facts)"
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:135 quote: "* into a single tab block to reduce feedback-screen density. Score, comparison,"
- evidence: In 04-story, the title appears in both navigation and content, followed by six full-height metadata/detail rows. The first playback control appears well down the screen despite recordings already preceding questions. The metadata card has greater visual weight than the recording.
- fix: Apply the veteran's progressive-disclosure pattern to secondary facts. Keep the full wrapping title and a compact period/when summary visible, then place people, place, and quoted detail behind one native DisclosureGroup. Keep the recording immediately after the summary.

FINDING 6
- dimension: 8
- severity: should
- target: Retold/Screens/PeopleView.swift:33 quote: "OfferSection(offers: offers, target: .person(person))"
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:136 quote: "* and region breakdown stay above the fold; pedagogy is opt-in."
- evidence: PersonView places every open question before the person's episodes. This reproduces the priority problem already corrected on the story page. 05-browse shows a clean story-first result when no offers are visible; the offers-present state is not in packet as a screenshot.
- fix: Put the person's episodes first and fold available questions into a counted DisclosureGroup below them. This preserves the existing questions while making browsing consistently lead with the user's stories.

FINDING 7
- dimension: 1
- severity: should
- target: Retold/Screens/ConfirmView.swift:51 quote: "} else if findingSuggestions {"
- veteran counterpart: BoardBound/components/ui/StaggeredEntrance.tsx:37 quote: "reduceMotion"
- evidence: ConfirmView replaces the form with a separate loading VStack until suggestions finish or are skipped. "draft = built" at line 541 has no explicit transition, so completion replaces a small centered loading view with the entire long form. Apple's supplied loading guidance says, "Let people do other things in your app or game while they wait for content to load." [Apple loading guidance](https://developer.apple.com/design/human-interface-guidelines/loading)
- fix: Render the transcript and editable filing fields immediately, with suggestion progress in a reserved inline area. Reconcile arriving suggestions without replacing typed input. Use a short opacity transition for the suggestion area, including under Reduce Motion; do not copy the veteran's stagger onto every form row.

FINDING 8
- dimension: 7
- severity: should
- target: Retold/Copy/AppCopy.swift:187 quote: "Nothing was recorded. Close Retold and try again. Details: "
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:83 quote: "{__DEV__ && this.state.error && ("
- evidence: HomeView:174 concatenates this message with coordinator.startFailure. CaptureCoordinator:134 can supply "unknown", and line 219 uses "String(describing: error)". Production recovery copy therefore exposes technical or unhelpful diagnostic text, while the veteran confines debug information to development.
- fix: Keep diagnostics in development output or diagnostic reporting. Give the production alert a short explanation and a recovery action appropriate to the known failure category. Avoid requiring an app restart for every start failure.

FINDING 9
- dimension: 5
- severity: polish
- target: Retold/Design/DesignTokens.swift:60 quote: ".animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3), value: configuration.isPressed)"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:16 quote: "static let morph = Animation.spring(duration: 0.3)"
- evidence: Retold defines motion inline here, in HomeView:147, and in ConfirmView:441. Its spacing set also lacks the sibling's xs and m tokens, while views repeat 4 and 12 literals. HOUSE-STYLE rules 5 and 8 require shared spacing and motion tokens. This is a maintenance and consistency gap, not evidence that the current spring duration is wrong.
- fix: Extract the sibling's shared SwiftUI spacing and motion vocabulary as planned, including semantic press, fade, and form-change animations where needed. Replace equivalent literals while preserving native List and sheet geometry; do not force custom card radii onto system chrome.

VETERAN OR SIBLING FEATURES WORTH BORROWING

1. Distinctive reading typography - storycue/StoryCue/Views/RecorderView.swift:246, ".fontDesign(DesignTokens.questionFontDesign)". Trial the sibling's serif treatment on the recorder's live words while keeping timers and controls in system sans-serif. Effort S.

2. Tokenized recording-status capsule - storycue/StoryCue/Views/RecorderView.swift:292, ".background(nearsCap ? DesignTokens.capWarningFill : DesignTokens.recordingFill, in: Capsule())". Retold could group its existing state, time, and cap warning into one coherent status treatment, using a layout that still supports AX5. Effort M.

3. Stable loading placeholders - BoardBound/components/ui/Skeleton.tsx:32, "className={`rounded-lg bg-gray-200 dark:bg-gray-700 ${className}`}". Retold could reserve space for arriving suggestions with quiet placeholders while the existing fields remain usable; use static placeholders under Reduce Motion. Effort M.

4. Noninteractive completion overlay - BoardBound/components/game/EarnToast.tsx:41, "pointerEvents=\"none\"". Retold's existing Filed pill could explicitly pass touches through with allowsHitTesting(false). Effort S.

5. Diagnostic capture - BoardBound/components/ErrorBoundary.tsx:34, "Sentry.captureException(error, {". A native diagnostic integration could expose failures behind rough sessions; M4 confirms Retold currently has none, although this would improve diagnosis rather than directly change appearance. Effort M.

Retold already uses coherent terracotta actions, native navigation, clear recording phases, and a reachable Stop button.
Playback redraw isolation, accessibility clock reflow, Reduce Motion checks, and proportionate filing feedback are strong foundations.
hook: Stop
hook: Stop Failed
