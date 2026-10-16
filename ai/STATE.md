# STATE: retold (NOW)

**Updated 2026-10-16.** Keep this to one screen. Update it in the same commit as any change of state, and replace lines rather than appending dated entries. Older state is in `ai/archive/STATE-through-2026-10-04.md`; handoffs older than two weeks are in `ai/archive/` (none in `ai/`; this repo keeps handoffs in `docs/`, newest `docs/HANDOFF-2026-10-04-r7b-merged-device-sitting-next.md`).

## Critical path
Retold 1.0 submit targets ~10-27 (Perry, 2026-10-04: both apps out in October; `dab59d2`). The code is feature-complete for 1.0 through R7c (main `aa83a12`, 479 tests green, run `37261654235`). What gates the submit is Perry: run the device sitting (Sat 2026-10-17) on the TestFlight build, and finish submit prep. The latest main is on TestFlight (deploy run `38854452592`, 2026-10-16). Owner: Perry; StoryCue (submit 10-16) has priority on his device time.

## Live workstreams
| Stream | State | Next |
|---|---|---|
| TestFlight | R7c (`ced7c7a`) deployed to TestFlight 2026-10-16, run `38854452592` succeeded (previous upload 1.0.0 (6.1) from `47d5edd`, run `37255634221`) | None; device sitting next |
| Device sitting | Sat 2026-10-17, on Perry To-Do calendar. Not started (unverified, last seen 2026-10-04) | 16 Pro: R6 spec section 9, R7 spec section 10 step 5, R7B spec section 10 step 5, R7C spec section 8 |
| Submit prep | `docs/SUBMIT-KIT.md` draft `cb4c296` (listing, privacy label, review notes, policy) | Name availability, real icon (Gemini, in progress; unverified, last seen 2026-10-04), screenshots, publish martinapps.dev/retold privacy + support pages and the support email |
| Audits owed | Kimi independent audits of `85e43e0` (R7a), `47d5edd` (R7b), `ced7c7a` (R7c); Kimi was weekly-capped 2026-10-04 (unverified now) | Run when Kimi resets. Sol was weekly-limited to 2026-10-09 (since lapsed, unverified) |
| 1.1 backlog | Nudges, transcript corrections, one-time unlock, Live Activity, period reorder are all 1.1 (Perry, 2026-10-04, `393c459`); 1.0 ships free | Not started; items accumulate in `ai/IDEAS.md` |

## Waiting on Perry
1. Device sitting Sat 2026-10-17 on the `ced7c7a` TestFlight build (on Perry To-Do calendar).
2. Submit prep open items in `docs/SUBMIT-KIT.md`: name availability, icon, screenshots, privacy/support pages, support email, final wording and price (deferred to 2026-10-26, sitting 2026-10-16).

## Hard dates
- 2026-10-16: StoryCue submit (frees Perry's device time).
- ~2026-10-27: Retold submit target.
- 2027-03-14: distribution cert "Perry Martin (Distribution)" expires (shared with StoryCue; identity in the storycue `.p12`).

## Traps
- App name: bare "Retold" is taken on the App Store; ASC record is "Retold: Memory Journal" (Apple ID `6819052835`, SKU `retold`, bundle `dev.pmartin1915.retold`). The submit kit proposes `Retold: Life Stories, Spoken`.
- Two-profile deploy: widget extension `dev.pmartin1915.retold.controls`, profile "Retold Controls AppStore", secret `PROVISIONING_PROFILE_CONTROLS` (8 secrets total; `93abf4d`). App Review needs CFBundleIconName and a real 1024 icon; the current icon is a placeholder (`e009284`).
- Rule 1 (never rewrite the user's words): sealing is by fileprivate init (R4.5/R5 specs). Never widen access levels. A @MainActor XCTestCase must not override setUp/tearDown; non-isolated ones use `setUpWithError()`.
- Executors: the low-memory reaper kills shells but not the `kimi.exe` they started (check `Get-Process kimi*` before touching a worktree). Kimi has no shell and this machine has no Xcode, so CI is the first compile; budget 2-3 rounds. Never buy paid extra usage when Kimi or Sol 403 (Money Rule).
- CI is on a public repo (free minutes). Code reaches main only through a green PR; docs/state commits go straight to main. `build.yml` is PR-only; `deploy.yml` is `workflow_dispatch`/tag only. Remote branch `r1-impl` is stale and not ours.

## Where things live
- Plan and governing order: `docs/PLAN.md`; cross-app `../storycue/docs/STRATEGY-2026-09-22.md`.
- Specs: `docs/R1-DATAMODEL-SPEC.md` through `docs/R7C-SPEC.md` (R6 is `docs/R6-RECORDER-SPEC.md`); reviews and Sol audits in `docs/reviews/`; research in `docs/research/`.
- Ideas (append-only, deferred items from every audit): `ai/IDEAS.md`.
- Source: `Retold/`, `RetoldControls/`, `RetoldTests/`; build config `project.yml`, `.github/workflows/`.
- Merge history R1-R7c is in `git log` (PRs #1-#13; R5 `f5ff27f`, R6a `4a5bc1d`, R6b `93abf4d` + `16baf93`, R7a `85e43e0`, R7b `47d5edd`, R7c `ced7c7a`).
