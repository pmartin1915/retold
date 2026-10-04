# Handoff 2026-10-04 -- R7a merged + on TestFlight, R7b spec next

<!-- READ-FIRST:START -->
**State:** R7a merged: PR #11 squash `85e43e0` (404 tests, 0 failures). On-device filing model, confirm-before-file screen, Home Unfiled/Filed lists, Suggestions setting. TestFlight 1.0.0 (5.1) uploaded. main = origin = this handoff's commit (after `393c459`). Spec: docs/R7-SPEC.md.
**Next:** 1. Write the R7b spec, `docs/R7B-SPEC.md`. Scope is R7-SPEC section 9: Timeline, People, Places, episode and period pages, answering (AnswerAttacher, plus Sonnet findings 5/6 carried there), and the export zip to the share sheet. Sonnet spec review. 2. Build: Kimi if its weekly quota is back, else Sol (codex-exec). The model that types it does not review it. 3. Kimi independent audit of `85e43e0` (owed).
**Waiting on Perry:** device sitting after 10-16: R6 spec section 9 + R7 spec section 10 step 5, on build 5.1. Real app icon before submit (~10-27).
**In flight:** nothing. No open PRs. Remote branches: main, and the stale `r1-impl` (not ours).
**Traps:** Kimi hit its weekly cap 2026-10-04, and the 403 offered paid extra usage: never buy it (Money Rule). The worktree guard refuses compound or `-C` git commands, so split them; `main` is checked out in the main worktree, so commit docs on a branch from origin/main and `git push origin HEAD:main`. Multi-statement closures in `compactMap`/`map` need explicit return types (CI round 1 of R7a). Decided 2026-10-04: nudges, transcript corrections and the paid unlock are all 1.1; 1.0 ships free.
<!-- READ-FIRST:END -->

## Detail

### What shipped this session
- **Spec:** `docs/R7-SPEC.md`. Sonnet spec review (4 blockers, 9 should-fix) folded the same day. Section 13 is the record.
  - Cuts: answering moves to R7b; no rejection re-offer filter; no aliases; a Menu instead of autocomplete.
  - Dated PLAN §6.3 note: `DeviceTokenCounter` counts chars/3, because `tokenCount(for:)` is iOS 27.
- **PR #11 commit 1 (boss):**
  - `Retold/Filing/FoundationFilingModel.swift`, the only file that imports FoundationModels. It holds the fileprivate `@Generable` mirror, a fresh session per window, a 30 s timeout, error mapping, `ModelAvailability.current` and `DeviceTokenCounter`.
  - Tests: `RetoldTests/ModelBoundaryTests.swift` (source scan) and `FoundationAvailabilityTests.swift`.
  - Green on the first CI run. `.maximumCount` and the GenerationError cases compile. One deprecation warning: `GenerationOptions(sampling:)` should become `samplingMode:`. Harmless, so it was left alone.
- **PR #11 commit 3 (Sol-typed; Kimi wrote nothing):** `ConfirmDraft.swift`, `ConfirmFiler.swift`, `Screens/ConfirmView.swift`, `HomeView.swift`, `SettingsView.swift`, `RootView` auto-present, `LiveCaptureServices.container`, and 69 tests.
- **Commit 4 (boss):**
  - The compactMap return type.
  - Sonnet reviewer findings 1-4: forward cancellation into the model task, cache only `.proposal` outcomes, and non-vacuous wall 2/3 tests.
  - Deferred: nits 6-12 (duplicate entity when `useMatch == false` repeats; span captureID checks on person and place chips; auto-present may rarely fire if the capture is still `.live` at idle, so check it on device; empty section headers; no Cancel button).
- **Deploy:** run 37237825743, build 5.1, delivery `7c8860a6-01ea-4227-8578-45af9d4e7eba`.

### For R7b
- Read R7-SPEC section 9 and section 13, then `ai/IDEAS.md` (the R5/R7 lines on `EngineOffer.question.text`, the export zip, and the people typed-fill).
- AnswerAttacher design notes from the Sonnet review:
  - Run it on Home appear, on `lastImport` change, and on `scenePhase == .active`. The file pass completes audio-only captures without setting `lastImport`.
  - Use a pure `isAttachable(_:questionsWithEpisode:)`, true regardless of status.
  - Filter in memory. Never put an enum in `#Predicate`.
- `FilingResult.questionsByRowID` exists for "Answer now".
- The R7a Filed list in `HomeView` is a placeholder that the Timeline replaces.
