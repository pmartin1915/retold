# R2 spec — span verifier, windowed merge, template assembly

_Written 2026-09-30. Step R2 of `../storycue/docs/STRATEGY-2026-09-22.md` ("Retold — CI-provable
logic first"). Governing design: `docs/PLAN.md` §5.1 (Rule 1), §6.2 (the extract and the
assembly), §6.3 (windowing), §8 (no-model fallback). Same contract as R1: every type, file and
test name is fixed here. R1's Sol audit deferred two things to this step; both are in scope and
listed under "Carried from R1"._

## Scope

**In:** `Retold/Filing/` (five files), the move of `VerifiedSpan` into the verifier's file, and five
test files. Pure Swift, no `FoundationModels` import, no view, no `RetoldApp.swift`, `project.yml`
or `.github/` change. The real model sits behind `FilingModel`; only the mock exists here.

**Out:** the full audited question deck and the leading-question lint (R3), question ordering across
captures and nudges (R4), `DeckFilingModel` and export (R5), the `FoundationModels` implementation
and the confirm flow (device-gated, after 10-16), word-level audio times (R6: spans carry
**segment** ranges, which is what the transcript provides).

## 1. Carried from R1

1. **`VerifiedSpan` is unforgeable.** Its designated initializer is `fileprivate` and the struct
   lives in `SpanVerifier.swift` beside the only production producer. A `#if DEBUG`
   `VerifiedSpan.fixture(text:captureID:start:end:)` replaces direct construction in tests, so a
   Release build has no path to a span except `SpanVerifier.verify` (and decoding a stored one).
   The three R1 test files switch from `VerifiedSpan(` to `VerifiedSpan.fixture(`; nothing else in
   them changes. Within one module this is a convention the compiler enforces per file; the
   module split in `ai/IDEAS.md` (R7) is what makes it a boundary.
2. `Episode.excerpt` already has one writer (`setExcerpt(from:)`). Deriving it only from a
   **complete** capture is the confirm flow's rule, not a model-layer one; left in `ai/IDEAS.md`.

## 2. `SpanVerifier` — `Retold/Filing/SpanVerifier.swift`

`verify(_ candidate: String, in window: TranscriptWindow) -> VerifiedSpan?`

- **Match:** whole words, contiguous, in order. A word's comparison key is lowercased, curly
  apostrophes straightened, edge punctuation/symbols removed (inner punctuation kept: `didn't`).
  Words whose key is empty (a lone dash) are skipped on both sides. `lake` does not match
  `lakeview`; `Dan` does not match `Danny`.
- **Returned text is the transcript's, not the candidate's:** the original words from the first to
  the last matched word, whitespace-normalised, edge punctuation trimmed. So a span is always a
  contiguous piece of what was spoken, whatever the model typed.
- **Non-final segments are a wall.** A span lies inside one run of consecutive `isFinal` segments
  and may cross a boundary between two final segments.
- **Range:** earliest `start` and latest `end` of the segments the span covers.
- **First occurrence wins.** No match, or an empty candidate, is `nil`: dropped, never rephrased.
- `key(_:)` and `phraseKey(_:)` are internal and shared with the merger (one normaliser).

## 3. Model seam — `Retold/Filing/FilingModel.swift`

`WindowExtract` (the plain-Swift shape of PLAN §6.2's `@Generable` struct: `periodName`, `people`,
`places`, `timeCues`, `referents: [RawReferent]`, `titleSpan`), `ReferentKind`, `FilingModelError`
(every case PLAN §8 lists plus `other`), `protocol FilingModel: Sendable` with
`extract(from:periodTitles:) async throws -> WindowExtract`, and `MockFilingModel` (a `@Sendable`
async closure). Every string in a `WindowExtract` is a claim; nothing trusts it.

## 4. Windowing — `Retold/Filing/WindowChunker.swift`

`TokenCounter` protocol (the device implementation reads the SDK's measured count, PLAN §6.3
item 1) and `WordTokenCounter` (tests). `WindowChunker.windows(captureID:segments:maxTokens:
overlapTokens:counter:)`: greedy windows at segment boundaries; a single segment over budget gets
its own window; the next window starts in the previous one's tail within `overlapTokens`, and only
if tail plus the next segment still fits, so every window reaches a segment the last one had not
seen. Always terminates, always covers every segment, empty input gives no windows.

## 5. Merge — `Retold/Filing/ExtractMerger.swift`

`ExtractMerger.merge(_ results:[(window:, extract:)], periodTitles:) -> MergedExtract`. Each string is
verified against **its own window** first. Then: de-duplicate by normalised text per kind (this
also collapses one quotation seen in two overlapping windows); order by audio start; the period is
the user's own title (spelled as in their list) named by most windows, earliest window breaking
ties, and a name not in the list counts for nothing; the title span is the first verified one of
at most 8 words. **No second model call.** `MergedExtract` holds only verified spans and one period
title.

## 6. Assembly — `Retold/Filing/TemplateAssembler.swift`

`QuestionTemplate` (`id`, `cue`, `pattern` with `{slot}` markers), `FilingTemplates` (the six
patterns of PLAN §6.2: `when`, `whenWithCue`, `who`, `sensoryPlace`, `referent`, `broad`; the full
deck is R3), `TemplateAssembler.assemble(_:slots:segments:) throws -> AssembledQuestion`:

- slot count must equal the pattern's; **never more than two**; two slots only when both spans lie
  inside one transcript segment (PLAN §5.1 tail), else `slotsFromDifferentSegments`.
- spans are interleaved with the pattern's literal pieces, so span text is never re-scanned for
  markers.
- `AssembledQuestion.question()` builds the persisted `Question` with `.deck` origin.

`followUps(from:maxFollowUps: 5)`: `broad` first (broad before narrow), then `when` (`whenWithCue`
if a time cue verified), then up to five more rotating referent → place → person.

## 7. Pipeline — `Retold/Filing/FilingPipeline.swift`

`FilingPipeline(model:counter:maxWindowTokens: 1_600, overlapTokens: 200).file(captureID:segments:
periodTitles:) async -> FilingOutcome`. One fresh model call per window; **any** error in any window
returns `.noModel(error)` for the whole capture (a half-filed capture looks complete);
`CancellationError` → `.cancelled`, anything else → `.other`; empty transcript → `.noModel(.other)`
with no call. Success is `.proposal(MergedExtract, [AssembledQuestion])`. Nothing is persisted.

## 8. Tests — `RetoldTests/`

| File | Asserts |
|---|---|
| `SpanVerifierTests` (10) | exact match with transcript text and range; case/edge-punctuation insensitive but transcript spelling returned; result always a contiguous transcript piece; reordered/skipped/invented words rejected; partial words rejected; empty and punctuation-only rejected; crosses two final segments; never crosses a non-final one; first occurrence; `phraseKey` |
| `WindowChunkerTests` (6) | empty; one window; coverage and budget; overlap within budget and always advancing; oversize segment terminates; zero overlap partitions |
| `ExtractMergerTests` (6) | unverifiable strings dropped with no trace; overlap duplicates collapse; audio-start order; period must be in the list, returned as spelled; majority/earliest tie-break; title ≤ 8 words, first verified |
| `TemplateAssemblerTests` (8) | slot counts; verbatim fill; wrong count throws; two-slot same-segment rule; three slots never; follow-up order and rotation; slotless outcome; `.deck` origin |
| `FilingPipelineTests` (8) | **implant fixture**: a model returning invented names, a year, an emotion and a paraphrase leaves none of it in spans, questions or title, and every span and question slot is a contiguous transcript piece; fresh call per window seeing only its segments; period titles reach every call; every `FilingModelError` → `.noModel`; a later-window failure discards earlier results; unknown and cancellation mapped; empty transcript makes no call |

Fixtures are synthetic text written for the tests. No real memory text goes anywhere.

## Do not

No `FoundationModels`; no `try!`, `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`; no
`!` outside tests; no AI attribution.

## Done when

PR CI green (Build & XCTest + Release compile): the 38 new tests plus R1's 33 pass; the greps
above are empty; Sol's Rule-1 audit of the diff adjudicated, or, if Sol is out of quota, a
fresh-context reviewer pass recorded as such. State `ai/STATE.md` names R3 next.
