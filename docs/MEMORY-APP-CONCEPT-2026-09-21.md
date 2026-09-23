# Memory-recall app (working name "Hippo") — concept and first assessment

_Written 2026-09-21 (Fable session, remote) from Perry's idea of the same day. This is a
concept, not a plan: no repo, no timeline, no decision to build yet. It exists so the idea
is not lost and so the two Gemini prompts in `research-prompts/` have a spec to answer to.
Sibling: `IPHONE-DUO-PLAN-2026-09-18.md` (StoryCue), which this reuses heavily._

## 1. The idea in Perry's words, then in one sentence

Memories from childhood, junior high and high school, and years with no photos (an
ex-girlfriend, four years) feel like they are slipping, because nothing in adult life makes
you rehearse them. So: an app where, the moment a memory surfaces — summer camp, the family
Hawaii trip — you press the iPhone's Action button, talk about it in whatever order it
comes, and the app files it (who, roughly when, where, a summary) and then asks the
questions that pull out the rest of that period. Exercise for the hippocampus; a habit of
reflection.

**One sentence:** a voice-first, on-device memory notebook whose whole job is to make you
retrieve, and to ask the next question.

## 2. Why this is stronger than it first sounds

- **The science is on its side, and it names the mechanism.** Memories survive by being
  retrieved; retrieval practice is the single most replicated finding in memory research.
  Autobiographical memory is organised in a hierarchy (Conway's model: *lifetime periods* →
  *general events* → *event-specific details*), and cues work best when they walk down that
  hierarchy. That hierarchy is also the data model (§4). Prompt C asks the research to
  confirm and sharpen this rather than trusting my summary.
- **Every piece of the stack is now free and on-device.** iOS 26 shipped `SpeechAnalyzer` /
  `SpeechTranscriber` (long-form, on-device transcription) and the **Foundation Models
  framework** (Apple's on-device LLM with `@Generable` guided generation, i.e. typed Swift
  structs straight out of the model). iOS 27 added image input and a Private Cloud Compute
  variant. So the "categorise and suggest prompts" step costs nothing per user, sends
  nothing anywhere, and needs no account — which is the only way an app holding this data
  should work, and it keeps the Money Rule trivially true.
- **The Action button is exactly the right door.** An `AppIntent` with `openAppWhenRun`
  assigned to the Action button, plus a Control Center / Lock Screen `ControlWidget` on iOS
  18+, opens the app straight into recording. The design target is *thought-to-red-light in
  under a second*, because the memory is gone in two.
- **It shares most of StoryCue's skeleton.** Native SwiftUI, XcodeGen, the `macos-27`
  Actions pipeline, AVFoundation capture, a local library with export, the
  privacy-policy-verified-against-code rule. What is new is transcription, the on-device
  model layer, the prompt engine, and the people/period graph. What is absent is
  everything hard about StoryCue: no camera accessory, no Duo, no hardware risk.

## 3. Three things that could sink it, said early

1. **A memory app must never author memories.** An LLM summary that adds a plausible
   detail is not a bug, it is the worst possible bug: it implants. Rule: the raw audio and
   the verbatim transcript are the record; every derived field is marked *derived* and
   regenerable; the summary may only paraphrase what is in the transcript, and anything
   the model infers (a year, a person's role) is rendered as a **question the user
   confirms**, never as a statement. Follow-up prompts are questions by construction, so
   they are safe; summaries are where the hazard lives.
2. **Wellness claims have a line, and Perry has already drawn it once.** The standing
   wellness-claims decision (Wilderness, 2026-09-06): *the app instructs; it does not measure.* Here:
   the app prompts; it does not assess. No memory tests, no scores, no "your recall
   improved 12%", no mention of MCI or dementia in copy, no claim to treat anything.
   "Remember more" and "reflect" plausibly sit inside FDA's general-wellness category;
   prompt C asks for the exact boundary so the copy is written to it, not near it.
3. **The AI layer needs an Apple Intelligence device** (iPhone 15 Pro / 16 and later).
   Everything else runs on any iPhone. So there must be an honest no-model mode: manual
   tags, a curated static prompt deck per life period, and the same recorder. **Perry
   carries an iPhone 16 Pro (2026-09-21), so the model path is dogfoodable on his own phone
   via TestFlight**; the no-model mode is for the rest of the install base, not for him.

## 4. Shape of the thing

**Capture.** Action button → recording view in <1 s → talk → stop. Transcript appears live.
Audio and transcript saved immediately, before any model runs; a crash after this point
loses nothing.

**File.** The on-device model returns one `@Generable` struct: working title, *lifetime
period* guess (with the user's own period list as the vocabulary: "Camp Lakeview summers",
"Junior high", "The years with R."), approximate age or year *as a question*, place,
people mentioned, three to six follow-up questions, and a two-sentence paraphrase. The user
confirms with taps; nothing is filed as fact until confirmed.

**Ask.** Follow-up questions walk the hierarchy: period → a specific event → sensory
detail ("what did the cabin smell like", "who drove") → the people ("what was Dan like
when he was annoyed"). Unanswered questions queue under the period. A daily or weekly
nudge picks one, preferring periods that are thin and old — that is the spaced-retrieval
lever, and it is the whole "exercise" claim in one mechanism.

**Browse.** By period (a life timeline by age), by person, by place. A person page is the
answer to the four-years-no-photos problem: the record accretes from many small captures.

**Keep.** Everything on device under Data Protection; optional iCloud sync via CloudKit's
private database is a later decision that changes the privacy policy. Export to Markdown +
audio files, always, one tap — the app's premise is a fear of losing things, so lock-in
would be a betrayal of it.

**Not in v1:** photos import (later: PhotoKit by date range as a cue source), the
`JournalingSuggestions` framework (Apple exposes its Journal suggestions and reflection
prompts to third parties — worth a look, but its cues are about *today*, and this app is
about *then*), embeddings for "similar memories", sharing, any cloud model.

## 5. Where it sits relative to StoryCue

Build order stays StoryCue first: its window is fixed (Duo, 2026-10-23) and this one is
not. Research runs now in parallel because it is Perry's time in Gemini, not session time.
When StoryCue's recorder, library and export exist, they are the first third of this app.
The two are one product family — *StoryCue records other people's memories; this records
your own* — which is worth saying on the developer page and nowhere else yet.

A cloud model tier, if one is ever wanted for longer context than the on-device model
gives, would be a raw-HTTPS call from Swift to the Anthropic API (there is no official
Swift SDK), opt-in, and paid by the user; it is deliberately not in the concept.

## 6. What the research should settle

Prompt C (`deep-research-memory-recall-science.md`): the retrieval and cueing science,
the reconsolidation risk, whether reminiscence practice helps healthy adults in their
twenties, the general-wellness boundary for memory copy, the competitor map (Apple's own
Journal app is the incumbent; Day One, Rosebud and the AI journals; Remento and Storyworth
from the family side; Rewind/Limitless/Bee from the lifelogging side), monetisation, and a
name check on "Hippo".

Prompt D (`deep-research-memory-recall-apple-stack.md`): the Foundation Models framework's
real limits (context window, output size, `@Generable` nesting, refusal behaviour,
availability by device and region), `SpeechAnalyzer` capabilities and language coverage,
the fastest Action-button-to-recording path and its audio-session rules, `JournalingSuggestions`
and PhotoKit as cue sources, CloudKit encryption facts, and App Review rules for apps that
gate features on Apple Intelligence.

## 7. One non-technical note

Forgetting periods nobody talks about is the expected behaviour of a normal memory, not a
symptom, and building a rehearsal habit is the standard fix. If the worry ever feels
bigger than that, it is a conversation for a clinician, which Perry knows better than this
file does. The app is built for the first case only.
