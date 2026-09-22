# Gemini Deep Research prompt — a voice-first autobiographical-memory app: the science, the ethics, the market

> **Paste everything between the rules into Gemini Deep Research.** Gemini doesn't have file access; the prompt is fully self-contained. Drop the report back beside this file as `deep-research-memory-recall-science-REPORT.md`; a Claude session adjudicates it into a synthesis.

---

## Background

I am a solo iOS developer and a nurse. I want to build a personal, offline, no-account
iPhone app for people in their twenties and thirties who feel that memories from childhood,
school years, or relationships with no photo record are fading because adult life never
makes them retrieve those memories. The mechanic: when a memory surfaces, the user presses
the iPhone's Action button, talks about it in any order, and the app (using Apple's
on-device speech and language models, nothing sent to a server) transcribes it verbatim,
proposes how to file it — life period, approximate age or year, place, people — and then
asks follow-up questions designed to pull out more of that period. Later it nudges the
user with unanswered questions, preferring periods that are thin or old. The app never
scores memory, never tests recall, and makes no medical claims; the pitch is "remember
more, reflect more."

Today is 2026-09-21. I need the product grounded in evidence before I write a line.

## What I need you to research

Answer each numbered question separately. Cite primary sources (peer-reviewed papers with
year and journal, statutes, Apple's own documents, the products' own pages) with dates.
Mark each answer High / Medium / Low confidence. "Unknown" beats a guess.

### 1. How autobiographical memories are organised and cued
- Summarise the current consensus on autobiographical memory structure — the
  self-memory system (Conway & Pleydell-Pearce and successors), lifetime periods → general
  events → event-specific knowledge — and what it predicts about **which cues work**:
  period cues vs event cues vs sensory cues, generative vs direct retrieval.
- The **reminiscence bump** (roughly ages 10–30): what it implies for a 27-year-old user;
  whether memories from that window are more retrievable and more stable.
- The cue-word technique (Galton, Crovitz & Schiffman) and modern cueing methods used in
  research: what kinds of cue produce specific rather than generic memories, and what
  the "memory specificity" literature says about training specificity (e.g. MEST).
- Does talking about a memory aloud, versus writing, change what is retrieved? Any
  evidence on voice vs text recall.

### 2. Does retrieving strengthen — and does it distort?
- The **testing / retrieval-practice effect** applied to autobiographical memory, not lab
  word lists: does deliberately recalling personal memories make them more durable?
- **Reconsolidation and retrieval-induced distortion:** every retrieval can rewrite. What
  is the evidence that repeated recall of autobiographical memories introduces errors,
  and what practices minimise it (open questions vs leading questions, no suggested
  details, verbatim records)? I am worried specifically about a language model's
  *summary* implanting details; is there literature on AI or partner-narrated summaries
  altering memory (misinformation effect, co-witness contamination)?
- **Spaced retrieval** schedules that have evidence for personal memories, if any.
- Any evidence that reminiscence or life-review practice benefits **healthy young
  adults** (wellbeing, identity coherence, mood), not just older adults or clinical groups.
  Also the risks: rumination, re-traumatisation, and the expressive-writing literature's
  findings on when reflecting on the past hurts.

### 3. Follow-up question design
- What interviewing and oral-history practice says about question sequencing that opens
  a memory up (funnel, sensory anchors, people-first) versus questions that shut it down.
- Evidence on **contextual reinstatement** (re-imagining the place, the season, the
  people, the music) as a cue technique — the cognitive-interview literature.
- Any validated prompt sets for life periods (childhood home, school, first jobs,
  relationships, travel) that are public domain or licensable.

### 4. The wellness boundary
- FDA's General Wellness guidance and the mobile-medical-applications policy: exactly
  which memory-related claims fall inside general wellness ("mental acuity", "memory
  support"?) and which trip into device territory (screening, cognitive assessment,
  anything naming MCI, dementia, Alzheimer's). Give the guidance's own example phrases.
- App Store Review Guidelines (1.4 physical harm, 5.1 privacy, anything on health
  claims) as they apply to an app that stores voice recordings of personal memories with
  no cloud.
- Are there FTC or state consumer-protection actions against apps claiming to "improve
  memory" (brain-training settlements: Lumosity 2016 and later)? What did they penalise?

### 5. Competitors and adjacent products (as of September 2026)
For each: mechanic, whether it works from the past or from today, on-device vs cloud,
pricing, ratings and review count, and what negative reviews complain about:
- **Apple Journal** (iOS 17.2+, with Journaling Suggestions and, in iOS 27, Apple
  Intelligence writing prompts) — the incumbent; be precise about whether it can prompt
  about the distant past or only about recent activity.
- Day One, Rosebud, Reflectly, Stoic, Mindsera, Bearable, Finch.
- Remento, Storyworth, Memoirji, Tell Mel (family-memoir tools).
- Rewind, Limitless pendant, Bee, Plaud (lifelogging; the opposite approach — capture
  everything, retrieve nothing deliberately).
- Any app that specifically targets "recover fading memories" or "life timeline by age".
Then: what gap remains, and is "retrieval-first, past-first, voice-first, on-device" a
real distinction users would understand?

### 6. Monetisation and naming
- What personal-journal and memory apps charge and how (one-time, subscription, freemium);
  which model fits an app with zero server cost and a privacy-first pitch.
- Name check "Hippo" (hippocampus) for an App Store app in this category: conflicts on
  the App Store, USPTO, and the web; propose five alternatives that are short, warm, and
  not clinical.

## Output format

A report with one section per question, a one-page executive summary of the ten findings
that most change the design, a table of the strongest citations (author, year, journal,
finding, effect size where available), a table of competitors, and a "what I could not
find" list. Distinguish clearly between findings in healthy young adults and findings in
older or clinical populations.
