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

## What's Next
- [ ] Kimi pre-commit review of the scaffold (same step StoryCue took before its first
  push -- `docs/reviews/SCAFFOLD-REVIEW-2026-09-21.md` in the storycue repo is the
  precedent to follow).
- [ ] Create the private GitHub repo `pmartin1915/retold`, push, confirm `build.yml` goes
  green on an empty XcodeGen app (StoryCue's own week-0 gate needed 3 small fix-forward
  commits after first real push -- runner-label, PRODUCT_NAME collision,
  ENABLE_TESTABILITY -- budget the same here).
- [ ] Add the repo to dev-ops `config/portfolio-registry.json` once it exists on disk
  (PORTFOLIO.md rule) -- do this only after the push, per section 11 item 3.
- [ ] Operator acts, still Perry-only (`docs/PLAN.md` section 11 item 4): Apple Developer
  Portal App ID, App Store provisioning profile, ASC record, GitHub secrets. `build.yml`
  does not need these (`CODE_SIGNING_REQUIRED=NO`); only `deploy.yml` does, and nothing
  triggers `deploy.yml` by accident (`workflow_dispatch`/tag-push only).
- [ ] Prompt D (Apple stack) re-run solo, Personal Intelligence (Labs) toggle off (Perry
  flips it) -- `docs/PLAN.md` section 12 note.
- [ ] Week 1 (docs/PLAN.md section 6-7): recorder + live transcript (`SpeechAnalyzer`),
  save-first file writing, Action button intent, data model, question engine.

## Open Loops
- Prompt D never landed (3 failed runs, Labs-toggle leak suspected cause) -- science
  findings (prompt C) are adjudicated and load-bearing for the design; the Apple-stack
  platform facts prompt D was meant to confirm are currently sourced from Sol's review
  only (`docs/reviews/PLAN-REVIEW-2026-09-21.md`).
- No App ID / provisioning profile / ASC record yet -- `deploy.yml` exists but cannot run
  until Perry does the operator acts above.

## Git state
- Branch: main (local only until the remote exists -- this session creates it next).
