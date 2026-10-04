# IDEAS -- retold (append-only; not @-imported)

One line each: idea, why deferred, where it applies. Sweep at session start.
- 2026-09-22 (Sol R1 audit, deferred to R2): make `VerifiedSpan` unforgeable -- its initializer reachable only through the R2 span verifier -- and derive `Episode.excerpt` from a completed `Capture` rather than arbitrary segments. Rule 1 depends on "verified" meaning verified.
- 2026-09-22 (Sol R1 audit, deferred to R7): put the model pipeline (`FoundationFilingModel`) in a module that cannot see the persistence constructors (`Person(name:)`, `Place(name:)`, relationship setters), so only the confirm flow can write user-owned facts.
- 2026-09-22 (Sol R1 audit, deferred): confirm on the first CI run whether SwiftData's composite storage calls `Confirmable.init(from:)` on reopen; if not, decide whether to persist validated opaque `Data` instead.
- 2026-09-22 (Sol R1 audit, deferred to the first schema change): freeze V1 by copying its models into the `RetoldSchemaV1` namespace before defining V2 (Apple's migration pattern).
- 2026-10-03 research report WW-0101: Retold Apple-stack platform facts (prompt D) -> docs/research/2026-10-03-retold-apple-stack-platform-facts-prompt-d.md (adopted)
- 2026-10-02 (prompt D §5, deferred to R5): consider a Day One-compatible JSON export beside PLAN §2's folder export, so users can move to/from the incumbent; not v1-critical, R5 owns export.
- 2026-10-03 (R4 spec review): R2's `followUps` files every referent as `referent.open`, so R4's `sensory.mentioned` only fires for unfiled spans; consider filing `.sensory`-kind referents as `sensory.mentioned` at R7 when the confirm flow is built. Deferred: R2 behaviour change, not R4 scope.
- 2026-10-03 (R4 spec review, Sonnet item 12): slotless negatives share one (cue, "") triple, so one "I don't remember" on event.else quiets event.shape/event.anyone too. PLAN-literal; keying slotless negatives by template id is gentler. Perry's call; revisit after device use (R7).
- 2026-10-03 (Sol R2 audit, findings 1/2/4, deferred to R7): stop `VerifiedSpan` being forgeable through Codable decoding (persist a span reference and re-verify it against the completed capture), seal the `QuestionTemplate`/`AssembledQuestion`/`Question.init` constructors behind the deck, and bind capture id plus final segments in an opaque `CompletedTranscript` used for filing and the excerpt. See docs/reviews/R2-SOL-AUDIT-2026-10-03.md.
- 2026-10-03 (Sol R2 audit, finding 3, deferred): `SpanVerifier` stores transcript words joined by single spaces with edge punctuation trimmed, so "Dan?" becomes "Dan" and the uncertainty is lost. Keep the exact transcript substring by index range instead.
- 2026-10-03 (Sol R2 audit, finding 5, R7 half): retire the persisted questions, titles and details sourced from a segment when the user corrects it. R4 only stops offering them.
- 2026-10-03 (Sol R2 audit, finding 7, dormant): the two-slot check should require the same capture id and segment, not just timestamps. Fix it before the first two-slot template.
- 2026-10-03 (R4.5, sealed): `.user`-origin questions have no production constructor. Add `Question.init(typedByUser:)` when a PLAN feature needs one; decide its `templateID` then. Do not invent one now.
- 2026-10-03 (R4.5, sealed): the excerpt has no stored link to its capture; `setExcerpt` checks membership at write time only. Storing the source capture id is a schema change, so it belongs at the V1 freeze.
- 2026-10-04 (R5): per-default-period deck copy (PLAN §8, 20 questions × 5 cue levels per period) needs a stable key per seeded period, since `Period.title` is editable. A stored field: add it at the V1 freeze; author the copy with a lint run and Kimi readability pass.
- 2026-10-04 (R5): typed-entity fills for people templates (a person typed in manual filing). R5 seals only `PeriodTitleFill`; add a sibling fill when the no-model person page is built (R7).
- 2026-10-04 (R5): a persisted `period.slot` question keeps the title it was built with; offers and the export re-assemble from the current title. R7's views must show `EngineOffer.question.text`.
- 2026-10-04 (R5 spec review, copy nit): seeded titles read oddly mid-sentence in the opener ("When you think of The years after school, ..."). Lowercase a leading article at fill time, or reword the seeds; a copy decision, not R5.
- 2026-10-04 (R5): theme questions have no period; `NudgePicker` has only `.period`/`.unfiled` keys. R7's nudge adapter decides where they go (a `.theme` key, or exclusion).
- 2026-10-04 (R5): zip the export folder for the share sheet (R7, with the UI).
- 2026-10-04 (R6): the audio-only route needs a typed one-line note (PLAN §8). It is a stored field, so it waits for the V1 freeze; R7 builds the UI.
- 2026-10-04 (R6): store `CaptureEndReason` on `Capture` at the V1 freeze, plus a "recovered" marker for adopted orphans, so the library can say "recovered after a crash".
- 2026-10-04 (R6): set a maximum capture length, or a "still recording?" check, for a capture forgotten in a pocket after an accidental Action press. This is a product decision for Perry; StoryCue caps at 10 minutes.
- 2026-10-04 (R6): let a second Action press stop a recording. R6 ignores it.
- 2026-10-04 (R6): a Live Activity for lock-screen recording status and Stop (PLAN §1 calls it optional).
- 2026-10-04 (R6): a corrected capture is never re-transcribed from the file. R7 decides whether to offer the file pass and drop the corrections.
