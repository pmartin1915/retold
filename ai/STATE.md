# STATE -- retold

> Seeded 2026-09-22 by hand from dev-ops branch claude/ios-duo-app-ideas-te3edu (docs
> byte-matched via `git show` | `cmp`, same method StoryCue's own seed used). Scaffold
> (project.yml, build.yml, deploy.yml, app/test skeleton) forked from StoryCue's own
> repo at its week-0-gate-met state, with every Duo-specific piece (DuoSupport, the
> Duo-gate CI step, the StoryCueDuoTests target) dropped -- this app has no Duo path.
> Keep short; read first.

## What this is
See README.md and docs/PLAN.md. Decisions of record are in docs/HANDOFF-2026-09-21-kickoff.md
(name **Retold**, decided 2026-09-21 -- codename "Hippo" was USPTO-congested;
**"Recall" was independently screened and rejected the same day** for colliding with
Microsoft Windows Recall and a live "Recall: AI Journal" App Store app, `docs/PLAN.md`
line 654 -- Perry's local folder for this project was briefly named `Recall` before that
was caught and corrected 2026-09-22).

## Why "build" started before StoryCue shipped
`docs/HANDOFF-2026-09-21-kickoff.md` and `docs/PLAN.md` section 12 both assumed Retold's
build would start only after StoryCue ships (2026-10-23) -- "StoryCue first unless Perry
changes it." Perry explicitly changed it 2026-09-22: told to build Retold now, in
parallel with StoryCue's remaining weeks, not after. Treat `docs/PLAN.md` section 12's
"starts after StoryCue's launch" line and its week numbering as superseded by that date;
the plan's *content* (data model, hazard rules, question engine, timeline shape) is still
the governing design, only the start date moved.

## What's Done
- [x] Research (prompt C landed and adjudicated; prompt D failed 3x, queued to re-run --
  see docs/PLAN.md section 12 note), plan (`docs/PLAN.md`, 701 lines), Sol + Kimi review
  (`docs/reviews/PLAN-REVIEW-2026-09-21.md`, both adjudicated, nothing declined) -- all done
  2026-09-21 on a laptop Fable session, on the dev-ops branch.
- [x] Naming screen: 14 candidates checked against App Store + USPTO 2026-09-21. Landed
  on **Retold**. "Recall" was checked and rejected in the same pass (see above).
- [x] Local folder seeded 2026-09-22: docs/ copied byte-exact from dev-ops, renamed into
  StoryCue's doc convention (`docs/PLAN.md` canonical, `docs/reviews/`,
  `docs/research/PROMPT-<letter>-*`).
- [x] **Week-0 scaffold written 2026-09-22**, forked from StoryCue's own scaffold:
  `project.yml` (iOS 26 deployment target per plan section 4 item 3 -- not 27.0 like
  StoryCue; `dev.pmartin1915.retold`; one app target + one test target, no Duo test
  target), `build.yml`/`deploy.yml` on `xcode-27` with the Duo-gate step and the Duo test
  lane removed entirely, `PrivacyInfo.xcprivacy`, `NSMicrophoneUsageDescription` +
  `UIBackgroundModes: audio` per plan section 4 item 2, a placeholder app
  (`RetoldApp.swift`) and placeholder test proving the test target builds and links
  against the app before any real code exists.
- [x] **Kimi pre-commit scaffold review 2026-09-22** (`docs/reviews/SCAFFOLD-REVIEW-2026-09-22.md`,
  223s, return_code 0, 16 tool calls, cross-checked against the StoryCue sibling). No
  blocking findings; three Low-severity fixes applied (pinned XcodeGen to 2.46.0, typed
  `workflow_dispatch` input comparison, test-target version variables).
- [x] **GitHub repo created and pushed 2026-09-22**: `github.com/pmartin1915/retold`
  (private). Registry row added on dev-ops `master` (`bac1427`, via an isolated worktree
  so the other sessions active on dev-ops's feature branch weren't disturbed).
- [x] **Week-0 gate MET 2026-09-22, first push, no fix-forward rounds needed**
  (run `35758163727`, conclusion success, 5m1s). Unlike StoryCue's own week-0 (3 small
  fix-forward commits needed after first push), this scaffold went green immediately --
  the lessons StoryCue's history already taught (TEST_HOST/BUNDLE_LOADER,
  ENABLE_TESTABILITY, SWIFT_ACTIVE_COMPILATION_CONDITIONS, the real `xcode-27` runner
  label) were baked in from the start instead of rediscovered. `PlaceholderTests` ran: 1
  test, 0 failures.
- [x] **S0 (cross-app strategy) landed 2026-09-22** (`b650c1b` + fix-forward `31a837a`): App-Review-allowlisted Xcode selection (`.github/scripts/select-xcode.sh`, same file as StoryCue's), unsigned Release compile, docs-only pushes skip Build & Test, `TARGETED_DEVICE_FAMILY: "1"`, deploy reports the `.ipa`'s `DTXcodeBuild`. **CI green, run `35775513678`** on `Xcode_27_Release_Candidate.app` (27A266a). Allowlist trap: see StoryCue `ai/STATE.md` Open Loops -- a red "Select Xcode" after the image ships a GA Xcode means add its build to the allowlist, not a code bug.

## What's Next
**Governing order: `../storycue/docs/STRATEGY-2026-09-22.md`** (both apps). Parallel with
StoryCue as Perry decided, but on lanes that don't compete with StoryCue's fixed 10-16 submit:
the CI-provable pure logic first, the device-gated recorder after 10-16. PLAN.md's content
still governs; only the order moved.
- [x] R1 Data model (PLAN §6.1) -- **merged 2026-09-24, PR #1 squash `0b8f376`.** Kimi build (`518a304`) + Sol Rule-1 fix (`f590446`); spec `docs/R1-DATAMODEL-SPEC.md`, Kimi spec review `docs/reviews/R1-SPEC-REVIEW-2026-09-22.md`, Sol audit `docs/reviews/R1-SOL-AUDIT-2026-09-22.md` (4 findings deferred to R2/R7 in `ai/IDEAS.md` -- the R2 spec must make `VerifiedSpan` verifier-only). **CI green, run `35808889391`: 33/33.** The earlier "blocked on GitHub billing" note is superseded (repo went public 2026-09-23). **Spike verdict: generic `Confirmable` survives SwiftData reopen** -- `testConfirmableIntSurvivesReopen` and `testDetailStoredProvenanceSurvivesReopen` both passed, so the concrete `ConfirmableInt`/`ConfirmableString` fallback is NOT needed.
- [ ] R2 Span verifier + windowed merge + template assembly (§6.2-6.3), `FilingModel` mock, synthetic implant fixtures
- [ ] R3 Leading-question lint (§7) + wellness copy lint (§5.2) in CI
- [ ] R4 Question engine ordering + nudge selection (§7)
- [ ] R5 `DeckFilingModel` + export manifest (§8)
- [ ] R6 Recorder + SpeechAnalyzer + Action-button Control + sidecar journal -- **after 10-16**, needs App ID/profile and the 16 Pro
- [ ] Operator acts, still Perry-only (`docs/PLAN.md` section 11 item 4): Apple Developer
  Portal App ID, App Store provisioning profile, ASC record, GitHub secrets. `build.yml`
  does not need these (`CODE_SIGNING_REQUIRED=NO`); only `deploy.yml` does, and nothing
  triggers `deploy.yml` by accident (`workflow_dispatch`/tag-push only).
- [ ] Prompt D (Apple stack) re-run solo, Personal Intelligence (Labs) toggle off (Perry
  flips it) -- `docs/PLAN.md` section 12 note.

## Open Loops
- Prompt D never landed (3 failed runs, Labs-toggle leak suspected cause) -- science
  findings (prompt C) are adjudicated and load-bearing for the design; the Apple-stack
  platform facts prompt D was meant to confirm are currently sourced from Sol's review
  only (`docs/reviews/PLAN-REVIEW-2026-09-21.md`).
- No App ID / provisioning profile / ASC record yet -- `deploy.yml` exists but cannot run
  until Perry does the operator acts above.

## Git state
- Branch: main, remote https://github.com/pmartin1915/retold.git (private). `3475634`
  (seed docs + scaffold), `e6d89b8` (scaffold review fixes) -- CI green on `e6d89b8`
  (run 35758163727). 2026-09-22 strategy session: `b650c1b`, `35ed092`, `31a837a` -- CI green (run 35775513678).

## CI policy (2026-09-23)

- **The repo is PUBLIC as of 2026-09-23**, so GitHub Actions minutes are free, macOS included. Perry ran out of Actions minutes (100%) after about 13 fix-cycle runs; see the storycue handoff of the same date. Current files were scrubbed of personal/entity references first. Git history still has them and was deliberately left alone. No credentials were ever committed. Signing lives in GitHub secrets, and `deploy.yml` is `workflow_dispatch` only, so fork PRs never see secrets.
- `build.yml` runs on PRs only, not on push to main. A squash-merge re-tested the tree its PR had just passed. **Code reaches main only through a green PR.** Docs/state commits go straight to main, and `workflow_dispatch` runs a manual main check.
- Batch compile fixes: sweep an executor's diff for Swift 6 test pitfalls before its first CI run, and push each fix round once, never one fix per push.
