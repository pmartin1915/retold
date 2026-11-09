# comeup scorecard: Retold, 2026-11-09 (run 2)

| Dimension | Before | After | Notes |
|---|---|---|---|
| 1 Motion and fluidity | 2.0 | 3 | The recording dot pulses, custom rows spring to 0.97 on press, and confirm-draft changes animate. All three are gated on Reduce Motion. Haptics and spring feel still need a device check. |
| 2 State clarity | 1.7 | 3 | File it failure shows an alert and an error haptic. Startup failure shows Try again, which recovers. Playback failure is shown, felt and spoken once. Filing shows a "Filed: <title>" pill. Empty Home is a designed state. A branded launch view replaces the bare spinner. |
| 3 Input robustness | 3.0 | 3 | Unchanged. The single-flight Record and the Saving state from PR #20 hold. |
| 4 Accessibility | 2.0 | 3 | An AX XXXL harness covers Home and Confirm. "Use this: <text>" labels now name their object. Offer and choice buttons are 44 pt. The player stacks at accessibility sizes. The story title is a header. |
| 5 Visual system | 1.0 | 2 | Terracotta AccentColor and OnAccent tokens, one full-width primary action in thumb reach (Record, Stop/Resume) and a launch mark. Still not 3: the recorder screen is mostly empty, and transcript lines wrap centred under their timestamps (see the IDEAS note). |
| 6 Performance | 1.7 | 2 | The 4 Hz playback tick now redraws one PlayerRow, not the whole story page. Export still runs on the main actor (C18), and there are no launch or hitch numbers (M7). |
| 7 Copy | 2.3 | 2 | New strings are plain and specific (startup, playback, empty Home, Filed). The start-failure alert still shows raw error detail (C17, deferred on purpose). |
| 8 Layout resilience | 2.0 | 3 | Stories come before browse links, recordings before questions (now one "Questions (n)" row), confirm rows give the words full width, and the story title is inline. No truncation shows in the 6.5"/6.9" or AX checks. |

Before is the mean of the three seats' scores (S 2/2/3/2/1/2/2/2, K 2/2/3/2/1/2/3/2, O 2/1/3/2/1/1/2/2), after Opus verification.
After is the re-score post-merge, from the screenshots.yml artifacts of the run on #31 (asc-screenshots-6.5/6.9 and ui-checks-6.5/6.9) and the FlowTests assertions.

**Shipped** (all merged to main 2026-11-09, CI green on each merged head):
- #26 `56e858a`: UI assertions in the screenshot flow. Supersedes #25.
- #27 `a0eedab`: P1 state clarity.
- #28 `580bf0c`: P2 visual system and primary actions. It landed through #29's merge commit. #28's own screenshot run failed because the story row sat under the browse links. #29 fixed that, and #29's CI is green.
- #29 `1b54449`: P3 layout and hierarchy.
- #30 `f703715`: P4 playback.
- #31 `f031408`: P5, Perry's veteran picks V1, V2, V3 and V5.

**Rejected:** none. Kimi F1 had a mis-citation, but the finding is valid and S and O cite it correctly.

**Deferred** (also in ai/IDEAS.md):
- C17 raw error detail
- C18 export off the main actor
- C23 crash reporting
- V4 skeletons and V6 staggered entrance (not picked)
- M7 launch/hitch metrics
- A device check of haptics, springs and the launch view

**Harness.** Each change is exercised in CI on 6.5" and 6.9" simulators, by `RetoldUITests/ScreenshotTests` (`-RetoldDemo`) and `RetoldUITests/FlowTests`:

| Area | Test |
|---|---|
| Startup failure, then Try again | FlowTests.testStartupFailureTryAgainRecovers (`-RetoldFailFirstStart`) |
| AX XXXL Home and Confirm | FlowTests.testAccessibilityTextSizeHomeAndConfirm |
| Playback failure (demo audio does not decode) and story order | FlowTests.testPlaybackFailureIsVisible |
| Questions fold and open | FlowTests.testStoryQuestionsFoldIntoOneRow |
| Filed pill after File it | FlowTests.testFilingShowsFiledPill |
| Scrubber after scrolling, five store screens | ScreenshotTests.testCaptureAppStoreScreenshots |

Each check attaches a `check-*` screenshot, published as the `ui-checks-*` artifact.

**Open:** PR #25 is still open. It is superseded by #26, but closing it was refused by the auto-mode permission check, so it needs Perry's close.

**Next:** a device sitting on a 1.1 TestFlight build covers what simulators cannot show: haptics, spring feel and the launch view. Then comes the 1.1 interface-elevation brief (ai/IDEAS.md 2026-11-03), starting with the recorder screen's empty space and the centred transcript wrap.
