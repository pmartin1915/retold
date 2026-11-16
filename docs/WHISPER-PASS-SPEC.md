# Whisper pass after Stop (Retold 1.1.0)

Decision (Perry, 2026-11-16, from the TestFlight 21.1 self-test, PR #37 comment 6924576219):
Apple's SpeechTranscriber made 4.5% WER and got every name wrong. Whisper turbo
(`openai_whisper-large-v3-v20240930_turbo_632MB`) made 1.2% WER, got the names right, and took 4.06 s per audio
minute with 674 MB peak extra memory and a 3.1 s cached load. So 1.1.0 ships:

1. **Live text:** Apple, with the self-test's `fast` tuning (`.fastResults`, prepared model, converter flushed at
   Stop). First final 11.7 s -> 5.0 s, p90 lag 5.0 -> 1.1 s.
2. **Kept transcript:** after Stop, a Whisper pass over the saved audio, when the user has the model.
3. **Offered, not forced:** a one-time prompt, a Wi-Fi-only download, and a Settings row to download or delete it.
4. The Listening self-test stays TestFlight/Debug only.

## 1. Live tuning

`ListenTuning.shipping = .fast`. `useContext` is in `.fast`, but the capture engine passes no contextual
strings, so **context is off in 1.1.0**: the `CaptureEngine` protocol has no place for them. The 21.1 numbers
for `fast` include context. Wiring the user's Person/Place names in is in `ai/IDEAS.md`. The Apple file pass
(used only when the live run failed) uses `.shipping` too, so it gets the prepared model as well.

## 2. When the pass runs

The seam is between the journal and the frozen transcript. Rule 1 (never rewrite the user's words) holds
because Whisper's words reach `Capture` only through the existing `completeTranscript`, before the capture
is ever `.complete`. After that the transcript is frozen as before. No `Capture` field, mutator or access
level changes. No schema change.

- **Importer (`JournalImporter.writeStatus`).** A speech or dictation route that completed with an `.end` record:
  - If `afterStopPass.isReady()` (the model is downloaded) and the route's locale is English: write
    `updateTranscript(appleSegments, status: .live)` and **mark** the capture.
  - Otherwise: `completeTranscript(appleSegments)`, exactly as today.
  - Every other row of R6 section 4.3 is unchanged.
- **Marker.** `WhisperPassLedger`: a UserDefaults dictionary `captureID -> attempts`, written before the
  importer's save. It separates "Apple finished, Whisper may improve it" from "the live run failed, partial
  only". If the save fails, a stale marker is harmless: no row is matched, and the next import re-marks it. If
  the marker is lost, the row is plain `.live` and gets today's Apple file pass, so nothing is lost either way.
- **Coordinator.** The same single-flight file pass (`kickFilePass` / `performOneFilePass`) takes marked
  captures first:
  - It never touches the store while protected data is unavailable (as today).
  - It never starts Whisper while a capture is active (`activeCaptureID != nil`). The capture stays `.live`
    and marked, and the import at the next Stop kicks the pass again. 674 MB on top of a live recording is
    how a recording gets killed by jetsam.
  - Unmarked `.live`/`.pending`/`.fromFile` captures keep today's Apple file pass and today's outcomes, unchanged.

## 3. Outcomes for a marked capture

`CaptureCoordinator.applyWhisperPassResult` writes in a fresh context with no suspension between the
fetch and the save (as `applyFilePassResult`). It does nothing unless the capture is still `.live`.

| Situation | Written | Marker |
|---|---|---|
| Whisper returned at least 1 segment with text, and at least half as many words as Apple's | `completeTranscript(whisper)` | removed |
| Whisper threw, returned nothing, or returned under half of Apple's words | `completeTranscript(apple)` | removed |
| Timed out | `completeTranscript(apple)` | removed |
| Not enough free memory to load | `completeTranscript(apple)` | removed |
| Corrections present | `completeTranscript(apple)` | removed |
| Model no longer downloaded (deleted in Settings) | `completeTranscript(apple)` | removed |
| Attempts already at the cap (2): the process died during earlier passes | `completeTranscript(apple)` | removed |
| A capture started during the pass | nothing (Whisper cancelled and unloaded) | kept, attempt given back |
| Phone locked during the pass | nothing (as today) | kept, attempt given back |

**Never `.failed`** for a marked capture: Apple's transcript completed, and `.failed` would show "no
transcript". The "half the words" guard keeps Whisper from replacing a real transcript with a hallucinated
"Thank you." or a truncated pass.

**Attempt cap.** `attempts` is incremented and synchronized **before** the model loads. A jetsam kill runs
no fallback code, so without the cap the capture would loop "Transcribing" on every launch. A clean return
of any kind removes the marker or gives the attempt back.

## 4. Gates and limits

- **Memory:** on a device, `os_proc_available_memory()` must be at least 1,000 MB before the load (674 MB
  measured peak plus margin; Apple's model stays resident under `.processLifetime`). The simulator has no
  such limit and skips the check.
- **Time:** 60 s plus 15 s per audio minute, covering load and transcription (measured 3.1 s load and
  4.06 s per minute; the first load after a download that skipped the compile can take minutes). On timeout
  the task is cancelled. Apple's transcript is written at once, then the pass awaits the cancelled task and
  unloads, so two models are never resident.
- **Language:** English only. The Whisper call forces `language: "en"`, so other locales keep Apple's.
- **One model resident:** loaded per pass, unloaded after each capture's pass. The 3.1 s load is
  cheaper than holding 674 MB.

## 5. Prompt, download, delete

- **Prompt.** Shown once on Home, as an alert after the first capture exists: "Better transcripts" /
  "Download a 632 MB speech model, on Wi-Fi only…" with "Download on Wi-Fi" and "Not now". It is not shown
  in `DemoMode` (Screenshots CI), or when the model is already present. `AppStorage` records that it was
  shown.
- **Download (`WhisperModelManager`, main actor).**
  - It starts only on Wi-Fi: `NWPathMonitor`, Wi-Fi interface, not expensive, not constrained. Asked while
    off Wi-Fi, it waits and starts when Wi-Fi arrives while the app runs. It is cancelled if the path stops
    being Wi-Fi.
  - It reuses `WhisperModelStore` (folder, free-space check, the marker written only after a finished
    download).
  - After the download it **loads once (the compile) and unloads, then reports Ready.** The importer's
    `isReady` is "the marker exists".
- **Settings row.** It shows "Better transcripts" with the state: Download (632 MB, Wi-Fi), Waiting for
  Wi-Fi, Downloading n%, Preparing, On this phone (n MB) with Delete, Failed with Retry. **Delete** first
  cancels any download and awaits the running pass, then deletes. Captures still marked complete with
  Apple's transcript at their next pass, because the model is gone.
- **Self-test.** Its "Delete Whisper models" also deletes the app's model (the same store). That is
  acceptable on test builds and is noted in the self-test footer.

## 6. What the user sees after Stop

The capture row reads "Transcribing…" (as for any non-complete capture) for about 4 s per audio minute plus a
3 s load. The confirm sheet still auto-presents after Stop. It shows "Transcribing…" under What you said and can be
filed by title, as today for a `.live` capture. Its suggestions load once, so a sheet opened during the pass
gets none (suggestions are off by default in 1.1.0; the follow-up is in `ai/IDEAS.md`). The
transcript is not user-editable (nothing calls `addCorrection`), so the pass always ends before any edit.
Corrections, if they ever exist, keep Apple's transcript (section 3).

## 7. Code

- `Retold/Capture/Whisper/WhisperModel.swift`: `WhisperModelSpec`, `WhisperModelStore`, `WhisperEngineError`,
  and the `WhisperRunner` load/transcribe/unload, moved out of `Diagnostics/WhisperEngine.swift`. The harness
  engine is now a thin wrapper.
- `Retold/Capture/Whisper/WhisperPass.swift`: the `AfterStopPass` protocol (isReady, availableMemoryMB,
  transcribe), `WhisperPassLedger`, `WhisperAfterStopPass` (real), and the time limit.
- `Retold/Capture/Whisper/WhisperModelManager.swift`: download, Wi-Fi gate, delete, and state for the UI.
- `JournalImporter`: `afterStopPass` and `ledger` (defaults: none, so every existing caller and test is unchanged).
- `CaptureCoordinator`: marked captures in `performOneFilePass`, and `applyWhisperPassResult`.
- The macOS harness job compiles a fixed file list. None of those eight files mention a new type.

## 8. Tests

- RetoldTests (mocks): importer ready, not ready, and non-English; every row of the section 3 table; the
  attempt cap; deferral while recording; the unmarked path unchanged (existing tests untouched).
- RetoldListenHarness (simulator, real Whisper turbo on CPU): a `.live` marked capture with fake Apple
  segments over a fixture recording; `retranscribePending()`; assert `.complete` with Whisper's words (WER
  against the reference well under the fake's) and the marker removed.
