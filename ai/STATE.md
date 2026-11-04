# STATE: retold (NOW)

**Updated 2026-11-04.** Keep this to one screen. Update it in the same commit as any change of state, and replace lines rather than appending dated entries. Older state is in `ai/archive/STATE-through-2026-10-04.md`; handoffs older than two weeks are in `ai/archive/` (none in `ai/`; this repo keeps handoffs in `docs/`, newest `docs/HANDOFF-2026-10-04-r7b-merged-device-sitting-next.md`).

## Critical path
Retold 1.0 was pulled from review after the recorder failed on device (OSStatus -50); fixed in PRs #17-#19, then hardened in PR #20 (`d098c3a`: single-flight Record tap, Saving state, Done/Cancel, title hint). Version 1.0 in ASC is "Prepare for Submission". Build 14.1 (deploy run `41797235996`, main `d098c3a`) is processing in TestFlight; it replaces 13.1 on the version page. Add for Review and Submit are Perry's.

## Waiting on Perry
- Record the 8-step device video on build 14.1 (not 13.1), attach it under App Review Information > Attachment, then submit. Steps are in `dev-ops/HANDOFF-2026-11-04-bw-review-retold-resubmit.md`.

## Hard dates
- 2026-10-16: StoryCue submit (frees Perry's device time).
- 2027-03-14: distribution cert "Perry Martin (Distribution)" expires (shared with StoryCue; identity in the storycue `.p12`).

## Traps
- App name: bare "Retold" is taken on the App Store; ASC record is "Retold: Memory Journal" (Apple ID `6819052835`, SKU `retold`, bundle `dev.pmartin1915.retold`). The submit kit proposes `Retold: Life Stories, Spoken`.
- Two-profile deploy: widget extension `dev.pmartin1915.retold.controls`, profile "Retold Controls AppStore", secret `PROVISIONING_PROFILE_CONTROLS` (8 secrets total; `93abf4d`). App Review needs CFBundleIconName and a real 1024 icon. The icon comes from `brand/marks/apps/retold.svg` (see `design/icon/README.md`); the old brown R is kept for other branding.
- Rule 1 (never rewrite the user's words): sealing is by fileprivate init (R4.5/R5 specs). Never widen access levels. A @MainActor XCTestCase must not override setUp/tearDown; non-isolated ones use `setUpWithError()`.
- Executors: the low-memory reaper kills shells but not the `kimi.exe` they started (check `Get-Process kimi*` before touching a worktree). Kimi has no shell and this machine has no Xcode, so CI is the first compile; budget 2-3 rounds. Never buy paid extra usage when Kimi or Sol 403 (Money Rule).
- CI is on a public repo (free minutes). Code reaches main only through a green PR; docs/state commits go straight to main. `build.yml` is PR-only; `deploy.yml` is `workflow_dispatch`/tag only. Remote branch `r1-impl` is stale and not ours.

## Where things live
- Plan and governing order: `docs/PLAN.md`; cross-app `../storycue/docs/STRATEGY-2026-09-22.md`.
- Specs: `docs/R1-DATAMODEL-SPEC.md` through `docs/R7C-SPEC.md` (R6 is `docs/R6-RECORDER-SPEC.md`); reviews and Sol audits in `docs/reviews/`; research in `docs/research/`.
- Ideas (append-only, deferred items from every audit): `ai/IDEAS.md`.
- Source: `Retold/`, `RetoldControls/`, `RetoldTests/`; build config `project.yml`, `.github/workflows/`.
- Merge history R1-R7c is in `git log` (PRs #1-#13; R5 `f5ff27f`, R6a `4a5bc1d`, R6b `93abf4d` + `16baf93`, R7a `85e43e0`, R7b `47d5edd`, R7c `ced7c7a`).
