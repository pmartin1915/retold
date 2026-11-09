SCORES (0-4)

| # | Dimension | Score | One-line reason |
|---|---|---|---|
| 1 | Motion and fluidity | 2 | Screen fade and haptics exist (RetoldApp.swift:106). No press states, no animated list or draft changes, and Home and Confirm swap content abruptly. |
| 2 | State clarity | 2 | Starting, saving, transcribing and export states are good. Filing failure is silent, startup failure is a dead end, and an empty Home has no designed state. |
| 3 | Input/recording robustness | 3 | Single-flight start, interruption clock, mic-denied path, and scene and protected-data handling are strong (CaptureCoordinator.swift:325, FirstRunView.swift:32). Low storage and rapid Stop are not visible in the packet. |
| 4 | Accessibility | 2 | Labels and 44 pt targets exist. Repeated "Use this"/"Not this" buttons have no object, and HStack rows are not Dynamic Type safe. |
| 5 | Visual system | 1 | Stock grouped List everywhere. No brand colour, mark or prominent primary action (S1, S3). |
| 6 | Performance | 2 | Single-pass capture is fine. The 4 Hz playback tick re-renders the whole story page, and the hitch metrics are unmeasured (M7). |
| 7 | Copy | 2 | Plain and consistent, but "Use this" and "Not this" are ambiguous and the start-failure alert shows raw error text. |
| 8 | Layout resilience | 2 | The Confirm row squeezes titles to 3 lines (S4), the title truncates (S5), and the recorder has 60% dead space (S3). |
| 9 | Android parity | N/A | iOS only. |

FINDING 1
- dimension: 5
- severity: should
- target: Retold/Screens/HomeView.swift:41  quote: "Button(AppCopy.recordButton) {"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:73  quote: "className=\"mb-3 w-full rounded-xl bg-brand-600 px-6 py-4 active:bg-brand-700\""
- evidence: The only primary action of the app is a bare list-row button (S1) with the same weight as every other row. Apple Buttons: "use a button that has a prominent visual style for the most likely action in a view." HOUSE-STYLE rule 11: "`borderedProminent` in `.safeAreaInset(edge: .bottom)`".
- fix: Move the record action out of the List into a `.safeAreaInset(edge: .bottom)` containing a full-width `Button { ... }` with `Label(AppCopy.recordButton, systemImage: "mic.fill")`, `.buttonStyle(.borderedProminent)`, `.controlSize(.large)`. Keep the existing `playback.stop()` and `startCapture` body unchanged.

FINDING 2
- dimension: 8
- severity: should
- target: Retold/Screens/HomeView.swift:64  quote: "Section {" (the browse-links section, followed at line 65 by "NavigationLink(AppCopy.peopleHeader, destination: PeopleView())")
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:135  quote: "and region breakdown stay above the fold; pedagogy is opt-in."
- evidence: Five browse rows sit above the user's own stories (S2), so the stories start below the fold. Burn Wizard keeps the primary content above the fold and makes the secondary content opt-in.
- fix: Render the `sections` timeline (line 71) before the browse links. Collapse the five links into one compact "Browse" section placed last, or into a toolbar `Menu`. The user's stories should be the first thing after the record action.

FINDING 3
- dimension: 1
- severity: should
- target: Retold/Screens/RecorderView.swift:50  quote: "Circle()" (continues ".fill(.red)" and ".frame(width: 16, height: 16)" at lines 51-52); the clock is ".font(.title2.monospacedDigit())" at line 55
- veteran counterpart: BoardBound/components/ui/Skeleton.tsx:18  quote: "opacity.value = withRepeat("
- evidence: The recorder is a 16 pt static dot and a title2 clock above about 60% empty screen (S3). Nothing shows that the mic is live. Apple Motion: "Add motion purposefully, supporting the experience". A recording indicator that never moves reads as frozen.
- fix: Enlarge the clock to `.system(.largeTitle).monospacedDigit()` (keep it a text style, using `.largeTitle.monospacedDigit()`). Make the dot pulse with a repeating `.easeInOut(duration: 0.8)` opacity, gated on `!reduceMotion` and `isRecording`. Fill the middle band with a simple level or waveform view if one is available, otherwise with the live transcript at body size.

FINDING 4
- dimension: 4
- severity: should
- target: Retold/Screens/RecorderView.swift:91  quote: "Button(AppCopy.stopButton) {"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:72  quote: "<Pressable"
- evidence: Stop is a plain blue text link (S3) with no frame. HOUSE-STYLE rule 4 requires "48 pt or more on time-pressured screens", and rule 11 asks for one clear primary action in thumb reach. Stop is the most time-pressured control in the app.
- fix: Apply `.buttonStyle(.borderedProminent)`, `.tint(.red)`, `.controlSize(.large)`, `.frame(maxWidth: .infinity, minHeight: 56)`. Keep the `.disabled(isStopping || isStarting)` line. Resume at line 64 should get the same prominent style.

FINDING 5
- dimension: 8
- severity: should
- target: Retold/Screens/ConfirmView.swift:335  quote: "Text(AppCopy.acceptButton).frame(minHeight: 44).contentShape(Rectangle())"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:91  quote: "<Text className={`flex-1 text-base leading-5 ${getTextStyle()}`}>"
- evidence: The suggestion row puts the title, the "suggested" tag, a Spacer and two text buttons (lines 326-339) in one HStack. The title is squeezed to 3 lines (S4). The veteran gives the content `flex-1` so the action never starves it.
- fix: Make the row a VStack. The chip text and "suggested" tag go on the first line at full width. The two actions sit on a second line as an HStack of `.bordered` small buttons ("Use this" tinted, "Not this" neutral). The same restructure fixes the Period row (lines 118-131).

FINDING 6
- dimension: 8
- severity: should
- target: Retold/Screens/EpisodeView.swift:23  quote: "Section(AppCopy.recordingsHeader) {" (it comes after "OfferSection(" at line 19, and the title is set at line 29 with ".navigationTitle(facts.title ?? AppCopy.untitled)")
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:134  quote: "// Group educational content (teaching points, common mistakes, discussion prompts)"
- evidence: Five offer rows push the player and transcript off screen (S5), so the user's own voice is last. The nav title also truncates ("Summers at the lake ho..."). Burn Wizard groups secondary content so it does not crowd the primary.
- fix: Put the Recordings section directly after the facts and the OfferSection last. Collapse the offers into one "Questions (5)" `DisclosureGroup` row. Use `.navigationBarTitleDisplayMode(.inline)` and show the full title as a wrapping `.title2.bold()` Text at the top of the List.

FINDING 7
- dimension: 2
- severity: blocker
- target: Retold/RetoldApp.swift:14  quote: "Text(AppCopy.startupFailed)"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:74  quote: "onPress={this.handleRetry}"
- evidence: The startup failure screen is bare text with no button. The copy says "Restart the app to try again", so the user is stranded. Run 1 deferred this. Loading is a bare `ProgressView()` at line 19. HOUSE-STYLE rule 12: "Designed empty, error and missing-data states, each with one action."
- fix: Replace it with a `ContentUnavailableView` (the same pattern as EmptyPage.swift:13) with a "Try again" button. The button sets `startupFailed = false` and re-runs the `makeCoordinator` task, so move the do/catch into a function. Show a branded launch view instead of the bare spinner at line 19.

FINDING 8
- dimension: 7
- severity: should
- target: Retold/Screens/HomeView.swift:139  quote: "Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? \"\"))"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:83  quote: "{__DEV__ && this.state.error && ("
- evidence: CaptureCoordinator.swift:219 sets `startFailure = String(describing: error)`, so users see a raw Swift error dump after "Details: ". The veteran shows technical detail only in dev builds. The copy rubric asks for "what happened and what to do; no jargon".
- fix: Show only "Nothing was recorded. Close Retold and try again." to the user. Keep the detail behind `#if DEBUG`, or log it to the unified log. Drop the "Details: " suffix from `startFailedMessage`.

FINDING 9
- dimension: 2
- severity: should
- target: Retold/Screens/ConfirmView.swift:503  quote: "// Filing failures keep the unchanged draft on screen, per the R7a contract."
- veteran counterpart: Retold OfferRow is the in-house bar; veteran: BoardBound/components/ErrorBoundary.tsx:62 quote: "<View className=\"flex-1 items-center justify-center bg-white dark:bg-gray-900 px-8\">" (a designed failure surface)
- evidence: If `ConfirmFiler.file` throws, the catch is empty. File it does nothing visible: a silent failure on the most important commit action in the app. OfferRow.swift:44 already has `.alert(AppCopy.saveFailedTitle, isPresented: $saveFailed)`, so the pattern exists.
- fix: Add `@State private var saveFailed = false` to ConfirmView, set it in the catch, and attach the same `.alert(AppCopy.saveFailedTitle...)` to the NavigationStack. Disable File it while the call is in flight. Add a `.sensoryFeedback(.error, ...)` twin.

FINDING 10
- dimension: 1
- severity: should
- target: Retold/Screens/HomeView.swift:188  quote: ".buttonStyle(.plain)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:71  quote: "scale.value = withSpring(0.97, { damping: 15, stiffness: 300 });"
- evidence: Unfiled rows (lines 183-202) and PeriodsView.swift:22 use `.plain` with a `contentShape` and have no press feedback. Apple Buttons: "Always include a press state for a custom button. Without a press state, a button can feel unresponsive". The veteran adds a spring press plus `Haptics.selectionAsync()` (OptionButton.tsx:64). Retold's Accept/Reject (ConfirmView.swift:334-339) have neither.
- fix: Add one `PressableRowStyle: ButtonStyle` with `.scaleEffect(configuration.isPressed ? 0.97 : 1)` and `.animation(reduceMotion ? nil : .spring(duration: 0.35), value: configuration.isPressed)`. Use it in place of `.plain`. Add `.sensoryFeedback(.selection, trigger:)` on Accept/Reject taps (HOUSE-STYLE rule 10 asks for a visible twin, and the chip state change is one).

FINDING 11
- dimension: 1
- severity: polish
- target: Retold/Screens/ConfirmView.swift:394  quote: "private func mutateDraft(_ mutation: (inout ConfirmDraft) -> Void) {"
- veteran counterpart: BoardBound/components/ui/StaggeredEntrance.tsx:39  quote: ": FadeInUp.duration(durationMs).delay(initialDelayMs + i * staggerMs)"
- evidence: Every accept, reject and pick mutates the draft with no animation, so the picker, segmented control and "Same as" rows appear and vanish with a layout jump. The sheet body also swaps `ProgressView` for the full form at lines 42-55 with no transition. Apple Motion: "Aim for brevity and precision in feedback animations". The veteran gates its entry animation on Reduce Motion.
- fix: Wrap the assignment `draft = value` in `withAnimation(reduceMotion ? nil : .smooth(duration: 0.25))`. Add `.transition(.opacity)` plus `.animation(...)` on the Group at line 41 keyed on `draft != nil`.

FINDING 12
- dimension: 4
- severity: should
- target: Retold/Screens/ConfirmView.swift:335  quote: "Text(AppCopy.acceptButton).frame(minHeight: 44).contentShape(Rectangle())" (reject twin at line 338)
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:58  quote: "const accessibilityLabel = isAnswered"
- evidence: Every suggestion row exposes buttons named only "Use this" and "Not this", repeated for the title, the period and each person and place. VoiceOver cannot tell which suggestion each one acts on. The veteran builds a label from the option text. HOUSE-STYLE rule 17 requires VoiceOver to be complete.
- fix: Add `.accessibilityLabel("\(AppCopy.acceptButton): \(chip.span.text)")` and the matching reject label. Add `.accessibilityElement(children: .contain)` on the row. Do the same for the period row using `suggested.title`.

FINDING 13
- dimension: 6
- severity: should
- target: Retold/Screens/EpisodeView.swift:85  quote: "get: { isLoaded ? playback.currentTime : 0 },"
- veteran counterpart: none in packet
- evidence: `playerRow` is called from `EpisodeView.body` (line 70), so the body reads `playback.currentTime`, which AudioPlayback.swift:114 writes every 0.25 s ("self.currentTime = player.currentTime"). While audio plays, the whole List, including `facts` and `sortedCaptures` and `playback.canPlay` at line 69, re-renders 4 times a second. `canPlay` does a `FileManager.fileExists` call per capture each time (AudioPlayback.swift:24). This is a likely hitch source, and hitches are unmeasured (M7).
- fix: Extract the slider and clock into a small `PlayerRow` view that alone reads `currentTime`, so only that row invalidates. Compute `canPlay` once per capture into @State on appear.

FINDING 14
- dimension: 4
- severity: should
- target: Retold/Screens/EpisodeView.swift:81  quote: "return HStack {" (PlayPauseButton, Slider and clock Text all in one row, closed at line 102)
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:91  quote: "<Text className={`flex-1 text-base leading-5 ${getTextStyle()}`}>"
- evidence: At accessibility Dynamic Type sizes, the "0:00 / 3:25" clock at line 99 plus a 44 pt button leaves the slider a sliver. HomeView.swift:306 (EpisodeRow `HStack` with a Spacer and PlayPauseButton) is the same pattern. Run 1 deferred Dynamic Type row layout. HOUSE-STYLE rule 18: "Check at AX5".
- fix: Use `@Environment(\.dynamicTypeSize)` and switch to `VStack` (slider on its own line, clock under it) when `dynamicTypeSize.isAccessibilitySize`. Do the same for EpisodeRow.

FINDING 15
- dimension: 2
- severity: should
- target: Retold/Screens/HomeView.swift:64  quote: "Section {" (the browse-links section is always built; there is no empty branch for a first-time user)
- veteran counterpart: BoardBound/components/BrandedSplash.tsx:21  quote: "<View className=\"mb-4 h-20 w-20 items-center justify-center rounded-2xl bg-white/20\">"
- evidence: A new user sees "Record a memory" plus five empty browse links and nothing about what Retold is (S1: "no brand colour, no mark, no imagery"). The app already uses `ContentUnavailableView` for the same job (EmptyPage.swift:13).
- fix: When `unfiledCaptures.isEmpty && episodes.isEmpty`, show a `ContentUnavailableView` with the brand mark, one sentence of what the app does, and the prominent record button from Finding 1. Hide the browse links until at least one episode exists.

VETERAN FEATURES WORTH BORROWING

1. Spring press scale plus selection haptic on custom controls. BoardBound/components/question/OptionButton.tsx:64 and :71. In Retold, one shared `ButtonStyle` gives every tappable row and "Use this"/"Not this" a 0.97 spring press and a selection haptic. Effort S.
2. Brand splash and mark. BoardBound/components/BrandedSplash.tsx:16-24. In Retold, a brand-colour launch and loading view with the mark and a short fade-up replaces the bare `ProgressView` at RetoldApp.swift:19 and anchors the visual identity. Effort S.
3. Confirmation toast with an announcement. BoardBound/components/game/EarnToast.tsx:28 and :38. In Retold, a short "Filed under Summers at the lake" capsule fades in after File it, with a VoiceOver announcement and Reduce Motion respected, giving the flow one proportionate completion moment (HOUSE-STYLE rule 16). Effort S.
4. Skeleton pulse for pending rows. BoardBound/components/ui/Skeleton.tsx:15-23. In Retold, unfiled rows in the "Transcribing..." state and the Confirm sheet's loading phase show pulsing placeholder lines instead of a lone spinner. Effort S.
5. Tabbed secondary content. burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:134-158. In Retold, the story page gets a segmented control (Recordings / Questions), so a person's own recording and words are first and the offers are opt-in. Effort M.

ALREADY DOES WELL
- Reliability engineering is far above the UI: single-flight start (CaptureCoordinator.swift:325), recorded-time-only clock, interruption and protected-data handling, and the cancel-safe suggestion task (ConfirmView.swift:452).
- Accessibility and motion basics are in place: Reduce Motion gating on the screen fade (RetoldApp.swift:106), VoiceOver announcements on phase changes (RecorderView.swift:105), 44 pt hit targets, and a designed `EmptyPage` for sub-pages.
