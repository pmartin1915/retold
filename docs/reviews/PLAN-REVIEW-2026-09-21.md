# Hippo plan — external reviews and their adjudication (2026-09-21)

_Companion to `HIPPO-PLAN-2026-09-21.md`. Each review is recorded as returned, then adjudicated
finding by finding: **adopt** (folded into the plan with a dated note), **decline** (with the
reason), or **open** (needs a fact the reports or Perry must supply). Reviews of this plan are
text reviews, not code reviews; the pairing rule still holds (Kimi audits Claude-authored text;
Sol audits Kimi-authored diffs)._

## 1. Kimi — question engine (plan §7), Routine tier

Lane: `pal clink cli_name=kimi`, 2026-09-21, 63 s, on the extracted §7 text only. Prompt: list
the ways the questions could lead the witness, rewrite the five worst as open questions, propose
the ordering rule, and say what the leading-question lint misses.

### Findings, as returned (condensed)

**How the questions lead or implant.**
- Presupposed facts baked into wording: "What happened just before that?" (presupposes a prior
  event); "How did that day end?" (presupposes one day with an end); "What happened the next
  summer?" (presupposes a continuation); "What was [name] like when they were annoyed?" (double
  presupposition: the user saw it, and it was characteristic).
- Sensory reinstatement with an assumed answer: "What did the place smell like?", "What was the
  weather doing?", "What was playing?" assume the channel was attended. Cognitive-interview
  reinstatement reinstates context the witness *mentions*; demanding every channel yields a
  guess that then enters the record as confirmed.
- Concreteness pressure: "something [name] said that you can still hear" asks for a verbatim
  line; memories are rarely verbatim, so this invites plausible reconstruction.
- Emotion/state attribution and narrative completion: "How did that end?" and the sequence cues
  exploit the bias toward coherent stories; the app is asking the user to finish the plot.
- Model-generated follow-ups compound all of this: they see confirmed facts and extend them
  ("What did you do after the move?"); ranking by cue does not sanitise content, and
  token-overlap de-duplication will not catch near-paraphrase leading questions.

**Five worst, rewritten.**
1. "What was [name] like when they were annoyed?" → "How would you describe [name]?" (only after
   the user mentioned the person unprompted)
2. "What is something [name] said that you can still hear?" → "Is there anything about how
   [name] talked that stays with you?"
3. "How did that day end?" → "How do you remember that time — is it one moment, a stretch of
   days, something else?"
4. "What happened the next summer?" → "Does this connect to anything later that you've thought
   about since?"
5. "What did the place smell like?" → "When you think of that place, what comes to mind first?"

**Ordering rule.** Never offer a level N+1 cue until at least one *user-initiated* detail
exists at level N; within a level prefer the channel the user already used; cap two-in-a-row
per channel, not per level; a question answered "I don't remember" or skipped twice is retired
*and logged as a negative* so no paraphrase is re-offered; person questions fire only from the
person page and only while that page has fewer confirmed details than the episodes.

**What the lint misses.** Pragmatic presupposition with clean vocabulary; wh-category
presupposition ("what were you wearing"); intensifiers ("still hear", "remember most");
frame verbs ("continue", "again", "finally"); emotion words applied to others; ordinals and
quantifiers ("the next", "most days", "the first time"); bare definites ("the argument", "the
drive home"); alternative/tag questions that supply the answer space.

### Adjudication

| # | Finding | Disposition | Where |
|---|---|---|---|
| K1 | Example questions presuppose continuations, channels, verbatim recall | **Adopt.** All examples in §7 replaced; each now admits "nothing" as the honest answer | Plan §7, revision note |
| K2 | Five rewrites | **Adopt** all five verbatim | Plan §7 |
| K3 | Level N+1 unlocks only on a user-initiated level-N detail | **Adopt.** This is the single most important change: it makes the hierarchy walk *follow* the user rather than *pull* them | Plan §7 ordering rule |
| K4 | Prefer channels the user already used; cap per channel | **Adopt** | Plan §7 |
| K5 | Log negatives; token overlap cannot suppress paraphrases | **Adopt**, with a mechanism: the negative is stored as (episode, cue level, referent), and any new question on that triple is suppressed. That is a structural key, not a text match, so it does not need embeddings | Plan §7 |
| K6 | Person questions only from the person page, gated on the person's detail count vs the episodes' | **Adopt** in spirit; the "median" comparison is replaced by "fewer confirmed details than the episodes that mention them", which is the same intent with one fewer computed statistic | Plan §7 |
| K7 | Lint classes missed | **Adopt.** All eight classes added to the lint; the deck must pass it in CI | Plan §7 lint |
| K8 | Model follow-ups compound the problem | **Adopt** as a design consequence: model `followUps` pass the same lint as the deck, and the `@Guide` text for `followUps` already forbids mentioning anything the speaker did not; the lint is the enforcement, the guide is the hint | Plan §6.2, §7 |

Nothing declined. Open: whether the sensory-channel rule ("only channels the user mentioned")
is too strict for the *static deck* in no-model mode, where there is no transcript to gate on
for a fresh period — the deck's sensory questions are therefore phrased as the open form
("what comes to mind first") rather than the channel form. Report C §3 may show validated
prompt sets that settle the phrasing.

## 2. Sol — plan review (Substantive tier)

Lane: `pal clink cli_name=codex role=codereviewer`, 2026-09-21, 786 s (PAL backgrounded it), on
the full plan after report C was folded and before report D landed. Sol verified iOS 26 claims
against Apple documentation and labelled each platform fact High/Medium/Low.

### Findings, as returned (condensed)

- **S1 — Blocker, §§5.1, 6.1–6.2 — lexical grounding cannot prevent implantation.** The
  validator checks tokens, not meaning: a title can falsely combine spoken words; lowercase
  inventions ("What color was the car?") pass; a question can presuppose an event; and the
  fallback "Did you mention someone called …?" *repeats* the hallucinated name. Confirmation
  happens after exposure. `whenQuestion` and `Question.text` lacked provenance. **Fix:** titles
  user-authored or exact contiguous transcript spans; questions from audited neutral templates
  whose slots take only exact, range-validated spans or confirmed entities; drop failed entities
  silently.
- **S2 — Should-fix, §§6.2–6.3 — the "seven minutes" threshold is unsupported.** Context is
  4,096 tokens per session including instructions, prompt, schema and output (High). On the
  plan's own numbers 250 + 350 + 2,000 + 500 = 3,100, so a ten-minute example nominally fits;
  actual reliability is unknown because speech rate, schema cost and tokenisation vary (Medium).
  Measure with the SDK's token accounting and Instruments; fresh sessions; 1,400–1,800-token
  chunks, 150–250 overlap, ~700 output reserve, 15 % headroom; bound every array.
- **S3 — Blocker, §6.3 — merge-over-generated-extracts is unsound.** A second model call
  recombining generated phrases can produce a relation nobody spoke, and whole-transcript token
  membership cannot detect it. **Fix:** windows return typed exact spans with capture/range ids;
  merge, de-duplicate and rank deterministically in Swift; generate only safe templates after.
- **S4 — Blocker, §1 — the Action-button path still requires foregrounding.** `openAppWhenRun`
  is deprecated in iOS 26 → `supportedModes = [.foreground(.immediate)]` or `OpenIntent` (High).
  A `ControlWidgetButton` is the fastest direct surface but only invokes an intent (High;
  latency Medium). A general `AVAudioSession` cannot be activated from a cold background
  process, including while locked (High, Apple DTS). `AudioRecordingIntent` grants no mic
  exemption and needs a Live Activity for the whole recording (High). Pre-grant the mic
  permission; measure terminated/unlocked, terminated/locked, warm/locked, interruption recovery.
- **S5 — Should-fix, §§1, 4, 8 — speech fallback is explicit.** File input via
  `analyzeSequence(from:)` or `start(inputAudioFile:finishAfterFile:)` (the latter returns
  immediately and must be finished). `DictationTranscriber` is the documented older-device
  fallback, on-device dictation locales only. `SpeechAnalyzer` needs no
  `SFSpeechRecognizer.requestAuthorization`; keep the speech usage string only for
  `SFSpeechRecognizer` (High).
- **S6 — Should-fix, §§1, 6.1 — persistence contradiction.** `.complete` makes the store
  unwritable while locked, so appending transcript segments while locked contradicts the plan.
  Use an append-only `.completeUnlessOpen` sidecar journal during capture; import after unlock;
  reclassify the closed audio (High).
- **S7 — Should-fix, §§1, 4, 8 — availability and error handling.** Switch availability with
  `@unknown default`; no public deep link to the Apple Intelligence pane; handle refusal, assets,
  locale, decoding, context, rate limiting, timeout and cancellation, not just guardrails; in
  Xcode 27 the context error is `LanguageModelError.contextSizeExceeded` and `GenerationError`
  is deprecated; the Simulator can route the Mac microphone (High).
- **S8 — Note, preserve:** audio-first durability, immutable transcript plus corrections,
  confirm-before-fact, no summaries, file re-transcription, protocol mocks, the complete static
  no-model path.

### Adjudication

| # | Disposition | Where |
|---|---|---|
| S1 | **Adopt in full.** This is the review's central catch and it is right: the first draft's defence was lexical. The model is now an **extractor only** — it returns exact spans and a period pick; Swift verifies each span as a contiguous substring with an audio range, drops failures silently, and assembles every title and question from an audited template deck with one slot (two only within one segment). `Question` carries `templateID` + `slots`; `Episode.whenQuestion` is a `Question`. | Plan §5.1 items 3–7, §6.1, §6.2 (rewritten), §7 |
| S2 | **Adopt.** Arithmetic corrected; "seven minutes" withdrawn; measure at runtime; chunk parameters and array bounds as given. The API names Sol cites for token accounting are recorded as "confirm the spelling". | Plan §1 row 2, §6.3 |
| S3 | **Adopt in full.** The merge is deterministic Swift over verified spans; no model call ever sees generated output. | Plan §6.2, §6.3 |
| S4 | **Adopt.** Door = Control → foreground intent with `.foreground(.immediate)`; mic permission in onboarding; "under one second" replaced by a four-state measurement in the week-1 gate; `AudioRecordingIntent` demoted to "only if a Live Activity is wanted". | Plan §1 (three rows), §2 Capture, §12 week 1 |
| S5 | **Adopt.** Explicit chain `SpeechTranscriber` → `DictationTranscriber` → audio + note; speech usage string dropped unless `SFSpeechRecognizer` is used; `[R-D §2]` kept as the confirming source. | Plan §1, §4 item 2, §8 |
| S6 | **Adopt.** Sidecar journal design recorded. | Plan §1 Data Protection row, §2 Capture |
| S7 | **Adopt.** `@unknown default`; settings copy in words; full error-enum handling routed to the no-model path; error type name recorded with "verify against the SDK"; Simulator note softened. | Plan §4 item 4, §6.2, §8 |
| S8 | Kept as is. | — |

Nothing declined. **Open for the second round (when code exists):** a template whose slot is a
verified span can still juxtapose two true quotes into a false relation; the deck rule (one
slot, or two only within one segment) is the answer on paper and needs a fixture test. Report D
is expected to confirm S2/S4/S5's platform facts independently; where D and Sol disagree, the
synthesis records both and the first Swift resolves it against the SDK.
