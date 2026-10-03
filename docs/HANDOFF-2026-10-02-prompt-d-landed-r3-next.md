# Handoff 2026-10-02 -- Retold: prompt D landed, R3 next

<!-- READ-FIRST:START -->
**State:** Prompt D (Apple-stack facts) finally ran on 10-02 as Waterwheel WW-0101 and is adopted. It is filed at docs/research/2026-10-03-retold-apple-stack-platform-facts-prompt-d.md (`1f35a19`), and ai/STATE.md is updated (`781e28d`). R1 and R2 are merged (`0b8f376`, `608fb54`). main is **3 commits ahead of origin and unpushed**.
**Next:** 1. Adjudicate prompt D against Sol's review (docs/reviews/PLAN-REVIEW-2026-09-21.md) into SYNTHESIS-2026-09-21.md §D. Fix any PLAN.md assumption it breaks, and tick the "Prompt D re-run" box in ai/STATE.md "What's Next". 2. R3: leading-question lint (PLAN §7) plus the wellness copy lint (§5.2), in CI. Write the spec first, then /orchestrate it the way R1 and R2 were done.
**Waiting on Perry:** OK to push the 3 local commits; the operator acts (App ID, profile, ASC record, secrets) before R6.
**In flight:** nothing.
**Traps:**
- Read ai/STATE.md first. The governing order is ../storycue/docs/STRATEGY-2026-09-22.md. R6 (the recorder) waits until after StoryCue's 10-16 submit.
- Before starting, run ListAgents. Another Retold session (`recall-c8`) may be live; coordinate with it rather than duplicate.
- Prompt D's weak spots: the Private Cloud Compute 32K-token figure and the App Store minimum-OS row rest on "industry analysis". Verify them at Apple's docs before PLAN relies on them.
- Kimi was 403 on its weekly quota as of 10-02, and Sol's quota reset at 22:37 on 10-02.
<!-- READ-FIRST:END -->

## Detail

### Prompt D: what landed (for the adjudication)
The report is about 42 KB, with 7 sections matching the brief's 7 questions, plus a limits table and a "could
not find" list. Its eight headline constraints:
1. The on-device model has a hard **4,096-token** limit covering prompt, input, schema and output, so a 10-20
   minute transcript needs map-reduce chunking.
2. **JournalingSuggestions** gives data only through the user-facing picker. There is no background query by
   date range.
3. SpeechAnalyzer/SpeechTranscriber have **no speaker diarization**, although duration is uncapped.
4. Guardrails cannot be configured. Expect `guardrailViolation` on grief, relationship and health content, and
   fall back to saving the raw transcript.
5. Starting a recording from the Action button while locked is restricted. Control Widgets and Live
   Activities are the workarounds, and they often need Face ID.
6. `@Generable` fills every property, so extra fields cost latency and battery.
7. Model availability can change at runtime (AI off, assets downloading, thermal), so a full no-model mode
   is required.
8. Crash-safe capture means recording to a file first, then transcribing that file.

The "could not find" list covers: latency and battery numbers, PCC quotas and privacy, Camera Control
assignment to an audio intent, whether NLContextualEmbedding works offline, and speech asset sizes and
whether they need Wi-Fi.

### How it ran
It ran in the waterwheel two-click flow: Claude set up the tab, and Perry clicked Send and Start research.
This time the Personal intelligence (Labs) toggle was flagged to Perry first, and whether he turned it off is
not recorded. The plan card said "I've put together a research plan" and the run completed at 9:27 PM CT. The
two parallel runs that evening cost about 15 Gemini window points each (research-waterwheel
data/limit-map.md, `3190a5c`).

### R3 pointers
PLAN.md §7 covers the question engine and leading-question rules; §5.2 covers the wellness copy rules. R1's
spec (docs/R1-DATAMODEL-SPEC.md) and the R2 PR are the pattern to follow. Write the spec, have Kimi or Sol
build it in a worktree, review it, and get CI green first run. A Kimi executor's tests tend to copy the
implementation, so name the exported functions and constants in the spec, then mutation-test.
