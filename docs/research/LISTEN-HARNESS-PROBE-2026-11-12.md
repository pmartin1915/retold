# Listening harness: runtime probe, 2026-11-12

CI run 43316328905 (PR #37, commits `5c55576` and `0117bbc`), workflow `listen-harness.yml`, runner image
`xcode-27-arm64`, Xcode 27.0.

## Result: no CI runtime can run the recognizer

| Host | SpeechTranscriber.isAvailable | Route before / after the app's AssetPrefetch | What happened |
|---|---|---|---|
| macOS 27.0.1 VM (command-line build of the app's capture sources) | false | `audioOnly:assetsNotInstalled` / same | Prefetch returned at once; nothing to transcribe. |
| iOS 27.2 simulator, iPhone 17 (`RetoldListenHarness` test bundle) | false | `audioOnly:assetsNotInstalled` / `dictation:en-US` | DictationTranscriber "installs", but `SpeechAnalyzer.bestAvailableAudioFormat` returns nil (live start fails: `converterUnavailable`) and `analyzeSequence(from:)` fails on every file: `SFSpeechErrorDomain Code=3 "Audio format is not supported"`. |

The plumbing works on both hosts: fixtures generate (`say`, 48 kHz Float32 mono, 32-40 s each, voices Samantha
and Daniel), the harness compiles against the app's own sources, the report exports from the xcresult, and the
scorer runs. What is missing is the on-device speech model: GitHub's macOS runners are virtual machines, and
neither the VM nor the simulator gets a working SpeechTranscriber.

## Next best runtime: the phone itself

The same harness core (`harness/Core/ListenHarness.swift`) runs inside the app on Perry's iPhone, behind a
DEBUG/TestFlight-only "Listening self-test" switch:

- the fixtures ship inside the build (generated in CI by the same `say` script);
- one tap runs every fixture through the live path and the file pass, with no microphone and no speaking;
- the result is the same JSON the CI scorer reads, shared in one tap (AirDrop, Files, Mail), and
  `harness/score.py` turns it into the table;
- it runs the current settings and the hardened settings side by side in the same build, so one run gives
  baseline and after.

Tradeoffs:

- **Needs Perry's hands once per build** (open the self-test, tap Run, wait ~6 min, share), and the boss
  ships the build to TestFlight. CI alone cannot produce a WER number.
- **Real model, real chip, real thermal state:** the numbers are the ones that matter, which a simulator
  could never give.
- **Clean `say` audio** does not reproduce room noise, distance or accents. A clean baseline can be good
  even where Perry's own recordings were not. The capture-stats record (step 4) covers his real
  recordings.

CI keeps running the harness on every PR as a compile-and-plumbing check. It reports "no speech route on this
host" honestly rather than inventing numbers.
