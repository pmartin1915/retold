# R6 spec — recorder, sidecar journal, transcription route, Action-button Control

_Written 2026-10-04. Step R6 of `../storycue/docs/STRATEGY-2026-09-22.md`. Governing design: `docs/PLAN.md`
§1 (the platform rows on SpeechAnalyzer, the Action button → Control → intent door, `AVAudioSession` from a
cold start, background audio, Data Protection and the sidecar journal), §2 "Capture", §4 items 1, 2 and 4
(frameworks, usage strings, protocols with mocks), §8 (the transcription fallback chain), §5.1 (Rule 1).
Same contract as R1–R5: every type, file, rule and test name is fixed here. Sections are in build order._

## Two dispatches, and why

STRATEGY puts R6 "after 10-16" because the recorder needs Perry's 16 Pro, an Apple sitting and Opus review
time, all of which StoryCue owns until its submit. Most of R6 needs none of those, so it is split:

- **R6a: CI-provable, buildable now** (§1–§6). Pure Swift plus Foundation, SwiftData and AppIntents. It covers
  the recorder reducer, the sidecar journal and its import, the transcription route, the capture coordinator
  (driven by mocks), and the launch intent as a type. **There is no `AVFoundation`, `Speech` or `WidgetKit`
  import, and no `project.yml` or `.github/` change.** Kimi builds it via `/orchestrate`. Its Done-when is CI
  green plus the §6 journal replay tests. Those tests are the CI form of PLAN §12's week-1 gate, "a lock
  mid-capture loses nothing, including transcript segments".
- **R6b: device-gated, after 10-16 and the Apple sitting** (§7–§9). It covers the real `CaptureEngine` (on
  `AVAudioEngine` + `SpeechAnalyzer`), the file transcriber, the route probe, asset prefetch, file and store
  protection, a minimal recorder screen, the widget extension target, the second App ID, profile and secret,
  `deploy.yml`, the first TestFlight upload, and Perry's device checklist. Its Done-when is that checklist
  filled in, in the handoff.

The R6a/R6b seam is the `CaptureEngine`, `FileTranscriber`, `AudioDurationProbe` and `FileProtector`
protocols (§4). CI green never means "the device path works" (PLAN §4 item 4). The handoff for each
dispatch says which rung passed.

## Scope

**R6a in:**
- new folder `Retold/Capture/` with five files: `CaptureFiles.swift`, `RecorderMachine.swift`,
  `CaptureJournal.swift`, `JournalImporter.swift`, `CaptureCoordinator.swift`;
- `Retold/Capture/TranscriptionRoute.swift`;
- `Retold/Capture/CaptureEngine.swift` (the protocols);
- `Retold/Shared/StartCaptureIntent.swift`;
- `#if DEBUG` mocks in `Retold/Capture/CaptureMocks.swift`;
- the new test files in §6 and the `ai/IDEAS.md` lines in §10.

Both new folders sit under `Retold/`, the app target's source directory, so XcodeGen picks them up with no
`project.yml` edit. **No schema change:** no `@Model` is added or retyped, no stored property is added, and
the `Capture` writers are unchanged.

**R6a out (R6b):** every Apple adapter, every view, the extension target, `project.yml`, `deploy.yml`, the
speech usage string, and asset prefetch.

**Out of R6 entirely (R7 or later):**
- onboarding UI (R6b adds only the microphone request call and asset prefetch on a bare screen);
- the typed one-line note for audio-only captures (needs a stored field; V1 freeze);
- Live Activity;
- filing or confirming anything (R6 never creates an `Episode`, `Question`, `Detail`, `Person`, `Place` or
  `Period`);
- the Action button stopping a recording;
- a maximum capture length (§10).

## Rule-1 wall for R6

R6 writes exactly one kind of persisted user content: `Capture.transcript`. Its text is **the transcriber's
final-result text, verbatim** (no trimming, no case change, no joining or splitting of segments) and it
travels transcriber → journal line → importer → `Capture.updateTranscript` / `completeTranscript`
unchanged. Volatile results are UI-only. They are never journaled and never persisted.

Nothing in R6 reads a `Detail`, `Person`, `Place`, `Period`, `Episode` or `Question` into anything. The one
foreign key R6 writes, `Capture.answersQuestionID`, is a UUID the caller passes in. R6 never reads that
question's text.

Segment times are **audio-file time** (seconds from the first sample in `audio/<id>.m4a`). That keeps every
later `VerifiedSpan` range pointing at the right seconds of audio (PLAN §5.1). §2.3 fixes the offset
arithmetic.

**Never widen an access level to make something compile.** If a `fileprivate` or `private` member is in the
way, the code is in the wrong file. Report the error.

## 1. Files on disk — `Retold/Capture/CaptureFiles.swift`

```swift
/// Where a capture's files live. Production root: Application Support/Captures (R6b passes it);
/// tests pass a temp directory. Never Caches (purgeable — StoryCue S1 lesson).
struct CaptureFiles: Sendable, Equatable {
    let root: URL
    var audioDirectory: URL { get }      // root/audio
    var journalDirectory: URL { get }    // root/journal
    func audioURL(for captureID: UUID) -> URL     // audio/<uuidString>.m4a
    func journalURL(for captureID: UUID) -> URL   // journal/<uuidString>.jsonl
    static func audioFileName(for captureID: UUID) -> String   // "<uuidString>.m4a", what Capture.audioFileName stores
    /// Creates both directories (withIntermediateDirectories: true). Idempotent.
    func prepare() throws
}

/// The Data Protection class each file gets, and when (PLAN section 1, Data Protection row).
enum ProtectionPlan {
    /// .completeUnlessOpen: the audio file and the journal at creation, so an already-open file keeps
    /// being written after the phone locks.
    static let whileRecording: FileProtectionType = .completeUnlessOpen
    /// .complete: the audio file once its capture is imported (reclassified by the importer).
    static let afterImport: FileProtectionType = .complete
}
```

`audioDirectory` is the same directory `ExportWriter.write(_:audioDirectory:to:)` takes.

## 2. The recorder reducer — `Retold/Capture/RecorderMachine.swift`

Pure: `import Foundation` only. The reducer mirrors StoryCue's `SessionMachine` (state + event → state +
effects, with the IDs generated in the reducer), with **three deliberate divergences**. Kimi must not copy
StoryCue's rules over them:

1. **Locking is not a pause.** `UIBackgroundModes: audio` keeps an active `.record` session alive while
   locked (PLAN §1). `sceneDidEnterBackground`, `sceneWillResignActive` and
   `protectedDataWillBecomeUnavailable` **do not change the phase** of a recording. Only an audio
   interruption, `mediaServicesReset`, an engine failure or the user's Stop end or pause it. StoryCue's
   video reducer pauses on background, and Retold must not.
2. **One capture is one audio file.** A pause (an interruption) keeps the file open, and Resume keeps
   writing to the same file. There are no segments-of-files.
3. **Resume is always a user action.** `interruptionEnded(shouldResume: true)` does not auto-resume (PLAN §1:
   "pause, keep the file, resume on user action").

### 2.1 Types

```swift
enum MicrophonePermission: Equatable, Sendable { case undetermined, granted, denied }

enum CaptureEndReason: String, Codable, Equatable, Sendable {
    case userStop, mediaServicesReset, engineFailed, recovered   // recovered: importer only (crash, no end record)
}

enum RecorderPhase: Equatable, Sendable {
    case idle
    case blocked(MicrophonePermission)            // start requested without .granted; nothing recorded
    case starting(captureID: UUID)                // engine start requested; nothing journaled yet
    case recording(captureID: UUID)
    case interrupted(captureID: UUID)             // file open, engine stopped, waiting for tapResume
    case stopping(captureID: UUID, reason: CaptureEndReason)
}

struct RecorderState: Equatable, Sendable {
    var phase: RecorderPhase = .idle
    var permission: MicrophonePermission
    var route: TranscriptionRoute = .audioOnly(.notChecked)  // set per capture by the coordinator before start
    var answering: UUID?                          // the question the active capture answers, if any
    var runOffset: TimeInterval = 0               // audio-file time at which the current transcriber run began
    var protectedDataAvailable: Bool
}

enum RecorderEvent: Equatable, Sendable {
    case startRequested(answering: UUID?)         // Control intent or in-app Record button
    case permissionChanged(MicrophonePermission)
    case engineStarted(captureID: UUID)
    case engineStartFailed(captureID: UUID)
    case transcriberRunStarted(captureID: UUID, audioOffset: TimeInterval)
    case finalSegment(captureID: UUID, TranscriptSegment)  // run-relative times
    case transcriberEnded(captureID: UUID, completed: Bool)
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

### 2.2 Transitions (exhaustive; any pair not listed returns `(state, [])`)

| From | Event | To | Effects, in order |
|---|---|---|---|
| `.idle`, `.blocked` | `startRequested(a)`, permission ≠ `.granted` | `.blocked(permission)` | none |
| `.idle`, `.blocked` | `startRequested(a)`, permission `.granted` | `.starting(id)` (id = `newID()`), `answering = a`, `runOffset = 0` | `startEngine(id, route)` |
| `.starting`, `.recording`, `.interrupted`, `.stopping` | `startRequested` | unchanged | none (a second Action press never starts a second capture) |
| any | `permissionChanged(p)` | `permission = p`; from `.blocked` with `p == .granted` → `.idle` | none |
| `.starting(id)` | `engineStarted(id)` | `.recording(id)` | `journal(.begin(id, CaptureFiles.audioFileName(for: id), createdAt: now, answering, route))` |
| `.starting(id)` | `engineStartFailed(id)` | `.idle`, `answering = nil` | none (nothing was journaled; R6b deletes any empty audio file) |
| `.recording(id)`, `.interrupted(id)`, `.stopping(id, _)` | `transcriberRunStarted(id, o)` | `runOffset = o` | `journal(.runStarted(id, audioOffset: o))` |
| `.recording(id)`, `.interrupted(id)`, `.stopping(id, _)` | `finalSegment(id, s)` | unchanged | `journal(.segment(id, s shifted by runOffset))` (§2.3) |
| `.recording(id)`, `.interrupted(id)`, `.stopping(id, _)` | `transcriberEnded(id, c)` | unchanged | `journal(.transcriberEnded(id, completed: c))` |
| `.recording(id)` | `interruptionBegan` | `.interrupted(id)` | `pauseEngine(id)`, `journal(.paused(id, at: now))` |
| `.interrupted(id)` | `interruptionEnded(_)` | unchanged | none |
| `.interrupted(id)` | `tapResume` | `.recording(id)` | `resumeEngine(id)`, `journal(.resumed(id, at: now))` |
| `.recording(id)`, `.interrupted(id)` | `tapStop` | `.stopping(id, .userStop)` | `stopEngine(id)` |
| `.recording(id)`, `.interrupted(id)` | `mediaServicesReset` | `.stopping(id, .mediaServicesReset)` | `stopEngine(id)` |
| `.recording(id)`, `.interrupted(id)` | `engineFailed` | `.stopping(id, .engineFailed)` | `stopEngine(id)` |
| `.starting(id)` | `mediaServicesReset`, `engineFailed` | `.idle`, `answering = nil` | none |
| `.stopping(id, r)` | `engineStopped(id, d)` | `.idle`, `answering = nil`, `runOffset = 0` | `journal(.end(id, duration: d, reason: r, endedAt: now))`, `closeJournal(id)`, then `importJournals` **only if** `protectedDataAvailable` |
| `.recording(id)`, `.interrupted(id)` | `engineStopped(id, d)` (unrequested) | `.idle`, … | as the row above with reason `.engineFailed` |
| any | `protectedDataWillBecomeUnavailable` | `protectedDataAvailable = false`, phase unchanged | none |
| any | `protectedDataDidBecomeAvailable` | `protectedDataAvailable = true`, phase unchanged | `importJournals` |
| any | `sceneDidEnterBackground`, `sceneWillResignActive`, `sceneDidBecomeActive` | unchanged | none (divergence 1) |

An event that carries a capture ID different from the phase's ID is stale and returns `(state, [])`.
`transcriberRunStarted`, `finalSegment` and `transcriberEnded` are **accepted in `.stopping`** because
`stopEngine` finalises the analyzer, and the last finals arrive after Stop. `engineStopped` is the last
event of a capture: the adapter must deliver every final and `transcriberEnded` before it (§4).

### 2.3 Time base

`finalSegment` carries times relative to the current transcriber run. The journaled segment is
`TranscriptSegment(text: s.text, start: s.start + runOffset, end: s.end + runOffset, isFinal: true)`.
The text is byte-identical. When one analyzer runs for the whole capture (the normal case: the engine
feeds the same buffers to the file and the analyzer, so analyzer time equals file time), the adapter
sends one `transcriberRunStarted(audioOffset: 0)`. If the analyzer has to be restarted mid-capture, the
adapter sends a new `transcriberRunStarted` with the file's written duration at that moment.

## 3. Sidecar journal — `Retold/Capture/CaptureJournal.swift`

### 3.1 Why a journal

The SwiftData store is `.complete`, so it is unwritable while locked (PLAN §1). Locking mid-memory is the
common case. Capture therefore writes only to its own two files, the audio and this journal, both
`.completeUnlessOpen`. The store is touched only by the importer, only while protected data is available.

**A `.completeUnlessOpen` file cannot be reopened while locked once it is closed.** So the journal's handle
is opened once at `.begin` and held until `closeJournal`. It is never closed and reopened mid-capture.

The format is **JSON Lines** (one record per line, `\n`-terminated, append-only), not StoryCue's
rewrite-the-whole-file ledger. Appending one line per final segment is O(1). Rewriting a growing file on
every segment is O(n²), and every rewrite means creating a new file.

### 3.2 Records

```swift
struct JournalRecord: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case begin, runStarted, segment, transcriberEnded, paused, resumed, end }
    let v: Int                       // format version, 1
    let kind: Kind
    let captureID: UUID
    // begin
    var audioFileName: String? = nil
    var createdAt: Date? = nil
    var answersQuestionID: UUID? = nil
    var route: String? = nil         // TranscriptionRoute.journalTag
    // runStarted
    var audioOffset: TimeInterval? = nil
    // segment (audio-file time)
    var text: String? = nil
    var start: TimeInterval? = nil
    var end: TimeInterval? = nil
    // transcriberEnded
    var completed: Bool? = nil
    // paused / resumed / end
    var at: Date? = nil              // paused, resumed, end (endedAt)
    var duration: TimeInterval? = nil
    var reason: CaptureEndReason? = nil

    static func begin(_ id: UUID, _ audioFileName: String, createdAt: Date, answering: UUID?, route: TranscriptionRoute) -> JournalRecord
    static func runStarted(_ id: UUID, audioOffset: TimeInterval) -> JournalRecord
    static func segment(_ id: UUID, _ s: TranscriptSegment) -> JournalRecord
    static func transcriberEnded(_ id: UUID, completed: Bool) -> JournalRecord
    static func paused(_ id: UUID, at: Date) -> JournalRecord
    static func resumed(_ id: UUID, at: Date) -> JournalRecord
    static func end(_ id: UUID, duration: TimeInterval, reason: CaptureEndReason, endedAt: Date) -> JournalRecord
}
```

**Encoding:** a `JSONEncoder` with `outputFormatting = [.sortedKeys, .withoutEscapingSlashes]`,
`dateEncodingStrategy = .secondsSince1970`, nil fields omitted (the synthesized `encodeIfPresent`), and one
`\n` after each record. The encoder never emits a raw newline inside a line, because JSON escapes it in
strings. The golden test in §6 fixes the exact bytes of one line of each kind.

### 3.3 Writer and reader

```swift
/// Owns one capture's open journal handle. Not an actor: the coordinator is @MainActor and owns it.
final class JournalWriter {
    /// Creates journal/<id>.jsonl with attributes [.protectionKey: ProtectionPlan.whileRecording]
    /// (fails if it exists), opens a FileHandle for writing, and keeps it open.
    init(files: CaptureFiles, captureID: UUID) throws
    /// Encodes, appends the line, then synchronize() (fsync). Throws JournalError.wrongCapture
    /// if record.captureID != captureID, .closed after close().
    func append(_ record: JournalRecord) throws
    /// Closes the handle. Idempotent.
    func close()
}

struct JournalReplay: Equatable, Sendable {
    let captureID: UUID
    let records: [JournalRecord]
    let droppedTornTail: Bool        // the last line was incomplete or undecodable and was dropped
}

enum JournalError: Error, Equatable {
    case wrongCapture, closed, alreadyExists
    case corrupt(line: Int)          // an undecodable line that is NOT the last line (1-based)
    case missingBegin                // the first record is not .begin, or there are no records
    case mixedCaptures(line: Int)    // a record's captureID differs from the begin record's
}

enum JournalReader {
    /// Reads every line. A final line with no trailing "\n", or a final line that does not decode,
    /// is dropped (droppedTornTail = true): that is a crash mid-append, and every earlier line is intact.
    /// An undecodable line anywhere else throws .corrupt. Empty lines are skipped.
    static func read(_ url: URL) throws -> JournalReplay
    /// journal/*.jsonl, sorted by file name. Ignores other files.
    static func journalURLs(in files: CaptureFiles) throws -> [URL]
}
```

## 4. Seams — `Retold/Capture/CaptureEngine.swift`, `Retold/Capture/TranscriptionRoute.swift`

### 4.1 Protocols (R6a defines, R6b implements with Apple APIs, `CaptureMocks.swift` mocks)

```swift
/// The microphone, the audio file and the live transcriber, behind one seam: on device one
/// AVAudioEngine tap feeds both the file and the SpeechAnalyzer input, so they share a clock.
protocol CaptureEngine: AnyObject, Sendable {
    /// Never prompts.
    func microphonePermission() async -> MicrophonePermission
    /// Prompts once if .undetermined (onboarding only — never called on the capture path).
    func requestMicrophonePermission() async -> MicrophonePermission
    /// Activate the audio session, create the file at `audioURL` with ProtectionPlan.whileRecording,
    /// start the engine, and start the live transcriber on `route` (none for .audioOnly).
    /// Emits .engineStarted or .engineStartFailed via `events`.
    func start(captureID: UUID, audioURL: URL, route: TranscriptionRoute) async
    func pause(captureID: UUID) async
    func resume(captureID: UUID) async
    /// Stop the engine, finalise the transcriber (its last finals and transcriberEnded are emitted
    /// first), close the file, deactivate the session; then emit .engineStopped(duration:).
    func stop(captureID: UUID) async
    /// Every RecorderEvent the engine originates: engineStarted/StartFailed, transcriberRunStarted,
    /// finalSegment, transcriberEnded, interruptionBegan/Ended, engineStopped, mediaServicesReset,
    /// engineFailed. Also volatile text for the UI, which is never journaled.
    var events: AsyncStream<CaptureEngineEvent> { get }
}

enum CaptureEngineEvent: Equatable, Sendable {
    case recorder(RecorderEvent)
    case volatile(captureID: UUID, text: String)
}

/// Re-transcribes a closed audio file (PLAN section 1: save-audio-first; transcribe from the file if
/// the live pass died). Yields final segments in audio-file time, then finishes; throws on failure.
protocol FileTranscriber: Sendable {
    func transcribe(audioURL: URL, route: TranscriptionRoute) -> AsyncThrowingStream<TranscriptSegment, Error>
}

/// The written length of a closed audio file, for a journal with no .end (crash). nil if unreadable.
protocol AudioDurationProbe: Sendable { func duration(of audioURL: URL) -> TimeInterval? }

/// Sets a file's Data Protection class. Real: FileManager.setAttributes; mock: records calls.
protocol FileProtector: Sendable { func protect(_ url: URL, as type: FileProtectionType) throws }
```

### 4.2 The transcription route (PLAN §8 fallback chain)

```swift
enum AudioOnlyReason: String, Equatable, Sendable {
    case notChecked, noLocale, assetsNotInstalled, transcriberUnavailable
}

enum TranscriptionRoute: Equatable, Sendable {
    case speech(localeID: String)        // SpeechTranscriber
    case dictation(localeID: String)     // DictationTranscriber, the older-device fallback
    case audioOnly(AudioOnlyReason)

    var journalTag: String { get }       // "speech:<id>", "dictation:<id>", "audioOnly:<reason>"
    init?(journalTag: String)            // exact inverse; nil on anything else

    /// The checked chain. Each input is probed by R6b; none is assumed.
    /// speechModuleAvailable = SpeechTranscriber.isAvailable;
    /// *Locale = supportedLocale(equivalentTo: current) mapped to its identifier, nil if unsupported;
    /// *AssetsInstalled = AssetInventory.status(forModules:) == .installed for that module + locale.
    static func select(speechModuleAvailable: Bool, speechLocale: String?, speechAssetsInstalled: Bool,
                       dictationLocale: String?, dictationAssetsInstalled: Bool) -> TranscriptionRoute
}
```

`select` rules, in order:
1. If `speechModuleAvailable`, `speechLocale` is non-nil and `speechAssetsInstalled`, return `.speech`.
2. Else if `dictationLocale` is non-nil and `dictationAssetsInstalled`, return `.dictation`. `DictationTranscriber`
   has no `isAvailable`; its locale and asset checks are the gate.
3. Else return `.audioOnly`, with the reason taken from the best rung that failed:
   - `.assetsNotInstalled` if either locale was supported but its assets were missing (the offline-first-capture
     case that PLAN §8's prefetch exists for);
   - else `.noLocale` if the speech module was available;
   - else `.transcriberUnavailable`.

The route is chosen per capture, before `startRequested`. It is never changed mid-capture. It is journaled
in `.begin`.

### 4.3 What each route writes to `Capture.transcriptionStatus`

| Journal says | Importer writes | Then |
|---|---|---|
| route `speech`/`dictation`, `transcriberEnded(completed: true)` present, `.end` present | `completeTranscript(segments)` → `.complete` | done |
| route `speech`/`dictation`, no `transcriberEnded(true)` (it died, ended false, or no `.end`) | `updateTranscript(segments, status: .live)` (possibly `[]`) | queued for the file pass (§5.3) |
| route `audioOnly` | `updateTranscript([], status: .failed)` | not queued. The typed note is R7 (§10) |

The file pass writes `updateTranscript(current, .fromFile)` when it starts, `completeTranscript(fileSegments)`
when it finishes (the file pass's segments **replace** the live partial, because the file is authoritative),
and `updateTranscript(current, .failed)` when it throws. A `.failed` capture keeps its live partial
segments. It is never deleted.

## 5. Import and the coordinator

### 5.1 `Retold/Capture/JournalImporter.swift`

```swift
@MainActor
struct JournalImporter {
    let files: CaptureFiles
    let durationProbe: any AudioDurationProbe
    let protector: any FileProtector

    struct Report: Equatable { var imported: [UUID]; var alreadyPresent: [UUID]; var failed: [URL] }

    /// Imports every journal except `excluding` (the live capture's). Caller guarantees protected
    /// data is available. Per journal, in journalURLs order:
    ///  1. JournalReader.read; on throw, add to failed, leave the file, continue.
    ///  2. If a Capture with id == captureID exists: alreadyPresent; skip to step 5.
    ///  3. Build the Capture: Capture(audioFileName: begin.audioFileName, duration:, createdAt: begin.createdAt),
    ///     then set capture.id = captureID and answersQuestionID = begin.answersQuestionID.
    ///     duration = .end's duration, else durationProbe.duration(of: audioURL), else 0.
    ///     segments = the .segment records in journal order, each TranscriptSegment(text:start:end:isFinal: true)
    ///     with text exactly as journaled. Status per section 4.3. Insert.
    ///  4. context.save(). On throw: add to failed, context.rollback(), leave the file, continue.
    ///  5. protector.protect(audioURL, as: ProtectionPlan.afterImport) if the audio file exists
    ///     (a protect error is ignored and retried on the next import: the store is already right).
    ///  6. Remove the journal file. Order 4 → 5 → 6 makes a crash anywhere safe: a re-run finds the
    ///     Capture (step 2) and only finishes 5 and 6. No duplicate Capture is ever created.
    func importAll(into context: ModelContext, excluding: UUID?) -> Report
}
```

A journal with no `.end` and no live owner is a crash orphan. It imports as described above (duration from
the probe, `.live`, queued for the file pass), with no `CaptureEndReason` stored. `.recovered` exists for the
importer's report and for logging only, because there is no field to store it in (§10). An audio file with
no journal and no `Capture` is left alone in R6 (§10).

### 5.2 `Retold/Capture/CaptureCoordinator.swift`

```swift
@MainActor @Observable
final class CaptureCoordinator {
    init(engine: any CaptureEngine, fileTranscriber: any FileTranscriber, files: CaptureFiles,
         importer: JournalImporter, container: ModelContainer,
         protectedDataAvailable: Bool, now: @escaping () -> Date = Date.init,
         newID: @escaping () -> UUID = UUID.init)

    private(set) var state: RecorderState
    private(set) var liveText: String          // finals joined by " " + the current volatile; UI only
    private(set) var journalError: JournalError?   // last append failure, surfaced to the UI (R6b/R7)

    /// Reads engine.microphonePermission(), then listens to engine.events until stop.
    func run() async
    func send(_ event: RecorderEvent)          // reduce, then execute effects in array order
    /// Picks the route for the next capture (the R6b adapter supplies the probe inputs).
    func setRoute(_ route: TranscriptionRoute)
    /// The file pass over every Capture whose status is .live or .pending and whose audio exists,
    /// excluding the active capture. Sequential. Only while protectedDataAvailable.
    func retranscribePending() async
}
```

Effect execution:
- **`startEngine`** calls `engine.start(captureID:audioURL:route:)`.
- **`.journal(.begin)`** opens a `JournalWriter` before appending. If that open throws, the coordinator sends
  `tapStop`, so the capture ends cleanly. The audio is still on disk. It sets `journalError`.
- **A failed append of any other record** sets `journalError`. Recording continues, because the audio is
  the record. The coordinator does not retry.
- **`closeJournal`** closes the writer.
- **`importJournals`** runs `importer.importAll(into: container.mainContext, excluding: active capture ID)`,
  then `retranscribePending()`.
- **The store guard:** the coordinator touches `container` **only** inside `importJournals` and
  `retranscribePending`, and both return immediately unless `state.protectedDataAvailable`. Tests make
  this observable (§6).
- **On launch, `run()` imports orphans:** after reading the permission, if `protectedDataAvailable`, it
  sends nothing and executes `importJournals` once directly.

### 5.3 Launch intent — `Retold/Shared/StartCaptureIntent.swift`

The folder is `Shared/` because R6b compiles this file into the widget extension as well. Apple: *"The system
requires the Target Membership of the app intent to be set to both the app and the widget extension to open
the app."* (WidgetKit, *Creating controls to perform actions across the system*, "Open your app with a
control", read 2026-10-04.) An intent whose `supportedModes` is `.foreground` runs `perform()` **in the app
process** once the app is foregrounded, so **no App Group is needed**: the inbox is plain in-process state.
The file may import only `AppIntents` and `Foundation`, because it must compile in the extension.

```swift
import AppIntents

/// In-process hand-off from the intent to the coordinator. Compiled into both targets; only the app's
/// copy is ever reached (foreground intent).
@MainActor final class CaptureLaunchInbox {
    static let shared = CaptureLaunchInbox()
    private(set) var pendingStarts = 0
    func request() { pendingStarts += 1 }
    /// Returns true and resets if any start is pending.
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

The coordinator gets `func drainLaunchInbox()`. On `take() == true` it sends `startRequested(answering: nil)`.
R6b's scene calls it on `sceneDidBecomeActive`. Using a counter rather than a callback means a launch that
arrives before the coordinator exists is not lost.

Check `IntentModes`' spelling against the SDK when compiling. `supportedModes` and `IntentModes` are iOS 26.0
per Apple's documentation index (read 2026-10-04). If the static's type or spelling differs, fix it to the
SDK, and record the change in the PR. Do not fall back to `openAppWhenRun`.

## 6. R6a tests — `RetoldTests/`

Every new class is **non-isolated** `XCTestCase`. Tests that touch SwiftData or the coordinator are
individually `@MainActor`. **Do not override `setUp`/`tearDown` in a `@MainActor` class.** Use
`setUpWithError()`, never `setUp() throws`, and per-test `make…()` helpers plus `addTeardownBlock` (both
bit R5). Temp directories are `FileManager.default.temporaryDirectory/<UUID>`, removed in a teardown block.

**`RecorderMachineTests.swift`**
- `testStartWithoutPermissionBlocks` (undetermined and denied, separately; no effects).
- `testGrantedPermissionUnblocks`.
- `testStartEmitsStartEngineWithRoute`.
- `testEngineStartedJournalsBegin`, which asserts the full `.begin` record, including `answering` and
  `route.journalTag`.
- `testEngineStartFailedReturnsToIdleWithoutJournal`.
- `testSecondStartWhileRecordingIsIgnored`.
- `testBackgroundAndLockDoNotPauseRecording`: from `.recording`, sends `sceneDidEnterBackground`,
  `sceneWillResignActive` and `protectedDataWillBecomeUnavailable`. The phase is still `.recording` and no
  pause effect is emitted.
- `testInterruptionPausesAndKeepsCapture`.
- `testInterruptionEndedDoesNotAutoResume` (`shouldResume: true` stays `.interrupted`).
- `testTapResumeResumesSameCapture` (same id; `resumeEngine` + `.resumed`).
- `testStopThenEngineStoppedJournalsEndAndImportsWhenUnlocked`.
- `testStopWhileLockedDoesNotImport` (effects end at `closeJournal`).
- `testFinalsAfterStopAreStillJournaled` (`finalSegment` in `.stopping`).
- `testRunOffsetShiftsSegmentTimes`: offset 0, a final at 1–2; then `transcriberRunStarted(12.5)` and a final
  at 0–1. The journal has times 1–2 and 12.5–13.5, with text byte-identical.
- `testSegmentTextIsVerbatim` (leading/trailing spaces and mixed case survive).
- `testStaleCaptureIDIsIgnored` (for each of `engineStarted`, `finalSegment`, `engineStopped`).
- `testMediaServicesResetEndsCapture` and `testEngineFailedEndsCapture` (reason in `.end`).
- `testUnrequestedEngineStoppedEndsAsEngineFailed`.
- `testUnlockEmitsImport`.

**`CaptureJournalTests.swift`**
- `testRecordLineGolden`: the exact UTF-8 line for one record of each of the seven kinds, with a fixed UUID
  and dates.
- `testRoundTripEveryKind`.
- `testWriterAppendsAndReaderReplaysInOrder`.
- `testWriterRejectsWrongCapture` and `testWriterRejectsAfterClose`.
- `testWriterRefusesExistingFile`.
- `testTornTailIsDropped`: append three records, then write half a line with no `\n`. The replay has 3
  records and `droppedTornTail == true`.
- `testUndecodableLastLineIsDropped` (a final line of `"{garbage}\n"`).
- `testCorruptMiddleLineThrows` (`.corrupt(line: 2)`).
- `testMissingBeginThrows` and `testMixedCapturesThrows`.
- `testNewlineInTextStaysOneLine` (text `"a\nb"` round-trips; the file has one line per record).
- `testJournalURLsSortedAndFiltered`.

**`TranscriptionRouteTests.swift`**
- `testSpeechWhenAllSpeechChecksPass`.
- `testDictationWhenSpeechModuleUnavailable`.
- `testDictationWhenSpeechAssetsMissing`.
- `testAudioOnlyAssetsNotInstalled`.
- `testAudioOnlyNoLocale`.
- `testAudioOnlyTranscriberUnavailable`.
- `testJournalTagRoundTrip` (all three shapes, every reason).
- `testJournalTagRejectsGarbage`.

**`JournalImporterTests.swift`** (`@MainActor`, an in-memory container, a temp `CaptureFiles`, the mock
probe and protector)
- `testCompletedJournalImportsCompleteCapture`: id, audioFileName, duration, createdAt, answersQuestionID,
  segments verbatim, status `.complete`, `completedTranscript != nil`.
- `testJournalWithoutTranscriberEndImportsLive`.
- `testAudioOnlyImportsFailedWithNoSegments`.
- `testCrashOrphanUsesProbedDuration` (no `.end`; probe 42.0).
- `testCrashOrphanWithUnreadableAudioHasZeroDuration`.
- `testImportDeletesJournalAndProtectsAudio` (protector called once with `.complete`).
- `testImportIsIdempotent`: run twice, giving one `Capture`. The second run reports `alreadyPresent`.
- `testCrashAfterSaveBeforeDeleteDoesNotDuplicate`: save a `Capture` for the id, then leave the journal.
  Import gives one `Capture`, and the journal is removed.
- `testExcludedCaptureIsNotImported`.
- `testCorruptJournalIsReportedAndLeft`.
- `testTornTailStillImportsEarlierSegments`.
- `testImporterCreatesNoOtherEntities`: after import, `Episode`, `Question`, `Detail`, `Person`, `Place` and
  `Period` counts are 0.

**`CaptureCoordinatorTests.swift`** (`@MainActor`, `MockCaptureEngine`, `MockFileTranscriber`, an in-memory
container, a temp `CaptureFiles`). The mock engine records calls and lets the test push events. A test helper
awaits until the coordinator has processed a pushed event, which keeps the tests deterministic: no sleeps.
- **`testLockMidCaptureLosesNothing`** (the week-1 gate's CI form):
  1. Start, `engineStarted`, then finals 1 and 2.
  2. `protectedDataWillBecomeUnavailable`, then final 3.
  3. `tapStop`, then final 4 and `transcriberEnded(true)`, then `engineStopped(30)`.
  4. Check that the store has 0 `Capture`s. The journal file holds `begin`, the 4 segments,
     `transcriberEnded` and `end`.
  5. `protectedDataDidBecomeAvailable`. Check for one `.complete` `Capture` with the 4 segments, verbatim and
     in order. The journal is gone, and the audio is protected `.complete`.
- `testNoStoreAccessWhileLocked`, two halves. Each half must fail if the coordinator's guard (§5.2) is
  removed, even though the reducer already withholds `importJournals` while locked:
  - **Launch half:** write a complete orphan journal by hand, then `run()` with
    `protectedDataAvailable: false`. The store has 0 `Capture`s and the journal is still on disk.
  - **File-pass half:** insert a `.live` `Capture` whose audio exists, then call `retranscribePending()`
    while locked. `MockFileTranscriber` records no call.
- `testCrashOrphanImportedOnLaunch`: write a journal by hand with no `.end`. Launch `run()` unlocked. One
  `.live` `Capture` results, and the file pass runs (mock yields 2 segments). The status is `.complete` with
  the file segments.
- `testFilePassFailureMarksFailedAndKeepsPartial`.
- `testFilePassSkipsActiveCapture`.
- `testJournalOpenFailureStopsCleanly`: pre-create the journal file, so `alreadyExists` throws. The coordinator
  sends `tapStop`, `journalError` is set, and the engine gets `stop`.
- `testAppendFailureKeepsRecording`.
- `testVolatileTextIsNeverJournaled`: push `.volatile("xyz")`. `liveText` contains it. No journal line
  contains `"xyz"`.
- `testLaunchInboxStartsCapture`: `CaptureLaunchInbox.shared.request()`, then `drainLaunchInbox()`, gives
  `startEngine`. A second drain with nothing pending does nothing.
- `testAnsweringFlowsToCapture` (`startRequested(answering: q)` gives `Capture.answersQuestionID == q`).

**`StartCaptureIntentTests.swift`** (`@MainActor`)
- `testPerformRequestsAStart`: calls `perform()` directly, and `take()` becomes true.
- `testSupportedModesIsForegroundImmediate`. If `IntentModes` is not `Equatable` in the SDK, assert through
  whatever comparison the SDK offers, or drop this test and say so in the PR.

`CaptureMocks.swift` (`#if DEBUG`) contains `MockCaptureEngine`, `MockFileTranscriber`, `MockDurationProbe`
and `MockFileProtector`. The Release compile proves no production code reaches them. Under Swift 6, a mock
with mutable recorded calls is either an `actor` (with `events` declared `nonisolated`) or a `final class`
whose state sits behind a lock, marked `@unchecked Sendable` **in the mocks file only**. Production types
do not use `@unchecked Sendable`.

## 7. R6b — Apple adapters (after 10-16)

All of these live in `Retold/Capture/Device/`. This is the only folder that may import `AVFoundation` or `Speech`.

- **`LiveCaptureEngine: CaptureEngine`.**
  - Audio session: `AVAudioSession` category `.record`, mode `.spokenAudio`, activated inside `start`, never
    before the UI is up (PLAN §1).
  - File: `AVAudioEngine` input tap → an `AVAudioFile` (AAC, `.m4a`) created with
    `ProtectionPlan.whileRecording`.
  - Transcriber: the same tap's buffers, converted with `SpeechAnalyzer.bestAvailableAudioFormat`, go into an
    `AsyncStream<AnalyzerInput>` that feeds one `SpeechAnalyzer` running the route's module (`SpeechTranscriber`
    or `DictationTranscriber`).
  - Results: volatile results go to `.volatile`. Final results go to `.finalSegment`, with times taken from the
    result's `audioTimeRange` and text from `String(result.text.characters)`.
  - Notifications: `AVAudioSession.interruptionNotification` → `interruptionBegan`/`Ended`;
    `mediaServicesWereResetNotification` → `mediaServicesReset`.
  - Pause stops the engine and keeps both the file and the analyzer open.
  - Stop calls `finalizeAndFinishThroughEndOfInput()`, drains the remaining finals, emits
    `transcriberEnded(true)`, then closes the file and emits `engineStopped(duration)`.
- **`SpeechFileTranscriber: FileTranscriber`.** `SpeechAnalyzer(inputAudioFile:modules:finishAfterFile: true)`
  with the route's module, yielding finals only.
- **`SpeechRouteProbe`**: gathers the five `TranscriptionRoute.select` inputs. **`AssetPrefetch`**:
  `AssetInventory.assetInstallationRequest(supporting:)` for the speech module (else dictation), run right
  after the microphone grant (PLAN §8).
- **`AVDurationProbe`, `FileManagerProtector`.**
- **Store protection:** after `RetoldSchema.makeContainer(url:)`, set `.complete` on the store file and its
  `-wal`/`-shm` siblings, and on the store directory so new siblings inherit. Device checklist item 6 verifies
  that the locked app never touches the store.
- **Minimal screens** (no design pass; R7 replaces them):
  - a one-screen microphone grant plus prefetch on first run;
  - a recorder screen with a red dot, elapsed time, `liveText`, Stop, and Resume when interrupted;
  - the existing placeholder as the home screen with a Record button.
  - All copy goes through `AppCopy` and passes `WellnessLint`.
- **Scene wiring:** `scenePhase` and `UIApplication.protectedDataWillBecomeUnavailableNotification` /
  `…DidBecomeAvailableNotification` become coordinator events; `drainLaunchInbox()` runs on active.
- **Widget extension `RetoldControls/`:**
  - `RetoldControlsBundle: WidgetBundle` with one `StartCaptureControl: ControlWidget`.
  - The control is a `StaticControlConfiguration(kind: "dev.pmartin1915.retold.start-capture")` wrapping
    `ControlWidgetButton(action: StartCaptureIntent())`.
  - Label "Record a memory", SF Symbol `mic.fill`, `.displayName("Record a memory")`.
  - Its sources are `RetoldControls/` and `Retold/Shared/`.

## 8. R6b — project and pipeline changes

**Usage string — decided here.** Add `NSSpeechRecognitionUsageDescription: "Turns your recording into text on
this iPhone."` (PLAN §9's wording). The key alone triggers no prompt; only `SFSpeechRecognizer.requestAuthorization`
does, and R6 never calls it. A missing key would crash if report D is right. So including it is safe under
both readings of the Sol-vs-D conflict. The device checklist then records *whether any speech prompt appears*.
If none appears, the key is removed in a later release, and the privacy policy is checked against the code
either way.

**`project.yml`:**
- **App target:** add the usage string; add `dependencies: [{ target: RetoldControls }]` (embeds the
  extension). Sources stay `Retold`, which already contains `Retold/Shared`.
- **New target `RetoldControls`:**
  - `type: app-extension`, `platform: iOS`;
  - sources `RetoldControls` and `Retold/Shared`;
  - `PRODUCT_BUNDLE_IDENTIFIER: dev.pmartin1915.retold.controls`, `PRODUCT_NAME: RetoldControls`,
    `TARGETED_DEVICE_FAMILY: "1"`, `SKIP_INSTALL: YES`;
  - Release: `CODE_SIGN_STYLE: Manual`, `CODE_SIGN_IDENTITY: "Apple Distribution"`,
    `PROVISIONING_PROFILE_SPECIFIER: "Retold Controls AppStore"`;
  - Info.plist at `RetoldControls/Info.plist`, with `CFBundleDisplayName: Retold`,
    `CFBundleShortVersionString: $(MARKETING_VERSION)`, `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`
    (these must equal the app's, or ASC rejects the upload), and
    `NSExtension: { NSExtensionPointIdentifier: com.apple.widgetkit-extension }`.
- **No App Group and no entitlements file** (§5.3).

**`build.yml`:** no change. The unsigned Debug test and the unsigned Release compile build the embedded
extension as a scheme dependency. The first R6b PR is where that is proven.

**`deploy.yml`:**
- The "Install provisioning profile" step installs **two** secrets: `PROVISIONING_PROFILE_APP` (exists) and
  `PROVISIONING_PROFILE_CONTROLS` (new). Use one loop over both, the same UUID-named copy.
- `ExportOptions.plist` `provisioningProfiles` gains `dev.pmartin1915.retold.controls` → `Retold Controls AppStore`.
- The `.ipa` verify step also checks that `Payload/Retold.app/PlugIns/RetoldControls.appex/Info.plist` exists
  and that its `CFBundleVersion` equals `$BUILD_NUMBER`.
- `CURRENT_PROJECT_VERSION` is already passed on the archive command line, so it applies to both targets.

## 9. Perry's acts and the device checklist (R6b)

**Apple sitting (short; the boss drives the browser, Perry signs in and clicks Create):**
1. App ID `dev.pmartin1915.retold.controls`, explicit, no capabilities.
2. App Store profile **"Retold Controls AppStore"** for it, with the same distribution certificate as "Retold
   AppStore" (exp 2027-03-14).
3. Perry runs `gh secret set PROVISIONING_PROFILE_CONTROLS` with the base64 of the downloaded profile (the
   classifier blocks the session from doing it).
4. A deploy smoke run with `upload=false` (archive + export with both profiles), then `upload=true` once the
   R6b PR is merged. That is the first TestFlight build.

**Device checklist on the 16 Pro (recorded in the handoff; this is R6b's Done-when):**
1. Launch to red light, in seconds, measured by screen recording, in four states: terminated/unlocked,
   terminated/locked, warm/locked, and after an interruption. A number per state; no promise.
2. A 3-minute capture with the phone locked at 0:30 and unlocked at 2:30. Every spoken sentence is in the
   transcript; the audio plays end to end.
3. A phone call (or Siri) mid-capture. The recorder shows Resume, Resume continues the same capture, and the
   transcript times line up with the audio after the gap.
4. Force-quit mid-capture, relaunch. The capture appears and is re-transcribed from the file.
5. Airplane mode before the very first capture on a fresh install, with prefetch skipped. The capture lands
   audio-only, not as an error.
6. Does **any** speech-recognition prompt appear? (Sol vs D, recorded both ways.) Does the app touch the store
   while locked (no crash, no error in the console)?
7. The Action button is set to the "Record a memory" control and works. The control appears in Control Center.

## 10. `ai/IDEAS.md` additions (append-only, R6a PR)

- 2026-10-04 (R6): the audio-only route needs a typed one-line note (PLAN §8). That is a stored field, so it waits
  for the V1 freeze; R7 builds the UI.
- 2026-10-04 (R6): store `CaptureEndReason` (including `.recovered`) on `Capture` at the V1 freeze, so the
  library can say "recovered after a crash".
- 2026-10-04 (R6): a maximum capture length, or a "still recording?" check, for a capture forgotten in a pocket
  (an accidental Action press). This is a product decision for Perry; StoryCue capped at 10 minutes.
- 2026-10-04 (R6): an audio file with neither a journal nor a `Capture` (a crash between file create and
  `.begin`). Sweep these on launch, or surface them; R6 leaves them alone.
- 2026-10-04 (R6): the Action button stopping a recording (a second press). R6 ignores a second press.
- 2026-10-04 (R6): a Live Activity for lock-screen recording status and Stop (PLAN §1: optional,
  `AudioRecordingIntent` needs one).

## Do not

- Do not import `AVFoundation`, `Speech`, `WidgetKit`, `UIKit`, `SwiftUI` or `FoundationModels` in any R6a file.
  `Retold/Shared/` imports only `AppIntents` and `Foundation`.
- Do not journal, persist or log volatile text.
- Do not alter segment text anywhere between the engine event and `Capture` (no trim, no join, no split, no
  case change).
- Do not touch the `ModelContainer` outside `importJournals` / `retranscribePending`, or there while locked.
- Do not pause, stop or change the phase on scene or protected-data events.
- Do not auto-resume after an interruption.
- Do not close and reopen a journal mid-capture.
- Do not create any entity other than `Capture`. Do not edit `Entities.swift`, `Values.swift` or any R1–R5 file.
- Do not use `openAppWhenRun` or `AudioRecordingIntent`.
- Do not run `git checkout`, `git switch`, `git reset` or `git stash` in the main checkout.
- Never widen an access level to make something compile. Report the error instead.

## Done when

**R6a:**
- CI is green: the Debug tests and the Release compile pass, and every R1–R5 test is unchanged and passing.
- Every test named in §6 exists and passes, `testLockMidCaptureLosesNothing` among them.
- `grep -rnE "import (AVFoundation|Speech|WidgetKit|UIKit|SwiftUI|FoundationModels)" Retold/Capture Retold/Shared`
  matches nothing.
- `git diff main -- Retold/Model Retold/Filing Retold/Questions Retold/Export project.yml .github` is empty.
- `ai/IDEAS.md` has the six §10 lines. `ai/STATE.md` marks R6a merged and names R6b next (after 10-16).

**R6b:** the §9 Apple sitting is done. A green deploy with both profiles uploads to TestFlight. The §9 device
checklist is filled in, in the handoff, item by item, with numbers. If an item fails, it becomes a fix PR
before R7 starts.
