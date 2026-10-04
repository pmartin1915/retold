# R7b spec: Timeline, People, Places, the pages, answering, and the export zip

_Written 2026-10-04, after R7a merged (PR #11, `85e43e0`). This turns `docs/R7-SPEC.md` §9 into a full
spec. Governing design: `docs/PLAN.md` §2 (Ask, Browse, Keep), §5.1 (Rule 1, items 2 and 5), §7 (the
engine, the retirement rule, the reinstatement line), §8 (theme cards) and §9 (the export note). The
contract is the same as R1–R7a: every type, file, rule and test name is fixed here. Decided 2026-10-04:
nudges, transcript corrections and the paid unlock are all 1.1, and 1.0 ships free (R7-SPEC §11). Target
(Perry): Retold submitted ~10-27._

## Scope

**In:**

- The Timeline on Home. It replaces R7a's Filed list.
- The People and Places lists, and a page for each person and each place.
- The episode page (verbatim transcript, audio scrubber, confirmed facts, open questions), the period
  page, and a Themes page for the R5 theme cards.
- Answering a question: *Answer now* and *Not this one* on every question row, `AnswerAttacher`, and
  the period pre-pick for answers that go through the confirm flow.
- Adding and renaming periods. Reorder is cut to 1.1 (§6).
- The export zip, sent to the share sheet from Settings with `ShareLink`.
- A shared audio player.
- New copy in `AppCopy`.

**No schema change.** No `@Model` field is added, removed or retyped. Every V1-freeze item in
`ai/IDEAS.md` stays there.

**Out:**

- Nudges and Revisit (1.1, R7-SPEC §11 item 1).
- Transcript corrections (1.1, §11 item 2). The episode page shows segments only. No correction can
  exist in 1.0.
- Deleting anything: captures, episodes, periods, people or places. §11 asks Perry about deleting an
  unfiled capture.
- Answering the when question after filing. The wheel exists only on the confirm screen. The episode
  page never offers `when.open` or `when.cue`, because the engine excludes them.
- Renaming or merging people and places. Aliases are never written (R7a).
- Extracting people and places from an answer. **This is a recorded decision.** An answer to an
  episode's question attaches straight to that episode and never runs the filing pipeline, so names
  spoken in an answer are not offered as people or places in 1.0 (IDEAS, §12).

## Rule-1 wall for R7b

R7b mostly reads. Its writes are few, and these rules hold. §9 tests each one.

1. **Nothing `.proposed` is shown as a fact** (PLAN §5.1 item 2). Every page reads facts through
   `EpisodeFacts` (§3.2), which reads a `Confirmable` only when its status is `.confirmed`, the same
   rule as `ExportLibrary`. A non-confirmed title shows as `AppCopy.untitled`.
2. **Every question shown is an `EngineOffer`'s `question.text`** (IDEAS, R5). A page never shows
   `Question.text`, so a renamed period's opener shows its current title. The single exception is the
   recorder's answering line (§7.3), which has only a question id. It uses `QuestionText.display`
   (§3.5), which re-assembles `period.slot` the same way.
3. **Questions are persisted only through `AssembledQuestion.question()`**, inside `QuestionActions`
   (§4). No view constructs a `Question`.
4. **An answer attaches only to its own question's episode**, and only when that question has an
   episode (§5). An answer to a period or theme question goes through the confirm flow. Its period is
   pre-picked because the user chose to answer that period's question. That is a user act, not a
   suggestion.
5. **Generated prose: none.** The new pages show only user words (transcript segments, typed or quoted
   titles, entity names, period titles), confirmed values, deck questions and fixed copy.

## 1. Copy: additive to `Retold/Copy/AppCopy.swift`

Append these constants, each with a `/// R7b:` doc comment, and append each to `AppCopy.all`. Remove
`filedHeader` from both the constants and `all`, because R7b's Timeline replaces the only use. Verbatim:

| Constant | Text |
|---|---|
| `untitled` | `Untitled` |
| `placesTitle` | `Places` |
| `themesTitle` | `Themes` |
| `periodsTitle` | `Periods` |
| `addPeriod` | `Add a period` |
| `renamePeriod` | `Rename` |
| `duplicatePeriod` | `There is already a period with that name.` |
| `saveButton` | `Save` |
| `cancelButton` | `Cancel` |
| `questionsHeader` | `Questions` |
| `answerNow` | `Answer now` |
| `recordingsHeader` | `Recordings` |
| `noTranscript` | `No transcript` |
| `audioMissing` | `The recording file is missing.` |
| `playButton` | `Play` |
| `pauseButton` | `Pause` |
| `answeringLabel` | `Answering` |
| `exportButton` | `Export everything` |
| `exportNote` | `Recordings may name other people.` |
| `preparingExport` | `Preparing the export…` |
| `exportFailed` | `The export could not be made. Try again.` |
| `shareExport` | `Share the export` |

`…` is U+2026. The People list's title reuses `peopleHeader` (`People`), and the "Not in a period"
section reuses `noPeriod`. `exportNote` repeats the fixed line `index.md` already carries (PLAN §9). A
when value is displayed as the year (`"1998"`), as `"\(AppCopy.whenAge) \(age)"` (`Age 12`), or, when
both are confirmed, as both joined by `" · "` (`1998 · Age 12`). That composition is display-only and
never persisted.

## 2. The audio player: new `Retold/Playback/AudioPlayback.swift`

```swift
@MainActor @Observable
final class AudioPlayback {
    private(set) var captureID: UUID?          // the loaded capture, nil when stopped
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    init(files: CaptureFiles)
    func canPlay(_ captureID: UUID) -> Bool    // the audio file exists
    func play(_ captureID: UUID, from time: TimeInterval? = nil)
    func pause()
    func seek(to time: TimeInterval)
    func stop()
}
```

The signature of `stop` is `func stop(deactivateSession: Bool = true)`.

- The URL is always `files.audioURL(for: captureID)`. Nothing else builds an audio path. `canPlay` is
  one `FileManager.fileExists` call, which is cheap enough per row.
- **`play`:**
  - If the same capture is loaded and paused, it **resumes**, seeking first if `time` is given.
  - If a different capture is loaded, stop it first with `stop(deactivateSession: false)`.
  - Then load an `AVAudioPlayer` for the URL, set the session to `.playback` and activate it. Seek to
    `time` if one is given, then play.
  - On any throw (a missing file, a decode failure, a session error), call `stop()` and return. There
    is no alert.
- **While playing**, one `Task` updates `currentTime` from `player.currentTime` every 0.25 s. If it
  sees `!player.isPlaying` without a `pause()` call, the player reached the end, and the task calls
  `stop()`.
- **`pause`** cancels the update task and keeps the capture loaded. **`seek`** clamps to
  `0...duration`.
- **`stop`:**
  - **When nothing is loaded (`captureID == nil`), it is a strict no-op.** It touches neither the
    session nor any property.
  - Otherwise it stops the player, cancels the task and resets every property. If
    `deactivateSession` is true, it then calls `setActive(false, options: .notifyOthersOnDeactivation)`,
    ignoring the error.
- **The handoff to the recorder** (Sonnet review, blocker 1). `LiveCaptureEngine.startUnsafe` sets
  `.record` and activates the session, then awaits the analyzer before audio I/O begins. A
  deactivation inside that window would kill the recording.
  - Home's record button and *Answer now* call `playback.stop()` (deactivating) **before**
    `startCapture`, while the phase is still `.idle`.
  - `RootView` calls `playback.stop(deactivateSession: false)` whenever the phase leaves `.idle` and
    `.blocked`. That covers the Control and the Action button. The recorder's own `setCategory`
    supersedes playback, so nothing is deactivated after a start has begun.
- One instance lives in `RootView`, built from `services.coordinator.files` in `RootView.init` as
  `_playback = State(initialValue: AudioPlayback(files: services.coordinator.files))`, and passed down
  with `.environment(playback)`.

No unit tests: it is a thin device adapter. The device sitting checks it (§10 step 5).

## 3. Pure page models

### 3.1 Timeline: new `Retold/Browse/Timeline.swift`

```swift
struct TimelineEpisode: Equatable, Sendable { let id: UUID; let periodID: UUID?; let createdAt: Date }

struct TimelineSection: Equatable, Sendable {
    let period: PeriodRef?          // nil = "Not in a period"
    let episodeIDs: [UUID]
}

enum Timeline {
    static func sections(periods: [PeriodRef], episodes: [TimelineEpisode]) -> [TimelineSection]
}
```

1. There is one section per period, in `(sortOrder, id.uuidString)` order. **Empty periods are
   kept.** An empty period's page is where its opener lives, so it must be reachable.
2. Each section's episodes run newest first, ordered by `(createdAt descending, id.uuidString)`.
3. An episode with `periodID == nil`, or with an id that matches no period, goes to one final section
   with `period == nil`. That section exists only if it has episodes.

### 3.2 Episode facts: new `Retold/Browse/EpisodeFacts.swift`

```swift
struct EpisodeFacts: Equatable, Sendable {
    let title: String?              // title.value only when title.status == .confirmed
    let period: PeriodRef?
    let year: Int?                  // approxYear only when .confirmed
    let age: Int?                   // approxAge only when .confirmed
    let place: EntityRef?
    let people: [EntityRef]         // sorted by (name, id.uuidString)
    let details: [String]           // Detail.text, sorted by (kind.rawValue, text, id.uuidString)
}

extension EpisodeFacts { @MainActor init(episode: Episode) }
```

Every page that shows an episode's title, when, place or people reads it from here: the Timeline row,
the episode page, and the period, person and place pages. No view reads `episode.title` or
`approxYear` directly. Period ages are not shown: nothing writes them in 1.0.

### 3.3 Capture rows

```swift
enum CaptureTranscriptState: Equatable, Sendable { case transcribing, segments([TranscriptSegment]), none }

extension CaptureTranscriptState {
    static func of(status: TranscriptionStatus, segments: [TranscriptSegment]) -> CaptureTranscriptState
}
```

This lives in `EpisodeFacts.swift`:

- `.pending`, `.live` and `.fromFile` → `.transcribing`;
- `.complete` with segments → `.segments`;
- `.complete` with none, or `.failed`, → `.none`.

A `.failed` capture with a partial transcript shows `.none`, the same reading as R7a's Unfiled row.

### 3.4 Offer targets: in `Retold/Browse/QuestionActions.swift`

```swift
enum OfferTarget {
    case episode(Episode)
    case period(Period)
    case person(Person)
    case theme
}
```

### 3.5 Question display text: new `Retold/Questions/QuestionText.swift`

```swift
enum QuestionText {
    /// Question.text, except a period.slot question with a period: re-assembled with
    /// TemplateAssembler.assemble(_:periodTitle:) on period.titleFill, falling back to Question.text
    /// on a throw.
    @MainActor static func display(_ question: Question) -> String
}
```

This is `ExportLibrary`'s local `exportText` moved out unchanged. `ExportLibrary.init` calls
`QuestionText.display` instead, and the local function is deleted. The existing export tests prove
that behaviour is unchanged.

## 4. Question actions: new `Retold/Browse/QuestionActions.swift`

```swift
enum QuestionActionError: Error, Equatable {
    case noEpisodeForPersonOffer    // the person offer's slot capture is in none of the person's episodes
}

@MainActor enum QuestionActions {
    /// The persisted Question for `offer`, inserting it if new. Saves nothing.
    static func persist(_ offer: EngineOffer, target: OfferTarget, in context: ModelContext,
                        now: Date = Date()) throws -> Question

    /// persist, markShown(at: now), save. Returns the question's id for startCapture(answering:).
    static func prepareAnswer(_ offer: EngineOffer, target: OfferTarget, in context: ModelContext,
                              now: Date = Date()) throws -> UUID

    /// persist, markShown(at: now), record(.dontRemember), save.
    static func notThisOne(_ offer: EngineOffer, target: OfferTarget, in context: ModelContext,
                           now: Date = Date()) throws
}
```

**`persist`:**

1. If `offer.existingQuestionID` is non-nil and fetches a `Question`, return it unchanged. If it is
   non-nil and not found, fall through.
2. **The double-tap guard** (Sonnet review, should-fix 5). A view's captured offer keeps
   `existingQuestionID == nil` until the next render, so a second tap would insert a duplicate. Before
   inserting, look for an existing `Question` with:
   - the same `templateID`;
   - the same phraseKey of `slots.first?.text`, or `""` when slotless;
   - the same place:
     - `.episode(e)`: in `e.questions`;
     - `.period(p)`: `period?.id == p.id`, no episode;
     - `.person(p)`: `person?.id == p.id`;
     - `.theme`: no episode, period or person.

   Fetch every `Question` and filter in memory. If one is found, return it.
3. Otherwise build `let q = offer.question.question(createdAt: now)`, `context.insert(q)`, and attach
   it by target:
   - `.episode(e)`: `e.questions.append(q)`.
   - `.period(p)`: `q.period = p`. It gets no episode (`ExportLibrary` and `PeriodState` read it there).
   - `.person(p)`: **the question must sit in an episode**, because `PersonState` sees only questions
     reachable through `person.episodes[*].questions`. With no episode it would never be seen as asked,
     and would be offered again forever. Find the episode in `p.episodes` that holds a capture whose
     `id == offer.question.slots.first?.captureID`. Then `e.questions.append(q)` and `q.person = p`.
     If there is no such episode, throw `.noEpisodeForPersonOffer` before inserting. That means: check
     first, then insert.
   - `.theme`: no relation (`ThemeState` and export routing both expect episode, period and person to be
     nil).

**`prepareAnswer` and `notThisOne`:** on a throw from `save()`, call `context.rollback()` and rethrow.
`markShown` comes first in both. The broad opener stays pending until a `broad.open` ask is shown
after the latest capture (`QuestionEngine.queue(for: EpisodeState)`). Without the mark, *Not this one*
would leave it pending forever.

The view hides *Not this one* on `broad.open`, where `.dontRemember` does nothing (`Question.record`),
as on the confirm screen.

## 5. `AnswerAttacher`: new `Retold/Browse/AnswerAttacher.swift`

```swift
@MainActor enum AnswerAttacher {
    /// Pure. True iff `answersQuestionID` is non-nil and in `questionsWithEpisode`. Transcription
    /// status is deliberately not an input: a pending answer attaches at once and never shows in Unfiled.
    nonisolated static func isAttachable(answersQuestionID: UUID?, questionsWithEpisode: Set<UUID>) -> Bool

    /// Attaches every attachable unfiled capture. Returns the attached capture ids.
    @discardableResult
    static func attachPending(in context: ModelContext) throws -> [UUID]

    /// For a capture that will go through the confirm flow: its question's period id, if the
    /// question has a period and no episode. nil otherwise (theme, unknown, none).
    static func answeredPeriodID(for capture: Capture, in context: ModelContext) -> UUID?
}
```

**`attachPending`:**

1. Fetch the unfiled captures with `#Predicate<Capture> { $0.episode == nil }`, the predicate Home
   already uses, and every `Question`. Build `questionsWithEpisode` **in memory**. Never put an enum
   or an optional chain beyond `== nil` in a `#Predicate`.
   Build a `[UUID: (Question, Episode)]` map, with no force unwraps.
2. For each capture where `isAttachable` holds:
   - `episode.captures.append(capture)`;
   - `question.record(.answered)`, **but only if `capture.duration >= minimumAnswerDuration` (2 s)**.
     A tap on *Answer now* followed by an immediate Stop still attaches, so it never shows in Unfiled,
     but it leaves the question open, because `.answered` is terminal (Sonnet review, should-fix 3). A
     duration of 0 (the importer's fallback when the probe fails) also leaves the question open. That
     is the safe direction.
   - For `broad.open`, recording `.answered` answers it, which is its documented behaviour. An answer
     to `broad.open` does not re-arm the opener (`EpisodeState`'s `broadIDs` filter).

   `static let minimumAnswerDuration: TimeInterval = 2` is a member of `AnswerAttacher`.
3. **Do not call `setExcerpt`.** The excerpt is the first telling's. If an episode's first capture had
   no words, its excerpt stays `""` (IDEAS, §12).
4. If anything was attached, `try context.save()`. On a throw, `context.rollback()` and rethrow.

**When it runs:** all three run on Home's main context, and errors are ignored with `try?`, because a
missed run retries on the next trigger.

- on Home's `onAppear`;
- on `coordinator.lastImport` change;
- on `scenePhase` becoming `.active`. This one matters because the file pass completes audio-only
  captures without setting `lastImport`.

**Order inside Home's `onAppear`: seed periods, then attach, then `handleAutoPresent`.** Home is created
fresh when the phase returns to `.idle` after Stop, so `autoPresentID` is already set on its first
appear. If auto-present ran before attaching, an episode answer would open a confirm sheet it should
not get. `handleAutoPresent`, on its `onChange` path too, calls `attachPending` first.

**The file pass and the attacher in two contexts** (Sonnet review, should-fix 4). An import kicks the
file pass, which holds its own `ModelContext`, fetches captures up front and saves later. The attacher
saves `capture.episode` from the main context in between. R7a's filer has the same overlap. A
required test, `testAttachThenStaleFilePassSaveKeepsBoth`, proves the two writes merge:

1. Context A fetches the capture.
2. The main context attaches and saves.
3. Context A calls `completeTranscript` and saves.
4. After a reopen, the capture has both its episode and the complete transcript.

**If that test fails**, the builder stops, and the boss decides the fix (re-fetch inside the file pass
before its save). The builder does not improvise one.

**The confirm path for period and theme answers.** These stay unfiled, so the existing R7a flow
presents them. Home passes `answeredPeriodID(for:in:)` to `ConfirmView` (§7.4). The confirm filer
already records `.answered` on the question at File (R7-SPEC §4 step 9).

## 6. Period editing: new `Retold/Browse/PeriodEditor.swift`

```swift
enum PeriodEditError: Error, Equatable { case emptyTitle, duplicateTitle }

@MainActor enum PeriodEditor {
    static func add(title: String, in context: ModelContext, now: Date = Date()) throws -> Period
    static func rename(_ period: Period, to title: String, in context: ModelContext) throws
}
```

**Reorder is cut from 1.0** (Sonnet review, cuts). The six seeded periods are already in age order,
and a new period appends. Add and rename cover 1.0. Reorder moves to IDEAS. This narrows R7-SPEC §9.

- **Titles** are trimmed of whitespace and newlines.
  - An empty title throws `.emptyTitle`.
  - A title equal to another period's title, compared case-insensitively after trimming both, throws
    `.duplicateTitle`.
    - The check excludes only the period being renamed. A period may be renamed to its own title,
      including a change of case only.
    - Two pre-existing periods with the same title (the confirm filer does not dedupe) can each still
      be saved unchanged.
  - Both checks run before any write.
- **`add`** inserts `Period(title:, sortOrder: max existing + 1 (0 if none), createdAt: now)` and saves.
- **`rename`** sets `period.title` and saves.
- Every throw from `save()` rolls back and rethrows.
- **No delete.** R7-SPEC §9 lists add, rename and reorder. `DefaultPeriods` already reasons about a
  user deleting every period. That reasoning stands, and delete stays out of 1.0.
- A renamed seeded period keeps its persisted `period.slot` question. Offers and the export
  re-assemble from the current title (Rule-1 wall item 2).

## 7. Screens

No design pass. Use standard SwiftUI `List` and `Form`, with every string from `AppCopy` or user data.
Navigation uses `NavigationLink(destination:)` inside Home's existing `NavigationStack`. Each page
takes its `@Model` object as `let`.

### 7.1 The question row: new `Retold/Screens/OfferRow.swift`

`OfferRow(offer:, target:)` shows `offer.question.text`, then two buttons:

- **`answerNow`**:
  1. `playback.stop()`;
  2. `let id = try QuestionActions.prepareAnswer(...)`;
  3. `await coordinator.startCapture(answering: id)`.

  The coordinator comes from the environment (§7.6).

  **Accepted in 1.0, and stated here:**
  - The phase change replaces Home, and its navigation, with the recorder. After Stop, the user is
    back at Home's root, not on the page they answered from.
  - If the microphone is blocked, the start is dropped, but the question was already marked shown.

  Both are on the device checklist.
- **`notThisOne`**: `QuestionActions.notThisOne(...)`. Hidden when `templateID == "broad.open"`.

A throw from either does nothing visible, and the row stays. Buttons inside list rows use
`.buttonStyle(.borderless)`, so that each tap hits its own button.

A **questions section** is a `Section(AppCopy.questionsHeader)` with one `OfferRow` per offer in the
engine's queue order. It is omitted when the queue is empty. Every page shows the whole queue, not
`next(...)`. The channel cap (`recentChannels`) governs what one nudge offers, and nudges are 1.1. A
page lists what is open, in the engine's order (PLAN §7: "the queue order on each page").

### 7.2 Home: `Retold/Screens/HomeView.swift`

These sections replace R7a's body, in order:

1. The record button, as today. It calls `playback.stop()` before `startCapture`.
2. **Unfiled**, unchanged from R7a.
3. A section of four `NavigationLink`s:
   - `peopleHeader` → `PeopleView`;
   - `placesTitle` → `PlacesView`;
   - `themesTitle` → `ThemesView`;
   - `periodsTitle` → `PeriodsView`.
4. **The Timeline.** One `Section` per `Timeline.sections(...)`, built from `@Query` periods and
   episodes mapped to snapshots:
   - The first row of a period section is a `NavigationLink` to `PeriodView`, labelled with the period
     title in `.headline`.
   - The "Not in a period" section's first row is `Text(AppCopy.noPeriod)` in `.headline`, and is not
     a link.
   - Then one **episode row** per episode.

**Episode row** (a view in `HomeView.swift`, reused by the period, person and place pages): a
`NavigationLink` to `EpisodeView`. Its label shows:

- `EpisodeFacts.title ?? AppCopy.untitled`;
- `episode.excerpt` in secondary style, one line, if non-empty. These are verbatim user words, the
  same line the export prints. They tell "Untitled" rows apart (Sonnet review, should-fix 6). The
  excerpt is not a `Confirmable`, so reading it directly is allowed;
- the when display (§1) in secondary style, if present;
- a play/pause button (borderless) for the episode's **first capture** by `(createdAt, id.uuidString)`,
  disabled if `!playback.canPlay(id)`. Its accessibility labels are `playButton` and `pauseButton`.

Home keeps everything else from R7a: the gear, `SettingsView`, the outcome cache, seeding and
auto-present. The `onAppear` order is fixed in §5. Add `.onChange(of: coordinator.lastImport)` and
`.onChange(of: scenePhase)` for the attacher.

### 7.3 Recorder: `Retold/Screens/RecorderView.swift`

While `coordinator.state.answering` is non-nil, it shows, above the red dot:

- `AppCopy.answeringLabel` in a secondary style;
- `QuestionText.display(q)` for the question with that id, fetched once into `@State` on appear
  through the environment's model context. If the question is not found, this line is hidden;
- `AppCopy.reinstatement` in a footnote style (PLAN §7). The Action-button path is unchanged, because
  the Control always starts with `answering: nil`.

Nothing else on the recorder changes.

### 7.4 Confirm screen: `Retold/Screens/ConfirmView.swift`

There is one addition (Sonnet review, blocker 2):

- `ConfirmView` gains `let answeredPeriodID: UUID?`, declared **after `cachedOutcome` and before
  `onOutcome`**, so that Home's trailing-closure call still compiles.
- The pre-pick goes **inside `buildDraft(outcome:)`**, the one place that calls `ConfirmDraft.make`.
  `load()` reaches it on all four paths: deck, no transcript, cached outcome and pipeline. The code:
  `var built = ConfirmDraft.make(...)`, then
  `if let id = answeredPeriodID, periods.contains(where: { $0.id == id }) { built.pick(.existing(id)) }`,
  then `draft = built`.
- **Home computes `answeredPeriodID` once per presentation.** At the moment it sets
  `selectedCapture`, on both the tap path and the auto-present path, it stores
  `AnswerAttacher.answeredPeriodID(for:in:)` in `@State`. It is never computed in the sheet closure,
  which re-evaluates on every body pass.

`ConfirmDraft` is unchanged. When the answered period equals the model's suggestion, `pick` calls
`acceptSuggestedPeriod()`, so the chip shows as accepted. That is accepted: it is the user's own
choice coinciding with the model's, and nothing is logged.

### 7.5 The pages: new files in `Retold/Screens/`

All questions come from the engine, fed by `@Query private var allQuestions: [Question]` where a state
needs it.

- **`EpisodeView.swift`** (`episode: Episode`). Navigation title: `EpisodeFacts.title ?? untitled`.
  Sections, in order:
  1. **Facts.** Shown only for facts that exist:
     - the period title, with `periodHeader` as the row label;
     - the when display;
     - the place, a link to `PlaceView`;
     - each person, a link to `PersonView`;
     - each detail, as a quoted line.
  2. **Questions:** `QuestionEngine.queue(for: EpisodeState(episode:))`, target `.episode(episode)`.
  3. **`recordingsHeader`.** For each capture by `(createdAt, id.uuidString)`:
     - a header line with the date (`.abbreviated`, `.shortened`) and `ExportManifest.formatClock(duration)`;
     - a player row:
       - a play/pause button;
       - a `Slider` over `0...capture.duration`. Use `capture.duration`, not `playback.duration`,
         which is 0 while unloaded. Its value is `playback.currentTime` while this capture is loaded,
         and 0 otherwise. An edit calls `play(capture.id, from:)` if this capture is not loaded, and
         `seek` if it is. **It is disabled when `capture.duration <= 0`** (the importer's fallback).
       - elapsed and total, as `formatClock`.

       If `!canPlay`, show `audioMissing` instead of the row;
     - the transcript, read with `CaptureTranscriptState`:
       - `.transcribing` → `transcribingLabel`;
       - `.none` → `noTranscript`;
       - `.segments` → one line per segment, `"\(formatClock(start))  \(text)"`, verbatim.

       Tapping a segment line calls `playback.play(capture.id, from: segment.start)`.
- **`PeriodView.swift`** (`period: Period`). Title: the period title.
  1. Questions: `QuestionEngine.queue(for: PeriodState(period:, questions: allQuestions))`, target
     `.period(period)`. For an empty period, this is the R5 opener.
  2. Episode rows, newest first.
- **`PeopleView.swift`.** A list of `@Query(sort: \Person.name)` people, each a link to
  `PersonView(person:)`. **`PersonView`** sits in the same file. Title: `person.name`.
  1. Questions: `QuestionEngine.queue(for: PersonState(person:))`, target `.person(person)`.
  2. Episode rows, newest first.
- **`PlacesView.swift`.** The same as People, with `placesTitle`, `PlaceView(place:)` and no questions
  section (there is no place engine).
- **`ThemesView.swift`.** Title: `themesTitle`. One section per `ThemeCards.all` card, with
  `card.title` as its header. Its rows are `OfferRow`s for
  `QuestionEngine.queue(for: card, state: ThemeState(card:, questions: allQuestions))`, target
  `.theme`. **This is a departure from R7-SPEC §9**, which put the theme entry on the period page.
  Theme questions have no period (R5, `ThemeState`), so their entry sits on Home beside People and
  Places.
- **`PeriodsView.swift`.** Title: `periodsTitle`.
  - A `List` of periods in `(sortOrder, id.uuidString)` order. There is no reordering (§6).
  - Tapping a row opens a rename sheet. An `addPeriod` row opens the same sheet, empty.
  - **The sheet:** a `TextField` with the current title or empty, plus `saveButton` and `cancelButton`.
    - Save calls `add` or `rename`.
    - `.emptyTitle` keeps the sheet open, and Save is disabled while the trimmed text is empty.
    - `.duplicateTitle` shows `duplicatePeriod` as a footnote and keeps the sheet open.
    - No alerts.

### 7.6 Root wiring: `Retold/RetoldApp.swift`

- `@State private var playback: AudioPlayback`, built once from `services.coordinator.files`.
  `RootView` is built only after the services exist, so it is initialized in `RootView.init`.
- `.environment(playback)` and `.environment(coordinator)` on the routed group. `CaptureCoordinator`
  is already `@Observable`. `OfferRow` reads it with `@Environment(CaptureCoordinator.self)`.
- In the existing `.onChange(of: coordinator.state.phase)`, add: if the new phase is not `.idle` and not
  `.blocked`, call `playback.stop(deactivateSession: false)` (§2).
- In the existing `.task`, call `ExportArchiver.sweep(workDirectory:)` before `coordinator.run()`.
- `.modelContainer` is applied to the routed group inside `RootView`'s body. `RootView` itself has no
  model context, and needs none.

### 7.7 Settings and export: `Retold/Screens/SettingsView.swift` and new `Retold/Export/ExportArchiver.swift`

```swift
enum ExportArchiver {
    /// Clears and recreates `workDirectory`, writes `manifest` into workDirectory/<name> with
    /// ExportWriter, zips that folder with NSFileCoordinator(.forUploading), copies the zip to
    /// workDirectory/<name>.zip, removes the folder, and returns the zip's URL.
    nonisolated static func makeArchive(_ manifest: ExportManifest, audioDirectory: URL,
                                        workDirectory: URL, name: String) throws -> URL
}
```

- `NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordError)`
  hands over a temporary zip URL that is **valid only inside the accessor**. Copy it out there, and
  capture any copy error in a local.
- Afterwards, throw the coordinator error if there is one, else the copy error. If neither is set
  but the zip does not exist at the target, throw `ExportArchiveError.noArchive`. The accessor may
  never run without an error being set.
- `enum ExportArchiveError: Error { case noArchive }` sits in the same file.
- `static func sweep(workDirectory: URL)` removes the directory, ignoring errors.
- **Privacy** (Sonnet review, should-fix 7). The zip holds the whole library, unencrypted, in tmp.
  `sweep` runs at the start of every export and once at launch, from `RootView`'s `.task`. Peak disk
  use is about three times the audio size: the folder copy, the coordinator's zip, then the copied
  zip. The folder is removed as soon as the zip is copied.
- ExportWriter's skipped-audio list is ignored. The manifest already lists each file, and a missing
  recording must not fail the export (R5).
- `name` is `"Retold export yyyy-MM-dd"`, in the current time zone, Gregorian calendar and
  `en_US_POSIX` locale. `workDirectory` is `FileManager.default.temporaryDirectory/RetoldExport`.
  Clearing it at the start removes the previous export's zip.

**Settings** gains a second section:

- an `exportButton` button and an `exportNote` footnote.
- **The tap:**
  1. On the main actor, fetch every Period, Episode, Capture and Question. Build `ExportLibrary`, then
     `ExportManifest.build(library, exportedAt: Date(), timeZone: .current)`.
  2. Run `makeArchive` in `Task.detached`, since the manifest is `Sendable`.
  3. While it runs, the button is replaced by a `ProgressView` and `preparingExport`.
  4. On success, the button is replaced by `ShareLink(item: zipURL)`, labelled with `AppCopy.shareExport`.
     No UIKit wrapper is used (Sonnet review, cuts). A sheet inside the Settings sheet is a known
     presentation quirk.
  5. On a throw, show `exportFailed` as a footnote. No alert.
- The audio directory is `coordinator.files.audioDirectory`. `SettingsView` gains
  `let files: CaptureFiles`, and Home passes `coordinator.files`.
- Export is never gated (PLAN §9).

## 8. What does not change

- `ConfirmDraft`, `ConfirmFiler`, `FilingPipeline` and `QuestionEngine`.
- `FoundationFilingModel.swift`, which stays boss-only.
- The schema, `project.yml` and the dependencies. New folders under `Retold/` are picked up by
  XcodeGen's `sources: - Retold`.

## 9. Tests: `RetoldTests/`

The R7a shared rules apply:

- in-memory containers and `@MainActor` test classes;
- spans from `VerifiedSpan.fixture`;
- persisted questions only through `TemplateAssembler.assemble(...).question()`, never
  `Question.fixture`, for anything the code under test writes;
- "reopen" means a fresh `ModelContext(container)`.

Engine offers come from the real `QuestionEngine` queues, never hand-built.

### 9.1 `TimelineTests.swift`

- `testPeriodsInSortOrder`
- `testEpisodesNewestFirst`
- `testEmptyPeriodKept`
- `testUnperiodedLast`
- `testNoUnperiodedSectionWhenNone`
- `testUnknownPeriodIDIsUnperioded`

### 9.2 `EpisodeFactsTests.swift`

- `testWall1ProposedTitleIsNil`: an `Episode(titleQuote:)` that was never confirmed gives
  `title == nil`.
- `testConfirmedQuoteTitleShown`
- `testTypedTitleShown`
- `testWhenYearAndAgeShown`
- `testPeopleSortedByName`
- `testPlaceAndPeriodShown`
- `testTranscriptStateMapping`: every `TranscriptionStatus`, plus `.complete` with no segments, and
  `.failed` with a partial transcript.

### 9.3 `QuestionActionsTests.swift`

- `testEpisodeOfferPersistedOnEpisode`
- `testExistingOfferReused`: the Question count is unchanged.
- `testMissingExistingIDPersistsNew`
- `testPeriodOfferHasPeriodAndNoEpisode`
- `testPersonOfferLandsInSlotEpisodeWithPerson`
- `testPersonOfferSeenAsAskedAfterPersist`: rebuild `PersonState(person:)`. The same offer now carries
  `existingQuestionID`. This is the regression the episode rule exists for.
- `testPersonOfferWithoutEpisodeThrowsBeforeInsert`
- `testThemeOfferHasNoRelations`
- `testSecondPersistOfSameNewOfferReusesQuestion`: persist the same `existingQuestionID == nil` offer
  twice. There is one Question. Cover it for each target.
- `testRetiringPersonOfferHidesSiblingsOnSameSlot`: after `notThisOne` on a people-cue offer,
  `QuestionEngine.queue(for: PersonState)` offers no other people template on that slot. This is the
  engine's negatives rule, and it is intended.
- `testPrepareAnswerMarksShownAndSaves`: after reopening, `askedCount == 1` and `lastAskedAt == now`.
- `testNotThisOneRetires`
- `testNotThisOneConsumesBroadOpener`: after it, `QuestionEngine.queue(for: EpisodeState)` no longer
  leads with `broad.open`. `now` must be later than the capture's `createdAt`.
- `testWall3PersistedQuestionsAreDeckOrigin`: every persisted `Question.origin == .deck`, with its
  `templateID` in `QuestionDeck.all`.

### 9.4 `AnswerAttacherTests.swift`

- `testIsAttachableRequiresEpisodeQuestion` (pure)
- `testNilQuestionIDNotAttachable` (pure)
- `testAttachesToQuestionsEpisode`
- `testAttachRecordsAnswered`
- `testAttachLeavesExcerpt`
- `testAttachIgnoresTranscriptionStatus`: a `.pending` capture attaches.
- `testPeriodQuestionAnswerStaysUnfiled`
- `testThemeQuestionAnswerStaysUnfiled`
- `testUnknownQuestionStaysUnfiled`
- `testFiledCaptureUntouched`
- `testNothingToAttachSavesNothing`: returns `[]`, and `context.hasChanges == false`.
- `testAnsweredPeriodIDForPeriodQuestion`
- `testAnsweredPeriodIDNilForThemeAndEpisodeQuestions`
- `testShortAnswerAttachesButQuestionStaysOpen`: a duration of 1.5 s, and also 0.
- `testBroadOpenAnswerDoesNotRearmOpener`: after attaching an answer to `broad.open`,
  `EpisodeState(episode:)` gives the same `latestCaptureAt` as before.
- `testPersonQuestionAnswerLandsOnSlotEpisode`
- `testAttachThenStaleFilePassSaveKeepsBoth` (§5, two contexts). If it fails, stop and report.
- `testThemeAnswerFiledLeavesThemeQueue`: a theme answer goes through `ConfirmFiler.file`. After that,
  `ThemeState` shows the question `.answered`, and the card's queue no longer offers it.

### 9.5 `PeriodEditorTests.swift`

- `testAddAppendsSortOrder`
- `testAddTrims`
- `testAddEmptyThrows`
- `testAddDuplicateThrowsCaseInsensitive`
- `testRenameTrims`
- `testRenameDuplicateThrows`
- `testRenameToOwnTitleAllowed`
- `testRenameWithPreexistingDuplicateAllowed`: two periods share a title, and each can be saved
  unchanged.
- `testFailedEditWritesNothing`: the Period count and titles are unchanged after each throw.

### 9.6 `QuestionTextTests.swift`

- `testPeriodSlotUsesCurrentTitle`: rename the period, and the display text follows.
- `testOtherQuestionUsesStoredText`
- `testPeriodSlotFallsBackOnAssembleThrow`: a period retitled to whitespace only makes the assembler
  throw `.emptySlot`, so the display is the stored text.

### 9.7 `ExportArchiverTests.swift`

All of these run in a temp directory, with a tiny manifest of one text file and one audio file.

- `testArchiveIsZip`: the file exists, its size is greater than zero, and its first four bytes are
  `50 4B 03 04`.
- `testArchiveNamed`: `<name>.zip` directly in the work directory.
- `testWorkFolderRemoved`: the unzipped folder is gone.
- `testSecondRunReplacesFirst`: only one zip remains.
- `testMissingAudioDoesNotFail`
- `testSweepRemovesWorkDirectory`

Unzipping to check the layout would need a dependency, so the device sitting opens the zip (§10).
Whether `.forUploading` works on the CI simulator is unverified. That is why the archiver is built
and pushed early in the file order (§10), before the screens.

### 9.8 Existing tests

- `WellnessLintTests` picks up the new copy through `AppCopy.all`.
- The `ExportManifestTests` must pass unchanged after the `QuestionText` move.
- Drop any reference to `filedHeader`.

## 10. Build order and lanes

1. **Boss:** this spec, plus a Sonnet spec review (fresh context) folded before dispatch.
2. **Executor:** Kimi, if its weekly quota is back. Check with one tiny call. **If the 403 offers paid
   extra usage, decline it and use Sol (Money Rule).** Otherwise Sol, by codex-exec. The file order:
   1. `AppCopy.swift` (§1)
   2. `ExportArchiver.swift` (§7.7), then `ExportArchiverTests`. **Push and get CI green before
      going on**, because `.forUploading` on the simulator is unverified.
   3. `QuestionText.swift`, then the `ExportManifest.swift` call-site change (§3.5), then
      `QuestionTextTests`
   4. `Timeline.swift` and `EpisodeFacts.swift` (§3.1–3.3), then `TimelineTests` and `EpisodeFactsTests`
   5. `QuestionActions.swift` (§4), then `QuestionActionsTests`
   6. `AnswerAttacher.swift` (§5), then `AnswerAttacherTests`. Run the two-context test early.
   7. `PeriodEditor.swift` (§6), then `PeriodEditorTests`
   8. `AudioPlayback.swift` (§2)
   9. `OfferRow.swift`, `EpisodeView.swift`, `PeriodView.swift`, `PeopleView.swift`, `PlacesView.swift`,
      `ThemesView.swift`, `PeriodsView.swift`
   10. `HomeView.swift`, `RecorderView.swift`, `ConfirmView.swift`, `SettingsView.swift`
   11. `RetoldApp.swift` (§7.6)
3. **Boss:** a Swift 6 pitfall sweep before the first CI push. That covers explicit return types on
   multi-statement `map`/`compactMap` closures (R7a CI round 1), `nonisolated` on the pure statics,
   `Sendable` captures in `Task.detached`, and the `NSFileCoordinator` error pointer.
4. **Review.** The model that types it does not review it.
   - The Sonnet `reviewer` on the diff.
   - Then a cross-family pass from whichever of Kimi or Sol did not type it.
   - R7b does not touch the model session. Its one confirm-flow change is the period pre-pick (§7.4),
     so the Sol Rule-1 review that PLAN §10 requires for confirm-flow diffs runs on that hunk and on
     the Rule-1 wall above. If Sol typed the diff, Kimi or Sonnet stands in, and the record says so.
5. **Device**, added to Perry's sitting after 10-16:
   - browse Timeline, People and Places;
   - play a capture from a row, and scrub on the episode page;
   - tap a segment to seek;
   - Answer now on an episode question: the answer lands on that episode and never shows in Unfiled;
   - Answer now on an empty period's opener: the confirm sheet opens with that period picked;
   - rename a period, and add one;
   - export, then open the zip in Files and check `index.md`, `transcripts/` and `audio/`;
   - start a recording from the Control while audio plays: playback stops and recording works;
   - start a recording from the Control with nothing playing: recording works (§2, blocker 1);
   - Answer now, then Stop at once: the question is still offered;
   - after an answer, Home's root shows (accepted, §7.1);
   - the broad opener sits at the top of each episode page until it is answered (PLAN §7). Check that
     this does not read as nagging.

## 11. Open for Perry

1. **Deleting an unfiled capture in 1.0?** Today a botched recording cannot be removed. It can only
   be filed. Deleting means removing the `Capture`, its audio and any leftover journal, and that is
   the app's first destructive action. Boss recommendation: 1.1. Nothing is lost by keeping a
   recording, and a delete that also removes the audio needs its own small spec and a confirmation.
   If Perry wants it in 1.0, it becomes R7c: unfiled captures only, swipe to delete, one confirmation.

## 12. `ai/IDEAS.md` additions (append-only, in the R7b PR)

- 2026-10-04 (R7b): an answer to an episode's question attaches directly and skips the filing
  pipeline, so people and places spoken in an answer are not offered. A 1.1 option: run the pipeline
  on the attached answer, and offer only chips that are new to the episode.
- 2026-10-04 (R7b): an episode whose first capture had no words keeps an empty excerpt after an answer
  attaches. Set it from the first worded capture, which needs a rule for which capture "first" is.
- 2026-10-04 (R7b): answering the when question after filing (the wheel on the episode page) is 1.1.
- 2026-10-04 (R7b): the export ignores ExportWriter's skipped-audio list. Surface a count if device use
  shows missing files.
- 2026-10-04 (R7b): the theme entry sits on Home, not on the period page, because theme questions have
  no period.
- 2026-10-04 (R7b): deleting captures, episodes and periods is not in 1.0 (§11 item 1, pending Perry).
- 2026-10-04 (R7b, Sonnet review cut): reordering periods is 1.1. `PeriodEditor.move` should sort by
  `(sortOrder, id.uuidString)`, apply `Array.move`, and rewrite `sortOrder` contiguously.
- 2026-10-04 (R7b): after Answer now, the user lands on Home's root, not the page they answered from.
  Restoring the navigation path is 1.1.
- 2026-10-04 (R7b): a short answer (under 2 s) attaches but leaves its question open. Tune the
  threshold after device use.

## 13. Review record

Sonnet spec review, 2026-10-04 (fresh context; Sonnet, not Sol): APPROVE WITH CHANGES, with 2
blockers, 10 should-fix, cuts and nits. No Rule-1 violations were found. Adjudication:

- **Blocker 1** (stop deactivating the recorder's session): taken. §2 makes `stop` a no-op when idle,
  and the phase hook does not deactivate.
- **Blocker 2** (ConfirmView hunk against code that does not exist): taken. §7.4 puts the pre-pick in
  `buildDraft`.
- **Should-fix 3–10, 12:** all taken: short answers, the two-context test, the double-tap guard,
  excerpt lines, the tmp sweep plus the `noArchive` check, the slider range, ordering (now moot),
  duplicate titles, and the missing tests.
- **Should-fix 11** (navigation lost after answering; markShown when blocked): accepted and stated in
  §7.1. Not changed.
- **Cuts:**
  - Reorder: taken.
  - ActivityView → `ShareLink`: taken.
  - Scrubber: **declined**. PLAN §2 names it, and the range fix removes the risk.
  - Person-page questions: **kept**. They are the boss's fallback if the schedule slips.
- **Nits:**
  - Taken: the episode map, `State(initialValue:)`, `answeredPeriodID` computed once, both-values
    when display, and the early archiver CI.
  - Not changed: `canPlay` caching, because one `fileExists` per row is cheap.

## Do not

- Do not show `Question.text` on a page. Show `EngineOffer.question.text`, or `QuestionText.display`
  on the recorder only.
- Do not read `episode.title`, `approxYear` or `approxAge` in a view. Use `EpisodeFacts`.
- Do not construct a `Question` outside `QuestionActions.persist` (and the R7a filer).
- Do not attach an answer to any episode but its own question's, and do not attach when that question
  has no episode.
- Do not call `setExcerpt` from the attacher.
- Do not put an enum in a `#Predicate`.
- Do not build an audio path except with `CaptureFiles.audioURL(for:)`.
- Do not start a capture without stopping playback first.
- Do not show an alert. Every failure in R7b is a footnote or nothing.
- Do not add a schema field, a dependency, or a `project.yml` change.
- Do not add user-facing strings outside `AppCopy`.
- Do not edit `FoundationFilingModel.swift`, `ConfirmDraft.swift` or `ConfirmFiler.swift`.

## Done when

- CI is green (Debug tests and Release compile), and every §9 test is present and passing.
- The Sonnet review is APPROVE, and the cross-family review has its findings adjudicated.
- A TestFlight build with R7b is uploaded for Perry's device sitting.
- `ai/STATE.md` is updated, and the §12 lines are appended to `ai/IDEAS.md`.
