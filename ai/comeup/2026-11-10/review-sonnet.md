RETOLD COMEUP RUN 3 - QA REVIEW (Sonnet reviewer)

I received the five screenshots (01-home, 02-recorder, 03-confirm, 04-story, 05-browse) and cite them by name. Everything below comes from the packet and the images only. No audio engine changes are proposed, and Rule 1 is untouched.

SCORE TABLE (0 broken, 2 acceptable, 4 matches the veteran bar)

| # | Dimension | Score | One-line reason |
|---|---|---|---|
| 1 | Motion and fluidity | 2 | Press springs, Reduce Motion and haptics exist. State swaps, the confirm sheet and the filing moment still pop or collide (F3, F4, F14). |
| 2 | State clarity | 3 | starting/saving/paused statuses, disabled Stop, empty states and failure alerts are in place. The live-text area has no empty state (F1). |
| 3 | Input and recording robustness | 3 | Phase machine, mic-blocked alert and single-flight start are visible. Not enough of the packet to score kill/low-storage paths. |
| 4 | Accessibility | 3 | Labels, 44 pt frames and announcements are solid. The dot trough contrast is weak (F13). |
| 5 | Visual system | 2 | Stock grouped lists with a terracotta tint. Motion values and one-offs sit outside the tokens (F12). Several screens look unfinished (F6-F9, F11). |
| 6 | Performance | 1 | Live text re-joins and re-lays out the whole transcript per update. Cold launch and hitches are UNMEASURED (M7). |
| 7 | Copy | 3 | Plain and specific. Typographic inconsistencies only (F15). |
| 8 | Layout resilience | 3 | Safe-area bar and the PlayerRow Dynamic Type branch are good. Top-right File it, unlabeled fact rows and the duplicate title are weak. |
| 9 | Android parity | N/A | iOS only. |

FINDINGS (blocker -> polish)

FINDING 1
- dimension: 6 (also 1)
- severity: blocker
- target: Retold/Screens/RecorderView.swift:66  quote: "Text(coordinator.liveText)"
- veteran counterpart: none in packet
- evidence: The text sits in a bare `ScrollView {` (line 65). The whole of RecorderView.swift (lines 1-184) contains no ScrollViewReader, scroll anchor or position binding. Words are appended at the end of the string, so once the text passes the screen height the newest words fall below the fold and the user has to scroll by hand. On the weighted live-text path this reads as "dropped speech". Screenshot 02 shows two lines floating at the top of a roughly 80% blank screen, so the empty and growing states are both undesigned. `liveText` is reset to "" at CaptureCoordinator.swift:226 with no placeholder shown.
- fix: Keep the live view pinned to the tail with `.defaultScrollAnchor(.bottom)` on the ScrollView. Show a secondary placeholder line while `liveText.isEmpty` (for example "Start talking when you are ready") so a silent mic does not look broken.

FINDING 2
- dimension: 6
- severity: should
- target: Retold/Capture/CaptureCoordinator.swift:241  quote: "let joined = journaledFinalTexts.joined(separator: \" \")"
- veteran counterpart: Retold/Screens/EpisodeView.swift:116 (in-app precedent; no veteran file in packet)  quote: "Only this view reads `currentTime`, so the"
- evidence: `rebuildLiveText()` runs on every volatile event (line 139) and every final (line 190). Each call rebuilds the full joined string, up to a 30-minute capture (line 16 shows 30 * 60 for the limit). `RecorderView` reads `coordinator.liveText` directly in its body (line 66), so each update invalidates the whole body, TimelineView included, and re-lays out one very long Text. The cost is unmeasured (M7), but this is the only per-token work on the main actor that grows with recording length. It is the likeliest contributor to Perry's "lagged" report.
- fix: Keep finals as an array and show only the last few segments, or the last N lines, in the live view. The full transcript is already journaled, so no words are rewritten. Move the live view into its own child struct that alone reads `liveText`, as PlayerRow does. Style finals as primary text and the volatile tail as `.secondary`, so tentative words read as tentative. The two are merged into one string at lines 241-243 and the distinction is lost.

FINDING 3
- dimension: 1
- severity: should
- target: Retold/Screens/ConfirmView.swift:541  quote: "draft = built"
- veteran counterpart: BoardBound/components/ui/StaggeredEntrance.tsx:39  quote: "FadeInUp.duration(durationMs).delay(initialDelayMs + i * staggerMs)"; also BoardBound/components/ui/Skeleton.tsx:15  quote: "const opacity = useSharedValue(0.3);"
- evidence: The sheet body switches on `if let current = draft {` (line 49), with a bare `ProgressView()` otherwise (line 61). `draft` is assigned with no animation, so the seven-section Form pops in over a spinner. In the immediate paths (`buildDraft(outcome: nil)`) the first frame is still a spinner flash. Apple, https://developer.apple.com/design/human-interface-guidelines/loading (packet line 3410): "Show something as soon as possible." Screenshot 03 is the end state of this pop-in.
- fix: Build the draft for the no-model paths synchronously before the first frame. For the suggestion wait, replace the centered spinner with placeholder Title/Period rows (`.redacted(reason: .placeholder)` with a short opacity pulse). Wrap the final assignment in the same motion token as the rest of the app (see F12), with a plain opacity transition under Reduce Motion.

FINDING 4
- dimension: 1
- severity: should
- target: Retold/Screens/HomeView.swift:130  quote: "filedTitle = title"
- veteran counterpart: BoardBound/components/game/EarnToast.tsx:38  quote: "entering={reduceMotion ? undefined : FadeInDown.duration(200)}"
- evidence: `onFiled` fires first (ConfirmView.swift:549-550), then `dismiss()` (ConfirmView.swift:553). The pill is an `.overlay(alignment: .top)` on HomeView (line 134), which sits under the presented sheet. The 0.3 s slide-in (line 147) and the success haptic (line 148) therefore run while the sheet is still covering it. The pill is partly or wholly hidden for the first part of its 2.5 s life, and the haptic arrives before anything is visible. The filed row also leaves Unfiled and appears in a period with no animation on the Query-driven List.
- fix: Store the title in a pending variable and set `filedTitle` from `.sheet(item:onDismiss:)`, so the pill, haptic and row move start after the sheet has settled. Optionally add `.animation(.smooth, value: unfiledCaptures.count)` on the List, guarded by Reduce Motion, so the row leaves visibly.

FINDING 5
- dimension: 8 (also 5)
- severity: should
- target: Retold/Screens/ConfirmView.swift:72  quote: ".disabled(!(draft?.canFile ?? false))"
- veteran counterpart: Retold/Design/DesignTokens.swift:32 (in-app, used on Home and Recorder)  quote: "func primaryActionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {"
- evidence: House style rule 11 (packet line 3285): "One clear primary action per screen, in thumb reach". The confirm sheet is the one screen where the primary action (File it, toolbar `.confirmationAction`, line 68) sits at the top while the form runs seven sections long. Screenshot 03: File it is a faint grey pill at top right while disabled, almost invisible. The reason it is disabled ("Add a title to file this memory.", ConfirmView.swift:123) sits mid-form, away from the button.
- fix: Move File it into `.primaryActionBar` (full width, borderedProminent, disabled state with the hint text directly above it). Keep Cancel as the toolbar cancellation item.

FINDING 6
- dimension: 5 (also 8)
- severity: should
- target: Retold/Screens/EpisodeView.swift:107  quote: "Text(\"\\(ExportManifest.formatClock(segment.start))  \\(segment.text)\")"
- veteran counterpart: none in packet
- evidence: Screenshot 04: the transcript is the product, and it renders as terracotta paragraphs where the wrapped second lines are centered, not leading. This is the default Button label alignment. Line 108 sets only `.frame(maxWidth: .infinity, alignment: .leading)`, with no `multilineTextAlignment`. Timestamps are plain proportional text, so "0:15" and "0:00" start the sentence at different x positions. The entire story is set in link color (borderless button tint), against rule 2 "Use it only on tappable or wayfinding items".
- fix: Lay each segment out as `HStack(alignment: .firstTextBaseline)` with a fixed-width `Text(clock).monospacedDigit().foregroundStyle(.secondary)` and a primary-color, `.multilineTextAlignment(.leading)` body Text. Use `.buttonStyle(.pressable)` so the row gets a press state. Optionally tint only the active segment.

FINDING 7
- dimension: 5 (also 7)
- severity: should
- target: Retold/Screens/EpisodeView.swift:66  quote: "NavigationLink(ref.name, destination: PlaceView(place: place))"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:34  quote: "case \"grandparents\": \"house\""
- evidence: Screenshot 04: Period and When rows have labels (line 60, `LabeledContent(AppCopy.periodHeader, value: period.title)`). The place, the two people and the quoted detail ("the porch door banged every time") are bare lines with chevrons. A reader cannot tell "the lake house" is a place or "Aunt Ruth" a person without tapping. Rule 7 asks for SF Symbols; here there are none.
- fix: Give place and person rows a `Label(name, systemImage: "mappin.and.ellipse")` or `"person"`. Set the detail quotes in `.secondary` italic under a short heading, or give them a quote glyph, so the facts card reads as labeled facts.

FINDING 8
- dimension: 8 (also 5)
- severity: should
- target: Retold/Screens/EpisodeView.swift:42  quote: ".navigationTitle(facts.title ?? AppCopy.untitled)"
- veteran counterpart: none in packet
- evidence: Line 43 forces `.inline`, and the same title is the first row in the list (line 16, `Text(facts.title ?? AppCopy.untitled)`). Screenshot 04 shows "Summers at the lake house" twice within 250 px. Screenshot 05 (PeopleView:18 `.navigationTitle(AppCopy.peopleHeader)`) uses a large title. The two pushed pages have two different title styles.
- fix: Leave the inline nav title empty on the story page, since the in-list title already wraps in full (the stated reason at line 14), or drop the in-list title and use a large title. Pick one pattern for all pushed detail pages.

FINDING 9
- dimension: 5 (also 8)
- severity: should
- target: Retold/Screens/HomeView.swift:70  quote: "Text(ref.title)"
- veteran counterpart: none in packet
- evidence: Screenshot 01: every seeded period is a full-width card with the same weight, so an empty "Middle school / junior high" is a lone chevron card. The roughly 35 pt gaps between cards, plus the period list ahead of Browse (line 86), push Browse off the first screen. The Record bar clips "High school" mid-row. The header row is `.font(.headline)` only (line 71), with no count or "No stories yet" cue.
- fix: Add a secondary subtitle to each period row ("2 stories" or "No stories yet"). Tighten with `.listSectionSpacing(.compact)` so more periods fit above the bar.

FINDING 10
- dimension: 6 (also 1)
- severity: polish
- target: Retold/Screens/HomeView.swift:65  quote: "ForEach(Array(sections.enumerated()), id: \\.offset) { _, section in"
- veteran counterpart: Retold/Screens/EpisodeView.swift:116 (in-app)  quote: "Only this view reads `currentTime`, so the"
- evidence: Row identity is the array offset, so inserting or reordering a period re-identifies every later section (no move animation, lost row state). `periodsByID` is rebuilt in body (line 39, `let periodsByID = Dictionary(periods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })`). `canPlay` runs a `FileManager.default.fileExists` stat for each visible row on every body pass (AudioPlayback.swift:33, called from HomeView.swift:334 `.disabled(!playback.canPlay(captureID))`). M7 says none of this is measured.
- fix: Key sections by `section.period?.id` (with a fixed id for the no-period section). Cache the dictionaries and the per-row `canPlay` result outside the hot body, updated in `.onChange` or `.task`. Add an XCTHitchMetric scroll test so the claim can be settled.

FINDING 11
- dimension: 5
- severity: polish
- target: Retold/Design/DesignTokens.swift:40  quote: ".background(.bar)"
- veteran counterpart: none in packet
- evidence: Rule 6 (packet line 3280): "No opaque fake bars." Screenshot 01: a flat band with a hard top edge cuts the "High school" card mid-row. Screenshot 02: the band is a slightly different grey from the white page, a visible seam. In an iOS 26 SDK app the bottom edge is meant to blend with content (the screenshots are simulator CI, so confirm on device).
- fix: Try removing the explicit background so the system edge treatment applies, or use a floating prominent button without a full-width strip. Compare on device with Reduce Transparency and Increase Contrast on, per the rule 6 check.

FINDING 12
- dimension: 5 (also 1)
- severity: should
- target: Retold/Design/DesignTokens.swift:60  quote: ".animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3), value: configuration.isPressed)"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:16  quote: "static let morph = Animation.spring(duration: 0.3)"
- evidence: Rule 8 check (packet line 3282): "Motion values come only from the tokens file." Retold has no Motion enum. The values are scattered literals: `.smooth(duration: 0.25)` (ConfirmView.swift:441), `.smooth(duration: 0.3)` (HomeView.swift:147), and the bouncy press spring above. Other one-offs: `.tint(.gray)` (ConfirmView.swift:373), `.yellow.opacity(0.3)` (RecorderView.swift:75), `HStack(spacing: 12)` (RecorderView.swift:53). Apple Motion (packet line 3376): "In apps, generally avoid adding motion to UI interactions that occur frequently." A 0.3 bounce on every list-row tap is the bounciest motion in a calm app. BoardBound's equivalent is `{ damping: 15, stiffness: 300 }` (OptionButton.tsx:71).
- fix: Add `DesignTokens.Motion` (morph, fade, press) and route all animations through it. Set press `bounce` to about 0. Replace `.gray` and `.yellow` with neutral or accent tokens.

FINDING 13
- dimension: 4 (also 5)
- severity: polish
- target: Retold/Screens/RecorderView.swift:57  quote: ".symbolEffect(.pulse, options: .repeating, isActive: isRecording && !reduceMotion)"
- veteran counterpart: storycue/StoryCue/DesignTokens.swift:45  quote: "static let recordingFill = Color(red: 0.78, green: 0.10, blue: 0.10)"
- evidence: Screenshot 02 shows the dot as pale pink, caught in the pulse trough. Rule 3 (packet line 3277) asks for "3:1 for large text and controls". StoryCue deliberately darkened its red (line 44: "darker than system red so white text clears 4.5:1"). Retold keeps `static let recordingDot = Color.red` (DesignTokens.swift:17). The Stop button is also the same terracotta fill as Record (screenshots 01 and 02).
- fix: Use a darker red token, and pulse scale or a minimum opacity of about 0.7 rather than a full fade. Consider a distinct Stop treatment (red or dark fill) so state is not carried by the dot alone.

FINDING 14
- dimension: 1
- severity: polish
- target: Retold/Screens/RecorderView.swift:71  quote: "if coordinator.lengthWarning {"
- veteran counterpart: BoardBound/components/game/EarnToast.tsx:39  quote: "exiting={reduceMotion ? undefined : FadeOut.duration(200)}"
- evidence: The status line swaps between a Text and an HStack with a ProgressView (lines 119-142) and the warning inserts a banner into the VStack (lines 71-76), both with no animation. The text area is `.frame(maxHeight: .infinity)`, so it resizes abruptly. The Stop button is `.disabled(isStopping || isStarting)` (line 99) but keeps the same label with no in-button progress.
- fix: Give the status line a fixed min height and animate phase changes with the motion token (opacity only under Reduce Motion). Animate the warning with `.transition(.opacity)`.

FINDING 15
- dimension: 7
- severity: polish
- target: Retold/Copy/AppCopy.swift:66  quote: "static let noTranscriptLabel = \"No transcript -- you can still file it\""
- veteran counterpart: Retold/Copy/AppCopy.swift:14 (in-app)  quote: "who was around \\u{2014} then talk."
- evidence: Typographic style is mixed. `--` is used where line 14 uses a real em dash, and "Getting ready..." / "Saving..." use three periods (lines 35, 37). Screenshot 03: the engine-made "You said 'the summer I turned nine'" uses straight quotes. `startFailedMessage` (line 187) ends with raw technical detail that HomeView shows via `coordinator.startFailure ?? ""` (HomeView.swift:174).
- fix: Use one em dash, a real ellipsis character and curly quotes everywhere. Show a short human line first; keep the technical detail secondary (for example in a "Details" disclosure).

VETERAN OR SIBLING FEATURES WORTH BORROWING

1. Record ring that morphs to Stop (StoryCue/StoryCue/DesignTokens.swift:19-25 `enum RecordButton {` plus Motion at :15-18). One persistent bottom ring on Home and Recorder (dot to rounded square, 0.3 s spring) replaces two full-width terracotta bars. Rule 11 (packet line 3285) already allows "A custom control such as a record ring can be that action." Effort M.
2. Serif for the user's own words (StoryCue/StoryCue/DesignTokens.swift:27 `static let questionFontDesign: Font.Design = .serif`). Story title, live text and transcript set in `.fontDesign(.serif)` make the memories feel like writing, not a settings list. Effort S.
3. Placeholder skeleton while waiting (BoardBound/components/ui/Skeleton.tsx:14-36, a pulse 0.3 to 0.7 over 800 ms). The confirm sheet shows redacted Title and Period rows while suggestions generate, in place of the centered spinner. Effort S.
4. Staggered fade-in-up reveal (BoardBound/components/ui/StaggeredEntrance.tsx:20-47, Reduce Motion aware). The story page sections (facts, recordings, questions) ease in with a 75 ms stagger on first push. Effort S to M.
5. Density grouping (burn-wizard/app/src/components/trainer/TrainerFeedback.tsx:134-136, "Group educational content ... into a single tab block to reduce feedback-screen density"). The confirm form keeps Title, Period and When on top and folds People, Place and Questions for later into one "More details" disclosure, so File it sits near the fold. Effort M.

WHAT THE APP ALREADY DOES WELL
- Disciplined fundamentals: one primary action per screen via a single `primaryActionBar`, a Reduce Motion guard on every animation, haptics paired with visible state changes, and VoiceOver announcements for pause, saving, filing and playback failure.
- Careful state design and hot-path isolation: distinct starting, recording, paused and saving states; single-flight and disabled controls; a designed empty page; and a PlayerRow that isolates the 4 Hz tick so the story page does not redraw.
