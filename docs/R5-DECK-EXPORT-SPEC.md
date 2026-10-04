# R5 spec — no-model mode (DeckFilingModel, default periods, period.slot, theme cards) and export

_Written 2026-10-04; Sonnet spec review folded the same day (14 findings, all taken except the copy nit,
logged to IDEAS). Step R5 of `../storycue/docs/STRATEGY-2026-09-22.md`. Governing design: `docs/PLAN.md`
§5.3 (Rule 3: a no-model mode is mandatory; `DeckFilingModel` is the third `FilingModel`), §8 (the no-model
mode: mode selection, default periods, theme cards, the reason copy), §7 (period cues, the ordering rule),
§2 "Keep" and §4 item 4 (the export folder; the export manifest is tested under XCTest against fixtures),
§5.1 (Rule 1). Same contract as R1–R4.5: every type, file, rule and test name is fixed here. Sections are
in build order; §4 (export) is independent of §1–§3._

## Scope

**In:** five new source files, additive edits to `TemplateAssembler.swift` and `QuestionEngine.swift`, five
new test files, a dated note in PLAN §7, additions to two existing test files. Pure Swift, XCTest. **No schema change** (no
`@Model` added, removed or retyped; no stored property added). No `project.yml` or `.github/` change
(`Retold/` is the app target's source directory, so a new `Retold/Export/` folder is picked up).

**Out:**

- `FoundationFilingModel` and any `import FoundationModels` (device-gated; R6/R7). R5 defines a
  Retold-owned availability enum; the adapter from `SystemLanguageModel.Availability` arrives with the
  Foundation implementation.
- Every view: the manual filing screen, the period page, the theme card page, the settings toggle, the
  share sheet (R7). R5 is the logic those screens call.
- **Zipping** the export folder and handing it to the share sheet (R7, with the UI).
- **Per-default-period copy** (PLAN §8's "20 questions per period × 5 cue levels"). That is a
  deck-authoring task with its own lint run and Kimi readability pass, not R5 mechanism. It will also
  need a stable key per seeded period, because `Period.title` is editable; that key is a stored field,
  so it waits for the V1 freeze (§6, IDEAS).
- Typed-entity fills for **people** templates (a person typed in manual filing). R5 adds the one fill
  the handoff names, the period title. See §6, IDEAS.
- Nudge adapters (R7). In particular, which `PeriodKey` a theme question takes in `NudgePicker` is R7's
  call (§6, IDEAS). `NudgePicker` is not edited.
- A Day One-compatible JSON export (stays in `ai/IDEAS.md`; not v1-critical).
- Any new **question** copy. The deck stays the 25 R3 templates, byte-identical. The only new
  user-facing strings are the six default period titles and five theme-card titles, all PLAN §8's own
  words (§1.3, §3.1).

## Rule-1 wall for R5

R4's wall said the engine "never reads `Detail.text`, `Person.name`, `Place.name` or `Period.title` into a
slot." **R5 makes exactly one exception: `Period.title` may fill `period.slot`, and nothing else may fill
any slot except a `VerifiedSpan`.** PLAN §6.2 allows it ("slot fillers are verified spans or confirmed
entities") and §7 says the no-model templates "run slot-less or with user-typed entities". A period title
is user-owned text (PLAN §6.1) or one of the six seeded titles (app copy the user can edit).

The exception is enforced by type, the R4.5 way:

- The fill is a sealed value, `PeriodTitleFill`, whose `fileprivate` init is in `TemplateAssembler.swift`.
  Its only production producer is `Period.titleFill`, an extension **declared in that same file**.
- The only assembler entry point that takes it is `TemplateAssembler.assemble(_:periodTitle:)`, which
  accepts only the `period.slot` template.
- `PeriodTitleFill` is **not** `Codable`, and has no public or internal memberwise init. A test-only
  `static func fixture(_:)` sits inside `#if DEBUG`. CI's Release compile rejects any production caller.

**Stated exception to PLAN §5.1 item 6 (traceability).** A `period.slot` question persists with
`slots: []`, so its text cannot be rebuilt from `templateID` + `slots` alone; the filler is the linked
`Question.period`'s title, which the user owns and may since have renamed. Rule 1 still holds (no model
text is involved). This is deliberate and recorded here so a later audit does not flag it as a leak.

**Never widen an access level to make something compile.** If a `fileprivate` init is in the way, the
code is in the wrong file.

## 1. No-model mode — `Retold/Filing/FilingMode.swift`, `Retold/Model/DefaultPeriods.swift`

### 1.1 Mode selection (`FilingMode.swift`)

```swift
/// Retold's mirror of the model's availability (PLAN section 8). The FoundationModels adapter
/// maps SystemLanguageModel.Availability onto this, with `@unknown default` -> .unknown (R6/R7).
enum ModelAvailability: Equatable, Sendable {
    case available, deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, unknown
}

/// Why the app is in the no-model mode.
enum DeckReason: Equatable, Sendable {
    case deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, suggestionsOff
}

enum FilingMode: Equatable, Sendable {
    case model
    case deck(DeckReason)

    /// Suggestions off wins over every availability. Otherwise .available -> .model;
    /// .unknown -> .deck(.deviceNotEligible) (PLAN section 8: unknown gets the deviceNotEligible copy);
    /// each other case -> .deck of the same-named reason.
    static func select(availability: ModelAvailability, suggestionsOn: Bool) -> FilingMode

    /// The FilingModel for this mode: `foundation()` for .model, DeckFilingModel() for .deck.
    /// `foundation` is not evaluated in deck mode.
    func filingModel(foundation: () -> any FilingModel) -> any FilingModel
}

extension DeckReason {
    /// The banner copy for this reason, verbatim from AppCopy: deviceNotEligible -> newerPhoneReason,
    /// appleIntelligenceNotEnabled -> appleIntelligenceOffReason, modelNotReady -> modelsDownloadingReason,
    /// suggestionsOff -> nil (the user chose it; no banner).
    var copy: String? { get }
}
```

A per-capture model failure is a **separate** signal and is not changed: `FilingPipeline.file` already
returns `.noModel(FilingModelError)`, and that capture goes to the manual filing screen with no copy
(PLAN §6.2: errors land in the no-model path, not in an alert). `FilingMode` is the app-wide setting;
`.noModel` is per capture. Both end on the same screen.

### 1.2 `DeckFilingModel` (same file)

```swift
/// The no-model FilingModel (PLAN section 5.3). No inference: every window yields an empty extract,
/// so the pipeline proposes nothing and assembles only the slotless follow-ups.
struct DeckFilingModel: FilingModel {
    func extract(from window: TranscriptWindow, periodTitles: [String]) async throws -> WindowExtract {
        WindowExtract()
    }
}
```

Consequence, asserted in §5: `FilingPipeline(model: DeckFilingModel(), …).file(t, periodTitles: …)` on a
non-empty transcript returns `.proposal(MergedExtract(), [broad.open, when.open])`, in that order, because
`TemplateAssembler.followUps(from:)` on an empty `MergedExtract` emits exactly those two. **Do not add a
"deck proposal" type or any other output**: the manual filing screen is the confirm screen with empty
fields (PLAN §8), and an empty extract is exactly that.

### 1.3 Default periods (`Retold/Model/DefaultPeriods.swift`)

```swift
enum DefaultPeriods {
    /// PLAN section 8, verbatim, in age order. Middle entry uses " / " with spaces.
    static let titles = ["Early childhood", "Primary school", "Middle school / junior high",
                         "High school", "The years after school", "Twenties"]

    static let seededKey = "retold.didSeedDefaultPeriods"

    /// Seeds the six periods once per install. If `defaults.bool(forKey: seededKey)` is true, does
    /// nothing and returns false. Otherwise: if the store already holds any Period (fetchCount > 0;
    /// a throw propagates and the flag stays unset), sets the key and returns false; else inserts one
    /// Period per title, sortOrder 0...5 in `titles` order, createdAt = `now` for all six,
    /// approxStartAge and approxEndAge left nil, then calls context.save() (a throw propagates and
    /// the flag stays unset), then sets the key and returns true. The flag is written LAST, so a
    /// failure never leaves an install flagged but unseeded.
    @MainActor @discardableResult
    static func seedIfNeeded(_ context: ModelContext, defaults: UserDefaults, now: Date = Date()) throws -> Bool
}
```

Why a flag and not only "no Period exists": a user who deletes every period must not get the six back on
the next launch ("seeded on first run", PLAN §8). Ages stay nil: an age range is a fact the user did not
state, and seeding one would be the app authoring it.

## 2. `period.slot` and the empty-period opener

### 2.1 The fill — additive to `Retold/Filing/TemplateAssembler.swift`

```swift
enum TemplateAssemblyError: Error, Equatable {
    // existing three cases unchanged, then:
    /// assemble(_:periodTitle:) was given a template other than period.slot.
    case notAPeriodTitleTemplate
    /// The fill had no word left after trimming whitespace.
    case emptySlot
}

/// A user-owned Period.title as a slot fill (R5, the one non-span fill). Only Period.titleFill
/// below builds one.
struct PeriodTitleFill: Equatable, Sendable {
    let text: String

    fileprivate init(text: String) { self.text = text }

    #if DEBUG
    static func fixture(_ text: String) -> PeriodTitleFill { PeriodTitleFill(text: text) }
    #endif
}

extension Period {
    /// The period's current title as a slot fill.
    var titleFill: PeriodTitleFill { PeriodTitleFill(text: title) }
}

extension TemplateAssembler {   // or inside the enum body; same file either way
    /// Fills period.slot with a period title. Throws .notAPeriodTitleTemplate unless
    /// template.id == "period.slot" AND template.slotCount == 1 (checked before any indexing);
    /// .emptySlot if the title is empty after trimming
    /// whitespace and newlines; .slotIsFunctionWord under the same function-word rule as span
    /// slots. Otherwise the text is the pattern with its single {slot} replaced by the
    /// normalised title: `fill.text` with each run of newlines replaced by one space, then
    /// trimmed of leading/trailing whitespace. Built by the same
    /// split-and-interleave as assemble(_:slots:segments:) (so a title containing "{slot}" is
    /// never re-expanded). The result has slots == [] (no transcript span is involved) and
    /// templateID "period.slot", cue .period.
    static func assemble(_ template: QuestionTemplate, periodTitle fill: PeriodTitleFill) throws -> AssembledQuestion
}
```

The function-word check must reuse the existing `functionWords` set (it is `private` in the enum body;
an extension in the same file can read it). Factor the existing per-slot check into one `private static`
helper that both entry points call; do not copy the word list.

**Persisted form.** `Question.slots` is `[VerifiedSpan]`, so a title fill persists as `slots: []`. The
caller that persists the offer (R7) sets `question.period = period`. Consequences, all deliberate:

- `AskRecord.slotKey` is `""` for `period.slot`, the same triple `(cue .period, "")` as
  `period.else`/`period.who`/`period.where`. **A retired opener must not silence the period cues that
  come after the first episode**: it was asked about an empty period, and "I don't remember" there says
  nothing about the episodes to come. So R5 makes one additive edit to the shared person/period loop:
  its `negatives` filter also excludes `templateID == "period.slot"`. No R4 behaviour changes, because
  no R4 path ever creates a `period.slot` question.
- **Staleness.** `Question.text` is fixed at init and `Period.title` is editable. The engine re-assembles
  every offer from the current title (it already builds a fresh `AssembledQuestion` per call and attaches
  `existingQuestionID`), so `EngineOffer.question.text` is always current. The persisted `Question.text`
  may hold an older title. It is still the user's own words, so Rule 1 holds; R7's views must show the
  offer's text. Logged in §6.
- **Lint.** `LeadingQuestionLint` checks patterns with `{slot}` in place and never the filled text (its
  header comment: "a slot is a verified span or a confirmed entity, so it is never itself checked").
  `period.slot`'s pattern already passes R3's lint. R5 does not lint filled titles (a title like
  "Camp Lakeview" would trip `properNoun`, and it is a confirmed fact).

### 2.2 The opener — additive to `Retold/Questions/QuestionEngine.swift`

`PeriodState` gains one stored property, **last**, with a default so every existing call site compiles
unchanged:

```swift
struct PeriodState: Equatable, Sendable {
    var episodeCount: Int = 0
    var asks: [AskRecord] = []
    /// The period's title as a fill; nil only in tests that do not need the opener.
    var titleFill: PeriodTitleFill? = nil
}
```

The `@MainActor init(period:questions:)` adapter also sets `titleFill = period.titleFill`.

`queue(for: PeriodState)` becomes:

1. **`episodeCount == 0`:** the opener. If `titleFill` is nil, return `[]`. Let
   `existing = asks.first { $0.templateID == "period.slot" }`. If existing is `.answered` or `.retired`,
   return `[]`. If any **other** ask is `.retired` with `cue == .period` and `slotKey == ""` and its
   templateID not in `excludedTemplateIDs` (the existing negative rule, `period.slot` itself excluded
   as above), return `[]`. Otherwise assemble
   `period.slot` with `titleFill` (on a throw, return `[]`) and return the single offer, with
   `existingQuestionID = existing?.questionID`.
2. **`episodeCount >= 1`:** exactly R4's queue (`period.else`, `period.who`, `period.where` through the
   shared loop). `period.slot` is **not** offered here; R4's tests stay green unchanged.

`next(for: PeriodState, recentChannels:)` is unchanged (it already takes the first unblocked offer;
`period.slot` is on channel `.open`).

**Why §7's gate does not block the empty period.** This is a recorded departure from the letter of
PLAN §7, and R5 adds a dated note under PLAN §7 item 1 saying so:
`_2026-10-04 (R5): an empty period (no episodes) offers one opener, period.slot filled with the
period's own title, so a no-model user has a way into a seeded period. See docs/R5-DECK-EXPORT-SPEC.md §2.2._` §7 says period cues come "once the user has named the
period". A period the user typed is named by the user. A seeded period is the app's scaffold, and §8
makes the static deck the way in for a user with no model, so an empty period page with nothing on it
would leave that user stuck. The opener is one open question on the period's own title. It presupposes
nothing beyond the period the user is looking at, and it is shown only until the period has an episode.

## 3. Theme cards — new `Retold/Questions/ThemeCards.swift`, additive to `QuestionEngine.swift`

### 3.1 Cards

```swift
/// A theme card (PLAN section 8, Guided Autobiography's themes: themes usable, text not). A second
/// way in beside the periods, for a user who does not think in periods.
struct ThemeCard: Equatable, Sendable {
    let id: String              // "theme.turningPoint" etc.; equals its one template id today
    let title: String
    let templateIDs: [String]
}

enum ThemeCards {
    static let all: [ThemeCard] = [
        ThemeCard(id: "theme.turningPoint", title: "Turning points", templateIDs: ["theme.turningPoint"]),
        ThemeCard(id: "theme.family", title: "Family origins", templateIDs: ["theme.family"]),
        ThemeCard(id: "theme.work", title: "Work", templateIDs: ["theme.work"]),
        ThemeCard(id: "theme.body", title: "Health and the body", templateIDs: ["theme.body"]),
        ThemeCard(id: "theme.close", title: "Love and relationships", templateIDs: ["theme.close"]),
    ]
}
```

Titles are PLAN §8's theme names verbatim (capitalised first word only). `ThemeCard` has a plain internal
memberwise init: a card holds template **ids**, not copy, and every question still comes from a deck
template through the assembler.

### 3.2 Theme state and queue

In `ThemeCards.swift`:

```swift
/// The asks for one card: questions whose templateID is in the card's templateIDs and that have no
/// episode, no period and no person (a theme question belongs to no page but its card).
struct ThemeState: Equatable, Sendable {
    var asks: [AskRecord] = []
}

extension ThemeState {
    @MainActor
    init(card: ThemeCard, questions: [Question])
}
```

In `QuestionEngine.swift` (the shared person/period loop is `private` there; same-file access):

```swift
extension QuestionEngine {   // or in the enum body
    /// The card's templates through the shared loop, slot nil, sorted (skipped, ti). No gate: a
    /// theme card is a way in for any user, including one with an empty library.
    static func queue(for card: ThemeCard, state: ThemeState) -> [EngineOffer]
    static func next(for card: ThemeCard, state: ThemeState, recentChannels: [QuestionChannel]) -> EngineOffer?
}
```

Templates are `card.templateIDs.compactMap { QuestionDeck.template(id: $0) }`. Negatives use the shared
loop's rule unchanged. Because `ThemeState.asks` holds only one card's questions, a retired theme
question quiets only its own card. The channel is `.theme` (R4's table). A persisted theme question has
`episode`, `period` and `person` all nil; R7 persists it with `question.question()` and sets nothing else.

## 4. Export — new `Retold/Export/ExportManifest.swift`, `Retold/Export/ExportWriter.swift`

PLAN §2: a folder with `audio/<capture-id>.<ext>`, `transcripts/<capture-id>.md` and `index.md`. R5 builds
the manifest from value snapshots (tested against fixtures, PLAN §4 item 4) and writes it to a folder.
Zipping is R7.

### 4.1 Snapshots (values; `ExportManifest.swift`)

```swift
struct ExportQuestion: Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
}

struct ExportDetail: Equatable, Sendable {
    let id: UUID
    let text: String
    let kind: DetailKind
}

struct ExportCapture: Equatable, Sendable {
    let id: UUID
    let audioFileName: String
    let duration: TimeInterval
    let createdAt: Date
    let status: TranscriptionStatus
    let segments: [TranscriptSegment]
    let corrections: [UserCorrection]
    let episodeID: UUID?
}

struct ExportEpisode: Equatable, Sendable {
    let id: UUID
    /// The title only when its status is .confirmed; nil otherwise (proposed or rejected).
    let confirmedTitle: String?
    let excerpt: String
    let periodID: UUID?
    let approxYear: Int?        // confirmed only
    let approxAge: Int?         // confirmed only
    let place: String?
    let people: [String]
    let details: [ExportDetail]
    let openQuestions: [ExportQuestion]   // status .open or .skipped
    let createdAt: Date
}

struct ExportPeriod: Equatable, Sendable {
    let id: UUID
    let title: String
    let startAge: Int?          // confirmed only
    let endAge: Int?            // confirmed only
    let sortOrder: Int
    let createdAt: Date
    let openQuestions: [ExportQuestion]   // Question.period == this, episode nil, .open or .skipped
}

struct ExportLibrary: Equatable, Sendable {
    let periods: [ExportPeriod]
    let episodes: [ExportEpisode]
    let captures: [ExportCapture]
    /// .open/.skipped questions with no episode and no period (theme questions today).
    let otherOpenQuestions: [ExportQuestion]
}

extension ExportLibrary {
    /// The SwiftData adapter. The caller fetches every Period, Episode, Capture and Question.
    /// A Confirmable is read as a fact only when status == .confirmed. Capture.rejectedProposals
    /// are never read.
    /// Questions come ONLY from the `questions` argument (never from episode.questions), filtered
    /// to status .open or .skipped and templateID != "broad.open" (the opener stays open by design
    /// and would print on every episode). Routing: episode != nil -> that episode's openQuestions
    /// (person-linked questions included), or dropped if the episode is not in `episodes`;
    /// episode == nil, period != nil -> that period's openQuestions, or dropped if absent;
    /// both nil -> otherOpenQuestions (person ignored).
    /// ExportQuestion.text is the persisted Question.text, except a period.slot question with a
    /// period: its text is re-assembled with TemplateAssembler.assemble(_:periodTitle:) on
    /// period.titleFill, falling back to the persisted text on a throw, so a renamed period
    /// exports its current title.
    @MainActor
    init(periods: [Period], episodes: [Episode], captures: [Capture], questions: [Question])
}
```

**Rule 1 in export.** Only confirmed values print as facts. A proposed or rejected title, year, age or
period age never appears. `RejectedProposal` never appears. Transcripts are verbatim: corrections are
listed after the transcript, never substituted into it.

### 4.2 Manifest

```swift
struct ExportFile: Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case text(String)
        /// Copy the capture's audio file; the name is relative to the app's audio directory.
        case audio(sourceFileName: String)
    }
    let path: String            // relative, "/"-separated
    let content: Content
}

struct ExportManifest: Equatable, Sendable {
    let files: [ExportFile]

    /// index.md first, then for each capture in capture order: transcripts/<ID>.md, then
    /// audio/<ID>.<ext>. <ID> is uuidString. <ext> is audioFileName's path extension, or "m4a"
    /// when it has none. Dates use `timeZone`, the Gregorian calendar and the en_US_POSIX locale.
    static func build(_ library: ExportLibrary, exportedAt: Date, timeZone: TimeZone) -> ExportManifest
}
```

**Orders** (all ascending, so output is independent of input order): periods by (sortOrder, createdAt,
id.uuidString); episodes and captures by (createdAt, id.uuidString); questions by (createdAt,
id.uuidString); details by (kind.rawValue, text, id.uuidString); people by name with the String `<`
operator.

**Formats.**

- Date: `yyyy-MM-dd HH:mm`. Year and ages: `String(value)` (plain digits, no grouping).
- Time offset and duration: `m:ss` under one hour, `h:mm:ss` from one hour, whole seconds
  truncated (`61.9` → `1:01`, `3725` → `1:02:05`). Negative, NaN or infinite values print as `0:00`.
- **Every** user string printed (titles, names, place, excerpt, question text, detail text, segment
  text, correction text) has each run of newlines replaced by one space. Nothing else is escaped or
  altered; a `"` inside a quoted string is printed as-is.
- Every output line has trailing whitespace removed (so an empty segment prints `[0:00–0:02]`).

**`transcripts/<ID>.md`**, lines joined with `\n`, ending with one `\n`:

```
# Capture <ID>

Recorded <date> · <duration> · transcript <status.rawValue>
Audio: ../audio/<ID>.<ext>

[<start>–<end>] <segment.text>
... one line per segment, in stored order, every segment (final or not) ...
```

If there are no segments, the transcript block is the single line `(no transcript)`. If there are
corrections, append a blank line, `## Corrections`, a blank line, then one line per correction in
stored order: `- [<start>–<end>] "<originalText>" → "<correctedText>" (<correction date>)`, where
start/end are those of `segments[segmentIndex]` (or `[?]` if the index is out of range). The dash in
`[a–b]` is U+2013; the arrow is U+2192; the dot separator is U+00B7 with one space each side.

**`index.md`**, lines joined with `\n`, ending with one `\n`. Sections in this order; a section or
line with nothing to show is omitted entirely (no empty headings, except a period's own heading):

```
# Retold export

Exported <date>
Recordings may name other people.

## <period.title>
Ages <start>–<end>          (only if both ages; "From age <start>" or "Until age <end>" if one)

### <confirmedTitle, or "Untitled">
> <excerpt>                 (only if non-empty)
- When: <year>; age <age>   ("When: <year>" or "When: age <age>" if one; omitted if neither)
- Place: <place>
- People: <name>, <name>
- Details:
  - "<text>" (<kind.rawValue>)
- Captures:
  - <date> · <duration> · [transcript](transcripts/<ID>.md) · [audio](audio/<ID>.<ext>)
- Open questions:
  - <text>

Open questions for this period:
- <text>

## Not in a period
(### episode blocks as above, for episodes whose periodID is nil or not in `periods`)

## Unfiled captures
- <date> · <duration> · [transcript](transcripts/<ID>.md) · [audio](audio/<ID>.<ext>)

## Other open questions
- <text>
```

The `Recordings may name other people.` line is fixed copy, always present (PLAN §9, Guideline
1.4/5.1). An empty library's index is exactly
`"# Retold export\n\nExported <date>\nRecordings may name other people.\n"`.

Blank-line rule: one blank line between the title line and `Exported`, before every `##` and `###`
heading, and before `Open questions for this period:`. No blank line inside an episode block. A
capture whose `episodeID` names an episode not in `episodes` is listed under Unfiled captures.

The golden strings for the §5 fixtures are written into the tests verbatim. If the format above is
ambiguous for a case the fixtures do not cover, choose the simplest reading and say so in the PR body;
do not invent sections.

### 4.3 Writer (`ExportWriter.swift`)

```swift
enum ExportWriter {
    /// Creates `folder` (with intermediates) and writes every file of `manifest` under it:
    /// .text as UTF-8, .audio copied from audioDirectory/sourceFileName. A missing audio source is
    /// skipped, not fatal (the export must not fail because one file is gone), and its manifest
    /// path is returned. A sourceFileName that contains "/" or "\\" or equals ".." is treated as
    /// missing (skipped and returned), never resolved. Any other filesystem error throws. An
    /// existing file at a target path is removed before writing or copying (copyItem does not
    /// overwrite).
    @discardableResult
    static func write(_ manifest: ExportManifest, audioDirectory: URL, to folder: URL) throws -> [String]
}
```

## 5. Tests — `RetoldTests/`

New files are non-isolated `XCTestCase` classes; tests that touch SwiftData or the adapters are
`@MainActor`. Build fixtures with the existing `#if DEBUG` fixtures (`VerifiedSpan.fixture`,
`CompletedTranscript.fixture`, `Question.fixture`, `QuestionTemplate.fixture`) and `PeriodTitleFill.fixture`.

**`FilingModeTests.swift`**

- `testSuggestionsOffWinsOverAvailable` and `testSuggestionsOffWinsOverEveryAvailability` (all five).
- `testAvailableSelectsModel`.
- `testEachUnavailableReasonMapsToItsDeckReason` (three named cases).
- `testUnknownMapsToDeviceNotEligible`.
- `testReasonCopyIsAppCopyVerbatim` (three reasons; `suggestionsOff` → nil).
- `testDeckModeReturnsDeckFilingModelWithoutCallingFoundation` (the closure records a call; it must
  not run).
- `testModelModeReturnsFoundation`.
- `testDeckFilingModelPipelineProposesOnlyBroadAndWhen`: two-segment completed transcript →
  `.proposal(MergedExtract(), q)` with `q.map(\.templateID) == ["broad.open", "when.open"]`.
- `testDeckFilingModelEmptyTranscriptIsNoModel` (unchanged pipeline rule: `.noModel(.other)`).

**`DefaultPeriodsTests.swift`** (`@MainActor`, in-memory container, `UserDefaults(suiteName:)` with a
fresh UUID name, removed in `tearDown`)

- `testSeedsSixInOrderOnFirstRun` (titles, sortOrder 0...5, ages nil, returns true, flag set).
- `testSecondRunDoesNotReseed`.
- `testDoesNotReseedAfterUserDeletesAll` (seed, delete all, run again → 0 periods, false).
- `testExistingPeriodsSuppressSeedAndSetFlag`.
- `testSeedIsSavedBeforeFlag` (after a true return, a fresh `ModelContext` on the same container
  fetches six periods).
- `testTitlesAreWellnessClean` (`WellnessLint.violations` empty for each).

**`TemplateAssemblerTests.swift`** (additions)

- `testPeriodTitleFillsPeriodSlot`: text `"When you think of Twenties, what comes back first?"`,
  slots `[]`, templateID `"period.slot"`, cue `.period`.
- `testPeriodTitleIsTrimmed` (`"  High school \n"`).
- `testPeriodTitleRejectsOtherTemplates` (`people.describe` and `broad.open` → `.notAPeriodTitleTemplate`).
- `testPeriodTitleRejectsEmpty` (`"   "` → `.emptySlot`).
- `testPeriodTitleRejectsFunctionWordsOnly` (`"That"` → `.slotIsFunctionWord`).
- `testPeriodTitleWithSlotMarkerIsNotReexpanded` (title `"{slot} years"`).
- `testPeriodTitleNewlinesBecomeOneSpace` (`"High\n\nschool"` → text contains `"of High school,"`).
- `testPeriodTitleRejectsFixtureWithWrongSlotCount` (`QuestionTemplate.fixture(id: "period.slot",
  cue: .period, pattern: "No slot here?")` → `.notAPeriodTitleTemplate`, no crash).
- `testPeriodTitleFillFromPeriod` (`@MainActor`: `Period(title:sortOrder:).titleFill.text == title`).

**`QuestionEngineTests.swift`** (additions; R4's period tests unchanged)

- `testEmptyPeriodOffersTitleOpener`: episodeCount 0, fill `"High school"` → one offer, `period.slot`,
  text with the title, `existingQuestionID` nil.
- `testEmptyPeriodWithoutFillOffersNothing`.
- `testEmptyPeriodReusesExistingOpenOpener` (open `period.slot` ask → its id is attached).
- `testAnsweredOpenerIsNotReoffered` and `testRetiredOpenerIsNotReoffered`.
- `testOpenerUsesCurrentTitle` (ask exists, fill changed → offer text has the new title, same
  existing id).
- `testPeriodWithEpisodeDoesNotOfferOpener` (episodeCount 1, fill set → ids `period.else`,
  `period.who`, `period.where`, exactly as R4).
- `testRetiredOpenerDoesNotSilencePeriodCues` (episodeCount 1, a retired `period.slot` ask → still
  the three R4 ids).
- `testPeriodStateAdapterCarriesTitleFill` (`@MainActor`, in-memory store).

**`ThemeCardsTests.swift`**

- `testFiveCardsInPlanOrder` (ids and titles verbatim).
- `testEveryCardTemplateIsADeckTemplate` and `testEveryThemeTemplateIsInExactlyOneCard` (every deck id
  with prefix `theme.`).
- `testCardTitlesAreWellnessClean`.
- `testCardQueueOffersItsTemplate` (empty state → one offer, channel `.theme`).
- `testAnsweredAndRetiredThemeQuestionsAreNotReoffered`.
- `testSkippedThemeQuestionKeepsItsID`.
- `testRetiringOneCardDoesNotQuietAnother` (two states, two cards).
- `testThemeStateAdapterTakesOnlyOwnerlessQuestionsOfItsCard` (`@MainActor`: a `theme.work` question
  with an episode set is excluded; a `theme.family` question is excluded from the work card).

**`ExportManifestTests.swift`** (fixture library built directly from the §4.1 values, UTC)

- `testIndexGolden`: two periods (one with confirmed ages 12–14, one with none), an episode in each
  (one with title, year, age, place, two people out of order, two details, one capture, one open
  question), one episode with no period, one unfiled capture, one period open question, one other open
  question. Assert the full `index.md` string.
- `testTranscriptGolden`: three segments (one non-final), one correction. Assert the full string.
- `testEmptyTranscriptLine` (`(no transcript)`).
- `testUntitledWhenTitleNotConfirmed`.
- `testFileOrderAndPaths` (index first; per capture transcript then audio; `.caf` source keeps `caf`;
  extensionless source gets `m4a`).
- `testTimeFormats` (`61.9` → `1:01`, `3725` → `1:02:05`, `0` → `0:00`).
- `testOutputIndependentOfInputOrder` (reversed arrays → identical manifest).
- `testNewlinesInTitlesBecomeSpaces`.
- `testAdapterPrintsOnlyConfirmedFacts` (`@MainActor`: an episode with a proposed title quote, and a
  capture with a logged `RejectedProposal` whose text is unique; the index contains `Untitled` and
  neither string).
- `testAdapterRoutesQuestions` (`@MainActor`: episode open question, skipped question, answered question
  (absent), open `broad.open` (absent), period question, ownerless theme question).
- `testAdapterExportsCurrentPeriodTitleInOpener` (`@MainActor`: persist a `period.slot` question built
  for "Junior high", rename the period to "Middle school"; the exported text contains "Middle school").
- `testEmptyLibraryIndex` (the exact string in §4.2).
- `testYearPrintsWithoutGrouping` (1998 → `- When: 1998`).

**`ExportWriterTests.swift`** (temp directory per test, removed in `tearDown`)

- `testWritesTextAndAudio` (bytes equal).
- `testMissingAudioIsSkippedAndReported` (returned path; other files written).
- `testPathLikeSourceNameIsTreatedAsMissing` (`"../x.m4a"`).
- `testOverwritesExistingFiles`.

## 6. `ai/IDEAS.md` additions (append-only)

- 2026-10-04 (R5): per-default-period deck copy (PLAN §8, 20 questions × 5 cue levels per period) needs
  a stable key per seeded period, since `Period.title` is editable. A stored field: add it at the V1
  freeze; author the copy with a lint run and Kimi readability pass.
- 2026-10-04 (R5): typed-entity fills for people templates (a person typed in manual filing). R5 seals
  only `PeriodTitleFill`; add a sibling fill when the no-model person page is built (R7).
- 2026-10-04 (R5): a persisted `period.slot` question keeps the title it was built with; offers and the
  export re-assemble from the current title. R7's views must show `EngineOffer.question.text`.
- 2026-10-04 (R5 spec review, copy nit): seeded titles read oddly mid-sentence in the opener ("When
  you think of The years after school, ..."). Lowercase a leading article at fill time, or reword the
  seeds; a copy decision, not R5.
- 2026-10-04 (R5): theme questions have no period; `NudgePicker` has only `.period`/`.unfiled` keys.
  R7's nudge adapter decides where they go (a `.theme` key, or exclusion).
- 2026-10-04 (R5): zip the export folder for the share sheet (R7, with the UI).

## Do not

- Do not import `FoundationModels`, `UIKit` or `SwiftUI` in any R5 file.
- Do not change any deck pattern, template id, cue, or the order of `QuestionDeck.all`.
- Do not change R4's episode, person or period-with-episodes behaviour, or any existing test's
  assertions.
- Do not add a `@Model`, a stored property on a `@Model`, or a schema version.
- Do not give `PeriodTitleFill` a non-`fileprivate` init, a `Codable` conformance, or a producer
  outside `TemplateAssembler.swift`. Do not pass a `String` to any assembler entry point.
- Do not edit `docs/PLAN.md` beyond the one dated §7 note.
- Do not lint filled question text with `LeadingQuestionLint`.
- Do not write a `.proposed` or `.rejected` value, or a `RejectedProposal`, into any export file.
- Do not run `git checkout`, `git switch`, `git reset` or `git stash` in the main checkout.
- Never widen an access level to make something compile; report the error instead.

## Done when

- CI green: Debug tests and the Release compile, with every R1–R4.5 test unchanged and passing.
- Every test named in §5 exists and passes.
- `grep -rn "PeriodTitleFill(" Retold/` matches only `TemplateAssembler.swift`.
- `grep -rn "import FoundationModels" Retold/` matches nothing.
- `git diff main -- Retold/Questions/QuestionDeck.swift` is empty.
- `ai/IDEAS.md` has the six §6 lines; PLAN §7 has the dated note from §2.2; `ai/STATE.md` marks R5 merged and names R6 next.
