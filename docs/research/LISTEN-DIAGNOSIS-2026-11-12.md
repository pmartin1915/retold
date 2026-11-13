# Listening diagnosis, 2026-11-12

Lane `retold-listen`, branch `listen/hardening` (from main `e1e25ba`). Diagnosed from the code before any
measurement; the transcription harness (`harness/`, workflow `listen-harness.yml`) is how each line below is
tested. Ranked within each symptom, most likely first. Line numbers are at `e1e25ba`.

Symptoms Perry saw on his iPhone (builds 14.1 and 15.1, 2026-11-10): it **misheard words**, **dropped chunks of
speech**, and **lagged**.

## 0. The finding that touches all three

**The saved transcript is the live transcript. The file pass over the saved audio never runs on a normal capture.**

- `Retold/Capture/JournalImporter.swift:124-127`: a speech route that ended `completed` with an `.end` record is
  written with `completeTranscript(segments)`, i.e. the live finals become the frozen `.complete` transcript.
- `Retold/Capture/CaptureCoordinator.swift:367`: the file pass only takes captures in `.live`, `.pending` or
  `.fromFile`. A `.complete` capture is never re-transcribed.

So the file pass only runs when the live run failed. Whatever the live recognizer misheard or dropped under
real-time pressure, with no right-hand context, is what the story keeps. A pass over the whole file has full
context and no deadline.

- **Harness test:** for each fixture, compare the live finals (what is journaled today) with
  `SpeechFileTranscriber` over the m4a the same `TapSink` wrote. If the file pass has clearly lower WER and
  shorter missing stretches, the fix is to queue every capture for the file pass (spec R6 section 4.3 change).
- **Rule 1 check:** the spec already says "the file is authoritative and replaces the live partial", and the
  pass skips captures with corrections. No user words are rewritten.
- **UX cost:** confirm/filing needs `.complete` (`Retold/Filing/CompletedTranscript.swift:53-55`), so filing
  would wait for the file pass. The harness measures how long that takes per minute of audio.

## 1. Dropped chunks

| # | Hypothesis | Where | Harness test |
|---|---|---|---|
| D1 | Live recognizer drops words, and (section 0) the drop is kept forever because the file pass never runs | `JournalImporter.swift:124-127`, `CaptureCoordinator.swift:367` | longest missing reference stretch, live finals vs file pass |
| D2 | The sample-rate converter is fed one tap buffer per call and told `.noDataNow`; frames it holds back are never flushed at Stop (no `.endOfStream`), and any conversion error drops the whole buffer silently with no count | `LiveCaptureEngine.swift:413-434` (`TapSink.convert`), drop at `:432` | count of buffers the converter returned nothing for; frames in vs frames out; missing words at the very end of each fixture |
| D3 | When formats match, the tap's own `AVAudioPCMBuffer` is yielded to an async consumer; the engine may reuse that memory after the tap block returns | `LiveCaptureEngine.swift:408-409` | only reachable if the mic format equals the analyzer format; harness logs which path ran (expected: converter path, iPhone mic is 48 kHz Float32) |
| D4 | A configuration change that keeps the same input format is ignored, but `AVAudioEngine` stops itself on a configuration change, so the rest of the capture records nothing and transcribes nothing while the UI still shows recording | `LiveCaptureEngine.swift:336-344` | device-only (route change); covered by the capture-stats record (step 4): tap buffers received vs wall time |
| D5 | Interruptions pause and never auto-resume (by design, Divergence 3) | `RecorderMachine.swift:222-238` | device-only; capture-stats records interruptions |
| ruled out | AsyncStream buffering policy discarding input | `LiveCaptureEngine.swift:140` uses `makeStream()`, default `.unbounded` | n/a |
| ruled out | Finals after Stop never journaled | `RecorderMachine.swift:195-210` accepts finals in `.stopping`; `LiveCaptureEngine.stop` drains the results task before `transcriberEnded`, and `engineStopped` (which closes the journal) is yielded last (`:272-304`) | harness counts finals arriving after stop |
| ruled out | Stop ordering losing the tail | tap removed, engine stopped, input finished, `finalizeAndFinishThroughEndOfInput`, results drained (`:266-287`) | tail words of each fixture present in live finals |

## 2. Misheard words

| # | Hypothesis | Where | Harness test |
|---|---|---|---|
| M1 | The kept transcript is the live one (section 0). The file pass hears the same audio with full context | as section 0 | WER live vs file pass |
| M2 | No `AnalysisContext` contextual strings: people's names and places the user has already filed (Person, Place entities) are never given to the recognizer | nowhere in `Retold/` (grep `AnalysisContext`, `contextualStrings`: no hits); entities `Retold/Model/Entities.swift:130,143` | names-and-places fixtures with and without contextual strings; WER on the name words |
| M3 | Module options: `transcriptionOptions: []`, `reportingOptions: [.volatileResults]`, `attributeOptions: [.audioTimeRange]`; no preset choice was measured | `Retold/Capture/Device/SpeechModules.swift:15-19` | same fixtures, option variants |
| M4 | Locale comes from `Locale.current` through `supportedLocale(equivalentTo:)`; a region/language mismatch picks a different model | `SpeechRouteProbe.swift:9`, `AssetPrefetch.swift:11` | not reproducible on CI (runner is en_US); capture-stats records the route tag |
| M5 | AAC compression of the saved file hurts the file pass | `LiveCaptureEngine.swift:114-118` (AAC at the input rate, default bit rate) | file pass over the m4a vs over the original fixture |

## 3. Lag

| # | Hypothesis | Where | Harness test |
|---|---|---|---|
| L1 | No `analyzer.prepareToAnalyze(in:)` and default `SpeechAnalyzer` options (no priority, default model retention): the model loads when the first audio arrives, so the first words are late | `LiveCaptureEngine.swift:141-144` | time to first volatile and first final from the first pushed buffer |
| L2 | No `.fastResults` reporting option, so volatile results come at the recognizer's slower default cadence | `SpeechModules.swift:18` | volatile latency (arrival minus the wall time its audio was pushed) |
| L3 | Every volatile result hops to the main actor and invalidates `LiveTranscript`, whose body re-lays out the whole settled text plus the tail; cost grows with recording length | `CaptureCoordinator.swift:144-145`, `Retold/Screens/RecorderView.swift:211-236` | not measurable off device (SwiftUI layout); throttle only if device still lags (IDEAS 2026-11-11). Harness reports volatile results per second, the update rate the UI must absorb |
| L4 | Each final does a synchronous `append` + `synchronize()` (fsync) on the main actor | `CaptureCoordinator.swift:187-200`, `CaptureJournal.swift:147-151` | device-only; finals are a few per sentence, so low rank |
| L5 | The volatile tail is not cleared when a final arrives, so for a moment the same words show twice, then jump | `CaptureCoordinator.swift:144-145, 194-196` | harness counts volatiles overlapping an already-final range (display only) |
| L6 | Assets prefetch only after the mic grant; first capture on a fresh install may run audio-only and wait for the file pass | `AssetPrefetch.swift`, `SpeechRouteProbe.swift` | device-only; capture-stats records the route |

## What the harness reports (per fixture)

- **WER** (substitutions, deletions, insertions) against the reference text, for live finals and for the file
  pass over the recorded m4a.
- **Longest missing stretch:** the longest run of consecutive reference words deleted in the alignment. This is
  "dropped chunks".
- **Lag:** time to first volatile and first final; per-final latency (arrival minus the wall time the end of its
  audio was pushed), median and p90; stop-to-done time.
- **Plumbing:** buffers pushed, buffers the converter returned nothing for, volatile results per second.

Runtime: see `docs/research/LISTEN-HARNESS-PROBE-2026-11-12.md` once CI has run.
