# R7 spec — Foundation filing model, confirm-before-file flow (R7a); Timeline, People, Places (R7b)

_Written 2026-10-04. Sonnet spec review folded the same day: 4 blockers, 9 should-fix, test gaps and 4
cuts, all taken except where §13 says otherwise. Step R7 of `../storycue/docs/STRATEGY-2026-09-22.md`.
Governing design: `docs/PLAN.md` §2 (File, Browse), §5.1 (Rule 1, every item), §5.3 (Rule 3), §6.1–6.3 (entities,
the `@Generable` schema, the confirm-before-file flow, windowed extraction), §8 (no-model mode). Same
contract as R1–R6: every type, file, rule and test name is fixed here. **R7a is specified in full and
built first. R7b is fixed at scope level only (§9)** and is detailed after R7a merges, because its
screens read what R7a's filer writes. Target (Perry, 2026-10-04): Retold submitted ~10-27._

## Two dispatches, and why

- **R7a: model, confirm flow, filer.** The Rule-1 core. The first code that turns a model's output into
  persisted facts. CI proves everything except the model call itself.
- **R7b: browse, ask and keep.** Timeline, People, Places, the episode and period pages, answering a
  question, the share sheet. It is read-mostly and depends on R7a's write shapes.

R7a is split again by who types it:

- **Boss-typed:** §2, `Retold/Filing/FoundationFilingModel.swift`, plus §8.4 and §8.5. It sits against an
  SDK nobody here has compiled. **Done:** PR #11's first commit.
- **Kimi-typed:** §1 and §3–§8, in the file order of §10.

## Scope (R7a)

**In:** `FoundationFilingModel` and its availability adapter and token counter (done); a pure
`ConfirmDraft` value, which is the screen's state and is unit-tested; `ConfirmFiler`, the only code that
turns a proposal into persisted facts; the confirm screen (the same screen for model and deck modes);
Home's Unfiled and Filed lists; auto-present after Stop; the Suggestions setting; seeding the default
periods. New copy goes in `AppCopy`.

**No schema change.** No `@Model` field is added, removed or retyped. Proposals live in memory only.
The only persisted trace of a proposal is `Capture.rejectedProposals`, which has existed since R1. So
R7a needs no V1 freeze, and every V1-freeze item in `ai/IDEAS.md` stays there.

**Out (R7a):**

- **Answering a question** ("Answer now", `AnswerAttacher`, the answer capture's preferred period). It
  moves to R7b, where the episode and period pages are its entry points. In R7a a follow-up row offers
  only *Later* and *Not this one*. Captures still carry `answersQuestionID` from R6. R7a's filer marks
  that question answered when the capture is filed (§4 step 9). It is harmless today and correct later.
- Detail tagging (the PLAN §6.1 note). Moved to 1.1 (IDEAS). `Detail(quote:kind:)` is unchanged.
- **Transcript corrections UI.** It brings the retire-on-correction and re-transcription questions (IDEAS,
  R6 and Sol R2 finding 5). **Open for Perry, §11 item 2.** No correction can exist until a correction UI
  does, so 1.0 is safe either way.
- **Nudges** (notifications). **Open for Perry, §11 item 1.** Boss recommendation: 1.1.
- **Typed-person questions.** A person the user types, as opposed to a verified span, gets **no**
  `who.person` or other people question in 1.0. `TemplateAssembler` takes only verified spans or a
  `PeriodTitleFill`. The sealed `PersonNameFill` is the IDEAS item already logged at R5.
- **Alias matching.** Nothing in 1.0 writes `Person.aliases`, so person and place matching uses names only.
- Everything in §9 (R7b).

## Rule-1 wall for R7a

R7a is where model output first meets persistence. These hold, and §8 tests each one:

1. **The model file cannot write facts.** `FoundationFilingModel.swift` is the only file that may
   `import FoundationModels`. It produces a `WindowExtract` and nothing else. `ModelBoundaryTests` (§8.4)
   fails in two cases:
   - the file names any of `ModelContext`, `insert(`, `Person(`, `Place(`, `Episode(`, `Question(`,
     `Period(`, `Detail(`, `import SwiftData` (comments included; `Set.insert` is also banned there);
   - any other file under `Retold/` imports `FoundationModels`.

   This is the R1 audit's "module that cannot see the persistence constructors", done as a test.
2. **Only `ConfirmFiler` writes facts from a proposal.** It reads a `ConfirmDraft` and writes only what
   the draft marks `.accepted`, picked or typed. A **chip** still `.suggested` at File time is **not**
   written and **not** logged.
   **Follow-up rows are not chips.** They are assembled deck questions (PLAN §6.2 step 2) and are
   persisted by default (`.later`). That includes rows slotted with referent and time-cue spans, which
   have no chip. They are questions, not facts: nothing about the memory is asserted by keeping one.
3. **Every string the filer persists has one of four sources:** a verified span's own text, a
   user-typed string (trimmed), an existing entity's stored name, or an `AssembledQuestion`'s text. The
   draft holds no other kind of string.
4. **Nothing `.proposed` is persisted.** The title is written already confirmed (`confirmTitle()` before
   the first save) or typed. Periods, people and places have no proposed state on disk. They are
   attached only if accepted, picked or typed.
5. **The user's when-answer is only ever the user's.** The wheel starts on a blank row, and `when` stays
   `.notSure` until the user moves the wheel off it (§6). A default wheel position never files a year.
6. **Questions come only from `AssembledQuestion.question()`.** The filer never builds a template.
7. **Rejections are logged.** A rejected chip becomes `Capture.logRejected` at File time. There is no
   re-offer filter in 1.0. Rejections are logged only at File, and a filed capture never reopens the
   confirm screen, so a filter would have nothing to act on (IDEAS).

## 1. Copy — additive to `Retold/Copy/AppCopy.swift`

Append these constants, each with a `/// R7a:` doc comment, and append each to `AppCopy.all` so that
`WellnessLintTests` checks them. Remove `homePlaceholder` from both the constants and `all`. Verbatim:

| Constant | Text |
|---|---|
| `unfiledHeader` | `Unfiled` |
| `filedHeader` | `Filed` |
| `transcribingLabel` | `Transcribing…` |
| `noTranscriptLabel` | `No transcript — you can still file it` |
| `fileButton` | `File it` |
| `suggestedLabel` | `suggested` |
| `acceptButton` | `Use this` |
| `rejectButton` | `Not this` |
| `titleHeader` | `Title` |
| `titlePlaceholder` | `Type a title` |
| `periodHeader` | `Period` |
| `noPeriod` | `Not in a period` |
| `newPeriod` | `New period…` |
| `newPeriodPlaceholder` | `Name the period` |
| `whenHeader` | `When` |
| `whenYear` | `Year` |
| `whenAge` | `Age` |
| `notSure` | `Not sure` |
| `peopleHeader` | `People` |
| `placesHeader` | `Place` |
| `addPerson` | `Add a person` |
| `addPlace` | `Add a place` |
| `sameAs` | `Same as` |
| `newPerson` | `New person` |
| `newPlace` | `New place` |
| `followUpsHeader` | `Questions for later` |
| `later` | `Later` |
| `notThisOne` | `Not this one` |
| `findingSuggestions` | `Looking for names and places…` |
| `skipSuggestions` | `Skip suggestions` |
| `settingsTitle` | `Settings` |
| `suggestionsToggle` | `Suggestions` |
| `suggestionsFootnote` | `Suggestions are made on this iPhone.` |

`…` is U+2026; `—` is U+2014. `placesHeader` is singular because an episode has one place. `sameAs` is
followed by the entity's stored name at the call site (`"\(AppCopy.sameAs) \(name)"`). That composition
is display-only and is never persisted.

## 2. `FoundationFilingModel` — `Retold/Filing/FoundationFilingModel.swift` (BOSS, done in PR #11)

As built. This section is the record. Kimi does not edit this file.

- A `fileprivate` `@Generable` mirror of PLAN §6.2's `WindowExtract`: the six fields, their guides
  verbatim, `.maximumCount` bounds 8/8/4/8, never an exact count (PLAN open loop 2). It maps field for
  field onto the plain R2 `WindowExtract`. Nothing outside the file sees a generable type.
- `struct FoundationFilingModel: FilingModel`:
  - It builds a **fresh** `LanguageModelSession(instructions:)` per window and uses greedy sampling.
  - Each window has a `perWindowTimeout` (30 s), raced in a task group; the timeout throws `.timeout`.
  - The prompt is built by `static func prompt(for:periodTitles:)`: `Periods: ` + titles joined by
    `" | "`, a blank line, `Transcript:`, then the window's `isFinal` segment texts joined by single
    spaces.
  - The instructions are the extraction-only text of PLAN §5.1 item 7.
- Error mapping `LanguageModelSession.GenerationError` → `FilingModelError`:

  | SDK error | `FilingModelError` |
  |---|---|
  | refusal, guardrailViolation | `.refused` |
  | assetsUnavailable | `.assetsNotReady` |
  | unsupportedLanguageOrLocale | `.unsupportedLocale` |
  | decodingFailure, unsupportedGuide | `.decodingFailure` |
  | exceededContextWindowSize | `.contextExceeded` |
  | rateLimited, concurrentRequests | `.rateLimited` |
  | `CancellationError` | `.cancelled` |
  | unknown or other | `.other` |

  Every case lands in `.noModel` through `FilingPipeline`, never in an alert.
- `ModelAvailability.init(SystemLanguageModel.Availability)` and `static var current`, with
  `@unknown default` → `.unknown` at both levels.
- `struct DeviceTokenCounter: TokenCounter` returns 0 for `""`, otherwise `max(1, (count + 2) / 3)`.
  **This is a dated deviation from PLAN §6.3 item 1, 2026-10-04.** `tokenCount(for:)` is iOS 27, and
  the floor is iOS 26. Characters ÷ 3 over-counts English, which is the safe direction: windows only
  get smaller.
  - With the pipeline's defaults (1,600 / 200), a multi-segment window holds at most about 4,800
    characters, about 1,200 real tokens.
  - A single segment longer than the budget gets its own uncut window (`WindowChunker`). Such a window
    can exceed that, and if it overflows the context it throws `.contextExceeded` → deck path, which is
    safe. The device sitting (§10 step 5) watches for it.
  - PLAN §6.3 carries a dated note pointing here.

## 3. The draft — new `Retold/Filing/ConfirmDraft.swift`

Pure value types: `Sendable`, `Equatable`, no SwiftData, no SwiftUI. This is the screen's whole state.
Template ids are always the `FilingTemplates` constants (`FilingTemplates.when.id`, `.whenWithCue.id`,
`.who.id`, `.sensoryPlace.id`, `.broad.id`), never string literals.

### 3.1 Inputs

```swift
/// A snapshot of an existing Person or Place, so the draft never holds a @Model.
struct EntityRef: Equatable, Sendable { let id: UUID; let name: String }

/// A snapshot of an existing Period.
struct PeriodRef: Equatable, Sendable { let id: UUID; let title: String; let sortOrder: Int }
```

### 3.2 State

```swift
enum ChipState: Equatable, Sendable { case suggested, accepted, rejected }

struct SpanChip: Equatable, Sendable, Identifiable {
    let id: UUID                 // draft-local, from make's makeID
    let span: VerifiedSpan
    var state: ChipState = .suggested
    /// People and places only: the first existing entity (input order) whose name has the same
    /// SpanVerifier.phraseKey as span.text. nil for the title chip.
    let match: EntityRef?
    /// When `match` is non-nil: true = file as that entity (default), false = make a new one.
    var useMatch: Bool = true
}

enum PeriodPick: Equatable, Sendable {
    case none                        // "Not in a period"
    case existing(UUID)
    case new(String)                 // typed title, trimmed at File time
}

enum WhenAnswer: Equatable, Sendable { case notSure, year(Int), age(Int) }

enum TypedEntity: Equatable, Sendable { case existing(UUID), new(String) }

enum RowChoice: Equatable, Sendable { case later, notThisOne }

struct FollowUpRow: Equatable, Sendable, Identifiable {
    let id: UUID
    let question: AssembledQuestion
    var choice: RowChoice = .later
}

enum ResolvedTitle: Equatable, Sendable { case typed(String), quote(VerifiedSpan) }

struct ConfirmDraft: Equatable, Sendable {
    let captureID: UUID
    var titleChip: SpanChip?
    var typedTitle: String = ""
    let suggestedPeriod: PeriodRef?          // the model's pick, resolved; nil if none
    var periodSuggestionState: ChipState = .suggested   // meaningful only if suggestedPeriod != nil
    var periodPick: PeriodPick = .none
    let whenQuestion: AssembledQuestion
    var when: WhenAnswer = .notSure
    var people: [SpanChip]
    var typedPeople: [TypedEntity] = []
    var places: [SpanChip]
    var typedPlace: TypedEntity? = nil
    var followUps: [FollowUpRow]
}
```

### 3.3 Building one

```swift
extension ConfirmDraft {
    static func make(captureID: UUID,
                     outcome: FilingOutcome?,          // nil: no transcript, or suggestions skipped
                     periods: [PeriodRef],
                     people: [EntityRef],
                     places: [EntityRef],
                     makeID: () -> UUID = UUID.init) -> ConfirmDraft
}
```

1. **Deck path.** When `outcome == nil` or `.noModel`: no chips, `suggestedPeriod = nil`, and the
   questions of `TemplateAssembler.followUps(from: MergedExtract())` split as in item 3 (today that is
   `when.open` plus one `broad.open` row). This is PLAN §8's "manual filing screen = the confirm screen
   with empty fields".
2. **`.proposal(merged, questions)`:**
   - `titleChip` = `merged.titleSpan` as a chip.
   - `people` / `places` = one chip per span, in order, with `match` resolved against the `people` /
     `places` arrays. **A span is offered as a chip only if
     `try? TemplateAssembler.assemble(FilingTemplates.who, slots: [span])` succeeds**: the same
     function-word guard the assembler uses, so "he" or "that" never becomes a Person or Place. The
     place check uses `FilingTemplates.sensoryPlace`.
   - `suggestedPeriod` = the first `PeriodRef` whose `title` equals `merged.periodTitle` exactly (the
     merger already canonicalised the spelling).
3. **Splitting the questions.** `whenQuestion` = the first question whose `templateID` is
   `FilingTemplates.when.id` or `.whenWithCue.id`. **If there is none** (a verified time cue that is all
   function words, such as "then", makes the assembler refuse `when.cue`), it is the `when.open`
   question from `TemplateAssembler.followUps(from: MergedExtract())`. `followUps` = every other
   question, in order, one `FollowUpRow` each.
4. Every `id` comes from `makeID`, so tests can make two drafts equal.
5. The model's period is **not** pre-picked: it shows as a suggested chip until tapped (Rule 1 item 2).

### 3.4 Mutators and derived values

All on `ConfirmDraft`. Each mutator is a no-op on an id it does not find. Typed strings are stored as
given and trimmed of whitespace and newlines when compared or filed.

- `acceptTitle()`, `rejectTitle()` set `titleChip?.state`.
- **Period:**
  - `acceptSuggestedPeriod()`: `periodSuggestionState = .accepted`, `periodPick = .existing(id)`.
  - `rejectSuggestedPeriod()`: `.rejected`; if `periodPick` was `.existing(thatID)` it becomes `.none`.
  - `pick(_ p: PeriodPick)`: `pick(.existing(suggestedPeriod.id))` behaves exactly like
    `acceptSuggestedPeriod()`. Any other pick sets `periodPick`. If the suggestion was `.accepted`, it
    goes back to `.suggested`: choosing something else is not a rejection.
- **People and place chips:**
  - `setChip(_ id: UUID, _ state: ChipState)`.
  - **Places are single-select** (`Episode.place` holds one). Accepting a place chip sets every other
    `.accepted` place chip back to `.suggested` and sets `typedPlace = nil`.
  - `setUseMatch(_ id: UUID, _ value: Bool)`.
- **Typed people:**
  - `addTypedPerson(_ e: TypedEntity)`. It is ignored in each of these cases:
    - a `.new` name that is empty after trimming;
    - an `.existing` id already in `typedPeople`;
    - a `.new` whose phraseKey matches a `.new` already there;
    - a `.new` whose phraseKey matches an `.accepted` person chip's span, or the name of an
      `EntityRef` passed to `make` (keep the people refs in the draft for this; the user picks the
      existing person instead).
  - `removeTypedPerson(at index: Int)`.
- **Typed place:** `setTypedPlace(_ e: TypedEntity?)`. A `.new` that is empty after trimming sets nil.
  A non-nil value sets every `.accepted` place chip back to `.suggested`.
- `setWhen(_ w: WhenAnswer)` and `setRow(_ id: UUID, _ choice: RowChoice)`.
- `var resolvedTitle: ResolvedTitle?`: `typedTitle` trimmed, if non-empty, wins; otherwise the title
  chip if `.accepted`; otherwise nil. `var canFile: Bool { resolvedTitle != nil }`. The title is the
  one required field (PLAN §6.2: "tap to accept, or type one").
- `func isLive(_ row: FollowUpRow) -> Bool`. **False** for a `who.person` row whose slot is not the
  span of an `.accepted` person chip, and for a `sensory.place` row whose slot is not the span of the
  `.accepted` place chip. **True** otherwise. The view hides a non-live row and the filer never writes it.

The draft keeps the `people` and `places` `EntityRef` arrays it was made with, as `let` properties
(`knownPeople`, `knownPlaces`), for the dedupe rules above and for the view's menus.

## 4. The filer — new `Retold/Filing/ConfirmFiler.swift`

```swift
struct FilingResult {
    let episode: Episode
    let questionsByRowID: [UUID: Question]   // persisted follow-ups, keyed by FollowUpRow.id (R7b uses it)
}

enum ConfirmFilerError: Error, Equatable {
    case cannotFile           // draft.canFile == false
    case wrongCapture         // capture.id != draft.captureID, or a quote title's span is another capture's
    case alreadyFiled         // capture.episode != nil
}

@MainActor enum ConfirmFiler {
    @discardableResult
    static func file(_ draft: ConfirmDraft, capture: Capture, in context: ModelContext,
                     now: Date = Date()) throws -> FilingResult
}
```

The guards run first, in this order, and each throws before any write:

1. `.wrongCapture`, which also covers `resolvedTitle == .quote(span)` with
   `span.captureID != capture.id`;
2. `.alreadyFiled`;
3. `.cannotFile`.

Then the writes. **The order is fixed**, because `setExcerpt` refuses a capture that is not attached
yet (R4.5) and `answerWhen` needs `whenQuestion` set:

1. **Episode.** `.typed(s)` → `Episode(typedTitle: s trimmed, createdAt: now)`. `.quote(span)` →
   `Episode(titleQuote: span, createdAt: now)` then `confirmTitle()`. Then `context.insert(episode)`.
2. **Capture.** `episode.captures.append(capture)`. If `capture.completedTranscript` is non-nil,
   `episode.setExcerpt(from:)` with it. Otherwise the excerpt stays `""`.
3. **Period.**
   - `.existing(id)`: fetch it. If found, `episode.period = it`; if missing (deleted meanwhile), nil.
   - `.new(title)`, trimmed and non-empty: insert
     `Period(title:, sortOrder: max existing sortOrder + 1 (0 if none), createdAt: now)` and attach it.
     Empty after trimming → nil.
   - `.none` → nil.
4. **When.** `let wq = draft.whenQuestion.question(createdAt: now)`, then `episode.setWhenQuestion(wq)`.
   Then `.year(y)` → `answerWhen(year:)`, `.age(a)` → `answerWhen(age:)`, and `.notSure` does nothing
   (the question stays open).
5. **People.** For each `.accepted` chip, in order:
   - if `match != nil && useMatch`, fetch that `Person`; a missing one is treated as no match;
   - otherwise reuse an existing `Person` whose name has the same phraseKey as the span (this covers
     two chips or a deleted match), else insert `Person(name: span.text)`.

   Then each `typedPeople` entry: `.existing(id)` → fetch, skipping a missing one; `.new(name)` →
   trimmed, with the same reuse-by-phraseKey rule before inserting. Append to `episode.people` unless
   that Person is already there. Keep a map from span phraseKey to the Person filed for it.
6. **Place.** The `.accepted` place chip (same match and reuse rule, against `Place`), else
   `typedPlace` (same rule), else nil → `episode.place`.
7. **Follow-ups.** For each row in order where `draft.isLive(row)`:
   - `let q = row.question.question(createdAt: now)`, then `episode.questions.append(q)`;
   - for a `who.person` row, `q.person` = the Person mapped from its slot's phraseKey;
   - for `.notThisOne`, `q.record(.dontRemember)`. That retires it, which is what "not this one" means.
     `.skipped` would re-offer it.

   Record `q` in `questionsByRowID`.
8. **Rejections.** `capture.logRejected(kind, text:, at: now)` for each of these:
   - a `.rejected` title chip (`.title`, span text);
   - a `.rejected` period suggestion (`.period`, `suggestedPeriod.title`);
   - each `.rejected` person chip (`.person`) and place chip (`.place`), with the span text.

   Chips left `.suggested` are not logged.
9. **Answered question.** If `capture.answersQuestionID` resolves to a stored `Question`, call
   `record(.answered)` on it.
10. `try context.save()`. On a throw, `context.rollback()` and rethrow. Nothing is half-filed.

The filer never reads a `FilingOutcome`, a `MergedExtract` or any model type. It sees only the draft.

## 5. Shared helpers

- **Excerpt.** Add `var excerpt: String` to `CompletedTranscript` in `CompletedTranscript.swift`, using
  R1's word rule: the first 25 whitespace-separated words of the segments' texts, joined with single
  spaces. `Episode.setExcerpt(from:)` uses it, with identical behaviour; the existing excerpt tests
  prove it. Views never re-implement the rule.
- **Settings key.** `enum SettingsKeys { static let suggestionsOn = "retold.suggestionsOn" }` in
  `Retold/Screens/SettingsView.swift`.
- **Unfiled row state** (pure, in `ConfirmDraft.swift`), tested in §8.3:

  ```swift
  enum UnfiledRow: Equatable, Sendable { case transcribing, ready(excerpt: String), noTranscript }
  static func unfiledRow(status: TranscriptionStatus, transcript: CompletedTranscript?) -> UnfiledRow
  ```

  The mapping:
  - `.pending`, `.live`, `.fromFile` → `.transcribing`;
  - `.complete` with a non-empty `transcript.excerpt` → `.ready`;
  - `.complete` with an empty excerpt (silence), or `.failed` → `.noTranscript`.

## 6. The confirm screen — new `Retold/Screens/ConfirmView.swift`

Presented as a sheet. Input: one unfiled `Capture` whose row is `.ready` or `.noTranscript`, plus an
optional cached `FilingOutcome` (§7.1). No design pass: a standard SwiftUI `Form` inside a
`NavigationStack`, with all strings from `AppCopy`.

**Loading** runs in a `.task` that does nothing if `draft != nil`. Never in `onAppear`: a rebuild would
lose the user's edits.

1. `mode = FilingMode.select(availability: ModelAvailability.current, suggestionsOn: <SettingsKeys.suggestionsOn, default true>)`.
2. Decide the outcome:
   - If the row is `.noTranscript` or `mode` is `.deck`: `outcome = nil`, built at once, no spinner.
   - Else if a cached outcome was passed in: use it.
   - Else show `AppCopy.findingSuggestions` with a `ProgressView` and a `skipSuggestions` button. Run
     `FilingPipeline(model: FoundationFilingModel(), counter: DeviceTokenCounter()).file(transcript, periodTitles:)`,
     where the period titles are every `Period.title` by `sortOrder`. **Skip** cancels the task and
     uses `outcome = nil`. On completion, report the outcome to Home's cache through a callback.
3. Build the draft once, with `ConfirmDraft.make`, from snapshots of every Period, Person and Place in
   the store. The form below shows only after the draft exists. Nothing merges into a half-edited draft.
4. If `mode` is `.deck(reason)` and `reason.copy` is non-nil, show that copy as a footnote at the top.

Leaving the sheet without filing discards every choice. This is deliberate: nothing is written until
File. A swipe-down dismissal is allowed and also discards (stated, not guarded).

**Sections, in order** (PLAN §6.2 step 2):

1. **Title.** First the excerpt line: `.ready`'s excerpt, or `noTranscriptLabel`. It is not tappable
   (PLAN §6.2). Then the title chip, if any:
   - its text, plus `AppCopy.suggestedLabel` in a secondary style while `.suggested`;
   - `acceptButton` and `rejectButton`.

   Then `TextField(AppCopy.titlePlaceholder)` bound to `typedTitle`.
2. **Period.** The suggested chip (same style and buttons), while it is not rejected. Then a `Picker`
   over `noPeriod`, every period by `sortOrder`, and `newPeriod`. Choosing `newPeriod` shows
   `TextField(AppCopy.newPeriodPlaceholder)`, bound to `.new(String)`.
3. **When.** `whenQuestion.text`, a segmented control `whenYear` / `whenAge`, and a wheel `Picker` whose
   **first row is a blank "—" (U+2014) that maps to `.notSure`**. The year rows run from the current
   year down to 1900; the age rows run 0...100. The wheel starts on the blank row and `setWhen` fires
   only on a user change. A `notSure` button returns to the blank row. Switching the segment resets
   the wheel to the blank row and `when` to `.notSure`. Never file a value the user did not move to
   (Rule-1 wall item 5).
4. **People.** One row per chip: its text, `suggestedLabel` while suggested, accept and reject. An
   accepted chip with `match != nil` shows a two-option picker: `"\(sameAs) \(match.name)"` /
   `newPerson`. Below, the typed entries (with delete), then an `addPerson` `Menu` listing existing
   people by name (choosing one adds `.existing(id)`) and a `TextField` that adds a `.new` on submit.
5. **Place.** The same as people, single-select (§3.4), with `addPlace` and `newPlace`.
6. **Questions for later.** One row per `isLive` follow-up: `question.text`, and the choice `later`
   (default) / `notThisOne`. The choice is hidden on `broad.open`, where `.dontRemember` does nothing
   (`Question.record`), so that row is always `.later`.
7. **The file button.** A `fileButton` in the toolbar, disabled unless `canFile`. On tap it calls
   `ConfirmFiler.file` on the main context and dismisses. A throw keeps the sheet open, unchanged, with
   no alert.

## 7. Home, root, settings and wiring

### 7.1 `Retold/Screens/HomeView.swift` (replaces the R6b body)

- A `NavigationStack` with title `AppCopy.homeTitle` and the record button as today.
- A toolbar gear presents `SettingsView` as a sheet.
- **Unfiled** (`AppCopy.unfiledHeader`): `@Query` every `Capture` whose `episode == nil`, sorted
  newest first. Do **not** put `transcriptionStatus` in a `#Predicate`; map rows in memory with
  `unfiledRow`. Each row shows the date (`createdAt`: `.abbreviated` date, `.shortened` time) and then:
  - `.transcribing` → `transcribingLabel`, not tappable;
  - `.ready(excerpt)` → the excerpt, tappable;
  - `.noTranscript` → `noTranscriptLabel`, tappable.

  A tap presents `ConfirmView`.
- **Filed** (`AppCopy.filedHeader`): every `Episode` newest first, showing `title.value`. It is a
  placeholder until R7b's Timeline replaces it, and it is not tappable in R7a.
- An in-memory outcome cache, `@State var outcomes: [UUID: FilingOutcome]`, which is never persisted.
  It is passed to `ConfirmView`, and `ConfirmView` fills it, so reopening a capture in the same
  session does not re-run the model.
- On appear: `try? DefaultPeriods.seedIfNeeded(context, defaults: .standard)`. This is idempotent, and
  it covers a launch where the store's first use came after a locked start.

### 7.2 Auto-present after Stop (`Retold/RetoldApp.swift`, `RootView`)

PLAN §6.2: the confirm screen is "the screen after Stop". `HomeView` does not exist while the
recorder shows, so this belongs to `RootView`:

- `@State var autoPresentID: UUID?`, passed to `HomeView` as a `Binding`.
- `.onChange(of: coordinator.state.phase)`: when the old phase is `.stopping(let id, _)` and the new
  one is `.idle`, set `autoPresentID = id`.
- `HomeView` handles a non-nil `autoPresentID` on appear and on change. It fetches the capture. If the
  capture exists, has `episode == nil`, and `unfiledRow` is `.ready` or `.noTranscript`, it presents
  `ConfirmView` for it. In every case it then sets the binding back to nil. A capture still
  `.transcribing` is not presented; it waits in Unfiled.
- Accepted, and stated: a start from the Control or the Action button while `ConfirmView` is open
  replaces Home with the recorder and discards the open draft.

### 7.3 `Retold/Screens/SettingsView.swift` (new)

- `SettingsKeys` (§5).
- `Toggle(AppCopy.suggestionsToggle)` bound to `@AppStorage(SettingsKeys.suggestionsOn)`, default `true`,
  with `AppCopy.suggestionsFootnote` under it.
- Title `AppCopy.settingsTitle`.

### 7.4 `Retold/Capture/Device/LiveCapture.swift` and `Retold/RetoldApp.swift`

- `LiveCaptureServices` gains `let container: ModelContainer`, the container `makeCoordinator` already
  builds.
- `RootView` applies `.modelContainer(services.container)`, so views use `@Query` and
  `@Environment(\.modelContext)`.
- `HomeView` receives the coordinator, as today.

## 8. Tests — `RetoldTests/`

Shared rules for every test file:

- Use in-memory containers (`RetoldSchema.makeInMemoryContainer()`) and `@MainActor` test classes.
- Spans come from `VerifiedSpan.fixture` and transcripts from `CompletedTranscript.fixture`.
- Outcomes are built by running `FilingPipeline` with a `MockFilingModel` and `WordTokenCounter`, or as
  `.proposal(ExtractMerger.merge(...), TemplateAssembler.followUps(from:))`.
- Never use `Question.fixture` for anything the filer writes.
- Drafts use a counting `makeID`.
- **"Reopen"** means a fresh `ModelContext(container)` on the same container.

### 8.1 `ConfirmDraftTests.swift`

- `testNoOutcomeGivesWhenOpenAndBroadOnly`
- `testNoModelOutcomeEqualsNoOutcome` (same `makeID` sequence for both)
- `testProposalSplitsWhenQuestionFromRows`
- `testWhenCueChosenWhenTimeCueVerified`
- `testFunctionWordCueFallsBackToWhenOpen`
- `testFunctionWordPersonSpanGivesNoChip`
- `testSuggestedPeriodResolvesByExactTitle`
- `testSuggestedPeriodIsNotPrePicked`
- `testAcceptSuggestedPeriodPicks`
- `testPickingSuggestedIdAccepts`
- `testPickingAnotherPeriodUnacceptsSuggestion`
- `testRejectingSuggestedPeriodClearsPick`
- `testPersonMatchByName`
- `testSetUseMatch`
- `testPlaceAcceptIsSingleSelect`
- `testTypedPlaceClearsAcceptedChip`
- `testEmptyTypedPlaceIsNil`
- `testTypedPersonDedup`
- `testTypedPersonMatchingChipIgnored`
- `testTypedPersonMatchingExistingNameIgnored`
- `testEmptyTypedPersonIgnored`
- `testRemoveTypedPerson`
- `testTypedTitleWinsOverChip`
- `testWhitespaceTitleCannotFile`
- `testSuggestedTitleCannotFile`
- `testWhenDefaultsToNotSure` (Rule-1 wall item 5, draft level)
- `testWhoRowLiveOnlyWithAcceptedPerson`
- `testSensoryRowLiveOnlyWithAcceptedPlace`

### 8.2 `ConfirmFilerTests.swift`

- **Guards** (each asserts the Episode count is unchanged):
  - `testWrongCaptureThrowsBeforeWrites`
  - `testQuoteSpanFromOtherCaptureThrows`
  - `testAlreadyFiledThrows`
  - `testCannotFileThrows`
- **Writes:**
  - `testQuoteTitleIsConfirmedTranscriptQuote` (status `.confirmed`; provenance `.transcriptQuote` with
    the span's capture id and range; value == span text)
  - `testTypedTitleIsUserTypedAndTrimmed`
  - `testExcerptSetFromCapture`
  - `testFailedCaptureFilesWithEmptyExcerpt`
  - `testNewPeriodAppendsSortOrder`
  - `testEmptyNewPeriodIsNone`
  - `testExistingPeriodAttached`
  - `testDeletedPeriodLeavesNone`
  - `testWhenYearAnswersWhenQuestion`
  - `testWhenAgeAnswersWhenQuestion`
  - `testNotSureLeavesWhenOpen`
  - `testAcceptedPersonNewUsesSpanText`
  - `testMatchedPersonReused` (Person count unchanged)
  - `testMatchDeclinedMakesNewPerson`
  - `testTypedExistingAndNewPeople`
  - `testTypedNewReusesSameNamedPerson`
  - `testSamePersonNotDuplicated`
  - `testAcceptedPlaceAttached`
  - `testTypedPlaceAttached`
  - `testWhoQuestionLinkedToFiledPerson`
  - `testNotThisOneRetires`
  - `testNonLiveRowsNotWritten`
  - `testAnsweredQuestionRecorded`
- **Logging:**
  - `testRejectedTitleLogged`
  - `testRejectedPeriodLogged`
  - `testRejectedPersonLogged`
  - `testRejectedPlaceLogged`
- **Rule-1 wall** (one test each, named for the wall item):
  - `testWall2SuggestedChipsNeitherFiledNorLogged`: every chip left `.suggested`, title typed. No
    Person, no Place, no period, and `rejectedProposals` is empty.
  - `testWall3EveryPersistedStringHasASource`: after a full filing, every `Person.name`, `Place.name`,
    `Period.title`, the title value and every `Question.text` equals one of: a span text, a trimmed
    typed string, a pre-existing name, or an `AssembledQuestion.text` from the draft.
  - `testWall4NothingProposedPersisted`: after reopening, the episode's title status is `.confirmed`.
  - `testWall5WheelDefaultFilesNoYear`: a draft whose `when` was never set files with `approxYear` and
    `approxAge` nil and the when question `.open`.
  - `testWall6QuestionsAreDeckOrigin`: every persisted `Question.origin == .deck`, and its `templateID`
    is in `QuestionDeck.all`.
- Not required: a save-failure rollback test (no injectable save failure exists). Note it in the PR
  body.

### 8.3 `UnfiledRowTests.swift`

- `testInProgressStatusesAreTranscribing`
- `testCompleteWithWordsIsReady`
- `testCompleteSilenceIsNoTranscript`
- `testFailedIsNoTranscript`
- `testExcerptMatchesSetExcerptRule`

### 8.4 `ModelBoundaryTests.swift` (boss, done)

Exactly one file under `Retold/` imports FoundationModels, and that file names no persistence type. It
also covers `DeviceTokenCounter`'s arithmetic.

### 8.5 `FoundationAvailabilityTests.swift` (boss, done)

Covers the availability mapping for every reason, and the prompt's final-segments-only rule.

### 8.6 Existing tests

`WellnessLintTests` picks up the new copy through `AppCopy.all`. Update any test that names
`homePlaceholder` to drop it.

## 9. R7b — scope (detailed after R7a merges)

- **Timeline** (PLAN §2 Browse): periods by `sortOrder`, each a row of its episodes, newest first. Each
  episode plays its first capture. "Not in a period" comes last. Periods can be added, renamed and
  reordered (the R5 seeded periods are editable). Replaces Home's Filed list.
- **People** and **Places**: a list, then a page per entity with its episodes. The person page shows
  its open questions via `QuestionEngine.queue(for: PersonState)`, showing `EngineOffer.question.text`
  (IDEAS, R5).
- **Episode page:** the verbatim transcript (segments with timestamps), an audio scrubber, the confirmed
  facts and the open questions. Nothing `.proposed` anywhere (PLAN §5.1 item 2).
- **Answering** (moved from R7a): "Answer now" on the episode and period pages calls `markShown()`,
  saves, then `coordinator.startCapture(answering:)`. `AnswerAttacher` attaches an answer capture to its
  question's episode. It runs on Home appear, on `lastImport` change, and on `scenePhase == .active`.
  The last is needed because the file pass completes audio-only captures without setting `lastImport`.
  It uses a pure `isAttachable(_:questionsWithEpisode:)`, true regardless of status, so a pending
  answer is never shown in Unfiled. An answer to a period or theme question goes through the confirm
  flow with that period pre-picked.
- **Period page:** the empty-period opener (`QuestionEngine.queue(for: PeriodState)`) and the theme
  cards entry.
- **Export:** the R5 folder, zipped with `NSFileCoordinator` `.forUploading` (no dependency), sent to the
  share sheet, with PLAN §9's note that recordings may name other people.
- **Excluded unless Perry says otherwise:** nudges (§11 item 1) and transcript corrections (§11 item 2).

## 10. Build order and lanes (R7a)

1. **Boss (done):** §2, §8.4, §8.5 and the PLAN §6.3 note, in PR #11 commit 1. CI must be green before
   step 2.
2. **Kimi** (slim wrapper), in this file order:
   1. `AppCopy.swift` (§1)
   2. `CompletedTranscript.swift` + `Entities.swift` `setExcerpt` (§5)
   3. `ConfirmDraft.swift` (§3, §5 unfiled row)
   4. `ConfirmDraftTests.swift`
   5. `UnfiledRowTests.swift`
   6. `ConfirmFiler.swift` (§4)
   7. `ConfirmFilerTests.swift`
   8. `SettingsView.swift`
   9. `ConfirmView.swift`
   10. `HomeView.swift`
   11. `LiveCapture.swift`
   12. `RetoldApp.swift` (§7.2, §7.4)
3. **Boss:** a Swift 6 test-pitfall sweep before the first CI push, and batched fix rounds.
4. **Review:**
   - Sonnet `reviewer` on the diff.
   - **Sol Rule-1 review is required for R7a.** PLAN §10 requires it for every diff that touches the
     confirm flow and the model session, and this is the first. Use the prompt in PLAN §10's Sol row.
   - If Sol's quota is out, Sonnet stands in and the record says so.
5. **Device:** Perry's one sitting after 10-16, together with R6 §9. The checks:
   - file one capture on the model path;
   - file one with Suggestions off;
   - confirm that a span chip shows the transcript's own words;
   - time the suggestions wait on a 3-minute capture;
   - watch for `.contextExceeded` on a long monologue.

## 11. Open for Perry

1. **Nudges in 1.1?** Asked 2026-10-04, unanswered. Recommendation: yes. They need notification
   permission, scheduling and a copy pass. None of that is on the submit path, and the app is complete
   without them.
2. **Transcript corrections: 1.0 or 1.1?** Perry decided 2026-10-04 that "corrected-capture
   re-transcription is R7". This spec has no correction UI, and a correction UI brings the Sol R2
   finding 5 retirement work with it. Recommendation: 1.1. With no UI, no correction can exist in 1.0.
   If Perry wants corrections in 1.0, they go into R7b with retire-on-correction.
3. **Pricing** (PLAN §9: free up to a capture count, then a one-time unlock) is not in R7. In-app
   purchase adds StoreKit, an App Store Connect product and a review surface. Recommendation: 1.0 ships
   free with no purchase, and the unlock lands in 1.1 once the count is chosen. Price is Perry's call
   (PLAN §9).

## 12. `ai/IDEAS.md` additions (append-only, R7a PR)

- 2026-10-04 (R7a): detail tagging in the confirm flow (PLAN §6.1 note) moved to 1.1;
  `Detail(quote:kind:)` stays unused in 1.0.
- 2026-10-04 (R7a): `DeviceTokenCounter` estimates characters ÷ 3. Add the measured `tokenCount(for:)`
  path behind `#available(iOS 27, *)` in 1.1 (PLAN §6.3 item 1).
- 2026-10-04 (R7a): proposals are not stored. Rejections are logged only at File, and there is no
  re-offer filter. If logging moves to tap time, add the phraseKey filter (dropped from R7a in Sonnet
  review, finding 14a).
- 2026-10-04 (R7a): `Episode.place` is single, so the confirm flow is single-select for place. Several
  places per episode is a schema change for the V1 freeze.
- 2026-10-04 (R7a): person and place matching uses names only; aliases are never written in 1.0. Add
  alias matching when a merge or rename UI writes aliases.
- 2026-10-04 (R7a): a session-only outcome cache avoids re-running the model on reopen. If device
  timing shows long waits on first open, consider running the pipeline when transcription completes.

## 13. Review record

Sonnet spec review, 2026-10-04: 4 blockers, 9 should-fix, test gaps, cuts and nits. All taken, with
these adjudications:

- **Finding 8** (`.notThisOne`): mapped to `.dontRemember` (retire), and the choice is hidden on
  `broad.open`.
- **Finding 14** cuts:
  - (a) the rejection filter: taken.
  - (b) aliases: taken.
  - (c) answering moved to R7b: taken. It also moves findings 5 and 6's attach parts to R7b (§9).
  - (d) Menu instead of autocomplete: taken.
- **The `suggestionsFootnote` nit:** reworded to a claim the code makes true ("made on this iPhone"),
  not a policy claim.

## Do not

- Do not import `FoundationModels` anywhere but `FoundationFilingModel.swift`, and do not edit that file.
- Do not persist a proposal, a `MergedExtract`, a `FilingOutcome` or a `ConfirmDraft`.
- Do not write a chip that is still `.suggested`, and do not log one as rejected.
- Do not file a year or age the user did not move the wheel to.
- Do not build a `Question` any way except `AssembledQuestion.question()`.
- Do not use `Question.fixture` or `VerifiedSpan.fixture` outside `RetoldTests/`.
- Do not show an alert for any model error. Every model error lands in the deck path.
- Do not pre-pick the model's period, accept any chip by default, or render a suggested value without
  the word *suggested*.
- Do not put an enum in a `#Predicate`.
- Do not use string literals for template ids.
- Do not add a schema field, a dependency, or a `project.yml` change.
- Do not add user-facing strings outside `AppCopy`.

## Done when

- CI is green (Debug tests and Release compile) on PR #11, and every §8 test is present and passing.
- `ModelBoundaryTests` passes.
- The Sonnet review is APPROVE, and the Sol Rule-1 review (or a recorded Sonnet stand-in) has its
  findings adjudicated.
- A TestFlight build with R7a is uploaded for Perry's device sitting.
- `ai/STATE.md` is updated, and the §12 lines are appended to `ai/IDEAS.md`.
