# Synthesis: memory-recall research → plan dispositions

**Sources:** `deep-research-memory-recall-science-REPORT.md` (prompt C, Gemini Deep Research,
2026-09-21, 68 citations); `deep-research-memory-recall-apple-stack-REPORT.md` (prompt D) —
**see §D below for its status.**
**Adjudicated:** 2026-09-21 session (Fable, laptop). This is planning input for
`HIPPO-PLAN-2026-09-21.md`; **nothing here authorizes building** — the build decision is Perry's,
after Sol's review of the plan.

**Citation quality (C):** mixed, and it matters which is which. The load-bearing findings trace
to primary sources: the false-memory implantation meta-analysis (PMC10126919), the two
testing-effect-in-autobiographical-memory papers (PMC5976790; Frontiers 2018), the FDA General
Wellness guidance PDF, Frattaroli 2006 (PubMed 17073523), a 2026 *Memory* paper on
retrieval-induced forgetting, and the USPTO record for "Talking Baby Hippo". A second tier is
textbook-grade secondary (Simply Psychology, a Cambridge CaR-FA-X paper, Guided Autobiography on
ResearchGate). A third tier is filler and is not relied on here: Vaia, arabpsychology, a Scribd
upload, a science.gov topic page, a femtech consulting blog for App Review, and — for the whole
competitor table — a competitor's own marketing blog (Rosebud). The SpeechAnalyzer "2.12 % WER"
figure comes from a developer blog and is not used; it is prompt D's question anyway.

**The one-line takeaway:** the science tightens Rule 1 rather than loosening it — *no generated
prose about the memory at all* — and it quietly changes what the app is for: not rehearsal that
strengthens, but extraction into a record plus re-exposure to it.

## C. Science, ethics, market (prompt C)

### Adopt

1. **Drop the generated paraphrase from v1 (C §2, exec summary row 1).** The report's strongest
   finding: memory is labile on retrieval, and a rich-false-memory implantation meta-analysis
   reports *d* ≈ 1.43. Its directive is that LLM synthesis of the user's narrative "must be
   avoided", not merely labelled. The plan's grounding validator (§5.1) stops invented nouns and
   numbers; it cannot stop a shifted valence or an invented logical bridge, and the user reads
   the paraphrase inside the reconsolidation window. **Caveat recorded honestly:** the *d* comes
   from multi-session suggestive-interview paradigms, not from reading a summary once, so the
   report over-applies it — but the design cost of dropping the paraphrase is near zero and the
   hazard is the app's number-one risk. Consequence: `shortVersion` is removed from the data model
   and the `@Generable` schema; list rows show a **verbatim excerpt** (the first ~25 spoken words)
   under a validated title; the only generated text in the product is *questions* and the
   *title*, and the title is built from spoken words and confirmed by tap. The paraphrase
   regeneration loop — the hole Sol was to probe — no longer exists.
2. **The hierarchy and the two retrieval routes (C §1).** Lifetime periods → general events →
   event-specific knowledge is confirmed as the model. Sharpening: the Action-button moment *is*
   direct retrieval (a cue bypassed the search and the memory arrived), and the Ask surface is
   generative retrieval (a top-down walk). The plan says so now; it names why capture must be
   instant and why questions must walk downward.
3. **Sensory anchors are the potent cue, but must be "report everything" (C §3, cognitive
   interview; C §1 CaR-FA-X).** Contextual reinstatement is the most validated technique and
   sensory grounding is what breaks overgeneral memory. This partly conflicts with Kimi's
   review (`HIPPO-PLAN-REVIEWS-2026-09-21.md` K3/K4), which gated sensory questions to channels
   the user had already mentioned. Resolution: sensory cues are allowed on unmentioned channels
   **only in the cognitive-interview form** — a multi-channel *report-everything* invitation
   ("Anything about the place itself — the light, the sounds, the weather, what you were
   wearing? However small.") — never a single-channel wh-question ("What did it smell like?").
   Nothing is recorded unless spoken, so an "I don't know" costs nothing. Plan §7 amended.
4. **Retrieval-induced forgetting (C §2).** Narrow, repeated questioning on one aspect suppresses
   the unpracticed rest of the period. Consequences, all cheap: the *first* follow-up after any
   capture is always the broad one ("Anything else at all, however small?") before any narrow
   cue; the engine rotates across referents within a period rather than drilling one; Kimi's
   per-channel cap stands. Plan §7.
5. **Contextual reinstatement before speaking — for nudges only (C §3).** The report wants a
   visualisation step before the user talks. That conflicts with the sub-second capture path,
   where the memory has *already* surfaced (direct retrieval; adding a step loses it). Adopt for
   the nudge path only: when the user opens a queued question, the recording view shows one line
   — "Take a second. Where were you, what time of year, who was around — then talk." Plan §7.
6. **The testing effect does not persist in autobiographical memory (C §2; PMC5976790, Frontiers
   2018).** Retrieving a personal memory gives no measurable retention advantage over re-reading
   it. Medium confidence (two studies, modest samples) but it costs nothing to honour and the
   product gains a surface: the value claim becomes **extraction into a durable record +
   re-exposure**, and a **Revisit** action is first-class — a nudge may offer *listening to an old
   capture* as well as a question, and Timeline rows play. "Spaced retrieval" in the plan is
   renamed *spaced re-exposure*. The listing copy gets quieter ("keep", "reflect"), which also
   suits Rule 2. Plan §2, §7, §9.
7. **Reminiscence bump (C §1).** A 27-year-old is leaving the 10–30 window, so the last decade is
   the richest material, not toddlerhood. The nudge weighting is rebalanced: **thinness first,
   age second**; default period seeds keep "Twenties" and the copy never implies that only
   childhood is worth keeping. Plan §7, §8.
8. **General-wellness boundary confirmed (C §4).** "Remember more, reflect more" sits inside the
   FDA's general-wellness examples; disease terms take it out. The copy lint's forbidden list is
   extended with *PTSD, depression, ADHD, anxiety, trauma, therapy, treat-, cure-, prevent-,
   diagnos-*. **Version note:** the report cites the 2016 guidance; the private wellness-claims
   memo has the **2026-01-06** revision archived with a SHA-256 — that copy is authoritative for
   copy review, not the report. FTC: Lumosity (2016, $2 M) and LearningRx were penalised for
   disease-prevention claims without trials; no action found against wellness-only journaling
   apps. Plan §5.2, §9.
9. **Emotion words are bad cues (C §1, cue-word literature).** Emotional cue words produce
   overgeneral memories; concrete places, times of day and objects produce specific ones. The
   deck never uses an emotion word as a cue — which Kimi's lint already enforces for a different
   reason. Recorded here so the two reasons are both on file.
10. **Monetisation: freemium → one-time unlock (C §6).** Fits a zero-server app and the
    privacy pitch; competitors at $9–15/month are paying for cloud LLMs. Adopt as the model of
    record with two constraints the report did not state: the free tier is capped by **capture
    count only**, and **export and the no-model mode are never gated** (Rule 3 and the "fear of
    losing things" premise). Price is Perry's call; $29.99–49.99 is the report's range.
11. **"Hippo" is unviable as a product name (C §6).** USPTO: "Talking Baby Hippo", Out Fit 7
    Limited, application 85189137, in the software/app class. Adopt: **"Hippo" is an internal
    codename only** — no App ID, repo, or ASC record under it. The report's alternatives —
    *Echoes, Epoch, Vivid, Loom, Ember* — were **not** conflict-checked by the report; each is a
    common English word and at least Echoes and Vivid look congested on their face. The name is
    an operator act (plan §11) and the chosen name gets its own USPTO + App Store check before
    any identifier is created.
12. **Competitor gap (C §5).** No incumbent is retrieval-first, past-first, voice-first and
    on-device: Apple Journal is present-tense by construction (confirms the concept's
    `JournalingSuggestions` decision); the AI journals are cloud-bound and subscription-priced;
    the lifeloggers capture everything and retrieve nothing; Day One's top complaint (locked out
    of old entries when the subscription lapses) is the exact betrayal the always-on export
    prevents. Adopted as positioning. **Numbers in that table are from a competitor's blog and
    are indicative only.**
13. **Guided Autobiography themes as a second axis (C §3).** Birren & Cochran's themes —
    turning points, family origins, work, health and the body, love and relationships — become
    optional **theme cards** in the static deck beside the period seeds. **Licensing caution:**
    GAB is a published method, not public domain; the *themes* are usable, the *text* is not.
    Deck copy is authored.

### Decline

- **Autobiographical Memory Interview (AMI) "to score the richness of episodic detail" for
  internal metadata (C §3).** Declined outright. The AMI is a clinical assessment instrument;
  scoring detail richness, even internally, is assessment by another door and contradicts
  Decision #47's posture and plan §5.2 item 1 ("no performance metrics exist in the data
  model"). The engine's thinness heuristic counts captures, not quality.
- **Pre-recording visualisation on the capture path (C §3).** Declined for capture (see Adopt 5
  for where it is kept).
- **"The app does not need to focus on childhood" read as a product pivot (C §1).** The
  weighting changes (Adopt 7); the premise — years with no photos, whatever the age — does not.

### Unknown / not settled by report C

- Spoken vs written retrieval: the report's argument (lower working-memory load, prosody) is
  plausible and its sources are weak (a Scribd upload, a topic page). Voice-first stands on
  product grounds, not on evidence. Report's own "could not find" #1.
- Spaced re-exposure schedules for healthy young adults: no evidence either way (report's #2).
  The nudge cadence is a UX choice; the copy must not claim it does anything to memory.
- FTC posture toward wellness-only journaling apps: no action found (report's #3). Absence of
  enforcement is not a safe harbour; the lint stands.
- Whether any *validated, licensable* prompt set exists beyond GAB themes: not found. Deck copy
  is authored here.
- App Review specifics for on-device speech (the report's source is a consulting blog): prompt
  D's question.
- The reminiscence-bump papers cited are the classic ones; nothing newer than 2011 was found,
  which is fine for a robust effect.

## D. Apple on-device stack (prompt D)

**Status 2026-09-21: no report.** Three runs of prompt D failed in one session, all in the
execution phase, while prompt C completed on the same account: run 1 (concurrent with C)
stalled at "Starting research…" for 90+ minutes with no error and no banner; run 2 (solo) failed
with Gemini's generic "Something went wrong. Please try again later."; run 3 (solo, verbatim
paste confirmed) ran with a live thinking trace for ~15 minutes, then reverted to the bare
"Starting research…" placeholder and stayed there. No quota, rate-limit or upgrade banner was
ever shown, so the lane's stop gate did not fire; the driver stopped after the third failure
rather than keep retrying. The three dead conversations remain in Gemini's history
(`8b1fecfaeb9fb516`, `444fb74defa71c0a`, `706f30db671aa1fa`) if Perry wants to inspect them.
**One thing to check before any re-run:** the driver observed the *Personal Intelligence (Labs)*
toggle ON under More Tools, and the auto-generated research plan injected "Birmingham, Alabama"
as a comparison point that nothing in the brief asked for — a location leak into research plans,
and a possible contributor to the instability. Turning it off is an account-settings change and
is Perry's. **Decision (Perry, 2026-09-21): re-run D solo in plan §12 week 0**, not before the
build decision — its questions bind the week 2 and week 3 gates, and Sol covers the four
load-bearing facts at High until then. Perry turns the Labs toggle off first; the session drops
the report beside this file and adjudicates it here in the same adopt / decline / unknown shape. Until then every `[R-D]` tag in the plan stands as written, and the
plan's platform facts rest on this session's recollection of WWDC 2025 plus Sol's review.

Questions D must settle, in the order they bind the plan: the on-device context window (plan
§6.3 budget); whether `SpeechTranscriber` runs on non-Apple-Intelligence iPhones (decides
whether no-model mode has a transcript); whether on-device `SpeechAnalyzer` needs the speech
usage string; `AudioRecordingIntent` vs `openAppWhenRun` as the Action-button door; guardrail
scope over personal content; App Review wording for Apple Intelligence gating; CloudKit
encryption facts for a later sync version.

**Sol's review (same day, `HIPPO-PLAN-REVIEWS-2026-09-21.md` §2) pre-answered four of these
from Apple documentation at High confidence** and the plan was amended on that basis: 4,096
tokens per session, shared; `openAppWhenRun` deprecated in iOS 26 and a Control → foreground
intent as the door, with no background microphone start; `SpeechAnalyzer` needs no speech
authorisation and `DictationTranscriber` is the explicit older-device fallback; `.complete`
stores are unwritable while locked. Report D is still wanted as the independent second source
on each; where D and Sol disagree, record both here and resolve against the SDK when the first
Swift is written. Still D-only: guardrail scope, App Review gating wording, CloudKit encryption,
language coverage and asset sizes, the Apple Intelligence install-base share.
