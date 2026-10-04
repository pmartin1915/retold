# Handoff 2026-10-04 -- Retold: R5 merged, signing pipeline live, R6 spec next

<!-- READ-FIRST:START -->
**State:** R5 is merged (PR #7, squash `f5ff27f`). CI: 228 tests, 0 failures, Release compile green. The operator acts are also done:
- the "Retold AppStore" profile;
- the ASC record **"Retold: Memory Journal"** (Apple ID `6819052835`, SKU `retold`), because bare "Retold" is taken;
- all 7 GitHub secrets;
- the deploy smoke run `37219609107` (upload=false), green on its first try.

main = origin = `8d30d48`.
**Next:** 1. Write the R6 spec in the style of docs/R5-DECK-EXPORT-SPEC.md. Scope: recorder + SpeechAnalyzer + Action-button Control + sidecar journal (PLAN §2, §4, §6). The Control needs a **widget extension**, which means a second App ID, a second profile and a second secret, plus a `deploy.yml` and `project.yml` change, so plan one more short Apple sitting with Perry. 2. Get a fresh Sonnet spec review, then build with Kimi via /orchestrate. 3. Do the first TestFlight upload (`deploy.yml upload=true`) only once a recorder exists.
**Waiting on Perry:** the Apple sitting for the widget-extension App ID and profile once R6 is specced, and on-device testing on the 16 Pro after the first upload.
**In flight:** nothing. No open PRs. The remote has the stale `r1-impl` branch (not ours).
**Traps:**
- The low-memory reaper kills background shells but NOT the kimi.exe they started. Check `Get-Process kimi*` before touching a worktree.
- A @MainActor XCTestCase cannot override setUp/tearDown. A non-isolated one must use `setUpWithError()`, not `setUp() throws`. Both bit R5.
- The auto-mode classifier blocks `gh secret set` and ASC create clicks. Perry runs or approves those.
- Never widen access levels. Rule-1 sealing is by fileprivate init (see R4.5/R5 specs).
<!-- READ-FIRST:END -->

## Detail

### R5 (PR #7, `f5ff27f`)
- Spec `docs/R5-DECK-EXPORT-SPEC.md` (`d54b33b` + Sonnet review folded `6e3b4d9`, 14 findings taken, copy nit logged).
- Kimi build in `.orchestrate/wt/r5`; shell reaped mid-run, orphan kimi.exe finished everything and wrote `.orchestrate/R5-NOTES.md`.
- Boss fixes: DefaultPeriodsTests @MainActor setUp override -> per-test `makeStore()` + `addTeardownBlock`; ExportWriterTests `setUp() throws` -> `setUpWithError()` (CI run 37181752502 failed on it); golden correction-date offset 30900 -> 300 s; ExportWriter treats "", "." as missing.
- Sonnet `reviewer` APPROVE (traced goldens + epochs independently). Green CI run 37181865457.
- Six R5 lines in `ai/IDEAS.md` (per-period copy needs V1-freeze key; people typed fills; stale persisted period.slot text; theme nudges; zip/share; opener capitalisation nit).

### Operator acts (all recorded in ai/STATE.md)
- Profile "Retold AppStore": App Store type, cert "Perry Martin (Distribution)" exp 2027-03-14 = identity in `C:\tmp\apple-signing\storycue.p12`. File `Downloads\Retold_AppStore.mobileprovision`.
- ASC record "Retold: Memory Journal" (Perry chose; "Retold" alone rejected as in use). Name editable later; bundle/SKU fixed.
- Secrets: API key `TM3T3B7QBF` (.p8 at `Downloads\_SECRETS_REVIEW\`), issuer id on ASC Integrations page, cert password = storycue.p12's.
- Smoke run `37219609107`: Xcode_27.app 27A266a, archive + export OK, upload skipped.

### Side items
- Shortless: April 9 App Review 5.4 message is stale; 2.1.0 build 16 resubmitted 2026-09-30 (VPN removed, account now Martin Apps LLC, explained in App Review notes; description has no "VPN"). Resolution Center thread is read-only while Waiting for Review; Perry chose to wait. Optional: Contact Us with the drafted reply.
- Perry asked StoryCue vs Retold: keep separate (different user, medium, rhythm, hardware; StoryCue's 10-16 submit). Possible v2 bridge: Retold imports a StoryCue interview as a capture (not logged yet).
- Suggested Perry move `Downloads\_SECRETS_REVIEW` (three .p8 keys) somewhere safer.
