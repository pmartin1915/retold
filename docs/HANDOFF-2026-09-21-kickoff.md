# Kickoff handoff 2026-09-21 — "Hippo" (voice-first memory-recall app)

**Paste this into the new instance (laptop, dev-ops open):**

> Read `dev-ops/HANDOFF-2026-09-21-hippo-kickoff.md` on branch
> `claude/ios-duo-app-ideas-te3edu` (`git fetch origin` first), then
> `MEMORY-APP-CONCEPT-2026-09-21.md` and the two prompts
> `research-prompts/deep-research-memory-recall-{science,apple-stack}.md`. This is a
> research-and-plan session, not a build session. Claim the session, then do the "This
> session" list. Sol reviews the plan; Kimi reviews the question engine.

## What this is, and what phase it is in

Press the Action button when a memory surfaces, talk about it in any order, and the app
files it — life period, age or year *as a question*, place, people, a paraphrase — then
asks the follow-up questions that pull out the rest of that period, and nudges later
toward thin, old periods. On-device only: iOS 26 `SpeechAnalyzer` for transcription, the
Foundation Models framework (`@Generable`) for filing and questions. It reuses StoryCue's
recorder, library, export and `macos-27` pipeline.

**Phase: research → plan → Sol review. No repo, no Swift, until (a) the Gemini reports for
prompts C and D are adjudicated, (b) a plan exists in the StoryCue plan's shape, (c) Sol
has reviewed it, and (d) Perry says build.** StoryCue's window (2026-10-23) is fixed; this
one is not. Build order is StoryCue first unless Perry changes it.

## Locked facts

| | |
|---|---|
| Device | **Perry carries an iPhone 16 Pro** (2026-09-21) → Apple Intelligence supported → the on-device model path is dogfoodable on his phone via TestFlight |
| Name | "Hippo" is a working name; prompt C §6 runs the conflict check. Do not create ids or a repo under it yet |
| Money | Zero marginal cost by design: no server, no cloud model, no account. A cloud tier is explicitly out of the concept |
| Rule 1 | **A memory app never authors memories.** Audio + verbatim transcript are the record; every derived field is marked derived; the paraphrase may only restate what is in the transcript; anything inferred (a year, a person's role) renders as a question the user confirms |
| Rule 2 | **Martin Apps Decision #47 applies: the app prompts, it does not assess.** No memory tests, scores, trends, or MCI/dementia language anywhere, including marketing |
| Rule 3 | A no-model mode is mandatory (manual tags, static prompt deck per period) for iPhones without Apple Intelligence |

## This session, in order

1. **Orient and claim.**
   `node scripts/session-claim.mjs write --lane hippo --repos dev-ops --intent "Hippo research + plan"`
2. **Adjudicate the research, if the reports are in.** Look for
   `research-prompts/deep-research-memory-recall-*-REPORT.md`. Write
   `research-prompts/MEMORY-RECALL-SYNTHESIS-<date>.md` in the shape of
   `LEGIBILITY-SYNTHESIS-2026-08.md`: per finding, adopt / decline / unknown, with the reason,
   and a short list of what the reports could not settle. If the reports are not in, do
   step 3 from the concept alone and mark every research-dependent claim as such.
3. **Write `HIPPO-PLAN-<date>.md`** mirroring `IPHONE-DUO-PLAN-2026-09-18.md`'s sections:
   platform constraints as a table with sources; the app (capture → file → ask → browse →
   keep); why native Swift on the StoryCue skeleton; pipeline deltas (none expected beyond
   the speech and model frameworks); the three hazards above as design rules with the
   mechanism that enforces each; the **data model** (Period → Episode → Detail, plus Person,
   Place, Capture, Question) and the **`@Generable` schema** as real Swift, with the
   confirm-before-file flow; the question engine (walk the hierarchy; sensory and people
   cues; spaced nudges preferring thin/old periods); the no-model mode; App Review and
   wellness copy boundary; lanes; a timeline that starts after StoryCue's 10-23 launch.
4. **Sol reviews the plan.** Substantive → Sol required; expect PAL to background it.
   ```
   pal clink cli_name=codex role=codereviewer
   prompt: "Review HIPPO-PLAN-<date>.md as a senior iOS engineer who has shipped with the
   Foundation Models framework and SpeechAnalyzer. Will the @Generable schema fit the
   on-device context window with a 10-minute transcript, and if not what is the right
   chunking? Where can the paraphrase step implant details despite the rule, and what
   mechanism prevents it? What is the fastest Action-button-to-recording path and its
   trap? Cite APIs by name."
   ```
5. **Kimi reviews the question engine** (Routine tier, fast):
   ```
   pal clink cli_name=kimi
   prompt: "Here is a follow-up-question engine for autobiographical memories (period ->
   event -> detail; sensory and people cues). List the ways its questions could lead the
   witness, rewrite the five worst as open questions, and propose the ordering rule."
   ```
6. **End:** synthesis and plan committed on the branch, `ai/IDEAS.md` entry updated with the
   plan's path, this file's "Next" line replaced with what is actually next, `session-claim
   release`. No repo folder yet; when Perry says build, seed it with a script modelled on
   `scripts/bootstrap-storycue.ps1` and add the registry row only then.

## Do not

- Write Swift into dev-ops, or scaffold a repo before Perry says build.
- Send any transcript or memory text to a cloud model for testing, even a sample.
- Use Apple's `JournalingSuggestions` as the core cue source (it cues about *today*); it is a
  v2 candidate, noted in the concept.
- Soften Rule 1 for convenience: a "nicer" summary that adds a detail is the failure mode.
- Reuse StoryCue's session or claim lane; the two are separate claims.

## Done 2026-09-21 (laptop, Fable session)

Steps 1–6 ran, with two deviations. (a) The session ran the Gemini Deep Research prompts
itself via the `gemini-deep-research` skill (the StoryCue precedent), not Perry: **prompt C
landed** and is adjudicated; **prompt D failed three times** (stall, generic error, stall) and
was not retried a fourth — see the synthesis §D for the conversation ids and a possible cause
(the *Personal Intelligence (Labs)* toggle was on and leaked "Birmingham, Alabama" into the
research plan; turning it off is Perry's). (b) Sol ran *before* report D, since Sol is an
independent source for the same platform facts; four of D's questions are now answered at High
confidence by Sol and D remains wanted as the second source.

Artefacts on the branch: `HIPPO-PLAN-2026-09-21.md` (the plan, rewritten twice — after report C
and after Sol), `HIPPO-PLAN-REVIEWS-2026-09-21.md` (Kimi on §7, Sol on the whole plan, both
adjudicated, nothing declined), `research-prompts/deep-research-memory-recall-science-REPORT.md`,
`research-prompts/MEMORY-RECALL-SYNTHESIS-2026-09-21.md`, and the `ai/IDEAS.md` entry.

What the day changed, in three lines: the model **extracts spans and picks a period, nothing
else** — every title and question is a Swift template filled with a verified transcript quote
(Sol's blocker: a lexical validator cannot check meaning); the value claim is **record +
re-exposure**, not rehearsal (the testing effect does not persist for autobiographical memory);
and **"Hippo" is a codename only** (Outfit7's "Talking Baby Hippo" mark).

**Next:** (1) Perry: read the plan and the two review adjudications; say build or not, after
StoryCue ships 10-23. **Name decided 2026-09-21: "Retold"** (App Store + USPTO screen in plan
§11 item 2; Echoes / Epoch / Vivid / Loom / Ember were not offered). (2) Prompt D: **decided —
a later session re-runs it solo in week 0** with the Labs toggle off (Perry flips it), and
adjudicates it into the synthesis §D. (3) When Perry says build: seed the
repo with a script modelled on `scripts/bootstrap-storycue.ps1`, add the registry row only then,
and start week 0 of plan §12. Nothing here needs a session before (1).
