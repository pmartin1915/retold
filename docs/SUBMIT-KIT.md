# Retold 1.0 submit kit (draft)

_Drafted 2026-10-04 for the ~10-27 submit. Every claim below was checked against the code on
2026-10-04 (see §5). Copy follows PLAN §9: no word from the WellnessLint list (brain, sharpen,
improve memory, cognitive, dementia, therapy, treat, prevent and the rest), and the reflection
register only. Perry owns the final wording and the price._

## 1. Listing

| Field (limit) | Draft |
|---|---|
| App name (30) | `Retold: Life Stories, Spoken` (28 chars; "Your Life in Your Voice" was 31) |
| Subtitle (30) | `Talk through your memories` |
| Category | Lifestyle (primary), Productivity (secondary) |
| Price | Free (R7-SPEC §11: 1.0 ships free; the unlock is 1.1) |
| Age rating | 4+ (no objectionable content; the user records their own voice) |

**Promotional text (170):**

> Press a button, talk about a memory, and Retold keeps it: your voice, the words you said, and the
> next question to ask. Everything stays on your iPhone.

**Description:**

> Retold helps you keep the stories of your life, in your own voice.
>
> When a memory comes to you, press the Action button (or tap Record) and just talk. Retold records
> the audio and writes down what you said, word for word, right on your iPhone.
>
> **Your words, not a summary.** Retold never rewrites your story. Every title, name and place it
> suggests is taken from what you actually said, and nothing is filed until you confirm it.
>
> **The next question.** After each memory, Retold offers a few follow-up questions: who else was
> there, where you were, what came next. Answer one whenever you like, with another recording.
>
> **Your life, in order.** Browse your stories by period of life, by person, and by place. Each story
> shows its transcript and plays its recording.
>
> **Private by design.** No account. No server. No ads, no tracking. Recordings and transcripts never
> leave your iPhone unless you export them.
>
> **Always yours.** Export everything at any time (every recording, every transcript and an index)
> as a single zip you can keep or share.
>
> Suggested questions use Apple Intelligence on supported iPhones. Recording, filing and browsing work
> on every iPhone running iOS 26.

**Keywords (100):** `life story,memoir,journal,voice recorder,autobiography,family history,legacy,stories,storytelling`

**What's New (1.0):** first release.

## 2. App Privacy (the nutrition label)

- **Data collection: "No, we do not collect data from this app."** Retold has no server, no
  analytics, no crash reporter and no third-party SDK. Apple's definition of "collect" means
  transmitting data off the device in a way the developer or a third party can access, and nothing
  is transmitted.
- **Tracking: No.** `PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` to false and declares no
  tracking domains.

## 3. Review notes (for App Review)

> Retold records the user's own voice and transcribes it on device (SpeechAnalyzer). It has no
> account, no sign-in and no server, so no demo account is needed. To try it: tap Record, speak for
> a few seconds, tap Stop, then confirm the suggestions on the filing screen. On a device without
> Apple Intelligence, the filing screen still works without suggestions. The Action button can open
> straight to recording through the Retold control (Settings > Action Button > Controls).

## 4. Privacy policy and support pages (needed before submit)

Retold has no page yet on martinapps.dev (BoardBound, Shortless and Wilderness each have one). The
publishing needs Perry's go, because it is a public site. Proposed:
`martinapps-site/retold/privacy-policy.html` and `retold/support.html`, following Wilderness's
pattern.

Draft policy text:

> **Retold privacy policy**. Effective [date].
>
> Retold does not collect, store or share any personal information on any server. The app has no
> account, no server, no analytics and no advertising.
>
> **What stays on your iPhone.** Your recordings, their transcripts, and the titles, people, places
> and questions you confirm are stored only on your iPhone, protected by iOS Data Protection.
> Transcription runs on your iPhone. Suggestions use Apple Intelligence on your iPhone when it is
> available.
>
> **Microphone and speech.** Retold uses the microphone only while you are recording. Speech
> recognition runs on device.
>
> **Export.** If you export your library, the zip goes wherever you choose to send it from the share
> sheet. What happens to it then is up to you and the service you share it with. Recordings may
> mention other people, so share with care.
>
> **Deleting.** You can delete an unfiled recording in the app. Deleting the app deletes everything
> it stored.
>
> **Children.** Retold is not directed at children under 13 and collects no data from anyone.
>
> **Changes.** If this ever changes (for example, if a later version adds sync), this policy will be
> updated before that version ships.
>
> Contact: [support email].

## 5. Verified against the code (2026-10-04)

- **No network:** `Retold/` has no `URLSession`, no analytics and no crash SDK (grep).
- **On-device transcription:** `SpeechAnalyzer` and `SpeechTranscriber` (`LiveCaptureEngine.swift`,
  `AssetPrefetch.swift`).
- **Usage strings** (`project.yml`):
  - microphone: "Recordings stay on this phone.";
  - speech: "Turns your recording into text on this iPhone."
- **Privacy manifest:**
  - no tracking and no collected data types;
  - declared API reasons:
    - UserDefaults, `CA92.1`;
    - file timestamp, `C617.1`. This one was **added 2026-10-04 on PR #13**: `JournalImporter`
      reads an orphan audio file's `creationDate`, and the reason was missing.
- **Export** is never gated, matching PLAN §9.
- **Delete:** the unfiled-capture delete arrives with R7c (PR #13).

## 6. Still open (Perry)

1. The app name: is "Retold" available on the App Store? The full name above is a fallback.
2. The final icon (in progress in Gemini).
3. Screenshots: 6.9" iPhone, at least three, taken from the device sitting build.
4. A go to publish the privacy and support pages, plus the support email to show on them.
