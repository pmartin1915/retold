# Handoff 2026-10-04 -- R7b merged + on TestFlight 6.1, device sitting next

<!-- READ-FIRST:START -->
**State:** R7b merged: PR #12 squash `47d5edd`, full suite green (run 37255100878). Timeline, People, Places, episode/period/theme pages, Answer now + AnswerAttacher, period add/rename, export zip via ShareLink. TestFlight 1.0.0 (6.1) uploaded (deploy 37255634221). main = origin = `15fcb76` + this handoff. Spec: docs/R7B-SPEC.md.
**Next:** 1. Kimi independent audits of `85e43e0` (R7a) and `47d5edd` (R7b) once Kimi's weekly cap resets (it was still capped 2026-10-04 evening). 2. Fold device-sitting findings when Perry reports. 3. Submit prep (~10-27): real app icon, listing copy, privacy policy check.
**Waiting on Perry:** device sitting after 10-16 on build 6.1 (R6 spec §9, R7 spec §10 step 5, R7B spec §10 step 5). R7B spec §11: delete an unfiled capture in 1.0? (boss rec: 1.1). Real app icon.
**In flight:** nothing. No open PRs. Remote branches: main, and the stale `r1-impl` (not ours).
**Traps:** Sol is WEEKLY-limited until 2026-10-09 5:37 PM; Kimi weekly-capped. Both offer paid extra usage: never buy (Money Rule). If the worktree guard refuses every shell call after a cd, re-pin with EnterWorktree(path=<session worktree>) (PAPERCUTS). Build sub-worktrees go inside the session worktree (.orchestrate/wt/...). An empty locked `.orchestrate/wt/r7b` dir may linger: harmless, gitignored.
<!-- READ-FIRST:END -->

## Detail

### What shipped this session
- **Spec** `docs/R7B-SPEC.md` (`c47d846`, folded in `ca29e3b`). Sonnet spec review: APPROVE WITH CHANGES.
  - Blockers:
    - Playback `stop()` could deactivate the recorder's audio session during `LiveCaptureEngine.startUnsafe`'s await window. Fix: `stop` is a no-op when idle, and the phase hook uses `stop(deactivateSession: false)`.
    - The ConfirmView pre-pick named code that did not exist. It now goes in `buildDraft`.
  - Cuts: period reorder moved to 1.1, and ShareLink replaced the UIKit wrapper. The scrubber was kept.
  - Spec §13 is the record.
- **Build** (Sonnet-typed; Perry chose it after Sol hit its Plus limit with zero writes and Kimi was capped):
  - CI round 1: a test property shadowed `XCTestCase.name`.
  - CI round 2: the required `testAttachThenStaleFilePassSaveKeepsBoth` caught a real race. The file pass saved a Capture snapshot held across its transcription awaits, which wiped the `capture.episode` that AnswerAttacher had set meanwhile.
    - Boss fix: `CaptureCoordinator.applyFilePassResult(captureID:segments:in:)`. The pass now gathers candidate IDs, transcribes, then re-fetches and saves synchronously on the main actor.
    - R7a's filer was never exposed, because it only files captures the file pass does not touch.
  - CI round 3 green.
- **Review:** Sol went weekly-limited, so per Perry the review was Gemini 2.5 Flash via PAL (free) plus an Opus pass. There were no correctness findings, and all six invariants were confirmed. Declined:
  - full-table fetches, fine at personal-library scale;
  - moving the manifest off main, because `ExportLibrary.init` is `@MainActor` by design;
  - offset ForEach ids, because the rows are stateless;
  - logging.
- **Deploy:** run 37255634221, build 6.1, delivery `d97589f7-9291-47d9-9d96-0e714ffc231b`.

### Accepted 1.0 behaviours (spec §7.1, IDEAS)
- After Answer now, the user lands at Home's root, not the page they answered from.
- An answer under 2 s attaches but leaves its question open.
- Answers to episode questions skip the filing pipeline, so no new people or places are extracted.
- The theme entry is on Home, not the period page.

### Notes
- Kimi audits use the `/orchestrate` audit lane (`--implement` in a throwaway worktree at the merged commit, capped response). Do not include Opus, Sonnet or Gemini conclusions in the request.
