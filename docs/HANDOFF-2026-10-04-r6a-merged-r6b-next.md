# Handoff 2026-10-04 -- Retold: R6a merged, Apple side of R6b done, R6b build next

<!-- READ-FIRST:START -->
**State:**
- R6a is merged: PR #8, squash `4a5bc1d`. 319 tests, 0 failures, Release compile green.
- The R6b Apple side is done: App ID `dev.pmartin1915.retold.controls`, profile "Retold Controls AppStore", and secret `PROVISIONING_PROFILE_CONTROLS`.
- Perry's decisions are in spec §7a. main = origin = `912b471`.

**Next:**
1. Build R6b per `docs/R6-RECORDER-SPEC.md` §7, §7a and §8 with Kimi via /orchestrate. Write a slim wrapper spec that tells Kimi to write files in a fixed order and not redesign.
2. CI green, then a Sonnet `reviewer` pass, then merge.
3. Run `deploy.yml` with `upload=true` for the first TestFlight build, then hand Perry the §9 device checklist.

**Waiting on Perry:** on-device testing (§9) once TestFlight has a build. Perry said proceed with the defaults; StoryCue still owns his device time until 10-16.

**In flight:** nothing. No open PRs. The remote `r1-impl` branch is stale and not ours.

**Traps:**
- The low-memory reaper kills shells but not the kimi.exe they started. Check `Get-Process kimi*`. Last night's 13 leftovers were killed 2026-10-04.
- Kimi has no working shell and this machine has no Xcode, so CI is the first compile. Expect test-harness bugs.
- Python patches: these test files are CRLF, and a bash heredoc eats `\\n`. Write the script to scratchpad with raw strings.
- `try?` flattens optionals. That bit orphan adoption once.
- Never widen access levels. A @MainActor XCTestCase must not override setUp/tearDown.
<!-- READ-FIRST:END -->

## Detail

### R6 spec
- `docs/R6-RECORDER-SPEC.md`: written this session.
- A Sonnet spec review returned 25 findings, all folded.
- Later amendments:
  - `cb3e539`: `stop()` is idempotent and always emits `engineStopped`.
  - `8913757`: the completion rule. A capture is complete only if every run ends completed, and an append failure forces the file pass.
  - `912b471`: §7a, Perry's decisions.
- Apple docs (read 2026-10-04): an app-opening Control intent must be a member of BOTH targets and runs in the app process, so no App Group is needed. `supportedModes`/`IntentModes` are iOS 26.

### R6a (PR #8)
- **What landed:**
  - `Retold/Capture/`: CaptureFiles, RecorderMachine, CaptureJournal, CaptureEngine protocols, TranscriptionRoute, JournalImporter, CaptureCoordinator, CaptureMocks.
  - `Retold/Shared/StartCaptureIntent.swift`.
  - Six test files.
- **Kimi run 1:** wrote nothing. It spent its 32K output budget on one think block. Fixed by adding "write files in this order, don't redesign" to the wrapper.
- **Kimi run 2:** the shell was reaped, but the orphan kimi.exe finished the work.
- **Boss fixes before CI:** torn tail is judged on the last non-empty line; quarantine only on JournalError; file-pass lock check moved next to the save; explicit `TranscriptionStatus` array.
- **CI rounds:**
  1. A rethrowing `map` was missing its `try`.
  2. 13 test-harness bugs: the harness didn't mint captureID, the lock test had no route, records lacked `.begin`, and the idempotence assertion was wrong.
  3. Green, 314 tests.
- **Sonnet reviewer:** REQUEST-CHANGES. Fixed:
  - an append failure, or any incomplete run, now forces the file pass;
  - the store guard is re-checked after every await, and autosave is off;
  - the launch file pass runs in the background (`kickFilePass`, `awaitFilePass`);
  - single flight no longer loses a rerun;
  - a fetch error is no longer treated as "absent";
  - a duration of 0 now uses the probe.

  Five tests were added. That fix round itself introduced a `try?` bug in orphan adoption, which was caught by tests and fixed. Final run 37228204051: 319 green.
- Three review nits went to `ai/IDEAS.md`: orphan protect retry, ghost rows from failed starts, and journal-open failure on an audio-only route.

### R6b scope (spec §7, §7a, §8)
- **Adapters** in `Retold/Capture/Device/`: LiveCaptureEngine (AVAudioEngine tap → AVAudioFile plus SpeechAnalyzer), SpeechFileTranscriber, SpeechRouteProbe (also the `routeProvider`), AssetPrefetch, AVDurationProbe, FileManagerProtector.
- **Store protection:** `.complete` on the store files.
- **Minimal screens:** a first-run mic grant plus prefetch, the recorder screen, and Home with a Record button.
- **Scene wiring.**
- **The `RetoldControls` widget extension.**
- **§7a:**
  - `timeLimitReached` plus `CaptureEndReason.timeLimit`, with a banner at 20 min and auto-stop at 30 min;
  - a second Action press stops the recording, replacing the R6a "ignored" row, and the test is renamed.
- **§8:**
  - the `NSSpeechRecognitionUsageDescription` key;
  - project.yml: the extension target, `embed: true`, `APPLICATION_EXTENSION_API_ONLY`;
  - deploy.yml: a loop over both profile secrets, an ExportOptions entry, and an appex Info.plist version check.
- **Checklist:** §9 has 7 device items for Perry.

### Apple sitting 2026-10-04
- The boss drove Chrome. Perry clicked Register and Generate.
- The profile file is `Downloads\Retold_Controls_AppStore.mobileprovision`. Verified: app id `NN8F5WX25R.dev.pmartin1915.retold.controls`, `get-task-allow` false, expires 2027-03-14.
- Perry ran `gh secret set` himself. The classifier blocks the session from doing it.
