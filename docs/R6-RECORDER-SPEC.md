# R6 spec — recorder, sidecar journal, transcription route, Action-button Control

_Written 2026-10-04. A Sonnet spec review the same day returned 25 findings (5 blockers), and all were
folded in. Step R6 of `../storycue/docs/STRATEGY-2026-09-22.md`._

_Governing design, in `docs/PLAN.md`:_
- _§1: the platform rows on SpeechAnalyzer, the Action button → Control → intent door, `AVAudioSession` from
  a cold start, background audio, and Data Protection with the sidecar journal;_
- _§2 "Capture";_
- _§4 items 1, 2 and 4: the frameworks, the usage strings, and protocols with mocks;_
- _§8: the transcription fallback chain;_
- _§5.1: Rule 1._

_Same contract as R1–R5: every type, file, rule and test name is fixed here. Sections are in build order._

## Two dispatches, and why

STRATEGY puts R6 "after 10-16". The recorder needs three things StoryCue owns until it submits: Perry's 16
Pro, an Apple sitting and Opus review time. Most of R6 needs none of them, so R6 is split in two.

**R6a — CI-provable, buildable now (§1–§6).**
- **What it is:** pure Swift plus Foundation, SwiftData and AppIntents.
- **What it builds:**
  - the recorder reducer;
  - the sidecar journal and its import;
  - the transcription route;
  - the capture coordinator, driven by mocks;
  - the launch intent as a type.
- **What it leaves alone:** no `AVFoundation`, `Speech` or `WidgetKit` import, and no `project.yml` or
  `.github/` change.
- **Who builds it:** Kimi, via `/orchestrate`.
- **Done when:** CI is green and the §6 journal replay tests pass. Those tests are the CI form of PLAN §12's
  week-1 gate: "a lock mid-capture loses nothing, including transcript segments".

**R6b — device-gated, after 10-16 and the Apple sitting (§7–§9).**
- **What it builds:**
  - the real `CaptureEngine`, on `AVAudioEngine` and `SpeechAnalyzer`;
  - the file transcriber, the route probe and asset prefetch;
  - file protection and store protection;
  - a minimal recorder screen;
  - the widget extension target;
  - the `deploy.yml` change.
- **What it needs from Perry:** a second App ID, a second profile and a second secret.
- **What it ends with:** the first TestFlight upload, then Perry's device checklist.
- **Done when:** that checklist is filled in, in the handoff.

The seam between R6a and R6b is the protocols in §4: `CaptureEngine`, `FileTranscriber`,
`AudioDurationProbe`, `FileProtector` and `JournalAppending`. CI green never means "the device path works"
(PLAN §4 item 4). Each dispatch's handoff says which rung passed.

## Scope

**R6a in:**

- **New source folder `Retold/Capture/`:**
  - `CaptureFiles.swift`, `RecorderMachine.swift`, `CaptureJournal.swift`;
  - `JournalImporter.swift`, `CaptureCoordinator.swift`;
  - `TranscriptionRoute.swift`, `CaptureEngine.swift`;
  - `CaptureMocks.swift` (`#if DEBUG`).
- **New file `Retold/Shared/StartCaptureIntent.swift`.**
- **Tests and notes:** the new test files in §6, and the `ai/IDEAS.md` lines in §10.

Both new folders sit under `Retold/`, the app target's source directory, so XcodeGen picks them up without a
`project.yml` edit.

**No schema change.** No `@Model` is added or retyped, no stored property is added, and the `Capture` writers
are unchanged.

**R6a out (moved to R6b):** every Apple adapter, every view, the extension target, `project.yml`, `deploy.yml`,
the speech usage string, and asset prefetch.

**Out of R6 entirely (R7 or later):**

- **Onboarding UI.** R6b only adds the microphone request and asset prefetch, on a bare screen.
- **The typed note for audio-only captures.** It needs a stored field, so it waits for the V1 freeze.
- **A Live Activity.**
- **Any filing or confirming.** R6 never creates an `Episode`, `Question`, `Detail`, `Person`, `Place` or
  `Period`.
- **Stopping a recording with the Action button.**
- **A maximum capture length** (§10).

## Rule-1 wall for R6

R6 writes exactly one kind of persisted user content: `Capture.transcript`.

**Its text is the transcriber's final-result text, verbatim.** There is no trimming, no case change, and no
joining or splitting of segments. It travels transcriber → journal line → importer →
`Capture.updateTranscript` / `completeTranscript`, unchanged at every step.

**Volatile results are UI-only.** They are never journaled and never persisted. `CaptureCoordinator.liveText`
joins segments for display only, and it is never written anywhere.

**R6 reads no stored content.** Nothing in R6 reads a `Detail`, `Person`, `Place`, `Period`, `Episode` or
`Question` into anything. The one foreign key R6 writes, `Capture.answersQuestionID`, is a UUID passed in by
the caller, and R6 never reads that question's text.

**Segment times are audio-file time:** seconds from the first sample in `audio/<id>.m4a`. That keeps every
later `VerifiedSpan` range pointing at the right seconds of audio (PLAN §5.1). §2.3 fixes the arithmetic.

**Never widen an access level to make something compile.** If a `fileprivate` or `private` member is in the
way, the code is in the wrong file. Report the error.

## 1. Files on disk — `Retold/Capture/CaptureFiles.swift`

```swift
/// Where a capture's files live. Production root: Application Support/Captures (R6b passes it);
/// tests pass a temp directory. Never Caches (purgeable; StoryCue S1 lesson).
struct CaptureFiles: Sendable, Equatable {
    let root: URL
    init(root: URL)
    // Computed properties / methods:
    var audioDirectory: URL                       // root/audio
    var journalDirectory: URL                     // root/journal
    func audioURL(for captureID: UUID) -> URL     // audio/<uuidString>.m4a
    func journalURL(for captureID: UUID) -> URL   // journal/<uuidString>.jsonl
    /// "<uuidString>.m4a" — what Capture.audioFileName stores.
    static func audioFileName(for captureID: UUID) -> String
    /// The capture ID encoded in an audio or journal file name ("<uuid>.m4a", "<uuid>.jsonl",
    /// "<uuid>.jsonl.bad"), or nil.
    static func captureID(fromFileName name: String) -> UUID?
    /// Creates both directories (withIntermediateDirectories: true). Idempotent.
    func prepare() throws
}

/// The Data Protection class each file gets, and when (PLAN section 1, Data Protection row).
enum ProtectionPlan {
    /// The audio file and the journal at creation: an already-open file keeps being written while locked.
    static let whileRecording: FileProtectionType = .completeUnlessOpen
    /// The audio file once its capture is imported.
    static let afterImport: FileProtectionType = .complete
}
```

`audioDirectory` is the directory `ExportWriter.write(_:audioDirectory:to:)` takes.

## 2. The recorder reducer — `Retold/Capture/RecorderMachine.swift`

This file is pure: it imports only `Foundation`. The reducer has StoryCue's `SessionMachine` shape: state +
event → state + effects, with the reducer generating the IDs.

It **deliberately diverges from StoryCue in three ways.** Do not copy StoryCue's rules across these:

1. **Locking is not a pause.** `UIBackgroundModes: audio` keeps an active `.record` session alive while the
   phone is locked (PLAN §1). Scene events and protected-data events never change the phase.
2. **One capture is one audio file.** An interruption pauses the capture but keeps the file open. Resume
   continues writing the same file.
3. **Resume is always a user action.** `interruptionEnded(shouldResume: true)` does not resume by itself.

### 2.1 Types

```swift
enum MicrophonePermission: Equatable, Sendable { case undetermined, granted, denied }

enum CaptureEndReason: String, Codable, Equatable, Sendable {
    case userStop, mediaServicesReset, engineFailed
}

enum RecorderPhase: Equatable, Sendable {
    case idle
    case blocked                                  // a start was requested without .granted; see state.permission
    case starting(captureID: UUID, stopRequested: Bool)
    case recording(captureID: UUID)
    case interrupted(captureID: UUID)             // file open, engine paused, waiting for tapResume
    case stopping(captureID: UUID, reason: CaptureEndReason)
    case aborting(captureID: UUID)                // failed during .starting; waiting for engineStopped
}

struct RecorderState: Equatable, Sendable {
    var phase: RecorderPhase
    var permission: MicrophonePermission
    var protectedDataAvailable: Bool
    var route: TranscriptionRoute
    var answering: UUID?                          // the question the active capture answers
    var runOffsets: [Int: TimeInterval]           // transcriber run number -> audio-file time it began at
    init(permission: MicrophonePermission, protectedDataAvailable: Bool,
         route: TranscriptionRoute = .audioOnly(.notChecked))   // phase .idle, answering nil, runOffsets [:]
}

enum RecorderEvent: Equatable, Sendable {
    case startRequested(answering: UUID?)         // Control intent or in-app Record button
    case permissionChanged(MicrophonePermission)
    case routeChanged(TranscriptionRoute)         // only honoured in .idle / .blocked
    case engineStarted(captureID: UUID)
    case engineStartFailed(captureID: UUID)
    case transcriberRunStarted(captureID: UUID, run: Int, audioOffset: TimeInterval)
    case finalSegment(captureID: UUID, run: Int, segment: TranscriptSegment)   // run-relative times
    case transcriberEnded(captureID: UUID, run: Int, completed: Bool)
    case interruptionBegan, interruptionEnded(shouldResume: Bool)
    case tapResume, tapStop
    case engineStopped(captureID: UUID, duration: TimeInterval)
    case mediaServicesReset, engineFailed
    case protectedDataWillBecomeUnavailable, protectedDataDidBecomeAvailable
    case sceneDidEnterBackground, sceneWillResignActive, sceneDidBecomeActive
}

enum RecorderEffect: Equatable, Sendable {
    case startEngine(captureID: UUID, route: TranscriptionRoute)
    case pauseEngine(captureID: UUID)
    case resumeEngine(captureID: UUID)
    case stopEngine(captureID: UUID)
    case openJournal(captureID: UUID)
    case journal(JournalRecord)
    case closeJournal(captureID: UUID)
    case importJournals                            // only ever emitted while protectedDataAvailable
}

enum RecorderMachine {
    /// `newID` is the reducer's only source of capture IDs (injected so tests are deterministic).
    static func reduce(_ state: RecorderState, _ event: RecorderEvent, now: Date,
                       newID: () -> UUID) -> (RecorderState, [RecorderEffect])
}
```

### 2.2 Transitions (exhaustive)

Any pair not listed here returns `(state, [])`. Below, `id` is the phase's capture ID. An event carrying a
**different** capture ID is stale and returns `(state, [])`.

**Starting a capture**

| From | Event | To | Effects, in order |
|---|---|---|---|
| `.idle`, `.blocked` | `startRequested(answering: a)` while `permission != .granted` | `.blocked` | none. **The request is dropped; a later grant does not replay it.** |
| `.idle`, `.blocked` | `startRequested(answering: a)` while `permission == .granted` | `.starting(captureID: n, stopRequested: false)` where `n = newID()`; `answering = a`; `runOffsets = [:]` | `.startEngine(captureID: n, route: state.route)` |
| `.starting`, `.recording`, `.interrupted`, `.stopping`, `.aborting` | `startRequested` | unchanged | none. A second Action press never starts a second capture. |
| any | `permissionChanged(p)` | `permission = p`; if phase is `.blocked` and `p == .granted`, phase becomes `.idle` | none |
| `.idle`, `.blocked` | `routeChanged(r)` | `route = r` | none |

**While the engine is starting**

| From | Event | To | Effects, in order |
|---|---|---|---|
| `.starting(id, false)` | `engineStarted(id)` | `.recording(id)` | `.openJournal(captureID: id)`, then `.journal(.begin(id, audioFileName: CaptureFiles.audioFileName(for: id), createdAt: now, answering: state.answering, route: state.route))` |
| `.starting(id, true)` | `engineStarted(id)` | `.stopping(id, reason: .userStop)` | `.openJournal`, then `.journal(.begin(…))` as above, then `.stopEngine(captureID: id)` |
| `.starting(id, _)` | `tapStop` | `.starting(id, stopRequested: true)` | none |
| `.starting(id, _)` | `engineStartFailed(id)` | `.idle`; `answering = nil` | none. Nothing was journaled. |
| `.starting(id, _)` | `mediaServicesReset` or `engineFailed` | `.aborting(id)` | `.stopEngine(captureID: id)` |
| `.aborting(id)` | `engineStopped(id, _)` | `.idle`; `answering = nil`; `runOffsets = [:]` | none. The audio file, if any, is left for the orphan rule (§5.1). |
| `.aborting(id)` | `engineStarted(id)` | unchanged | `.stopEngine(captureID: id)` |

**While recording**

| From | Event | To | Effects, in order |
|---|---|---|---|
| `.recording(id)`, `.interrupted(id)`, `.stopping(id, _)` | `transcriberRunStarted(id, run: k, audioOffset: o)` | `runOffsets[k] = o` | `.journal(.runStarted(id, run: k, audioOffset: o))` |
| `.recording(id)`, `.interrupted(id)`, `.stopping(id, _)` | `finalSegment(id, run: k, segment: s)` | unchanged | `.journal(.segment(id, run: k, segment: shifted))`. See §2.3. |
| `.recording(id)`, `.interrupted(id)`, `.stopping(id, _)` | `transcriberEnded(id, run: k, completed: c)` | unchanged | `.journal(.transcriberEnded(id, run: k, completed: c))` |
| `.recording(id)` | `interruptionBegan` | `.interrupted(id)` | `.pauseEngine(captureID: id)`, then `.journal(.paused(id, at: now))` |
| `.interrupted(id)` | `interruptionEnded(_)` | unchanged | none (divergence 3) |
| `.interrupted(id)` | `tapResume` | `.recording(id)` | `.resumeEngine(captureID: id)`, then `.journal(.resumed(id, at: now))` |
| `.recording(id)`, `.interrupted(id)` | `tapStop` | `.stopping(id, reason: .userStop)` | `.stopEngine(captureID: id)` |
| `.recording(id)`, `.interrupted(id)` | `mediaServicesReset` | `.stopping(id, reason: .mediaServicesReset)` | `.stopEngine(captureID: id)` |
| `.recording(id)`, `.interrupted(id)` | `engineFailed` | `.stopping(id, reason: .engineFailed)` | `.stopEngine(captureID: id)` |

**Ending a capture**

| From | Event | To | Effects, in order |
|---|---|---|---|
| `.stopping(id, r)` | `engineStopped(id, duration: d)` | `.idle`; `answering = nil`; `runOffsets = [:]` | `.journal(.end(id, duration: d, reason: r, endedAt: now))`, `.closeJournal(captureID: id)`, then `.importJournals` **only if** `protectedDataAvailable` |
| `.recording(id)`, `.interrupted(id)` | `engineStopped(id, duration: d)`, not requested | as the row above | as the row above, with `r = .engineFailed` |

**Lock, unlock and scene events**

| From | Event | To | Effects, in order |
|---|---|---|---|
| any | `protectedDataWillBecomeUnavailable` | `protectedDataAvailable = false`; phase unchanged | none |
| any | `protectedDataDidBecomeAvailable` | `protectedDataAvailable = true`; phase unchanged | `.importJournals` |
| any | `sceneDidEnterBackground`, `sceneWillResignActive`, `sceneDidBecomeActive` | unchanged | none (divergence 1) |

Ordering rules:

- **Transcriber events are accepted in `.stopping`.** `stopEngine` finalises the analyzer, so the last finals
  arrive after Stop.
- **`engineStopped` is the last event of a capture.** The adapter delivers every final and every
  `transcriberEnded` before it, and `engineStarted` before any `transcriberRunStarted` or `finalSegment`
  (§4.1).

### 2.3 Time base

`finalSegment` carries times relative to its own transcriber run, `k`. The journaled segment is:

```swift
TranscriptSegment(text: s.text,
                  start: s.start + (runOffsets[k] ?? 0),
                  end:   s.end   + (runOffsets[k] ?? 0),
                  isFinal: true)
```

The text is byte-identical. The offset is looked up **by run**, so a late final from run 1 that arrives after
run 2 has started still gets run 1's offset.

- **Normal case:** one analyzer runs the whole capture. The engine feeds the same buffers to the file and to
  the analyzer, so analyzer time equals file time. The adapter sends one
  `transcriberRunStarted(run: 0, audioOffset: 0)`.
- **Analyzer restart mid-capture:** the adapter sends `transcriberRunStarted(run: k+1, …)` with the file's
  written duration at that moment as the offset.

## 3. Sidecar journal — `Retold/Capture/CaptureJournal.swift`

### 3.1 Why a journal

The SwiftData store is `.complete`, which makes it unwritable while the phone is locked (PLAN §1). A lock
mid-memory is the common case. So capture writes only to its own two files, the audio and this journal, both
`.completeUnlessOpen`. Only the importer touches the store, and only while protected data is available.

**A closed `.completeUnlessOpen` file cannot be reopened while locked.** So the journal handle is opened once
at `.openJournal`, and held until `.closeJournal`. Captures start in the foreground, and therefore unlocked.

The format is **JSON Lines**: one record per line, `\n`-terminated, append-only. StoryCue's
rewrite-the-whole-file ledger does not fit here. Rewriting a growing file on every segment costs O(n²), while
appending a line per final segment costs O(1).

### 3.2 Records

```swift
struct JournalRecord: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case begin, runStarted, segment, transcriberEnded, paused, resumed, end }
    let v: Int                       // format version, 1
    let kind: Kind
    let captureID: UUID
    var audioFileName: String? = nil      // begin
    var createdAt: Date? = nil            // begin
    var answersQuestionID: UUID? = nil    // begin
    var route: String? = nil              // begin: TranscriptionRoute.journalTag
    var run: Int? = nil                   // runStarted, segment, transcriberEnded
    var audioOffset: TimeInterval? = nil  // runStarted
    var text: String? = nil               // segment (audio-file time)
    var start: TimeInterval? = nil        // segment
    var end: TimeInterval? = nil          // segment
    var completed: Bool? = nil            // transcriberEnded
    var at: Date? = nil                   // paused, resumed, end (= endedAt)
    var duration: TimeInterval? = nil     // end
    var reason: CaptureEndReason? = nil   // end

    static func begin(_ id: UUID, audioFileName: String, createdAt: Date, answering: UUID?, route: TranscriptionRoute) -> JournalRecord
    static func runStarted(_ id: UUID, run: Int, audioOffset: TimeInterval) -> JournalRecord
    static func segment(_ id: UUID, run: Int, segment: TranscriptSegment) -> JournalRecord   // stores text/start/end
    static func transcriberEnded(_ id: UUID, run: Int, completed: Bool) -> JournalRecord
    static func paused(_ id: UUID, at: Date) -> JournalRecord
    static func resumed(_ id: UUID, at: Date) -> JournalRecord
    static func end(_ id: UUID, duration: TimeInterval, reason: CaptureEndReason, endedAt: Date) -> JournalRecord
}

enum JournalCoding {
    /// outputFormatting [.sortedKeys, .withoutEscapingSlashes]; dateEncodingStrategy .secondsSince1970.
    static func encoder() -> JSONEncoder
    /// dateDecodingStrategy .secondsSince1970.
    static func decoder() -> JSONDecoder
    /// Encoded record + "\n".
    static func line(_ record: JournalRecord) throws -> Data
}
```

Encoding rules:

- Nil fields are omitted, because the synthesized encoder uses `encodeIfPresent`.
- JSON escapes newlines inside strings, so a record is always exactly one physical line.
- A record whose `v != 1` is undecodable for the reader (§3.3).
- The golden test (§6) fixes the exact bytes.

### 3.3 Writer and reader

```swift
/// One capture's open journal (the coordinator's seam; the mock throws on demand).
protocol JournalAppending: AnyObject {
    var captureID: UUID { get }
    func append(_ record: JournalRecord) throws
    func close()
}

final class JournalWriter: JournalAppending {
    /// Exclusive create + open in one step: open(2) with O_WRONLY|O_CREAT|O_EXCL|O_APPEND, mode 0o600
    /// (EEXIST -> JournalError.alreadyExists); wrap in FileHandle(fileDescriptor:closeOnDealloc: true);
    /// then protector.protect(url, as: ProtectionPlan.whileRecording). If protect throws: close, remove
    /// the file, rethrow. The handle stays open until close().
    init(files: CaptureFiles, captureID: UUID, protector: any FileProtector) throws
    /// Writes JournalCoding.line(record) in one write, then synchronize(). Throws .wrongCapture if
    /// record.captureID != captureID, .closed after close().
    func append(_ record: JournalRecord) throws
    func close()                       // idempotent
}

struct JournalReplay: Equatable, Sendable {
    let captureID: UUID
    let records: [JournalRecord]       // every good record before the first bad line
    let droppedTornTail: Bool          // the last physical line was undecodable and was dropped
    let corruptLine: Int?              // 1-based physical line (empty lines counted) of the first undecodable
                                       // line that is NOT the last; records after it are not read
}

enum JournalError: Error, Equatable {
    case wrongCapture, closed, alreadyExists
    case missingBegin                  // no decodable records, or the first is not .begin
    case mixedCaptures(line: Int)      // a record's captureID differs from begin's
}

enum JournalReader {
    /// Splits on "\n". Empty lines are skipped (but counted for line numbers). A last line (with or
    /// without a trailing "\n") that decodes is KEPT; one that does not decode is dropped
    /// (droppedTornTail = true). The first undecodable non-last line sets corruptLine and stops reading;
    /// the records before it are returned (salvage). Throws only .missingBegin and .mixedCaptures.
    static func read(_ url: URL) throws -> JournalReplay
    /// journal/*.jsonl (not *.bad), sorted by file name.
    static func journalURLs(in files: CaptureFiles) throws -> [URL]
}
```

## 4. Seams — `Retold/Capture/CaptureEngine.swift`, `Retold/Capture/TranscriptionRoute.swift`

### 4.1 Protocols

R6a defines these protocols. R6b implements them with Apple APIs, and `CaptureMocks.swift` mocks them.

```swift
/// The microphone, the audio file and the live transcriber behind one seam: on device one
/// AVAudioEngine tap feeds both the file and the SpeechAnalyzer input, so they share a clock.
protocol CaptureEngine: AnyObject, Sendable {
    func microphonePermission() async -> MicrophonePermission              // never prompts
    /// Prompts once if .undetermined. Onboarding only; never called on the capture path.
    func requestMicrophonePermission() async -> MicrophonePermission
    /// Activate the session, create the file at audioURL (ProtectionPlan.whileRecording), start the
    /// engine, start the live transcriber on `route` (none for .audioOnly). Emits engineStarted or
    /// engineStartFailed.
    func start(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async
    func pause(captureID: UUID) async
    func resume(captureID: UUID) async
    /// Stop the engine; finalise the transcriber, emitting its last finals and then
    /// transcriberEnded(completed:) — true only if the run finished without error; close the file;
    /// deactivate the session; then emit engineStopped(duration:) last.
    func stop(captureID: UUID) async
    /// The SAME stream on every access; single consumer (the coordinator). The mock holds one
    /// continuation and exposes finish().
    var events: AsyncStream<CaptureEngineEvent> { get }
}
```

**Contract for `stop`:**
- `stop(captureID:)` **always** emits `engineStopped(duration:)` eventually, even when `start` never completed
  or already failed. In that case the duration is 0.
- `stop` is idempotent: a second call for the same capture ID is a no-op and emits nothing further. The
  `.aborting` path can call it twice.

**Ordering contract for `events`:**
- `engineStarted` comes before any transcriber event.
- For each run, every `finalSegment` comes before that run's `transcriberEnded`.
- A run's `transcriberRunStarted` comes before its finals.
- `engineStopped` comes last.

```swift
enum CaptureEngineEvent: Equatable, Sendable {
    case recorder(RecorderEvent)
    case volatile(captureID: UUID, text: String)    // UI only
}

/// Re-transcribes a closed audio file (PLAN section 1: save audio first; transcribe from the file
/// if the live pass died). Yields final segments in audio-file time, then finishes; throws on failure.
protocol FileTranscriber: Sendable {
    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error>
}

/// The written length of a closed audio file; nil if unreadable.
protocol AudioDurationProbe: Sendable { func duration(of audioURL: URL) -> TimeInterval? }

/// Sets a file's Data Protection class. Real: FileManager.setAttributes; mock: records calls, can throw.
protocol FileProtector: Sendable { func protect(_ url: URL, as type: FileProtectionType) throws }
```

### 4.2 The transcription route (PLAN §8 fallback chain)

```swift
enum AudioOnlyReason: String, Equatable, Sendable, CaseIterable {
    case notChecked, noLocale, assetsNotInstalled, transcriberUnavailable
}

enum TranscriptionRoute: Equatable, Sendable {
    case speech(localeID: String)        // SpeechTranscriber
    case dictation(localeID: String)     // DictationTranscriber, the older-device fallback
    case audioOnly(AudioOnlyReason)

    var journalTag: String { get }       // "speech:<id>", "dictation:<id>", "audioOnly:<reason rawValue>"
    init?(journalTag: String)            // the exact inverse; nil for anything else (incl. empty locale id)

    /// The checked chain. R6b probes each input; none is assumed:
    ///   speechModuleAvailable = SpeechTranscriber.isAvailable
    ///   *Locale = supportedLocale(equivalentTo: .current)?.identifier, nil if unsupported
    ///   *AssetsInstalled = AssetInventory.status(forModules:) == .installed for that module and locale
    static func select(speechModuleAvailable: Bool, speechLocale: String?, speechAssetsInstalled: Bool,
                       dictationLocale: String?, dictationAssetsInstalled: Bool) -> TranscriptionRoute
}
```

`select` applies these rules in order:

1. If `speechModuleAvailable` is true, `speechLocale` is non-nil and `speechAssetsInstalled` is true, return
   `.speech`.
2. Else, if `dictationLocale` is non-nil and `dictationAssetsInstalled` is true, return `.dictation`.
   `DictationTranscriber` has no `isAvailable`, so its locale and asset checks are the gate. (Apple's
   documentation index, read 2026-10-04, lists `isAvailable` only on `SpeechTranscriber`.)
3. Otherwise return `.audioOnly`, with one of these reasons:
   - `.assetsNotInstalled` if either locale was supported but its assets were missing. This is the
     offline-first-capture case that PLAN §8's prefetch exists for.
   - Else `.noLocale`, if the speech module was available.
   - Else `.transcriberUnavailable`.

The live route is chosen before each capture, through `routeChanged`. It never changes mid-capture, and it is
journaled in `.begin`. The file pass asks the coordinator's `routeProvider` afresh, because the journal is gone
by then (§5.2).

### 4.3 What the importer writes to `Capture.transcriptionStatus`

Below, "completed" means all three of these hold:
- there is at least one `transcriberEnded` record;
- none of them has `completed != true`;
- every run that has a `runStarted` record has a completed `transcriberEnded`.

_Amended 2026-10-04 by the R6a code review. The first version said "the last `transcriberEnded` decides",
which let a completed later run hide an earlier run's hole. Also, a capture whose journal append failed has
its `transcriberEnded` written as `completed: false` by the coordinator, so a missing segment always forces
the file pass._

| Journal says | Importer writes |
|---|---|
| a route tag that parses as `speech`/`dictation`, completed, and `.end` present | `completeTranscript(segments)` → `.complete` |
| a `speech`/`dictation` route without completion (died, ended false, or no `.end`), **or** an unparseable/missing route | `updateTranscript(segments, status: .live)` (possibly `[]`) → queued for the file pass |
| a route that parses as `audioOnly` | `updateTranscript([], status: .live)` → queued (the file pass uses the current route, so assets installed later still help) |
| no importable journal (§5.1 orphan rule) | `updateTranscript([], status: .live)` → queued |

**The file pass (§5.2) works on one `Capture` at a time:**

- **When to skip:** skip a capture with non-empty `corrections`, because correction indices point at the
  current segments. Also skip when `routeProvider()` returns `.audioOnly`; those captures stay `.live` for a
  later pass.
- **On start:** `updateTranscript(current, status: .fromFile)`.
- **Finished with ≥1 segment:** `completeTranscript(fileSegments)`. The file is authoritative and replaces the
  live partial.
- **Finished with 0 segments:**
  - if the current transcript is non-empty, `updateTranscript(current, status: .failed)`;
  - if it is empty, `completeTranscript([])`, because silence is a complete transcript.
- **Throws:** `updateTranscript(current, status: .failed)`. A `.failed` capture keeps its partial and is
  never deleted.

## 5. Import and the coordinator

### 5.1 `Retold/Capture/JournalImporter.swift`

```swift
@MainActor
struct JournalImporter {
    let files: CaptureFiles
    let durationProbe: any AudioDurationProbe
    let protector: any FileProtector

    struct Report: Equatable {
        var imported: [UUID] = []          // Capture created from a journal
        var adoptedOrphans: [UUID] = []    // Capture created from an audio file with no importable journal
        var alreadyPresent: [UUID] = []
        var quarantined: [URL] = []        // journals renamed to .bad
        var failed: [URL] = []             // save/write failed; file left for the next import
        var protectFailed: [UUID] = []     // journal kept so protection is retried
    }

    /// Caller guarantees protected data is available. Uses a FRESH ModelContext(container), never
    /// mainContext, so rollback/save cannot touch unrelated edits. `excluding` = the live capture.
    func importAll(into container: ModelContainer, excluding: UUID?) -> Report
}
```

**Pass 1: journals, in `journalURLs` order.**

1. **Read.** Call `JournalReader.read`, and skip the URL if its ID equals `excluding`.
   - On `.missingBegin` or `.mixedCaptures`, rename the file to `<name>.bad` (`quarantined`). Its audio is
     picked up in pass 2. Continue to the next journal.
   - A replay with `corruptLine != nil` imports its salvaged records as below. It is then renamed `.bad`
     instead of removed in step 6, and listed in `quarantined`.
2. **Check for an existing row.** Fetch with `FetchDescriptor<Capture>(predicate: #Predicate { $0.id == cid })`,
   where `cid` is a local `let`. If a row is found, it is `alreadyPresent`: skip to step 5.
3. **Build the row.**
   - Create it with `Capture(audioFileName: begin.audioFileName, duration: d, createdAt: begin.createdAt)`.
   - Then set `capture.id = captureID` and `capture.answersQuestionID = begin.answersQuestionID`.
   - `d` is the `.end` record's duration, else `durationProbe.duration(of: audioURL)`, else 0.
   - The segments are the `.segment` records in journal order, each built as
     `TranscriptSegment(text:start:end:isFinal: true)` with the text exactly as journaled.
   - Write the status per §4.3, using `try`. If it throws, record the journal in `failed` and continue.
   - Insert the row.
4. **Save.** Call `context.save()`. If it throws, call `context.rollback()`, record the journal in `failed`,
   leave the file, and continue.
5. **Protect the audio.** If the audio file exists, call
   `protector.protect(audioURL, as: ProtectionPlan.afterImport)`. If that throws, add the capture to
   `protectFailed` and **do not run step 6**. Because the journal survives, the next import retries through
   step 2.
6. **Remove the journal** (or rename it `.bad`, per step 1).

The order 4 → 5 → 6 makes a crash safe at any point. A re-run finds the row in step 2 and finishes only steps
5 and 6. No duplicate `Capture` is ever created.

**Pass 2: orphan audio.** Look at every `audio/*.m4a` whose ID (from `CaptureFiles.captureID(fromFileName:)`)
has no `Capture` row, no remaining `.jsonl` journal, and is not `excluding`.

- **Adopt** each one: `Capture(audioFileName:, duration: probe ?? 0, createdAt: file creationDate ?? now)`, with
  `id` set, then `updateTranscript([], status: .live)`.
- **Save, then protect** it, as in steps 4–5. List it in `adoptedOrphans`.

This pass covers three cases: a crash between creating the file and `.begin`, a journal-open failure, and a
quarantined journal. A recording is never lost to a bad journal.

### 5.2 `Retold/Capture/CaptureCoordinator.swift`

```swift
@MainActor @Observable
final class CaptureCoordinator {
    init(engine: any CaptureEngine,
         fileTranscriber: any FileTranscriber,
         routeProvider: @escaping @Sendable () async -> TranscriptionRoute,
         files: CaptureFiles,
         importer: JournalImporter,
         container: ModelContainer,
         initialPermission: MicrophonePermission,
         protectedDataAvailable: Bool,
         inbox: CaptureLaunchInbox = .shared,
         makeWriter: @escaping (CaptureFiles, UUID) throws -> any JournalAppending,   // default: JournalWriter with the importer's protector
         now: @escaping () -> Date = Date.init,
         newID: @escaping () -> UUID = UUID.init)

    private(set) var state: RecorderState
    private(set) var liveText: String = ""        // UI only: journaled finals joined by " " + current volatile; reset at startEngine
    private(set) var journalError: JournalError?  // last journal failure, for the UI
    private(set) var processedEventCount = 0      // incremented after each handled event (tests)
    private(set) var lastImport: JournalImporter.Report?

    /// files.prepare(); then, if protectedDataAvailable, one import + file pass; then
    /// `for await e in engine.events { handle(e) }`. Returns when the stream finishes.
    func run() async
    func handle(_ event: CaptureEngineEvent)      // .recorder(e) -> send(e); .volatile -> liveText
    func send(_ event: RecorderEvent)             // reduce, enqueue effects, drain
    /// Awaits until the effect queue is empty and every engine call has returned (tests).
    func drainEffects() async
    /// Refreshes the permission, the route (routeProvider), then takes the inbox; if a start was
    /// pending, sends startRequested(answering: nil). Called on sceneDidBecomeActive and by the inbox's
    /// onRequest hook.
    func drainLaunchInbox() async
    func startCapture(answering: UUID?) async     // in-app Record button: refresh route, then send
    /// File pass over every Capture with status .live, .pending or .fromFile whose audio exists,
    /// excluding the active capture. Single-flight. Only while protectedDataAvailable.
    func retranscribePending() async
}
```

Non-observable stored members (the engine, the writer, the queue, tasks and closures) are marked
`@ObservationIgnored`.

**Effect execution: one FIFO queue.**

- **Enqueue, then drain.** `send` reduces, appends the effects to a queue, and drains it unless a drain is
  already running (an `isDraining` guard). A `send` made during a drain only enqueues. Effects run strictly in
  order.
- **Journal effects run synchronously:**
  - `openJournal` calls `makeWriter`. If that throws, it sets `journalError`, keeps no writer, and enqueues
    `send(.tapStop)`. The audio survives, and pass 2 adopts it.
  - `journal(r)` with no writer for `r.captureID` is skipped silently.
  - `journal(r)` with a writer that throws on `append` sets `journalError`. Recording continues, because the
    audio is the record. There is no retry.
  - `closeJournal` closes the writer and drops it.
- **Engine effects** (`startEngine`, `pauseEngine`, `resumeEngine`, `stopEngine`) are handed, in order, to
  **one serial task**: an `AsyncStream<RecorderEffect>` that a single task consumes and awaits one call at a
  time. So a pause can never overtake a start.
- **`startEngine`** first calls `try files.prepare()`. If that throws, it sets `journalError` and sends
  `engineStartFailed`. Otherwise it resets `liveText`, then calls
  `engine.start(captureID:audioURL: files.audioURL(for:), route:)`.
- **`importJournals`**, when `state.protectedDataAvailable`:
  1. sets `lastImport = importer.importAll(into: container, excluding: activeCaptureID)`;
  2. starts `retranscribePending()` (single-flight).

**Store guard.** The coordinator touches `container` only inside `importJournals` and `retranscribePending`.
Both return immediately unless `state.protectedDataAvailable`, and the file pass checks the flag again
before each capture's save.

**Single flight.** `retranscribePending` keeps one `filePassTask`. A call made while that task runs sets a
`rerunRequested` flag, and the running pass loops once more at the end, instead of starting a second pass.

### 5.3 Launch intent — `Retold/Shared/StartCaptureIntent.swift`

**Why the folder is `Shared/`:** R6b compiles this file into the widget extension too.

- Apple: *"The system requires the Target Membership of the app intent to be set to both the app and the
  widget extension to open the app."* (WidgetKit, *Creating controls to perform actions across the system*,
  "Open your app with a control", read 2026-10-04.)
- An intent with `supportedModes = .foreground` runs `perform()` **in the app process** once the app is in the
  foreground. That means **no App Group is needed**: the inbox is plain in-process state.
- The file imports only `AppIntents` and `Foundation`, because it must also compile as extension-safe code.

```swift
import AppIntents

/// In-process hand-off from the intent to the coordinator. Only the app's copy is ever reached.
@MainActor final class CaptureLaunchInbox {
    static let shared = CaptureLaunchInbox()
    init() {}
    private(set) var pendingStarts = 0
    /// Set by the coordinator; called after every request() so a press that arrives after
    /// sceneDidBecomeActive (cold launch) is still drained.
    var onRequest: (@MainActor () -> Void)?
    func request() { pendingStarts += 1; onRequest?() }
    /// True and resets to 0 if any start is pending.
    func take() -> Bool
}

struct StartCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a memory"
    static let description = IntentDescription("Opens Retold and starts recording.")
    static let supportedModes: IntentModes = .foreground(.immediate)   // iOS 26; NOT openAppWhenRun
    @MainActor func perform() async throws -> some IntentResult {
        CaptureLaunchInbox.shared.request()
        return .result()
    }
}
```

**Coordinator wiring:**
- In `init`, the coordinator sets `inbox.onRequest = { [weak self] in Task { await self?.drainLaunchInbox() } }`.
- `drainLaunchInbox` refreshes the permission before it takes the inbox. So a press is never consumed while
  the permission is stale.
- The inbox is a counter, not a callback alone, so a press made before the coordinator exists is not lost.

**SDK check.** `supportedModes` and `IntentModes` are iOS 26.0 per Apple's documentation index (read
2026-10-04). If their spelling or type differs in the SDK, fix it to match the SDK and record the change in
the PR. Do not fall back to `openAppWhenRun`.

## 6. R6a tests — `RetoldTests/`

**Conventions for every test file:**

- Every new class is a **non-isolated** `XCTestCase`. Tests that touch SwiftData, the coordinator, the
  importer or the inbox are individually `@MainActor`.
- **Never override `setUp`/`tearDown` in a `@MainActor` class.** Use `setUpWithError()`, never
  `setUp() throws`. Prefer per-test `make…()` helpers with `addTeardownBlock`. All three rules bit R5.
- Temp roots are `FileManager.default.temporaryDirectory/<UUID>`, removed in a teardown block. Containers
  come from `RetoldSchema.makeInMemoryContainer()`.
- **Tests that check "audio protected" must first create a stub audio file** (any bytes) at
  `files.audioURL(for:)`.
- The coordinator tests use fresh `CaptureLaunchInbox()` instances. Only `StartCaptureIntentTests` touches
  `.shared`, and it calls `take()` in a teardown block.

**Determinism**
- Coordinator tests drive `handle(_:)` and `send(_:)` directly, then `await coordinator.drainEffects()` before
  asserting on the mock's recorded calls.
- Exactly one test, `testEventsStreamPathIsHandled`, goes through `run()` and the mock stream. It pushes N
  events, then calls the mock's `finish()`, and asserts `processedEventCount == N` after `run()` returns.
- There are no sleeps. Where waiting is unavoidable, loop on `await Task.yield()` up to 1000 times.

**`RecorderMachineTests.swift`**
- `testStartWithoutPermissionBlocks`: covers undetermined and denied separately. No effects; phase `.blocked`.
- `testPermissionChangeWhileBlocked` (`.denied` updates `state.permission`; `.granted` gives `.idle`; no start
  is replayed).
- `testStartEmitsStartEngineWithRoute` (after `routeChanged`).
- `testRouteChangeIgnoredWhileRecording`.
- `testEngineStartedOpensJournalThenBegins`: asserts the effects `openJournal`, then the full `.begin` record
  (`answering`, `route.journalTag`).
- `testEngineStartFailedReturnsToIdleWithoutJournal`.
- `testStopDuringStartingStopsRightAfterStart`: `tapStop` in `.starting`, then `engineStarted`. Effects are
  `openJournal`, `.begin`, `stopEngine`; phase is `.stopping(.userStop)`.
- `testFailureDuringStartingAbortsAndStopsEngine`: covers `mediaServicesReset` and `engineFailed` in
  `.starting`. Both give `stopEngine` and `.aborting`; `engineStopped` then gives `.idle` with no journal
  effects.
- `testSecondStartWhileRecordingIsIgnored`.
- `testBackgroundAndLockDoNotPauseRecording`: in `.recording`, send `sceneDidEnterBackground`,
  `sceneWillResignActive` and `protectedDataWillBecomeUnavailable`. The phase is still `.recording`, and no
  effect is emitted.
- `testInterruptionPausesAndKeepsCapture`.
- `testInterruptionEndedDoesNotAutoResume` (`shouldResume: true`).
- `testTapResumeResumesSameCapture`.
- `testStopThenEngineStoppedJournalsEndAndImportsWhenUnlocked`.
- `testStopWhileLockedDoesNotImport` (effects end at `closeJournal`).
- `testFinalsAfterStopAreStillJournaled`.
- `testRunOffsetShiftsSegmentTimes`: run 0, offset 0, a final at 1–2 → 1–2. Then
  `transcriberRunStarted(run: 1, audioOffset: 12.5)` and a final at 0–1 → 12.5–13.5. The text is
  byte-identical.
- `testLateFinalFromEarlierRunUsesItsOwnOffset`: after run 1 starts, a run-0 final at 3–4 → 3–4.
- `testStaleCaptureIDIsIgnored` (`engineStarted`, `finalSegment`, `engineStopped`, each with a wrong ID).
- `testMediaServicesResetEndsCapture` and `testEngineFailedEndsCapture` (the reason in `.end`).
- `testUnrequestedEngineStoppedEndsAsEngineFailed`.
- `testUnlockEmitsImport`.

**`CaptureJournalTests.swift`**
- `testRecordLineGolden`: the exact UTF-8 bytes of one line of each of the seven kinds, with a fixed UUID and
  fixed dates.
- `testRoundTripEveryKind`.
- `testWriterAppendsAndReaderReplaysInOrder`.
- `testWriterRejectsWrongCapture` and `testWriterRejectsAfterClose`.
- `testWriterRefusesExistingFile` (`.alreadyExists`).
- `testWriterRequestsCompleteUnlessOpen` (mock protector, one call).
- `testWriterRemovesFileWhenProtectFails`.
- `testCompleteLastLineWithoutNewlineIsKept` (3 records, the third written without `\n` → 3 records; not torn).
- `testTornTailIsDropped` (2 records, then half a line → 2 records, `droppedTornTail`).
- `testCorruptMiddleLineSalvagesEarlierRecords` (a bad line 3 of 5 → 2 records, `corruptLine == 3`).
- `testUnknownVersionIsUndecodable` (`"v":2` as the last line → dropped as torn).
- `testMissingBeginThrows` (an empty file, and a first record that is a segment).
- `testMixedCapturesThrows`.
- `testNewlineInTextStaysOneLine`.
- `testJournalURLsSortedAndSkipBad`.

**`TranscriptionRouteTests.swift`**
- `testSpeechWhenAllSpeechChecksPass`.
- `testDictationWhenSpeechModuleUnavailable`.
- `testDictationWhenSpeechAssetsMissing`.
- `testAudioOnlyAssetsNotInstalled`.
- `testAudioOnlyNoLocale`.
- `testAudioOnlyTranscriberUnavailable`.
- `testJournalTagRoundTrip`: all three shapes, every `AudioOnlyReason`.
- `testJournalTagRejectsGarbage`: covers `""`, `"speech:"`, `"audioOnly:nope"` and `"fax:en_US"`.

**`JournalImporterTests.swift`** (`@MainActor`)
- `testCompletedJournalImportsCompleteCapture`. Checks id, audioFileName, duration, createdAt,
  answersQuestionID and the segments verbatim; the status is `.complete` and `completedTranscript != nil`.
- `testLastTranscriberEndedDecides` (`true`, then a later `false` → `.live`).
- `testJournalWithoutTranscriberEndImportsLive`.
- `testAudioOnlyRouteImportsLiveForFilePass`.
- `testUnparseableRouteImportsLive`.
- `testCrashOrphanUsesProbedDuration` (no `.end`; probe 42.0).
- `testCrashOrphanWithUnreadableAudioHasZeroDuration`.
- `testImportDeletesJournalAndProtectsAudio` (stub audio; protector called once with `.complete`).
- `testProtectFailureKeepsJournalAndRetries`. The first import gives `protectFailed`, and the journal stays.
  The second import, with the protector now succeeding, gives `alreadyPresent`, and the journal is gone.
  There is still one `Capture`.
- `testImportIsIdempotent`.
- `testCrashAfterSaveBeforeDeleteDoesNotDuplicate`.
- `testExcludedCaptureIsNotImported` (and its audio is not adopted).
- `testMissingBeginIsQuarantinedAndAudioAdopted`.
- `testCorruptJournalSalvagesThenQuarantines`.
- `testOrphanAudioWithoutJournalIsAdopted` (status `.live`, protected).
- `testTornTailStillImportsEarlierSegments`.
- `testVerbatimTextSurvivesEndToEnd`: segments with leading and trailing spaces, mixed case, an emoji, a
  combining mark, `\u{2028}` and `"a\nb"`. Each goes reducer → `JournalWriter` → `JournalReader` → importer.
  `Capture.transcript == expected`, compared as `[TranscriptSegment]`.
- `testImporterCreatesNoOtherEntities`: after import, `Episode`, `Question`, `Detail`, `Person`, `Place` and
  `Period` counts are all 0.

**`CaptureCoordinatorTests.swift`** (`@MainActor`; `MockCaptureEngine`, `MockFileTranscriber`, a mock
`routeProvider`, `MockJournalWriter` via `makeWriter` where noted, an in-memory container, a temp
`CaptureFiles`)
- **`testLockMidCaptureLosesNothing`** (the week-1 gate's CI form). Uses the real `JournalWriter`; create the
  stub audio after `startEngine`.
  1. `send(startRequested)`, then `handle(engineStarted)`.
  2. Finals 1 and 2, then `protectedDataWillBecomeUnavailable`, then final 3.
  3. `tapStop`, then final 4, `transcriberEnded(true)` and `engineStopped(30)`.
  4. The store has 0 `Capture`s. The journal holds `begin`, 4 segments, `transcriberEnded` and `end`.
  5. `protectedDataDidBecomeAvailable`. There is now one `.complete` `Capture`, with the 4 segments verbatim
     and in order. The journal is gone, and the audio is protected `.complete`.
- `testNoStoreAccessWhileLocked`. It has two halves, and each must fail if the guard in §5.2 is removed:
  - **Launch half:** write a complete journal by hand, then `run()` with `protectedDataAvailable: false` and
    the mock stream finished. 0 `Capture`s; the journal is still on disk.
  - **File-pass half:** insert a `.live` `Capture` with stub audio, then `retranscribePending()` while locked.
    The mock file transcriber records no call.
- `testCrashOrphanImportedAndRetranscribedOnLaunch`: a journal by hand with no `.end`, then `run()` unlocked.
  The mock yields 2 segments, giving `.complete` with those segments.
- `testFilePassUsesRouteProvider` (mock returns `.speech("en_US")`; the transcriber sees that route).
- `testFilePassLeavesLiveWhenRouteIsAudioOnly`.
- `testFilePassFailureMarksFailedAndKeepsPartial`.
- `testFilePassEmptyResultDoesNotEraseLivePartial` (gives `.failed`, partial kept).
- `testFilePassSkipsCorrectedCapture`.
- `testFilePassResumesFromFileStatus` (a `Capture` left `.fromFile` is picked up).
- `testFilePassIsSingleFlight`. The mock transcriber is gated by a continuation. Two
  `retranscribePending()` calls run, the gate is released, and the transcriber is called once per capture,
  never twice.
- `testJournalOpenFailureStopsCleanly` (`makeWriter` throws): `journalError` is set, the engine gets `stop`,
  and after `engineStopped` the state is `.idle` with no second `journalError`.
- `testAppendFailureKeepsRecording` (`MockJournalWriter` throws on the 3rd append; phase is still
  `.recording`).
- `testVolatileTextIsNeverJournaled`. `handle(.volatile("xyz"))` puts it in `liveText`, and no journal line
  contains `"xyz"`.
- `testEngineCallsKeepEffectOrder`: start, interruption, resume, stop in quick succession. The mock's recorded
  calls are `start`, `pause`, `resume`, `stop`, in that order.
- `testLaunchInboxStartsCaptureAfterPermissionRefresh`. The coordinator is created with
  `initialPermission: .undetermined`, and the mock engine reports `.granted`. Call `inbox.request()`, then
  `await drainLaunchInbox()`, then `drainEffects()`. The engine gets `start`. A second drain with nothing
  pending does nothing.
- `testInboxRequestHookDrains`: `inbox.request()` alone, then a `Task.yield()` loop until the engine records
  `start`. This proves the `onRequest` path for a press that arrives after the scene is already active.
- `testAnsweringFlowsToCapture`.
- `testEventsStreamPathIsHandled`.

**`StartCaptureIntentTests.swift`** (`@MainActor`)
- `testPerformRequestsAStart`: calling `perform()` makes `CaptureLaunchInbox.shared.take()` true.
- `testSupportedModesIsForegroundImmediate`. If `IntentModes` is not `Equatable`, use whatever comparison the
  SDK offers, or drop this test and say so in the PR.

**`CaptureMocks.swift`** (`#if DEBUG`) holds `MockCaptureEngine`, `MockFileTranscriber`, `MockDurationProbe`,
`MockFileProtector` and `MockJournalWriter`.

- The Release compile proves that no production code reaches them.
- Under Swift 6, a mock with mutable recorded calls is either an `actor` (with `events` declared
  `nonisolated let`) or a `final class` whose state sits behind a lock, marked `@unchecked Sendable` **in the
  mocks file only**.
- Production types never use `@unchecked Sendable`.

## 7. R6b — Apple adapters (after 10-16)

All R6b adapters live in `Retold/Capture/Device/`. That is the only folder that imports `AVFoundation` or
`Speech`.

**`LiveCaptureEngine: CaptureEngine`.**
- **Audio session:** `AVAudioSession` with category `.record` and mode `.spokenAudio`. It is activated inside
  `start`, never before the UI is up (PLAN §1).
- **Audio file:** an `AVAudioEngine` input tap writes to an `AVAudioFile` (AAC `.m4a`). The file is created
  exclusively, with `ProtectionPlan.whileRecording`, then opened.
- **Live transcription:** the same tap's buffers are converted with `SpeechAnalyzer.bestAvailableAudioFormat`
  and fed through an `AsyncStream<AnalyzerInput>` to one `SpeechAnalyzer` running the route's module.
- **Events:**
  - volatile results become `.volatile`;
  - final results become `.finalSegment`, with times from `audioTimeRange` and text
    `String(result.text.characters)`;
  - `AVAudioSession.interruptionNotification` becomes the interruption events;
  - `mediaServicesWereResetNotification` becomes `mediaServicesReset`.
- **Pause:** stops the engine, and keeps both the file and the analyzer open.
- **Stop:**
  1. Call `finalizeAndFinishThroughEndOfInput()` and drain the remaining finals.
  2. Emit `transcriberEnded`, with `completed` true only if the run finished without an error.
  3. Close the file and emit `engineStopped(duration)` last.
- **Start failure:** delete any zero-byte audio file.

**Other adapters.**
- **`SpeechFileTranscriber`:** `SpeechAnalyzer(inputAudioFile:modules:finishAfterFile: true)`, yielding
  finals only.
- **`SpeechRouteProbe`:** supplies the five `select` inputs. It also serves as the coordinator's
  `routeProvider`.
- **`AssetPrefetch`:** calls `AssetInventory.assetInstallationRequest(supporting:)` after the microphone
  grant (PLAN §8).
- **`AVDurationProbe`** and **`FileManagerProtector`**.

**Store protection.** After `RetoldSchema.makeContainer(url:)`, set `.complete` on the store file, its
`-wal`/`-shm` siblings and the store directory. Checklist item 6 verifies there is no store access while
locked.

**Minimal screens.** R7 replaces these; they get no design pass. All copy is in `AppCopy` and passes
`WellnessLint`.
- **First run:** the microphone grant plus prefetch.
- **Recorder:** a red dot, the elapsed time, `liveText`, a Stop button, and a Resume button while
  interrupted.
- **Home:** the existing placeholder plus a Record button that calls `startCapture`.

**Scene wiring.**
- `scenePhase`, `protectedDataWillBecomeUnavailableNotification` and `…DidBecomeAvailableNotification`
  become coordinator events.
- `drainLaunchInbox()` runs when the scene becomes active.
- `UIApplication.shared.isProtectedDataAvailable` supplies the initial flag.

**Widget extension `RetoldControls/`.**
- `RetoldControlsBundle: WidgetBundle` contains one `StartCaptureControl: ControlWidget`.
- That control is a `StaticControlConfiguration(kind: "dev.pmartin1915.retold.start-capture")` wrapping a
  `ControlWidgetButton(action: StartCaptureIntent())`.
- Its label is "Record a memory", it uses the `mic.fill` symbol, and it sets
  `.displayName("Record a memory")`.

## 7a. R6b — decided 2026-10-04 (Perry)

- **Maximum capture length.** At 20 minutes of recording, `CaptureCoordinator` exposes a
  `lengthWarning: Bool` (a banner on the recorder screen; no notification). At 30 minutes the recording
  ends exactly like a Stop.
  - It needs a new reducer event `timeLimitReached` and a new `CaptureEndReason.timeLimit`.
  - In `.recording` or `.interrupted`, `timeLimitReached` goes to `.stopping(id, reason: .timeLimit)` and
    emits `stopEngine`.
  - Elapsed time is the engine's written duration. Time spent interrupted does not count.
  - The coordinator owns the timer. Tests drive the event directly.
  - _As built (R6b part 1):_ the protocol has no duration query, so "recorded time" is measured by the
    coordinator: a stretch opens on entering `.recording` and closes on leaving it, using the injected
    `now()`, and one task per stretch sleeps for the time left. `.starting` resets the count and the
    banner; `.idle` clears the banner. The thresholds are an injectable
    `CaptureLengthLimits` (`.standard` = 20/30 min), a new last `init` parameter with a default, so the
    real timer is also tested in milliseconds.
  - Adding the enum case changes the journal format: the `reason` raw values gain `"timeLimit"`, so
    `JournalRecord.v` stays 1. Old readers never see it, because the journal is the app's own and
    short-lived.
- **A second Action press stops the recording.** In `.recording` or `.interrupted`, `startRequested`
  now behaves like `tapStop`. In `.starting` it sets `stopRequested`. In `.stopping` and `.aborting` it
  is still ignored. This replaces the R6a row that ignored a second press. Update
  `testSecondStartWhileRecordingIsIgnored` into `testSecondStartStopsRecording`, and add a test for
  each phase.
- **Live Activity:** deferred to 1.1.

## 8. R6b — project and pipeline changes

**The speech usage string is decided here.** Add `NSSpeechRecognitionUsageDescription: "Turns your recording
into text on this iPhone."` (PLAN §9).
- The key alone triggers no prompt. Only `SFSpeechRecognizer.requestAuthorization` prompts, and R6 never
  calls it.
- A missing key crashes if report D is right.
- So including the key is safe under both readings of the Sol vs D conflict. The device checklist records
  whether a prompt appears.

**`project.yml`.**
- **App target:**
  - add the usage string;
  - add `dependencies: [{ target: RetoldControls, embed: true }]`;
  - keep the sources as `Retold`, which already includes `Retold/Shared`.
- **New target `RetoldControls`:**
  - `type: app-extension`, `platform: iOS`;
  - sources `RetoldControls` and `Retold/Shared`;
  - settings `PRODUCT_BUNDLE_IDENTIFIER: dev.pmartin1915.retold.controls`, `PRODUCT_NAME: RetoldControls`,
    `TARGETED_DEVICE_FAMILY: "1"`, `SKIP_INSTALL: YES`, `APPLICATION_EXTENSION_API_ONLY: YES`;
  - Release settings `CODE_SIGN_STYLE: Manual`, `CODE_SIGN_IDENTITY: "Apple Distribution"` and
    `PROVISIONING_PROFILE_SPECIFIER: "Retold Controls AppStore"`.
- **Extension `Info.plist`** at `RetoldControls/Info.plist`. These values must equal the app's, or App Store
  Connect rejects the build:
  - `CFBundleDisplayName: Retold`;
  - `CFBundlePackageType: XPC!`;
  - `CFBundleShortVersionString: $(MARKETING_VERSION)`;
  - `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`;
  - `NSExtension: { NSExtensionPointIdentifier: com.apple.widgetkit-extension }`.
- **No App Group and no entitlements file** (§5.3).

**`build.yml`: no change.** The scheme builds `Retold: all`, and the extension builds as its embedded
dependency. The first R6b PR must show `RetoldControls.appex` under `Retold.app/PlugIns` in the CI log.

**`deploy.yml`.**
- **"Install provisioning profile":** loop over `PROVISIONING_PROFILE_APP` and the new
  `PROVISIONING_PROFILE_CONTROLS`, and fail the job if either is empty. Copy each to a UUID-named file, as now.
- **ExportOptions:** add `dev.pmartin1915.retold.controls` → `Retold Controls AppStore` under
  `provisioningProfiles`. Nothing else changes.
- **Verify step:** keep the app `Info.plist` lookup. Also read
  `Payload/Retold.app/PlugIns/RetoldControls.appex/Info.plist` by explicit path, and fail unless it exists,
  its `CFBundleVersion` equals `$BUILD_NUMBER`, and its `CFBundleShortVersionString` equals the app's.
- **Unchanged:** `CURRENT_PROJECT_VERSION` on the archive command line already applies to both targets, and
  `altool --upload-app` uploads the app and the extension in one `.ipa`.

## 9. Perry's acts and the device checklist (R6b)

**Apple sitting — DONE 2026-10-04.** Items 1–3 are complete. Item 4 is waiting on the R6b PR. The sitting was short: the boss drove the browser, and Perry signed in and clicked Create.
1. Create the App ID `dev.pmartin1915.retold.controls`: explicit, with no capabilities.
2. Create an App Store profile **"Retold Controls AppStore"** for it, using the same distribution certificate
   as "Retold AppStore" (expires 2027-03-14).
3. Perry runs `gh secret set PROVISIONING_PROFILE_CONTROLS` with the profile's base64. The classifier blocks
   the session from running it.
4. Run a deploy smoke with `upload=false`, using both profiles. Once the R6b PR has merged, run it with
   `upload=true`. That is the first TestFlight build.

**Device checklist on the 16 Pro.** Record each item in the handoff; this is R6b's Done-when.
1. Launch to red light, in seconds, measured by screen recording, in four states:
   - terminated, unlocked;
   - terminated, locked (Action press → Face ID unlock → launch; a foreground intent needs the unlock, so the
     unlock is part of the measured path);
   - warm, locked (the same);
   - after an interruption.
   Record a number per state; nothing is promised in advance.
2. A 3-minute capture with the phone locked at 0:30 and unlocked at 2:30. Every spoken sentence is in the
   transcript, and the audio plays end to end.
3. A phone call or Siri mid-capture. The recorder shows Resume, which continues the same capture, and the
   transcript times line up with the audio after the gap.
4. Force-quit mid-capture, then relaunch. The capture appears and is re-transcribed from the file.
5. Airplane mode before the first capture on a fresh install, with prefetch skipped. The capture lands as
   audio, gets transcribed after the assets arrive, and never shows as an error.
6. Two questions, recorded either way: does **any** speech-recognition prompt appear (Sol vs D), and does the
   locked app touch the store (no crash, no console error)?
7. The Action button runs the "Record a memory" control, and the control also appears in Control Center.

## 10. `ai/IDEAS.md` additions (append-only, R6a PR)

- 2026-10-04 (R6): the audio-only route needs a typed one-line note (PLAN §8). It is a stored field, so it
  waits for the V1 freeze; R7 builds the UI.
- 2026-10-04 (R6): store `CaptureEndReason` on `Capture` at the V1 freeze, plus a "recovered" marker for
  adopted orphans, so the library can say "recovered after a crash".
- 2026-10-04 (R6): set a maximum capture length, or a "still recording?" check, for a capture forgotten in a
  pocket after an accidental Action press. This is a product decision for Perry; StoryCue caps at 10 minutes.
- 2026-10-04 (R6): let a second Action press stop a recording. R6 ignores it.
- 2026-10-04 (R6): a Live Activity for lock-screen recording status and Stop (PLAN §1 calls it optional).
- 2026-10-04 (R6): a corrected capture is never re-transcribed from the file. R7 decides whether to offer the
  file pass and drop the corrections.

## Do not

- Do not import `AVFoundation`, `Speech`, `WidgetKit`, `UIKit`, `SwiftUI` or `FoundationModels` in any R6a
  file. `Retold/Shared/` imports only `AppIntents` and `Foundation`.
- Do not journal, persist or log volatile text.
- Do not alter segment text anywhere between the engine event and `Capture`: no trim, no join, no split and
  no case change.
- Do not touch the `ModelContainer` outside `importJournals` and `retranscribePending`, and never touch it
  while locked. Do not use `mainContext` in the importer.
- Do not pause, stop or change the phase on scene or protected-data events. Do not auto-resume.
- Do not close and reopen a journal mid-capture.
- Do not delete an audio file, ever, in R6a.
- Do not use `try!`.
- Do not create any entity other than `Capture`.
- Do not edit `Entities.swift`, `Values.swift` or any R1–R5 file.
- Do not use `openAppWhenRun` or `AudioRecordingIntent`.
- Do not run `git checkout`, `git switch`, `git reset` or `git stash` in the main checkout.
- Never widen an access level to make something compile. Report the error instead.

## Done when

**R6a**
- CI is green: the Debug tests and the Release compile both pass, and every R1–R5 test is unchanged and
  passing.
- Every test named in §6 exists and passes, including `testLockMidCaptureLosesNothing`.
- `grep -rnE "import (AVFoundation|Speech|WidgetKit|UIKit|SwiftUI|FoundationModels)" Retold/Capture Retold/Shared`
  matches nothing.
- `git diff main -- Retold/Model Retold/Filing Retold/Questions Retold/Export project.yml .github` is empty.
- `ai/IDEAS.md` has the six §10 lines. `ai/STATE.md` marks R6a merged and names R6b next (after 10-16).

**R6b**
- The §9 Apple sitting is done.
- A green deploy with both profiles has uploaded to TestFlight.
- The §9 device checklist is filled in, in the handoff, item by item, with numbers.
- Any failed item becomes a fix PR before R7 starts.
