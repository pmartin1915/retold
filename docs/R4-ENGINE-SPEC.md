# R4 spec — question engine ordering, outcomes, nudge selection

_Written 2026-10-03. Step R4 of `../storycue/docs/STRATEGY-2026-09-22.md` ("Question engine ordering +
nudge candidate selection (§7), pure Swift"). Governing design: `docs/PLAN.md` §7 (walk the hierarchy,
ordering rule, nudges, the lint's channel clause), §8 (nudges work the same with no model), §5.1 (Rule 1:
no slot that is not a verified span). Same contract as R1–R3: every type, file, rule and test name is
fixed here. The boss prototyped §3–§6 in Python before dispatch (episode ordering over three fixture
episodes, the channel cap, retirement, and a 30-day nudge rotation); the expected sequences in §7 are
that prototype's output._

## Scope

**In:** five new source files under `Retold/Questions/`, one additive edit each to
`LeadingQuestionLint.swift` and `QuestionDeck.swift`, five new test files, one edit to
`LeadingQuestionLintTests.swift`. Pure Swift, XCTest. **No schema change** (no new `@Model`, no new
stored property: everything below is derived from R1's fields), no `project.yml` or `.github/` change.

**Out:** notification scheduling, `UNUserNotificationCenter`, nudge history storage and the nudge
adapter from SwiftData (R7; R4 takes nudge inputs as values); the confirm flow that persists questions
and sets `Question.person`/`.period` (R7); per-period deck assignment, theme cards and typed-entity slot
fills — so `period.slot` and the five `theme.*` templates are **never offered by R4** (R5); the when
question (owned by the confirm flow via `Episode.setWhenQuestion`, never offered by the engine); any new
deck copy, including wh-questions on a channel (R3 fixed bulk copy as "same file, no lint change").

**Rule 1 wall.** The engine never builds a `VerifiedSpan`. Every slot it fills is a span already stored
in some `Question.slots` (put there by R2's filing follow-ups through `SpanVerifier`). It never reads
`Detail.text`, `Person.name`, `Place.name` or `Period.title` into a slot.

## 1. Sensory channels — `Retold/Questions/SensoryChannel.swift`

```swift
enum SensoryChannel: String, CaseIterable, Sendable { case sound, smell, taste, sight, clothing, weather }
extension SensoryChannel {
    /// Channels the user's own words mention. Keys by SpanVerifier.key; a word counts once.
    static func mentioned(in texts: [String]) -> Set<SensoryChannel>
}
```

`mentioned` splits each text on whitespace, keys each token with `SpanVerifier.key(_:)`, and returns
every channel one of whose **mention words** appears. Mention words (fixed, `private static let`):

| channel | mention words |
|---|---|
| sound | sound, sounds, sounded, hear, hearing, noise, noises, noisy, loud, music, song, songs, singing, voice, voices |
| smell | smell, smells, smelled, smelt, smelling, scent |
| taste | taste, tastes, tasted, tasting, flavour, flavor |
| sight | seeing, light, colour, color, colours, colors |
| clothing | wear, wearing, wore, clothes, dress, dressed |
| weather | weather, temperature, warm, rain, raining, snow, snowing, sunny, wind, windy |

`see`, `saw`, `heard`, `look`, `looked`, `looking`, `playing`, `cold` and `hot` are deliberately **not** mention
words: "you see", "I saw my dad", "I heard he left", "kids playing" and "I caught a cold" are not the user
describing a sense. (They stay lint triggers,
§2: a false positive there only blocks a question.)

## 2. Transcript-aware channel rule — additive edit to `LeadingQuestionLint.swift`

Add, without changing `violations(in:)`'s signature:

```swift
static func violations(in pattern: String, mentionedChannels: Set<SensoryChannel>) -> [LeadingViolation]
```

and make `violations(in:)` return `violations(in: pattern, mentionedChannels: [])`. Every rule other
than `unmentionedChannel` is untouched. Replace the private `channelWords` set with a private
`channelWords: [String: SensoryChannel]` map holding R3's 28 words plus seven inflections R3 missed
(marked +):

| channel | lint trigger words |
|---|---|
| sound | sound, sounded, sounds, hear, heard, **+hearing**, music, playing, song |
| smell | smell, smelled, smelt, **+smells**, **+smelling** |
| taste | taste, tasted, **+tastes**, **+tasting** |
| sight | see, saw, **+seeing**, look, looked, **+looking**, colour, color, light |
| clothing | wear, wearing, wore |
| weather | weather, temperature, cold, warm, hot |

`unmentionedChannel` now fires for the first non-slot token of a `wh`-opened clause that is a trigger
word **and** whose channel is not in `mentionedChannels` — i.e. scan for the first *unmentioned* trigger,
not the first trigger ("What did you hear and smell?" with `[.sound]` fails on `smell`). Match = that
token's surface. With
`mentionedChannels` empty this is R3's rule plus the seven inflections. PLAN §7: a wh-question on a
channel is "allowed only when the channel appears in the episode's transcript".

## 3. Question channel and deck lookup — `Retold/Questions/QuestionChannel.swift`, edit `QuestionDeck.swift`

```swift
enum QuestionChannel: String, CaseIterable, Sendable {
    case open, time, place, people, sensory, referent, sequence, theme
    /// The channel a question is on, for the "never more than two in a row" rule (PLAN section 7:
    /// the cap is on channel, not merely on cue level).
    static func of(templateID: String, cue: CueKind) -> QuestionChannel
}
```

`of` reads a fixed `private static let` table for the 25 deck ids; an id not in the table falls back
by cue: period → open, event → open, sensory → sensory, people → people, sequence → sequence.

| channel | template ids |
|---|---|
| open | broad.open, period.else, period.slot, event.else |
| time | when.open, when.cue, event.shape |
| place | period.where |
| people | who.person, period.who, event.anyone, people.describe, people.talk, people.together |
| sensory | sensory.place, sensory.everything, sensory.mentioned |
| referent | referent.open |
| sequence | sequence.connect, sequence.otherTimes |
| theme | theme.turningPoint, theme.family, theme.work, theme.body, theme.close |

Add to `QuestionDeck`: `static func template(id: String) -> QuestionTemplate?` (first match in `all`).
No deck pattern, id or order changes.

## 4. Outcomes — `Retold/Questions/QuestionOutcome.swift`

```swift
enum QuestionOutcome: String, Sendable { case answered, dontRemember, skipped }
extension Question {
    /// The question was put in front of the user: askedCount += 1, lastAskedAt = date.
    func markShown(at date: Date = Date())
    /// Applies the user's response. False, and nothing changes, if status is .answered or .retired.
    @discardableResult func record(_ outcome: QuestionOutcome) -> Bool
}
```

Transitions (PLAN §7 retirement rule; no new field — the second skip is read off `status`):

| current status | answered | dontRemember | skipped |
|---|---|---|---|
| open | answered | **retired** | skipped |
| skipped | answered | **retired** | **retired** |
| answered / retired | (false, unchanged) | (false, unchanged) | (false, unchanged) |

**Exception: `broad.open`** ("Anything else at all, however small?") is the per-capture opener. For
it, `answered` → answered; `dontRemember` and `skipped` return true and leave the status unchanged
(open). It is never retired and never logs a negative.

A **negative** is not stored separately: it is the triple (scope, cue, slot key) of every question with
status `.retired`, where the scope is the episode / person / period the question belongs to and the slot
key is `SpanVerifier.phraseKey(slots[0].text)`, or `""` for a slotless question. Any candidate on the same
(cue, slot key) in the same scope is suppressed (PLAN §7: "any new question on that triple is
suppressed"), so a retired `event.else` also suppresses `event.shape` and `event.anyone` on that episode.
This is PLAN's literal triple and deliberately blunt: one "I don't remember" on a slotless cue quiets that
level's slotless cues for the scope. Keying slotless negatives by template id instead is a design change
for Perry, not the executor.

## 5. The engine — `Retold/Questions/QuestionEngine.swift`

### 5.1 Inputs (value snapshots) and adapters

```swift
struct AskRecord: Equatable, Sendable {
    let questionID: UUID
    let templateID: String
    let cue: CueKind
    let slotKey: String          // phraseKey of slots[0].text; "" when slotless
    let status: QuestionStatus
    let lastAskedAt: Date?
}
struct EpisodeState: Equatable, Sendable {
    var latestCaptureAt: Date?
    var transcriptTexts: [String]
    var referentSpans: [VerifiedSpan]
    var placeSpans: [VerifiedSpan]
    var asks: [AskRecord]
}
struct PersonState: Equatable, Sendable {
    var spans: [VerifiedSpan]    // unprompted spans only (see adapter)
    var episodeCount: Int
    var asks: [AskRecord]
}
struct PeriodState: Equatable, Sendable {
    var episodeCount: Int
    var asks: [AskRecord]
}
```

**Corrected spans are stale** (Sol R2 audit finding 5, 2026-10-03): every adapter below drops a stored span
when its capture (found by `span.captureID`) has a `UserCorrection` whose segment `transcript[segmentIndex]`
has `start <= span.start && span.end <= segment.end`. The span quoted words the user has since corrected, so
no question may be built on it again. A dropped span yields no candidate, so its filed question is never offered.

Declare every adapter `init` in an **extension**, so the memberwise initialisers stay available to tests.

- `AskRecord.init(_ question: Question)` — fields copied; `slotKey` as §4.
- `EpisodeState.init(episode: Episode)`:
  `latestCaptureAt` = max `createdAt` of `episode.captures`, **excluding captures whose `answersQuestionID`
  names a `broad.open` question in `episode.questions`** (an answer to the opener must not re-arm it); nil if none.
  `transcriptTexts` = captures in `createdAt` order; for each, every segment's `text` in order, then every
  correction's `correctedText` in order.
  `referentSpans` = `slots[0]` of the episode's questions whose `templateID` is `referent.open` or
  `sensory.mentioned`; `placeSpans` = `slots[0]` of those whose `templateID` is `sensory.place`. Both: questions
  sorted by (`createdAt`, `id.uuidString`) — SwiftData relationship arrays are unordered — then deduplicated
  by phrase key (first wins).
  `asks` = `AskRecord` of every question in `episode.questions`.
- `PersonState.init(person: Person)`: let Q = every question in `person.episodes`' questions (dedup by
  `id`) whose `person?.id == person.id`. `asks` = Q's records. `episodeCount` = `person.episodes.count`.
  `spans` = `slots[0]` of Q's questions whose `templateID` is `who.person`, `people.describe`, `people.talk`
  or `people.together`, sorted by (`createdAt`, `id.uuidString`), deduplicated by phrase key, **kept only if unprompted**:
  the capture with `id == span.captureID` is found among `person.episodes`' captures, and either its
  `answersQuestionID` is nil or the question it names is **found** among `person.episodes`' questions and is
  not on the `people` channel (§3). Fail closed: a span whose capture is not found, or whose capture answers a
  question that cannot be resolved there (e.g. a `period.who` question, which has no episode), is dropped (PLAN §7: people cues "only
  for a person the user named unprompted").
- `PeriodState.init(period: Period, questions: [Question])` — `Question.period` has no inverse, so the
  caller passes candidates; keep those with `period?.id == period.id`. `episodeCount` = `period.episodes.count`.

### 5.2 Output and API

```swift
struct EngineOffer: Equatable, Sendable {
    let question: AssembledQuestion
    let existingQuestionID: UUID?   // non-nil: show this persisted Question; nil: persist question.question()
    var channel: QuestionChannel { QuestionChannel.of(templateID: question.templateID, cue: question.cue) }
}
enum QuestionEngine {
    static let episodeTemplateIDs = ["referent.open", "event.else", "event.shape", "event.anyone",
        "sensory.mentioned", "sensory.place", "sensory.everything", "sequence.connect", "sequence.otherTimes"]
    static let personTemplateIDs = ["who.person", "people.describe", "people.talk", "people.together"]
    static let periodTemplateIDs = ["period.else", "period.who", "period.where"]
    static var episodeTemplates: [QuestionTemplate]   // ids above via QuestionDeck.template(id:), in order
    static var personTemplates: [QuestionTemplate]
    static var periodTemplates: [QuestionTemplate]

    static func queue(for state: EpisodeState, templates: [QuestionTemplate] = episodeTemplates) -> [EngineOffer]
    static func next(for state: EpisodeState, recentChannels: [QuestionChannel],
                     templates: [QuestionTemplate] = episodeTemplates) -> EngineOffer?
    static func queue(for state: PersonState) -> [EngineOffer]
    static func next(for state: PersonState, recentChannels: [QuestionChannel]) -> EngineOffer?
    static func queue(for state: PeriodState) -> [EngineOffer]
    static func next(for state: PeriodState, recentChannels: [QuestionChannel]) -> EngineOffer?
    /// The channels of the last two questions shown anywhere, oldest first: questions with a
    /// lastAskedAt, broad.open excluded, sorted by lastAskedAt.
    static func recentChannels(from questions: [Question]) -> [QuestionChannel]
}
```

`recentChannels` is app-wide on purpose: "in a row" is what the user experiences, across pages.

### 5.3 Episode queue — exact algorithm

1. `latestCaptureAt == nil` → `[]` (no event described yet).
2. **Broad opener pending** iff no `broad.open` ask has `lastAskedAt > latestCaptureAt` (other questions shown
   since the capture, e.g. the when question, do not consume the opener). If pending, the queue
   starts with `broad.open`: `existingQuestionID` = the id of an ask with `templateID == "broad.open"`,
   status `.open` and `lastAskedAt == nil`, if one exists (R2's filing persists one), else nil.
3. **Candidates**, for each template `t` in `templates` at index `ti`:
   - skip `t` if its cue is `.period` or `.people`, or its id is `broad.open`, `when.open` or `when.cue`;
   - slot options: `t.slotCount == 0` → one slotless option. `slotCount == 1` → by id:
     `referent.open` and `sensory.mentioned` share `referentSpans` and each span goes to **exactly one** of them
     (they would be paraphrases): if an ask exists for the span's slot key under either id, that id (so R2's
     filed `referent.open` question is reused, never orphaned); otherwise `sensory.mentioned` when
     `SensoryChannel.mentioned(in: [span.text])` is non-empty, else `referent.open`. `sensory.place` ← `placeSpans`;
     any other id → none.
     `slotCount == 2` → none. Slot index `si` = position in that list;
   - gate: cue `.sequence` only if some ask has status `.answered`, cue `.event` or `.sensory`, and a
     `templateID` other than `broad.open`, `when.open`, `when.cue` (a user-initiated detail beyond the first
     telling; answering the when wheel is not one);
   - an ask with the same `(templateID, slotKey)`: status `.answered`/`.retired` → no candidate;
     `.open`/`.skipped` → candidate with `existingQuestionID` = its id;
   - negative: no candidate if a `.retired` ask whose `templateID` is not `broad.open`, `when.open` or
     `when.cue` has the same `(cue, slotKey)` (the when question belongs to the confirm flow and must not
     silence event cues);
   - lint gate: no candidate unless `LeadingQuestionLint.violations(in: t.pattern, mentionedChannels:
     SensoryChannel.mentioned(in: transcriptTexts))` is empty;
   - assemble with `try? TemplateAssembler.assemble(t, slots:)`; a throw (e.g. a function-word slot) → no candidate.
4. **Sort** candidates ascending by this tuple, lexicographically:
   `(skipped ? 1 : 0, level, sameSlot ? 1 : 0, slotless ? 1 : 0, ti, si)` where level is event 0, sensory 1,
   sequence 2 (broad before narrow, PLAN §7); `sameSlot` = the slot key is non-empty and equals the slot
   key of the most recent ask (asks with non-nil `lastAskedAt` only, `broad.open` excluded; ties by
   `questionID.uuidString` descending) — rotate rather than return to the
   same referent; slotted before slotless — prefer what the user mentioned.
5. `next`: the pending broad opener if any (it is **exempt** from the cap); otherwise the first queued
   offer whose channel is not blocked. A channel is blocked iff `recentChannels.count >= 2` and its last two
   entries both equal it. Nothing unblocked → `nil` (no question now; the app offers nothing rather than a
   third in a row).

### 5.4 Person and period queues

Person (PLAN §7: person questions only from the person page, only for someone named unprompted, only
while "that person has fewer confirmed details than the episodes that mention them"): `[]` unless
`spans` is non-empty **and** the number of asks with status `.answered` is `< episodeCount`. Candidates:
each of `personTemplates` with slot `spans[0]`; same exclusion, negative, assembly and existing-id rules
as §5.3; sort `(skipped ? 1 : 0, ti)`. `next` = first unblocked, else nil. No broad opener.

Period (period cues "once the user has named the period"; a period counts as named once a memory is
filed in it): `[]` unless `episodeCount >= 1`. Candidates: `periodTemplates`, slotless; same rules; sort
`(skipped ? 1 : 0, ti)`. `next` = first unblocked, else nil.

## 6. Nudges — `Retold/Questions/NudgePicker.swift`

```swift
enum PeriodKey: Hashable, Sendable { case period(UUID), unfiled }
enum NudgeItemKind: Hashable, Sendable { case question(UUID), revisit(captureID: UUID) }
struct NudgeItem: Equatable, Sendable {
    let kind: NudgeItemKind; let period: PeriodKey; let createdAt: Date; let lastOfferedAt: Date?
}
struct NudgePeriod: Equatable, Sendable {
    let key: PeriodKey; let captureCount: Int; let detailCount: Int
    let lastVisitedAt: Date?; let startAge: Int?; let sortOrder: Int
}
enum NudgeCadence: String, CaseIterable, Codable, Sendable { case daily, threeTimesWeekly, weekly, off }
enum NudgePicker {
    static func score(_ period: NudgePeriod, among periods: [NudgePeriod], now: Date) -> Int
    static func pick(items: [NudgeItem], periods: [NudgePeriod], lastPeriod: PeriodKey?, now: Date) -> NudgeItem?
    static func isDue(cadence: NudgeCadence, lastNudgeAt: Date?, now: Date, calendar: Calendar) -> Bool
}
```

The caller (R7) supplies eligible items only: open or skipped questions, and every capture as a Revisit
(PLAN §7). `startAge` is the confirmed `approxStartAge` value or nil; `lastVisitedAt` is the latest
capture `createdAt` or question `lastAskedAt` in the period.

**Score** (PLAN §7: thinness first, then staleness, then age; prototyped so a well-filled period still
resurfaces about monthly when the user ignores nudges):
`T = 5 − min(5, captureCount + detailCount)`; `S = 30` if `lastVisitedAt` is nil, else
`min(30, max(0, Int(now.timeIntervalSince(lastVisitedAt) / 86_400)))`; `A` = age rank: order `periods`
by (`.unfiled` last, `startAge == nil` after non-nil, `startAge` ascending, `sortOrder` ascending); with
index `i` of `count n`, `A = 2` if `n == 1`, else `(2 * (n − 1 − i)) / (n − 1)` (integer division).
**score = 4T + S + A.** The weights are additive on purpose: PLAN §7 says the pick is *weighted* thinness,
then staleness, then age, and a strictly lexicographic key never resurfaces a well-filled period while any
thinner one has items, which starves Revisits (PLAN §2: revisiting is as much the product as asking). So a
never-visited thick period can outrank a recently visited thin one (day 6 of the §7 rotation).

**Pick:** candidate periods = those in `periods` with at least one item and `key != lastPeriod` (hard
rule: never the same period twice running — if no other period qualifies, return nil). Items whose period
is not in `periods` are ignored. Highest score wins; ties → lower `sortOrder`, then `.period` before
`.unfiled`, then `uuidString` ascending. Within the winning period, the item that sorts first by
(`lastOfferedAt == nil` first, then older `lastOfferedAt`, then `.question` before `.revisit`, then older
`createdAt`, then the kind's UUID `uuidString` ascending).

**isDue:** `.off` → false; `lastNudgeAt == nil` → true; else `d` = whole days from
`calendar.startOfDay(for: lastNudgeAt)` to `calendar.startOfDay(for: now)`; daily `d >= 1`,
threeTimesWeekly `d >= 2`, weekly `d >= 7`. (At most one a day in every cadence, PLAN §7.)

## 7. Tests — `RetoldTests/`

Fixed literal strings and values only; tests must not read the private word lists or the channel table,
and must assert the **specific** outcome (rule, id, order), not merely non-empty. Spans via
`VerifiedSpan.fixture`. `@Model` objects are built without a container, as `EntityRuleTests` does.

| File | Asserts |
|---|---|
| `SensoryChannelTests` | one sentence per channel returns exactly that channel ("The noise of the gulls" → sound; "It smelled of pine" → smell; "That flavour" → taste; "The light was orange" → sight; "I wore my coat" → clothing; "It was raining" → weather); "You see, look, the kids were playing" → empty; "I heard he left, I saw my dad, I caught a cold" → empty; punctuation and case ("SMELL," → smell); empty input → empty; two channels in one text → both. |
| `LeadingQuestionLintTests` (edit, +5) | "What were you hearing?" → unmentionedChannel (new inflection); "What did the place smell like?" with `[.smell]` → no unmentionedChannel **and** still bareDefinite; same pattern with `[.sound]` → unmentionedChannel; "What other smells come back to you?" strict → exactly `[unmentionedChannel]`, with `[.smell]` → `[]`; for every pattern in `QuestionDeck.all`, `violations(in:)` equals `violations(in:mentionedChannels: [])`; "What did you hear and smell?" with `[.sound]` → unmentionedChannel with match `smell`. |
| `QuestionChannelTests` | a literal 25-row table: each deck id → its channel from §3; an unknown id falls back by cue (`("x", .sensory)` → sensory, `("x", .period)` → open); `QuestionDeck.template(id: "event.else")?.pattern` is the R3 text; unknown id → nil. |
| `QuestionOutcomeTests` | each cell of the §4 table (9 cases, including false-and-unchanged); skip, skip → retired; skip, answered → answered; `broad.open` skip / dontRemember → true, still open; `markShown` increments `askedCount` and sets `lastAskedAt` to the given date. |
| `QuestionEngineTests` | see below. |
| `NudgePickerTests` | see below. |

**`QuestionEngineTests`** (`EpisodeState` etc. built memberwise unless the test names an adapter; give the
state structs' properties defaults — `nil`, `[]`, `0` — so tests set only what they need). In the (c)/(d)
loops an offer's ask is `AskRecord(questionID: existingQuestionID ?? new UUID, templateID:, cue:, slotKey:
SpanVerifier.phraseKey(slot text) or "", status:, lastAskedAt:)`, **created if absent, else updated in place**
(matched on templateID + slotKey; every `broad.open` offer appends a new record); the loop stops at the first nil.

- (a) no capture → `queue` empty, `next` nil.
- (b) broad first: fresh state with a capture → `next` is `broad.open`; with an `.open`, never-asked
  `broad.open` ask → `existingQuestionID` is its id; with `recentChannels [.open, .open]` → still `broad.open`.
- (c) **scenario A, literal sequence.** Referents "the pier", "the old boat", "the noise of the gulls";
  place "the cabin"; a counter t = 0 and `latestCaptureAt` = date(t). Loop 20 times: `next` with the channels
  of the last two non-broad offers; t += 1; append an `.answered` ask with `lastAskedAt` = date(t); if the
  offer is not `broad.open`, t += 1 and `latestCaptureAt` = date(t) (the answer is a capture). date(t) =
  a fixed reference date + t seconds. Expected template ids (slot text in
  brackets), exactly: broad.open, referent.open[the pier], broad.open, referent.open[the old boat],
  broad.open, event.else, broad.open, event.shape, broad.open, event.anyone, broad.open,
  sensory.mentioned[the noise of the gulls], broad.open, sensory.place[the cabin], broad.open,
  sequence.connect, broad.open, sensory.everything, broad.open, sequence.otherTimes.
  (The cap is visible at step 16: a third sensory question in a row is deferred and sequence.connect offered.)
- (d) **scenario C, skips.** Referents "the pier", "the old boat"; place "the cabin". Same loop but every
  outcome is a skip (status from §4, the ask's status updated in place); no new capture. Expected exactly:
  broad.open, referent.open[the pier], referent.open[the old boat], event.else, event.shape,
  event.anyone, sensory.place[the cabin], sensory.everything, referent.open[the pier],
  referent.open[the old boat], event.else, sensory.place[the cabin], sensory.everything, then nil.
  (`event.shape`/`event.anyone` are not re-offered: the retired `event.else` is a negative on (event, "").)
- (e) cap: after broad, with `recentChannels [.referent, .referent]` and referents available, `next` is
  `event.else`; with event.else, event.shape, event.anyone, sensory.everything, sequence.connect and
  sequence.otherTimes all answered, no places, and that history → nil although referent offers are queued.
- (f) negatives are scoped by slot: a retired `referent.open[the pier]` suppresses nothing slotless and
  does not suppress `referent.open[the old boat]`; a retired `when.open` suppresses nothing.
- (f2) broad pending: a `when.open` ask shown after the capture does not consume the opener (`next` is still
  `broad.open`); a `broad.open` ask shown after the capture does.
- (g) sequence gate: only `broad.open` and `when.open` answered → no `sequence.*` in the queue; one
  `event.else` answered → both present.
- (h) rotation: referent "the loud pier" and place "the loud pier"; after `sensory.mentioned[the loud pier]`
  is the most recent ask, the queue's sensory level reads `sensory.everything` before `sensory.place[the loud pier]`.
- (i) a referent span "I" produces no offer; "my aunt" does.
- (i2) referent family: span "the noise of the gulls" with a filed `.open` `referent.open` ask → offered as
  `referent.open` with that ask's id, and no `sensory.mentioned` for it; with no ask → `sensory.mentioned` only.
- (i3) slotted first within a level: `templates: [event.else, referent.open]` (deck templates, this order)
  with one referent → the referent offer is queued first; `templates: [sensory.everything, sensory.place]`
  with one place → `sensory.place` first.
- (j) lint gate: `templates: [QuestionTemplate(id: "test.sounds", cue: .sensory, pattern: "What other
  sounds come back to you?")]` → not queued with `transcriptTexts ["We sat by the lake"]`; queued with
  `["the noise of the boats"]`.
- (k) excluded templates: `templates: QuestionDeck.all` on a rich state → no queued id has cue period or
  people, and none is `when.open`, `when.cue`, `period.slot` or a `theme.*`.
- (l) person: gate fails with no spans, and with `answered == episodeCount`; otherwise order is
  who.person, people.describe, people.talk, people.together; `recentChannels [.people, .people]` → nil.
- (m) period: `episodeCount 0` → empty; otherwise period.else, period.who, period.where; a retired
  `period.else` suppresses the other two (same (period, "") triple); `recentChannels [.open, .open]` → `next`
  is `period.who`.
- (n) adapters (`@MainActor`, objects inserted into `RetoldSchema.makeInMemoryContainer()`'s main
  context so SwiftData maintains inverses; set only the owning side): `EpisodeState(episode:)` from an `Episode` with two captures (one with a correction) and
  filing questions built via `TemplateAssembler.followUps` → transcript texts in order with the
  correction last for its capture; referent/place spans as filed, deduplicated; `latestCaptureAt` = the
  later capture. `PersonState(person:)`: a span from a capture answering an `event.anyone` question is
  dropped; one from a capture with no `answersQuestionID` is kept; one whose capture answers an unresolvable
  question id is dropped; one whose capture is not in `person.episodes` is dropped. `EpisodeState(episode:)`: a
  capture answering the episode's `broad.open` question does not move `latestCaptureAt`.
  A referent span inside a corrected segment is absent from `referentSpans`; a person span inside a
  corrected segment is absent from `PersonState.spans`. `recentChannels(from:)` ignores
  `broad.open` and never-shown questions and returns the last two, oldest first.

**`NudgePickerTests`:** literal `score` cases (empty never-visited oldest of 6 → 4·5 + 30 + 2 = 52; 10
captures visited 3 days ago, fourth-oldest of 6 (i = 3) → 0 + 3 + 0 = 3); the same period twice → excluded, and the
only eligible period being `lastPeriod` → nil; a period with no items never wins; ties → lower
`sortOrder`, then `.period` before `.unfiled` at equal score and sortOrder; a single period scores A = 2; within-period order (never-offered before offered, question before revisit at equal
`lastOfferedAt`); **30-day literal rotation**: six periods (start ages 0, 5, 11, 14, 18, 20; sortOrder
0–5; the age-14 one has 4 captures + 6 details, the rest 0), each with one item; each day `pick` with the
previous pick's period as `lastPeriod`, then set the picked period's `lastVisitedAt` to that day; expected
by start age: 0 5 11 18 20 14 0 5 11 18 0 20 5 11 0 18 5 20 0 11 5 18 0 20 11 5 0 18 11 20.
`isDue`: a table over all four cadences at d = 0, 1, 2, 7 with a UTC Gregorian calendar, including
23:59 → 00:01 counting as one day, and nil `lastNudgeAt` → true except `.off`.

## Do not

No new dependency; no `FoundationModels`; no `try!`, `Task.detached`, `@unchecked Sendable`,
`nonisolated(unsafe)`; no `!` outside tests; no schema change; no change to any R1–R3 behaviour other
than §2's seven inflections and the new overload; no edit to deck copy; no `VerifiedSpan` built outside
`SpanVerifier` (tests use `.fixture`); no AI attribution in code, comments or commits. If an expected
sequence in §7 does not come out, **stop and report the step where it diverges** — do not change the
sort key or the test to make it pass; the order is the boss's call.

## Done when

PR CI green (Build & XCTest + Release compile): R1–R3 tests unchanged and passing, plus the new ones.
Boss **mutation pass**: separately disable (1) the broad-opener rule, (2) the cap, (3) the negative
check, (4) the sequence gate, (5) the `sameSlot` key, (6) the slotted-first key, (7) the lint gate,
(8) the referent/sensory.mentioned split, (9) the unprompted filter, (10) the person answered-count gate,
(11) the nudge `lastPeriod` rule, (12) each of T, S, A in the score, (13) the broad.open outcome exception,
(14) the referent-family reuse of a filed ask, (15) the broad-answer capture exclusion in the adapter,
(16) the when.* exclusions from the negative and the sequence gate, (17) the fail-closed unresolved-question drop, (18) the corrected-span drop
— at least one test must fail for each; a survivor is a missing test and blocks merge. Pre-merge review:
Kimi transition review per the strategy row, or the Sonnet `reviewer` if Kimi built it. `ai/STATE.md`
names R5 next.
