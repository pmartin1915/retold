# Memory-recall app (working name "Hippo") — plan

_Written 2026-09-21 (Fable session, laptop) from `MEMORY-APP-CONCEPT-2026-09-21.md` and the
kickoff handoff. This is the plan in the shape of `IPHONE-DUO-PLAN-2026-09-18.md`; it is NOT a
decision to build. Phase gates, in order: (a) the Gemini reports for prompts C and D are
adjudicated into `research-prompts/MEMORY-RECALL-SYNTHESIS-<date>.md` — **half met: C is in, D
produced no report after three failed runs** (synthesis §D); (b) this plan exists — **met**;
(c) Sol has reviewed it — **met 2026-09-21**, adjudicated in `HIPPO-PLAN-REVIEWS-2026-09-21.md`
with Kimi's review of §7; (d) Perry says build — **open**. Build order stays **StoryCue first**
(its window, 2026-10-23, is fixed; this one is not). No repo, no Swift source, no identifiers
yet._

**Research-status key.** Every claim that depends on a Gemini report is tagged **`[R-C §n]`**
(science) or **`[R-D §n]`** (Apple stack). **Report C is in and adjudicated** —
`research-prompts/MEMORY-RECALL-SYNTHESIS-2026-09-21.md`; its adopted findings are folded in
below with "(C, adopted)" notes, so an `[R-C]` tag now means "settled, see the synthesis".
**Report D does not exist**: three runs failed on 2026-09-21 (synthesis §D says how, and what to
check before re-running). Every `[R-D]` tag is therefore still open as a *second source*; where a
row also says "Sol, High", Sol confirmed the fact against Apple documentation in his review, and
the plan is built on it. The remaining untagged platform facts are this session's recollection
of Apple's iOS 26 documentation and WWDC 2025. Whether to waive D or re-run it is Perry's call.

## 0. The decision this plan is for, in one line

A voice-first, on-device, no-account iPhone app whose whole job is to make the user
**retrieve** an autobiographical memory and then **ask the next question** — Action button →
talk → the app files it as questions the user confirms → follow-ups walk the period → later
nudges prefer thin, old periods. Nothing leaves the phone. Zero marginal cost by design.

Two sharpenings from report C (adopted): the Action-button moment is **direct retrieval** — a
cue bypassed the search and the memory arrived, which is why capture must be instant — and the
Ask surface is **generative retrieval**, a top-down walk of the hierarchy. And the value claim is
not "rehearsal strengthens": the testing effect does not persist for autobiographical memory
(C §2), so what the app does is **extract the memory into a durable record and bring the user
back to it**. Revisiting is as much the product as asking.

## 1. Platform constraints (what decides the design)

| Fact | Status | Consequence for us |
|---|---|---|
| **Foundation Models framework** (iOS 26): `SystemLanguageModel.default.availability` is `.available` or `.unavailable(reason:)` with `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady` | Known (WWDC25 "Meet the Foundation Models framework"); regions/languages **[R-D §1]** | Three distinct no-model states, each with its own copy; the app must be whole in all three (§8) |
| On-device model context is **4,096 tokens per session, shared** by instructions, prompt, the injected schema and the output; a context-exceeded error is thrown when exceeded (Sol: spelled `LanguageModelError.contextSizeExceeded` in Xcode 27; `GenerationError` deprecated) | Sol, High; **[R-D §1]** to confirm and to say whether iOS 27 changed it | A 10-minute capture *nominally* fits one call but not reliably; **windowed extraction with measured token counts is the rule** (§6.3), and it must still work if the real figure is smaller |
| `@Generable` structs with `@Guide` constraints; nested `@Generable` types and arrays of them are supported in Apple's own examples | Known; nesting depth and array-size limits **[R-D §1]** | The filing schema is one nested struct (§6.2). Keep it shallow: two levels, short arrays |
| `GenerationError.guardrailViolation`; the guardrails' scope over personal content (grief, relationships, health mentions) is not documented in detail | **[R-D §1]** | Every model call has a non-model fallback path (§8). A refusal files the capture as "unfiled" with the static deck, never as an error the user must fix |
| `SystemLanguageModel(useCase: .contentTagging)` — a specialised adapter for topics, entities, emotions | Known to exist; quality for names/places **[R-D §1]** | Candidate for the people/place pass in the window extractor; the general model does the rest of the extraction. No model writes a question (§5.1) |
| **`SpeechAnalyzer` / `SpeechTranscriber`** (iOS 26): on-device, long-form, live volatile results, `AttributedString` results with audio time ranges, **file input** (`start(inputAudioFile:)`) as well as streams; models fetched via `AssetInventory` | Known; language list, model size, whether it needs Wi-Fi, and 10–20-minute continuous behaviour **[R-D §2]** | Save-audio-first is possible: record to file and transcribe from the file if the live pass dies. Time ranges let every derived detail point at the seconds of audio it came from (§5.1) |
| Whether `SpeechTranscriber` runs on **non-Apple-Intelligence** iPhones on iOS 26, or falls back to `DictationTranscriber` | **[R-D §2]** | Decides whether the no-model mode still has a transcript. Plan assumes yes (transcript everywhere, model optional); if wrong, no-model mode is audio + manual notes |
| Speech authorisation: `SpeechAnalyzer` modules are on-device and do **not** require `SFSpeechRecognizer.requestAuthorization`; `NSSpeechRecognitionUsageDescription` is needed only if the server-capable `SFSpeechRecognizer` is used | Sol, High; **[R-D §2, §6]** to confirm | Ship the microphone string only, unless report D contradicts Sol. `SpeechTranscriber.isAvailable` + locale/asset checks gate the feature, not a permission prompt |
| **Action button → Control → intent.** The fastest direct surface is a `ControlWidgetButton` (iOS 18+; the Action button can invoke a Control); it merely runs an `AppIntent`. `openAppWhenRun` is **deprecated in iOS 26** — use `supportedModes = [.foreground(.immediate)]` or `OpenIntent` | Sol, High (latency: Medium) | The door is the Control; the app must still come to the foreground and, if locked, be unlocked. "Under one second" is a measurement, not a promise: test terminated/unlocked, terminated/locked, warm/locked, and interruption recovery on the 16 Pro |
| A general `AVAudioSession` recording **cannot be activated from a cold background process**, including while locked: foreground/unlock → permission → session activation → file open → engine start is the minimum path | Sol, High (Apple DTS) | Microphone permission is granted during onboarding, never on the capture path. Nothing records before the UI appears |
| **`AudioRecordingIntent`** (App Intents, iOS 18) grants **no** microphone exemption and requires a Live Activity for the whole recording or iOS stops it | Sol, High | Not the door. Considered only if a Live Activity is wanted for lock-screen status while recording; otherwise a plain foreground intent |
| Background recording: `UIBackgroundModes: audio` keeps an active `AVAudioSession` (`.record`) alive when the phone locks; interruptions arrive as `AVAudioSession.interruptionNotification` | Known | Lock mid-memory is the common case (phone in pocket, eyes closed). Handle interruption → pause, keep the file, resume on user action |
| Camera Control (iPhone 16+) cannot launch third-party non-camera intents | Believed no **[R-D §3]** | Not a door |
| **Data Protection**: `.complete` files are unreadable *and unwritable* while locked; `.completeUnlessOpen` lets an already-open file keep being written | Sol, High | In-progress audio file: `.completeUnlessOpen`. The SwiftData store: `.complete` — which means **transcript segments cannot be appended to the store while locked** (Sol S6). So capture writes an append-only **sidecar journal** (`.completeUnlessOpen`) beside the audio; on unlock the journal is imported into the store and the closed audio file is reclassified to `.complete` |
| **CloudKit private database**: encrypted, but what Apple can read with vs without Advanced Data Protection, and whether `CKRecord.encryptedValues` gives E2E for our fields | **[R-D §5]** | v1 has **no sync**. The honest privacy-policy sentence for a later sync version depends on this answer |
| **App Review** rules for gating features on Apple Intelligence; allowed wording for "requires iPhone 15 Pro or later" | **[R-D §6]** | Listing copy (§9) written after the report; the app itself never hard-requires the model |
| **`JournalingSuggestions`** (iOS 17.2+) cues about recent activity, not a chosen past date range | Believed **[R-D §4]** | Not the core cue source. v2 candidate at most |
| **PhotoKit** by date range as a period cue | Known feasible; limited-library UX **[R-D §4]** | v2 |
| Share of active US iPhones with Apple Intelligence hardware | **[R-D §7]** | Sizes how much the no-model mode matters commercially; changes nothing about whether it exists |
| **Retrieval strengthens; retrieval can distort** — testing effect, reconsolidation, misinformation effect, co-witness contamination | **[R-C §2]** | Rule 1 (§5.1) is the mechanism whatever the exact effect sizes are; the report decides how loud the copy can be about "remember more" |
| Autobiographical memory hierarchy (Conway): lifetime periods → general events → event-specific knowledge; cues walk it; sensory and people cues produce specific rather than generic memories | **[R-C §1, §3]** | This IS the data model (§6.1) and the question engine (§7) |
| Reminiscence bump (≈ ages 10–30) | **[R-C §1]** | The default period seeds (§8) start with school years, not toddlerhood |
| FDA general-wellness boundary for memory copy; FTC brain-training actions (Lumosity 2016) | **[R-C §4]** | The forbidden-word list in §9 starts from this session's reading and is finalised from the report |
| Name "Hippo" conflict check | **[R-C §6]** | No identifiers until it returns |

## 2. The app (capture → file → ask → browse → keep)

**Capture.** Action button → a Control → a foreground intent → the recording view (Sol S4:
this is the fastest surface; nothing can start the microphone from the background or before
unlock, so "thought to red light" is foreground launch time plus session activation, measured
on the 16 Pro in four states and never promised as a number) → red light, live transcript
scrolling as volatile results, elapsed time, one Stop button. Microphone permission was granted
in onboarding, never here. Audio is being written to a file from the first buffer; final
transcript segments are appended to a lock-safe sidecar journal as they arrive (§1, Data
Protection). A crash or a lock after the first second loses nothing. Stop → the capture exists
in the library immediately, labelled "unfiled", before any model runs.

**File.** If the model is available: a *proposal* appears (§6.2) — a working title, the period
it seems to belong to (from the user's own period list), **when** as a question ("Was this the
summer you were about 12?"), places and people as spoken, and three to six follow-up questions.
**There is no generated summary** (C §2, adopted 2026-09-21: the first draft had a labelled
two-sentence paraphrase; the false-memory implantation evidence says even a labelled summary
read right after retrieval is the hazard, so it is gone). The list-row text is a **verbatim
excerpt** — the first ~25 spoken words. The user taps to confirm, edit, or reject each item;
**nothing is filed as a fact until it is confirmed**, and every confirmed item keeps its
provenance (§6.1). If the model is unavailable or refuses: the same screen with empty fields, a
period picker, and the static deck's questions for that period (§8).

**Ask.** The follow-up questions queue under the episode and its period. The user can answer
one now (another capture, attached to the question) or leave it. Later, a notification offers
one item chosen by the engine (§7) — a question, or a **Revisit** (listen to an old capture;
C §2: re-exposure does as much for retention as retrieval) — thin periods first, then old ones,
spaced. Answering is always another capture; there is no typing-only path in v1 beyond editing a
name.

**Browse.** Three views: **Timeline** (periods in age order; each period a row of episodes,
each row plays), **People** (a page per person, accreting from every capture that names them),
**Places**. An episode page shows the verbatim transcript with the audio scrubber, the confirmed
facts, and the open questions. Nothing on any page is generated prose.

**Keep.** Everything on device under Data Protection. **Export**, one tap, always: a folder with
`audio/<capture-id>.m4a`, `transcripts/<capture-id>.md` (verbatim, with timestamps), and
`index.md` (periods → episodes → confirmed facts and open questions), zipped to the share
sheet. The premise of the app is fear of losing things; lock-in would betray it. Sync is a
later decision that changes the privacy policy [R-D §5].

**Not in v1:** photos import, `JournalingSuggestions`, embeddings/"similar memories", sharing,
Apple Watch capture, any cloud model, accounts, scores of any kind.

## 3. Why native Swift on the StoryCue skeleton

Same reasoning as StoryCue §3: the Tauri pattern cannot reach `SpeechAnalyzer`, Foundation
Models, App Intents or Data Protection cleanly from a WKWebView. StoryCue, once its week-1
recorder exists, provides: the XcodeGen `project.yml` pattern, `build.yml` on `macos-27` with
XCTest on the simulator, `deploy.yml` with `CURRENT_PROJECT_VERSION=${{ github.run_number }}`
and the verify-the-.ipa step, the `CaptureService` protocol with a mock for XCTest, a local
library with export, the consent/privacy conventions, and the privacy-policy-verified-against-
code rule (Wilderness DECISIONS 2026-08-04). This app forks that skeleton rather than sharing a
package: the two apps diverge immediately (audio-only vs video, no Duo path here), and a shared
Swift package would be a single-use abstraction.

Identifiers: **none yet.** Pattern will follow Shortless/StoryCue (`dev.pmartin1915.<name>`,
`pmartin1915/<name>`), created only after the name check [R-C §6] and Perry's build decision.

## 4. Pipeline deltas from StoryCue

Expected: **none in the workflows.** Deltas are in the app target only:

1. Frameworks: `FoundationModels`, `Speech` (SpeechAnalyzer), `AppIntents`, `WidgetKit`
   (controls), `SwiftData`, `AVFoundation`, `UserNotifications`.
2. `UIBackgroundModes: audio`; usage string `NSMicrophoneUsageDescription` only —
   `SpeechAnalyzer` needs no speech-recognition authorisation (Sol S5, High; [R-D §2] to
   confirm), so `NSSpeechRecognitionUsageDescription` is added only if `SFSpeechRecognizer` is
   ever used; `PrivacyInfo.xcprivacy` with no tracking, no required-reason APIs beyond file
   timestamps/disk space if used.
3. **No Duo gate.** No `#if DUO_SDK`. The only `#available` gates are iOS 26 (floor) and, if a
   27-only API is adopted, `#available(iOS 27, *)` — the plan assumes an **iOS 26 floor** and
   takes nothing from 27 unless report D shows it buys a lot [R-D §1].
4. Simulator tests: the simulator has no Apple Intelligence model (it can route the Mac's
   microphone, Sol S7, but hosted runners have none), so XCTest runs the state machine, the
   span verifier and template assembly (§5.1, §6.2), the question engine (§7), and the export
   manifest against fixtures. Model and speech paths get **protocols with mocks**
   (`FilingModel`, `Transcriber`) and are exercised only on Perry's iPhone 16 Pro via
   TestFlight. CI green therefore never means "the model path works"; the handoff for each
   week says which rung passed, as StoryCue §5 does.

## 5. The three hazards as design rules, each with its enforcing mechanism

### 5.1 Rule 1 — a memory app never authors memories

The failure mode: a generated summary that adds one plausible detail, or shifts a valence, or
supplies a logical bridge, which the user then reads inside the reconsolidation window and later
remembers as theirs [R-C §2: misinformation effect; rich-false-memory implantation *d* ≈ 1.43 in
suggestive-interview paradigms — over-applied by the report, but the design cost of honouring
it is nil]. **Consequence adopted 2026-09-21: the app generates no prose about a memory at all.**
The only generated text is *questions* and a *title*. Mechanisms, all of which must exist
before the model path ships:

1. **The record is the audio and the verbatim transcript, and they are immutable.**
   `Capture.transcript` is written once by the transcriber and never edited by the model or the
   app. Editing a transcript is a user act that creates a `UserCorrection` alongside it, never a
   rewrite.
2. **Every derived value carries provenance and status.** A `Confirmable<T>` (§6.1) is
   `.proposed` until the user taps it; the UI renders proposed values in a distinct style with
   the word *suggested*, and nothing `.proposed` appears on Timeline, People or Places pages.
3. **The model writes nothing the user reads. It extracts; Swift assembles.** (Sol blocker 1
   and 3, adopted 2026-09-21; replaces the first draft, in which the model generated the title
   and the follow-up questions and a lexical validator checked them. Sol's point: a validator
   that checks tokens cannot check *meaning* — a title can falsely combine spoken words, a
   question can presuppose an event, lowercase inventions pass, and the user has already read
   the text by the time they decline it.) The schema (§6.2) has no free-text field at all. The
   model returns **exact transcript spans**, each typed (person, place, time-cue, referent) —
   and a period pick from the user's own list. Swift verifies each span is a **contiguous
   substring of the transcript** and attaches its audio time range; a span that does not match
   is **dropped silently** — never rephrased as "Did you mention X?", which would itself expose
   the invention. Titles and questions are then built by Swift from an **audited template
   deck** whose slots take only verified spans or confirmed entities. The lint in §7 runs over
   the deck at CI time, so a question cannot lead because no question is ever composed at run
   time from anything but a template and a quote.
4. **Every inference is a question the user answers, never a value the model supplies.** There
   is no field for a year, an age or a person's role anywhere the model can reach. "When" is a
   template ("Roughly when was this — a year, or how old you were?", or with a verified time-cue
   span: "You said '{span}' — roughly what year would that be?"), answered by the user on a
   wheel or with "not sure". "Who" is the same shape on the person page.
5. **No generated prose, anywhere.** (C §2, adopted 2026-09-21.) No summary field exists. The
   list-row text is a verbatim excerpt. The title is either a **contiguous transcript span** the
   model pointed at (verified, confirmed by tap) or **typed by the user**. Export contains only
   the user's words, the confirmed facts and the open questions.
6. **Questions carry provenance too** (Sol blocker 1): a `Question` records its template id and
   the spans that filled its slots, so any question can be traced to the seconds of audio that
   justify it, and a question whose slot span is later corrected by the user is retired.
7. **Model instructions are the last line, not the first.** The `instructions` say: return only
   words that appear verbatim in the text, in the order they appear; never add, never
   paraphrase. They are necessary and known to be insufficient; that is why 1–6 exist.

Sol's remaining probe (§10, second round when code exists): a template whose slot is a verified
span can still juxtapose two true quotes into a false relation ("You mentioned {Dan} and {the
lake} — what happened there?"). Rule for the deck: **one slot per template**, or two slots only
when both spans come from the same transcript segment.

### 5.2 Rule 2 — the app prompts; it does not assess (standing wellness-claims decision)

Decision #47 (**adopted 2026-09-06**) sets the company's posture for Wilderness: *"the app
instructs; it does not measure."* The same posture here reads: **the app prompts; it does not
assess.** Mechanisms:

1. **No performance metrics exist in the data model.** There is no field for recall quality,
   response time, completeness, or trend. The engine's "thin period" heuristic (§7) counts
   captures per period, which is content volume, and its wording is about the *period* ("You
   haven't visited Junior High in a while"), never about the *user's memory*.
2. **A copy lint in CI.** A test loads every string catalog, the App Store metadata files kept
   in-repo, and the privacy policy source, and fails on a forbidden list: *memory test, score,
   improve(d/s) your memory, cognitive, decline, assess(ment), screen(ing), MCI, dementia,
   Alzheimer, diagnos-, treat-, cure-, prevent-, brain training, sharpen, PTSD, depression,
   ADHD, anxiety, trauma, therapy* (C §4, adopted 2026-09-21: the FDA general-wellness examples
   permit "remember more, reflect more"; any disease or condition term takes the app out of
   the safe harbour, and the FTC's Lumosity and LearningRx actions were for exactly those
   claims). The guidance version that governs copy review is the **2026-01-06** revision
   archived with Decision #47, not the 2016 text the report cites.
3. **No streaks, no percentages, no charts.** Nudges say "one question waiting", never "3-day
   streak".
4. The general-wellness reading (memory support / reflection as low-risk wellness) is confirmed
   or corrected by [R-C §4] before any listing copy is written (§9).

### 5.3 Rule 3 — a no-model mode is mandatory

The AI layer needs Apple Intelligence hardware and a user who has it switched on. Mechanism: the
model is behind a `FilingModel` protocol with three implementations — `FoundationFilingModel`,
`DeckFilingModel` (static prompt deck, no inference), and a test mock — and the app selects at
launch and on every `availability` change. **Every screen is designed against
`DeckFilingModel` first**; the Foundation model is an enhancement of the same screens. §8 is
the spec. Perry's iPhone 16 Pro exercises the model path via TestFlight; the no-model path is
exercised on the simulator and on any older test device.

## 6. Data model and the `@Generable` schema

### 6.1 Entities (SwiftData; names are the plan's, not final)

The hierarchy is Conway's [R-C §1]: **Period → Episode → Detail**, plus the cross-cutting
**Person** and **Place**, the primary record **Capture**, and **Question**.

```swift
// Provenance is the whole point of this model. Every fact the user did not
// speak verbatim is a Confirmable, and starts .proposed.
enum Provenance: Codable {
    case userTyped
    case userConfirmed(proposedBy: Origin)
    case transcriptQuote(capture: UUID, range: ClosedRange<TimeInterval>)
    case model                       // never persisted as a *fact*; only inside a .proposed
    case deck(promptID: String)
}
enum Origin: Codable { case model, deck, user }
enum ConfirmStatus: Codable { case proposed, confirmed, rejected }

struct Confirmable<T: Codable>: Codable {
    var value: T
    var status: ConfirmStatus
    var provenance: Provenance
}

@Model final class Period {             // "Camp Lakeview summers", "Junior high"
    var title: String                   // always user-owned text
    var approxStartAge: Confirmable<Int>?
    var approxEndAge: Confirmable<Int>?
    var sortOrder: Int
    @Relationship(deleteRule: .nullify) var episodes: [Episode]
    var createdAt: Date
}

@Model final class Episode {            // one memory: "the Hawaii trip"
    var title: Confirmable<String>
    var period: Period?                 // nil until confirmed
    var whenQuestion: Question?         // a template Question (§6.2), with provenance like any other
    var approxYear: Confirmable<Int>?   // only ever set by the user answering whenQuestion
    var approxAge:  Confirmable<Int>?
    var place: Place?
    @Relationship var people: [Person]
    @Relationship(deleteRule: .cascade) var captures: [Capture]
    @Relationship(deleteRule: .cascade) var details: [Detail]
    @Relationship(deleteRule: .cascade) var questions: [Question]
    var excerpt: String                 // first ~25 words of the first capture, VERBATIM;
                                        // the list-row text. No generated summary exists (C §2)
    var createdAt: Date
}

@Model final class Detail {             // event-specific knowledge, always a quote
    var text: String
    var kind: DetailKind                // sensory, people, sequence, emotion, object
    var provenance: Provenance          // .transcriptQuote or .userTyped, never .model
    var episode: Episode?
}
enum DetailKind: String, Codable { case sensory, people, sequence, emotion, object }

@Model final class Person {
    var name: String                    // user-owned; the model only ever supplies nameAsSpoken
    var aliases: [String]
    var note: String?                   // user-typed only
    @Relationship var episodes: [Episode]
}

@Model final class Place { var name: String; @Relationship var episodes: [Episode] }

@Model final class Capture {            // THE record
    var audioURL: URL                   // .completeUnlessOpen while recording, .complete after
    var duration: TimeInterval
    var transcript: [TranscriptSegment] // immutable after transcription completes
    var transcriptionStatus: TranscriptionStatus   // pending, live, fromFile, complete, failed
    var createdAt: Date
    var episode: Episode?
    var answersQuestion: Question?
    var corrections: [UserCorrection]   // never rewrites
}
struct TranscriptSegment: Codable { var text: String; var start: TimeInterval; var end: TimeInterval; var isFinal: Bool }

@Model final class Question {
    var text: String                    // assembled by Swift from templateID + slots; never model text
    var templateID: String              // the audited deck entry it was built from (Sol S1)
    var slots: [VerifiedSpan]           // the exact transcript spans that filled it, with audio ranges
    var cue: CueKind                    // period, event, sensory, people, sequence
    var origin: Origin                  // deck (all questions are deck templates now); user
    var status: QuestionStatus          // open, answered, skipped, retired
    var episode: Episode?               // or
    var period: Period?                 // or
    var person: Person?
    var askedCount: Int
    var lastAskedAt: Date?
    var createdAt: Date
}
enum CueKind: String, Codable { case period, event, sensory, people, sequence }
```

Design notes. `Episode.approxYear` can only be written by the confirm flow, and its
provenance is always `.userConfirmed(proposedBy: .model)` or `.userTyped`; there is no code path
that writes `.model` into a persisted fact. `Detail` has no `Confirmable` because details are
quotes: the confirm flow offers transcript spans (from the segment time ranges) to tag as a
sensory or people detail; the model may *point* at a span but cannot *write* one.

### 6.2 The `@Generable` schema, and the confirm-before-file flow

_Rewritten 2026-09-21 after Sol's review (`HIPPO-PLAN-REVIEWS-2026-09-21.md` §2, S1/S3). The
first draft asked the model for a title, a "when" question and three to six follow-up
questions as free text. The model now returns **spans and a period pick only**; every string
the user reads is assembled in Swift from an audited template deck._

```swift
import FoundationModels

/// One call per transcript window (§6.3). Nothing here is free text: every String must be an
/// exact, contiguous quotation of the window, and Swift verifies that before anything is kept.
@Generable
struct WindowExtract {
    @Guide(description: "The one entry from the supplied list of life periods that fits best, copied exactly, or nil if none fits.")
    var periodName: String?

    @Guide(description: "Exact phrases from the text, copied word for word, that name or describe a person, e.g. 'Dan' or 'my camp counselor'.", .maximumCount(8))
    var people: [String]

    @Guide(description: "Exact phrases from the text, copied word for word, that name a place.", .maximumCount(8))
    var places: [String]

    @Guide(description: "Exact phrases from the text, copied word for word, that say roughly when this was, e.g. 'the summer before eighth grade'. Empty if none.", .maximumCount(4))
    var timeCues: [String]

    @Guide(description: "Exact short phrases from the text, copied word for word, naming a thing, activity, or moment the speaker mentioned that could be asked about.", .maximumCount(8))
    var referents: [Referent]

    @Guide(description: "One exact phrase of at most eight words, copied word for word from the text, that could serve as a title.")
    var titleSpan: String?
}

@Generable
struct Referent {
    @Guide(description: "The exact phrase, copied word for word.")
    var span: String
    @Guide(description: "What kind of thing it is.")
    var kind: ReferentKind
}

@Generable
enum ReferentKind { case object, activity, moment, sensory }
```

Array bounds on every field (Sol S2: unbounded arrays are unbounded output tokens). The `@Guide`
array-constraint spelling (`.maximumCount`) is confirmed against the SDK when the first Swift is
written.

**Verification in Swift, before anything is drawn.** Each returned string is located as a
**contiguous, case-insensitive substring** of the window's transcript segments; on success it
becomes a `VerifiedSpan { text, captureID, range: ClosedRange<TimeInterval> }` carrying the
audio time range from `TranscriptSegment`. A string that does not match is **dropped silently**
(Sol S1: the first draft turned a failed name into "Did you mention someone called …?", which
exposes the invention). Verified spans are de-duplicated and merged across windows
deterministically in Swift (§6.3). No second model call ever sees generated output.

**Assembly from templates.** Titles, the "when" question, "who" questions and follow-ups are
built by Swift from the authored deck (§7, §8), which is linted in CI. A template has at most
**one slot**, or two only when both spans fall in the same transcript segment (§5.1 tail). Slot
fillers are verified spans or confirmed entities, nothing else. Examples:

| Purpose | Template | Slot |
|---|---|---|
| Title | `{titleSpan}` verbatim, or the user types one | verified span |
| When | "Roughly when was this — a year, or how old you were?" | none |
| When, with a cue | "You said '{cue}' — roughly what year would that be?" | verified time-cue span |
| Who | "Who was {person} to you, back then?" | verified person span |
| Sensory (report-everything) | "Anything about {place} itself — the light, the sounds, the weather? However small." | verified place span |
| Referent | "You mentioned {referent}. Is there anything else about that?" | verified referent span |
| Broad | "Anything else at all, however small?" | none |

Session set-up: `LanguageModelSession(instructions:)` with the extraction-only instructions
(§5.1 item 7) and the user's period titles supplied in the prompt as the only allowed
`periodName` vocabulary; a **fresh session per window** (Sol S2: no transcript accumulates in a
session's context). `respond(to:generating: WindowExtract.self)`; `GenerationOptions` with low
temperature. Errors: every case of the framework's error enum is handled (Sol S7 — refusal,
assets not ready, unsupported locale, decoding failure, context exceeded, rate limit, timeout,
cancellation) and every one of them lands in the no-model path for that capture, not in an
alert. (Sol reports the context-exceeded case is spelled `LanguageModelError.contextSizeExceeded`
in Xcode 27 and that `GenerationError` is deprecated; verify against the SDK in use.)

**Confirm-before-file flow** (the screen after Stop):

1. Capture is saved and shown as *Unfiled* with its transcript. Extraction runs per window.
2. The user sees, in order: **title** (the verified span as a chip: tap to accept, or type
   one), **period** (a chip; tap to accept, or pick another, or "new period…"), **when** (the
   template question with a year/age wheel and a "not sure" button — "not sure" files nothing
   and keeps the question open), **people** (one chip per verified span: accept as a new Person,
   merge into an existing Person by name match, or reject; the *who* question is queued, not
   answered here), **places** (same), **follow-ups** (assembled from templates; each a row with
   "answer now" / "later" / "not this one"). The excerpt under the title is the transcript's
   own first words and is not a tappable item.
3. "File it" writes the `Episode` with only `.confirmed` values; rejected chips are kept on the
   capture as a `RejectedProposal` log for tests.
4. Nothing in this flow blocks Stop → next capture; a user can leave it Unfiled and file later.

### 6.3 Fitting the context window — windowed extraction

The on-device context is **4,096 tokens per session, shared** by instructions, prompt, the
injected `@Generable` JSON schema and the output (Sol: High confidence; report D to confirm
[R-D §1]). The first draft's arithmetic was wrong (Sol S2): on its own numbers — instructions
≈ 250, schema ≈ 350, a 10-minute transcript ≈ 2,000, output ≈ 500 — a single call *nominally*
fits, so "roughly seven minutes" did not follow. It is still unreliable at that length because
speech rate, schema cost and tokenisation vary, so the rule is:

1. **Measure, never estimate from elapsed time.** Use the SDK's runtime token accounting (Sol
   names `SystemLanguageModel.contextSize` and `tokenCount(for:)`; confirm the spelling) and
   Instruments on the 16 Pro; the chunker reads the measured budget, not a constant.
2. **Fresh session per window.** Windows of **1,400–1,800 tokens** at segment boundaries, with
   **150–250 tokens of overlap**, a **~700-token output reserve**, and **15 % headroom**.
3. Per window, one `WindowExtract` call (§6.2). Every returned string is verified as a
   contiguous span of *its own window*.
4. **Merge in Swift, deterministically** (Sol S3, replaces the first draft's second model call
   over concatenated extracts, which could recombine generated text into a relation nobody
   spoke): union the verified spans across windows, de-duplicate by normalised text and by
   overlapping time range, rank by first occurrence, and resolve `periodName` by majority with
   the first window breaking ties. Templates are filled only after the merge.

If report D shows a larger on-device window, the chunk size rises and nothing else changes. A
Private Cloud Compute model is **not** used for this app — "nothing leaves the device" is the
product.

## 7. The question engine

Inputs: the episode's confirmed facts, its open questions, the period's other episodes, the
person pages, and the age of each period. Outputs: the *next question to offer*, and the queue
order on each page. **Every question is a question; none contains a detail the user did not
say; none proposes an answer.** Kimi's review (§10) is on this section.

_Revised 2026-09-21 after Kimi's review (`HIPPO-PLAN-REVIEWS-2026-09-21.md` §1): the first
draft's example questions presupposed continuations ("the next summer"), assumed sensory
channels ("what did it smell like"), and demanded verbatim recall ("something they said that you
can still hear"). Every example below now admits "nothing" or "I don't know" as the honest
answer, and the ordering rule unlocks a level only on what the user has already said._

**Walk the hierarchy** [R-C §1, §3], but only on referents the user has already named:

1. *Period cues* once the user has named the period: "What else comes to mind from that time?",
   "Who do you think of when you think of that time?"
2. *Event cues* once the user has described an event: "Is there anything else about that?",
   "How do you remember it — one moment, a stretch of days, something else?"
3. *Sensory / contextual reinstatement* [R-C §3, cognitive interview — C adopted 2026-09-21,
   reconciled with Kimi K3/K4]: for a referent the user mentioned, the open form — "When you
   think of that place, what comes to mind first?", "You mentioned the noise — is there
   anything else you remember of it?" For channels the user has *not* mentioned, only the
   cognitive-interview **report-everything** form, several channels at once, never a
   single-channel wh-question: "Anything about the place itself — the light, the sounds, the
   weather, what you were wearing? However small." Sensory anchors are the most potent cue in
   the literature and are what breaks an overgeneral memory; the form is what keeps them from
   presupposing.
4. *People cues* only on the person page, and only for a person the user named unprompted:
   "How would you describe [name]?", "Is there anything about how [name] talked that stays with
   you?"
5. *Sequence cues*, phrased without a presupposed continuation: "Does this connect to anything
   else you've thought about since?"

The deck for each cue level is authored copy, and **every question the app ever shows is a
deck template** — with the model path, the templates' slots are filled by verified transcript
spans (§6.2); without it, the same templates run slot-less or with user-typed entities. (Sol S1,
2026-09-21: the first draft let the model write follow-up questions and ranked them into these
levels; that path is gone.) De-duplication is by template id and slot span, which is exact, so
no text similarity is needed.

**Ordering rule** (sharpened per Kimi; amended per report C; Sol may still object):

- **Broad before narrow, always** (C §2, retrieval-induced forgetting: drilling one aspect
  suppresses the unpracticed rest of the period). The first follow-up after *any* capture is
  the open one — "Anything else at all, however small?" — before any cue below; and the engine
  rotates across referents within a period rather than returning to the same one.
- A cue at level N+1 is offered only after at least one **user-initiated** detail exists at
  level N: period cues once the user named a period, event cues once they described an event,
  people cues only for someone they named. Sensory cues follow item 3 above: open form for
  mentioned referents, report-everything form otherwise.
- Within a level, prefer the cue that matches a channel or referent the user already used over
  an unmentioned one.
- Never more than two questions in a row on the same **channel** (not merely the same level).
- A question answered "I don't remember" or skipped twice is retired **and logged as a
  negative** for that episode: no paraphrase of it is offered again. Because token overlap will
  not catch paraphrases, the negative is stored as (episode, cue level, referent), and any new
  question on that triple is suppressed.
- Person questions are asked only from the person page, and only while that person has fewer
  confirmed details than the episodes that mention them, so people are not drilled while
  episodes starve.

**Nudges** (spaced *re-exposure*, renamed per C §2: retrieval and re-reading do the same for
retention in autobiographical memory, and no spaced-schedule evidence exists for healthy young
adults — the cadence is a UX choice and the copy claims nothing for it). At most one
notification per day (user-set: daily, three times a week, weekly, off). The candidate set is
all open questions **plus every capture as a Revisit** (listen again). The pick is weighted by
*period thinness* first (few captures, few details), then *staleness* (days since the period was
last visited), then *period age* (older first, in the user's age terms — demoted from the first
draft per C §1: the last decade is the richest material for a user in their twenties, not the
poorest), with a hard rule that the same period is not offered two nudges running. A nudge is
one question or one Revisit, in the notification body, with the recording view (or the player)
as the tap target. When the tap target is a question, the recording view shows one line before
the red light — "Take a second. Where were you, what time of year, who was around — then talk."
— the cognitive-interview reinstatement step (C §3), kept **off** the Action-button path, where
the memory has already surfaced and any step would lose it. No schedule is "adaptive to
performance" because there is no performance (§5.2).

**Leading-question lint** (deterministic, applied to the authored deck at CI time, and to
slot-filled output in tests as a belt-and-braces check — no model output reaches it any more).
Reject a question that contains any of:

- a proper noun not in the transcript or the confirmed facts; any numeral;
- an emotion or state word applied to the user **or to anyone else** ("when you were scared",
  "when Dan was annoyed");
- an ordinal or quantifier that presupposes a sequence or a norm: *the next, the first time,
  most days, always, again, finally, continue, still*;
- a bare definite description not in the confirmed facts (*the argument, the drive home*), not
  only the adjective form (*the red …*);
- an intensifier that implies a salient target exists (*remember most, still hear*);
- an alternative or tag form that supplies the answer space ("Did it end badly, or just fade?");
- a wh-question on a channel the user has not mentioned (*what were you wearing, what did it
  smell like*) — allowed only when the channel appears in the episode's transcript.

Kimi named the classes the first draft missed (pragmatic presupposition with clean vocabulary,
wh-category presupposition, frame verbs, bare definites, other-directed emotion, alternative
questions); all are in the list above. The lint is a test fixture first: the authored deck must
pass it in CI before any of it ships.

## 8. The no-model mode

Selected when `availability` is anything but `.available`, when a call throws
*any* model error for a capture (refusal, assets not ready, unsupported locale, decoding,
context exceeded, rate limit, timeout, cancellation — Sol S7), or when the user turns
"Suggestions" off in settings (they can).

- **Recorder identical; transcript by an explicit fallback chain** (Sol S5, High; [R-D §2] to
  confirm): `SpeechTranscriber.isAvailable` + locale + asset checks → else try
  `DictationTranscriber` (the documented older-device fallback, on-device dictation locales
  only) → else audio plus a typed one-line note. Nothing is automatic; each step is a checked
  branch with its own copy.
- **Manual filing screen** = the confirm screen with empty fields: title (typed), period
  (picker), when (the same year/age wheel with "not sure"), people and places (typed chips
  with autocomplete from existing entities).
- **Static prompt deck**: authored questions per cue level (§7) and per default period.
  Default periods seeded on first run, editable, in age order: *Early childhood · Primary
  school · Middle school / junior high · High school · The years after school · Twenties*, plus
  "Add your own" (a relationship, a job, a town). Beside the periods, optional **theme cards**
  (C §3, adopted: Guided Autobiography's themes — turning points, family origins, work, health
  and the body, love and relationships) as a second way in for a user who does not think in
  periods. Deck size target: 20 questions per period × 5 cue levels, plus ~10 per theme,
  authored, plain, open. Report C found **no validated, licensable prompt set** beyond GAB's
  *themes* (GAB is a published method, not public domain: themes are usable, text is not), so
  the deck is written here, must pass the §7 lint in CI, and gets a Kimi readability pass.
  Emotion words are never cues (C §1: they produce overgeneral memories; Kimi's lint bans them
  for the presupposition reason — both reasons are on file).
- **Nudges** work identically; the candidate set is the deck's unanswered questions.
- Copy for each unavailable reason, switched with `@unknown default` (Sol S7): *deviceNotEligible*
  → "Suggestions need a newer iPhone; everything else works"; *appleIntelligenceNotEnabled* →
  "Turn on Apple Intelligence in Settings to get suggested questions" (there is **no** public
  deep link to that pane — `openSettingsURLString` opens only this app's settings, so the copy
  gives the path in words); *modelNotReady* → "Suggestions will appear once your phone finishes
  downloading them"; unknown → the deviceNotEligible copy.

## 9. App Review and the wellness-copy boundary

- **Usage strings**: `NSMicrophoneUsageDescription` ("Records your memories in your own voice.
  Recordings stay on this iPhone."); `NSSpeechRecognitionUsageDescription` if required [R-D §2]
  ("Turns your recording into text on this iPhone."). `PrivacyInfo.xcprivacy` declares no
  tracking and no data collection; the privacy policy is verified against the code before every
  release (Wilderness DECISIONS 2026-08-04) and says, truthfully, that the app has no server.
- **Apple Intelligence gating** [R-D §6]: the app never hard-requires it. Listing wording is
  taken from report D; the fallback wording is "Suggested questions use Apple Intelligence on
  supported iPhones; recording, filing and browsing work on every iPhone running iOS 26."
- **Wellness boundary** [R-C §4]: the pitch is *remember more, reflect more*. Permitted
  register (pending the report): reflection, keeping memories, a habit of looking back.
  Forbidden register (§5.2 lint): anything that measures, screens, trains, treats, or names a
  condition. No "brain", no "sharpen", no "exercise" in listing copy even though the concept
  uses the word internally — the copy is written *to* the boundary, not near it.
- **Guideline 1.4 / 5.1**: recordings are the user's own voice about their own life; no
  consent card is needed for self-recording, but the export includes a note that recordings
  may name other people. Contacts and Calendar are not requested in v1 [R-D §4].
- **Pricing** (C §6, adopted as the model of record; price is Perry's): **free up to a capture
  count, then a one-time unlock** — no subscription, because there is no server to pay for and
  the competitors' $9–15/month is the cost of their cloud model. Two constraints the report did
  not state: the free tier is capped by **capture count only**, and **export and the no-model
  mode are never gated** — lock-in is the betrayal the app exists to avoid, and Rule 3 is a
  rule, not a tier.

## 10. Lanes

**Gemini Deep Research** (dispatched 2026-09-21 by this session via the `gemini-deep-research`
skill; the concept assumed Perry would run them — the StoryCue precedent on 09-18 is that a
laptop session runs them):

- `research-prompts/deep-research-memory-recall-science.md` → `…-science-REPORT.md` (prompt C)
  — **in, adjudicated 2026-09-21.**
- `research-prompts/deep-research-memory-recall-apple-stack.md` → `…-apple-stack-REPORT.md`
  (prompt D) — first run stalled; solo re-run dispatched 2026-09-21. **Adjudicate on arrival.**
- Adjudication: `research-prompts/MEMORY-RECALL-SYNTHESIS-2026-09-21.md`, per finding adopt /
  decline / unknown with reasons, plus what the reports could not settle. Accepted findings
  are folded into this plan with "(C, adopted)" notes; D's go in the same file and the same way.

| Lane | Task | Prompt |
|---|---|---|
| **Sol** (`pal clink cli_name=codex role=codereviewer`) | Review THIS plan before code exists. Substantive tier → Sol required. **Run 2026-09-21; adjudicated in `HIPPO-PLAN-REVIEWS-2026-09-21.md` §2; second round when code exists** | "Review HIPPO-PLAN-2026-09-21.md as a senior iOS engineer who has shipped with the Foundation Models framework and SpeechAnalyzer. Will the @Generable schema in §6.2 fit the on-device context window with a 10-minute transcript, and if not what is the right chunking — critique §6.3? Where can a generated title or question still implant a detail despite §5.1, and what mechanism prevents it? What is the fastest Action-button-to-recording path and its trap — plain openAppWhenRun vs AudioRecordingIntent + Live Activity vs a Control? Cite APIs by name." |
| **Kimi** (`pal clink cli_name=kimi`) | Review the question engine (§7) — Routine tier | "Here is a follow-up-question engine for autobiographical memories (period → event → detail; sensory and people cues). List the ways its questions could lead the witness, rewrite the five worst as open questions, and propose the ordering rule." |
| **Sol** | Every diff touching Rule 1: the validator, the confirm flow, the model session, the transcript store | "Code review, iOS 26, SwiftUI + SwiftData + FoundationModels. Focus: any path by which a model-returned string is persisted without passing the span verifier; transcript immutability; two-slot templates juxtaposing quotes from different segments." |
| **Kimi** | Deck copy readability and open-question lint; state machine transitions of capture × lock × interruption × transcription | — |
| `glm-4-flash` / `gemini-2.5-flash` | Routine: unit-test scaffolds, fixture transcripts (synthetic, never real memories) | — |

Pairing rule holds: Kimi audits Claude-authored text; Sol audits Kimi-authored diffs. No
transcript or memory text, even a sample, goes to any cloud model for testing — fixtures are
synthetic and written for the purpose.

## 11. Operator acts — only Perry can do these

1. **Say build**, after the synthesis and Sol's review exist. Nothing below happens before.
2. **Name: "Retold"** (Perry, 2026-09-21). **"Hippo" stays a codename** — report C §6 found
   "Talking Baby Hippo" (Out Fit 7 Limited, USPTO application 85189137) in the software/app
   class. The report's alternatives (*Echoes, Epoch, Vivid, Loom, Ember*) were not offered:
   all common words, two of them established tech brands. Screen run 2026-09-21 before the
   pick: App Store bare-name search on 14 candidates — 10 already taken, three of those in the
   journaling/memory class (Retell, Yore, BackThen); "Recall" excluded for Microsoft's Windows
   Recall and a live "Recall: AI Journal" app. Finalists offered: Retold, Whenabouts,
   Erstwhile, Yesteryear. **USPTO (tmsearch.uspto.gov, same day) on "retold":** 11 records; no
   bare RETOLD in class 009/042. Live: RETOLD (88263648, Retold Recycling Inc., IC 035/040,
   recycling bags — unrelated), RETOLD TALES (74376648, IC 016 books), and "11-11: MEMORIES
   RETOLD" (79244499, Bandai Namco, IC 009/016/025/028/038/041 — a video-game title, composite
   mark). Eight others dead. App Store: only "Fairytales Retold" (a children's storybook)
   shares the word. **This is a screen, not clearance**; identifiers `dev.pmartin1915.retold`
   / `pmartin1915/retold` are created only when Perry says build (item 1).
3. **Repo** `pmartin1915/<name>` (private); the session seeds it with a script modelled on
   `scripts/bootstrap-storycue.ps1` and adds the registry row only when the folder exists on
   disk (PORTFOLIO.md rule, 2026-08-26).
4. **Apple Developer Portal**: App ID, App Store provisioning profile, ASC record; GitHub secrets
   copied from StoryCue/Shortless.
5. **Privacy policy page** on martinapps.dev before TestFlight external testing.
6. Later: the sync decision (changes the policy); the photos-import decision.

Nothing in the registry or `config/deadlines.json` is edited by this plan.

## 12. Timeline — starts after StoryCue's launch (2026-10-23)

Six weeks, Claude sessions on the code, Kimi on bulk copy and scaffolds via `/orchestrate`,
Perry on §11. Dates assume "build" is said by 10-26; slide everything if not.

| Week | Dates | Deliverable | Gate |
|---|---|---|---|
| 0 | 10-27 → 11-02 | Name final, repo seeded from the StoryCue skeleton, App ID + profile + secrets, CI green on an empty XcodeGen app | Green `build.yml` on `macos-27` |
| 1 | 11-03 → 11-09 | Recorder + live transcript (`SpeechAnalyzer`), save-first file writing, file-input re-transcription on relaunch, Action button intent + Control, lock/interruption handling | TestFlight on the 16 Pro: launch-to-red-light measured in all four states (terminated/unlocked, terminated/locked, warm/locked, after interruption) and recorded in the handoff; a lock mid-capture loses nothing, including transcript segments (sidecar journal) |
| 2 | 11-10 → 11-16 | Data model (§6.1), **no-model mode complete** (manual filing, static deck, Timeline/People/Places, export) | Sol review of the store + export; the app is shippable with no model |
| 3 | 11-17 → 11-23 | Foundation Models filing: `WindowExtract` schema, measured windowing, span verifier + template assembly with implant fixtures, confirm flow | Sol review of the Rule-1 diff; verifier and template tests green; every model-error case exercised into the no-model path |
| 4 | 11-24 → 11-30 | Question engine + nudges (notifications), leading-question lint, Kimi pass on deck copy | Kimi review folded; copy lint in CI |
| 5 | 12-01 → 12-07 | Metadata, privacy policy live, copy written to the wellness boundary, TestFlight dogfood week on Perry's phone | A week of real captures with zero implant reports from Perry |
| 6 | 12-08 → 12-14 | Fix from dogfood; submit | "Waiting for Review" before the holiday freeze |

The week-3 gate is the one that can slip on platform facts (context window, guardrails); if it
does, week 2's deliverable ships as 1.0 and the model path is 1.1 — the same shape as StoryCue's
pivot rule, decided now so it is not decided in a panic.

## Sources (as of 2026-09-21)

- `MEMORY-APP-CONCEPT-2026-09-21.md`; `HANDOFF-2026-09-21-hippo-kickoff.md`; `IPHONE-DUO-PLAN-2026-09-18.md`
- The developer's standing wellness-claims decision (adopted 2026-09-06) and the Wilderness FDA-posture memo (both private)
- Apple, WWDC 2025: *Meet the Foundation Models framework* (`SystemLanguageModel`, `LanguageModelSession`, `@Generable`, `@Guide`, availability cases); *Explore prompt design & safety for on-device foundation models* (context limit, guardrails); *Bring advanced speech-to-text to your app with SpeechAnalyzer* (`SpeechTranscriber`, `AssetInventory`, file and stream input, volatile results, audio time ranges). Session recollection; **report D confirms or corrects each.**
- Apple, WWDC 2024: *Extend your app's controls across the system* (ControlWidget, intents from Lock Screen; `AudioRecordingIntent` recollection to be confirmed)
- Apple developer documentation: App Intents (`supportedModes`, `OpenIntent`, `AudioRecordingIntent`, `AppShortcutsProvider`; `openAppWhenRun` deprecated in iOS 26 per Sol), Data Protection (`FileProtectionType`), `UIBackgroundModes`; Sol's cited pages are listed in `HIPPO-PLAN-REVIEWS-2026-09-21.md` §2
- Conway & Pleydell-Pearce (2000), *The construction of autobiographical memories in the self-memory system*, Psychological Review — the hierarchy; confirmed by report C.
- `research-prompts/deep-research-memory-recall-science-REPORT.md` (Gemini Deep Research, 2026-09-21) as adjudicated in `research-prompts/MEMORY-RECALL-SYNTHESIS-2026-09-21.md`: implantation meta-analysis (PMC10126919), testing effect in autobiographical memory (PMC5976790; Frontiers 2018), retrieval-induced forgetting (*Memory*, 2026), Frattaroli 2006, FDA General Wellness guidance, USPTO 85189137.
- `HIPPO-PLAN-REVIEWS-2026-09-21.md` — Kimi's question-engine review, adjudicated.
