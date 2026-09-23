# IDEAS -- retold (append-only; not @-imported)

One line each: idea, why deferred, where it applies. Sweep at session start.
- 2026-09-22 (Sol R1 audit, deferred to R2): make `VerifiedSpan` unforgeable -- its initializer reachable only through the R2 span verifier -- and derive `Episode.excerpt` from a completed `Capture` rather than arbitrary segments. Rule 1 depends on "verified" meaning verified.
- 2026-09-22 (Sol R1 audit, deferred to R7): put the model pipeline (`FoundationFilingModel`) in a module that cannot see the persistence constructors (`Person(name:)`, `Place(name:)`, relationship setters), so only the confirm flow can write user-owned facts.
- 2026-09-22 (Sol R1 audit, deferred): confirm on the first CI run whether SwiftData's composite storage calls `Confirmable.init(from:)` on reopen; if not, decide whether to persist validated opaque `Data` instead.
- 2026-09-22 (Sol R1 audit, deferred to the first schema change): freeze V1 by copying its models into the `RetoldSchemaV1` namespace before defining V2 (Apple's migration pattern).
