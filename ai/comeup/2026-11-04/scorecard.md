# comeup scorecard: Retold, 2026-11-04

Before = mean of Sonnet, Kimi, Sol scores. After = Opus estimate from the merged diffs only; NOT yet re-scored from screenshots or a device (CI cannot feel haptics, hear VoiceOver or show the fade). Treat "after" as provisional until a TestFlight pass.

| Dimension | Before | After (est.) | Notes |
|---|---|---|---|
| 1 Motion and fluidity | 1.3 | 2.5 | Screen fades (off under Reduce Motion), recorder + playback haptics, haptics unmuted during recording |
| 2 State clarity | 2.3 | 3.0 | Clock counts recording time only, Getting ready state, save-failure alert, no blank confirm sheet |
| 3 Input robustness | 2.3 | 2.8 | Mic-denied recovery (Open Settings, recheck on return), single-flight permission request |
| 4 Accessibility | 2.0 | 2.8 | Scrubber label + value, labelled gear and trash, 44 pt targets, VoiceOver announcements |
| 5 Visual system | 1.7 | 1.7 | Deferred to the 1.1 interface-elevation brief |
| 6 Performance | 2.0 | 2.3 | Dictionary trap removed, single-pass first capture; export fetch still on main actor |
| 7 Copy | 2.3 | 2.4 | Hardcoded OK removed; raw error string in start-failure alert not fixed |
| 8 Layout resilience | 2.3 | 2.4 | Larger hit targets only; Dynamic Type row layout not addressed |

Shipped to main (not in any build): PR #21 state clarity, #22 motion + haptics, #23 accessibility, #24 performance. All CI green; reviewer agent on each (P3 had two real defects, fixed before merge).
Rejected: C6 (double-tap Record; already single-flight in CaptureCoordinator.startCapture).
Deferred (also in ai/IDEAS.md): C12 colour tokens/error styling, C16 discarded attach errors, C17 startup retry, C18 empty Home, export fetch off main actor, Dynamic Type row layout, raw error text in start-failure alert.
Harness: CI Build & XCTest only. Gap: no UI-test or screenshot step was added for the changed screens (recorder starting state, FirstRun denied, fades); next run should add them to RetoldUITests / screenshots.yml before claiming "after" scores.
Process lesson: all three reviewers made the same false finding (C6) because the packet omitted CaptureCoordinator; include coordinator entry points next time.
Next: put these four PRs on a device build (Perry's call, after 1.0 review), then re-score.
