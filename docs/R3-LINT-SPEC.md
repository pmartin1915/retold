# R3 spec — leading-question lint, wellness copy lint, seed deck

_Written 2026-10-02. Step R3 of `../storycue/docs/STRATEGY-2026-09-22.md` ("Leading-question lint (§7) +
wellness copy lint (§5.2) as CI tests; the authored template deck must pass them"). Governing design:
`docs/PLAN.md` §7 (the lint and the cue levels), §5.2 (the copy lint), §8 (the deck), §5.1 (one-slot
rule). Same contract as R1 and R2: every type, file, rule and test name is fixed here. Deck copy is
written here by Opus; the executor types it, it does not write copy._

## Scope

**In:** three new source files, one edit to `Retold/Filing/TemplateAssembler.swift`, three new test
files, one edit to `RetoldTests/TemplateAssemblerTests.swift`. Pure Swift, XCTest. No `project.yml`
or `.github/` change (XcodeGen picks up new files under `Retold/`; `.swift` files are not in
`build.yml`'s `paths-ignore`, so every deck or lint edit re-runs CI).

**Out:** question ordering, negatives, per-channel caps and nudge selection (R4); per-period deck
assignment and `DeckFilingModel` (R5); the transcript-aware form of the channel rule, which needs a
transcript (R4 — at CI time there is none, so the deck form below is strict); the full deck size of
PLAN §8 (bulk copy later, same file, no lint change); string catalogs, App Store metadata and the
privacy policy (none exist yet — the file scan below picks them up when they do).

## 1. Seed deck — `Retold/Questions/QuestionDeck.swift`

`enum QuestionDeck { static let all: [QuestionTemplate] }` = `FilingTemplates.all` followed by the 19
templates below, in this order. Add `static let all: [QuestionTemplate]` to `FilingTemplates`
(`[broad, when, whenWithCue, who, sensoryPlace, referent]`). Patterns verbatim, including the em dash
(`\u{2014}`, matching R2's style) and the curly-free ASCII apostrophe in `you've`/`you'd`.

| id | cue | pattern |
|---|---|---|
| `period.else` | period | What else comes to mind from that time? |
| `period.who` | period | Who do you think of when you think of that time? |
| `period.where` | period | Is there anywhere that comes to mind from that time? |
| `period.slot` | period | When you think of {slot}, what comes back first? |
| `event.else` | event | Is there anything else about that? |
| `event.shape` | event | How do you remember it \u{2014} one moment, a stretch of days, something else? |
| `event.anyone` | event | Is there anyone you think of with this? |
| `sensory.everything` | sensory | Anything about the place itself \u{2014} the light, the sounds, the weather, what you were wearing? However small. |
| `sensory.mentioned` | sensory | You mentioned {slot} \u{2014} is there anything else you remember of it? |
| `people.describe` | people | How would you describe {slot}? |
| `people.talk` | people | Is there anything about how {slot} talked that stays with you? |
| `people.together` | people | Is there anything you remember doing with {slot}? |
| `sequence.connect` | sequence | Does this connect to anything else you've thought about since? |
| `sequence.otherTimes` | sequence | Has anything about this come back to you at other times? |
| `theme.turningPoint` | period | Is there anything you'd call a turning point? |
| `theme.family` | period | What comes to mind when you think of where your family comes from? |
| `theme.work` | period | What comes to mind when you think of work you've done? |
| `theme.body` | period | Is there anything about your health and your body, at any age, that comes to mind? |
| `theme.close` | period | Who comes to mind when you think of someone you've been close to? |

Theme ids are Guided Autobiography's *themes* (PLAN §8: themes usable, text not); the copy is ours.
**If any of these fails the lint, do not weaken a rule and do not reword the copy: stop and report
the failing id and rule.** Copy changes are the boss's. (The boss ran a Python prototype of §2 over this deck and every §5
vector before dispatch: all 25 pass, every negative hits its named rule.)

## 2. Leading-question lint — `Retold/Questions/LeadingQuestionLint.swift`

```swift
enum LeadingRule: String, CaseIterable, Sendable {
    case properNoun, numeral, emotionWord, presupposingSequence, bareDefinite,
         intensifier, alternativeQuestion, tagQuestion, closedQuestion, unmentionedChannel
}
struct LeadingViolation: Equatable, Sendable { let rule: LeadingRule; let match: String }
enum LeadingQuestionLint {
    static func violations(in pattern: String) -> [LeadingViolation]
}
```

It lints a **template pattern**, `{slot}` markers in place. A slot is a verified span or a confirmed
entity, so it is never itself checked; it is a token that matches no list and is never a proper noun.
Slot text is never linted (a verified span may legitimately be "the summer of '98").

**Tokens.** Split on whitespace. A token whose raw text **contains** `{slot}` (e.g. `{slot},` or
`'{slot}'`) is a slot token, key `{slot}`; detect this *before* keying, because R2's
`SpanVerifier.key(_:)` strips braces as edge punctuation. Every other token's key is
`SpanVerifier.key(_:)` (lowercased, apostrophes straightened, edge punctuation removed); empty keys are
dropped. Phrases match on consecutive keys. **Sentences** are the pieces of the pattern split on `.`,
`?`, `!`; **clauses** are the pieces of a sentence further split on the em dash `—`; both trimmed. A
clause's *opener* is its first token key. `bareDefinite` and the report-everything test work per
**sentence**; every other rule works per **clause**. `wh` = {what, which, how, where,
who, whom, whose, when, why}; `aux` = {is, are, was, were, did, do, does, have, has, had, can, could,
would, will}; `open` = {anything, anyone, anywhere, something else, anybody}.

| Rule | Fails when | Word lists (fixed) |
|---|---|---|
| `properNoun` | a token whose first character is uppercase, other than `I`, `I'm`/`I've`/`I'd`, and other than the first token of a clause | — |
| `numeral` | a token containing an ASCII digit | — |
| `emotionWord` | a key in the list, applied to anyone | afraid, scared, frightened, happy, happier, sad, sadder, angry, mad, annoyed, upset, proud, ashamed, embarrassed, excited, nervous, worried, lonely, hurt, jealous, guilty, grateful, disappointed, relieved, furious, bitter, heartbroken, miserable, joy, joyful, fear, grief, shame, regret, feel, felt, feeling, feelings |
| `presupposingSequence` | a key or phrase in the list | the next, the first time, the last time, most days, every time, always, again, finally, continue, continued, still, end, ended, ending, before that, after that, afterwards |
| `bareDefinite` | the key `the` followed by any token, **except** inside a report-everything sentence (below) when the next key is a channel noun. `the {slot}` always fails (the deck may not add a definite to a spoken phrase) | — |
| `intensifier` | a key or phrase in the list | most, stands out, stand out, vivid, clearest, best, worst, favorite, favourite |
| `alternativeQuestion` | a clause whose opener is in `aux` and which contains the key `or` | — |
| `tagQuestion` | a clause ending `, <aux>[n't] <pronoun>` before its `?` (regex on the raw clause, case-insensitive: `,\s*(is|are|was|were|did|do|does|have|has|had|can|could|would|will)(n't|nt)?\s+(it|you|he|she|they|we|there|that)\s*$`) | — |
| `closedQuestion` | a clause whose opener is in `aux` and which contains no `open` key or phrase | — |
| `unmentionedChannel` | a clause whose opener is in `wh` and which contains a channel word | channel words: smell, smelled, smelt, taste, tasted, sound, sounded, sounds, hear, heard, see, saw, look, looked, wear, wearing, wore, weather, music, playing, song, colour, color, light, temperature, cold, warm, hot |

**Report-everything sentence** (PLAN §7 item 3; C adopted): a sentence whose first token key is
`anything`, which contains **at least two distinct** channel nouns from {light, sounds, sound, weather, smell, smells,
air, colours, colors, voices, place, wearing, temperature, music}. Inside such a sentence, `the` before
a channel noun is allowed. Nothing else is exempted: a single-channel invitation, or any `wh` opener,
gets no exemption. `sensoryPlace` ("Anything about {slot} itself — the light, the sounds, the
weather?") and `sensory.everything` pass by this rule and by no other.

`violations` returns every violation in pattern order (a pattern can break several rules). Word lists
are `private static let` inside the lint; **tests must not reference them** (see §5).

## 3. Wellness copy lint — `Retold/Questions/WellnessLint.swift`, `Retold/Copy/AppCopy.swift`

```swift
struct WellnessViolation: Equatable, Sendable { let term: String; let match: String }
enum WellnessLint { static func violations(in text: String) -> [WellnessViolation] }
```

Case-insensitive regexes, each anchored with `\b` at the start; `term` is the entry's label below,
`match` the matched text. PLAN §5.2's list plus *memory loss* (report D §6, Guideline 1.1, adopted
2026-10-02) and *brain* (PLAN §9):

| term | regex |
|---|---|
| memory test | `\bmemory tests?\b` |
| memory loss | `\bmemory loss\b` |
| score | `\bscor(e|es|ed|ing)\b` |
| improve memory | `\bimprov(e|es|ed|ing) (your |my )?memor(y|ies)\b` |
| cognitive | `\bcognitive\b` |
| decline | `\bdeclin(e|es|ed|ing)\b` |
| assess | `\bassess\w*` |
| screen | `\bscreen(s|ed|ing)?\b` |
| MCI | `\bmci\b` |
| dementia | `\bdementia\b` |
| Alzheimer | `\balzheimer\w*` |
| diagnose | `\bdiagnos\w*` |
| treat | `\btreat\w*` |
| cure | `\bcur(e|es|ed|ing)\b` |
| prevent | `\bprevent\w*` |
| brain | `\bbrain\w*` |
| sharpen | `\bsharpen\w*` |
| PTSD | `\bptsd\b` |
| depression | `\bdepress\w*` |
| ADHD | `\badhd\b` |
| anxiety | `\banxi(ety|eties|ous)\b` |
| trauma | `\btrauma\w*` |
| therapy | `\btherap\w*` |

(`screen` deliberately does not match `screenshot`; `cure` does not match `secure` or `curious`;
`score` does not match `underscore`. These are tested.)

`enum AppCopy { static let all: [String] }` holds the user-facing strings PLAN already fixes, verbatim,
so the lint has real copy to check before any string catalog exists: the three distinct §8
unavailable-reason lines ("Suggestions need a newer iPhone; everything else works", "Turn on Apple Intelligence in
Settings to get suggested questions", "Suggestions will appear once your phone finishes downloading
them"), the §7 reinstatement line ("Take a second. Where were you, what time of year, who was around
\u{2014} then talk."), the §5.2 nudge line ("One question waiting"), and the §9 fallback line
("Suggested questions use Apple Intelligence on supported iPhones; recording, filing and browsing work
on every iPhone running iOS 26."). Each as a named `static let` and listed in `all`. Not wired to any
view in R3.

## 4. Function-word slot guard — edit `Retold/Filing/TemplateAssembler.swift`

R2's known gap: a one-word span such as "I" verifies (it is verbatim) and would fill `who` as "Who was
I to you, back then?". Add `case slotIsFunctionWord` to `TemplateAssemblyError`, and in `assemble`,
after the count check, throw it when **every** word key of any slot (`SpanVerifier.key`, empty keys
skipped) is in this set: i, me, my, mine, myself, you, your, yours, he, him, his, she, her, hers, it,
its, we, us, our, ours, they, them, their, theirs, this, that, these, those, there, here, a, an, the,
and, or, but, so, then, um, uh, like, just. `followUps` already uses `try?`, so such spans are silently
skipped there — no other change.

## 5. Tests — `RetoldTests/`

Tests use **fixed literal strings only**. They must not read the lint's word lists or regexes, and must
not build expectations from them; a test that passes because it mirrors the implementation is a
failed test. Every test asserts the **specific rule** (`LeadingRule` / `term`), not just non-empty.

| File | Asserts |
|---|---|
| `LeadingQuestionLintTests` | **(a) one negative per `LeadingRule`** (10 tests, each asserting that rule appears): "Who was Dan to you?" (properNoun), "What happened in 1998?" (numeral), "Were you scared, back then?" (emotionWord), "What happened the next summer?" (presupposingSequence), "What do you remember about the drive home?" (bareDefinite), "What do you remember most?" (intensifier), "Did it end badly, or just fade?" (alternativeQuestion), "It was summer, wasn't it?" (tagQuestion), "Was it summer?" (closedQuestion), "What did the place smell like?" (unmentionedChannel). **(b) Kimi's five worst and PLAN's own fail, with the named rule:** "What was {slot} like when they were annoyed?" → emotionWord; "What is something {slot} said that you can still hear?" → presupposingSequence; "How did that day end?" → presupposingSequence; "What happened the next summer?" → presupposingSequence; "What did the place smell like?" → unmentionedChannel **and** bareDefinite; "You mentioned the {slot}. Is there anything else?" → bareDefinite; "Anything about {slot} \u{2014} the smell?" → bareDefinite (one channel noun is not report-everything). **(c) positives pass with zero violations:** every pattern in `FilingTemplates.all`; "When you think of that place, what comes to mind first?"; "Is there anything about how {slot} talked that stays with you?"; "Does this connect to anything else you've thought about since?". **(d)** `I` is not a proper noun ("Is there anything I should ask?" passes); a capital after `?` or `—` starts a clause ("Anything else? However small." passes). **(e)** a slot is never linted: "{slot}" alone passes. |
| `QuestionDeckTests` | every template in `QuestionDeck.all` has zero leading violations (failure message names id and rules) and zero wellness violations; ids are unique; patterns are unique; every template has ≤ 2 slots and the deck has none with 2 (R3 seeds none); `QuestionDeck.all` starts with `FilingTemplates.all`; count is exactly 25; every `CueKind` case has at least one template; **every template id `TemplateAssembler.followUps` can return is in the deck** — build a `MergedExtract` with a time cue, two referents, two places and two people (fixture spans) and one without a time cue, collect `templateID`s, assert ⊆ deck ids. |
| `WellnessLintTests` | one hit per term (23 cases, a table-driven test with fixed sentences, asserting the `term`); near-misses pass: "Take a screenshot", "Keep it secure", "I was curious", "an underscore", "It was a treasure" (no `treat` match — `treas…` ≠ `treat`); `AppCopy.all` is non-empty and clean; **file scan**: from `#filePath`, find the repo root (the directory holding `project.yml`), extract every `NS*UsageDescription:` value from `project.yml` (at least one must be found — fail, don't skip, if zero or unreadable), plus every `Retold/**/*.xcstrings` and `metadata/**/*.txt` file's full text if any exist; all clean. Assert the scanned set is non-empty. |
| `TemplateAssemblerTests` (edit) | +2: `assemble(who, slots: ["I"])` throws `.slotIsFunctionWord`, and so do "the" and "um, you"; `followUps` from an extract whose only person span is "I" contains no `who.person` question, while a person span "my aunt" still produces one (a function word plus a content word is allowed). |

## Do not

No new dependency; no `FoundationModels`; no `try!`, `Task.detached`, `@unchecked Sendable`,
`nonisolated(unsafe)`; no `!` outside tests; no change to any R1/R2 behaviour other than §4; no edit
to deck copy or to a rule to make a test pass; no AI attribution in code, comments or commits.

## Done when

PR CI green first run (Build & XCTest + Release compile): R1+R2's tests plus the new ones pass. The boss
then runs a **mutation pass**: for each `LeadingRule`, disable that rule's check and confirm at least
one test fails; same for three wellness regexes and the function-word guard; any surviving mutant is a
missing test and blocks merge. Pre-merge review: Sonnet `reviewer` agent (or Sol if he did not build
it). `ai/STATE.md` names R4 next.
