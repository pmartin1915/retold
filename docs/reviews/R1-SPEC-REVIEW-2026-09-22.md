# R1 spec review — Kimi pre-dispatch, 2026-09-22

Reviewer: Kimi (`kimi-exec.sh --review`, spec text only, no repo access). 32 findings. Raw
output was not committed (`.orchestrate/r1-spec-review.txt`, local). Sol's review was attempted
first and failed on a ChatGPT Plus usage limit; Sol audits the implementation diff instead.

| # | Finding (short) | Verdict | Action in spec |
|---|---|---|---|
| 1 | "equal field by field" undefined (Date precision, computed vs stored) | accept | Defined in §4: computed `provenance`, Dates within 1 ms, relationships by id set |
| 2 | Decoder validation vs getter precondition ambiguous | accept | Decoder does all validation; getter's precondition is unreachable by design |
| 3 | `updateTranscript` "must not be .complete" ambiguous | accept | Current-status check first; `.complete` argument throws `.useCompleteTranscript`; test added |
| 4, 19 | `whenQuestionID` integrity; no test that `whenQuestion` picks by id | accept | `whenQuestionID` private(set), `setWhenQuestion(_:)`, `testWhenQuestionPicksByID` |
| 5 | Question may belong to episode and period at once | reject | Intended: a question is about one subject but can be surfaced from several places; R4 decides |
| 6 | `Question.origin != .model` precondition untestable | accept as noted | No test for a trap; the precondition stays |
| 7 | `Period.sortOrder` contract | reject for R1 | Storage only in R1; ordering UI is later |
| 8 | `excerpt` was a free-text init parameter | accept | `excerpt` private(set); only writer `setExcerpt(from:)` (verbatim first 25 words); test added |
| 9, 18 | `makeContainer(inMemory:url:)` underspecified; who creates the dir | accept | Split into `makeInMemoryContainer()` / `makeContainer(url:)`, which creates the parent dir |
| 10, 29 | Reopening the same URL in-process is vague | accept | Helper-function scoping so the first container is released; per-test directory |
| 11 | `Person/Place.episodes` bare arrays | clarify | Deliberate: inverse declared once, on `Episode`; the round-trip test proves it |
| 12 | Per-kind `StoredProvenance` validation not stated | accept | Per-kind table added; malformed test covers `userConfirmed` too |
| 13 | Status table vs `Detail` | accept | Table scoped to `Confirmable` only |
| 14, 32 | `Detail.text` mutable, invariant only at init | accept | `text` private(set); no provenance mutator |
| 15 | Decoder validation under-tested | accept | `testDecodingConfirmedDeckProposalThrows`, `testIsValidMatchesTable` |
| 16, 22, 24, 28 | Spike failures not attributable; fallback trigger undefined | accept | Two isolating tests (flat `StoredProvenance` vs one `Confirmable<Int>`); boss decides from the CI log |
| 17 | Which workflow runs Release | accept | Named: `build.yml`, Release compile step from S0 |
| 20 | Audit gate not mechanical | accept | Forbidden-pattern grep added to Done-when |
| 21 | `isValid` private but asserted | accept | Made internal |
| 23 | Why tests are `@MainActor` | accept | One sentence added |
| 25 | `private(set)` on `@Model` may be rejected | partial | Kept (expected to compile); executor reports rather than silently drops |
| 26 | `range` can trap after decode | accept | `range` uses min/max |
| 27 | Fixture insertion direction | accept | Always from the declared owning side |
| 30 | Decode test bypasses the store | accept as intended | JSONDecoder directly is the intent; a store-level forged record isn't reachable without raw SQL |
| 31 | No schema versioning | accept | `RetoldSchemaV1: VersionedSchema` + `RetoldMigrationPlan` from day one |
