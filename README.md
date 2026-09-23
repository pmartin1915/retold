# Retold

Voice-first, on-device autobiographical memory app. Press the Action button when a
memory surfaces, talk about it in any order; the app files it (life period, age/year as a
question, place, people, a paraphrase) and asks follow-up questions that pull out the rest
of that period. On-device only: iOS 26 `SpeechAnalyzer` for transcription, the Foundation
Models framework (`@Generable`) for filing and questions. Forks StoryCue's skeleton
(XcodeGen, `build.yml`/`deploy.yml` on `macos-27`/`xcode-27`) rather than sharing a
package -- the two apps diverge immediately (audio-only vs video, no Duo path here).

- **Plan and decisions:** `docs/PLAN.md`
- **Handoff for agents:** `docs/HANDOFF-2026-09-21-kickoff.md`, then `ai/STATE.md`
- **Research:** prompts and reports in `docs/research/`, review adjudications in
  `docs/reviews/`

Bundle id `dev.pmartin1915.retold`. Codename during planning was "Hippo" -- rejected
(USPTO collision, `docs/PLAN.md` section 11). Zero marginal cost by design: no server, no
cloud model, no account. Three hazard rules govern everything here (`docs/PLAN.md`
section 5): the app never authors memories (verbatim transcript is the record, everything
derived is a confirm-before-file question); it prompts, it never assesses (standing
wellness-claims decision -- no memory scores, no MCI/dementia language, anywhere); a no-model mode is
mandatory for iPhones without Apple Intelligence.
