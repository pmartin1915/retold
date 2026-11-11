# comeup adjudication: Retold, 2026-11-10 (run 3)

Perry, 2026-11-10: "it does not look professional or feel smooth yet."
Reviewers held: Sonnet [x] (screenshots + code)  Kimi [x] (code only; the kimi CLI cannot take images)  Sol [x] (screenshots + code, codex exec -i, account pmartin1913).
Raw: review-sonnet.md, review-kimi.md, review-sol.md. Packet: packet.md (neutral: no Opus screenshot notes, unlike run 2). Screenshots: shots/ (CI run 42689909268, 6.9", current main).

Scores (S / K / O): motion 2/2/2, state 3/3/3, input 3/3/2, a11y 3/3/2, visual 2/3/2, perf 1/1/1, copy 3/3/3, layout 3/2/2.
Mean before: motion 2.0, state 3.0, input 2.7, a11y 2.7, visual 2.3, perf 1.0, copy 3.0, layout 2.3.

| ID | Dim | Finding (merged) | Said by | Verified in code? | Verdict | PR |
|---|---|---|---|---|---|---|
| C1 | 6/1 | Live text: every volatile result rebuilds the whole joined string on the main actor and redraws all of RecorderView (timer included); the ScrollView has no bottom anchor, so new words fall below the fold; finals and the tentative tail look the same; the empty state is blank | S(blocker) K(blocker) O | yes: CaptureCoordinator.swift:139,240-243; RecorderView.swift:65-70 | accepted. Child view reads the live text; `.defaultScrollAnchor(.bottom)`; finals primary, volatile tail secondary; placeholder line while empty. No throttling (it could hide words), no engine change | A |
| C2 | 1/6 | Home sections keyed by array offset (`id: \.offset`) | O S | yes HomeView.swift:65 | accepted: key by period id, fixed id for "no period" | B |
| C3 | 6 | `canPlay` stats the file system per row per body pass | S K | yes AudioPlayback.swift:32, HomeView.swift:334 | deferred: cheap stat, no measured cost; fold into M7 metrics | IDEAS |
| C4 | 2 | An accepted suggestion looks the same as an unaccepted one (both buttons stay) | O | yes ConfirmView.swift:333 passes only isSuggested | accepted: accepted state shows a filled "Using this" with Not this still available | C |
| C5 | 4/8 | Use this / Not this buttons are 32 pt high and always side by side | K (32 pt) O (AX layout) | yes ConfirmView.swift:360,370 | accepted: 44 pt; ViewThatFits vertical at large sizes | C |
| C6 | 1 | Confirm sheet: bare spinner, then the whole form pops in unanimated | S O (K as feature) | yes ConfirmView.swift:49-62, 541 | accepted: fade the form in (Reduce Motion: opacity). Rendering the form before suggestions finish (Sol) deferred: it changes the R7a draft contract | C |
| C7 | 1 | Filed pill and success haptic fire under the still-closing sheet | S | yes HomeView.swift:130 (onFiled) vs 134 overlay; ConfirmView.swift:549-553 | accepted: set the pill from the sheet's onDismiss | C |
| C8 | 8/5 | File it is a faint top-right toolbar pill, far from the "Add a title" hint | S | yes ConfirmView.swift:68-72, 122-126 | accepted: File it moves to the bottom primary bar with the hint above it (rule 11) | C |
| C9 | 5 | Story transcript: whole text in accent tint, wrapped lines centred, timestamps ragged | S (Opus noted the centring in run 2) | yes EpisodeView.swift:105-111. The segments ARE tap-to-seek buttons, so the accent is allowed; the fix is hierarchy | accepted: accent monospaced timestamp, primary leading-aligned words, press state | B |
| C10 | 5/7 | Place and people fact rows have no label or icon; the quote row is unstyled | S | yes EpisodeView.swift:63-74 | accepted: Label with mappin / person symbols; quote in secondary italic | B |
| C11 | 8 | Story title shown twice (inline nav title + in-list header) | S | yes EpisodeView.swift:16,42 | accepted: empty nav title, the wrapping header stays; ScreenshotTests:43 switches to the header text | B |
| C12 | 8 | Fold secondary facts behind a disclosure | O | yes | rejected for this pass: C10 makes the rows legible; six short rows is not the problem the screenshot shows | - |
| C13 | 8 | Person page puts open questions above the person's stories | O | yes PeopleView.swift:32-38 | accepted: stories first, questions folded into one counted row (same as the story page, Perry's V5 in run 2) | B |
| C14 | 5/1 | No Motion tokens; spacing literals (4, 12, 16); `.yellow.opacity(0.3)` and `.tint(.gray)` one-offs | S K O | yes DesignTokens.swift:60, HomeView.swift:147, ConfirmView.swift:52,373,441, RecorderView.swift:53,75 | accepted: Motion + xs/m spacing + warning tokens (StoryCue values). Press spring VALUE kept (Perry picked it in run 2), only tokenized | B |
| C15 | 4/5 | Recording dot is system red and fades to pale pink in the pulse trough | S | yes DesignTokens.swift:17, RecorderView.swift:57; 02-recorder shows it | accepted: StoryCue's darker recording red; a scale "breathe" instead of an opacity pulse | A |
| C16 | 5 | Primary bar is an opaque `.bar` strip with a hard edge (rule 6) | S | yes DesignTokens.swift:40; 01-home cuts a card mid-row | accepted: iOS 26 `safeAreaBar` (system scroll-edge effect), no fake bar | B |
| C17 | 5/8 | Period rows give no hint of what is inside; wide gaps between sections | S | yes HomeView.swift:70; 01-home | accepted: "2 stories" / "No stories yet" subtitle, compact section spacing | B |
| C18 | 1 | Recorder status line and length banner swap with no animation | S | yes RecorderView.swift:71-76,119-142 | accepted (opacity transitions through Motion tokens) | A |
| C19 | 8 | Recorder at accessibility sizes: the live text loses its space | K | yes RecorderView.swift:52-70 | accepted: layoutPriority on the live text | A |
| C20 | 1 | Borderless custom buttons have no press state | K | yes ConfirmView.swift:398, OfferRow.swift:37, EpisodeView.swift:110 | accepted: `.pressable` | B/C |
| C21 | 6 | Seed + attach run in Home onAppear after every recording | K | yes HomeView.swift:190-192 | deferred: the comment there makes the order load-bearing (auto-present); not worth the risk without a measured hitch | IDEAS |
| C22 | 4 | Year wheel's empty row reads "--" | K | yes ConfirmView.swift:171 | accepted: AppCopy.notSure | C |
| C23 | 7 | Start-failure alert appends raw error detail | S K O | yes | still deferred (run 2 C17 reason: it is the only device diagnostic until crash reporting exists) | IDEAS |
| C24 | 7 | Mixed "--" vs em dash, "..." vs ellipsis | S | yes AppCopy.swift:66 | accepted (copy only) | C |
| O-1 | 5 | Confirm: the recording's transcript excerpt sits first under the "Title" header, so it reads as the title | Opus (03-confirm) | yes ConfirmView.swift:102-110 | accepted: own "What you said" section, secondary, 4-line limit; words unchanged (Rule 1) | C |

No fabricated quotes found; Kimi's line numbers were off by one in two places (240 vs 241), content correct.

## Veteran / sibling features to borrow (merged; Perry picks)
- F1 Serif for the user's own words (StoryCue DesignTokens.swift:27 `.serif`): story titles, transcript, live text. S, O. Effort S.
- F2 Record control that reads as recording: StoryCue's record ring (DesignTokens.swift:19-25) or its recording capsule (RecorderView.swift:292). S, O, K. Effort M.
- F3 Placeholder rows instead of the confirm spinner (BoardBound Skeleton.tsx). S, O, K. Effort S.
- F4 Confirm "More details" fold so File it sits near the fold (burn-wizard TrainerFeedback.tsx:134). S. Effort M.
- Not offered again: staggered entrance (Perry did not pick it in run 2). Crash reporting is a vendor + privacy decision, kept in IDEAS.

## PR plan
A recorder (C1, C15, C18, C19) - B home + story + tokens + harness (C2, C9-C11, C13, C14, C16, C17, C20, dark-mode capture) - C confirm (C4-C8, C20, C22, C24, O-1) - D Perry's picks.

## Perry's answers (AskUserQuestion, 2026-11-10)
- Features: all four (F1 serif, F2 recording ring/capsule, F3 placeholder rows, F4 "More details" fold).
- Transcription: screen side only; accuracy stays its own lane.
- Merging: Claude merges each PR once CI is green and the reviewer agent is clean.
- TestFlight: yes, a TestFlight build after the merges; no App Store submission (1.0 stays parked).
