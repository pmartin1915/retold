# R3 spec — leading-question lint and wellness copy lint

_Written 2026-10-02. Step R3 of `../storycue/docs/STRATEGY-2026-09-22.md`. Governing design:
`docs/PLAN.md` §7 ("Leading-question lint"), §5.2 (Rule 2, the copy lint), §5.1 tail (one slot per
template). Same contract as R1/R2: every type, file and test name is fixed here._

## Scope

**In:** `Retold/Lint/` (`QuestionLint`, `SlotGuard`, `CopyLint`), a small edit to
`TemplateAssembler.swift` (`FilingTemplates.all`, and `followUps` skips degenerate spans), and four
test files. Pure Swift, no `FoundationModels`. The lint runs as XCTests inside the existing
`RetoldTests` target, so it runs in the existing `build.yml` job. **No workflow file is added or
edited.**

**Out:** the full authored deck (R4 owns ordering and the deck's growth; R3 lints what exists —
the six `FilingTemplates` — and every future template inherits the test), nudge copy, App Store
metadata (does not exist yet; the copy lint scans it when it appears).

## 1. `QuestionLint` — `Retold/Lint/QuestionLint.swift`

Deterministic and lexical. It lints a template's **literal text** (the pattern with every `{slot}`
masked), because slot content is a verified transcript span and is the user's own words. Slots are
checked separately (§3).

`LintRule`: `properNoun`, `numeral`, `emotion`, `ordinal`, `bareDefinite`, `intensifier`,
`alternative`, `unmentionedChannel`, `degenerateSlot`. `LintViolation(rule, evidence)`.
`LintContext(allowedNames, allowedDefinites, mentionedChannels)`, all empty by default: the
facts a caller may legitimately rely on (user-typed names, confirmed-fact nouns, channels the
transcript mentions). The authored-deck test uses the empty context, the strictest.

| Rule | Rejects (PLAN §7) | Mechanism |
|---|---|---|
| `properNoun` | a proper noun not in the allowed names | a capitalised word that does not start a sentence (not after `.?!`, not first) and is not "I" |
| `numeral` | any numeral | a digit, or a spelled number two to twenty, hundred, thousand. "one" is allowed ("one moment, a stretch of days") |
| `emotion` | an emotion or state word, any subject | word list plus safe stems: scared, afraid, angry, annoyed, upset, sad, happy, nervous, anxious, worried, embarrassed, ashamed, guilty, jealous, lonely, excited, proud, terrified, furious, grief, stress, … |
| `ordinal` | a sequence or norm presupposition | next, first, third–tenth, last, most, always, never, usually, often, every, again, finally, continue/-d/-s, still. "second" is not listed (it is a time unit in nudge copy) |
| `bareDefinite` | "the X" not in the allowed definites | `the` + a word not in `allowedDefinites`. Exemption: a channel noun inside a report-everything list (rule below) |
| `intensifier` | implies a salient target exists | vividly, clearly, distinctly, especially, particularly, really, definitely, obviously, surely; "stand(s) out" |
| `alternative` | supplies the answer space | the word "or"; a tag ending (", right?", "isn't it", "didn't you", …) |
| `unmentionedChannel` | a one-channel question (any form, yes/no included) on a channel the transcript did not mention | channels: sight, sound, smell, taste, touch, weather, clothing. A question naming **two or more** channels is the cognitive-interview report-everything form and is allowed; one channel needs that channel in `mentionedChannels` |
| `degenerateSlot` | a slot that cannot carry a question | see §3 |

Audited exemptions (`QuestionLint.exemptions`, a visible, tested list): a template may be exempt
from one rule with a written reason. Currently **one**: `when.open` / `alternative` — "a year, or
how old you were" offers two *units* for a date, not two contents for the memory. A test pins the
list to exactly this, so adding an exemption is a reviewed diff.

## 2. `CopyLint` — `Retold/Lint/CopyLint.swift`

PLAN §5.2 item 2's forbidden list: memory test, score, improve(d/s/ing) your/the memory, cognitive,
decline, assess-, screening, MCI, dementia, Alzheimer, diagnos-, treat-, cure, prevent-, brain
training, sharpen, PTSD, depression, ADHD, anxiety, trauma, therapy. Tokenised (lowercase, split
on non-letters), stems as prefixes, short words (score, cure, MCI) exact, phrases on the joined
token string. `CopyLint.violations(in:) -> [String]` of matched terms.

Files scanned by `CopyLintTests`, found from `#filePath` (the simulator test host shares the
runner's disk): every `*.xcstrings` under `Retold/`; every file under `AppStore/`, `fastlane/
metadata/`; any `PRIVACY*` / `PrivacyPolicy*` file; the user-facing strings of `project.yml`
(`NS*UsageDescription`, `CFBundleDisplayName`); and every `FilingTemplates` pattern. `README.md`
and `docs/` are **not** scanned: they name the forbidden terms in order to forbid them. Absent
directories scan as empty (they do not exist yet); the `project.yml` test asserts it found the
strings it guards, so "no files found" cannot pass silently there.

## 3. Slot guard — `Retold/Lint/SlotGuard.swift` — the known gap from R2

`SlotGuard.isDegenerate(_ text:)`: a span whose words are all stopwords or pronouns (I, me, you, it,
the, and, …) or a single word under two letters. "I" verifies as a span but must not fill `who`.
`TemplateAssembler.followUps` skips degenerate spans (production guard, not only a test).
`QuestionLint.slotViolations(_:)` reports them.

## 4. Tests — `RetoldTests/`

| File | Asserts |
|---|---|
| `QuestionLintTests` | **one failing leading question per reject-list rule** (proper noun, numeral, emotion — user and other-directed, ordinal/quantifier, bare definite, intensifier, alternative and tag, unmentioned channel), each also with a passing near-twin; report-everything form passes; allowed names/definites/channels honoured |
| `DeckLintTests` | every `FilingTemplates` pattern is clean with the empty context except the pinned `when.open` exemption; every `followUps` output from a fixture with all kinds of span lints clean; exemption list is exactly the one entry; a `{slot}`-expanded span's content is not linted |
| `SlotGuardTests` | "I", "it", "the" rejected; "Dan", "the lake" accepted; `followUps` with a "I" person span emits no `who.person` |
| `CopyLintTests` | each forbidden term caught (stem and exact, case-insensitive); near-misses pass ("curious", "cured" is caught, "screen" alone passes, "scoreboard" passes); real scanned files are clean; planted string caught |

## Do not

No new dependency, workflow, or Info.plist change. No `try!`, `!` outside tests, no AI attribution.
