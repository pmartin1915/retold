No screenshots. Reviewed from the packet code only.

## Score table

| Dim | Score | Note |
|---|---|---|
| 1 Motion/fluidity | 2 | Pill, press springs, Reduce Motion all present; the live-text path stutters and several buttons have no press state |
| 2 State clarity | 3 | starting/saving/paused labels, alerts, disabled Stop, cached outcomes; no in-flight state on File it |
| 3 Input/recording robustness | 3 | Interrupted/Resume, blocked-mic alerts, no-full-swipe delete, single-flight via startInFlight |
| 4 Accessibility | 3 | Labels, announcements, 44 pt in most places; 32 pt suggestion buttons, fixed-size dot, "--" picker tag |
| 5 Visual system | 3 | Tokens exist and match StoryCue values; motion literals and one off-brand yellow banner remain |
| 6 Performance | 1 | M7 unmeasured (0); O(n) live-text rebuild per volatile event; per-row FileManager on main thread; store work in onAppear |
| 7 Copy | 3 | Plain and consistent; raw error detail leaks into one user-facing alert |
| 8 Layout | 2 | safeAreaInset bar and PlayerRow AX reflow are good; recorder screen has no AX-size strategy and no scroll-to-bottom |
| 9 Android parity | N/A | iOS only |

## Findings (blocker -> polish)

FINDING 1
- dimension: 6 (also 1)
- severity: blocker
- target: Retold/Capture/CaptureCoordinator.swift:240  quote: "private func rebuildLiveText() { let joined = journaledFinalTexts.joined(separator: \" \")" ; Retold/Screens/RecorderView.swift:66  quote: "Text(coordinator.liveText)"
- veteran counterpart: storycue/StoryCue/Views/RecorderView.swift:287  quote: ".fixedSize()"
- evidence: Perry's device report (2026-11-10): "live transcription misheard words, dropped speech and lagged." Every volatile event (CaptureCoordinator.swift:137-139) rebuilds the ENTIRE joined string, and because RecorderView reads `coordinator.liveText` in body, the whole title3 Text re-renders per event; the ScrollView (RecorderView.swift:65-70) has no ScrollViewReader, so as text grows the newest words appear below the visible area. StoryCue keeps its recording surface a small fixed-size pill instead of an unbounded growing text block.
- fix: Render journaled finals as one immutable Text and the volatile tail as a separate, secondary-styled Text so only the tail re-renders; throttle volatile UI updates to ~4 Hz; wrap the ScrollView in a ScrollViewReader and scroll to the bottom on change (instant, not animated, when Reduce Motion is on).

FINDING 2
- dimension: 5
- severity: should
- target: Retold/Screens/RecorderView.swift:75  quote: ".background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:48  quote: "static let capWarningFill = Color(red: 1.0, green: 0.76, blue: 0.03)"
- evidence: House style rule 2 ("Everything else is neutral") and rule 5 (values come from the tokens file); StoryCue's near-cap warning is a named token "always paired with the '1 min left' word". Retold's banner is an unnamed yellow one-off that will diverge from the shared package.
- fix: Add a `warningFill`/`warningInk` pair to DesignTokens (copy StoryCue's capWarning values) and use it for the length banner.

FINDING 3
- dimension: 4
- severity: should
- target: Retold/Screens/ConfirmView.swift:360  quote: ".frame(minHeight: 32)"
- veteran counterpart: storycue/StoryCue/Views/RecorderView.swift:232  quote: ".padding(.vertical, -8)              // 44 pt to touch, 28 pt of card height"
- evidence: Fetched Apple doc (developer.apple.com/design/human-interface-guidelines/buttons): "a button needs a hit region of at least 44x44 pt"; house style rule 4. Both the accept (line 360) and reject (line 370) buttons are 32 pt.
- fix: Raise both to `.frame(minHeight: 44)`; keep the visual weight with font, not height (StoryCue's comment shows the pattern).

FINDING 4
- dimension: 1
- severity: should
- target: Retold/Screens/ConfirmView.swift:398  quote: ".buttonStyle(.borderless)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:71  quote: "scale.value = withSpring(0.97, { damping: 15, stiffness: 300 });"
- evidence: Fetched Apple doc (HIG buttons): "Always include a press state for a custom button. Without a press state, a button can feel unresponsive." The same borderless style is used on OfferRow.swift:37 and the transcript segment buttons at EpisodeView.swift:110. Retold already HAS the fix: PressableRowStyle (DesignTokens.swift:47-63) with Reduce Motion handling.
- fix: Apply `.buttonStyle(.pressable)` to choiceButton, OfferRow's buttons, and the transcript segment buttons.

FINDING 5
- dimension: 6
- severity: should
- target: Retold/Playback/AudioPlayback.swift:32  quote: "func canPlay(_ captureID: UUID) -> Bool { FileManager.default.fileExists(atPath: files.audioURL(for: captureID).path) }"
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:110  quote: "const followUpQuestions = useMemo(() => {"
- evidence: Called in body per row at HomeView.swift:334 (".disabled(!playback.canPlay(captureID))") and EpisodeView.swift:83, i.e. a synchronous disk hit on the main thread for every row on every re-render of a long list (rubric dim 6: "scroll cost of long lists").
- fix: Cache the result per capture id (refresh on appear and after record/delete), or persist a hasAudio flag on the Capture model so body evaluation stays pure.

FINDING 6
- dimension: 6
- severity: should
- target: Retold/Screens/HomeView.swift:190  quote: "try? DefaultPeriods.seedIfNeeded(modelContext, defaults: .standard)"
- veteran counterpart: BoardBound/components/ui/Skeleton.tsx:30  quote: "<Animated.View style={animatedStyle} className={`rounded-lg bg-gray-200 dark:bg-gray-700 ${className}`}"
- evidence: Rubric dim 6 flags "first-frame work on the main thread"; the comment at HomeView.swift:188 says "Home is created fresh after Stop", so seed + AnswerAttacher.attachPending (line 191) run synchronously in onAppear after EVERY recording, plus a FetchDescriptor in handleAutoPresent (lines 293-297). Fetched Apple doc (HIG loading): "Show something as soon as possible."
- fix: Move seed/attach into a `.task` (attach already re-runs on scenePhase active, line 201-205) so the first frame is the list, not the store.

FINDING 7
- dimension: 8 (also 4)
- severity: should
- target: Retold/Screens/RecorderView.swift:55  quote: ".font(.system(size: DesignTokens.recordingDotSize))"
- veteran counterpart: storycue/StoryCue/Views/RecorderView.swift:294  quote: ".dynamicTypeSize(...DynamicTypeSize.accessibility1)"
- evidence: StoryCue's comment at line 293: "The nav bar has a fixed height; past AX1 the pill would clip", and lines 327-330 reflow the controls row at accessibility sizes. Retold's recorder has no `dynamicTypeSize` handling anywhere: the 20 pt dot never scales, and at AX5 the answering block, dot, timer, status, banner and live-text ScrollView (line 70 `.frame(maxHeight: .infinity)`) compete for fixed space, squeezing the live text. House rule 18.
- fix: Cap the dot/timer cluster at accessibility1 like StoryCue (or reflow it), and give the live-text ScrollView `.layoutPriority(1)` so it keeps the flexible space at AX sizes.

FINDING 8
- dimension: 1 (also 5)
- severity: polish
- target: Retold/Design/DesignTokens.swift:60  quote: ".animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3), value: configuration.isPressed)"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:15  quote: "enum Motion {                          // nothing over 0.5 s"
- evidence: House rule 8: "Motion values come only from the tokens file." Retold hardcodes `.spring(duration: 0.3, bounce: 0.3)` here, `.smooth(duration: 0.3)` at HomeView.swift:148, and `.smooth(duration: 0.25)` at ConfirmView.swift:441.
- fix: Add `DesignTokens.Motion` (morph/fade, mirroring StoryCue) and reference it from all three sites.

FINDING 9
- dimension: 5
- severity: polish
- target: Retold/Screens/RecorderView.swift:53  quote: "HStack(spacing: 12)"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:5  quote: "static let xs: CGFloat = 4"
- evidence: House rule 5's check is "Grep for padding and radius literals outside the tokens file." Retold's tokens lack xs (4) and m (12), so literals leak: RecorderView.swift:53 (12), HomeView.swift:254 (4), EpisodeView.swift:357 (4), ConfirmView.swift:52 (16), and a bare `.padding()` at RecorderView.swift:78.
- fix: Add xs/m to Retold's Spacing (same values as StoryCue) and replace the literals.

FINDING 10
- dimension: 7 (also 4)
- severity: polish
- target: Retold/Copy/AppCopy.swift:186  quote: "static let startFailedMessage = \"Nothing was recorded. Close Retold and try again. Details: \""
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:68  quote: "An unexpected error occurred. Your study progress is saved locally and"
- evidence: HomeView.swift:174 appends the raw value: "Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? \"\"))", and CaptureCoordinator.swift:134 falls back to the string "unknown", so users can see "Details: unknown". ErrorBoundary keeps user copy clean and gates debug detail behind `__DEV__` (lines 83-91). Rubric dim 7: "no jargon."
- fix: Show only the plain sentence; log the detail, or append it only in `#if DEBUG`.

FINDING 11
- dimension: 4
- severity: polish
- target: Retold/Screens/ConfirmView.swift:171  quote: "Text(\"--\").tag(Int?.none)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:84  quote: "accessibilityLabel={accessibilityLabel}"
- evidence: VoiceOver reads "--" as punctuation, not a state; the app already has the right string at AppCopy.swift:94: "static let notSure = \"Not sure\"" (used by the button at ConfirmView.swift:192).
- fix: Use `Text(AppCopy.notSure).tag(Int?.none)` as the wheel's first row.

## Veteran or sibling features worth borrowing

1. StoryCue recording pill (dot + word + timer in one capsule, fixedSize): storycue/StoryCue/Views/RecorderView.swift:270-296. In Retold: one "Recording 04:12" pill replaces the bare 20 pt dot plus separate secondary label, so state reads at a glance. Effort S.
2. Crash reporting: BoardBound/components/ErrorBoundary.tsx:34 "Sentry.captureException(error, {". Retold has none (probe M4 = 0); a MetricKit or Sentry subscriber would make the next device crash diagnosable. Effort M.
3. Motion tokens: storycue/StoryCue/DesignTokens.swift:15-18. Shared `Motion.morph`/`Motion.fade` so the future shared package lands with zero call-site churn. Effort S.
4. StaggeredEntrance: BoardBound/components/ui/StaggeredEntrance.tsx:39 "FadeInUp.duration(durationMs).delay(initialDelayMs + i * staggerMs)". ConfirmView's sections could stagger in once when the draft builds, making filing feel composed instead of popped. Effort M.
5. Skeleton placeholder: BoardBound/components/ui/Skeleton.tsx:30-33. ConfirmView's bare ProgressView while "Looking for names and places..." (ConfirmView.swift:61) becomes shimmering placeholder rows matched to the form's shape. Effort S.

## What the target already does well

The Filed pill is a faithful EarnToast port: transition + Reduce Motion fade fallback, VoiceOver announcement, success haptic, and a cancel-safe 2.5 s auto-dismiss (HomeView.swift:144-154). PlayerRow isolates the 4 Hz playback tick to one row and reflows at accessibility sizes (EpisodeView.swift:127-142), Stop is disabled while starting/stopping, and the press-spring row style correctly keeps dimming under Reduce Motion.
