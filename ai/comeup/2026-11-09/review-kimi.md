Retold QA review, run 2 packet (2026-11-09). All quotes are verbatim from the packet; target line numbers are the in-file numbers shown in the excerpts. Dimension 9 is N/A (iOS only).

## Score table

| # | Dimension | Score | One-line basis |
|---|---|---|---|
| 1 | Motion and fluidity | 2 | Fades + phase haptics + Reduce Motion respected, but no press states, no stagger, recorder/home read static (S1, S3) |
| 2 | State clarity | 2 | Good recorder labels and alerts, but silent playback failure, dead-end startup failure, no retry, empty Home |
| 3 | Input and recording robustness | 3 | Single-flight taps, interruption/resume states, launch inbox, background file pass all present |
| 4 | Accessibility | 2 | Labels, announcements, some 44 pt targets; no Dynamic Type pass, low-contrast disabled states (M6) |
| 5 | Visual system | 1 | Stock inset-grouped list, no brand presence, primary action is a plain text row (S1); rows squeeze and wrap (S4) |
| 6 | Performance | 2 | Single-pass first capture and detached zip, but export fetch on main actor and zero fluidity measurement (M7) |
| 7 | Copy | 3 | Plain, consistent AppCopy throughout; docked for raw error detail in the start-failure alert |
| 8 | Layout resilience | 2 | S5 shows the story page pushing the player's own content below the fold; largest-type behavior unverified |
| 9 | Android parity | N/A | iOS only |

## Findings (ordered blocker -> polish; no blockers this run)

FINDING 1
- dimension: 5
- severity: should
- target: Retold/Screens/HomeView.swift:41  quote: "Button(AppCopy.recordButton) {"
- veteran counterpart: BoardBound/components/BrandedSplash.tsx:73  quote: "className=\"mb-3 w-full rounded-xl bg-brand-600 px-6 py-4 active:bg-brand-700\""
- evidence: S1: the primary action "Record a memory" is "a plain blue text row, same weight as every other row, no icon, no fill." Apple HIG buttons (https://developer.apple.com/design/human-interface-guidelines/buttons): "use a button that has a prominent visual style for the most likely action in a view." House rule 11 check: "A stranger names the action in one second."
- fix: Make Record a single prominent control (borderedProminent with a mic symbol, or a record ring) anchored in thumb reach via .safeAreaInset(edge: .bottom); it becomes the one accent use on the screen.

FINDING 2
- dimension: 1
- severity: should
- target: Retold/Screens/RecorderView.swift:91  quote: "Button(AppCopy.stopButton) {"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:71  quote: "scale.value = withSpring(0.97, { damping: 15, stiffness: 300 });"
- evidence: S3: "~60% of the screen empty white; ... 'Stop' as a plain blue text link at the bottom ... Stop is not a prominent button," and the only recording signal is a 16 pt red dot (RecorderView.swift:50-52 "Circle() / .fill(.red) / .frame(width: 16, height: 16)"). Apple HIG buttons: "Always include a press state for a custom button. Without a press state, a button can feel unresponsive."
- fix: Give Stop a large, filled, high-contrast treatment with a press-state scale animation, and grow the recording indicator so the screen's empty band carries the live state.

FINDING 3
- dimension: 8
- severity: should
- target: Retold/Screens/ConfirmView.swift:327  quote: "Text(chip.span.text)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:91  quote: "<Text className={`flex-1 text-base leading-5 ${getTextStyle()}`}>"
- evidence: S4: the suggestion row "squeezes the suggested title into a narrow column that wraps to 3 lines, because the two text buttons and the 'suggested' tag take most of the row width." The HStack at ConfirmView.swift:326-340 puts the span text, the "suggested" tag and two 44 pt-high buttons in one row; the period row repeats it (ConfirmView.swift:118-131).
- fix: Give the span text the flexible width (fixed buttons, or tag and buttons stacked on a second line) so the user's words get the room; the BoardBound pattern is text = flex-1, chrome = fixed.

FINDING 4
- dimension: 8
- severity: should
- target: Retold/Screens/EpisodeView.swift:19  quote: "OfferSection("
- veteran counterpart: burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:136  quote: "and region breakdown stay above the fold; pedagogy is opt-in."
- evidence: S5: "Five question offers ... push the Recordings section with the player and the transcript entirely below the fold: the user's own voice and words are the last thing on the page," verified by XCUI needing to scroll to find the slider. EpisodeView renders OfferSection (line 19) before Section(AppCopy.recordingsHeader) (line 23).
- fix: Put the Recordings section first, or collapse Questions to a single expandable row, so the recordings and player are above the fold.

FINDING 5
- dimension: 7
- severity: should
- target: Retold/Screens/HomeView.swift:139  quote: "Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? \"\"))"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:83  quote: "{__DEV__ && this.state.error && ("
- evidence: AppCopy.swift:181: "static let startFailedMessage = \"Nothing was recorded. Close Retold and try again. Details: \"" - the raw engine string (CaptureCoordinator.swift:134 "startFailure = engine.lastStartFailure ?? \"unknown\"") is concatenated straight into user-facing copy; this is the run-1 deferred item "raw error text in the start-failure alert."
- fix: Keep the alert to the plain sentence; log the technical detail, or gate it behind a DEBUG-only section the way ErrorBoundary does.

FINDING 6
- dimension: 2
- severity: should
- target: Retold/Playback/AudioPlayback.swift:28  quote: "/// failure (a missing file, a decode failure, a session error) stops quietly: no alert."
- veteran counterpart: BoardBound/components/game/EarnToast.tsx:28  quote: "AccessibilityInfo.announceForAccessibility(announcement);"
- evidence: M5: "playback failures are silent by design." The catch at AudioPlayback.swift:64-66 just calls stop(), so a tap on a corrupt file looks like a dead tap - the exact "no dead taps" failure rubric dimension 1 and "no silent failure" in dimension 2 both prohibit.
- fix: Surface an inline "Could not play this recording" state on the row plus a VoiceOver announcement; non-modal, matching the EarnToast pattern.

FINDING 7
- dimension: 2
- severity: should
- target: Retold/RetoldApp.swift:13  quote: "Text(AppCopy.startupFailed)"
- veteran counterpart: BoardBound/components/ErrorBoundary.tsx:79  quote: "Try Again"
- evidence: A store-open failure renders "Retold could not open its storage. Restart the app to try again." (AppCopy.swift:49) with no action and no retry path - the run-1 deferred item "startup failure has no Retry." The user must force-quit and relaunch manually.
- fix: Add a Retry button below the message that re-runs the service-creation block in the existing .task, clearing startupFailed.

FINDING 8
- dimension: 4
- severity: should
- target: Retold/Screens/ConfirmView.swift:335  quote: "Text(AppCopy.acceptButton).frame(minHeight: 44).contentShape(Rectangle())"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:82  quote: "className={`flex-row items-center rounded-xl border-2 px-4 py-3.5 ${getStyle()}`}"
- evidence: M6: "5 accessibilityLabel/Hint call sites in Retold/; no Dynamic Type, contrast or a11y audit test in CI." S4: "'File it' is a disabled glass capsule, low contrast." House rule 18 check: "Check at AX5"; the SwiftUI column prescribes "@ScaledMetric, scrolling containers." Nothing in the excerpts adapts the confirm form or home rows to larger text sizes.
- fix: Run an AX5 pass over ConfirmView and HomeView (wrap or stack the suggestion rows, let the form scroll), use @ScaledMetric where fixed padding is assumed, and add an AX5 screenshot assertion to the existing harness.

FINDING 9
- dimension: 2
- severity: should
- target: Retold/Screens/HomeView.swift:64  quote: "Section {"
- veteran counterpart: brand/HOUSE-STYLE.md rule 12  quote: "Designed empty, error and missing-data states, each with one action."
- evidence: The run-1 deferral list: "empty Home shows empty sections." HomeView always renders the browse-links Section (lines 64-70) and timeline sections even with an empty library, while the app's own designed pattern exists but is unused here: Retold/Screens/EmptyPage.swift:13 "ContentUnavailableView {".
- fix: When periods and episodes are both empty, show a ContentUnavailableView (a sentence on what will appear plus the Record action) instead of the bare link list.

FINDING 10
- dimension: 6
- severity: should
- target: Retold/Screens/SettingsView.swift:82  quote: "let periods = try modelContext.fetch(FetchDescriptor<Period>())"
- veteran counterpart: BoardBound/components/ui/Skeleton.tsx:29  quote: "className={`rounded-lg bg-gray-200 dark:bg-gray-700 ${className}`}"
- evidence: SettingsView.swift:68-70: "Builds the manifest on the main actor... the fetch stays on the main actor"; runExport then does four full-table fetches (lines 82-85) and builds the manifest on the main actor, detaching only the zip (lines 96-101) - the run-1 deferred item "export fetch on the main actor." On a large library the preparing spinner sits over a blocked thread.
- fix: Fetch lightweight value types (or page by batch) off the main actor and build the manifest there; keep only SwiftData object access isolated.

FINDING 11
- dimension: 1
- severity: polish
- target: Retold/RetoldApp.swift:105  quote: "// Screen swaps fade instead of cutting; Reduce Motion turns the animation off."
- veteran counterpart: BoardBound/components/ui/StaggeredEntrance.tsx:39  quote: "reduceMotion"
- evidence: Every screen swap and list is a single flat opacity fade (RetoldApp.swift:106 ".animation(reduceMotion ? nil : .smooth(duration: 0.25), value: screen)"); BoardBound staggers children per-item (lines 36-39: "FadeInUp.duration(durationMs).delay(initialDelayMs + i * staggerMs)") and renders statically under Reduce Motion.
- fix: Add a small index-staggered entrance to Home and Period episode sections, gated on accessibilityReduceMotion the same way StaggeredEntrance is.

FINDING 12
- dimension: 2
- severity: polish
- target: Retold/Screens/ConfirmView.swift:54  quote: "ProgressView()"
- veteran counterpart: BoardBound/components/ui/Skeleton.tsx:18  quote: "opacity.value = withRepeat("
- evidence: Before the draft loads, the sheet body is a bare spinner with no copy (ConfirmView.swift:53-55), and the transcribing state in lists is a static grey label (HomeView captureRow, EpisodeView transcript). Apple HIG loading (https://developer.apple.com/design/human-interface-guidelines/loading): "Show something as soon as possible... consider showing placeholder text, graphics, or animations."
- fix: Skeleton rows shaped like the form (or at minimum a labeled spinner) while the draft and transcripts load.

FINDING 13
- dimension: 3
- severity: polish
- target: Retold/Screens/ConfirmView.swift:357  quote: ".buttonStyle(.borderless)"
- veteran counterpart: BoardBound/components/question/OptionButton.tsx:82  quote: "rounded-xl border-2 px-4 py-3.5"
- evidence: choiceButton (ConfirmView.swift:349-357) and the OfferRow "Answer now / Not this one" pair (OfferRow.swift:21-32) are borderless text with no 44 pt frame, unlike the trash buttons right beside them, which carry ".frame(minWidth: 44, minHeight: 44)" (ConfirmView.swift:221-222). House rule 4 check: "Every control passes a hit test."
- fix: Apply the same .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) treatment the app already uses for its icon buttons to every small text action.

## Veteran features worth borrowing

1. Press-state spring on buttons - BoardBound/components/question/OptionButton.tsx:69-77 (handlePressIn/handlePressOut withSpring 0.97). Retold: every tap target (Record, Stop, Use this / Not this, Answer now) scales briefly on touch. Effort S.
2. Staggered list entrance - BoardBound/components/ui/StaggeredEntrance.tsx:36-39. Retold: Home and Period episode rows fade up with a ~75 ms stagger on appearance, static under Reduce Motion. Effort S.
3. Skeleton shimmer for loading rows - BoardBound/components/ui/Skeleton.tsx:14-22. Retold: "Transcribing..." rows and the confirm sheet's suggestion wait become shimmering placeholders shaped like content. Effort S.
4. Non-modal toast with a VoiceOver twin - BoardBound/components/game/EarnToast.tsx:24-28, 44-49. Retold: a quiet pill for "Filed" and for play failures (fixing Finding 6), announced to VoiceOver, no alert. Effort M.
5. Branded splash and recoverable error screen with crash capture - BoardBound/components/BrandedSplash.tsx:15-24 and BoardBound/components/ErrorBoundary.tsx:32-37, 72-81. Retold: a brand-mark moment at launch (S1 has none) and a Sentry/MetricKit subscriber (M4 scores 0) behind the retry screen from Finding 7. Effort M/L.

## What the target already does well

Recorder state clarity is the strongest part of the app: distinct "Getting ready..."/"Saving..."/"Paused" labels, a clock that counts recording time only, VoiceOver announcements for each transition, and phase-mapped haptics with Reduce Motion honored. The capture plumbing is equally careful - single-flight start taps, a serial effect queue, no full-swipe delete, 44 pt targets on play/trash, one shared playback object, and a single designed EmptyPage reused on every empty page.
