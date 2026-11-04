# comeup adjudication: Retold, 2026-11-04

Reviewers held: Sonnet [x]  Kimi [x]  Sol [x]. Raw: review-sol.md, review-kimi-final.md (Kimi's stdout transcript in review-kimi.md). Sonnet's report was returned in-session only; its score table and finding list are folded in below.
Bar named by Perry: motion and transitions, haptics, state clarity, visual polish (Wilderness Survival).
Packet gaps (all three said so): no coordinator, no AppCopy, no HOUSE-STYLE text excerpts landed in the reviewers' hands as numbered rules, no fetched Apple docs. Apple claims below are marked "to fetch" before implementing.

Scores (S / K / O=Sol): motion 1/2/1, state 2/3/2, input 2/3/2, a11y 2/2/2, visual 1/2/2, perf 2/2/2, copy 2/3/2, layout 2/3/2. Mean before: motion 1.3, state 2.3, input 2.3, a11y 2.0, visual 1.7, perf 2.0, copy 2.3, layout 2.3.

| ID | Dim | Finding (merged) | Said by | Verified in code | Verdict | PR |
|---|---|---|---|---|---|---|
| C1 | 2 | Recorder clock is wall time since view appeared; keeps counting while interrupted, starting, stopping (RecorderView.swift:11,40,92) | S(blocker) O | yes | accepted | P1 |
| C2 | 2 | .starting shows "recording" with live clock and enabled Stop (RecorderView.swift:61-74) | S O | yes | accepted | P1 |
| C3 | 3 | FirstRun denied is a dead end: no Open Settings, no recheck on return; button has no in-flight guard (FirstRunView.swift:20-30) | S (O: guard only) | yes | accepted | P1 |
| C4 | 2 | PeriodEditSheet.save() swallows save failure, no alert (PeriodsView.swift:116-118) | S K O | yes (comment is the quote) | accepted | P1 |
| C5 | 2 | ConfirmView shows Color.clear before draft loads (ConfirmView.swift:54) | S K | yes | accepted | P1 |
| C6 | 3 | Record/answerNow double-tap cancels the capture | S K | NO: CaptureCoordinator.startCapture has startInFlight single-flight (CaptureCoordinator.swift:325), merged in PR #20. Reviewers lacked the coordinator. | rejected (already fixed) | - |
| C7 | 1 | No haptics anywhere (grep confirms no sensoryFeedback / feedback generator) | S K O | yes | accepted; fetch Apple doc on AVAudioSession haptics-during-recording before wiring the start haptic | P2 |
| C8 | 1 | No transitions between Home/Recorder/Confirm, no Reduce Motion handling (grep: no accessibilityReduceMotion) | S K | yes | accepted | P2 |
| C9 | 4 | Slider (EpisodeView.swift:83) has no label/value | S O | yes | accepted | P3 |
| C10 | 4 | Hit targets <44 pt: PlayPauseButton, trash buttons, accept/reject; rows break at large Dynamic Type | S O(layout) K | partly (verify sizes in CI screenshots) | accepted as should | P3 |
| C11 | 4 | No VoiceOver announcements for pause/saving/length warning; icon-only buttons unlabeled (gear, trash) | S K | yes | accepted | P3 |
| C12 | 5 | Recorder uses .red and .yellow one-offs; errors styled as gray footnotes; no tokens | S K O | yes | DEFERRED to the 1.1 interface-elevation brief (needs HOUSE-STYLE rules and Sol-reviewed design) | IDEAS |
| C13 | 6 | Settings export builds manifest on main actor | O K | yes (file's own comment) | accepted | P4 |
| C14 | 6 | Per-row sort in EpisodeRow/EpisodeView, dictionaries rebuilt per body in HomeView (uniqueKeysWithValues trap) | S O K | yes | accepted (min(by:), uniquingKeysWith) | P4 |
| C15 | 7 | HomeView hardcoded "OK"; raw startFailure appended to alert; "-" picker tag | S K O | yes | accepted | P1 (copy) |
| C16 | 2 | HomeView attach errors discarded with try? | O | partial; behavior may be deliberate | deferred, needs Perry-visible decision | IDEAS |
| C17 | 2 | Startup-failure state has no Retry | S | yes | deferred | IDEAS |
| C18 | 2 | Home with no episodes shows empty sections not an EmptyPage | K | not checked | deferred pending screenshot | IDEAS |

Notes: Sonnet FINDING 13 crash claim (uniqueKeysWithValues on duplicate id) is real Swift behavior but unlikely given unique UUIDs; kept as polish inside C14.
Process note: all three seats made the same C6 error because the packet omitted CaptureCoordinator. Next run's packet must include the coordinator's public entry points.

Release constraint: build 14.1 is attached to the 1.0 version awaiting submission. P1-P4 land on main as PRs but do NOT go to a build until Perry decides what ships in 1.0 vs 1.1.

PR plan: P1 state clarity + copy (C1-C5, C15), P2 motion + haptics (C7, C8), P3 accessibility (C9-C11), P4 performance (C13, C14).
