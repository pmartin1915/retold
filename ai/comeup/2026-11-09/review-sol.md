| Dimension | Score | Basis |
|---|---|---|
| 1. Motion and fluidity | 2/4 | Reduce Motion and recorder/playback haptics implemented; M7 reports hitches unmeasured. |
| 2. State clarity | 1/4 | Useful recording states, but filing and playback can fail silently; startup has no Retry. |
| 3. Input and recording robustness | 3/4 | Single-flight capture start, serial engine effects, and scene/protected-data handling. Device interruption and low-storage results not in packet. |
| 4. Accessibility | 2/4 | Improved labels, announcements, and targets; crowded rows remain, and AX5 validation is not in packet. |
| 5. Visual system | 1/4 | S1-S4 show weak hierarchy and little product identity. |
| 6. Performance | 1/4 | Export preparation blocks the main actor; launch and hitch metrics absent per M7. |
| 7. Copy | 2/4 | Mostly specific and plain; recording-start errors expose technical details. |
| 8. Layout resilience | 2/4 | Native containers, but S4-S5 demonstrate crowding and truncation. Foldable-hazard audit not in packet. |
| 9. Android parity | N/A | iOS only. |

FINDING 1
- dimension: 2
- severity: should
- target: Retold/Screens/ConfirmView.swift:503 quote: "// Filing failures keep the unchanged draft on screen, per the R7a contract."
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:76 quote: "accessibilityLabel=\"Try again\""
- evidence: After "try ConfirmFiler.file(draft, capture: capture, in: modelContext)" at line 500, the catch contains only the quoted comment. A failed File it tap leaves no visible explanation.
- fix: Preserve the draft and show a filing-failure alert with a concrete retry instruction. Keep File it available for retry; change only failure presentation, leaving filing logic intact.

FINDING 2
- dimension: 2
- severity: should
- target: Retold/Playback/AudioPlayback.swift:29 quote: "/// failure (a missing file, a decode failure, a session error) stops quietly: no alert."
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:65 quote: "Something went wrong"
- evidence: The catch at line 65 calls "stop()" without exposing an error state. An existing but undecodable audio file can therefore produce an apparently dead Play tap.
- fix: Publish a playback failure state and present a short explanation beside the affected recording, with a retry action. Distinguish a missing recording from a temporary playback failure.

FINDING 3
- dimension: 2
- severity: should
- target: Retold/RetoldApp.swift:23 quote: "guard services == nil, !startupFailed else { return }"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:42 quote: "this.setState({ hasError: false, error: null });"
- evidence: Startup failure sets "startupFailed = true" at line 37; the failure branch displays only "Text(AppCopy.startupFailed)" at line 14. The guard prevents another initialization attempt.
- fix: Present a native error state with Retry. Extract initialization into a reusable action that clears the failure state and attempts service creation again, showing progress during the attempt.

FINDING 4
- dimension: 6
- severity: should
- target: Retold/Screens/SettingsView.swift:70 quote: "/// the \"preparing\" state paint before a large library blocks the thread."
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:110 quote: "const followUpQuestions = useMemo(() => {"
- evidence: "Task { @MainActor in" at line 73 reaches synchronous fetches and "manifest = ExportManifest.build(library, exportedAt: Date(), timeZone: .current)" at line 88. Yielding once permits a paint but does not remove the subsequent blocking work.
- fix: Translate the veteran's isolated derived-work pattern into a SwiftData background actor with its own context, returning a Sendable manifest. Keep export-state updates on the main actor and verify responsiveness with a large library.

FINDING 5
- dimension: 5
- severity: should
- target: Retold/Screens/HomeView.swift:41 quote: "Button(AppCopy.recordButton) {"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:73 quote: "className=\"mb-3 w-full rounded-xl bg-brand-600 px-6 py-4 active:bg-brand-700\""
- evidence: S1 identifies Record a memory as a plain blue row with the same weight as other rows. Apple says, "In general, use a button that has a prominent visual style for the most likely action in a view." https://developer.apple.com/design/human-interface-guidelines/buttons
- fix: Give Record a memory a native prominent style, a microphone SF Symbol, and the product accent. Place it within thumb reach using a bottom safe-area inset, retaining system chrome and built-in interaction states.

FINDING 6
- dimension: 8
- severity: should
- target: Retold/Screens/HomeView.swift:65 quote: "NavigationLink(AppCopy.peopleHeader, destination: PeopleView())"
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:136 quote: "// and region breakdown stay above the fold; pedagogy is opt-in."
- evidence: The five browse links at lines 65-69 precede the story sections at line 71. S2 reports that the user's stories begin below the fold after one unfiled row.
- fix: Put recent stories before the browse links. Group the existing browse destinations into a compact secondary section so library navigation does not consume the first screen.

FINDING 7
- dimension: 8
- severity: should
- target: Retold/Screens/EpisodeView.swift:19 quote: "OfferSection("
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:135 quote: "// into a single tab block to reduce feedback-screen density. Score, comparison,"
- evidence: OfferSection appears before "Section(AppCopy.recordingsHeader)" at line 23. S5 confirms that five question offers push the player and transcript below the fold, and XCUI required scrolling to find the slider.
- fix: Place recordings and verbatim transcripts ahead of question offers. Put the existing questions in a DisclosureGroup below them, translating the veteran's optional secondary-content pattern into SwiftUI without changing the question queue.

FINDING 8
- dimension: 4
- severity: should
- target: Retold/Screens/ConfirmView.swift:327 quote: "Text(chip.span.text)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:91 quote: "<Text className={`flex-1 text-base leading-5 ${getTextStyle()}`}>"
- evidence: The HStack at line 326 shares width among the suggestion, status, spacer, and two buttons. S4 reports that the suggestion wraps to three lines because the controls consume most of the width; the period suggestion repeats this structure at line 118.
- fix: Give suggestion text a full-width first row and place status and actions beneath it. Use an adaptive layout for both suggestion implementations, preserve 44x44 pt action regions, and verify at AX5 without shrinking text.

FINDING 9
- dimension: 5
- severity: should
- target: Retold/Screens/RecorderView.swift:91 quote: "Button(AppCopy.stopButton) {"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:82 quote: "className={`flex-row items-center rounded-xl border-2 px-4 py-3.5 ${getStyle()}`}"
- evidence: S3 describes Stop as a plain blue text link beneath a largely empty recorder. Apple says, "Different platforms define different styles that help you communicate hierarchies of actions in your app." https://developer.apple.com/design/human-interface-guidelines/buttons
- fix: Make Stop the recorder's prominent native control in a bottom safe-area inset, with a stop SF Symbol and at least a 44x44 pt target. Strengthen the existing timer and recording-status grouping while preserving starting, interrupted, and saving states.

FINDING 10
- dimension: 7
- severity: should
- target: Retold/Screens/HomeView.swift:139 quote: "Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? \"\"))"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:83 quote: "{__DEV__ && this.state.error && ("
- evidence: AppCopy.swift:181 includes "Nothing was recorded. Close Retold and try again. Details: " and CaptureCoordinator.swift:219 assigns "startFailure = String(describing: error)". Technical error descriptions therefore reach the production alert, whereas the veteran gates its debug detail.
- fix: Map known start failures to plain explanations and useful next steps; use a generic retry message for unknown failures. Keep technical details in developer diagnostics rather than the user-facing message.

FINDING 11
- dimension: 5
- severity: polish
- target: Retold/Screens/RecorderView.swift:89 quote: ".background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:35 quote: "? \"border-brand-600 bg-brand-50 dark:bg-brand-950\""
- evidence: The recorder uses literal color, opacity, radius, and spacing values; S1 also reports no visible brand color or mark on Home. House style requires "Shared spacing and radius tokens:" and "One accent: the product line's".
- fix: Define shared SwiftUI spacing, radius, accent, and semantic warning tokens, then apply them across the supplied screens. Use the product accent for actions and wayfinding; validate warning and secondary-text contrast in light, dark, and Increase Contrast appearances.

FINDING 12
- dimension: 8
- severity: polish
- target: Retold/Screens/EpisodeView.swift:29 quote: ".navigationTitle(facts.title ?? AppCopy.untitled)"
- veteran counterpart: BoardBound/components/BrandedSplash.tsx:24 quote: "<Text className=\"text-3xl font-bold text-white\">BoardBound</Text>"
- evidence: S5 reports that the navigation title truncates to "Summers at the lake ho...". The supplied EpisodeView has no separate full-title content header.
- fix: Render the full story title as a wrapping semantic heading within the scrollable content, borrowing the veteran's explicit content-heading pattern. Retain a compact native navigation title and verify long titles at AX5.

VETERAN FEATURES WORTH BORROWING

- Accessible completion notice - BoardBound/components/game/EarnToast.tsx:28, "AccessibilityInfo.announceForAccessibility(announcement);". In Retold, a successful filing could show a brief confirmation and announce it to VoiceOver, with Reduce Motion respected. Effort: S.
- Selection feedback - BoardBound/components/question/OptionButton.tsx:64, "Haptics.selectionAsync();". In Retold, accepting a suggestion could pair a light selection haptic with a visible accepted state. Effort: S.
- Content-shaped loading placeholders - BoardBound/components/ui/Skeleton.tsx:32, "className={`rounded-lg bg-gray-200 dark:bg-gray-700 ${className}`}". In Retold, suggestion loading could reserve the eventual form structure using SwiftUI redacted placeholders, static under Reduce Motion. Effort: M.
- Branded loading identity - BoardBound/components/BrandedSplash.tsx:22, "<BrandMark size={64} color=\"#ffffff\" />". In Retold, the existing startup loading state could include its own mark and semantic product title without adding a timed splash delay. Effort: S.

Retold already handles recording-time accounting, starting/saving labels, Reduce Motion, and discrete recorder haptics thoughtfully.
Native navigation, labelled playback controls, explicit deletion confirmation, and verbatim transcript presentation provide a solid foundation.