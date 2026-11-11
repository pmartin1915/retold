# comeup scorecard: Retold, 2026-11-10 (run 3)

Perry: "it does not look professional or feel smooth yet." This run was screenshot-led: Sonnet and Sol saw the five CI screenshots, Kimi reviewed code only.

| Dimension | Before | After | Notes |
|---|---|---|---|
| 1 Motion and fluidity | 2.0 | 3 | Phase fades, the record ring morphs from dot to square, the confirm form fades in over placeholder rows, the More details fold animates, and the Filed pill waits for the sheet. Motion values now come from tokens. Springs still need a device check. |
| 2 State clarity | 3.0 | 3 | The recorder status is a capsule with the state in words. Accepted suggestions show as chosen ("Using this"). The live-text area has a placeholder. |
| 3 Input robustness | 2.7 | 3 | Unchanged paths. The Stop ring keeps the single-flight disable while starting or saving. |
| 4 Accessibility | 2.7 | 3 | Suggestion buttons are now 44 pt and stack at accessibility sizes. Transcript lines have a seek hint. Place and person rows are labelled. The year wheel's empty row says "Not sure". Checked at AX XXXL (check-ax5-*). |
| 5 Visual system | 2.3 | 3 | The serif face is used for the user's own words. StoryCue's recording red and record ring are in. Tokens now cover motion, spacing, warning and recording. The system safe-area bar replaces the opaque strip. The transcript hierarchy is fixed (accent times, primary leading-aligned words). The story page has one title. Dark mode is captured in CI. |
| 6 Performance | 1.0 | 2 | A volatile result no longer rebuilds the whole transcript or redraws the recorder. Only the live-words view reads it. Still unmeasured: M7 launch and hitch metrics, and the device lag Perry reported. |
| 7 Copy | 3.0 | 3 | New strings are in AppCopy and wellness-linted: placeholder, story counts, "What you said", "Using this", More details. The raw start-failure detail is still deferred (C23). |
| 8 Layout resilience | 2.3 | 3 | Stories come before questions on the person and period pages. File it sits in thumb reach. The live text keeps its space at large sizes. Periods show counts with compact spacing. |

Before is the mean of the three seats (S/K/O, adjudication.md). After is Opus re-scoring from the CI screenshots of the merged heads: #33 run 42966635383 and #35 run 42970289356, 6.9" ASC plus the ui-checks artifacts.

**Shipped.** All merged to main 2026-11-11, with CI green on each merged head (build, unit tests, both screenshot sizes). The reviewer agent ran on the three feature commits. The two follow-up fixes (`6fa6477` reviewer fixes, `16ffb8f` button layout + transcript colour) were checked by CI screenshots only.

| PR | Merge | What it shipped |
|---|---|---|
| #33 | `4b189b0` | P1 recorder (capsule, record ring, live text split and pinned), tokens, safe-area bar, dark-mode harness |
| #35 | `bc11052` | P2 story page, Home, person and period pages, plus P3 confirm sheet and the reviewer fixes |

- #34 (P2 alone) was closed as superseded by #35.
- Its 6.9" screenshot job had failed once at the story page's back button. The cause was a 1×1 principal-item hack. It was replaced with `toolbar(removing: .title)`, and the next run was green.
- My first P3 screenshot run caught two of my own defects, both fixed before merge:
  - The suggestion buttons collapsed into tall pills with icons and no labels (ViewThatFits plus fixedSize).
  - The transcript words stayed in the tint, because `.primary` inside a borderless button resolves to the tint.

**Rejected.**
- C12, fold the secondary facts: labelling the rows was enough.
- C24, mixed dashes and ellipses: an artefact of the ASCII-folded packet. The source already uses real em dashes and ellipses.
- C20, partly rejected:
  - Borderless buttons already dim on press. A custom style in multi-button List rows risked whole-row taps.
  - Only the ring uses `.pressable`.

**Deferred** (also in ai/IDEAS.md):
- C3: `canPlay` file stat per row.
- C21: seed and attach in Home's onAppear.
- C23: raw start-failure detail.
- Throttling volatile updates.
- Inline (rather than stacked) tentative words.
- The demo engine emits only volatile text, so App Store screenshot 02 shows grey words.
- The "suggested" tag hyphenates at AX XXXL.
- M7 metrics.
- Crash reporting.

**Harness.**
- FlowTests.testDarkModeMainScreens (DEBUG `-RetoldDark`) captures Home, the recorder and the story page in dark mode.
- screenshots.yml now also runs on Design, assets, RetoldApp.swift and Playback changes.
- CaptureCoordinatorTests asserts the final/volatile split.
- ScreenshotTests finds the story page by its header (`storyTitle`).
- The existing FlowTests cover AX XXXL, the Filed pill (it must still appear after the sheet closes), playback failure and the questions fold.

**Device check owed** (simulators cannot show these):
- Live-text smoothness while talking.
- Whether the bottom scroll anchor pulls a reader back down while new words arrive.
- The breathing dot and ring morph.
- Haptics.
- The serif face at length.

**Next:** Perry records a few stories on the TestFlight build from this run (1.1.0 (16.1), deploy run 16; ASC upload succeeded, delivery 15483318). Then the transcription-accuracy lane picks up, as STATE says.
