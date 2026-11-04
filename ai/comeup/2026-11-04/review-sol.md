| Dimension | Score (0-4) | Packet-based assessment |
|---|---:|---|
| 1. Motion and fluidity | 1 | Native navigation is present; shown recorder actions lack the veteran's explicit haptic feedback. |
| 2. State clarity | 2 | Saving, export and several errors are visible; starting and some persistence failures are not distinguished. |
| 3. Input and recording robustness | 2 | Reducer handles interruptions and repeated recorder events; permission requests lack a UI single-flight guard. |
| 4. Accessibility | 2 | Semantic text styles and playback labels help; playback seeking lacks a descriptive label. |
| 5. Visual system | 2 | Mostly consistent system components; recorder uses local color literals. Full HOUSE-STYLE rules and contrast numbers: not in packet. |
| 6. Performance | 2 | Archive creation runs off the main actor; synchronous export preparation and repeated sorting remain. |
| 7. Copy | 2 | Copy is centralized, but its definitions are not in packet. One picker uses an ambiguous literal. |
| 8. Layout resilience | 2 | Lists and forms provide adaptive foundations; suggestion controls stay in horizontal rows. APPLE-IPHONE-DUO-PREP and orientation configuration: not in packet. |

Scores are provisional assessments of the excerpts. No blocker is demonstrated. Engine/coordinator implementations, kill recovery, low-storage handling, rendered contrast, Bold Text behavior and device layouts are not in packet. ConfirmView ends during load(); its filing implementation cannot be assessed.

FINDING 1
- dimension: 2
- severity: should
- target: retold/Retold/Screens/PeriodsView.swift:117  quote: "// .emptyTitle and save failures keep the sheet open, with no alert."
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:178  quote: ": \"Questions may not have loaded yet. Try restarting the app.\"}"
- evidence: The generic catch at lines 116-118 neither updates visible state nor reports an error. A thrown save failure leaves the same form onscreen without explaining why Save did not complete. The veteran explicitly describes a failure and a recovery action.
- fix: Add a save-error state and show an inline message or alert explaining that the period could not be saved and the user can retry. Preserve the entered text and keep duplicate-title feedback distinct.

FINDING 2
- dimension: 2
- severity: should
- target: retold/Retold/Screens/RecorderView.swift:62  quote: "Text(AppCopy.recordingLabel)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:192  quote: "return <QuestionSkeleton />;"
- evidence: RetoldApp.swift:67 routes .starting to RecorderView. RecorderView only distinguishes interrupted and stopping; consequently .starting reaches the recording label before engineStarted changes the reducer to .recording. The veteran gives not-yet-ready content a separate presentation.
- fix: Give .starting an explicit preparing presentation with a ProgressView and accurate copy. Preserve the reducer's existing Stop-during-start behavior instead of presenting the engine as already recording.

FINDING 3
- dimension: 3
- severity: should
- target: retold/Retold/Screens/RecorderView.swift:92  quote: "let total = Int(now.timeIntervalSince(startedAt))"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:102  quote: "if (isAnswered) {"
- evidence: startedAt is initialized when the view is created, and elapsed() always measures wall time from that date. RecorderMachine.swift:225 pauses the engine during an interruption, but the displayed timer continues advancing during that pause and during stopping. The veteran's timer explicitly freezes outside its timed activity.
- fix: Drive elapsed time from coordinator-owned recording duration or accumulated active intervals. Freeze it during interruptions and finalization, and start it when recording actually begins.

FINDING 4
- dimension: 3
- severity: should
- target: retold/Retold/Screens/FirstRunView.swift:22  quote: "let permission = await engine.requestMicrophonePermission()"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:82  quote: "if (isAnswered) return; // freeze chip during answer feedback"
- evidence: Every press creates a Task, and the button has no pending flag, synchronous guard or disabled modifier. The excerpt therefore permits concurrent permission-request tasks and repeated prefetch/onDone calls if multiple tasks return granted. Whether the engine independently coalesces requests is not in packet; the veteran illustrates explicitly gating work by state.
- fix: Set an isRequesting flag synchronously in the button action before creating the Task. Disable the button and show progress until the request finishes, clearing the flag on every completion path.

FINDING 5
- dimension: 2
- severity: should
- target: retold/Retold/Screens/HomeView.swift:155  quote: "_ = try? AnswerAttacher.attachPending(in: modelContext)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:178  quote: ": \"Questions may not have loaded yet. Try restarting the app.\"}"
- evidence: This attachment call discards thrown errors and proceeds to handleAutoPresent(). Attachment failures are also discarded at lines 162, 167 and 243. The shown UI cannot distinguish a failed attachment attempt from normal completion; the veteran makes a failed content state visible.
- fix: Catch attachment errors and expose one recoverable message without discarding the capture. Preserve the attach-before-presentation ordering and retry through the existing attachment path.

FINDING 6
- dimension: 4
- severity: should
- target: retold/Retold/Screens/EpisodeView.swift:83  quote: "Slider("
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:171  quote: "aria-label=\"Restart breathing exercise\""
- evidence: The shown Slider initializer supplies a value binding and range but no label, and its modifiers add only disabled state. The adjacent clock text is not explicitly connected as its accessibility value. The veteran supplies an explicit action name.
- fix: Add an accessibility label such as "Playback position" and an accessibility value expressing elapsed time and duration in spoken units. Include recording context when multiple players are present on the page.

FINDING 7
- dimension: 6
- severity: should
- target: retold/Retold/Screens/SettingsView.swift:79  quote: "manifest = ExportManifest.build(library, exportedAt: Date(), timeZone: .current)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:72  quote: "const todayTotal = useMemo(() => getTodayAnsweredCount(), [isAnswered]);"
- evidence: startExport() synchronously fetches all periods, episodes, captures and questions and builds the manifest before reaching its Task. The file explicitly says this preparation occurs on the main actor. Setting exportState to .preparing does not yield before that work, so progress rendering and interaction can wait for it. Runtime cost is not measured in packet; the veteran limits repeated derived work using explicit dependencies.
- fix: Fetch and prepare export data in a background SwiftData ModelActor, returning a Sendable manifest to the view. Keep progress-state changes on the main actor and avoid passing live model instances into Task.detached.

FINDING 8
- dimension: 8
- severity: should
- target: retold/Retold/Screens/ConfirmView.swift:320  quote: "HStack {"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:128  quote: "<div className=\"flex flex-col items-center gap-3 py-8 text-center\">"
- evidence: suggestionRow places the span, optional suggested label, spacer and both action buttons in one HStack. The suggested-period row at lines 118-131 has the same structure. These rows have no width- or Dynamic-Type-dependent vertical alternative, so increasing text size leaves every element competing for the same horizontal space. Actual clipping is not demonstrated by the packet; the veteran shows a vertical content/action arrangement.
- fix: Use ViewThatFits or an accessibility-Dynamic-Type branch to move the actions below the suggestion. Give each action adequate padding and a minimum 44-point interactive height, then verify long names at the largest text sizes.

FINDING 9
- dimension: 6
- severity: polish
- target: retold/Retold/Screens/HomeView.swift:294  quote: "episode.captures.sorted { (a: Capture, b: Capture) -> Bool in"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:72  quote: "const todayTotal = useMemo(() => getTodayAnsweredCount(), [isAnswered]);"
- evidence: firstCapture sorts the complete capture collection and then takes .first. EpisodeRow.body reads that property for its playback control, so reevaluation repeats a full sort merely to select one item. The veteran caches derived work against a stated dependency.
- fix: Replace sorted(...).first with min(by:) using the same createdAt and UUID ordering. This preserves the selected recording while reducing selection from a full sort to one pass.

FINDING 10
- dimension: 1
- severity: polish
- target: retold/Retold/Screens/RecorderView.swift:52  quote: "Task { @MainActor in coordinator.send(.tapResume) }"
- veteran counterpart: wilderness/src/components/breathing/BreathingExercise.tsx:60  quote: "void haptic('medium');"
- evidence: The complete shown RecorderView sends Resume and Stop events but contains no sensoryFeedback modifier or UIKit feedback call. The veteran explicitly provides haptic feedback at meaningful phase changes. Coordinator-level feedback is not in packet, so this finding is limited to the shown view.
- fix: If feedback is not already centralized, attach SwiftUI sensory feedback to confirmed recording-state transitions. Trigger it once when recording begins or resumes and when stopping completes, rather than on every timer update or repeated tap.

FINDING 11
- dimension: 5
- severity: polish
- target: retold/Retold/Screens/RecorderView.swift:69  quote: ".background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))"
- veteran counterpart: burn-wizard/app/src/styles/design-system.css:49  quote: "--warning: 43 89% 58%; /* Amber for caution */"
- evidence: The recorder defines warning color, opacity and corner radius locally; its status circle also uses .red at line 38. The veteran centralizes warning styling and supplies a dark-mode warning token at line 167. Retold's full palette and HOUSE-STYLE rules are not in packet, so a specific brand or contrast violation cannot be established.
- fix: Route these recorder treatments through shared SwiftUI semantic colors and shape constants, using existing project tokens if available. Verify the resulting foreground/background combinations in both appearances without copying the veteran's palette.

FINDING 12
- dimension: 7
- severity: polish
- target: retold/Retold/Screens/ConfirmView.swift:164  quote: "Text(\"-\").tag(Int?.none)"
- veteran counterpart: BoardBound/boardbound/app/quiz/question.tsx:173  quote: "{isSrsMode ? \"All caught up\" : \"No questions available\"}"
- evidence: The wheel represents its nil selection with a hyphen, although that selection explicitly sets .notSure at lines 177-179. The veteran names its states in plain words; the target's symbol does not explain its meaning.
- fix: Replace the hyphen with AppCopy.notSure so the visible wheel selection matches the existing action and stored state.

Retold already provides reusable empty states with a recovery action, destructive-action confirmation, and visible export preparation/failure states.
Its recorder reducer guards capture identity, handles interruptions with explicit resume, and preserves journal import ordering around protected-data availability.