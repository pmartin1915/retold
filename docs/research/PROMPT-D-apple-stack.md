# Gemini Deep Research prompt — the Apple on-device stack for a voice-first memory app (iOS 26/27)

> **Paste everything between the rules into Gemini Deep Research.** Gemini doesn't have file access; the prompt is fully self-contained. Drop the report back beside this file as `deep-research-memory-recall-apple-stack-REPORT.md`; a Claude session adjudicates it into a synthesis.

---

## Background

I am a solo iOS developer with no Mac; I build native Swift apps with XcodeGen and ship
them from GitHub Actions macOS runners. I am designing an iPhone app where the user presses
the Action button, the app opens straight into voice recording, transcribes on-device,
and uses Apple's on-device language model to propose how to file the memory (life period,
approximate year as a question, place, people, a short paraphrase) and to generate
follow-up questions. Nothing may leave the device; there is no account and no server.
Target OS floor is iOS 26 (I would accept iOS 27 if it buys a lot).

Today is 2026-09-21. I need the real limits of the platform pieces, from Apple's own
documentation and WWDC sessions (2025 and 2026) plus developer reports, not marketing.

## What I need you to research

Answer each numbered question separately with dated sources. Mark High / Medium / Low
confidence. Say "unknown" rather than guess.

### 1. Foundation Models framework (on-device LLM)
- Availability: which devices (Apple Intelligence hardware), which regions and languages,
  what happens on unsupported devices (`SystemLanguageModel.default.availability` cases),
  and whether the user can have Apple Intelligence off while the app still works.
- Hard limits: context window in tokens, maximum output, whether a single
  `@Generable` response can be a nested struct with arrays (e.g. people: [Person],
  followUps: [String]), and how `@Guide` constraints behave.
- Behaviour on long inputs: what happens when a transcript exceeds the context; recommended
  chunking or summarise-then-extract patterns from Apple's sessions.
- Safety and refusal behaviour: what kinds of personal content the on-device model declines
  (grief, relationships, health mentions), the `guardrailViolation` error and how apps
  handle it, and whether Apple documents guardrail scope.
- Latency and battery on iPhone 15 Pro / 16 / 17 for a ~500-token structured extraction.
- iOS 27 changes: image attachments, `PrivateCloudComputeLanguageModel` (is it free to
  the developer and user? what leaves the device? does it change the privacy story?),
  tool-calling controls, session persistence.
- Whether `NLContextualEmbedding` / `NLEmbedding` sentence embeddings are usable offline
  for "similar memories", and their quality.

### 2. On-device speech: `SpeechAnalyzer` / `SpeechTranscriber`
- Supported languages and whether models download on first use (size, needs Wi-Fi?).
- Long-form behaviour: can it run for 10–20 minutes continuously; live partial results
  latency; punctuation and speaker labels; accuracy vs `SFSpeechRecognizer` and vs
  Whisper on conversational speech.
- Whether it can transcribe from a recorded file as well as a live stream, so audio is
  saved first and transcribed second (crash-safety).
- Any usage limits, entitlements, or privacy manifest / usage-description requirements.

### 3. The fastest path from Action button to recording
- The Action button → App Intent path: `openAppWhenRun`, whether an intent can start an
  `AVAudioSession` and recording *before* the UI appears, cold-start vs warm-start
  latency, and what Apple's Voice Memos does.
- Control Center and Lock Screen `ControlWidget` on iOS 18+ for the same intent; whether a
  control can start recording without unlocking, and the rules for microphone use from the
  Lock Screen.
- Background audio: what an app may do if the user locks the phone mid-recording;
  `UIBackgroundModes` audio; interruptions (calls, Siri).
- Apple Watch as a capture surface (a complication that starts a recording on the phone or
  records on the watch and hands off): feasibility and API.
- Whether the Camera Control button on iPhone 16+ can be assigned to third-party non-camera
  intents (I believe no — confirm).

### 4. Cue sources on the device
- **`JournalingSuggestions` framework** (iOS 17.2+): what a third-party app receives
  (photos, workouts, locations, contacts, reflection prompts), the entitlement and review
  process, whether it can ask for suggestions from a **specific past date range** or only
  recent activity, and what iOS 27 added.
- **PhotoKit**: fetching the user's photos by date range and location as period cues with
  limited-library access; on-device scene/people labels available to apps; performance.
- Contacts and Calendar as cue sources: what is reasonable to request, and what App Review
  expects for justification.

### 5. Storage, encryption, sync
- Data Protection classes for audio files and a SwiftData/SQLite store; what "encrypted at
  rest" actually means on iPhone and what a backup contains.
- CloudKit private database: what Apple can read with and without Advanced Data
  Protection; whether an app can *require* end-to-end encryption; the honest sentence a
  privacy policy can make in each case.
- Local-only alternatives for multi-device (e.g. peer transfer, encrypted export/import).
- Export formats other memory apps use and what users expect (Day One JSON, Markdown,
  audio files).

### 6. App Review and gating
- Rules for apps that gate features on Apple Intelligence: must the app work without it,
  how to describe the requirement on the listing, and whether "Requires iPhone 15 Pro or
  later" is allowed as a hard requirement.
- Microphone and speech usage-description strings and privacy-manifest declarations
  required for on-device-only speech.
- Any Apple guidance discouraging health or memory claims for apps using its models.

### 7. Sizing the fallback
- Share of active US iPhones that support Apple Intelligence as of mid-2026, so I can
  size the no-model mode.

## Output format

A report with one section per question, an executive summary of the eight platform facts
that most constrain the design, a table of every hard limit found (item, value, source,
date), and a "what I could not find" list. Prefer Apple documentation and WWDC 2025/2026
session transcripts; when citing a blog, say whether it measured or repeated.
