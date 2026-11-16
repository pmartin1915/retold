# STATE: retold (NOW)

**Updated 2026-11-16.** Keep this to one screen. Update it in the same commit as any change of state, and replace lines rather than appending dated entries. Older state is in `ai/archive/STATE-through-2026-10-04.md`; handoffs older than two weeks are in `ai/archive/` (none in `ai/`; this repo keeps handoffs in `docs/`, newest `docs/HANDOFF-2026-10-04-r7b-merged-device-sitting-next.md`).

## Critical path
**2026-11-16 (Perry): engine decided from the phone self-test (21.1; numbers in PR #37 comment 6924576219).** Apple 4.5% WER with names wrong on every tuning; Apple `fast` cuts first-final 11.7 s -> 5.0 s and p90 lag 5.0 -> 1.1 s; Whisper turbo 1.2% with names right, 4 s per audio min, 674 MB peak. 1.1.0 = Apple `fast` live text + a Whisper turbo pass over the saved audio after Stop that produces the kept transcript before any user edit (Rule 1). Whisper is OFFERED, not forced: one-time prompt 'Better transcripts (632 MB, Wi-Fi)'; until it is downloaded Apple's transcript is kept. Then Sol review, merge PR #37, build, release-train submit (Perry's go before the submit). Never submit the parked 1.0 (14.1).

**2026-11-12 (Perry): listening hardening first, then ship 1.1.0 to the App Store.** Lane `retold-listen` (worktree `../retold-listen`, branch `listen/hardening`, brief dev-ops `boss/2026-11-12/retold-listen.md`) diagnoses the three device symptoms, builds a CI transcription harness (fixtures -> WER, dropped stretches, latency), fixes, gets Sol review, and reports to the boss; the boss merges, uploads, and submits once Perry confirms. Before that: **PARKED 2026-11-10 (Perry): 1.0 will not be filed.** He could not file it, and on device the transcription misheard words, dropped chunks of speech, and lagged. Next step is a redesign + transcription-quality lane, started once the other ship-wave apps (Tellfolk, BoardBound, Burn Wizard) are uploaded and done. ASC 1.0 (build 14.1) stays READY_FOR_REVIEW and unsubmitted; 1.1.0 build 15.1 is on TestFlight. The engine is already iOS 26 `SpeechTranscriber` (`Retold/Capture/Device/SpeechModules.swift`), so the lane tunes it (file re-pass over saved audio, custom vocabulary via the analysis context, the 1.1 corrections UI from IDEAS 2026-10-04) rather than swapping engines.

1.1 work on main: comeup run 2 (#26-#31, 2026-11-09) and run 3 (#33, #35, 2026-11-11: recorder capsule + record ring, cheap live text, serif for the user's words, story/confirm/Home redesign, dark-mode CI capture). **1.1.0 build 16.1 (deploy run 16, main `bc11052`) uploaded to TestFlight 2026-11-11**; no submission. Scorecards: `ai/comeup/2026-11-09/`, `ai/comeup/2026-11-10/`.

## Waiting on Perry
- Nothing now. Next ask: the final go before the 1.1.0 submit.

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
