# Handoff 2026-10-03 -- Retold: R4 merged, R2 audit decided, R4.5 next

<!-- READ-FIRST:START -->
**State:** R4 (question engine, outcomes, nudges) is merged as PR #5, squash `6fc9a28`. CI was green on the first run: 164 tests, 0 failures. Sol's Rule-1 audit of R2 is done. Sol said "broken", but Sonnet's independent pass and the boss both found it holds on current paths, and Perry decided **holds** (docs/reviews/R2-SOL-AUDIT-2026-10-03.md). main = origin = `df485ff`.
**Next:** 1. R4.5 Rule-1 sealing, code only, no schema change. Spec first, in the style of docs/R4-ENGINE-SPEC.md. It covers two things: (a) questions are built only from audited deck template ids, with the raw `Question` construction path hidden; (b) an opaque `CompletedTranscript` binds the capture id to its final segments, for `FilingPipeline` and `Episode.setExcerpt`. 2. Then R5: `DeckFilingModel`, export, `period.slot`/theme cards.
**Waiting on Perry:** operator acts before R6 (App ID, profile, ASC record, GitHub secrets).
**In flight:** nothing. No open PRs. Remote branches are main plus stale `r1-impl` (not this session's; local worktree .orchestrate/wt/r1).
**Traps:**
- Run `gh pr list` and ListAgents first.
- Finding 1 (`VerifiedSpan` is decodable, so a span can be forged) is NOT in R4.5. Fixing it needs a schema change, which needs the V1 freeze first (ai/IDEAS.md). It is R7 work.
- After a Claude Code memory-reaper kill, an orphaned `kimi.exe` can keep writing to the worktree. Check `Get-Process kimi*` (logged in ~/.claude/PAPERCUTS.md).
- The R4 Sonnet code review was partial: it stopped at its turn limit and did not read the test bodies.
<!-- READ-FIRST:END -->

## Detail

### R4
- Spec: `docs/R4-ENGINE-SPEC.md` (`d19db65`), amended in `07bc4cf` with the corrected-span drop. The rules were prototyped in Python first; the scripts are in the session scratchpad, not the repo. The Sonnet spec review hand-traced scenario A, scenario C and the 30-day nudge rotation, and all three match. 15 fixes were folded in, the biggest being a loop in which answering `broad.open` re-armed it.
- Build: Kimi via `/orchestrate`. The run was killed by Claude Code's low-memory reaper, but `kimi.exe` kept running orphaned and wrote the remaining test files. Perry said "finish it yourself", so the boss stopped the orphan and fixed the rest:
  - a compile blocker: tuple sorts on `Bool`;
  - the scenario C test loop, which never retired a question on its second skip;
  - a missing `cue:` label;
  - a nudge tie-break fixture in which the third period outscored the two tied ones.
  The boss also added the corrected-span drop and its test, and moved the stale-span and person filters ahead of dedupe.
- Mutation coverage was checked by inspection, not executed. Each of the 18 Done-when items maps to a named test.
- Design calls left PLAN-literal, both logged in `ai/IDEAS.md`:
  - slotless negatives share one (cue, "") triple, so one "I don't remember" quiets that level's other slotless cues;
  - R2's `followUps` files every referent as `referent.open`, so `sensory.mentioned` only fires for unfiled spans.
- R4 deliberately never offers `period.slot`, `theme.*` or `when.*` (R5 and the confirm flow own those).

### R2 Sol audit
- Sol's raw findings summary: scratchpad `sol-r2-findings.md` (not in repo). The adjudication table and the decision are in `docs/reviews/R2-SOL-AUDIT-2026-10-03.md`.
- Deferred items appended to `ai/IDEAS.md`: findings 1, 2 and 4 hardening (2 and 4 are now pulled forward into R4.5), finding 3's punctuation fidelity, finding 5's R7 half (retire persisted questions on correction), and finding 7 (the dormant two-slot check).

### Process notes
- The R4.5 spec touches Rule 1, so a decorrelated review is warranted. The routing table allows Sol for Rule-1 work, but Sol's quota is tight. A fresh-context Sonnet pass is acceptable for the spec; consider Sol for the diff.
- Kimi's review mode can't read repo files, so skip `kimi-exec --review` on a slim wrapper spec.
