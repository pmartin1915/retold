# STATE: retold (NOW)

**Updated 2026-11-16.** Keep this to one screen. Update it in the same commit as any change of state, and replace lines rather than appending dated entries. Older state is in `ai/archive/STATE-through-2026-10-04.md`; handoffs older than two weeks are in `ai/archive/` (none in `ai/`; this repo keeps handoffs in `docs/`, newest `docs/HANDOFF-2026-10-04-r7b-merged-device-sitting-next.md`).

## Critical path
**2026-11-16: 1.1.0 engine is on main (PR #40, `48516dd`; spec `docs/WHISPER-PASS-SPEC.md`).** Live text is Apple `fast`. After Stop, when the user has downloaded the model, a Whisper turbo pass over the saved audio makes the kept transcript. Apple's transcript is kept on any fallback (error, short result, timeout, low memory, corrections, model deleted, 2 attempts). The model is offered, not forced: a one-time Home prompt, a Wi-Fi-only download, and a Settings row (Better transcripts) to download or delete it. Sol (Codex pmartin18551998) reviewed it in two rounds, and every high and medium was fixed. PR #37 (listen hardening) merged first (`abf6cf7`). TestFlight build from deploy run 22 (`48516dd`). **Perry chose to try the TestFlight build before submitting.** After his go, run `/release-train retold` for 1.1.0. Never submit the parked 1.0 (14.1). The engine numbers are in PR #37 comment 6924576219.

**2026-11-12 (Perry): listening hardening first, then ship 1.1.0 to the App Store.** Lane `retold-listen` (worktree `../retold-listen`, branch `listen/hardening`, brief dev-ops `boss/2026-11-12/retold-listen.md`) diagnoses the three device symptoms, builds a CI transcription harness (fixtures -> WER, dropped stretches, latency), fixes, gets Sol review, and reports to the boss; the boss merges, uploads, and submits once Perry confirms. Before that: **PARKED 2026-11-10 (Perry): 1.0 will not be filed.** He could not file it, and on device the transcription misheard words, dropped chunks of speech, and lagged. Next step is a redesign + transcription-quality lane, started once the other ship-wave apps (Tellfolk, BoardBound, Burn Wizard) are uploaded and done. ASC 1.0 (build 14.1) stays READY_FOR_REVIEW and unsubmitted; 1.1.0 build 15.1 is on TestFlight. The engine is already iOS 26 `SpeechTranscriber` (`Retold/Capture/Device/SpeechModules.swift`), so the lane tunes it (file re-pass over saved audio, custom vocabulary via the analysis context, the 1.1 corrections UI from IDEAS 2026-10-04) rather than swapping engines.

1.1 work on main: comeup run 2 (#26-#31, 2026-11-09) and run 3 (#33, #35, 2026-11-11: recorder capsule + record ring, cheap live text, serif for the user's words, story/confirm/Home redesign, dark-mode CI capture). **1.1.0 build 16.1 (deploy run 16, main `bc11052`) uploaded to TestFlight 2026-11-11**; no submission. Scorecards: `ai/comeup/2026-11-09/`, `ai/comeup/2026-11-10/`.

## Waiting on Perry
- Try 1.1.0 from TestFlight (deploy run 22, `48516dd`): accept 'Better transcripts' on Wi-Fi, wait for Settings to show it on the phone, record about a minute with names, Stop, and check the kept transcript. Then say 'submit 1.1.0' (runs `/release-train retold`) or report what is wrong.

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
