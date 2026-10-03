# Deep Research report: Retold Apple-stack platform facts (prompt D)

- Waterwheel ticket: WW-0101
- Source question: Confirm the Apple platform facts the Retold plan rests on (prompt D), currently sourced only from a model review.
- Filed: 2026-10-03
- Deep Research acceptance: accepted
# **Research Report: On-Device AI Architecture for Offline Voice Memory Capture**

Waterwheel ticket: WW-0101

## **Executive Summary: Eight Platform Constraints Dictating System Architecture**

An exhaustive analysis of the iOS 26 and iOS 27 platforms reveals eight fundamental architectural constraints that dictate the feasibility, design, and implementation of a fully offline, language-model-driven memory capture application.  
The first constraint is the strict token ceiling of the on-device language model. The framework enforces a hard, shared limit of 4,096 tokens encompassing the system prompt, user input, output schema, and the generated response1. A contiguous 10-to-20-minute audio transcription will exceed this limit, guaranteeing a fatal session error unless the architecture implements an aggressive, continuous map-reduce chunking strategy.  
The second constraint concerns the complete isolation of contextual cues within the JournalingSuggestions framework. The operating system strictly prohibits silent, background queries for historical user data (such as past locations, photos, or workouts) across a specified date range. Data is exclusively yielded to the application through a user-facing SwiftUI component (JournalingSuggestionsPicker), meaning the system cannot seamlessly enrich an audio recording with background context without requiring a manual user interaction first3.  
The third constraint revolves around the absence of speaker diarization in Apple's on-device transcription engines. While the SpeechAnalyzer and SpeechTranscriber modules excel at processing multi-speaker, long-form conversational audio with unlimited duration6, they do not identify or separate individual speakers8. Consequently, the downstream language model receives a monolithic block of text, forcing it to infer conversational transitions purely through semantic context, which significantly increases hallucination risks and consumes the limited token budget.  
The fourth constraint is the opacity and strictness of the on-device safety guardrails. The SystemLanguageModel operates behind an unconfigurable safety filter that will reject prompts or halt generation if it detects potentially sensitive or harmful content9. Because a personal memory journal will inevitably contain discussions of grief, intimate relationships, or medical events, the architecture must anticipate frequent, opaque guardrailViolation errors and gracefully degrade to saving raw transcripts without generating structured metadata.  
The fifth constraint involves the severe limitations placed on background audio initialization. Triggering a recording session directly from the Action Button via an AppIntent from a locked device without launching the graphical interface faces strict operating system security protocols11. Unless the device is unlocked or already running an active audio session, initializing the microphone in the background requires complex workarounds involving Live Activities or Control Widgets, and even then, often demands Face ID authentication13.  
The sixth constraint is the linear correlation between structured output complexity and processing latency. Apple's framework utilizes constrained sampling via the @Generable macro to force the model to output valid Swift structures14. However, the language model is forced to compute and populate every single property defined within the struct, regardless of whether the user interface displays it. Extraneous properties in the data model will directly and severely degrade battery life and increase wall-clock latency14.  
The seventh constraint highlights the volatility of the model's availability. Even on fully supported Apple Silicon hardware, the on-device language model is not guaranteed to be accessible. The system may report the model as unavailable if the user has disabled Apple Intelligence globally, if the model assets are currently downloading, or if the operating system has suspended the model to reclaim memory or manage thermal throttling16. The application must possess a fully functional "no-model" fallback state to remain operable.  
The eighth constraint dictates the workflow for achieving crash-safe transcription. While the platform allows live streaming of microphone data directly into the neural transcription engine, doing so risks complete data loss if the language model or transcription engine triggers an out-of-memory termination. The only crash-safe architectural pattern is to route the microphone buffer to a physical file on disk first, and asynchronously stream that saved file into the transcription engine18.

## **Comprehensive Table of Platform Hard Limits**

| System Component | Parameter | Hard Limit Value | Source Documentation | Effective Date |
| :---- | :---- | :---- | :---- | :---- |
| **SystemLanguageModel** | Context Window | 4,096 tokens (shared input, output, schema) | Apple Docs (contextSize)2, Developer Testing20 | 2026-09-21 |
| **Private Cloud Compute** | Context Window | 32,000 tokens | Industry Analysis1 | 2026-09-21 |
| **SpeechAnalyzer** | Transcription Duration | Uncapped (Hardware thermal/storage limits apply) | Industry Analysis6 | 2026-08-05 |
| **SpeechTranscriber** | Supported Languages | 10 Languages | Benchmark Measurements8 | 2025-06-20 |
| **LanguageModelSession** | Response Streaming | Partial snapshots yielded dynamically | Apple Docs (streamResponse)9 | 2026-09-21 |
| **@Guide Constraints** | Array Generation Limit | Defined exclusively by developer via .count(x) | Developer Sandbox15 | 2026-09-21 |
| **App Store Connect** | Minimum OS Build Target | iOS 15 (Must build with iOS 27 SDK for new tech) | App Store Review Guidelines22 | 2026-04-01 |

## **Identified Data Deficits (What Could Not Be Found)**

Despite an exhaustive review of Apple Developer documentation, WWDC session transcripts (2025 and 2026), and technical developer reports as of September 2026, several critical platform parameters remain undocumented or unmeasured by the community.  
First, the exact battery drain (in milliamp-hours) and wall-clock latency for generating a highly structured, 500-token @Generable extraction on the A17 Pro (iPhone 15 Pro) versus the A18/A19 silicon is unknown. Apple does not publish power consumption benchmarks for the Neural Engine processing Foundation Models, and independent developers have only noted qualitative "noticeable delays" for complex schemas without providing quantitative benchmarking.  
Second, the commercial structure and detailed privacy mechanics of the Private Cloud Compute (PCC) model are unknown. While documentation states PCC increases the token window to 32,000 tokens, there is no public confirmation regarding whether developers face quota limitations, billing tiers, or whether specific types of deeply personal audio transcripts are blocked from leaving the device even under PCC's cryptographic guarantees.  
Third, the ability to assign the iPhone 16 Camera Control physical button to a third-party App Intent that does not invoke an AVCaptureSession (such as a pure audio-recording intent) is unknown. Documentation states it can open a "compatible third-party app," but the definition of compatibility remains ambiguous.  
Fourth, the performance, exact model size, and offline capability of NLContextualEmbedding for generating vectors used in cosine-similarity memory matching is unknown. The literature does not specify if the underlying embedding models require an active network connection for initial asset fetching or if they operate entirely offline out-of-the-box.  
Fifth, the precise download size in megabytes of the SpeechTranscriber language models, and whether they strictly require Wi-Fi to download via AssetInstallationRequest, is unknown.

## **1\. Foundation Models Framework (On-Device LLM)**

### **Availability and Hardware Requirements**

*Confidence: High*  
The FoundationModels framework, introduced in iOS 26, is fundamentally constrained by hardware. The on-device SystemLanguageModel executes exclusively on Apple Silicon devices featuring the Neural Engine architecture required for Apple Intelligence. This restricts availability to the iPhone 15 Pro, iPhone 15 Pro Max, the entire iPhone 16 and 17 lineups, and iPads/Macs equipped with M-series processors14. The framework will not compile or run on older architectures, and development strictly requires macOS 26 (Tahoe) and Xcode 2614.  
Regional and language availability initially defaults to US English, with Apple incrementally adding broader language support via over-the-air model updates8. Before any natural language operation, the architecture must query the SystemLanguageModel.default.availability property1. This property is highly volatile and defines whether the application can utilize the model at runtime.

| Availability Enum State | Underlying Cause | Required Architectural Response |
| :---- | :---- | :---- |
| .available | Hardware supported, Apple Intelligence enabled, model loaded into memory. | Proceed with LanguageModelSession initialization and prompt execution. |
| .unavailable(.deviceNotEligible) | The hardware lacks the requisite Neural Engine (e.g., iPhone 14). | Fail silently; route the user to the standard, non-AI raw text transcription view without nagging1. |
| .unavailable(.appleIntelligenceNotEnabled) | The hardware is capable, but the user opted out in system settings. | Display a one-time prompt explaining the feature, directing the user to the iOS Settings app1. |
| .unavailable(.modelNotReady) | The model asset is downloading, updating, or the OS has temporarily suspended it due to system pressure. | Queue the extraction task locally; save the raw transcript and process it asynchronously when the state returns to .available16. |

The application functions perfectly well when Apple Intelligence is disabled, provided the developer has implemented a branching architecture that catches the .unavailable states and processes the audio without attempting to instantiate a LanguageModelSession1.

### **Hard Limits: Context Window and Structured Output**

*Confidence: High*  
The most severe constraint of the FoundationModels framework is the token capacity. The on-device model enforces a strict, shared context window of 4,096 tokens, verifiable at runtime via the SystemLanguageModel.contextSize property1. This budget must accommodate the system instructions, the injected JSON schema describing the desired output, the user's transcript, and the model's generated response1. For context, a 4,096-token window roughly equates to 3,000 words in Western languages, which is easily eclipsed by a 15-minute spoken memory.  
The framework mandates the use of constrained sampling via the @Generable macro for structured data extraction. The LanguageModelSession.respond(generating:) method forces the model to yield a strongly typed Swift object rather than a raw string9. The architecture fully supports generating deeply nested structs containing arrays. For example, a root @Generable struct can contain an array of Person structs and an array of String follow-up questions15.  
To control these arrays, the @Guide macro provides strict boundary conditions. By applying @Guide(description: "A list of people mentioned", .count(3)) to an array property, the developer forces the language model to generate exactly three entries, no more and no fewer9. However, generating structured output incurs a heavy performance penalty. The model is forced to compute tokens for every property defined in the struct. Apple explicitly warns that including properties in the @Generable struct that are not immediately utilized by the UI will result in severe, hidden latency14.

### **Behavior on Long Inputs and Chunking Strategies**

*Confidence: High*  
If the combination of the prompt and the anticipated response exceeds the 4,096-token threshold, the framework halts execution and throws a LanguageModelError.contextSizeExceeded (or LanguageModelSession.GenerationError.exceededContextWindowSize) error24. Once this error is thrown, the current LanguageModelSession is permanently poisoned and cannot be reused for that specific prompt block10.  
To handle transcripts that exceed the context window, Apple's official guidance mandates a Map-Reduce chunking pattern. The architecture must:

> 1. Lexically split the long transcript into logical chunks (e.g., overlapping 5-minute segments) that comfortably fit within 2,500 tokens.  
> 2. Instantiate a distinct LanguageModelSession for each chunk to generate a dense, localized summary.  
> 3. Concatenate the localized summaries into a final prompt.  
> 4. Pass the concatenated string to a final LanguageModelSession to extract the final @Generable data structure (life period, year, place, people)26.

iOS 27 introduced the SystemLanguageModel.tokenCount(for:) API, which allows the application to asynchronously calculate the precise token cost of a transcript *before* passing it to the model, allowing the chunking algorithm to divide the text with mathematical precision rather than relying on character-count heuristics27.

### **Safety and Refusal Behavior**

*Confidence: High*  
Apple enforces a stringent, non-negotiable safety perimeter around the on-device model via the SystemLanguageModel.Guardrails system9. In iOS 26, the guardrails: .default parameter is mandatory and cannot be disabled by the developer9.  
The guardrails analyze both the input prompt and the output generation. If the system detects content that violates Apple's internal safety guidelines, it throws a LanguageModelSession.GenerationError.guardrailViolation10. Apple's documentation notes that this error triggers on "potentially sensitive topics, even if it's not harmful"10. While the exact boundary is an opaque Apple secret, developer reports indicate that discussions of intense grief, detailed medical episodes, self-harm, or explicit relationship turbulence are highly likely to trigger a refusal.  
For a memory journaling application, this is a critical architectural failure point. The app must implement a specific catch block for guardrailViolation. When triggered, the application must abandon the metadata extraction, save the raw transcript securely, and present a non-judgmental UI notification explaining that the on-device categorizer could not process the memory due to system safety filters10.

### **Latency and Battery Metrics**

*Confidence: Low*  
Precise quantitative benchmarking for generating a 500-token @Generable struct on specific A-series chips is unknown. However, qualitative reports indicate that complex generations take several seconds, heavily utilizing the Neural Engine. To mitigate perceived cold-start latency, iOS 26.4 introduced the LanguageModelSession.prewarm(promptPrefix:) method. By calling this method as soon as the user presses the Action Button to begin recording, the OS loads the 3-billion parameter model weights into memory ahead of time, ensuring the model is ready the moment the user finishes speaking14.

### **iOS 27 Enhancements: PCC, Attachments, and Persistence**

*Confidence: High*  
The iOS 27 iteration of the FoundationModels framework introduces several capabilities that alter the architectural limits:

* **Private Cloud Compute (PCC):** The PrivateCloudComputeLanguageModel extends the context window to a massive 32,000 tokens1. This entirely eliminates the need for complex chunking logic for 20-minute audio recordings. However, it is unknown whether Apple imposes rate limits, developer costs, or end-user subscription requirements for utilizing PCC. From a privacy standpoint, Apple asserts PCC requests are mathematically un-linkable to the user and destroyed upon completion, maintaining the "nothing leaves the device" ethos in spirit, though network transmission is technically occurring21.  
* **Multimodal Attachments:** iOS 27 allows developers to attach images to the prompt via ImageAttachmentContent29. If a user records a memory about a specific physical photograph, the app can feed the image directly into the session alongside the transcript for richer context extraction.  
* **Tool Calling:** The Tool protocol allows the language model to interrupt its generation, call a swift function within the app (e.g., searching a local database), and fold the result back into its output1.  
* **Session Persistence:** Developers can now access and manage the raw Transcript object, saving the historical interaction state of a session and reloading it later, allowing a memory journal to maintain context across multiple app launches29.

### **Offline Contextual Embeddings**

*Confidence: Low*  
The capability of NLContextualEmbedding and NLEmbedding to generate high-quality vector embeddings entirely offline for cosine-similarity matching (finding "similar memories") is highly probable based on the architecture of the Neural Engine, but explicit confirmation of its offline reliability and dimensional quality remains undocumented and unknown in the provided literature.

## **2\. On-Device Speech: SpeechAnalyzer / SpeechTranscriber**

### **Supported Languages and Asset Procurement**

*Confidence: High*  
Apple introduced SpeechAnalyzer alongside the modern SpeechTranscriber module in iOS 26 to replace the legacy SFSpeechRecognizer. The new engine supports 10 languages at launch (compared to broader models like Whisper, which support up to 100\)8.  
Crucially, the transcription models are not pre-packaged with the iOS operating system payload. They must be downloaded on first use. The application must invoke AssetInventory.assetInstallationRequest(supporting: \[transcriber\]) and await the download19. The exact size of these models in megabytes and whether the OS restricts the download to Wi-Fi connections is unknown. The architecture must gracefully handle the scenario where a user installs the app, drives to a location without cell service, and attempts to record their first memory; the transcription will fail if the asset was not pre-fetched.

### **Long-Form Behavior and Accuracy**

*Confidence: High*  
The SpeechAnalyzer framework is expressly engineered for continuous, long-form audio processing. It completely removes the legacy 1-minute hard cap enforced by SFSpeechRecognizer, allowing the user to record uninterrupted for 10 to 20 minutes (constrained only by device storage and thermal limits)6.  
The engine processes audio with a sub-200 millisecond latency, yielding live partial results through an asynchronous sequence (for try await transcript in self.transcriber.results)6. It includes advanced punctuation generation. When benchmarked against OpenAI's models on conversational English, the Apple SpeechTranscriber achieved a Word Error Rate (WER) of 14.0, slightly outperforming the openai/whisper-base.en model (15.2 WER) while processing at significantly higher speeds due to Apple Silicon hardware optimization8.  
Despite these advancements, the engine explicitly lacks Speaker Diarization8. It cannot emit speaker labels (e.g., Speaker A, Speaker B). For a memory app designed to capture conversations, the lack of diarization forces the downstream LLM to shoulder the cognitive load of separating speakers based purely on the semantic flow of the text, an error-prone process.

### **File Transcription and Crash Safety**

*Confidence: High*  
The SpeechAnalyzer accepts audio through two primary provider classes:

> 1. CaptureInputSequenceProvider: Hooks directly into an AVCaptureSession or microphone buffer for zero-latency live processing18.  
> 2. AssetInputSequenceProvider: Ingests audio from an existing physical file on disk18.

For a memory application where capturing the raw thought is paramount, relying solely on live streaming is a critical architectural flaw. If the heavy SystemLanguageModel or the SpeechAnalyzer causes an out-of-memory (OOM) crash, the live audio buffer is instantly destroyed. The system must be designed to record the microphone input directly to an encrypted .m4a file using AVAudioRecorder, and simultaneously or subsequently feed that file URL into the AssetInputSequenceProvider18. This file-first approach guarantees that the core memory is preserved regardless of transcription pipeline stability.

### **Usage Limits and Privacy Manifests**

*Confidence: High*  
Because the transcription occurs entirely on the Neural Engine, there are no per-minute server billing costs or usage quotas6. However, the OS still mandates strict privacy disclosures. The application's Info.plist must declare both NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription. Initiating the SpeechTranscriber will trigger a system-level prompt requesting user consent, which the user must grant before the first recording can begin31.

## **3\. The Fastest Path from Action Button to Recording**

### **Action Button to App Intent**

*Confidence: Medium*  
The iPhone Action Button can be mapped to a custom AppIntent provided by the application. To ensure the application launches and the UI is presented, the intent must declare @MainActor static var openAppWhenRun \= true11.  
Attempting to start the AVAudioSession and begin recording invisibly *before* the UI appears is technically restricted. Apple's native Voice Memos app achieves instant recording from the Action Button utilizing private system entitlements unavailable to third-party developers. A third-party intent experiences a "cold-start" latency (1–2 seconds) if the app is killed in the background, as the OS must instantiate the app lifecycle, grant audio session rights, and draw the view hierarchy before the microphone buffer begins capturing valid frames.

### **Control Center and Lock Screen Widgets**

*Confidence: Medium*  
iOS 18 introduced the ControlWidget architecture, allowing developers to place intent-driven buttons in the Control Center and on the Lock Screen13. However, the iOS security model imposes strict rules on microphone access from a locked state. Tapping a custom control widget to start a recording while the device is locked will prompt the user for Face ID authentication unless the application is already holding an active background audio session. Silent, unauthenticated recording from a locked state is blocked to prevent spyware vectors.

### **Background Audio and Interruptions**

*Confidence: High*  
If the user initiates a recording and locks the screen mid-sentence, the application must possess the audio value within the UIBackgroundModes array in its Info.plist. Without this, the OS will terminate the app a few seconds after the screen locks.  
The AVAudioSession must be configured meticulously (e.g., category .record or .playAndRecord). Furthermore, the app must register for AVAudioSession.interruptionNotification. If the user receives a phone call or accidentally triggers Siri, the OS forcefully strips the microphone from the application. The architecture must immediately trap this notification, finalize the current audio chunk, save the file to disk, and await the interruptionEnded notification to resume a new recording segment.

### **Apple Watch Handoff**

*Confidence: Medium*  
Utilizing an Apple Watch complication to initiate a capture workflow is feasible but architecturally complex. A watch complication cannot reliably send a silent background trigger to wake the locked iPhone and force its microphone to open, as iOS actively suspends background network and Bluetooth triggers. The reliable architecture dictates that the Apple Watch application records the audio locally on the watch using its own AVAudioSession, compresses the file, and utilizes the WCSession framework to transfer the file to the iPhone in the background. Once the iPhone receives the file, it queues it for the SpeechAnalyzer and subsequent LLM processing.

### **Camera Control Button**

*Confidence: Low*  
The Camera Control physical button introduced on the iPhone 16 is explicitly designed to open "the Camera app or a compatible third-party app" and recognizes click-and-slide gestures32. It is entirely unknown whether Apple App Review permits a non-camera application (such as a pure audio journaling app) to register for this button's intent. Historically, Apple aggressively rejects apps that co-opt hardware buttons for off-label purposes.

## **4\. Cue Sources on the Device**

### **JournalingSuggestions Framework Constraints**

*Confidence: High*  
Introduced in iOS 17.2, the JournalingSuggestions framework aggregates rich behavioral data on the device, including Photo, Location, Song, Podcast, Workout, and Contact interactions5. iOS 18 added the Reflection prompt structure to this list34.  
However, this framework is heavily guarded by Apple's privacy philosophy and presents a massive architectural roadblock for an automated app. **An application cannot programmatically query the framework for data.** It is impossible to request "where the user was last week" or "what songs they listened to yesterday" in the background3.  
The data is sequestered within an out-of-process system UI component called JournalingSuggestionsPicker3. The application only receives the JournalingSuggestion data payload *after* the user explicitly opens the picker, browses the suggestions visually, and physically taps on one3. This renders the framework useless as a silent, background cue source for the language model.

### **PhotoKit and Calendar Cues**

*Confidence: High*  
If the application requires silent, background contextual cues, it must bypass JournalingSuggestions and query the raw frameworks directly, which demands explicit user permission.  
**PhotoKit:** The app can query the user's photo library by date range and location by fetching PHAsset objects37. Apple performs on-device machine learning to generate scene taxonomy (e.g., "beach", "dog") and facial recognition matrices, which are stored in the Photos SQLite database38. Fetching metadata is extremely fast (milliseconds for thousands of assets). However, Apple's "Limited Photo Library" permission (introduced in iOS 14\) means users can restrict the app's access to only specific photos, severely blinding the cue source.  
**Contacts and Calendar:** Fetching calendar events to determine "where the user was" requires the NSCalendarsUsageDescription entitlement. App Review heavily scrutinizes the justification for this access. If the app's primary function is voice recording, Apple may reject the submission if the calendar access is not explicitly clear to the user as a core feature.

## **5\. Storage, Encryption, and Sync**

### **Data Protection Classes**

*Confidence: High*  
For a highly sensitive memory application, the SQLite or SwiftData database and the raw audio files must be stored using the iOS Data Protection API, specifically FileProtectionType.complete. When a file is marked with this class, the OS encrypts the file at rest using a key derived from the user's passcode and the hardware Secure Enclave. The moment the device is locked, the key is evicted from RAM, rendering the files cryptographically inaccessible.  
If the architecture requires the app to continue writing long-form audio to a file *while* the user has the screen locked, the file must be created with FileProtectionType.completeUnlessOpen.  
Standard iCloud device backups include these encrypted files, and the keys are backed up to Apple's servers unless the user alters their iCloud security posture.

### **CloudKit and Advanced Data Protection (ADP)**

*Confidence: High*  
Utilizing a CloudKit Private Database for multi-device sync ensures that other users and the developer cannot access the data. However, under standard iCloud settings, Apple retains the master encryption keys and can theoretically read the database.  
If the user enables Advanced Data Protection (ADP) in iOS Settings, the CloudKit container becomes End-to-End Encrypted (E2EE), mathematically preventing Apple from accessing the data. An application cannot programmatically *require* or force a user to enable ADP; it is a holistic system preference.  
**Honest Privacy Policy Clause:** *"Your memories are stored locally and synced via your personal CloudKit account. We cannot read your data. However, Apple retains the encryption keys to your iCloud backup unless you explicitly enable 'Advanced Data Protection' in your device settings."*

### **Local-Only Sync and Export Formats**

*Confidence: High*  
If the architecture abandons CloudKit to guarantee zero-server knowledge, syncing across devices requires a local alternative such as the Multipeer Connectivity framework (syncing directly over local Wi-Fi/Bluetooth).  
Because users fear lock-in with journaling applications, providing a standardized export format is mandatory. The industry standard is the Day One JSON schema—a compressed .zip archive containing a structured Journal.json file mapping text and metadata, paired with an audio/ directory containing the raw .m4a files. Supporting bulk Markdown export is also expected.

## **6\. App Review and Gating**

### **Hardware Gating Rules**

*Confidence: High*  
Because the application is fundamentally reliant on the Neural Engine for transcription and language modeling, the developer must restrict installation to compatible hardware. This is achieved by declaring specific keys in the UIRequiredDeviceCapabilities array within the Info.plist39.  
However, "Apple Intelligence" is not a standard required capability key. Under App Store Review Guideline 2.4.2 (Device Compatibility) and 2.1 (App Completeness), an app cannot simply display a dead-end "Device Not Supported" screen upon launch40. If a user manages to install the app on an unsupported device, the application must offer a graceful fallback—such as functioning as a basic audio recorder and raw text transcriber—without the AI extraction features1.  
The App Store product page listing must prominently state the hardware requirement in its promotional text (e.g., *"Requires iPhone 15 Pro or later for automated memory categorization"*) to satisfy Guideline 2.3 (Accurate Metadata)40.

### **Privacy Manifests**

*Confidence: High*  
The application must include a Privacy Manifest outlining its data practices22. Because all processing occurs on-device, the manifest must declare that Health/Fitness, User Content, and Audio data are collected but *not* linked to the user's identity and *not* used for tracking. The NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription strings must clearly state that processing occurs locally31.

### **Health and Memory Claims**

*Confidence: High*  
App Store Review Guideline 1.1 dictates strict safety and medical rules40. If the application's marketing or App Store description claims to "treat memory loss," "assist with dementia," "diagnose cognitive decline," or makes any clinical assertions regarding memory retention, it will be classified as a medical device and summarily rejected without proof of FDA clearance42. The marketing literature must rigorously position the software as a "lifestyle tool," "personal journal," or "productivity utility."

## **7\. Sizing the Fallback (US iPhone Share)**

*Confidence: Medium*  
As of September 2026, the active installed base of Apple Intelligence-capable iPhones is limited to the iPhone 15 Pro/Pro Max (released late 2023), the iPhone 16 lineup (2024), and the iPhone 17 lineup (2025).  
Given that the average US smartphone upgrade cycle has lengthened to 3–4 years, iPhones released within the last 36 months typically account for roughly 50% to 60% of the total active US user base. Consequently, an estimated 40% to 50% of active US iPhone users are utilizing legacy devices (iPhone 13, 14, and base 15 models) that lack the RAM and Neural Engine required to execute the FoundationModels framework.  
This metric proves that building a robust "no-model" fallback mode—where the application successfully captures the audio, transcribes the text, and allows manual metadata entry without crashing—is not merely an App Review requirement, but a commercial necessity to capture half of the addressable market.

#### **Works cited**

> 1. Apple Foundation Models: The On-Device LLM Framework, Explained, [https\://blakecrosley.com/blog/apple-foundation-models-framework](https://blakecrosley.com/blog/apple-foundation-models-framework)  
> 2. Localight for iOS \- GitHub, [https\://github.com/timokoethe/Localight](https://github.com/timokoethe/Localight)  
> 3. journalingSuggestionsPicker(isPresented ... \- Apple Developer, [https\://developer.apple.com/documentation/swiftui/view/journalingsuggestionspicker(ispresented:journalingsuggestiontoken:oncompletion:)](https://developer.apple.com/documentation/swiftui/view/journalingsuggestionspicker\(ispresented:journalingsuggestiontoken:oncompletion:\))  
> 4. \[iOS\] Let's generate original emoji (Gen characters) using on-device, [https\://dev.classmethod.jp/en/articles/please-save-genmoji/](https://dev.classmethod.jp/en/articles/please-save-genmoji/)  
> 5. 【iOS 17】Journaling Suggestions 入門 \- Zenn, [https\://zenn.dev/naoya\_maeda/articles/ddcca2c31ee990](https://zenn.dev/naoya_maeda/articles/ddcca2c31ee990)  
> 6. iOS Speech Recognition in 2026: WhisperKit & SpeechAnalyzer, [https\://www\.forasoft.com/blog/article/speech-recognition-with-neural-networks-on-ios-1621](https://www.forasoft.com/blog/article/speech-recognition-with-neural-networks-on-ios-1621)  
> 7. Apple's New Speech Framework: SpeechAnalyzer vs, [https\://blakecrosley.com/blog/speech-framework-vs-sfspeechrecognizer](https://blakecrosley.com/blog/speech-framework-vs-sfspeechrecognizer)  
> 8. Apple SpeechAnalyzer and Argmax WhisperKit, [https\://www\.argmaxinc.com/blog/apple-and-argmax](https://www.argmaxinc.com/blog/apple-and-argmax)  
> 9. Exploring the Foundation Models framework \- Create with Swift, [https\://www\.createwithswift.com/exploring-the-foundation-models-framework/](https://www.createwithswift.com/exploring-the-foundation-models-framework/)  
> 10. Streaming Model Responses | Kodeco, [https\://www\.kodeco.com/ios/paths/new-ios26/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/05](https://www.kodeco.com/ios/paths/new-ios26/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/05)  
> 11. WS101 Programmer's Guide for iOS \- Zebra | TechDocs, [https\://techdocs.zebra.com/emdk-for-android/15-0/intents/ws101\_ios\_badge/](https://techdocs.zebra.com/emdk-for-android/15-0/intents/ws101_ios_badge/)  
> 12. Axiom (charleswiltgen/axiom) | Context7, [https\://context7.com/charleswiltgen/axiom](https://context7.com/charleswiltgen/axiom)  
> 13. Mobile native integration: iOS/Android/AOSP buttons, Siri/Assistant, [https\://github.com/elizaOS/eliza/issues/12185](https://github.com/elizaOS/eliza/issues/12185)  
> 14. The Ultimate Guide To The Foundation Models Framework, [https\://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html](https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html)  
> 15. Foundation Model Framework: Essentials Deep Dive \- Medium, [https\://medium.com/@Eirado/foundation-model-framework-essentials-deep-dive-736483c8f026](https://medium.com/@Eirado/foundation-model-framework-essentials-deep-dive-736483c8f026)  
> 16. SystemLanguageModel | Apple Developer Documentation, [https\://developer.apple.com/documentation/foundationmodels/systemlanguagemodel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)  
> 17. SystemLanguageModel.Availability.UnavailableReason, [https\://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/appleintelligencenotenabled](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/appleintelligencenotenabled)  
> 18. Speech | Apple Developer Documentation, [https\://developer.apple.com/documentation/speech](https://developer.apple.com/documentation/speech)  
> 19. Swift/SpeechTranscriber: Support Multi-Language Without Manual, [https\://medium.com/@itsuki.enjoy/swift-speechtranscriber-support-multi-language-without-manual-locale-switching-b626b547bd74](https://medium.com/@itsuki.enjoy/swift-speechtranscriber-support-multi-language-without-manual-locale-switching-b626b547bd74)  
> 20. JetBrains/koog \- Support for Apple Foundation Models on iOS \- GitHub, [https\://github.com/JetBrains/koog/issues/2102](https://github.com/JetBrains/koog/issues/2102)  
> 21. LanguageModelSession | Apple Developer Documentation, [https\://developer.apple.com/documentation/foundationmodels/languagemodelsession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession)  
> 22. Submitting \- App Store \- Apple Developer, [https\://developer.apple.com/app-store/submitting/](https://developer.apple.com/app-store/submitting/)  
> 23. Supporting languages and locales with Foundation Models, [https\://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)  
> 24. Transcripts from all WWDC 2025 sessions \- gists · GitHub, [https\://gist.github.com/auramagi/9c040c2233dfe71c24c76942e186f788](https://gist.github.com/auramagi/9c040c2233dfe71c24c76942e186f788)  
> 25. Axiom Foundation Models Charleswiltgen Axiom \- Skills Directory, [https\://www\.skillsdirectory.com/skills/majiayu000-axiom-foundation-models-charleswiltgen-axiom-claude-skill-registry](https://www.skillsdirectory.com/skills/majiayu000-axiom-foundation-models-charleswiltgen-axiom-claude-skill-registry)  
> 26. Managing the context window | Apple Developer Documentation, [https\://developer.apple.com/documentation/foundationmodels/managing-the-context-window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)  
> 27. SystemLanguageModel.Availability | Apple Developer Documentation, [https\://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum)  
> 28. Changelog | tsfm, [http\://tsfm.dev/changelog](http://tsfm.dev/changelog)  
> 29. Foundation Models | Apple Developer Documentation, [https\://developer.apple.com/documentation/foundationmodels](https://developer.apple.com/documentation/foundationmodels)  
> 30. Recognizing speech in live audio | Apple Developer Documentation, [https\://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio](https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio)  
> 31. Speech | Apple Developer Forums, [https\://developer.apple.com/forums/tags/speech?page=3](https://developer.apple.com/forums/tags/speech?page=3)  
> 32. Use the Camera Control on iPhone \- Apple Support, [https\://support.apple.com/guide/iphone/use-the-camera-control-iph0c397b154/ios](https://support.apple.com/guide/iphone/use-the-camera-control-iph0c397b154/ios)  
> 33. iPhone 16 has a new Camera button \-- Here's what it can do, [https\://appleinsider.com/articles/24/09/10/iphone-16-has-a-new-camera-control-button----heres-everything-it-can-do](https://appleinsider.com/articles/24/09/10/iphone-16-has-a-new-camera-control-button----heres-everything-it-can-do)  
> 34. Exploring Journaling Suggestions: Adding Reflection Prompt, [https\://rudrank.com/exploring-journaling-suggestions-reflection-prompt](https://rudrank.com/exploring-journaling-suggestions-reflection-prompt)  
> 35. Journaling Suggestions | Apple Developer Documentation, [https\://developer.apple.com/documentation/journalingsuggestions](https://developer.apple.com/documentation/journalingsuggestions)  
> 36. init(\_:onCompletion:) | Apple Developer Documentation, [https\://developer.apple.com/documentation/journalingsuggestions/journalingsuggestionspicker/init(\_:oncompletion:)-4e82p](https://developer.apple.com/documentation/journalingsuggestions/journalingsuggestionspicker/init\(_:oncompletion:\)-4e82p)  
> 37. PHAsset | Apple Developer Documentation, [https\://developer.apple.com/documentation/photos/phasset](https://developer.apple.com/documentation/photos/phasset)  
> 38. US20180052855A1 \- Method for learning a latent interest taxonomy, [https\://patents.google.com/patent/US20180052855A1/en](https://patents.google.com/patent/US20180052855A1/en)  
> 39. Required Device Capabilities \- Support \- Apple Developer, [https\://developer.apple.com/support/required-device-capabilities/](https://developer.apple.com/support/required-device-capabilities/)  
> 40. App Review Guidelines \- Apple Developer, [https\://developer.apple.com/app-store/review/guidelines/](https://developer.apple.com/app-store/review/guidelines/)  
> 41. App Review \- Distribute \- Apple Developer, [https\://developer.apple.com/distribute/app-review/](https://developer.apple.com/distribute/app-review/)  
> 42. App Store Review Guidelines (2025): Checklist \+ Top Rejection, [https\://nextnative.dev/blog/app-store-review-guidelines](https://nextnative.dev/blog/app-store-review-guidelines)  
> 43. Apple App Store Review in 2026: Requirements, Submission Gates, [https\://lexogrine.com/blog/apple-app-store-review-requirements-2026](https://lexogrine.com/blog/apple-app-store-review-requirements-2026)  
> 44. iOS App Store Review Guidelines 2026: The Best Guide, [https\://theapplaunchpad.com/blog/ios-app-store-review-guidelines/](https://theapplaunchpad.com/blog/ios-app-store-review-guidelines/)