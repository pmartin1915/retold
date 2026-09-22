# R1 spec — data model + SwiftData schema spike

_Written 2026-09-22. Step R1 of `../storycue/docs/STRATEGY-2026-09-22.md` ("Retold — CI-provable
logic first"). Governing design: `docs/PLAN.md` §5.1 (Rule 1) and §6.1–6.2. Every type, method,
file and test name is fixed here so `/orchestrate` (Kimi executes, Sol audits the diff — required,
this is a Rule-1 diff) doesn't invent shapes. Where this spec departs from PLAN §6.1's sketch, the
departure and its reason are listed in "Departures from PLAN §6.1" at the end._

## Why a spike

PLAN §6.1 puts a generic `Confirmable<T>` holding an enum with associated values
(`Provenance`) inside `@Model` classes. Neither shape is proven to persist in SwiftData, and a
schema that corrupts or crashes on fetch is found only on a device, after users have data. So
R1's first deliverable is a round-trip test suite that persists **every entity and every
provenance case** through an in-memory and an on-disk `ModelContainer`, reopens the on-disk
store in a fresh container, and compares. That suite runs on CI; it is the spike.

To take the likeliest failure off the table up front, `Provenance` is **not** persisted as an
enum with associated values: `Confirmable` stores a flat `StoredProvenance` struct (optional
plain columns) and exposes `Provenance` as a computed property. The generic `Confirmable<T>`
itself is kept, because it's the cheap thing to test.

**Pre-registered fallback** (applied by a follow-up spec, not improvised in this dispatch): if
the round-trip suite fails on CI because of `Confirmable<T>`'s genericity, replace it with two
concrete structs `ConfirmableInt` and `ConfirmableString` with the identical API, and re-run.
If it fails for any other reason, stop and report — do not redesign in the executor.
**Who decides which it is:** the boss (Opus), from the CI log, not the executor. The tests are
split so the log answers it: `testDetailStoredProvenanceSurvivesReopen` persists the flat
`StoredProvenance` with no generic in the path; `testConfirmableIntSurvivesReopen` persists one
`Confirmable<Int>`. The first passing and the second failing is the genericity signature.

## Scope

**In:** the value types, the seven `@Model` classes, `RetoldSchema`, the Rule-1 invariants
enforced by initializers and mutators, and the tests below. All in `Retold/Model/` and
`RetoldTests/`.

**Out:** any view, `RetoldApp.swift` (not touched — no `.modelContainer` yet), transcription,
the `@Generable` schema and span verifier (R2), the template deck and lints (R3), the question
engine (R4), export (R5). No `FoundationModels` import anywhere in R1.

## 1. Value types — `Retold/Model/Values.swift`

All are `Codable, Equatable, Hashable, Sendable`. Enums without payloads are `String`-backed.

```swift
enum Origin: String, Codable, Hashable, Sendable { case model, deck, user }
enum ConfirmStatus: String, Codable, Hashable, Sendable { case proposed, confirmed, rejected }
enum DetailKind: String, Codable, Hashable, Sendable { case sensory, people, sequence, emotion, object }
enum CueKind: String, Codable, Hashable, Sendable { case period, event, sensory, people, sequence }
enum QuestionStatus: String, Codable, Hashable, Sendable { case open, answered, skipped, retired }
enum TranscriptionStatus: String, Codable, Hashable, Sendable { case pending, live, fromFile, complete, failed }
enum ProposalKind: String, Codable, Hashable, Sendable { case title, period, person, place, timeCue, referent }

/// An exact transcript quotation with its audio range. R2's verifier is the only producer in
/// production; R1 constructs them directly in tests.
struct VerifiedSpan: Codable, Hashable, Sendable {
    let text: String
    let captureID: UUID
    let start: TimeInterval
    let end: TimeInterval
    var range: ClosedRange<TimeInterval> { min(start, end)...max(start, end) }   // never traps, even on a decoded value
    init(text: String, captureID: UUID, start: TimeInterval, end: TimeInterval) // precondition(start <= end)
}

struct TranscriptSegment: Codable, Hashable, Sendable {
    var text: String; var start: TimeInterval; var end: TimeInterval; var isFinal: Bool
}

/// A user's edit to one transcript segment. The transcript itself is never rewritten.
struct UserCorrection: Codable, Hashable, Sendable {
    let id: UUID
    let segmentIndex: Int
    let originalText: String      // copied from the segment at correction time
    let correctedText: String
    let createdAt: Date
}

/// A chip the user declined in the confirm flow (PLAN §6.2 step 3), kept for tests and audit.
struct RejectedProposal: Codable, Hashable, Sendable {
    let kind: ProposalKind
    let text: String
    let rejectedAt: Date
}
```

`precondition` is allowed in `VerifiedSpan.init` (programmer error, not user input). No `try!`.

## 2. `Provenance` and `Confirmable<T>` — `Retold/Model/Confirmable.swift`

```swift
enum Provenance: Hashable, Sendable {              // NOT Codable; never persisted directly
    case userTyped
    case userConfirmed(proposedBy: Origin)
    case transcriptQuote(captureID: UUID, start: TimeInterval, end: TimeInterval)
    case model
    case deck(promptID: String)
}

/// Flat persisted form. Exactly one `kind`; the optionals it needs are set, the rest nil.
struct StoredProvenance: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable { case userTyped, userConfirmed, transcriptQuote, model, deck }
    var kind: Kind
    var proposedBy: Origin?
    var captureID: UUID?
    var start: TimeInterval?
    var end: TimeInterval?
    var promptID: String?
    init(_ p: Provenance)
    /// nil if the fields don't form a valid case — see the per-kind table below.
    var provenance: Provenance? { get }
}
```

Per-kind field rules for `StoredProvenance.provenance` (anything else → `nil`):

| kind | must be non-nil | must be nil |
|---|---|---|
| `userTyped`, `model` | — | all five optionals |
| `userConfirmed` | `proposedBy` | `captureID`, `start`, `end`, `promptID` |
| `transcriptQuote` | `captureID`, `start`, `end` | `proposedBy`, `promptID` |
| `deck` | `promptID` | `proposedBy`, `captureID`, `start`, `end` |

```swift

enum ConfirmableDecodingError: Error, Equatable { case malformedProvenance, invalidStatusProvenance }

struct Confirmable<T: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    private(set) var value: T
    private(set) var status: ConfirmStatus
    private var stored: StoredProvenance
    var provenance: Provenance { get }             // stored.provenance; the decoder and factories guarantee non-nil, so the getter's `guard ... else { preconditionFailure() }` is unreachable by design — no `!`

    // The ONLY ways to make one. The memberwise init is private.
    static func proposedByModel(_ value: T) -> Confirmable            // .proposed, .model
    static func proposedByDeck(_ value: T, promptID: String) -> Confirmable   // .proposed, .deck
    static func proposedQuote(_ value: T, span: VerifiedSpan) -> Confirmable  // .proposed, .transcriptQuote(span's capture/start/end)
    static func userTyped(_ value: T) -> Confirmable                  // .confirmed, .userTyped

    /// .proposed → .confirmed. Provenance: .model → .userConfirmed(proposedBy: .model),
    /// .deck → .userConfirmed(proposedBy: .deck), .transcriptQuote stays as is.
    /// Returns false and changes nothing unless status was .proposed.
    @discardableResult mutating func confirm() -> Bool
    /// .proposed → .rejected, provenance unchanged. False and no change otherwise.
    @discardableResult mutating func reject() -> Bool
    /// Any state → value replaced, .confirmed, .userTyped.
    mutating func replaceByUser(_ value: T)

    init(from decoder: Decoder) throws             // decodes value/status/stored, then validates
    // encode(to:) is synthesized-equivalent: keys value, status, stored.
}
```

**The Rule-1 invariant (PLAN §5.1, §6.1 design notes), enforced here and nowhere else:**

| status | allowed provenance |
|---|---|
| `.proposed` | `.model`, `.deck`, `.transcriptQuote` |
| `.confirmed` | `.userTyped`, `.userConfirmed`, `.transcriptQuote` |
| `.rejected` | `.model`, `.deck`, `.transcriptQuote` |

So a `.confirmed` value with `.model` provenance — "the model supplied a fact" — cannot be
constructed, reached by a mutator, or decoded. `init(from:)` does all validation: fields that
don't form a case (per-kind table above) throw `malformedProvenance`; a valid case outside this
table throws `invalidStatusProvenance`. Put the table in one **internal** (not private)
`static func isValid(status: ConfirmStatus, provenance: Provenance) -> Bool`, used by the decoder
and called directly by tests via `@testable import`. This table governs `Confirmable` only;
`Detail` has no status and its rule is in section 3.

## 3. Entities — `Retold/Model/Entities.swift`

`import SwiftData`. Every class is `@Model final class`, has `var id: UUID` (set in `init` to
`UUID()`), and array relationships default to `[]`. Every relationship names its inverse on
exactly one side, as written below — so `Person.episodes`, `Place.episodes` and the `episode`
back-references are deliberately bare properties with no `@Relationship` attribute; do not add
a second `inverse:` on them. No `@Attribute(.unique)`. `private(set)` on `@Model` stored
properties is intended; if the macro rejects it for a property, report which one rather than
dropping the restriction silently.

```swift
@Model final class Period {
    var id: UUID
    var title: String                                   // user-owned text
    var approxStartAge: Confirmable<Int>?
    var approxEndAge: Confirmable<Int>?
    var sortOrder: Int
    @Relationship(deleteRule: .nullify, inverse: \Episode.period) var episodes: [Episode] = []
    var createdAt: Date
    init(title: String, sortOrder: Int, createdAt: Date = Date())
}

@Model final class Episode {
    var id: UUID
    var title: Confirmable<String>
    var period: Period?
    private(set) var whenQuestionID: UUID?              // one of `questions`; see Departures
    private(set) var approxYear: Confirmable<Int>?
    private(set) var approxAge: Confirmable<Int>?
    @Relationship(inverse: \Place.episodes) var place: Place?
    @Relationship(inverse: \Person.episodes) var people: [Person] = []
    @Relationship(deleteRule: .cascade, inverse: \Capture.episode) var captures: [Capture] = []
    @Relationship(deleteRule: .cascade, inverse: \Detail.episode) var details: [Detail] = []
    @Relationship(deleteRule: .cascade, inverse: \Question.episode) var questions: [Question] = []
    private(set) var excerpt: String                    // verbatim first words of a transcript; "" until set
    var createdAt: Date
    init(title: Confirmable<String>, createdAt: Date = Date())   // excerpt ""

    /// The ONLY writer of excerpt: the first 25 whitespace-separated words of the segments'
    /// texts joined with single spaces, in order, unaltered (fewer if the transcript is shorter).
    func setExcerpt(from segments: [TranscriptSegment])
    var whenQuestion: Question? { get }                 // questions.first { $0.id == whenQuestionID }; nil if none matches
    /// Appends `question` to `questions` if not already there and sets whenQuestionID to its id.
    func setWhenQuestion(_ question: Question)
    /// The ONLY writers of approxYear/approxAge (PLAN §6.1: "only ever set by the user answering
    /// whenQuestion"). Sets the value as .userTyped and marks whenQuestion (if any) .answered.
    func answerWhen(year: Int)
    func answerWhen(age: Int)
}

@Model final class Detail {
    var id: UUID
    private(set) var text: String                        // fixed at init; a quote's text never changes
    var kind: DetailKind
    private(set) var provenance: StoredProvenance        // only .transcriptQuote or .userTyped; no mutator exists
    var episode: Episode?
    init(quote span: VerifiedSpan, kind: DetailKind)     // text = span.text, provenance = .transcriptQuote(span)
    init(typed text: String, kind: DetailKind)           // provenance = .userTyped
    // No other initializer. There is no way to build a Detail from model output.
}

@Model final class Person {
    var id: UUID
    var name: String
    var aliases: [String] = []
    var note: String?
    var episodes: [Episode] = []
    init(name: String)
}

@Model final class Place {
    var id: UUID
    var name: String
    var episodes: [Episode] = []
    init(name: String)
}

enum CaptureError: Error, Equatable { case transcriptAlreadyComplete, useCompleteTranscript, segmentIndexOutOfRange }

@Model final class Capture {
    var id: UUID
    var audioFileName: String                           // relative to the app's audio directory; see Departures
    var duration: TimeInterval
    private(set) var transcript: [TranscriptSegment] = []
    private(set) var transcriptionStatus: TranscriptionStatus
    private(set) var corrections: [UserCorrection] = []
    private(set) var rejectedProposals: [RejectedProposal] = []
    var answersQuestionID: UUID?                        // see Departures
    var episode: Episode?
    var createdAt: Date
    init(audioFileName: String, duration: TimeInterval, createdAt: Date = Date())   // status .pending

    /// Transcriber-only writers. Both throw .transcriptAlreadyComplete if the CURRENT status is
    /// .complete (checked first). updateTranscript throws .useCompleteTranscript if the `status`
    /// ARGUMENT is .complete — completion goes only through completeTranscript.
    func updateTranscript(_ segments: [TranscriptSegment], status: TranscriptionStatus) throws
    func completeTranscript(_ segments: [TranscriptSegment]) throws                             // sets .complete; transcript frozen after
    /// User edit: appends a UserCorrection (originalText copied from the segment); transcript unchanged.
    func addCorrection(segmentIndex: Int, correctedText: String, at date: Date = Date()) throws
    func logRejected(_ kind: ProposalKind, text: String, at date: Date = Date())
}

@Model final class Question {
    var id: UUID
    var text: String                                    // assembled by Swift from templateID + slots (R3/R4)
    var templateID: String
    var slots: [VerifiedSpan] = []
    var cue: CueKind
    var origin: Origin                                  // .deck or .user only; init precondition
    var status: QuestionStatus
    var episode: Episode?
    var period: Period?                                 // one-way, no inverse
    var person: Person?                                 // one-way, no inverse
    var askedCount: Int
    var lastAskedAt: Date?
    var createdAt: Date
    init(text: String, templateID: String, slots: [VerifiedSpan], cue: CueKind, origin: Origin, createdAt: Date = Date())
    // status .open, askedCount 0. precondition(origin != .model) — no question is ever model text.
}
```

`Retold/Model/RetoldSchema.swift`:

```swift
/// Versioned from day one so R2+ schema changes get a migration stage, not a store wipe.
enum RetoldSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Period.self, Episode.self, Detail.self, Person.self, Place.self, Capture.self, Question.self] }
}
enum RetoldMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RetoldSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
enum RetoldSchema {
    static func makeInMemoryContainer() throws -> ModelContainer
    /// Creates `url`'s parent directory (withIntermediateDirectories: true) if missing, then opens
    /// the store there with `migrationPlan: RetoldMigrationPlan.self`.
    static func makeContainer(url: URL) throws -> ModelContainer
}
```
If `static let versionIdentifier` trips Swift 6 global-state checking, use a computed
`static var` instead; `Schema.Version` is `Sendable`, so `let` is expected to compile.

No field anywhere records recall quality, response time, completeness, streaks or scores
(PLAN §5.2 rule 1). Don't add counters beyond `askedCount`/`lastAskedAt`.

## 4. Tests — `RetoldTests/`

All test classes are `@MainActor final class ...: XCTestCase` and use `container.mainContext`
(`@MainActor` is required: `@Model` instances are not `Sendable`). Delete `PlaceholderTests.swift`.

- **On disk:** each test uses its own `FileManager.default.temporaryDirectory/<UUID>/r1.store`
  via `RetoldSchema.makeContainer(url:)`, and removes that directory in `tearDown`.
- **Reopen:** write the first phase inside a helper function that builds the container,
  inserts, calls `try context.save()` and returns only the ids (plain `UUID`s) — so the first
  container and every model object are out of scope when it returns. Then build a new container
  on the same URL and fetch with `FetchDescriptor` + `#Predicate { $0.id == id }`.
- **"Equal field by field":** compare every stored property; for `Confirmable` compare `value`,
  `status` and the computed `provenance`; compare `Date`s with
  `XCTAssertEqual(a.timeIntervalSince1970, b.timeIntervalSince1970, accuracy: 0.001)`;
  relationships by the set of related ids.
- **Relationship fixtures** are always built from the owning side declared in section 3
  (`episode.people.append(person)`, `episode.captures.append(capture)`, ...), never from the
  inverse side.
- A fetch-time error that surfaces as a SwiftData error is still a failure — tests must not
  catch-and-pass.

`SchemaRoundTripTests.swift` — **the spike**:

| Test | Asserts |
|---|---|
| `testDetailStoredProvenanceSurvivesReopen` | one quote `Detail` and one typed `Detail`, reopened: `text`, `kind`, `provenance` equal (the non-generic signal) |
| `testConfirmableIntSurvivesReopen` | one `Period` with `approxStartAge = .userTyped(12)`, reopened, equal (the single-generic signal) |
| `testInMemoryRoundTripAllEntities` | one of each entity, fully populated (every optional set, every array non-empty), fetched back equal field by field |
| `testOnDiskRoundTripAllEntities` | same graph, reopened in a fresh container, equal field by field |
| `testEveryProvenanceCaseSurvivesReopen` | five `Period`s whose `approxStartAge` carries each provenance case (use `confirm()` for `.userConfirmed`), reopened, `provenance` and `status` equal |
| `testConfirmableStringSurvivesReopen` | `Episode.title` as proposed quote, confirmed quote, user-typed — each survives reopen |
| `testCodableArraysSurviveReopen` | `transcript`, `corrections`, `rejectedProposals`, `slots`, `aliases` keep order and content |
| `testManyToManyPeopleSurvivesReopen` | two episodes sharing two people; both sides of the relation correct after reopen |
| `testDeleteEpisodeCascades` | deleting an episode removes its captures, details and questions; people/place/period remain |
| `testDeletePeriodNullifiesEpisodes` | deleting a period leaves its episodes with `period == nil` |

`ConfirmableTests.swift`:

| Test | Asserts |
|---|---|
| `testFactoriesSetStatusAndProvenance` | each of the four factories yields the status/provenance in section 2 |
| `testConfirmModelProposalBecomesUserConfirmed` | `.model` → `.userConfirmed(proposedBy: .model)`; `.deck` → `.userConfirmed(proposedBy: .deck)` |
| `testConfirmQuoteKeepsQuoteProvenance` | quote stays `.transcriptQuote` with the same capture/start/end |
| `testConfirmAndRejectOnlyFromProposed` | on confirmed/rejected values both return false and change nothing |
| `testReplaceByUserFromEveryState` | proposed, confirmed, rejected → value replaced, `.confirmed`, `.userTyped` |
| `testNoReachableStateIsConfirmedModel` | from every factory, apply every sequence of up to 3 operations from {confirm, reject, replaceByUser}; no result has status `.confirmed` with provenance `.model`, and every result passes `isValid` |
| `testDecodingConfirmedModelThrows` | hand-written JSON with status `confirmed`, stored kind `model` → `invalidStatusProvenance` |
| `testDecodingMalformedProvenanceThrows` | via `JSONDecoder` directly: kind `deck` without `promptID`, and kind `userConfirmed` without `proposedBy` → `malformedProvenance` each |
| `testDecodingConfirmedDeckProposalThrows` | status `confirmed`, stored kind `deck` → `invalidStatusProvenance` (a deck proposal must be confirmed via `confirm()`) |
| `testIsValidMatchesTable` | `isValid` over every (status × provenance case) pair equals the section-2 table |
| `testStoredProvenanceRoundTripsEveryCase` | `StoredProvenance(p).provenance == p` for all five cases |

`EntityRuleTests.swift`:

| Test | Asserts |
|---|---|
| `testAnswerWhenYearIsUserTypedAndAnswersQuestion` | `answerWhen(year:)` sets `.confirmed`/`.userTyped`; the `whenQuestion` becomes `.answered` |
| `testAnswerWhenWithoutQuestionStillSetsValue` | `whenQuestionID == nil` → value set, nothing crashes |
| `testWhenQuestionPicksByID` | episode with three questions, `setWhenQuestion` on the second → `whenQuestion` is that one; only it becomes `.answered` after `answerWhen(age:)` |
| `testSetExcerptIsVerbatimFirst25Words` | 3 segments totalling 40 words → exactly the first 25, in order, unaltered; a 10-word transcript → all 10 |
| `testUpdateTranscriptRejectsCompleteArgument` | `updateTranscript(_, status: .complete)` → `.useCompleteTranscript`, status unchanged |
| `testDetailInitializersNeverModel` | both initializers' provenance is `.transcriptQuote` or `.userTyped` |
| `testTranscriptUpdatableUntilComplete` | `updateTranscript` twice (`.live`), then `completeTranscript` → status `.complete` |
| `testCompletedTranscriptRejectsRewrite` | after complete, both writers throw `.transcriptAlreadyComplete` and the transcript is unchanged |
| `testCorrectionLeavesTranscriptUnchanged` | `addCorrection` appends one correction with the segment's original text; transcript equal to before |
| `testCorrectionOutOfRangeThrows` | index past the end → `.segmentIndexOutOfRange` |
| `testLogRejectedAppends` | two calls → two entries in order |

## Do not

- No `FoundationModels`, no views, no change to `RetoldApp.swift`, `project.yml` or `.github/`.
- No `@unchecked Sendable`, `nonisolated(unsafe)`, `try!`, `Task.detached`; no `!` force-unwrap
  outside tests.
- No public/internal memberwise path to a `Confirmable` or `Detail` beyond the ones listed.
- No AI attribution trailers.

## Done when

CI Build & Test (`.github/workflows/build.yml`, which already has the unsigned Release compile
step from S0) green; the 10 + 11 + 11 tests above run and pass; `grep -rn "FoundationModels"
Retold/` is empty; `grep -rnE "try!|Task\.detached|unchecked Sendable|nonisolated\(unsafe\)"
Retold/ RetoldTests/` is empty; Sol's diff audit adjudicated.

## Departures from PLAN §6.1 (and why)

1. **`Provenance.transcriptQuote(capture:range:)` → `(captureID:start:end:)`**, and persisted via
   `StoredProvenance`. `ClosedRange` encodes as an unkeyed array and the enum has associated
   values — the two shapes most likely to break SwiftData's composite attributes. `VerifiedSpan`
   keeps a computed `range` for callers.
2. **`Episode.whenQuestion: Question?` → `whenQuestionID: UUID?`**, the question living in
   `questions`. Two relationships from `Episode` to `Question` with one inverse on `Question`
   is ambiguous to SwiftData.
3. **`Capture.answersQuestion: Question?` → `answersQuestionID: UUID?`** for the same reason
   (Question already relates to Episode).
4. **`Capture.audioURL: URL` → `audioFileName: String`.** An absolute URL into the app container
   breaks when the container path changes (restore to a new device); the directory is resolved
   at runtime (R6).
5. **`Confirmable` construction is factory-only** and `Detail` has two initializers — this is
   the "restricted initializers" mechanism the strategy asked for.
6. **`Episode.excerpt` has one writer**, `setExcerpt(from:)`, which copies transcript words
   verbatim — not a free-text init parameter. Same for `Detail.text` (fixed at init).
7. **Versioned schema** (`RetoldSchemaV1` + migration plan) from day one; PLAN didn't cover it.
8. `id: UUID` on every entity; `RejectedProposal`, `UserCorrection`, `VerifiedSpan` given concrete
   fields (PLAN named them without fields).
