# Handoff 2026-11-09 -- comeup run 2 merged (Retold 1.1 UI pass)

<!-- READ-FIRST:START -->
**State:** comeup run 2 is done. PRs #26-#31 are merged to main, with merge commits 56e858a, a0eedab, 580bf0c, 1b54449, f703715 and f031408. The docs are in main 16cb6aa: ai/comeup/2026-11-09/ holds the packet, three reviews, adjudication and scorecard. CI was green on each merged head. All of this is 1.1 work. Build 14.1, the 1.0 build in review, is untouched, and nothing went to ASC or TestFlight.
**Next:**
1. Perry's 1.0 submit (ai/STATE.md Waiting on Perry).
2. A 1.1 device sitting for the checks simulators can't make: haptics, the press spring and the launch view.
3. The 1.1 interface-elevation brief (ai/IDEAS.md), starting with the empty recorder screen and the centred transcript wrap.
**Waiting on Perry:** close PR #25, which merged #26 supersedes. The auto-mode check refused the close for the lane.
**In flight:**
- PR #25 is open (comeup/ui-checks). It is the main checkout's branch: leave it alone.
- Stale remote branches remain: comeup2/* (all merged), comeup/2026-11-09 (docs, merged into main), plus older icon-brand, ios-screenshots, r1-impl and r7c that are not this lane's.
- Nothing is uncommitted.
**Traps:**
- Lists are lazy, so XCUI must scroll before asserting on off-screen rows.
- build.yml runs only on PRs to main.
- Stacked PRs were merged with merge commits, not squash, so #28 auto-closed via #29.
<!-- READ-FIRST:END -->

## Detail
- Scorecard is in ai/comeup/2026-11-09/scorecard.md:

  | Measure | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
  |---|---|---|---|---|---|---|---|---|
  | Before | 2.0 | 1.7 | 3.0 | 2.0 | 1.0 | 1.7 | 2.3 | 2.0 |
  | After | 3 | 3 | 3 | 3 | 2 | 2 | 2 | 3 |

- #28's own screenshot run failed: the story row sat under the browse links, which #29 reorders. #29, which contains #28, was green and was merged.
- On #31, the first run of FlowTests.testStoryQuestionsFoldIntoOneRow failed with "Questions did not open". The cause was the lazy list. A scroll loop fixed it (5f12974) after reviewer changes.
- Deferrals are in ai/IDEAS.md (2026-11-09 line): C17, C18, C23, V4, V6, M7, and the device check.
- The harness is RetoldUITests/FlowTests plus ScreenshotTests in screenshots.yml. It publishes the `ui-checks-*` and `asc-screenshots-*` artifacts.
