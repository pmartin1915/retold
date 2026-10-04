# Handoff 2026-10-04 -- Retold: R4.5 merged, R5 spec next

<!-- READ-FIRST:START -->
**State:** R4.5 (Rule-1 sealing) is merged as PR #6, squash `ac91ff2`. CI: 168 tests, 0 failures, Release compile green. STATE was updated in `c3404c8`, and main = origin = `c3404c8`.
- `QuestionTemplate`, `AssembledQuestion`, `TranscriptWindow` and `CompletedTranscript` now have fileprivate inits in their own files.
- A production `Question` comes only from `Question(assembled:)`.
- `FilingPipeline.file(_ CompletedTranscript, periodTitles:)` and `Episode.setExcerpt(from: CompletedTranscript) -> Bool` replace the raw-segments forms.
- Test fixtures are `#if DEBUG` `.fixture(...)`.

**Next:** 1. R5 spec, in the style of docs/R4-ENGINE-SPEC.md and docs/R4.5-SEAL-SPEC.md. It covers `DeckFilingModel` plus the export manifest (PLAN §8), `period.slot` typed-entity slot fills, theme cards, and per-period deck assignment. Get a fresh-context Sonnet spec review, then build with Kimi via /orchestrate.
**Waiting on Perry:** operator acts before R6 (App ID, profile, ASC record, GitHub secrets).
**In flight:** nothing. No open PRs. Remote branches are main plus stale `r1-impl` (not this session's; local worktree .orchestrate/wt/r1).
**Traps:**
- R5 must build questions only through `TemplateAssembler.assemble` on deck templates. New `Question`s come via `.question()` / `init(assembled:)`. Never widen an access level to make something compile.
- Subagent reviewers may run `git checkout` in the MAIN checkout. Tell them not to touch git state, and check `git status -sb` after any review.
- There is no Swift toolchain locally, so CI is the compiler. Kimi's code had one compile error last time.
<!-- READ-FIRST:END -->

## Detail

### R4.5 process
- Spec `docs/R4.5-SEAL-SPEC.md` (`9c154c6`). A fresh Sonnet review raised 5 findings, all folded in (`68e343f`):
  - designated inits cannot delegate, so the bodies are duplicated;
  - the missed `SchemaRoundTripTests:92` call site;
  - `.fromFile` is an in-progress state;
  - the excerpt check is described as a guard, not a seal;
  - the new test file is non-isolated.
- A planned CI grep guard was dropped: `build.yml` already has a Release compile step, which rejects any production call to a `#if DEBUG` fixture.
- Kimi built it in `.orchestrate/wt/r45`. The first CI run failed on `contains({...})` needing a `where:` label; the fix is `5d5caea`.
- The Sonnet `reviewer` approved after reading the test bodies.
- The boss grep matched spec §5, and the moved templates and deck are byte-identical (diffed).
- Ledger run `retold-r45` is done.

### Logged to ai/IDEAS.md
- `.user`-origin questions have no production constructor.
- The excerpt has no stored link to its capture (V1 freeze).

### Still deferred
- Finding 1 (`VerifiedSpan` is decodable) is R7 and needs the V1 schema freeze.
- Findings 3, 6, 7 and 8 stay as recorded in `ai/IDEAS.md`.
