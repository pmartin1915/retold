# Handoff 2026-10-04 -- R6b shipped to TestFlight, R7 spec next

<!-- READ-FIRST:START -->
**State:** R6b merged: PR #9 `93abf4d` (time limit, second press, RetoldControls, two-profile deploy) + PR #10 `16baf93` (device adapters, screens, scene wiring). Placeholder icon `e009284`. TestFlight build 1.0.0 (4.1) uploaded (run 37233207977). main = origin = `dab59d2`.
**Next:** 1. Write `docs/R7-SPEC.md` (STRATEGY R7: FoundationFilingModel, confirm flow, Timeline/People/Places, nudges), split R7a = filing + confirm flow, R7b = Timeline/People/Places; spec review by Sonnet. 2. Build R7a via /orchestrate Kimi (slim wrapper, fixed file order). 3. Target: Retold submit ~10-27 (Perry, 2026-10-04: both apps out in October).
**Waiting on Perry:** (a) OK to move nudges to 1.1? (asked, unanswered). (b) §9 device checklist on build 4.1 after 10-16. (c) Real app icon before submission.
**In flight:** nothing. No open PRs; only remote branches are main and the stale `r1-impl` (not ours).
**Traps:** Kimi has no shell, no local Xcode: CI is the first compile; budget 2 rounds for new Apple APIs. Session worktree guard refuses compound git/gh commands: split them, use `scratchpad/crlfpatch.py` for CRLF files. App Review needs CFBundleIconName + a real 1024 icon. StoryCue (submit 10-16) still has priority on Perry's device time.
<!-- READ-FIRST:END -->

## Detail

### What shipped this session
- **PR #9 (boss-typed):** `RecorderMachine` `timeLimitReached` + `CaptureEndReason.timeLimit`; `startRequested` while recording/interrupted stops, while starting sets `stopRequested`. `CaptureCoordinator.lengthWarning` (20 min) and auto-stop (30 min) on recorded time only, `CaptureLengthLimits` injectable (spec §7a "As built" note). `RetoldControls/` widget extension. `deploy.yml`: both profiles, ExportOptions entry, appex version check. 329 tests. Deploy smoke (upload=false) run 37231395989 proved the appex is in the signed .ipa. Sonnet reviewer APPROVE.
- **PR #10 (Kimi-typed, wrapper `.orchestrate/spec-r6b2.md`):** `Retold/Capture/Device/` (LiveCaptureEngine, SpeechModules, SpeechFileTranscriber, SpeechRouteProbe, AssetPrefetch, AVDurationProbe, FileManagerProtector, LiveCapture composition root), `Retold/Screens/`, `RetoldApp.swift`. CI round 1 failed on one spelling (`AVAudioApplication.recordPermission`); round 2 green. Sonnet REQUEST-CHANGES, fixed in `7f66ba2`: `onChange(of: scenePhase, initial: true)` (cold launch drained nothing), explicit `AVAudioFile.close()`, `AVAudioEngineConfigurationChange`/resume format check -> engineFailed, analyzer cancel on failed start/finalize, lock-protected flags, exclusive file create, `run()` single-start guard. Not taken: store protection stays `.complete` (spec decision; checklist item 6 tests it). Two deferrals in `ai/IDEAS.md`.
- **First upload rejected** (altool 90713/90022: no icon). Placeholder serif-R icon, re-run uploaded: delivery `ae5687d8-58a9-441b-9d2b-04d2eea7cf19`.

### Device checklist (spec §9) for Perry
Launch-to-recording seconds in 4 states; 3-min locked capture; call/Siri mid-capture + Resume; force-quit + relaunch; airplane-mode first capture; speech prompt? / locked store access?; Action button + Control Center. Perry may need to add himself as an internal tester in ASC.

### Untested on device (CI proves compile only)
Every SpeechAnalyzer call, the AVAudioConverter path, interruption handling, the control opening the app, store `.complete` while recording locked.
