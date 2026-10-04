# Handoff 2026-10-03 -- Retold: R3 merged, R4 next

<!-- READ-FIRST:START -->
**State:** Prompt D adjudicated against Sol (docs/research/SYNTHESIS-2026-09-21.md §D, `0939061`); PLAN unbroken. R3 (leading-question lint, wellness copy lint, 25-template seed deck, function-word slot guard) merged as PR #4 squash `40bfdfe`, CI green, 102 tests. main = origin = `8bdfad4`. A duplicate R3 PR #3 from a parallel session was closed as superseded (Perry OK'd).
**Next:** 1. R4: question engine ordering + nudge selection (PLAN §7). Spec first (pattern: docs/R3-LINT-SPEC.md), prototype rules before dispatch, then /orchestrate. It includes the transcript-aware form of the `unmentionedChannel` lint rule. 2. Sol Rule-1 audit of R2 (`608fb54`) is still owed.
**Waiting on Perry:** operator acts before R6 (App ID, profile, ASC record, GitHub secrets).
**In flight:** nothing. No open PRs. Remote branches: main, plus stale `r1-impl` (R1's old branch, already squash-merged as `0b8f376`; not deleted, not this session's).
**Traps:**
- Run `gh pr list` and ListAgents first; a parallel session built R3 unseen last time.
- R6 must settle the speech usage-string conflict (Sol: not needed; D: needed) and verify `@Guide(.maximumCount)` exists (an exact `.count` would force invented names).
- The governing order is ../storycue/docs/STRATEGY-2026-09-22.md; R6 waits until after StoryCue's 10-16 submit.
<!-- READ-FIRST:END -->

## Detail

### Prompt D adjudication (`0939061`)
- Confirms Sol: 4,096-token shared context, three unavailable reasons, `.completeUnlessOpen` sidecar,
  no silent locked start, `UIBackgroundModes: audio` + interruptions, save-audio-first.
- Conflicts: speech usage string (open until R6); `openAppWhenRun` (Sol stands; D cited a Zebra page).
- Declined: D's summarise-then-extract chunking (Sol S3 rejected it); PCC 32K and "iOS 15 minimum"
  are unverified and not relied on.
- Still open (SDK/device): `.maximumCount` spelling; `tokenCount(for:)` is iOS 27 per D, so the
  device TokenCounter needs an iOS 26 path; SpeechTranscriber on non-AI iPhones; asset size/Wi-Fi.
- Added to PLAN §8: onboarding prefetches speech assets. *memory loss* went into the copy lint.
- Day One JSON export idea is in ai/IDEAS.md for R5.

### R3 (`40bfdfe`, spec `docs/R3-LINT-SPEC.md`)
- Files: Retold/Questions/{QuestionDeck,LeadingQuestionLint,WellnessLint}.swift,
  Retold/Copy/AppCopy.swift, TemplateAssembler.swift (`FilingTemplates.all`, `slotIsFunctionWord`),
  tests LeadingQuestionLintTests, QuestionDeckTests, WellnessLintTests, +2 in TemplateAssemblerTests.
- Kimi built it; the boss fixed 2 compile errors (unlabeled `contains(where:)`, `StaticString`→URL)
  before the first CI run. The Sonnet reviewer found no blockers, and 3 test gaps were added
  (`4c02589`). Mutation coverage was checked by inspection, not by running mutants.
- The wellness file scan reads project.yml from the simulator via `#filePath`; this works on CI.
- Violation order is grouped by sentence then clause; no consumer may rely on position (spec amended).

### Side change
- combo `3fb4933`: the handoff skill now requires `gh pr list` and `git ls-remote` before writing
  "In flight: nothing". It is deployed live on this machine.
