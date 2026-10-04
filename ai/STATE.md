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
- [x] R2 Span verifier + windowed merge + template assembly (§6.2-6.3), `FilingModel` mock, synthetic implant fixtures -- **merged 2026-10-01, PR #2 squash `608fb54`, CI green first run (run 36814046118).** Spec `docs/R2-FILING-SPEC.md`; built directly (Kimi at weekly cap), reviewed by the fresh-context `reviewer` agent (**Sonnet 5.5**, the standing reviewer while Sol is out), **Sol Rule-1 audit NOT run: run it against `608fb54` when Sol is back** (Perry, 2026-09-30). `VerifiedSpan` now unforgeable per file (fileprivate init; Debug-only `fixture`). Known gap for R3 lint: one-word spans like "I" fill `who`.
- [x] R3 Leading-question lint (§7) + wellness copy lint (§5.2) + 25-template seed deck + function-word slot guard -- **merged 2026-10-02, PR #4 squash `40bfdfe`, CI green (run 37093663127): 102 tests, 0 failures.** Spec `docs/R3-LINT-SPEC.md` (rules prototyped in Python before dispatch). Kimi build; boss fixed 2 compile errors pre-CI; Sonnet `reviewer` pass: no blockers, 3 test gaps added (`4c02589`). Mutation coverage by inspection (one rule-specific test per rule/term/guard), not executed. The wellness file scan reads `project.yml` from the simulator via `#filePath` -- works on CI. Sol audit not run (not required: Kimi built, Sonnet reviewed).
- [x] R4 Question engine ordering, outcomes + nudge selection (§7) -- **merged 2026-10-03, PR #5 squash `6fc9a28`, CI green first run (run 37176525407): 164 tests, 0 failures.** Spec `docs/R4-ENGINE-SPEC.md` (prototyped in Python; Sonnet spec review traced every literal sequence, 15 fixes folded). Kimi build cut short by Claude Code's low-memory reaper; boss finished it (Bool tuple sort compile fix, scenario C retire logic, corrected-span drop, a tie fixture). Sonnet `reviewer` pass (partial, no blockers). Mutation coverage by inspection, one test per Done-when item. Transcript-aware `unmentionedChannel` landed as an additive overload.
- [x] **Sol Rule-1 audit of R2 DONE 2026-10-03** -- `docs/reviews/R2-SOL-AUDIT-2026-10-03.md`. **Sol said "Rule 1 broken"; boss adjudicated "holds on current paths"** (stored span text is always the transcript's own words); hardening items deferred to R7 in `ai/IDEAS.md`; finding 5 (corrected words reused in questions) fixed in R4. **Perry decided 2026-10-03: holds** (Sonnet's independent second opinion concurred); seal findings 2 and 4 as R4.5 now, finding 1 at R7 (needs the V1 schema freeze).
- [x] R4.5 Rule-1 sealing (Sol R2 findings 2 and 4) -- **merged 2026-10-04, PR #6 squash `ac91ff2`: 168 tests, 0 failures, Release compile green.** Spec `docs/R4.5-SEAL-SPEC.md` (Sonnet spec review, 5 findings folded). Kimi built it; the second CI run was green after a one-line `contains(where:)` label fix. Sonnet `reviewer` APPROVE (read the test bodies). After R4.5, `QuestionTemplate`, `AssembledQuestion`, `TranscriptWindow` and `CompletedTranscript` are fileprivate-init in their own files, and production `Question`s come only from `init(assembled:)`. Fixtures are DEBUG-only (the Release compile guards them). `setExcerpt(from: CompletedTranscript)` refuses another episode's capture.
- [x] R5 No-model mode + export -- **merged 2026-10-04, PR #7 squash `f5ff27f`: 228 tests, 0 failures, Release compile green.** Spec `docs/R5-DECK-EXPORT-SPEC.md` (Sonnet spec review, 14 findings folded). Kimi built it; its shell was stopped by the low-memory reaper but the orphaned `kimi.exe` finished the work. Boss fixes: a `@MainActor` test class overriding `setUp` (Swift 6), `setUp() throws` -> `setUpWithError()`, a golden timestamp offset, and empty/dot audio names. Sonnet `reviewer` APPROVE. Delivered: `FilingMode` + `DeckFilingModel`, `DefaultPeriods.seedIfNeeded`, sealed `PeriodTitleFill` + the empty-period `period.slot` opener (a dated PLAN §7 note), `ThemeCards` + theme queue, `ExportManifest` + `ExportWriter`. Per-default-period copy, people typed fills, zip/share and theme nudges are deferred in `ai/IDEAS.md`.
- [x] R6a recorder logic -- **merged 2026-10-04, PR #8 squash `4a5bc1d`: 319 tests, 0 failures, Release compile green (run 37228204051).** Spec `docs/R6-RECORDER-SPEC.md` (Sonnet spec review, 25 findings folded; completion rule amended by code review `8913757`). Kimi built it (first run wrote nothing after spending its output on one think block; the re-run's shell was reaped and the orphan kimi.exe finished). Boss fixes: torn-tail detection on the last non-empty line, quarantine only on JournalError, store guard before the file pass saves, 5 test-harness bugs. Sonnet `reviewer` REQUEST-CHANGES, fixed: append failure or any incomplete run forces the file pass, store guard after every await + no autosave, launch file pass in the background, single flight without a lost rerun, fetch errors are not absent, zero duration uses the probe (+5 tests; 3 findings to IDEAS). Delivered: `RecorderMachine`, `CaptureJournal` (JSON Lines, O_EXCL, salvage reader), `JournalImporter` (save -> protect -> delete, orphan-audio adoption), `TranscriptionRoute`, `CaptureCoordinator`, `StartCaptureIntent` + `CaptureLaunchInbox` in `Retold/Shared/`. `testLockMidCaptureLosesNothing` is the CI form of the week-1 gate.
- [x] **R6b built and on TestFlight 2026-10-04.** Part 1 = PR #9 `93abf4d` (boss-typed: time limit 20/30 min, second press stops, `RetoldControls` extension, two-profile deploy; 329 tests; deploy smoke proved the appex in the signed .ipa). Part 2 = PR #10 `16baf93` (Kimi-typed device adapters, screens, scene wiring; boss SDK fixes; CI round 2 green; Sonnet REQUEST-CHANGES fixed: cold-launch inbox drain via `onChange(initial:)`, explicit `AVAudioFile.close()`, input-format change ends capture, analyzer cancel on failure, locks; store stays `.complete` per spec, checklist item 6 tests it). Placeholder icon `e009284` (first upload rejected 90713/90022). **TestFlight build 1.0.0 (4.1)**, deploy run 37233207977, delivery `ae5687d8-58a9-441b-9d2b-04d2eea7cf19`.
- [ ] **NEXT: Perry runs the spec §9 device checklist on the 16 Pro (after 10-16); any failed item becomes a fix PR before R7.** Original R6b scope note (spec §7-§9): AVAudioEngine + SpeechAnalyzer adapters, minimal recorder screen, widget extension `dev.pmartin1915.retold.controls`, deploy.yml with a second profile. **Apple side DONE 2026-10-04** (boss drove the browser, Perry clicked Register/Generate): App ID `dev.pmartin1915.retold.controls` (explicit, no capabilities), profile "Retold Controls AppStore" (App Store, cert "Perry Martin (Distribution)" exp 2027-03-14, `Downloads\Retold_Controls_AppStore.mobileprovision`), secret `PROVISIONING_PROFILE_CONTROLS` set (8 secrets total). Then first TestFlight (`upload=true`) and the 7-item device checklist on the 16 Pro. **Perry decided 2026-10-04:** a capture has a max length (boss rec adopted: banner at 20 min, auto-stop at 30 min saved like a normal Stop); a second Action press stops the recording; Live Activity deferred to 1.1; typed note + stored end reason at the V1 freeze; corrected-capture re-transcription is R7. The first two are R6b scope (spec §7a).
- [ ] R6 Recorder + SpeechAnalyzer + Action-button Control + sidecar journal -- **after 10-16**, needs App ID/profile and the 16 Pro
- [x] **Operator acts, Apple side, 2026-10-04** (Perry signed in, boss drove the browser). App ID `dev.pmartin1915.retold` already existed (made in StoryCue's S5 sitting). Profile **"Retold AppStore"** (App Store type, cert "Perry Martin (Distribution)" exp 2027-03-14, the identity in `C:	mppple-signing\storycue.p12`), file `Downloads\Retold_AppStore.mobileprovision`. ASC record **"Retold: Memory Journal"** (bare "Retold" is taken on the App Store; Perry chose this 2026-10-04), Apple ID `6819052835`, SKU `retold`, en-US, Full Access. **All 7 GitHub secrets set 2026-10-04** (Perry ran the `gh secret set` lines; API key `TM3T3B7QBF`, `.p8` at `Downloads\_SECRETS_REVIEW\`; cert = `storycue.p12` + its password). **Signing pipeline smoke run GREEN first try**: deploy run `37219609107` (`upload=false`), archive + export succeeded on release `Xcode_27.app`, DTXcodeBuild 27A266a. No TestFlight upload yet (the app is still a placeholder; first upload when R6 has a recorder). R6 will add a Control widget extension, which needs its own App ID + profile + a second profile secret and a `deploy.yml` change.
- [ ] (history) Operator acts, still Perry-only (`docs/PLAN.md` section 11 item 4): Apple Developer
  Portal App ID, App Store provisioning profile, ASC record, GitHub secrets. `build.yml`
  does not need these (`CODE_SIGNING_REQUIRED=NO`); only `deploy.yml` does, and nothing
  triggers `deploy.yml` by accident (`workflow_dispatch`/tag-push only).
- [x] Prompt D (Apple stack) re-run -- **landed 2026-10-02 (WW-0101), adjudicated 2026-10-02**
  in `docs/research/SYNTHESIS-2026-09-21.md` §D "Report D landed". Confirms Sol on the context
  window, availability, Data Protection and the locked door. Breaks nothing in PLAN.

## Open Loops
- **Prompt D adjudicated 2026-10-02** (synthesis §D). Open items it leaves, all closed on the SDK or
  device, not by research: (1) **speech usage string** -- Sol says not needed, D says needed (weak
  cite); R6 decides; (2) verify `@Guide(.maximumCount)` exists before `FoundationFilingModel` --
  an exact `.count` would push the model to pad arrays with invented names; (3) `tokenCount(for:)`
  is iOS 27 per D, so the device `TokenCounter` needs an iOS 26 path; (4) whether
  `SpeechTranscriber` runs on non-AI iPhones. PCC 32K and the "iOS 15 minimum" row were not
  verified and are not relied on (PCC is excluded; floor is iOS 26). New for R3: add *memory loss*
  to the copy lint (D §6, Guideline 1.1).
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
