# comeup packet: Retold, run 2 (2026-11-09)

Plain ASCII. Second pass. Perry, 2026-11-09: "it worked mostly but was janky and definitely needs a comeup."
Run 1 (2026-11-04) merged PRs #21-#24 to main: state clarity (clock counts recording time only, Getting
ready state, save-failure alert), motion and haptics (screen fades off under Reduce Motion, recorder and
playback haptics), accessibility (scrubber label/value, labelled gear and trash, 44 pt targets, VoiceOver
announcements), performance (single-pass first capture). Deferred from run 1: visual system / colour tokens,
Dynamic Type row layout, HomeView try? attachPending discards errors, startup failure has no Retry, empty
Home shows empty sections, export fetch on the main actor, raw error text in the start-failure alert.

Scope this run: JANK and INTERFACE ELEVATION. Perry's 2026-11-03 note: "Retold looks like a notes page.
Raise it to the Burn Wizard benchmark." Retold is SwiftUI (iOS 26 SDK, Liquid Glass era). The veterans are
web/Expo (burn-wizard: React + Capacitor; BoardBound: Expo React Native), so cite the veteran's PATTERN
(file:line) and translate it to SwiftUI; do not ask Retold to adopt web code.
Dimension 9 (Android parity) is N/A: Retold is iOS only.
Out of scope: store listings, billing, the 1.0 build in review, the transcription/filing pipeline logic,
Rule 1 (the app never rewrites the user's words).


## Rubric (rubric.md, in full)
# comeup rubric (score each dimension 0-4: 0 broken, 2 acceptable, 4 matches the veteran bar)

Every finding must carry: file:line in the TARGET, the veteran file:line that does it right, evidence
(quoted code, or a fetched Apple doc URL), severity (blocker / should / polish), and a concrete fix.
No finding without a quote that exists in the packet. If you cannot cite it, do not report it.

1. **Motion and fluidity.** Transitions, spring animations, matched geometry, haptics on meaningful actions, no dead taps, no layout jumps, Reduce Motion respected.
2. **State clarity.** Every screen shows loading, saving, empty, success and error. Buttons disable while work is in flight. No silent failure. Single-flight on taps that start work.
3. **Input and recording robustness.** Interruptions (call, route change, backgrounding), permissions denied or revoked, low storage, rapid repeated taps, resume after kill.
4. **Accessibility.** Dynamic Type through the largest sizes, VoiceOver labels/hints/order, contrast (HOUSE-STYLE numbers), hit targets >= 44 pt, Reduce Motion and Bold Text.
5. **Visual system.** HOUSE-STYLE rules 1-26: palette tokens, mark use, spacing, type scale, no off-brand one-offs.
6. **Performance.** Cold launch, first-frame work on the main thread, scroll cost of long lists, image and audio memory.
7. **Copy.** Plain, specific, consistent voice; error text says what happened and what to do; no jargon.
8. **Layout resilience.** iPhone sizes and the foldable-hazard list in APPLE-IPHONE-DUO-PREP (UIScreen.main, portrait lock, full-screen flags).
9. **Android parity (Play apps only).** Same flows on the Android build: back gesture/button behaviour, system bars and edge-to-edge insets, Material touch targets (48 dp), font scale to 200%, TalkBack labels, no iOS-only affordance left dead (swipe-back, haptics silently missing), and the Android screenshot matches the iOS one in state and copy. Score N/A for iOS-only apps.

Output a score table first, then findings ordered blocker -> polish.


## Reviewer instructions
# Reviewer prompt (identical for Sonnet, Kimi, Sol; ASCII only)

You are doing QA on a newer iPhone app so it can match the polish of the same author's older apps.
You are one of three independent reviewers. You will not see the others' work.

Below are: the rubric, the target app's source excerpts, and the veteran apps' counterparts.
Use ONLY what is in this packet. Do not invent files, lines or quotes. If a screen is not in the packet, say "not in packet".

Task: score each rubric dimension 0-4, then list findings in this exact shape:

FINDING <n>
- dimension: <1-8>
- severity: blocker | should | polish
- target: <path>:<line>  quote: "<exact text from the packet>"
- veteran counterpart: <path>:<line>  quote: "<exact text>"
- evidence: <quote from a fetched Apple doc with URL, or the failure you can show from the code>
- fix: <concrete change, 1-4 sentences>

Rules: prefer 8-15 strong findings over 40 weak ones. Say what the target already does well in two lines at the end.
Do not propose new features. Do not touch store listings, billing or clinical content.

ADDED FOR THIS RUN (Perry 2026-11-09): after your findings, list up to 5 VETERAN FEATURES WORTH BORROWING
(things BoardBound or burn-wizard do that Retold lacks and would feel better with). Each: name, the
veteran file:line from this packet, what it would look like in Retold in one sentence, effort S/M/L.
This list is the one exception to "do not propose new features"; Perry picks from it.


## Measured probes (counted by Opus 2026-11-09; reviewers do not re-argue these)

| # | Probe | Result | Score 0-3 |
|---|---|---|---|
| M1 | CI on PRs | build.yml last 20 runs: 14 success, 1 failure, 5 cancelled (superseded). main is NOT branch-protected (no required checks); PR-only discipline is by convention | 2 |
| M2 | Test floor | 41 files in RetoldTests (unit, incl. CaptureCoordinatorTests 706 lines), 1 UI test file (ScreenshotTests). No coverage threshold anywhere | 2 |
| M3 | Release gate | docs/SUBMIT-KIT.md runbook; deploy.yml is workflow_dispatch/tag only; no preflight script | 1 |
| M4 | Crash reporting | none (no Sentry, Crashlytics or MetricKit subscriber) | 0 |
| M5 | Failure UX | 7 .alert( sites (HomeView 3, OfferRow 2, PeriodsView 1, SetAsideView 1); playback failures are silent by design (AudioPlayback.swift:28-29 comment "stops quietly: no alert") | 2 |
| M6 | Accessibility | 5 accessibilityLabel/Hint call sites in Retold/; no Dynamic Type, contrast or a11y audit test in CI | 1 |
| M7 | Fluidity baseline | no XCTApplicationLaunchMetric, XCTHitchMetric or MetricKit; cold launch and hitches UNMEASURED | 0 |
| M8 | Harness | screenshots.yml + RetoldUITests drives home -> recorder -> story -> browse -> confirm in demo mode on 6.5" and 6.9" simulators; PR #26 adds label assertions; no mutation check yet | 2 |
| M9 | Docs spine | ai/STATE.md current (2026-11-04/09), ai/IDEAS.md; NO ai/DECISIONS.md, NO CLAUDE.md/AGENTS.md | 1 |
| M10 | Money path | N/A (no purchases) | - |
| M11 | Review readiness | Retold/PrivacyInfo.xcprivacy present; no accounts; 1.0 resubmission pending (Perry) | 3 |


## Screenshot observations (Opus read the CI simulator screenshots, 6.5", demo mode, run 42093837503)

These are what "janky" looks like on screen. Cite them by ID.

- S1 Home (01-home): stock inset-grouped List on grey; the primary action "Record a memory" is a plain
  blue text row, same weight as every other row, no icon, no fill. Title "Retold" is a stock large title.
  Nothing on the page signals this is a memory journal (no brand colour, no mark, no imagery).
- S2 Home: browse links (People, Places, Themes, Periods, Set-aside questions) sit ABOVE the stories,
  so the user's own stories start below the fold after one unfiled row.
- S3 Recorder (02-recorder): a small red dot, "00:01" in body-size text, the live transcript, then ~60%
  of the screen empty white; "Recording" grey text and "Stop" as a plain blue text link at the bottom.
  No level meter or any sign the mic hears you; Stop is not a prominent button.
- S4 Confirm sheet (03-confirm): the suggestion row "taught me to fish off the dock | suggested |
  Use this | Not this" squeezes the suggested title into a narrow column that wraps to 3 lines, because
  the two text buttons and the "suggested" tag take most of the row width. Same pattern on the Period row.
  "File it" is a disabled glass capsule, low contrast. Below the Year/Age segmented control there is a large
  empty band inside the card.
- S5 Story page (04-story): the nav title truncates ("Summers at the lake ho..."). Five question offers
  ("Answer now / Not this one" text-button pairs) push the Recordings section with the player and the
  transcript entirely below the fold: the user's own voice and words are the last thing on the page.
  (Verified: XCUI could not find the slider until it scrolled; PR #26.)


## Target source excerpts (Retold), with line numbers


### Retold/RetoldApp.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| import UIKit
   4| 
   5| @main
   6| struct RetoldApp: App {
   7|     @State private var services: LiveCapture.LiveCaptureServices?
   8|     @State private var startupFailed = false
   9| 
  10|     var body: some Scene {
  11|         WindowGroup {
  12|             Group {
  13|                 if startupFailed {
  14|                     Text(AppCopy.startupFailed)
  15|                         .padding()
  16|                 } else if let services {
  17|                     RootView(services: services)
  18|                 } else {
  19|                     ProgressView()
  20|                 }
  21|             }
  22|             .task {
  23|                 guard services == nil, !startupFailed else { return }
  24|                 do {
  25|                     #if DEBUG
  26|                     // `-RetoldDemo` (ScreenshotTests only) launches the seeded mock demo; everything
  27|                     // else is production. The Release build compiles only the production line below.
  28|                     if DemoMode.isActive {
  29|                         services = try DemoMode.makeServices()
  30|                     } else {
  31|                         services = try LiveCapture.makeCoordinator()
  32|                     }
  33|                     #else
  34|                     services = try LiveCapture.makeCoordinator()
  35|                     #endif
  36|                 } catch {
  37|                     startupFailed = true
  38|                 }
  39|             }
  40|         }
  41|     }
  42| }
  43| 
  44| /// Routes between first run, recorder and home, and turns scene / protected-data signals
  45| /// into coordinator events.
  46| private struct RootView: View {
  47|     let services: LiveCapture.LiveCaptureServices
  48|     @Environment(\.scenePhase) private var scenePhase
  49|     @State private var autoPresentID: UUID?
  50|     @State private var playback: AudioPlayback
  51| 
  52|     private var coordinator: CaptureCoordinator { services.coordinator }
  53| 
  54|     init(services: LiveCapture.LiveCaptureServices) {
  55|         self.services = services
  56|         _playback = State(initialValue: AudioPlayback(files: services.coordinator.files))
  57|     }
  58| 
  59|     @Environment(\.accessibilityReduceMotion) private var reduceMotion
  60| 
  61|     private enum Screen { case firstRun, recorder, home }
  62| 
  63|     private var screen: Screen {
  64|         if coordinator.state.permission == .undetermined { return .firstRun }
  65|         switch coordinator.state.phase {
  66|         case .starting, .recording, .interrupted, .stopping: return .recorder
  67|         case .idle, .blocked, .aborting: return .home
  68|         }
  69|     }
  70| 
  71|     /// Haptic for a recorder phase change; nil means no feedback.
  72|     static func feedback(from old: RecorderPhase, to new: RecorderPhase) -> SensoryFeedback? {
  73|         switch (old, new) {
  74|         case (_, .recording):
  75|             return .start
  76|         case (.recording, .interrupted):
  77|             return .warning
  78|         case (_, .stopping):
  79|             return .stop
  80|         case (.stopping, .idle):
  81|             return .success
  82|         default:
  83|             return nil
  84|         }
  85|     }
  86| 
  87|     var body: some View {
  88|         Group {
  89|             if coordinator.state.permission == .undetermined {
  90|                 FirstRunView(engine: services.engine, prefetch: services.prefetch) { permission in
  91|                     coordinator.send(.permissionChanged(permission))
  92|                 }
  93|                 .transition(.opacity)
  94|             } else {
  95|                 switch coordinator.state.phase {
  96|                 case .starting, .recording, .interrupted, .stopping:
  97|                     RecorderView(coordinator: coordinator)
  98|                         .transition(.opacity)
  99|                 case .idle, .blocked, .aborting:
 100|                     HomeView(coordinator: coordinator, autoPresentID: $autoPresentID)
 101|                         .transition(.opacity)
 102|                 }
 103|             }
 104|         }
 105|         // Screen swaps fade instead of cutting; Reduce Motion turns the animation off.
 106|         .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: screen)
 107|         .sensoryFeedback(trigger: coordinator.state.phase) { old, new in
 108|             Self.feedback(from: old, to: new)
 109|         }
 110|         .environment(playback)
 111|         .environment(coordinator)
 112|         .modelContainer(services.container)
 113|         .task {
 114|             // The export zip holds the whole library unencrypted in tmp: clear any leftover.
 115|             ExportArchiver.sweep(workDirectory: ExportArchiver.defaultWorkDirectory)
 116|             await coordinator.run()
 117|         }
 118|         .onChange(of: coordinator.state.phase) { oldPhase, newPhase in
 119|             if case .stopping(let id, _) = oldPhase, case .idle = newPhase {
 120|                 autoPresentID = id
 121|             }
 122|             // Playback yields to the recorder (covers the Control and the Action button). The
 123|             // recorder's own setCategory supersedes playback, so the session is not deactivated.
 124|             switch newPhase {
 125|             case .idle, .blocked:
 126|                 break
 127|             default:
 128|                 playback.stop(deactivateSession: false)
 129|             }
 130|         }
 131|         // initial: true -- RootView appears only after the services exist, when the scene is already
 132|         // active; without it a cold launch from the Control never drains the launch inbox.
 133|         .onChange(of: scenePhase, initial: true) { _, newPhase in
 134|             Task { @MainActor in
 135|                 switch newPhase {
 136|                 case .active:
 137|                     coordinator.send(.sceneDidBecomeActive)
 138|                     await coordinator.drainLaunchInbox()
 139|                 case .inactive:
 140|                     coordinator.send(.sceneWillResignActive)
 141|                 case .background:
 142|                     coordinator.send(.sceneDidEnterBackground)
 143|                 @unknown default:
 144|                     break
 145|                 }
 146|             }
 147|         }
 148|         .onReceive(NotificationCenter.default.publisher(
 149|             for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
 150|             Task { @MainActor in coordinator.send(.protectedDataWillBecomeUnavailable) }
 151|         }
 152|         .onReceive(NotificationCenter.default.publisher(
 153|             for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
 154|             Task { @MainActor in coordinator.send(.protectedDataDidBecomeAvailable) }
 155|         }
 156|     }
 157| }
 158| 
```


### Retold/Screens/HomeView.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| struct HomeView: View {
   5|     let coordinator: CaptureCoordinator
   6|     @Binding var autoPresentID: UUID?
   7| 
   8|     @Environment(\.modelContext) private var modelContext
   9|     @Environment(\.scenePhase) private var scenePhase
  10|     @Environment(AudioPlayback.self) private var playback
  11|     @Environment(\.openURL) private var openURL
  12|     @Query(
  13|         filter: #Predicate<Capture> { $0.episode == nil },
  14|         sort: [SortDescriptor(\Capture.createdAt, order: .reverse)]
  15|     ) private var unfiledCaptures: [Capture]
  16|     @Query(sort: \Period.sortOrder) private var periods: [Period]
  17|     @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
  18| 
  19|     @State private var selectedCapture: Capture?
  20|     @State private var selectedAnsweredPeriodID: UUID?
  21|     @State private var showingSettings = false
  22|     @State private var outcomes: [UUID: FilingOutcome] = [:]
  23|     // The id, never a Capture: reading a property of a deleted SwiftData model can trap.
  24|     @State private var pendingDeleteID: UUID?
  25|     @State private var deleteFailed = false
  26|     @State private var micBlocked = false
  27| 
  28|     private var sections: [TimelineSection] {
  29|         Timeline.sections(
  30|             periods: periods.map { PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder) },
  31|             episodes: episodes.map { TimelineEpisode(id: $0.id, periodID: $0.period?.id, createdAt: $0.createdAt) }
  32|         )
  33|     }
  34| 
  35|     var body: some View {
  36|         let periodsByID = Dictionary(periods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  37|         let episodesByID = Dictionary(episodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  38|         NavigationStack {
  39|             List {
  40|                 Section {
  41|                     Button(AppCopy.recordButton) {
  42|                         // Stop playback (deactivating) before the capture starts, while the phase is .idle.
  43|                         playback.stop()
  44|                         Task { @MainActor in
  45|                             await coordinator.startCapture(answering: nil)
  46|                             // A denied microphone used to do nothing visible.
  47|                             if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
  48|                                 micBlocked = true
  49|                             }
  50|                         }
  51|                     }
  52|                 }
  53|                 if !unfiledCaptures.isEmpty {
  54|                     Section(AppCopy.unfiledHeader) {
  55|                         ForEach(unfiledCaptures) { capture in
  56|                             unfiledRow(capture)
  57|                                 // Not a full swipe: a full swipe must never delete without the dialog.
  58|                                 .swipeActions(edge: .trailing, allowsFullSwipe: false) {
  59|                                     Button(AppCopy.deleteAction, role: .destructive) { pendingDeleteID = capture.id }
  60|                                 }
  61|                         }
  62|                     }
  63|                 }
  64|                 Section {
  65|                     NavigationLink(AppCopy.peopleHeader, destination: PeopleView())
  66|                     NavigationLink(AppCopy.placesTitle, destination: PlacesView())
  67|                     NavigationLink(AppCopy.themesTitle, destination: ThemesView())
  68|                     NavigationLink(AppCopy.periodsTitle, destination: PeriodsView())
  69|                     NavigationLink(AppCopy.setAsideTitle, destination: SetAsideView())
  70|                 }
  71|                 ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
  72|                     Section {
  73|                         if let ref = section.period {
  74|                             if let period = periodsByID[ref.id] {
  75|                                 NavigationLink(destination: PeriodView(period: period)) {
  76|                                     Text(ref.title)
  77|                                         .font(.headline)
  78|                                 }
  79|                             }
  80|                         } else {
  81|                             Text(AppCopy.noPeriod)
  82|                                 .font(.headline)
  83|                         }
  84|                         ForEach(section.episodeIDs, id: \.self) { id in
  85|                             if let episode = episodesByID[id] {
  86|                                 EpisodeRow(episode: episode)
  87|                             }
  88|                         }
  89|                     }
  90|                 }
  91|             }
  92|             .navigationTitle(AppCopy.homeTitle)
  93|             .toolbar {
  94|                 ToolbarItem(placement: .topBarTrailing) {
  95|                     Button {
  96|                         showingSettings = true
  97|                     } label: {
  98|                         Image(systemName: "gearshape")
  99|                             .accessibilityLabel(AppCopy.settingsTitle)
 100|                     }
 101|                 }
 102|             }
 103|         }
 104|         .sheet(isPresented: $showingSettings) {
 105|             SettingsView(files: coordinator.files)
 106|         }
 107|         .sheet(item: $selectedCapture) { capture in
 108|             ConfirmView(
 109|                 capture: capture,
 110|                 row: ConfirmDraft.unfiledRow(
 111|                     status: capture.transcriptionStatus,
 112|                     transcript: capture.completedTranscript
 113|                 ),
 114|                 cachedOutcome: outcomes[capture.id],
 115|                 answeredPeriodID: selectedAnsweredPeriodID
 116|             ) { outcome in
 117|                 outcomes[capture.id] = outcome
 118|             }
 119|         }
 120|         .confirmationDialog(
 121|             AppCopy.deleteRecordingTitle,
 122|             isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
 123|             titleVisibility: .visible,
 124|             presenting: pendingDeleteID
 125|         ) { id in
 126|             Button(AppCopy.deleteRecordingConfirm, role: .destructive) { deleteCapture(id) }
 127|         } message: { _ in
 128|             Text(AppCopy.deleteRecordingMessage)
 129|         }
 130|         .alert(AppCopy.deleteFailed, isPresented: $deleteFailed) {
 131|             Button(AppCopy.okButton, role: .cancel) {}
 132|         }
 133|         .alert(AppCopy.startFailedTitle, isPresented: Binding(
 134|             get: { coordinator.startFailure != nil },
 135|             set: { if !$0 { coordinator.clearStartFailure() } }
 136|         )) {
 137|             Button(AppCopy.okButton, role: .cancel) {}
 138|         } message: {
 139|             Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? ""))
 140|         }
 141|         .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
 142|             Button(AppCopy.openSettings) {
 143|                 if let url = URL(string: UIApplication.openSettingsURLString) {
 144|                     openURL(url)
 145|                 }
 146|             }
 147|             Button(AppCopy.cancelButton, role: .cancel) {}
 148|         } message: {
 149|             Text(AppCopy.micDenied)
 150|         }
 151|         .onAppear {
 152|             // Order matters: seed periods, then attach answers, then auto-present. Home is created
 153|             // fresh after Stop, so autoPresentID is already set here; an episode answer must attach
 154|             // before auto-present, or it would open a confirm sheet it should not get.
 155|             try? DefaultPeriods.seedIfNeeded(modelContext, defaults: .standard)
 156|             _ = try? AnswerAttacher.attachPending(in: modelContext)
 157|             handleAutoPresent()
 158|         }
 159|         .onChange(of: autoPresentID) { _, _ in
 160|             handleAutoPresent()
 161|         }
 162|         .onChange(of: coordinator.lastImport) { _, _ in
 163|             _ = try? AnswerAttacher.attachPending(in: modelContext)
 164|         }
 165|         // The file pass completes audio-only captures without setting lastImport.
 166|         .onChange(of: scenePhase) { _, newPhase in
 167|             if newPhase == .active {
 168|                 _ = try? AnswerAttacher.attachPending(in: modelContext)
 169|             }
 170|         }
 171|     }
 172| 
 173|     @ViewBuilder
 174|     private func unfiledRow(_ capture: Capture) -> some View {
 175|         let state = ConfirmDraft.unfiledRow(
 176|             status: capture.transcriptionStatus,
 177|             transcript: capture.completedTranscript
 178|         )
 179|         switch state {
 180|         case .transcribing:
 181|             // Tappable: a recording whose transcript never arrives (no on-device speech for this
 182|             // locale) must still be fileable with a typed title. ConfirmView handles this row.
 183|             Button {
 184|                 present(capture)
 185|             } label: {
 186|                 captureRow(capture, detail: AppCopy.transcribingLabel)
 187|             }
 188|             .buttonStyle(.plain)
 189|         case .ready(let excerpt):
 190|             Button {
 191|                 present(capture)
 192|             } label: {
 193|                 captureRow(capture, detail: excerpt)
 194|             }
 195|             .buttonStyle(.plain)
 196|         case .noTranscript:
 197|             Button {
 198|                 present(capture)
 199|             } label: {
 200|                 captureRow(capture, detail: AppCopy.noTranscriptLabel)
 201|             }
 202|             .buttonStyle(.plain)
 203|         }
 204|     }
 205| 
 206|     private func captureRow(_ capture: Capture, detail: String) -> some View {
 207|         VStack(alignment: .leading, spacing: 4) {
 208|             Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
 209|             Text(detail)
 210|                 .foregroundStyle(.secondary)
 211|                 .lineLimit(2)
 212|         }
 213|         .frame(maxWidth: .infinity, alignment: .leading)
 214|         .contentShape(Rectangle())
 215|     }
 216| 
 217|     @MainActor
 218|     private func deleteCapture(_ id: UUID) {
 219|         do {
 220|             try CaptureDeleter.delete(
 221|                 captureID: id,
 222|                 activeCaptureID: coordinator.activeCaptureID,
 223|                 files: coordinator.files,
 224|                 in: modelContext.container
 225|             )
 226|             outcomes[id] = nil
 227|         } catch CaptureDeleteError.filed {
 228|             // Attached since the swipe: the row has already left Unfiled.
 229|         } catch {
 230|             deleteFailed = true
 231|         }
 232|     }
 233| 
 234|     /// Computes the answered period once per presentation, never in the sheet closure.
 235|     private func present(_ capture: Capture) {
 236|         selectedAnsweredPeriodID = AnswerAttacher.answeredPeriodID(for: capture, in: modelContext)
 237|         selectedCapture = capture
 238|     }
 239| 
 240|     private func handleAutoPresent() {
 241|         guard let id = autoPresentID else { return }
 242|         defer { autoPresentID = nil }
 243|         // An answer to an episode's question attaches first, so it never opens a confirm sheet.
 244|         _ = try? AnswerAttacher.attachPending(in: modelContext)
 245|         let wantedID = id
 246|         var descriptor = FetchDescriptor<Capture>(
 247|             predicate: #Predicate { $0.id == wantedID }
 248|         )
 249|         descriptor.fetchLimit = 1
 250|         guard let captures = try? modelContext.fetch(descriptor),
 251|               let capture = captures.first,
 252|               capture.episode == nil
 253|         else { return }
 254| 
 255|         switch ConfirmDraft.unfiledRow(
 256|             status: capture.transcriptionStatus,
 257|             transcript: capture.completedTranscript
 258|         ) {
 259|         case .ready, .noTranscript:
 260|             present(capture)
 261|         case .transcribing:
 262|             break
 263|         }
 264|     }
 265| }
 266| 
 267| /// A button that plays or pauses one capture. Disabled when its audio file is missing.
 268| struct PlayPauseButton: View {
 269|     let captureID: UUID
 270| 
 271|     @Environment(AudioPlayback.self) private var playback
 272| 
 273|     var body: some View {
 274|         let isThisPlaying = playback.captureID == captureID && playback.isPlaying
 275|         Button {
 276|             if isThisPlaying {
 277|                 playback.pause()
 278|             } else {
 279|                 playback.play(captureID)
 280|             }
 281|         } label: {
 282|             Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
 283|                 .frame(minWidth: 44, minHeight: 44)
 284|                 .contentShape(Rectangle())
 285|         }
 286|         .buttonStyle(.borderless)
 287|         .disabled(!playback.canPlay(captureID))
 288|         .accessibilityLabel(isThisPlaying ? AppCopy.pauseButton : AppCopy.playButton)
 289|         .sensoryFeedback(.impact(weight: .light), trigger: isThisPlaying)
 290|     }
 291| }
 292| 
 293| /// One episode in a list (R7b section 7.2), reused by the period, person and place pages.
 294| struct EpisodeRow: View {
 295|     let episode: Episode
 296| 
 297|     private var firstCapture: Capture? {
 298|         episode.captures.min { (a: Capture, b: Capture) -> Bool in
 299|             (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
 300|         }
 301|     }
 302| 
 303|     var body: some View {
 304|         let facts = EpisodeFacts(episode: episode)
 305|         NavigationLink(destination: EpisodeView(episode: episode)) {
 306|             HStack {
 307|                 VStack(alignment: .leading, spacing: 4) {
 308|                     Text(facts.title ?? AppCopy.untitled)
 309|                     // Verbatim user words, the same line the export prints; not a Confirmable.
 310|                     if !episode.excerpt.isEmpty {
 311|                         Text(episode.excerpt)
 312|                             .font(.subheadline)
 313|                             .foregroundStyle(.secondary)
 314|                             .lineLimit(1)
 315|                     }
 316|                     if let when = facts.whenDisplay {
 317|                         Text(when)
 318|                             .font(.subheadline)
 319|                             .foregroundStyle(.secondary)
 320|                     }
 321|                 }
 322|                 Spacer()
 323|                 if let capture = firstCapture {
 324|                     PlayPauseButton(captureID: capture.id)
 325|                 }
 326|             }
 327|         }
 328|     }
 329| }
 330| 
 331| extension Collection where Element == Episode {
 332|     /// Newest first, by `(createdAt descending, id.uuidString)`.
 333|     func newestFirst() -> [Episode] {
 334|         sorted { (a: Episode, b: Episode) -> Bool in
 335|             if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
 336|             return a.id.uuidString < b.id.uuidString
 337|         }
 338|     }
 339| }
 340| 
```


### Retold/Screens/RecorderView.swift
```
   1| import Foundation
   2| import SwiftData
   3| import SwiftUI
   4| 
   5| /// R6b recorder: red dot, elapsed time, live text, Stop, and Resume while interrupted
   6| /// (R7 replaces this screen; no design pass).
   7| struct RecorderView: View {
   8|     let coordinator: CaptureCoordinator
   9|     /// Anchor for the once-a-second redraw only; the displayed time is accumulated audio time.
  10|     @State private var tickAnchor = Date()
  11|     /// Seconds recorded in earlier .recording stretches (an interruption closes one).
  12|     @State private var accumulated: TimeInterval = 0
  13|     /// When the current .recording stretch began; nil while starting, interrupted or stopping.
  14|     @State private var runningSince: Date?
  15|     @Environment(\.modelContext) private var modelContext
  16|     /// R7b: the question this capture answers, fetched once on appear. Hidden when not found.
  17|     @State private var answeringText: String?
  18| 
  19|     private var isInterrupted: Bool {
  20|         if case .interrupted = coordinator.state.phase { return true }
  21|         return false
  22|     }
  23| 
  24|     private var isRecording: Bool {
  25|         if case .recording = coordinator.state.phase { return true }
  26|         return false
  27|     }
  28| 
  29|     private var isStarting: Bool {
  30|         if case .starting = coordinator.state.phase { return true }
  31|         return false
  32|     }
  33| 
  34|     private var isStopping: Bool {
  35|         if case .stopping = coordinator.state.phase { return true }
  36|         return false
  37|     }
  38| 
  39|     var body: some View {
  40|         VStack(spacing: 20) {
  41|             if coordinator.state.answering != nil {
  42|                 Text(AppCopy.answeringLabel)
  43|                     .foregroundStyle(.secondary)
  44|                 if let answeringText {
  45|                     Text(answeringText)
  46|                 }
  47|                 Text(AppCopy.reinstatement)
  48|                     .font(.footnote)
  49|             }
  50|             Circle()
  51|                 .fill(.red)
  52|                 .frame(width: 16, height: 16)
  53|             TimelineView(.periodic(from: tickAnchor, by: 1)) { context in
  54|                 Text(elapsed(at: context.date))
  55|                     .font(.title2.monospacedDigit())
  56|             }
  57|             ScrollView {
  58|                 Text(coordinator.liveText)
  59|                     .frame(maxWidth: .infinity, alignment: .leading)
  60|             }
  61|             if isInterrupted {
  62|                 Text(AppCopy.pausedLabel)
  63|                     .foregroundStyle(.secondary)
  64|                 Button(AppCopy.resumeButton) {
  65|                     Task { @MainActor in coordinator.send(.tapResume) }
  66|                 }
  67|             } else if isStarting {
  68|                 // Engine spin-up: no audio is being captured yet, so do not say "Recording".
  69|                 HStack(spacing: 8) {
  70|                     ProgressView()
  71|                     Text(AppCopy.startingLabel)
  72|                         .foregroundStyle(.secondary)
  73|                 }
  74|             } else if isStopping {
  75|                 // The engine is finalizing the file: say so, instead of looking like it still records.
  76|                 HStack(spacing: 8) {
  77|                     ProgressView()
  78|                     Text(AppCopy.savingLabel)
  79|                         .foregroundStyle(.secondary)
  80|                 }
  81|             } else {
  82|                 Text(AppCopy.recordingLabel)
  83|                     .foregroundStyle(.secondary)
  84|             }
  85|             if coordinator.lengthWarning {
  86|                 Text(AppCopy.lengthWarning)
  87|                     .font(.footnote)
  88|                     .padding(8)
  89|                     .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  90|             }
  91|             Button(AppCopy.stopButton) {
  92|                 Task { @MainActor in coordinator.send(.tapStop) }
  93|             }
  94|             .disabled(isStopping || isStarting)
  95|         }
  96|         .padding()
  97|         .onAppear {
  98|             loadAnsweringText()
  99|             syncClock()
 100|         }
 101|         .onChange(of: coordinator.state.phase) { _, _ in
 102|             syncClock()
 103|             // A sighted user sees the label change; VoiceOver users need it spoken.
 104|             if isInterrupted {
 105|                 AccessibilityNotification.Announcement(AppCopy.pausedLabel).post()
 106|             } else if isStopping {
 107|                 AccessibilityNotification.Announcement(AppCopy.savingLabel).post()
 108|             }
 109|         }
 110|         .onChange(of: coordinator.lengthWarning) { _, warning in
 111|             if warning { AccessibilityNotification.Announcement(AppCopy.lengthWarning).post() }
 112|         }
 113|     }
 114| 
 115|     /// Counts time only while the phase is .recording, so the clock matches the saved file.
 116|     private func syncClock() {
 117|         if isRecording {
 118|             if runningSince == nil { runningSince = Date() }
 119|         } else if let since = runningSince {
 120|             accumulated += Date().timeIntervalSince(since)
 121|             runningSince = nil
 122|         }
 123|     }
 124| 
 125|     private func loadAnsweringText() {
 126|         guard let id = coordinator.state.answering else { return }
 127|         var descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.id == id })
 128|         descriptor.fetchLimit = 1
 129|         if let question = try? modelContext.fetch(descriptor).first {
 130|             answeringText = QuestionText.display(question)
 131|         }
 132|     }
 133| 
 134|     private func elapsed(at now: Date) -> String {
 135|         let live = runningSince.map { now.timeIntervalSince($0) } ?? 0
 136|         let total = Int(accumulated + live)
 137|         return String(format: "%02d:%02d", total / 60, total % 60)
 138|     }
 139| }
 140| 
```


### Retold/Screens/ConfirmView.swift
```
   1| import Foundation
   2| import SwiftData
   3| import SwiftUI
   4| 
   5| struct ConfirmView: View {
   6|     let capture: Capture
   7|     let row: UnfiledRow
   8|     let cachedOutcome: FilingOutcome?
   9|     /// R7b: the period of the question this capture answers, if any; pre-picked in the draft.
  10|     let answeredPeriodID: UUID?
  11|     let onOutcome: (FilingOutcome) -> Void
  12| 
  13|     @Environment(\.dismiss) private var dismiss
  14|     @Environment(\.modelContext) private var modelContext
  15|     @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
  16|     @Query(sort: \Period.sortOrder) private var periods: [Period]
  17|     @Query(sort: \Person.name) private var people: [Person]
  18|     @Query(sort: \Place.name) private var places: [Place]
  19| 
  20|     @State private var draft: ConfirmDraft?
  21|     @State private var mode: FilingMode?
  22|     @State private var suggestionTask: Task<FilingOutcome, Never>?
  23|     @State private var findingSuggestions = false
  24|     @State private var whenMode = WhenMode.year
  25|     @State private var selectedWhenValue: Int?
  26|     @State private var newPersonName = ""
  27|     @State private var newPlaceName = ""
  28| 
  29|     private enum WhenMode: Hashable {
  30|         case year, age
  31|     }
  32| 
  33|     private enum PeriodPickerValue: Hashable {
  34|         case none
  35|         case existing(UUID)
  36|         case new
  37|     }
  38| 
  39|     var body: some View {
  40|         NavigationStack {
  41|             Group {
  42|                 if let current = draft {
  43|                     form(current)
  44|                 } else if findingSuggestions {
  45|                     VStack(spacing: 16) {
  46|                         ProgressView()
  47|                         Text(AppCopy.findingSuggestions)
  48|                         Button(AppCopy.skipSuggestions) {
  49|                             skipSuggestions()
  50|                         }
  51|                     }
  52|                     .padding()
  53|                 } else {
  54|                     ProgressView()
  55|                 }
  56|             }
  57|             .toolbar {
  58|                 ToolbarItem(placement: .cancellationAction) {
  59|                     Button(AppCopy.cancelButton) { dismiss() }
  60|                 }
  61|                 ToolbarItem(placement: .confirmationAction) {
  62|                     Button(AppCopy.fileButton) {
  63|                         file()
  64|                     }
  65|                     .disabled(!(draft?.canFile ?? false))
  66|                 }
  67|             }
  68|         }
  69|         .task {
  70|             await load()
  71|         }
  72|         .onDisappear {
  73|             suggestionTask?.cancel()
  74|         }
  75|     }
  76| 
  77|     @ViewBuilder
  78|     private func form(_ current: ConfirmDraft) -> some View {
  79|         Form {
  80|             if case .deck(let reason)? = mode, let copy = reason.copy {
  81|                 Section {
  82|                     Text(copy)
  83|                         .font(.footnote)
  84|                         .foregroundStyle(.secondary)
  85|                 }
  86|             }
  87| 
  88|             Section(AppCopy.titleHeader) {
  89|                 switch row {
  90|                 case .ready(let excerpt):
  91|                     Text(excerpt)
  92|                 case .noTranscript:
  93|                     Text(AppCopy.noTranscriptLabel)
  94|                 case .transcribing:
  95|                     Text(AppCopy.transcribingLabel)
  96|                 }
  97|                 if let chip = current.titleChip {
  98|                     suggestionRow(chip: chip) {
  99|                         mutateDraft { $0.acceptTitle() }
 100|                     } reject: {
 101|                         mutateDraft { $0.rejectTitle() }
 102|                     }
 103|                 }
 104|                 TextField(AppCopy.titlePlaceholder, text: Binding(
 105|                     get: { draft?.typedTitle ?? "" },
 106|                     set: { value in mutateDraft { $0.typedTitle = value } }
 107|                 ))
 108|                 if !current.canFile {
 109|                     Text(AppCopy.titleNeededHint)
 110|                         .font(.footnote)
 111|                         .foregroundStyle(.secondary)
 112|                 }
 113|             }
 114| 
 115|             Section(AppCopy.periodHeader) {
 116|                 if let suggested = current.suggestedPeriod,
 117|                    current.periodSuggestionState != .rejected {
 118|                     HStack {
 119|                         Text(suggested.title)
 120|                         if current.periodSuggestionState == .suggested {
 121|                             Text(AppCopy.suggestedLabel)
 122|                                 .foregroundStyle(.secondary)
 123|                         }
 124|                         Spacer()
 125|                         Button(AppCopy.acceptButton) {
 126|                             mutateDraft { $0.acceptSuggestedPeriod() }
 127|                         }
 128|                         Button(AppCopy.rejectButton) {
 129|                             mutateDraft { $0.rejectSuggestedPeriod() }
 130|                         }
 131|                     }
 132|                     .buttonStyle(.borderless)
 133|                 }
 134|                 Picker(AppCopy.periodHeader, selection: periodSelection) {
 135|                     Text(AppCopy.noPeriod).tag(PeriodPickerValue.none)
 136|                     ForEach(periods) { period in
 137|                         Text(period.title).tag(PeriodPickerValue.existing(period.id))
 138|                     }
 139|                     Text(AppCopy.newPeriod).tag(PeriodPickerValue.new)
 140|                 }
 141|                 if case .new = current.periodPick {
 142|                     TextField(AppCopy.newPeriodPlaceholder, text: Binding(
 143|                         get: {
 144|                             if case .new(let title)? = draft?.periodPick { return title }
 145|                             return ""
 146|                         },
 147|                         set: { title in mutateDraft { $0.pick(.new(title)) } }
 148|                     ))
 149|                 }
 150|             }
 151| 
 152|             Section(AppCopy.whenHeader) {
 153|                 Text(current.whenQuestion.text)
 154|                 Picker(AppCopy.whenHeader, selection: $whenMode) {
 155|                     Text(AppCopy.whenYear).tag(WhenMode.year)
 156|                     Text(AppCopy.whenAge).tag(WhenMode.age)
 157|                 }
 158|                 .pickerStyle(.segmented)
 159|                 .onChange(of: whenMode) { _, _ in
 160|                     selectedWhenValue = nil
 161|                     mutateDraft { $0.setWhen(.notSure) }
 162|                 }
 163|                 Picker(AppCopy.whenHeader, selection: $selectedWhenValue) {
 164|                     Text("-").tag(Int?.none)
 165|                     if whenMode == .year {
 166|                         ForEach(Array(stride(from: Calendar.current.component(.year, from: Date()), through: 1900, by: -1)), id: \.self) { year in
 167|                             Text(String(year)).tag(Int?.some(year))
 168|                         }
 169|                     } else {
 170|                         ForEach(0...100, id: \.self) { age in
 171|                             Text(String(age)).tag(Int?.some(age))
 172|                         }
 173|                     }
 174|                 }
 175|                 .pickerStyle(.wheel)
 176|                 .onChange(of: selectedWhenValue) { _, value in
 177|                     guard let value else {
 178|                         mutateDraft { $0.setWhen(.notSure) }
 179|                         return
 180|                     }
 181|                     mutateDraft {
 182|                         $0.setWhen(whenMode == .year ? .year(value) : .age(value))
 183|                     }
 184|                 }
 185|                 Button(AppCopy.notSure) {
 186|                     selectedWhenValue = nil
 187|                     mutateDraft { $0.setWhen(.notSure) }
 188|                 }
 189|             }
 190| 
 191|             Section(AppCopy.peopleHeader) {
 192|                 ForEach(current.people) { chip in
 193|                     suggestionRow(chip: chip) {
 194|                         mutateDraft { $0.setChip(chip.id, .accepted) }
 195|                     } reject: {
 196|                         mutateDraft { $0.setChip(chip.id, .rejected) }
 197|                     }
 198|                     if chip.state == .accepted, let match = chip.match {
 199|                         Picker(AppCopy.peopleHeader, selection: Binding(
 200|                             get: {
 201|                                 draft?.people.first(where: { $0.id == chip.id })?.useMatch ?? true
 202|                             },
 203|                             set: { useMatch in
 204|                                 mutateDraft { $0.setUseMatch(chip.id, useMatch) }
 205|                             }
 206|                         )) {
 207|                             Text("\(AppCopy.sameAs) \(match.name)").tag(true)
 208|                             Text(AppCopy.newPerson).tag(false)
 209|                         }
 210|                         .pickerStyle(.segmented)
 211|                     }
 212|                 }
 213|                 ForEach(Array(current.typedPeople.enumerated()), id: \.offset) { index, entity in
 214|                     HStack {
 215|                         Text(entityName(entity, known: current.knownPeople))
 216|                         Spacer()
 217|                         Button {
 218|                             mutateDraft { $0.removeTypedPerson(at: index) }
 219|                         } label: {
 220|                             Image(systemName: "trash")
 221|                                 .frame(minWidth: 44, minHeight: 44)
 222|                                 .contentShape(Rectangle())
 223|                         }
 224|                         .accessibilityLabel(removeLabel(entityName(entity, known: current.knownPeople)))
 225|                     }
 226|                     .buttonStyle(.borderless)
 227|                 }
 228|                 Menu(AppCopy.addPerson) {
 229|                     ForEach(current.knownPeople, id: \.id) { person in
 230|                         Button(person.name) {
 231|                             mutateDraft { $0.addTypedPerson(.existing(person.id)) }
 232|                         }
 233|                     }
 234|                 }
 235|                 TextField(AppCopy.newPerson, text: $newPersonName)
 236|                     .onSubmit {
 237|                         let name = newPersonName
 238|                         mutateDraft { $0.addTypedPerson(.new(name)) }
 239|                         newPersonName = ""
 240|                     }
 241|             }
 242| 
 243|             Section(AppCopy.placesHeader) {
 244|                 ForEach(current.places) { chip in
 245|                     suggestionRow(chip: chip) {
 246|                         mutateDraft { $0.setChip(chip.id, .accepted) }
 247|                     } reject: {
 248|                         mutateDraft { $0.setChip(chip.id, .rejected) }
 249|                     }
 250|                     if chip.state == .accepted, let match = chip.match {
 251|                         Picker(AppCopy.placesHeader, selection: Binding(
 252|                             get: {
 253|                                 draft?.places.first(where: { $0.id == chip.id })?.useMatch ?? true
 254|                             },
 255|                             set: { useMatch in
 256|                                 mutateDraft { $0.setUseMatch(chip.id, useMatch) }
 257|                             }
 258|                         )) {
 259|                             Text("\(AppCopy.sameAs) \(match.name)").tag(true)
 260|                             Text(AppCopy.newPlace).tag(false)
 261|                         }
 262|                         .pickerStyle(.segmented)
 263|                     }
 264|                 }
 265|                 if let typedPlace = current.typedPlace {
 266|                     HStack {
 267|                         Text(entityName(typedPlace, known: current.knownPlaces))
 268|                         Spacer()
 269|                         Button {
 270|                             mutateDraft { $0.setTypedPlace(nil) }
 271|                         } label: {
 272|                             Image(systemName: "trash")
 273|                                 .frame(minWidth: 44, minHeight: 44)
 274|                                 .contentShape(Rectangle())
 275|                         }
 276|                         .accessibilityLabel(removeLabel(entityName(typedPlace, known: current.knownPlaces)))
 277|                     }
 278|                     .buttonStyle(.borderless)
 279|                 }
 280|                 Menu(AppCopy.addPlace) {
 281|                     ForEach(current.knownPlaces, id: \.id) { place in
 282|                         Button(place.name) {
 283|                             mutateDraft { $0.setTypedPlace(.existing(place.id)) }
 284|                         }
 285|                     }
 286|                 }
 287|                 TextField(AppCopy.newPlace, text: $newPlaceName)
 288|                     .onSubmit {
 289|                         let name = newPlaceName
 290|                         mutateDraft { $0.setTypedPlace(.new(name)) }
 291|                         newPlaceName = ""
 292|                     }
 293|             }
 294| 
 295|             Section(AppCopy.followUpsHeader) {
 296|                 ForEach(current.followUps.filter { current.isLive($0) }) { row in
 297|                     VStack(alignment: .leading, spacing: 8) {
 298|                         Text(row.question.text)
 299|                         if row.question.templateID != FilingTemplates.broad.id {
 300|                             HStack {
 301|                                 choiceButton(
 302|                                     AppCopy.later,
 303|                                     selected: row.choice == .later
 304|                                 ) {
 305|                                     mutateDraft { $0.setRow(row.id, .later) }
 306|                                 }
 307|                                 choiceButton(
 308|                                     AppCopy.notThisOne,
 309|                                     selected: row.choice == .notThisOne
 310|                                 ) {
 311|                                     mutateDraft { $0.setRow(row.id, .notThisOne) }
 312|                                 }
 313|                             }
 314|                         }
 315|                     }
 316|                 }
 317|             }
 318|         }
 319|     }
 320| 
 321|     private func suggestionRow(
 322|         chip: SpanChip,
 323|         accept: @escaping () -> Void,
 324|         reject: @escaping () -> Void
 325|     ) -> some View {
 326|         HStack {
 327|             Text(chip.span.text)
 328|             if chip.state == .suggested {
 329|                 Text(AppCopy.suggestedLabel)
 330|                     .foregroundStyle(.secondary)
 331|             }
 332|             Spacer()
 333|             // The frame sits inside the label: a frame outside a borderless Button grows the row, not the tap area.
 334|             Button(action: accept) {
 335|                 Text(AppCopy.acceptButton).frame(minHeight: 44).contentShape(Rectangle())
 336|             }
 337|             Button(action: reject) {
 338|                 Text(AppCopy.rejectButton).frame(minHeight: 44).contentShape(Rectangle())
 339|             }
 340|         }
 341|         .buttonStyle(.borderless)
 342|     }
 343| 
 344|     private func choiceButton(
 345|         _ title: String,
 346|         selected: Bool,
 347|         action: @escaping () -> Void
 348|     ) -> some View {
 349|         Button(action: action) {
 350|             HStack {
 351|                 if selected {
 352|                     Image(systemName: "checkmark")
 353|                 }
 354|                 Text(title)
 355|             }
 356|         }
 357|         .buttonStyle(.borderless)
 358|     }
 359| 
 360|     private var periodSelection: Binding<PeriodPickerValue> {
 361|         Binding(
 362|             get: {
 363|                 switch draft?.periodPick ?? .none {
 364|                 case .none: return .none
 365|                 case .existing(let id): return .existing(id)
 366|                 case .new: return .new
 367|                 }
 368|             },
 369|             set: { selection in
 370|                 mutateDraft {
 371|                     switch selection {
 372|                     case .none: $0.pick(.none)
 373|                     case .existing(let id): $0.pick(.existing(id))
 374|                     case .new: $0.pick(.new(""))
 375|                     }
 376|                 }
 377|             }
 378|         )
 379|     }
 380| 
 381|     private func removeLabel(_ name: String) -> String {
 382|         name.isEmpty ? AppCopy.removeLabel : "\(AppCopy.removeLabel) \(name)"
 383|     }
 384| 
 385|     private func entityName(_ entity: TypedEntity, known: [EntityRef]) -> String {
 386|         switch entity {
 387|         case .existing(let id):
 388|             return known.first(where: { $0.id == id })?.name ?? ""
 389|         case .new(let name):
 390|             return name.trimmingCharacters(in: .whitespacesAndNewlines)
 391|         }
 392|     }
 393| 
 394|     private func mutateDraft(_ mutation: (inout ConfirmDraft) -> Void) {
 395|         guard var value = draft else { return }
 396|         mutation(&value)
 397|         draft = value
 398|     }
 399| 
 400|     @MainActor
 401|     private func load() async {
 402|         guard draft == nil else { return }
 403|         #if DEBUG
 404|         // `-RetoldDemo` only: a simulator has no Apple Intelligence, so the demo files through the
 405|         // production pipeline over a scripted model (DemoMode.filingPipeline). Without the
 406|         // argument this block does nothing; the Release build does not compile it.
 407|         if DemoMode.isActive {
 408|             mode = .model
 409|             if let transcript = capture.completedTranscript {
 410|                 let outcome = await DemoMode.filingPipeline()
 411|                     .file(transcript, periodTitles: periods.map(\.title))
 412|                 buildDraft(outcome: outcome)
 413|             } else {
 414|                 buildDraft(outcome: nil)
 415|             }
 416|             return
 417|         }
 418|         #endif
 419|         let selectedMode = FilingMode.select(
 420|             availability: ModelAvailability.current,
 421|             suggestionsOn: suggestionsOn
 422|         )
 423|         mode = selectedMode
 424| 
 425|         if row == .noTranscript {
 426|             buildDraft(outcome: nil)
 427|             return
 428|         }
 429|         if case .deck = selectedMode {
 430|             buildDraft(outcome: nil)
 431|             return
 432|         }
 433|         if let cachedOutcome {
 434|             buildDraft(outcome: cachedOutcome)
 435|             return
 436|         }
 437|         guard let transcript = capture.completedTranscript else {
 438|             buildDraft(outcome: nil)
 439|             return
 440|         }
 441| 
 442|         findingSuggestions = true
 443|         let periodTitles = periods.map(\.title)
 444|         let task = Task {
 445|             await FilingPipeline(
 446|                 model: FoundationFilingModel(),
 447|                 counter: DeviceTokenCounter()
 448|             ).file(transcript, periodTitles: periodTitles)
 449|         }
 450|         suggestionTask = task
 451|         // The inner Task is unstructured, so forward cancellation to it explicitly.
 452|         let outcome = await withTaskCancellationHandler {
 453|             await task.value
 454|         } onCancel: {
 455|             task.cancel()
 456|         }
 457|         suggestionTask = nil
 458|         findingSuggestions = false
 459|         guard draft == nil else { return }
 460|         if Task.isCancelled {
 461|             // A cancelled load must not strand a blank sheet; show the plain form instead.
 462|             buildDraft(outcome: nil)
 463|             return
 464|         }
 465|         // Only a real proposal is cached: a .noModel failure (cancelled, timeout) retries on the next open.
 466|         if case .proposal = outcome {
 467|             onOutcome(outcome)
 468|         }
 469|         buildDraft(outcome: outcome)
 470|     }
 471| 
 472|     private func skipSuggestions() {
 473|         suggestionTask?.cancel()
 474|         suggestionTask = nil
 475|         findingSuggestions = false
 476|         buildDraft(outcome: nil)
 477|     }
 478| 
 479|     private func buildDraft(outcome: FilingOutcome?) {
 480|         guard draft == nil else { return }
 481|         var built = ConfirmDraft.make(
 482|             captureID: capture.id,
 483|             outcome: outcome,
 484|             periods: periods.map {
 485|                 PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder)
 486|             },
 487|             people: people.map { EntityRef(id: $0.id, name: $0.name) },
 488|             places: places.map { EntityRef(id: $0.id, name: $0.name) }
 489|         )
 490|         // The user chose to answer this period's question: a user act, not a suggestion.
 491|         if let id = answeredPeriodID, periods.contains(where: { $0.id == id }) {
 492|             built.pick(.existing(id))
 493|         }
 494|         draft = built
 495|     }
 496| 
 497|     private func file() {
 498|         guard let draft else { return }
 499|         do {
 500|             try ConfirmFiler.file(draft, capture: capture, in: modelContext)
 501|             dismiss()
 502|         } catch {
 503|             // Filing failures keep the unchanged draft on screen, per the R7a contract.
 504|         }
 505|     }
 506| }
 507| 
```


### Retold/Screens/EpisodeView.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| /// The episode page (R7b section 7.5): confirmed facts, open questions, and the recordings with
   5| /// their verbatim transcripts. Every fact is read through EpisodeFacts.
   6| struct EpisodeView: View {
   7|     let episode: Episode
   8| 
   9|     @Environment(AudioPlayback.self) private var playback
  10| 
  11|     var body: some View {
  12|         let facts = EpisodeFacts(episode: episode)
  13|         List {
  14|             if hasFacts(facts) {
  15|                 Section {
  16|                     factRows(facts)
  17|                 }
  18|             }
  19|             OfferSection(
  20|                 offers: QuestionEngine.queue(for: EpisodeState(episode: episode)),
  21|                 target: .episode(episode)
  22|             )
  23|             Section(AppCopy.recordingsHeader) {
  24|                 ForEach(sortedCaptures) { capture in
  25|                     captureBlock(capture)
  26|                 }
  27|             }
  28|         }
  29|         .navigationTitle(facts.title ?? AppCopy.untitled)
  30|     }
  31| 
  32|     private var sortedCaptures: [Capture] {
  33|         episode.captures.sorted { (a: Capture, b: Capture) -> Bool in
  34|             (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
  35|         }
  36|     }
  37| 
  38|     private func hasFacts(_ facts: EpisodeFacts) -> Bool {
  39|         facts.period != nil || facts.whenDisplay != nil || facts.place != nil
  40|             || !facts.people.isEmpty || !facts.details.isEmpty
  41|     }
  42| 
  43|     @ViewBuilder
  44|     private func factRows(_ facts: EpisodeFacts) -> some View {
  45|         if let period = facts.period {
  46|             LabeledContent(AppCopy.periodHeader, value: period.title)
  47|         }
  48|         if let when = facts.whenDisplay {
  49|             LabeledContent(AppCopy.whenHeader, value: when)
  50|         }
  51|         if let ref = facts.place, let place = episode.place {
  52|             NavigationLink(ref.name, destination: PlaceView(place: place))
  53|         }
  54|         ForEach(facts.people, id: \.id) { ref in
  55|             if let person = episode.people.first(where: { $0.id == ref.id }) {
  56|                 NavigationLink(ref.name, destination: PersonView(person: person))
  57|             }
  58|         }
  59|         ForEach(Array(facts.details.enumerated()), id: \.offset) { _, text in
  60|             Text("\u{201C}\(text)\u{201D}")
  61|         }
  62|     }
  63| 
  64|     @ViewBuilder
  65|     private func captureBlock(_ capture: Capture) -> some View {
  66|         VStack(alignment: .leading, spacing: 8) {
  67|             Text("\(capture.createdAt.formatted(date: .abbreviated, time: .shortened)) \u{00B7} \(ExportManifest.formatClock(capture.duration))")
  68|                 .font(.subheadline)
  69|             if playback.canPlay(capture.id) {
  70|                 playerRow(capture)
  71|             } else {
  72|                 Text(AppCopy.audioMissing)
  73|                     .foregroundStyle(.secondary)
  74|             }
  75|             transcript(capture)
  76|         }
  77|     }
  78| 
  79|     private func playerRow(_ capture: Capture) -> some View {
  80|         let isLoaded = playback.captureID == capture.id
  81|         return HStack {
  82|             PlayPauseButton(captureID: capture.id)
  83|             Slider(
  84|                 value: Binding(
  85|                     get: { isLoaded ? playback.currentTime : 0 },
  86|                     set: { value in
  87|                         if playback.captureID == capture.id {
  88|                             playback.seek(to: value)
  89|                         } else {
  90|                             playback.play(capture.id, from: value)
  91|                         }
  92|                     }
  93|                 ),
  94|                 in: 0...max(capture.duration, 1)
  95|             )
  96|             .disabled(capture.duration <= 0)
  97|             .accessibilityLabel(AppCopy.playbackPosition)
  98|             .accessibilityValue("\(ExportManifest.formatClock(isLoaded ? playback.currentTime : 0)) / \(ExportManifest.formatClock(capture.duration))")
  99|             Text("\(ExportManifest.formatClock(isLoaded ? playback.currentTime : 0)) / \(ExportManifest.formatClock(capture.duration))")
 100|                 .font(.footnote.monospacedDigit())
 101|                 .foregroundStyle(.secondary)
 102|         }
 103|         .buttonStyle(.borderless)
 104|     }
 105| 
 106|     @ViewBuilder
 107|     private func transcript(_ capture: Capture) -> some View {
 108|         switch CaptureTranscriptState.of(status: capture.transcriptionStatus, segments: capture.transcript) {
 109|         case .transcribing:
 110|             Text(AppCopy.transcribingLabel)
 111|                 .foregroundStyle(.secondary)
 112|         case .none:
 113|             Text(AppCopy.noTranscript)
 114|                 .foregroundStyle(.secondary)
 115|         case .segments(let segments):
 116|             ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
 117|                 Button {
 118|                     playback.play(capture.id, from: segment.start)
 119|                 } label: {
 120|                     Text("\(ExportManifest.formatClock(segment.start))  \(segment.text)")
 121|                         .frame(maxWidth: .infinity, alignment: .leading)
 122|                 }
 123|                 .buttonStyle(.borderless)
 124|             }
 125|         }
 126|     }
 127| }
 128| 
```


### Retold/Screens/OfferRow.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| /// One engine offer with its two actions (R7b section 7.1). Shows `offer.question.text`, never
   5| /// `Question.text`. A throw from either action shows a short alert, and the row stays.
   6| struct OfferRow: View {
   7|     let offer: EngineOffer
   8|     let target: OfferTarget
   9| 
  10|     @Environment(\.modelContext) private var modelContext
  11|     @Environment(AudioPlayback.self) private var playback
  12|     @Environment(CaptureCoordinator.self) private var coordinator
  13|     @Environment(\.openURL) private var openURL
  14| 
  15|     @State private var micBlocked = false
  16|     @State private var saveFailed = false
  17| 
  18|     var body: some View {
  19|         VStack(alignment: .leading, spacing: 8) {
  20|             Text(offer.question.text)
  21|             HStack {
  22|                 Button(AppCopy.answerNow) {
  23|                     answerNow()
  24|                 }
  25|                 // .dontRemember does nothing on broad.open (Question.record), as on the confirm screen.
  26|                 if offer.question.templateID != "broad.open" {
  27|                     Button(AppCopy.notThisOne) {
  28|                         notThisOne()
  29|                     }
  30|                 }
  31|             }
  32|             .buttonStyle(.borderless)
  33|         }
  34|         .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
  35|             Button(AppCopy.openSettings) {
  36|                 if let url = URL(string: UIApplication.openSettingsURLString) {
  37|                     openURL(url)
  38|                 }
  39|             }
  40|             Button(AppCopy.cancelButton, role: .cancel) {}
  41|         } message: {
  42|             Text(AppCopy.micDenied)
  43|         }
  44|         .alert(AppCopy.saveFailedTitle, isPresented: $saveFailed) {
  45|             Button(AppCopy.okButton, role: .cancel) {}
  46|         } message: {
  47|             Text(AppCopy.saveFailedMessage)
  48|         }
  49|     }
  50| 
  51|     private func answerNow() {
  52|         playback.stop()
  53|         let id: UUID
  54|         do {
  55|             id = try QuestionActions.prepareAnswer(offer, target: target, in: modelContext)
  56|         } catch {
  57|             saveFailed = true
  58|             return
  59|         }
  60|         let coordinator = coordinator
  61|         Task { @MainActor in
  62|             await coordinator.startCapture(answering: id)
  63|             if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
  64|                 micBlocked = true
  65|             }
  66|         }
  67|     }
  68| 
  69|     private func notThisOne() {
  70|         do {
  71|             try QuestionActions.notThisOne(offer, target: target, in: modelContext)
  72|         } catch {
  73|             saveFailed = true
  74|         }
  75|     }
  76| }
  77| 
  78| /// A `Section(questionsHeader)` with one OfferRow per offer, in the engine's queue order.
  79| /// Omitted when the queue is empty.
  80| struct OfferSection: View {
  81|     let offers: [EngineOffer]
  82|     let target: OfferTarget
  83| 
  84|     var body: some View {
  85|         if !offers.isEmpty {
  86|             Section(AppCopy.questionsHeader) {
  87|                 ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
  88|                     OfferRow(offer: offer, target: target)
  89|                 }
  90|             }
  91|         }
  92|     }
  93| }
  94| 
```


### Retold/Screens/FirstRunView.swift
```
   1| import SwiftUI
   2| 
   3| /// R6b first run: the microphone grant plus asset prefetch (R7 replaces this screen).
   4| struct FirstRunView: View {
   5|     let engine: LiveCaptureEngine
   6|     let prefetch: AssetPrefetch
   7|     let onDone: (MicrophonePermission) -> Void
   8|     @State private var denied = false
   9|     /// Single-flight: a second tap while the system prompt is up must not start a second request.
  10|     @State private var requesting = false
  11|     @Environment(\.openURL) private var openURL
  12|     @Environment(\.scenePhase) private var scenePhase
  13| 
  14|     var body: some View {
  15|         VStack(spacing: 20) {
  16|             Text(AppCopy.micPrompt)
  17|                 .multilineTextAlignment(.center)
  18|             if denied {
  19|                 Text(AppCopy.micDenied)
  20|                     .font(.footnote)
  21|                     .foregroundStyle(.secondary)
  22|                     .multilineTextAlignment(.center)
  23|             }
  24|             if denied {
  25|                 Button(AppCopy.openSettings) {
  26|                     if let url = URL(string: UIApplication.openSettingsURLString) {
  27|                         openURL(url)
  28|                     }
  29|                 }
  30|             } else {
  31|                 Button(AppCopy.micAllow) {
  32|                     guard !requesting else { return }
  33|                     requesting = true
  34|                     Task { @MainActor in
  35|                         defer { requesting = false }
  36|                         finish(await engine.requestMicrophonePermission())
  37|                     }
  38|                 }
  39|                 .disabled(requesting)
  40|             }
  41|         }
  42|         .padding()
  43|         // Back from Settings with the microphone now on: carry on without another tap.
  44|         .onChange(of: scenePhase) { _, phase in
  45|             guard phase == .active, denied, !requesting else { return }
  46|             requesting = true
  47|             Task { @MainActor in
  48|                 defer { requesting = false }
  49|                 finish(await engine.microphonePermission())
  50|             }
  51|         }
  52|     }
  53| 
  54|     private func finish(_ permission: MicrophonePermission) {
  55|         guard permission != .denied else {
  56|             denied = true
  57|             return
  58|         }
  59|         Task { await prefetch.run() }   // never blocks the UI
  60|         onDone(permission)
  61|     }
  62| }
  63| 
```


### Retold/Screens/EmptyPage.swift
```
   1| import SwiftUI
   2| 
   3| /// The one designed empty state (house style rule 12): a title, a sentence on what will appear,
   4| /// and one action. Used wherever a page can end up with no questions and no stories, so rejecting
   5| /// the last question never leaves a blank page.
   6| struct EmptyPage: View {
   7|     let title: String
   8|     let message: String
   9| 
  10|     @Environment(\.dismiss) private var dismiss
  11| 
  12|     var body: some View {
  13|         ContentUnavailableView {
  14|             Label(title, systemImage: "text.bubble")
  15|         } description: {
  16|             Text(message)
  17|         } actions: {
  18|             Button(AppCopy.goBack) {
  19|                 dismiss()
  20|             }
  21|         }
  22|     }
  23| }
  24| 
```


### Retold/Screens/PeriodsView.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| /// The Periods page (R7b section 7.5): rename and add. No reordering, no delete in 1.0.
   5| struct PeriodsView: View {
   6|     @Query private var periods: [Period]
   7| 
   8|     @State private var sheet: PeriodSheetTarget?
   9| 
  10|     private var ordered: [Period] {
  11|         periods.sorted { (a: Period, b: Period) -> Bool in
  12|             (a.sortOrder, a.id.uuidString) < (b.sortOrder, b.id.uuidString)
  13|         }
  14|     }
  15| 
  16|     var body: some View {
  17|         List {
  18|             ForEach(ordered) { period in
  19|                 Button(period.title) {
  20|                     sheet = .rename(period)
  21|                 }
  22|                 .buttonStyle(.plain)
  23|             }
  24|             Button(AppCopy.addPeriod) {
  25|                 sheet = .add
  26|             }
  27|         }
  28|         .navigationTitle(AppCopy.periodsTitle)
  29|         .sheet(item: $sheet) { target in
  30|             PeriodEditSheet(target: target)
  31|         }
  32|     }
  33| }
  34| 
  35| enum PeriodSheetTarget: Identifiable {
  36|     case add
  37|     case rename(Period)
  38| 
  39|     var id: String {
  40|         switch self {
  41|         case .add: return "add"
  42|         case .rename(let period): return period.id.uuidString
  43|         }
  44|     }
  45| }
  46| 
  47| /// The rename / add sheet. Save is disabled while the trimmed text is empty; a duplicate keeps
  48| /// the sheet open with a footnote. No alerts.
  49| struct PeriodEditSheet: View {
  50|     let target: PeriodSheetTarget
  51| 
  52|     @Environment(\.modelContext) private var modelContext
  53|     @Environment(\.dismiss) private var dismiss
  54|     @State private var text: String
  55|     @State private var isDuplicate = false
  56|     @State private var saveFailed = false
  57| 
  58|     init(target: PeriodSheetTarget) {
  59|         self.target = target
  60|         switch target {
  61|         case .add:
  62|             _text = State(initialValue: "")
  63|         case .rename(let period):
  64|             _text = State(initialValue: period.title)
  65|         }
  66|     }
  67| 
  68|     private var isAdd: Bool {
  69|         if case .add = target { return true }
  70|         return false
  71|     }
  72| 
  73|     var body: some View {
  74|         NavigationStack {
  75|             Form {
  76|                 Section {
  77|                     TextField(AppCopy.newPeriodPlaceholder, text: $text)
  78|                     if isDuplicate {
  79|                         Text(AppCopy.duplicatePeriod)
  80|                             .font(.footnote)
  81|                             .foregroundStyle(.secondary)
  82|                     }
  83|                 }
  84|             }
  85|             .navigationTitle(isAdd ? AppCopy.addPeriod : AppCopy.renamePeriod)
  86|             .navigationBarTitleDisplayMode(.inline)
  87|             .toolbar {
  88|                 ToolbarItem(placement: .cancellationAction) {
  89|                     Button(AppCopy.cancelButton) {
  90|                         dismiss()
  91|                     }
  92|                 }
  93|                 ToolbarItem(placement: .confirmationAction) {
  94|                     Button(AppCopy.saveButton) {
  95|                         save()
  96|                     }
  97|                     .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  98|                 }
  99|             }
 100|             .onChange(of: text) { _, _ in
 101|                 isDuplicate = false
 102|             }
 103|             .alert(AppCopy.saveFailedTitle, isPresented: $saveFailed) {
 104|                 Button(AppCopy.okButton, role: .cancel) {}
 105|             } message: {
 106|                 Text(AppCopy.saveFailedMessage)
 107|             }
 108|         }
 109|     }
 110| 
 111|     private func save() {
 112|         do {
 113|             switch target {
 114|             case .add:
 115|                 _ = try PeriodEditor.add(title: text, in: modelContext)
 116|             case .rename(let period):
 117|                 try PeriodEditor.rename(period, to: text, in: modelContext)
 118|             }
 119|             dismiss()
 120|         } catch PeriodEditError.duplicateTitle {
 121|             isDuplicate = true
 122|         } catch PeriodEditError.emptyTitle {
 123|             // Save is disabled for an empty title; the sheet stays open.
 124|         } catch {
 125|             saveFailed = true
 126|         }
 127|     }
 128| }
 129| 
```


### Retold/Screens/PeriodView.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| /// A period's page (R7b section 7.5): its open questions (for an empty period, the R5 opener),
   5| /// then its episodes, newest first.
   6| struct PeriodView: View {
   7|     let period: Period
   8| 
   9|     @Query private var allQuestions: [Question]
  10| 
  11|     var body: some View {
  12|         let offers = QuestionEngine.queue(for: PeriodState(period: period, questions: allQuestions))
  13|         Group {
  14|             if offers.isEmpty && period.episodes.isEmpty {
  15|                 EmptyPage(title: AppCopy.emptyTitle, message: AppCopy.emptyPeriodMessage)
  16|             } else {
  17|                 List {
  18|                     OfferSection(offers: offers, target: .period(period))
  19|                     Section {
  20|                         ForEach(period.episodes.newestFirst()) { episode in
  21|                             EpisodeRow(episode: episode)
  22|                         }
  23|                     }
  24|                 }
  25|             }
  26|         }
  27|         .navigationTitle(period.title)
  28|     }
  29| }
  30| 
```


### Retold/Screens/PeopleView.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| /// The People list (R7b section 7.5).
   5| struct PeopleView: View {
   6|     @Query(sort: \Person.name) private var people: [Person]
   7| 
   8|     var body: some View {
   9|         Group {
  10|             if people.isEmpty {
  11|                 EmptyPage(title: AppCopy.noPeopleTitle, message: AppCopy.noPeopleMessage)
  12|             } else {
  13|                 List(people) { person in
  14|                     NavigationLink(person.name, destination: PersonView(person: person))
  15|                 }
  16|             }
  17|         }
  18|         .navigationTitle(AppCopy.peopleHeader)
  19|     }
  20| }
  21| 
  22| /// One person's page: the person engine's open questions, then their episodes, newest first.
  23| struct PersonView: View {
  24|     let person: Person
  25| 
  26|     var body: some View {
  27|         let offers = QuestionEngine.queue(for: PersonState(person: person))
  28|         Group {
  29|             if offers.isEmpty && person.episodes.isEmpty {
  30|                 EmptyPage(title: AppCopy.emptyTitle, message: AppCopy.emptyPersonMessage)
  31|             } else {
  32|                 List {
  33|                     OfferSection(offers: offers, target: .person(person))
  34|                     Section {
  35|                         ForEach(person.episodes.newestFirst()) { episode in
  36|                             EpisodeRow(episode: episode)
  37|                         }
  38|                     }
  39|                 }
  40|             }
  41|         }
  42|         .navigationTitle(person.name)
  43|     }
  44| }
  45| 
```


### Retold/Screens/SettingsView.swift
```
   1| import SwiftData
   2| import SwiftUI
   3| 
   4| enum SettingsKeys {
   5|     static let suggestionsOn = "retold.suggestionsOn"
   6| }
   7| 
   8| struct SettingsView: View {
   9|     let files: CaptureFiles
  10| 
  11|     @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
  12|     @Environment(\.modelContext) private var modelContext
  13|     @Environment(\.dismiss) private var dismiss
  14| 
  15|     private enum ExportState {
  16|         case idle
  17|         case preparing
  18|         case ready(URL)
  19|         case failed
  20|     }
  21| 
  22|     @State private var exportState = ExportState.idle
  23| 
  24|     var body: some View {
  25|         NavigationStack {
  26|             Form {
  27|                 Section {
  28|                     Toggle(AppCopy.suggestionsToggle, isOn: $suggestionsOn)
  29|                     Text(AppCopy.suggestionsFootnote)
  30|                         .font(.footnote)
  31|                         .foregroundStyle(.secondary)
  32|                 }
  33|                 Section {
  34|                     switch exportState {
  35|                     case .idle, .failed:
  36|                         Button(AppCopy.exportButton) {
  37|                             startExport()
  38|                         }
  39|                     case .preparing:
  40|                         HStack {
  41|                             ProgressView()
  42|                             Text(AppCopy.preparingExport)
  43|                         }
  44|                     case .ready(let url):
  45|                         ShareLink(item: url) {
  46|                             Text(AppCopy.shareExport)
  47|                         }
  48|                     }
  49|                     if case .failed = exportState {
  50|                         Text(AppCopy.exportFailed)
  51|                             .font(.footnote)
  52|                             .foregroundStyle(.secondary)
  53|                     }
  54|                     Text(AppCopy.exportNote)
  55|                         .font(.footnote)
  56|                         .foregroundStyle(.secondary)
  57|                 }
  58|             }
  59|             .navigationTitle(AppCopy.settingsTitle)
  60|             .toolbar {
  61|                 ToolbarItem(placement: .confirmationAction) {
  62|                     Button(AppCopy.doneButton) { dismiss() }
  63|                 }
  64|             }
  65|         }
  66|     }
  67| 
  68|     /// Builds the manifest on the main actor, then zips off it. Export is never gated.
  69|     /// SwiftData models are not Sendable, so the fetch stays on the main actor; yielding first lets
  70|     /// the "preparing" state paint before a large library blocks the thread.
  71|     private func startExport() {
  72|         exportState = .preparing
  73|         Task { @MainActor in
  74|             await Task.yield()
  75|             runExport()
  76|         }
  77|     }
  78| 
  79|     private func runExport() {
  80|         let manifest: ExportManifest
  81|         do {
  82|             let periods = try modelContext.fetch(FetchDescriptor<Period>())
  83|             let episodes = try modelContext.fetch(FetchDescriptor<Episode>())
  84|             let captures = try modelContext.fetch(FetchDescriptor<Capture>())
  85|             let questions = try modelContext.fetch(FetchDescriptor<Question>())
  86|             let library = ExportLibrary(
  87|                 periods: periods, episodes: episodes, captures: captures, questions: questions)
  88|             manifest = ExportManifest.build(library, exportedAt: Date(), timeZone: .current)
  89|         } catch {
  90|             exportState = .failed
  91|             return
  92|         }
  93|         let audioDirectory = files.audioDirectory
  94|         let workDirectory = ExportArchiver.defaultWorkDirectory
  95|         let name = ExportArchiver.exportName(at: Date())
  96|         Task { @MainActor in
  97|             do {
  98|                 let url = try await Task.detached {
  99|                     try ExportArchiver.makeArchive(
 100|                         manifest, audioDirectory: audioDirectory, workDirectory: workDirectory, name: name)
 101|                 }.value
 102|                 exportState = .ready(url)
 103|             } catch {
 104|                 exportState = .failed
 105|             }
 106|         }
 107|     }
 108| }
 109| 
```


### Retold/Playback/AudioPlayback.swift
```
   1| import AVFoundation
   2| import Foundation
   3| import Observation
   4| 
   5| /// The one shared audio player (R7b section 2). A thin device adapter over AVAudioPlayer, so it
   6| /// has no unit tests; the device sitting checks it. One instance lives in RootView.
   7| @MainActor @Observable
   8| final class AudioPlayback {
   9|     private(set) var captureID: UUID?          // the loaded capture, nil when stopped
  10|     private(set) var isPlaying = false
  11|     private(set) var currentTime: TimeInterval = 0
  12|     private(set) var duration: TimeInterval = 0
  13| 
  14|     @ObservationIgnored private let files: CaptureFiles
  15|     @ObservationIgnored private var player: AVAudioPlayer?
  16|     @ObservationIgnored private var updateTask: Task<Void, Never>?
  17| 
  18|     init(files: CaptureFiles) {
  19|         self.files = files
  20|     }
  21| 
  22|     /// The audio file exists. One FileManager call, cheap enough per row.
  23|     func canPlay(_ captureID: UUID) -> Bool {
  24|         FileManager.default.fileExists(atPath: files.audioURL(for: captureID).path)
  25|     }
  26| 
  27|     /// Plays `captureID`, from `time` if given. The same capture, loaded and paused, resumes
  28|     /// (seeking first if `time` is given); a different capture loaded is stopped first. Any
  29|     /// failure (a missing file, a decode failure, a session error) stops quietly: no alert.
  30|     func play(_ captureID: UUID, from time: TimeInterval? = nil) {
  31|         if self.captureID == captureID, let player {
  32|             if let time { seek(to: time) }
  33|             guard player.play() else {
  34|                 stop()
  35|                 return
  36|             }
  37|             isPlaying = true
  38|             currentTime = player.currentTime
  39|             startUpdates()
  40|             return
  41|         }
  42|         if self.captureID != nil {
  43|             stop(deactivateSession: false)
  44|         }
  45|         do {
  46|             // The URL is always files.audioURL(for:); nothing else builds an audio path.
  47|             let newPlayer = try AVAudioPlayer(contentsOf: files.audioURL(for: captureID))
  48|             self.player = newPlayer
  49|             self.captureID = captureID
  50|             duration = newPlayer.duration
  51|             let session = AVAudioSession.sharedInstance()
  52|             try session.setCategory(.playback)
  53|             try session.setActive(true)
  54|             if let time {
  55|                 newPlayer.currentTime = min(max(time, 0), newPlayer.duration)
  56|             }
  57|             guard newPlayer.play() else {
  58|                 stop()
  59|                 return
  60|             }
  61|             isPlaying = true
  62|             currentTime = newPlayer.currentTime
  63|             startUpdates()
  64|         } catch {
  65|             stop()
  66|         }
  67|     }
  68| 
  69|     /// Cancels the update task and keeps the capture loaded.
  70|     func pause() {
  71|         guard let player else { return }
  72|         updateTask?.cancel()
  73|         updateTask = nil
  74|         player.pause()
  75|         isPlaying = false
  76|         currentTime = player.currentTime
  77|     }
  78| 
  79|     /// Clamps to 0...duration.
  80|     func seek(to time: TimeInterval) {
  81|         guard let player else { return }
  82|         let clamped = min(max(time, 0), duration)
  83|         player.currentTime = clamped
  84|         currentTime = clamped
  85|     }
  86| 
  87|     /// Strictly a no-op when nothing is loaded: it touches neither the session nor any property.
  88|     /// Otherwise it stops the player, cancels the update task, resets every property and, if
  89|     /// `deactivateSession`, deactivates the session (ignoring the error).
  90|     func stop(deactivateSession: Bool = true) {
  91|         guard captureID != nil else { return }
  92|         player?.stop()
  93|         player = nil
  94|         updateTask?.cancel()
  95|         updateTask = nil
  96|         captureID = nil
  97|         isPlaying = false
  98|         currentTime = 0
  99|         duration = 0
 100|         if deactivateSession {
 101|             try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
 102|         }
 103|     }
 104| 
 105|     /// One task updates currentTime every 0.25 s while playing. Seeing the player stopped without a
 106|     /// pause() call (pause cancels this task) means it reached the end.
 107|     private func startUpdates() {
 108|         updateTask?.cancel()
 109|         updateTask = Task { [weak self] in
 110|             while !Task.isCancelled {
 111|                 try? await Task.sleep(for: .milliseconds(250))
 112|                 guard !Task.isCancelled, let self, let player = self.player else { return }
 113|                 if player.isPlaying {
 114|                     self.currentTime = player.currentTime
 115|                 } else {
 116|                     self.stop()
 117|                     return
 118|                 }
 119|             }
 120|         }
 121|     }
 122| }
 123| 
```


### Retold/Capture/CaptureCoordinator.swift
```
   1| import Foundation
   2| import Observation
   3| import SwiftData
   4| 
   5| // Owns the recorder loop: reduces engine events through RecorderMachine, runs journal effects
   6| // synchronously in a FIFO drain, and hands engine effects to one serial task so a pause can never
   7| // overtake a start. The store is touched only inside importJournals/retranscribePending and only
   8| // while protectedDataAvailable.
   9| 
  10| /// ?7a: recorded-time thresholds for one capture. Time spent interrupted does not count.
  11| /// Injectable so tests can run the real timer in milliseconds.
  12| struct CaptureLengthLimits: Equatable, Sendable {
  13|     var warning: TimeInterval
  14|     var limit: TimeInterval
  15| 
  16|     static let standard = CaptureLengthLimits(warning: 20 * 60, limit: 30 * 60)
  17| }
  18| 
  19| @MainActor @Observable
  20| final class CaptureCoordinator {
  21|     private(set) var state: RecorderState
  22|     private(set) var liveText: String = ""        // UI only: journaled finals joined by " " + current volatile; reset at startEngine
  23|     private(set) var journalError: Error?         // last journal failure, for the UI
  24|     private(set) var startFailure: String?        // why the last start failed, for the UI alert
  25|     private(set) var processedEventCount = 0      // incremented after each handled event (tests)
  26|     private(set) var lastImport: JournalImporter.Report?
  27|     private(set) var lengthWarning = false        // ?7a: the recorder screen's banner, from limits.warning
  28| 
  29|     let files: CaptureFiles
  30|     let importer: JournalImporter
  31| 
  32|     @ObservationIgnored private let engine: any CaptureEngine
  33|     @ObservationIgnored private let fileTranscriber: any FileTranscriber
  34|     @ObservationIgnored private let routeProvider: @Sendable () async -> TranscriptionRoute
  35|     @ObservationIgnored private let container: ModelContainer
  36|     @ObservationIgnored private let inbox: CaptureLaunchInbox
  37|     @ObservationIgnored private var startInFlight = false
  38|     @ObservationIgnored private let makeWriter: (CaptureFiles, UUID) throws -> any JournalAppending
  39|     @ObservationIgnored private let now: () -> Date
  40|     @ObservationIgnored private let newID: () -> UUID
  41|     @ObservationIgnored private let lengthLimits: CaptureLengthLimits
  42| 
  43|     @ObservationIgnored private var effectQueue: [RecorderEffect] = []
  44|     @ObservationIgnored private var isDraining = false
  45|     @ObservationIgnored private var writers: [UUID: any JournalAppending] = [:]
  46|     @ObservationIgnored private let effectContinuation: AsyncStream<RecorderEffect>.Continuation
  47|     @ObservationIgnored private var outstandingEngineCalls = 0
  48|     @ObservationIgnored private var filePassTask: Task<Void, Never>?
  49|     @ObservationIgnored private var rerunRequested = false
  50|     @ObservationIgnored private var journaledFinalTexts: [String] = []
  51|     @ObservationIgnored private var currentVolatile: String = ""
  52|     @ObservationIgnored private var degradedCaptures: Set<UUID> = []   // a journal append failed
  53|     @ObservationIgnored private var recordedBeforeSegment: TimeInterval = 0   // closed .recording stretches
  54|     @ObservationIgnored private var segmentStart: Date?                       // the open .recording stretch
  55|     @ObservationIgnored private var lengthTask: Task<Void, Never>?
  56|     @ObservationIgnored private var hasRun = false
  57| 
  58|     init(engine: any CaptureEngine,
  59|          fileTranscriber: any FileTranscriber,
  60|          routeProvider: @escaping @Sendable () async -> TranscriptionRoute,
  61|          files: CaptureFiles,
  62|          importer: JournalImporter,
  63|          container: ModelContainer,
  64|          initialPermission: MicrophonePermission,
  65|          protectedDataAvailable: Bool,
  66|          inbox: CaptureLaunchInbox = .shared,
  67|          makeWriter: @escaping (CaptureFiles, UUID) throws -> any JournalAppending,
  68|          now: @escaping () -> Date = Date.init,
  69|          newID: @escaping () -> UUID = UUID.init,
  70|          lengthLimits: CaptureLengthLimits = .standard) {
  71|         self.engine = engine
  72|         self.fileTranscriber = fileTranscriber
  73|         self.routeProvider = routeProvider
  74|         self.files = files
  75|         self.importer = importer
  76|         self.container = container
  77|         self.inbox = inbox
  78|         self.makeWriter = makeWriter
  79|         self.now = now
  80|         self.newID = newID
  81|         self.lengthLimits = lengthLimits
  82|         self.state = RecorderState(permission: initialPermission,
  83|                                    protectedDataAvailable: protectedDataAvailable)
  84| 
  85|         let (stream, continuation) = AsyncStream<RecorderEffect>.makeStream()
  86|         self.effectContinuation = continuation
  87|         // One serial consumer: engine effects are awaited one at a time, in order.
  88|         Task { [weak self] in
  89|             for await effect in stream {
  90|                 guard let self else { return }
  91|                 await self.performEngineEffect(effect)
  92|             }
  93|         }
  94| 
  95|         inbox.onRequest = { [weak self] in
  96|             Task { await self?.drainLaunchInbox() }
  97|         }
  98|     }
  99| 
 100|     /// The capture ID of the active phase, if any (excluded from import and the file pass).
 101|     var activeCaptureID: UUID? {
 102|         switch state.phase {
 103|         case .starting(let id, _), .recording(let id), .interrupted(let id),
 104|              .stopping(let id, _), .aborting(let id):
 105|             return id
 106|         case .idle, .blocked:
 107|             return nil
 108|         }
 109|     }
 110| 
 111|     // MARK: - Event intake
 112| 
 113|     /// files.prepare(); then, if protectedDataAvailable, one import + file pass; then
 114|     /// `for await e in engine.events { handle(e) }`. Returns when the stream finishes.
 115|     func run() async {
 116|         // engine.events has a single consumer; a re-created view's .task must not start a second loop.
 117|         guard !hasRun else { return }
 118|         hasRun = true
 119|         try? files.prepare()
 120|         if state.protectedDataAvailable {
 121|             lastImport = importer.importAll(into: container, excluding: activeCaptureID)
 122|             // In the background: an Action press during a long launch pass must not wait on it.
 123|             kickFilePass()
 124|         }
 125|         for await event in engine.events {
 126|             handle(event)
 127|         }
 128|     }
 129| 
 130|     func handle(_ event: CaptureEngineEvent) {
 131|         switch event {
 132|         case .recorder(let recorderEvent):
 133|             if case .engineStartFailed = recorderEvent {
 134|                 startFailure = engine.lastStartFailure ?? "unknown"
 135|             }
 136|             send(recorderEvent)
 137|         case .volatile(_, let text):
 138|             currentVolatile = text
 139|             rebuildLiveText()
 140|         }
 141|     }
 142| 
 143|     /// reduce, enqueue effects, drain.
 144|     func send(_ event: RecorderEvent) {
 145|         let oldPhase = state.phase
 146|         let (newState, effects) = RecorderMachine.reduce(state, event, now: now(), newID: newID)
 147|         state = newState
 148|         updateLengthTimer(from: oldPhase)
 149|         processedEventCount += 1
 150|         effectQueue.append(contentsOf: effects)
 151|         drain()
 152|     }
 153| 
 154|     /// Awaits until the effect queue is empty and every engine call has returned (tests).
 155|     func drainEffects() async {
 156|         var iterations = 0
 157|         while (isDraining || !effectQueue.isEmpty || outstandingEngineCalls > 0) && iterations < 10_000 {
 158|             await Task.yield()
 159|             iterations += 1
 160|         }
 161|     }
 162| 
 163|     // MARK: - Effect queue
 164| 
 165|     /// FIFO drain. A send made during a drain only enqueues. Journal effects run synchronously;
 166|     /// engine effects are handed to the one serial effect task.
 167|     private func drain() {
 168|         guard !isDraining else { return }
 169|         isDraining = true
 170|         while !effectQueue.isEmpty {
 171|             let effect = effectQueue.removeFirst()
 172|             switch effect {
 173|             case .openJournal(let captureID):
 174|                 do {
 175|                     writers[captureID] = try makeWriter(files, captureID)
 176|                 } catch {
 177|                     // The audio survives and pass 2 adopts it; stop cleanly.
 178|                     journalError = error
 179|                     send(.tapStop)
 180|                 }
 181|             case .journal(var record):
 182|                 guard let writer = writers[record.captureID] else { continue }
 183|                 if record.kind == .transcriberEnded, degradedCaptures.contains(record.captureID) {
 184|                     record.completed = false     // a segment may be missing: force the file pass
 185|                 }
 186|                 do {
 187|                     try writer.append(record)
 188|                     if record.kind == .segment, let text = record.text {
 189|                         journaledFinalTexts.append(text)
 190|                         rebuildLiveText()
 191|                     }
 192|                 } catch {
 193|                     journalError = error        // the audio is the record; recording continues
 194|                     degradedCaptures.insert(record.captureID)
 195|                 }
 196|             case .closeJournal(let captureID):
 197|                 writers[captureID]?.close()
 198|                 writers[captureID] = nil
 199|                 degradedCaptures.remove(captureID)
 200|             case .importJournals:
 201|                 guard state.protectedDataAvailable else { continue }
 202|                 lastImport = importer.importAll(into: container, excluding: activeCaptureID)
 203|                 kickFilePass()
 204|             case .startEngine, .pauseEngine, .resumeEngine, .stopEngine:
 205|                 outstandingEngineCalls += 1
 206|                 effectContinuation.yield(effect)
 207|             }
 208|         }
 209|         isDraining = false
 210|     }
 211| 
 212|     private func performEngineEffect(_ effect: RecorderEffect) async {
 213|         switch effect {
 214|         case .startEngine(let captureID, let route):
 215|             do {
 216|                 try files.prepare()
 217|             } catch {
 218|                 journalError = error
 219|                 startFailure = String(describing: error)
 220|                 send(.engineStartFailed(captureID: captureID))
 221|                 outstandingEngineCalls -= 1
 222|                 return
 223|             }
 224|             journaledFinalTexts = []
 225|             currentVolatile = ""
 226|             liveText = ""
 227|             await engine.start(captureID: captureID, audioURL: files.audioURL(for: captureID), route: route)
 228|         case .pauseEngine(let captureID):
 229|             await engine.pause(captureID: captureID)
 230|         case .resumeEngine(let captureID):
 231|             await engine.resume(captureID: captureID)
 232|         case .stopEngine(let captureID):
 233|             await engine.stop(captureID: captureID)
 234|         case .openJournal, .journal, .closeJournal, .importJournals:
 235|             break   // handled synchronously in the drain
 236|         }
 237|         outstandingEngineCalls -= 1
 238|     }
 239| 
 240|     private func rebuildLiveText() {
 241|         let joined = journaledFinalTexts.joined(separator: " ")
 242|         liveText = joined.isEmpty ? currentVolatile
 243|             : (currentVolatile.isEmpty ? joined : joined + " " + currentVolatile)
 244|     }
 245| 
 246|     // MARK: - Length limit (?7a)
 247| 
 248|     private static func isRecording(_ phase: RecorderPhase) -> Bool {
 249|         if case .recording = phase { return true }
 250|         return false
 251|     }
 252| 
 253|     /// Counts recorded time only: a stretch opens on entering .recording and closes on leaving it,
 254|     /// so .interrupted time does not count. A new capture (.starting) resets the count and the banner.
 255|     private func updateLengthTimer(from oldPhase: RecorderPhase) {
 256|         let wasRecording = Self.isRecording(oldPhase)
 257|         let isRecording = Self.isRecording(state.phase)
 258|         if case .starting = state.phase {
 259|             recordedBeforeSegment = 0
 260|             segmentStart = nil
 261|             lengthWarning = false
 262|         }
 263|         if wasRecording && !isRecording {
 264|             if let start = segmentStart {
 265|                 recordedBeforeSegment += max(0, now().timeIntervalSince(start))
 266|             }
 267|             segmentStart = nil
 268|             lengthTask?.cancel()
 269|             lengthTask = nil
 270|         }
 271|         if !wasRecording && isRecording {
 272|             segmentStart = now()
 273|             scheduleLengthTimer()
 274|         }
 275|         if state.phase == .idle {
 276|             lengthWarning = false
 277|         }
 278|     }
 279| 
 280|     /// One task per .recording stretch, sleeping only for the time left. Cancelled when the stretch closes.
 281|     private func scheduleLengthTimer() {
 282|         lengthTask?.cancel()
 283|         let recorded = recordedBeforeSegment
 284|         let limits = lengthLimits
 285|         lengthTask = Task { [weak self] in
 286|             let untilWarning = limits.warning - recorded
 287|             if untilWarning > 0 {
 288|                 try? await Task.sleep(for: .seconds(untilWarning))
 289|                 if Task.isCancelled { return }
 290|             }
 291|             guard let self else { return }
 292|             self.lengthWarning = true
 293|             let untilLimit = limits.limit - max(recorded, limits.warning)
 294|             if untilLimit > 0 {
 295|                 try? await Task.sleep(for: .seconds(untilLimit))
 296|                 if Task.isCancelled { return }
 297|             }
 298|             self.send(.timeLimitReached)
 299|         }
 300|     }
 301| 
 302|     // MARK: - Launch inbox and capture start
 303| 
 304|     /// Refreshes the permission, the route (routeProvider), then takes the inbox; if a start was
 305|     /// pending, sends startRequested(answering: nil). Called on sceneDidBecomeActive and by the
 306|     /// inbox's onRequest hook.
 307|     func drainLaunchInbox() async {
 308|         send(.permissionChanged(await engine.microphonePermission()))
 309|         send(.routeChanged(await routeProvider()))
 310|         if inbox.take() {
 311|             send(.startRequested(answering: nil))
 312|         }
 313|     }
 314| 
 315|     /// The UI shows startFailure once, then clears it.
 316|     func clearStartFailure() {
 317|         startFailure = nil
 318|     }
 319| 
 320|     /// In-app Record button: refresh route, then send.
 321|     func startCapture(answering: UUID?) async {
 322|         // The route lookup suspends. A second tap in that gap would reach the reducer as a second
 323|         // startRequested, which ?7a reads as "stop as soon as it starts": the capture would start
 324|         // and end at once. In-app taps are single-flight; the Action button sends the event directly.
 325|         guard !startInFlight else { return }
 326|         startInFlight = true
 327|         defer { startInFlight = false }
 328|         send(.routeChanged(await routeProvider()))
 329|         send(.startRequested(answering: answering))
 330|     }
 331| 
 332|     // MARK: - File pass
 333| 
 334|     /// File pass over every Capture with status .live, .pending or .fromFile whose audio exists,
 335|     /// excluding the active capture. Single-flight: a call made while the pass runs sets
 336|     /// rerunRequested and the running pass loops once more. Only while protectedDataAvailable.
 337|     func retranscribePending() async {
 338|         kickFilePass()
 339|         await awaitFilePass()
 340|     }
 341| 
 342|     /// Synchronous single-flight start: requests a (re)run and creates the pass task if none is
 343|     /// running. The task clears filePassTask itself, with no suspension between its last rerun
 344|     /// check and the clear, so a request can never be lost.
 345|     private func kickFilePass() {
 346|         guard state.protectedDataAvailable else { return }
 347|         rerunRequested = true
 348|         guard filePassTask == nil else { return }
 349|         filePassTask = Task { [weak self] in
 350|             guard let self else { return }
 351|             while self.rerunRequested && self.state.protectedDataAvailable {
 352|                 self.rerunRequested = false
 353|                 await self.performOneFilePass()
 354|             }
 355|             self.filePassTask = nil
 356|         }
 357|     }
 358| 
 359|     /// Awaits the running file pass, if any (tests; launch runs the pass in the background).
 360|     func awaitFilePass() async {
 361|         while let task = filePassTask { await task.value }
 362|     }
 363| 
 364|     private func performOneFilePass() async {
 365|         guard state.protectedDataAvailable else { return }
 366|         let scan = ModelContext(container)
 367|         guard let captures = try? scan.fetch(FetchDescriptor<Capture>()) else { return }
 368|         let candidateIDs = captures
 369|             .filter { [TranscriptionStatus.live, .pending, .fromFile].contains($0.transcriptionStatus) }
 370|             .filter { $0.id != activeCaptureID }
 371|             .filter { $0.corrections.isEmpty }               // correction indices point at current segments
 372|             .filter { FileManager.default.fileExists(atPath: files.audioURL(for: $0.id).path) }
 373|             .map(\.id)
 374|         for captureID in candidateIDs {
 375|             guard state.protectedDataAvailable else { return }  // re-checked after every await
 376|             let route = await routeProvider()
 377|             guard state.protectedDataAvailable else { return }
 378|             if case .audioOnly = route { continue }          // stays .live for a later pass
 379|             var segments: [TranscriptSegment]? = []
 380|             do {
 381|                 for try await segment in fileTranscriber.transcribe(
 382|                     audioURL: files.audioURL(for: captureID), route: route
 383|                 ) {
 384|                     segments?.append(segment)
 385|                 }
 386|             } catch {
 387|                 segments = nil
 388|             }
 389|             // The phone may have locked during the transcription: never touch the store then.
 390|             guard state.protectedDataAvailable else { return }
 391|             Self.applyFilePassResult(captureID: captureID, segments: segments, in: container)
 392|         }
 393|     }
 394| 
 395|     /// Writes one file-pass result to the capture, fetched in a fresh context with no suspension
 396|     /// between the fetch and the save. A capture object held across the transcription's awaits would
 397|     /// be a stale snapshot, and saving it would overwrite a main-context write made meanwhile, such as
 398|     /// R7b's AnswerAttacher setting capture.episode. Every writer is on the main actor, so nothing
 399|     /// interleaves here. `segments` nil = the transcription threw. Does nothing unless the capture is
 400|     /// still .live, .pending or .fromFile with no corrections.
 401|     static func applyFilePassResult(captureID: UUID, segments: [TranscriptSegment]?, in container: ModelContainer) {
 402|         let context = ModelContext(container)
 403|         context.autosaveEnabled = false
 404|         let wantedID = captureID
 405|         var descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.id == wantedID })
 406|         descriptor.fetchLimit = 1
 407|         guard let capture = (try? context.fetch(descriptor))?.first,
 408|               [TranscriptionStatus.live, .pending, .fromFile].contains(capture.transcriptionStatus),
 409|               capture.corrections.isEmpty
 410|         else { return }
 411|         let current = capture.transcript
 412|         do {
 413|             if let segments, !segments.isEmpty {
 414|                 try capture.completeTranscript(segments)     // the file is authoritative
 415|             } else if segments != nil, current.isEmpty {
 416|                 try capture.completeTranscript([])           // silence is a complete transcript
 417|             } else {
 418|                 try capture.updateTranscript(current, status: .failed)  // keep the partial
 419|             }
 420|             try context.save()
 421|         } catch {
 422|             context.rollback()
 423|         }
 424|     }
 425| }
 426| 
```


### Retold/Copy/AppCopy.swift
```
   1| import Foundation
   2| 
   3| /// The user-facing strings PLAN already fixes, verbatim, so WellnessLint has real copy to
   4| /// check before any string catalog exists. Not wired to any view in R3.
   5| enum AppCopy {
   6|     /// PLAN section 8: why suggestions are unavailable on a phone without Apple Intelligence.
   7|     static let newerPhoneReason = "Suggestions need a newer iPhone; everything else works"
   8|     /// PLAN section 8: why suggestions are unavailable while Apple Intelligence is off.
   9|     static let appleIntelligenceOffReason = "Turn on Apple Intelligence in Settings to get suggested questions"
  10|     /// PLAN section 8: why suggestions are unavailable while models are downloading.
  11|     static let modelsDownloadingReason = "Suggestions will appear once your phone finishes downloading them"
  12| 
  13|     /// PLAN section 7: the line that reinstates an interrupted open question.
  14|     static let reinstatement = "Take a second. Where were you, what time of year, who was around \u{2014} then talk."
  15|     /// PLAN section 5.2: the nudge notification body.
  16|     static let nudgeWaiting = "One question waiting"
  17|     /// PLAN section 9: the fallback explanation for unsupported phones.
  18|     static let fallback = "Suggested questions use Apple Intelligence on supported iPhones; recording, filing and browsing work on every iPhone running iOS 26."
  19| 
  20|     /// R6b: first-run microphone prompt.
  21|     static let micPrompt = "Retold records your voice while you talk through a memory."
  22|     /// R6b: first-run grant button.
  23|     static let micAllow = "Allow microphone"
  24|     /// R6b: shown when the microphone grant is denied.
  25|     static let micDenied = "Microphone access is off. Turn it on in Settings to record."
  26|     /// R6b: home screen record button.
  27|     static let recordButton = "Record a memory"
  28|     /// R6b: recorder stop button.
  29|     static let stopButton = "Stop"
  30|     /// R6b: recorder resume button while interrupted.
  31|     static let resumeButton = "Resume"
  32|     /// R6b: recorder state label while recording.
  33|     static let recordingLabel = "Recording"
  34|     /// Recorder state label while the engine is starting, before audio is captured.
  35|     static let startingLabel = "Getting ready..."
  36|     /// Recorder state label while the file is being finalized after Stop.
  37|     static let savingLabel = "Saving..."
  38|     /// VoiceOver label for the playback scrubber.
  39|     static let playbackPosition = "Playback position"
  40|     /// VoiceOver label prefix for a remove (trash) button; the item name follows.
  41|     static let removeLabel = "Remove"
  42|     /// Settings sheet dismiss button.
  43|     static let doneButton = "Done"
  44|     /// Confirm flow: why File it is unavailable.
  45|     static let titleNeededHint = "Add a title to file this memory."
  46|     /// R6b: recorder state label while interrupted.
  47|     static let pausedLabel = "Paused"
  48|     /// R6b: the store failed to open at launch.
  49|     static let startupFailed = "Retold could not open its storage. Restart the app to try again."
  50|     /// R6b: home screen title (the week-0 scaffold's, moved here so views carry no literals).
  51|     static let homeTitle = "Retold"
  52|     /// R6b spec 7a: the recorder banner after 20 minutes of recording.
  53|     static let lengthWarning = "Retold stops this recording at 30 minutes."
  54| 
  55|     /// R7a: heading for captures that have not been filed.
  56|     static let unfiledHeader = "Unfiled"
  57|     /// R7a: state shown while a capture is being transcribed.
  58|     static let transcribingLabel = "Transcribing..."
  59|     /// R7a: state shown when a capture has no transcript.
  60|     static let noTranscriptLabel = "No transcript - you can still file it"
  61|     /// R7a: confirm-flow filing action.
  62|     static let fileButton = "File it"
  63|     /// R7a: label for an unaccepted suggestion.
  64|     static let suggestedLabel = "suggested"
  65|     /// R7a: accepts a suggested value.
  66|     static let acceptButton = "Use this"
  67|     /// R7a: rejects a suggested value.
  68|     static let rejectButton = "Not this"
  69|     /// R7a: confirm-flow title section.
  70|     static let titleHeader = "Title"
  71|     /// R7a: prompt for a user-authored title.
  72|     static let titlePlaceholder = "Type a title"
  73|     /// R7a: confirm-flow period section.
  74|     static let periodHeader = "Period"
  75|     /// R7a: period picker option for no period.
  76|     static let noPeriod = "Not in a period"
  77|     /// R7a: period picker option for a new period.
  78|     static let newPeriod = "New period..."
  79|     /// R7a: prompt for a new period title.
  80|     static let newPeriodPlaceholder = "Name the period"
  81|     /// R7a: confirm-flow when section.
  82|     static let whenHeader = "When"
  83|     /// R7a: year mode for the when answer.
  84|     static let whenYear = "Year"
  85|     /// R7a: age mode for the when answer.
  86|     static let whenAge = "Age"
  87|     /// R7a: action for leaving the when answer open.
  88|     static let notSure = "Not sure"
  89|     /// R7a: confirm-flow people section.
  90|     static let peopleHeader = "People"
  91|     /// R7a: confirm-flow place section.
  92|     static let placesHeader = "Place"
  93|     /// R7a: action for adding a person.
  94|     static let addPerson = "Add a person"
  95|     /// R7a: action for adding a place.
  96|     static let addPlace = "Add a place"
  97|     /// R7a: prefix for reusing an existing entity.
  98|     static let sameAs = "Same as"
  99|     /// R7a: option for creating a person.
 100|     static let newPerson = "New person"
 101|     /// R7a: option for creating a place.
 102|     static let newPlace = "New place"
 103|     /// R7a: confirm-flow follow-up section.
 104|     static let followUpsHeader = "Questions for later"
 105|     /// R7a: keeps a follow-up question open.
 106|     static let later = "Later"
 107|     /// R7a: retires a follow-up question.
 108|     static let notThisOne = "Not this one"
 109|     /// R7a: progress copy while suggestions are generated.
 110|     static let findingSuggestions = "Looking for names and places..."
 111|     /// R7a: action for cancelling suggestion generation.
 112|     static let skipSuggestions = "Skip suggestions"
 113|     /// R7a: settings screen title.
 114|     static let settingsTitle = "Settings"
 115|     /// R7a: setting that enables filing suggestions.
 116|     static let suggestionsToggle = "Suggestions"
 117|     /// R7a: explanation of where suggestions are generated.
 118|     static let suggestionsFootnote = "Suggestions are made on this iPhone."
 119| 
 120|     /// R7b: title shown for an episode whose title is not confirmed.
 121|     static let untitled = "Untitled"
 122|     /// R7b: title of the Places list.
 123|     static let placesTitle = "Places"
 124|     /// R7b: title of the Themes page.
 125|     static let themesTitle = "Themes"
 126|     /// R7b: title of the Periods page.
 127|     static let periodsTitle = "Periods"
 128|     /// R7b: action for adding a period.
 129|     static let addPeriod = "Add a period"
 130|     /// R7b: action for renaming a period.
 131|     static let renamePeriod = "Rename"
 132|     /// R7b: footnote shown when a period title is a duplicate.
 133|     static let duplicatePeriod = "There is already a period with that name."
 134|     /// R7b: save action in the period sheet.
 135|     static let saveButton = "Save"
 136|     /// R7b: cancel action in the period sheet.
 137|     static let cancelButton = "Cancel"
 138|     /// Empty page: title when a page has no questions and no stories yet.
 139|     static let emptyTitle = "Nothing here yet"
 140|     /// Empty page: the one action, to leave an empty page.
 141|     static let goBack = "Go back"
 142|     /// Empty period page: what will appear.
 143|     static let emptyPeriodMessage = "Stories you file under this period will appear here."
 144|     /// Empty person page: what will appear.
 145|     static let emptyPersonMessage = "Stories that mention this person will appear here."
 146|     /// Empty place page: what will appear.
 147|     static let emptyPlaceMessage = "Stories filed at this place will appear here."
 148|     /// Empty People list: title.
 149|     static let noPeopleTitle = "No people yet"
 150|     /// Empty People list: what will appear.
 151|     static let noPeopleMessage = "People you confirm while filing a story will appear here."
 152|     /// Empty Places list: title.
 153|     static let noPlacesTitle = "No places yet"
 154|     /// Empty Places list: what will appear.
 155|     static let noPlacesMessage = "Places you confirm while filing a story will appear here."
 156|     /// Themes page: title when every question has been answered or set aside.
 157|     static let themesEmptyTitle = "All caught up"
 158|     /// Themes page: why the list is empty and what brings questions back.
 159|     static let themesEmptyMessage = "You have been through every question for now. New ones appear as you record more memories."
 160|     /// Alert title when recording cannot start because the microphone is off.
 161|     static let micBlockedTitle = "Microphone is off"
 162|     /// Alert action that opens the iOS Settings page for this app.
 163|     static let openSettings = "Open Settings"
 164|     /// Alert title when a question action could not be saved.
 165|     static let saveFailedTitle = "That did not save"
 166|     /// Alert message when a question action could not be saved.
 167|     static let saveFailedMessage = "Try again in a moment."
 168|     /// Alert dismiss button.
 169|     static let okButton = "OK"
 170|     /// Set-aside page: title, also the Home link.
 171|     static let setAsideTitle = "Set-aside questions"
 172|     /// Set-aside page: empty title.
 173|     static let setAsideEmptyTitle = "Nothing set aside"
 174|     /// Set-aside page: empty message.
 175|     static let setAsideEmptyMessage = "Questions you choose Not this one on appear here, so you can bring them back."
 176|     /// Set-aside page: action that reopens a question.
 177|     static let bringBack = "Bring back"
 178|     /// Alert title when a recording could not start.
 179|     static let startFailedTitle = "Recording could not start"
 180|     /// Alert message prefix; the technical detail follows it.
 181|     static let startFailedMessage = "Nothing was recorded. Close Retold and try again. Details: "
 182|     /// R7b: heading for the open questions on a page.
 183|     static let questionsHeader = "Questions"
 184|     /// R7b: action for answering a question by recording.
 185|     static let answerNow = "Answer now"
 186|     /// R7b: heading for an episode's recordings.
 187|     static let recordingsHeader = "Recordings"
 188|     /// R7b: state shown when a recording has no transcript.
 189|     static let noTranscript = "No transcript"
 190|     /// R7b: state shown when a recording's audio file is gone.
 191|     static let audioMissing = "The recording file is missing."
 192|     /// R7b: play action.
 193|     static let playButton = "Play"
 194|     /// R7b: pause action.
 195|     static let pauseButton = "Pause"
 196|     /// R7b: recorder label while a capture answers a question.
 197|     static let answeringLabel = "Answering"
 198|     /// R7b: settings action that builds the export.
 199|     static let exportButton = "Export everything"
 200|     /// R7b: fixed line shown beside the export action.
 201|     static let exportNote = "Recordings may name other people."
 202|     /// R7b: progress copy while the export is built.
 203|     static let preparingExport = "Preparing the export..."
 204|     /// R7b: footnote shown when the export fails.
 205|     static let exportFailed = "The export could not be made. Try again."
 206|     /// R7b: label of the share link for a finished export.
 207|     static let shareExport = "Share the export"
 208|     /// R7c: swipe action that deletes an unfiled recording.
 209|     static let deleteAction = "Delete"
 210|     /// R7c: title of the delete confirmation.
 211|     static let deleteRecordingTitle = "Delete this recording?"
 212|     /// R7c: message of the delete confirmation.
 213|     static let deleteRecordingMessage = "The recording and its transcript will be removed from this phone. This can't be undone."
 214|     /// R7c: label of the confirming delete button.
 215|     static let deleteRecordingConfirm = "Delete recording"
 216|     /// R7c: alert shown when a delete fails.
 217|     static let deleteFailed = "The recording couldn't be deleted. Try again."
 218| 
 219|     static let all: [String] = [
 220|         newerPhoneReason,
 221|         appleIntelligenceOffReason,
 222|         modelsDownloadingReason,
 223|         reinstatement,
 224|         nudgeWaiting,
 225|         fallback,
 226|         micPrompt,
 227|         micAllow,
 228|         micDenied,
 229|         recordButton,
 230|         stopButton,
 231|         resumeButton,
 232|         recordingLabel,
 233|         startingLabel,
 234|         savingLabel,
 235|         playbackPosition,
 236|         removeLabel,
 237|         doneButton,
 238|         titleNeededHint,
 239|         pausedLabel,
 240|         startupFailed,
 241|         homeTitle,
 242|         lengthWarning,
 243|         unfiledHeader,
 244|         transcribingLabel,
 245|         noTranscriptLabel,
 246|         fileButton,
 247|         suggestedLabel,
 248|         acceptButton,
 249|         rejectButton,
 250|         titleHeader,
 251|         titlePlaceholder,
 252|         periodHeader,
 253|         noPeriod,
 254|         newPeriod,
 255|         newPeriodPlaceholder,
 256|         whenHeader,
 257|         whenYear,
 258|         whenAge,
 259|         notSure,
 260|         peopleHeader,
 261|         placesHeader,
 262|         addPerson,
 263|         addPlace,
 264|         sameAs,
 265|         newPerson,
 266|         newPlace,
 267|         followUpsHeader,
 268|         later,
 269|         notThisOne,
 270|         findingSuggestions,
 271|         skipSuggestions,
 272|         settingsTitle,
 273|         suggestionsToggle,
 274|         suggestionsFootnote,
 275|         untitled,
 276|         placesTitle,
 277|         themesTitle,
 278|         startFailedTitle,
 279|         startFailedMessage,
 280|         setAsideTitle,
 281|         setAsideEmptyTitle,
 282|         setAsideEmptyMessage,
 283|         bringBack,
 284|         micBlockedTitle,
 285|         openSettings,
 286|         saveFailedTitle,
 287|         saveFailedMessage,
 288|         okButton,
 289|         emptyTitle,
 290|         goBack,
 291|         emptyPeriodMessage,
 292|         emptyPersonMessage,
 293|         emptyPlaceMessage,
 294|         noPeopleTitle,
 295|         noPeopleMessage,
 296|         noPlacesTitle,
 297|         noPlacesMessage,
 298|         themesEmptyTitle,
 299|         themesEmptyMessage,
 300|         periodsTitle,
 301|         addPeriod,
 302|         renamePeriod,
 303|         duplicatePeriod,
 304|         saveButton,
 305|         cancelButton,
 306|         questionsHeader,
 307|         answerNow,
 308|         recordingsHeader,
 309|         noTranscript,
 310|         audioMissing,
 311|         playButton,
 312|         pauseButton,
 313|         answeringLabel,
 314|         exportButton,
 315|         exportNote,
 316|         preparingExport,
 317|         exportFailed,
 318|         shareExport,
 319|         deleteAction,
 320|         deleteRecordingTitle,
 321|         deleteRecordingMessage,
 322|         deleteRecordingConfirm,
 323|         deleteFailed,
 324|     ]
 325| }
 326| 
```


## Veteran counterparts (the bar), with line numbers


### BoardBound/components/question/OptionButton.tsx
```
   1| import { Pressable, Text, View } from "react-native";
   2| import Animated, {
   3|   useSharedValue,
   4|   useAnimatedStyle,
   5|   withSpring,
   6| } from "react-native-reanimated";
   7| import * as Haptics from "expo-haptics";
   8| import { Ionicons } from "@expo/vector-icons";
   9| import type { AnswerOption } from "../../lib/types/question";
  10| 
  11| interface OptionButtonProps {
  12|   option: AnswerOption;
  13|   isSelected: boolean;
  14|   isAnswered: boolean;
  15|   onPress: (optionId: string) => void;
  16|   index?: number;
  17| }
  18| 
  19| export function OptionButton({
  20|   option,
  21|   isSelected,
  22|   isAnswered,
  23|   onPress,
  24|   index,
  25| }: OptionButtonProps) {
  26|   const scale = useSharedValue(1);
  27| 
  28|   const animatedStyle = useAnimatedStyle(() => ({
  29|     transform: [{ scale: scale.value }],
  30|   }));
  31| 
  32|   const getStyle = () => {
  33|     if (!isAnswered) {
  34|       return isSelected
  35|         ? "border-brand-600 bg-brand-50 dark:bg-brand-950"
  36|         : "border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900";
  37|     }
  38|     if (option.isCorrect) {
  39|       return "border-green-500 bg-green-50 dark:bg-green-950";
  40|     }
  41|     if (isSelected && !option.isCorrect) {
  42|       return "border-red-500 bg-red-50 dark:bg-red-950";
  43|     }
  44|     return "border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 opacity-50";
  45|   };
  46| 
  47|   const getTextStyle = () => {
  48|     if (!isAnswered) {
  49|       return isSelected ? "text-brand-700 dark:text-brand-300" : "text-gray-700 dark:text-gray-300";
  50|     }
  51|     if (option.isCorrect) return "text-green-700 dark:text-green-300";
  52|     if (isSelected && !option.isCorrect) return "text-red-700 dark:text-red-300";
  53|     return "text-gray-500 dark:text-gray-400";
  54|   };
  55| 
  56|   const showIcon = isAnswered && (option.isCorrect || isSelected);
  57| 
  58|   const accessibilityLabel = isAnswered
  59|     ? `${option.text} - ${option.isCorrect ? "Correct answer" : isSelected ? "Your answer, incorrect" : "Not selected"}`
  60|     : option.text;
  61| 
  62|   const handlePress = () => {
  63|     if (!isAnswered) {
  64|       Haptics.selectionAsync();
  65|       onPress(option.id);
  66|     }
  67|   };
  68| 
  69|   const handlePressIn = () => {
  70|     if (!isAnswered) {
  71|       scale.value = withSpring(0.97, { damping: 15, stiffness: 300 });
  72|     }
  73|   };
  74| 
  75|   const handlePressOut = () => {
  76|     scale.value = withSpring(1, { damping: 15, stiffness: 300 });
  77|   };
  78| 
  79|   return (
  80|     <Animated.View style={animatedStyle} className="mb-3">
  81|       <Pressable
  82|         className={`flex-row items-center rounded-xl border-2 px-4 py-3.5 ${getStyle()}`}
  83|         onPress={handlePress}
  84|         onPressIn={handlePressIn}
  85|         onPressOut={handlePressOut}
  86|         disabled={isAnswered}
  87|         accessibilityRole="radio"
  88|         accessibilityState={{ checked: isSelected, disabled: isAnswered }}
  89|         accessibilityLabel={accessibilityLabel}
  90|       >
  91|         <Text className={`flex-1 text-base leading-5 ${getTextStyle()}`}>
  92|           {index != null ? `${String.fromCharCode(65 + index)}. ` : ""}{option.text}
  93|         </Text>
  94|         {showIcon && (
  95|           <View className="ml-2" accessibilityElementsHidden>
  96|             {option.isCorrect ? (
  97|               <Ionicons name="checkmark-circle" size={22} color="#22c55e" />
  98|             ) : (
  99|               <Ionicons name="close-circle" size={22} color="#ef4444" />
 100|             )}
 101|           </View>
 102|         )}
 103|       </Pressable>
 104|     </Animated.View>
 105|   );
 106| }
 107| 
```


### BoardBound/components/ui/StaggeredEntrance.tsx
```
   1| import { View, type ViewProps } from "react-native";
   2| import { Children, ReactNode } from "react";
   3| import Animated, { FadeInUp } from "react-native-reanimated";
   4| import { useReduceMotion } from "../../lib/hooks/useReduceMotion";
   5| 
   6| interface StaggeredEntranceProps extends ViewProps {
   7|   children: ReactNode;
   8|   /** Per-child delay in ms. Defaults to 75 (matches the prototype stagger). */
   9|   staggerMs?: number;
  10|   /** Each child's fade-in duration in ms. Defaults to 400. */
  11|   durationMs?: number;
  12|   /** Offset added to every child's delay in ms. */
  13|   initialDelayMs?: number;
  14| }
  15| 
  16| // Wraps each child in an Animated.View with fade-in-up + index-based
  17| // stagger. Used for Quiz reveal's four sections to give the "revealing
  18| // knowledge" feel from the prototype. Honors Reduce Motion: when enabled,
  19| // children render statically.
  20| export function StaggeredEntrance({
  21|   children,
  22|   staggerMs = 75,
  23|   durationMs = 400,
  24|   initialDelayMs = 0,
  25|   style,
  26|   ...rest
  27| }: StaggeredEntranceProps) {
  28|   const reduceMotion = useReduceMotion();
  29|   const items = Children.toArray(children);
  30| 
  31|   return (
  32|     <View style={style} {...rest}>
  33|       {items.map((child, i) => (
  34|         <Animated.View
  35|           key={i}
  36|           entering={
  37|             reduceMotion
  38|               ? undefined
  39|               : FadeInUp.duration(durationMs).delay(initialDelayMs + i * staggerMs)
  40|           }
  41|         >
  42|           {child}
  43|         </Animated.View>
  44|       ))}
  45|     </View>
  46|   );
  47| }
  48| 
```


### BoardBound/components/ui/Skeleton.tsx
```
   1| import Animated, {
   2|   useSharedValue,
   3|   useAnimatedStyle,
   4|   withRepeat,
   5|   withTiming,
   6|   Easing,
   7| } from "react-native-reanimated";
   8| import { useEffect } from "react";
   9| 
  10| interface SkeletonProps {
  11|   className?: string;
  12| }
  13| 
  14| export function Skeleton({ className = "" }: SkeletonProps) {
  15|   const opacity = useSharedValue(0.3);
  16| 
  17|   useEffect(() => {
  18|     opacity.value = withRepeat(
  19|       withTiming(0.7, { duration: 800, easing: Easing.inOut(Easing.ease) }),
  20|       -1,
  21|       true
  22|     );
  23|   }, [opacity]);
  24| 
  25|   const animatedStyle = useAnimatedStyle(() => ({
  26|     opacity: opacity.value,
  27|   }));
  28| 
  29|   return (
  30|     <Animated.View
  31|       style={animatedStyle}
  32|       className={`rounded-lg bg-gray-200 dark:bg-gray-700 ${className}`}
  33|       testID="skeleton"
  34|     />
  35|   );
  36| }
  37| 
```


### BoardBound/components/game/EarnToast.tsx
```
   1| import { useEffect } from "react";
   2| import { View, Text, AccessibilityInfo } from "react-native";
   3| import Animated, { FadeInDown, FadeOut } from "react-native-reanimated";
   4| import { Ionicons } from "@expo/vector-icons";
   5| import { useReduceMotion } from "../../lib/hooks/useReduceMotion";
   6| 
   7| interface EarnToastProps {
   8|   amount: number;
   9|   showAmount: boolean;
  10|   onDismiss: () => void;
  11|   visibleMs?: number;
  12| }
  13| 
  14| const DEFAULT_VISIBLE_MS = 1800;
  15| 
  16| export function EarnToast({
  17|   amount,
  18|   showAmount,
  19|   onDismiss,
  20|   visibleMs = DEFAULT_VISIBLE_MS,
  21| }: EarnToastProps) {
  22|   const reduceMotion = useReduceMotion();
  23| 
  24|   useEffect(() => {
  25|     const announcement = showAmount
  26|       ? `Correct - ${amount} ${amount === 1 ? "coin" : "coins"} earned`
  27|       : "Progress unlocked";
  28|     AccessibilityInfo.announceForAccessibility(announcement);
  29|   }, [amount, showAmount]);
  30| 
  31|   useEffect(() => {
  32|     const timer = setTimeout(onDismiss, visibleMs);
  33|     return () => clearTimeout(timer);
  34|   }, [onDismiss, visibleMs]);
  35| 
  36|   return (
  37|     <Animated.View
  38|       entering={reduceMotion ? undefined : FadeInDown.duration(200)}
  39|       exiting={reduceMotion ? undefined : FadeOut.duration(200)}
  40|       className="absolute left-0 right-0 top-2 items-center"
  41|       pointerEvents="none"
  42|       testID="earn-toast"
  43|     >
  44|       <View className="flex-row items-center rounded-full bg-amber-500 dark:bg-amber-600 px-4 py-2 shadow-lg">
  45|         <Ionicons name="trophy" size={16} color="#fff" />
  46|         <Text className="ml-2 text-sm font-semibold text-white">
  47|           {showAmount ? `+${amount} coins` : "Progress unlocked"}
  48|         </Text>
  49|       </View>
  50|     </Animated.View>
  51|   );
  52| }
  53| 
```


### BoardBound/components/BrandedSplash.tsx
```
   1| import { useEffect } from "react";
   2| import { View, Text, StatusBar } from "react-native";
   3| import { BrandMark } from "./ui/BrandMark";
   4| import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
   5| import { useReduceMotion } from "../lib/hooks/useReduceMotion";
   6| 
   7| export function BrandedSplash() {
   8|   const reduceMotion = useReduceMotion();
   9| 
  10|   useEffect(() => {
  11|     StatusBar.setBarStyle("light-content");
  12|     return () => StatusBar.setBarStyle("dark-content");
  13|   }, []);
  14| 
  15|   return (
  16|     <View className="flex-1 items-center justify-center bg-brand-600">
  17|       <Animated.View
  18|         entering={reduceMotion ? undefined : FadeInUp.duration(600)}
  19|         className="items-center"
  20|       >
  21|         <View className="mb-4 h-20 w-20 items-center justify-center rounded-2xl bg-white/20">
  22|           <BrandMark size={64} color="#ffffff" />
  23|         </View>
  24|         <Text className="text-3xl font-bold text-white">BoardBound</Text>
  25|       </Animated.View>
  26|       <Animated.Text
  27|         entering={reduceMotion ? undefined : FadeIn.duration(800).delay(300)}
  28|         className="mt-2 text-base text-white/80"
  29|       >
  30|         Smart FNP Board Prep
  31|       </Animated.Text>
  32|     </View>
  33|   );
  34| }
  35| 
```


### BoardBound/components/ErrorBoundary.tsx
```
   1| import React, { Component, type ErrorInfo, type ReactNode } from "react";
   2| import { View, Text, Pressable } from "react-native";
   3| import * as Sentry from "@sentry/react-native";
   4| 
   5| interface ErrorBoundaryProps {
   6|   children: ReactNode;
   7|   fallback?:
   8|     | ReactNode
   9|     | ((props: { error: Error; resetError: () => void }) => ReactNode);
  10|   onError?: (error: Error, errorInfo: ErrorInfo) => void;
  11|   onReset?: () => void;
  12| }
  13| 
  14| interface ErrorBoundaryState {
  15|   hasError: boolean;
  16|   error: Error | null;
  17| }
  18| 
  19| export class ErrorBoundary extends Component<
  20|   ErrorBoundaryProps,
  21|   ErrorBoundaryState
  22| > {
  23|   constructor(props: ErrorBoundaryProps) {
  24|     super(props);
  25|     this.state = { hasError: false, error: null };
  26|   }
  27| 
  28|   static getDerivedStateFromError(error: Error): ErrorBoundaryState {
  29|     return { hasError: true, error };
  30|   }
  31| 
  32|   componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
  33|     console.error("[BoardBound] Component error:", error.message);
  34|     Sentry.captureException(error, {
  35|       extra: { componentStack: errorInfo.componentStack },
  36|     });
  37|     this.props.onError?.(error, errorInfo);
  38|   }
  39| 
  40|   handleRetry = (): void => {
  41|     this.props.onReset?.();
  42|     this.setState({ hasError: false, error: null });
  43|   };
  44| 
  45|   render(): ReactNode {
  46|     if (!this.state.hasError) {
  47|       return this.props.children;
  48|     }
  49| 
  50|     if (typeof this.props.fallback === "function") {
  51|       return this.props.fallback({
  52|         error: this.state.error!,
  53|         resetError: this.handleRetry,
  54|       });
  55|     }
  56| 
  57|     if (this.props.fallback) {
  58|       return this.props.fallback;
  59|     }
  60| 
  61|     return (
  62|       <View className="flex-1 items-center justify-center bg-white dark:bg-gray-900 px-8">
  63|         <Text className="mb-2 text-4xl">?</Text>
  64|         <Text className="mb-2 text-xl font-bold text-gray-900 dark:text-gray-100">
  65|           Something went wrong
  66|         </Text>
  67|         <Text className="mb-6 text-center text-base text-gray-500 dark:text-gray-400">
  68|           An unexpected error occurred. Your study progress is saved locally and
  69|           will be available after recovery.
  70|         </Text>
  71| 
  72|         <Pressable
  73|           className="mb-3 w-full rounded-xl bg-brand-600 px-6 py-4 active:bg-brand-700"
  74|           onPress={this.handleRetry}
  75|           accessibilityRole="button"
  76|           accessibilityLabel="Try again"
  77|         >
  78|           <Text className="text-center text-lg font-bold text-white">
  79|             Try Again
  80|           </Text>
  81|         </Pressable>
  82| 
  83|         {__DEV__ && this.state.error && (
  84|           <View className="mt-4 w-full rounded-lg bg-gray-50 dark:bg-gray-800 p-4">
  85|             <Text className="mb-1 text-xs font-bold uppercase text-gray-500 dark:text-gray-400">
  86|               Debug Info
  87|             </Text>
  88|             <Text className="text-xs text-gray-600 dark:text-gray-400">
  89|               {this.state.error.message}
  90|             </Text>
  91|           </View>
  92|         )}
  93|       </View>
  94|     );
  95|   }
  96| }
  97| 
```


### burn-wizard/app/src/components/trainer/TrainerFeedback.tsx (lines 1-160)
```
   1| import { useMemo, useRef, useState } from 'react';
   2| import type { TrainerAttempt } from '@/domain/types';
   3| import type { CopyStructure } from '@/constants/i18n';
   4| import { useCopy } from '@/hooks/useCopy';
   5| import { useLanguage, getLocalizedRegionLabel, formatNumber, interpolate } from '@/constants/i18n';
   6| import { formatElapsedTime } from '@/hooks/useElapsedTimer';
   7| import { getBodyAreaPercentage } from '@/constants/lundBrowder';
   8| import { getScenarioById } from '@/domain/clinicalScenarios';
   9| import {
  10|   getChallengeForScenario,
  11|   getRandomChallenge,
  12| } from '@/constants/clinicalChallenges';
  13| import { shouldSuggestPromotion } from '@/domain/trainerScoring';
  14| import { useAllTimeStats, useTrainerDifficulty, useTrainerActions } from '@/store/useTrainerStore';
  15| import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
  16| import { Button } from '@/components/ui/button';
  17| import { ArrowUp, Flame, Timer } from 'lucide-react';
  18| import { cn } from '@/lib/utils';
  19| import { ClinicalChallengeCard } from './ClinicalChallengeCard';
  20| 
  21| // ---------------------------------------------------------------------------
  22| // Types
  23| // ---------------------------------------------------------------------------
  24| 
  25| interface TrainerFeedbackProps {
  26|   attempt: TrainerAttempt;
  27|   onNext: () => void;
  28|   onEndSession: () => void;
  29| }
  30| 
  31| // ---------------------------------------------------------------------------
  32| // Constants
  33| // ---------------------------------------------------------------------------
  34| 
  35| /**
  36|  * Tolerance window (ms) around the user's average time where we show
  37|  * "At your average pace" instead of a faster/slower comparison. Typical
  38|  * questions take 30-90 seconds, so 5 seconds is a noticeable-but-not-
  39|  * over-sensitive threshold.
  40|  */
  41| const AVERAGE_PACE_TOLERANCE_MS = 5000;
  42| 
  43| /** Minimum attempts required before showing average-comparison text. */
  44| const MIN_ATTEMPTS_FOR_AVERAGE_COMPARISON = 5;
  45| 
  46| // ---------------------------------------------------------------------------
  47| // Helpers
  48| // ---------------------------------------------------------------------------
  49| 
  50| function getScoreColors(points: number): { bg: string; text: string; border: string } {
  51|   switch (points) {
  52|     case 100:
  53|       return {
  54|         bg: 'bg-green-50 dark:bg-green-900/20',
  55|         text: 'text-green-700 dark:text-green-400',
  56|         border: 'border-green-200 dark:border-green-800',
  57|       };
  58|     case 75:
  59|       return {
  60|         bg: 'bg-blue-50 dark:bg-blue-900/20',
  61|         text: 'text-blue-700 dark:text-blue-400',
  62|         border: 'border-blue-200 dark:border-blue-800',
  63|       };
  64|     case 50:
  65|       return {
  66|         bg: 'bg-amber-50 dark:bg-amber-900/20',
  67|         text: 'text-amber-700 dark:text-amber-400',
  68|         border: 'border-amber-200 dark:border-amber-800',
  69|       };
  70|     default:
  71|       return {
  72|         bg: 'bg-red-50 dark:bg-red-900/20',
  73|         text: 'text-red-700 dark:text-red-400',
  74|         border: 'border-red-200 dark:border-red-800',
  75|       };
  76|   }
  77| }
  78| 
  79| function getLocalizedScoreLabel(label: string, copy: CopyStructure): string {
  80|   const map: Record<string, string> = {
  81|     'Excellent': copy.TRAINER_COPY.feedback.excellent,
  82|     'Good': copy.TRAINER_COPY.feedback.good,
  83|     'Fair': copy.TRAINER_COPY.feedback.fair,
  84|     'Review needed': copy.TRAINER_COPY.feedback.reviewNeeded,
  85|   };
  86|   return map[label] ?? label;
  87| }
  88| 
  89| // ---------------------------------------------------------------------------
  90| // Component
  91| // ---------------------------------------------------------------------------
  92| 
  93| export function TrainerFeedback({ attempt, onNext, onEndSession }: TrainerFeedbackProps) {
  94|   const { copy } = useCopy();
  95|   const language = useLanguage();
  96|   const allTimeStats = useAllTimeStats();
  97|   const difficulty = useTrainerDifficulty();
  98|   const { setDifficulty } = useTrainerActions();
  99|   const promotionTarget = shouldSuggestPromotion(allTimeStats.currentStreak, difficulty);
 100|   const pc = copy.PROGRESSION_COPY;
 101| 
 102|   const colors = getScoreColors(attempt.score.points);
 103|   const localizedLabel = getLocalizedScoreLabel(attempt.score.label, copy);
 104| 
 105|   const ageYears = attempt.question.patientData.ageMonths / 12;
 106| 
 107|   const isScenario = attempt.question.source !== 'random';
 108| 
 109|   // Get follow-up discussion prompts from the scenario (if applicable)
 110|   const followUpQuestions = useMemo(() => {
 111|     if (!isScenario) return [];
 112|     const scenario = getScenarioById(attempt.question.source, language);
 113|     return scenario?.followUpQuestions ?? [];
 114|   }, [isScenario, attempt.question.source, language]);
 115| 
 116|   // Select a relevant clinical challenge.
 117|   // Use a ref so that remounts with the same attempt don't re-roll a different
 118|   // random challenge. The ref is seeded on first render for this attempt.
 119|   const challengeRef = useRef<ReturnType<typeof getRandomChallenge> | null>(null);
 120|   const challengeAttemptIdRef = useRef<string | null>(null);
 121| 
 122|   if (
 123|     challengeRef.current === null ||
 124|     challengeAttemptIdRef.current !== attempt.attemptId
 125|   ) {
 126|     challengeAttemptIdRef.current = attempt.attemptId;
 127|     challengeRef.current = isScenario
 128|       ? getChallengeForScenario(attempt.question.source)
 129|       : getRandomChallenge();
 130|   }
 131| 
 132|   const challenge = challengeRef.current;
 133| 
 134|   // Group educational content (teaching points, common mistakes, discussion prompts)
 135|   // into a single tab block to reduce feedback-screen density. Score, comparison,
 136|   // and region breakdown stay above the fold; pedagogy is opt-in.
 137|   const teachingPoints = attempt.question.teachingPoints ?? [];
 138|   const commonMistakes = attempt.question.commonMistakes ?? [];
 139| 
 140|   type LearnTab = 'teaching' | 'mistakes' | 'discussion';
 141|   const availableTabs: { key: LearnTab; label: string }[] = [];
 142|   if (teachingPoints.length > 0) {
 143|     availableTabs.push({ key: 'teaching', label: copy.TRAINER_COPY.feedback.teachingPoints });
 144|   }
 145|   if (commonMistakes.length > 0) {
 146|     availableTabs.push({ key: 'mistakes', label: copy.TRAINER_COPY.feedback.commonMistakes });
 147|   }
 148|   if (followUpQuestions.length > 0) {
 149|     availableTabs.push({ key: 'discussion', label: copy.TRAINER_COPY.challenge.discussionPrompts });
 150|   }
 151|   const [activeTab, setActiveTab] = useState<LearnTab>(
 152|     availableTabs[0]?.key ?? 'teaching'
 153|   );
 154|   // Guard against the active tab becoming unavailable when the attempt changes
 155|   // (e.g. next scenario has no teaching points). Fall back to the first tab.
 156|   const effectiveTab: LearnTab = availableTabs.some((t) => t.key === activeTab)
 157|     ? activeTab
 158|     : (availableTabs[0]?.key ?? 'teaching');
 159| 
 160|   return (
```


## House style (brand/HOUSE-STYLE.md, rules section)

## The rules

Each rule has one check that someone can actually run. "Native" is the SwiftUI way. The other
columns get filled in after the Gemini adjudication.

| # | Rule | Check | SwiftUI | Expo | Tauri |
|---|---|---|---|---|---|
| 1 | **System text styles. Weight, not size, makes the hierarchy.** About 4 styles a screen *(soft count)*. | No fixed font sizes outside the tokens file. | `.font(.body)`, `.headline`; never `.system(size:)` | Own `Text` wrapper; `allowFontScaling` (default true); size from tokens, not literals | CSS `font: -apple-system-body` and sibling keywords (headline, subheadline, caption1); no web fonts; needs reload on text-size change (unverified inside Tauri) |
| 2 | **One accent: the product line's** (`BRAND.md` table). Everything else is neutral. Use it only on tappable or wayfinding items *(soft)*. | Count accent uses per screen; none on decoration. | `AccentColor` asset, `.tint` | Theme module, accent only on pressables | Tailwind preset with CSS variables |
| 3 | **Contrast 4.5:1 for text, 3:1 for large text and controls. Never color alone.** | Contrast tool, plus a grayscale screenshot in light and dark. | Accessibility Inspector | Theme tokens plus contrast tool; Increase Contrast hook for iOS: unverified | Tokens plus tool; `@media (prefers-contrast: more)` works (Safari 14.1+) |
| 4 | **Tap targets at least 44 pt; 48 pt or more on time-pressured screens.** | Every control passes a hit test. | `.frame(minWidth:44,minHeight:44).contentShape(Rectangle())` | `minHeight/minWidth: 44` plus `hitSlop` | `min-h-[44px] min-w-[44px]` (equivalence not fetched, test on device) |
| 5 | **Shared spacing and radius tokens:** multiples of 4/8, a few radii *(soft)*. | Grep for padding and radius literals outside the tokens file. | `Tokens.swift` | Style Dictionary v4 to a JS theme object | Style Dictionary v4 to CSS variables for Tailwind |
| 6 | **System chrome: stock bars, tabs and sheets. No opaque fake bars.** Content over a camera feed may use a deliberate dark card. | Look with Reduce Transparency and Increase Contrast on. | `NavigationStack`, `TabView` | Real: react-native-screens native stack (Expo Router) and `expo-router/unstable-native-tabs` (SDK 54 to 57, unstable) give iOS 26 Liquid Glass | Imitation only (`backdrop-filter`, static); no scroll-edge effect; native chrome around the WebView needs custom Swift (unverified) |
| 7 | **SF Symbols, weight-matched, monochrome by default** *(soft)*. Brand marks are the exception. | No mismatched icon weights. | `Label` | `expo-symbols` (unverified here) | Not possible in a WebView; imitation only with a weight-matched SVG set |
| 8 | **Short springs; nothing slow** (about 0.35 s, none over 0.5 s) *(soft)*. | Motion values come only from the tokens file. | `.spring(duration: 0.35)` | Reanimated `withSpring` with ~0.35 s config | Imitation: CSS `linear()` (Safari 17.2+) or a short ease; avoid JS animation libs |
| 9 | **Reduce Motion honored:** slides become fades. | Toggle it; nothing travels. | `accessibilityReduceMotion` | `ReducedMotionConfig` (System mode disables animations) plus `useReducedMotion` for explicit fades; the hook is not reactive | `@media (prefers-reduced-motion: reduce)` swaps slides for fades |
| 10 | **Haptics only for discrete, visible outcomes. Every haptic has a visible twin** *(soft)*. | List each haptic and its twin. | `.sensoryFeedback` | `expo-haptics` `impactAsync`, `notificationAsync`, `selectionAsync`; silent in Low Power Mode and while Camera is active | `@tauri-apps/plugin-haptics` `impactFeedback`, `notificationFeedback`, `selectionFeedback`; on-device test (latency unverified) |
| 11 | **One clear primary action per screen, in thumb reach** *(soft)*. A custom control such as a record ring can be that action. | A stranger names the action in one second. | `borderedProminent` in `.safeAreaInset(edge: .bottom)` | Bottom-anchored `Pressable` in the safe area (`react-native-safe-area-context`, unverified here) | Bottom bar with `env(safe-area-inset-bottom)`; set `viewport-fit=cover` |
| 12 | **Designed empty, error and missing-data states, each with one action.** | Every state previewed. | `ContentUnavailableView` | Imitation: own component per state (no stock equivalent) | Imitation: own component per state |
| 13 | **Undo where reversible. Where not, a confirm with a verb label** ("Delete Recording") *(soft)*. | No "Are you sure?" on recoverable actions. | `.confirmationDialog` | `Alert.alert` with a destructive button (unverified here) | `@tauri-apps/plugin-dialog` confirm on iOS: unverified; else an HTML dialog (imitation) |
| 14 | **Fast path to first value: no account wall before the core task** *(soft)*. | Time a cold launch to the first win. | - | - | - |
| 15 | **Permissions primed in context:** one sentence and a "Not now" before the system dialog. | No system prompt before the user's own tap. | sheet, then request | In-app sheet, then the module's request call | In-app sheet, then the plugin's request call (per-plugin support unverified) |
| 16 | **One proportionate completion moment per flow.** No confetti near serious content *(soft)*. | Each flow ends exactly once. | success haptic + fade | `notificationAsync(Success)` plus a short fade | `notificationFeedback("success")` plus a short fade |
| 17 | **VoiceOver complete.** | Do the core task with your eyes closed. | `.accessibilityLabel`, `.combine` | `accessible`, `accessibilityLabel`/`Role`, group value plus unit in one element, JSX order matches reading order | Semantic HTML, labels, `aria-live` container rendered at load with only its text changed |
| 18 | **Text scales to the largest accessibility size without clipping.** | Check at AX5. | `@ScaledMetric`, scrolling containers | `allowFontScaling` on; do not cap with `maxFontSizeMultiplier` (see below); scroll or wrap instead | Font keywords plus wrapping or scrolling containers; check at AX5 on device |
| 19 | **No dark patterns.** The system rating API only, after a win; honest notifications; no fake urgency. | Grep for custom review prompts; read all decline copy. | `requestReview()` | `expo-store-review` for the system prompt (unverified here) | System rating prompt: no verified plugin; likely needs a custom Swift plugin (unverified) |

**Clinical apps** (the clinical line) add: calm, exact copy with no exclamation marks; units always
visible next to computed values; results set in a larger style with monospaced digits; and 48 pt
targets as the floor, not the stretch. From the Gemini check: a home screen of Favorites, Recent, then all tools, plus
search (MDCalc pattern; no keyboard auto-open); one US/SI unit toggle that changes everything; offline
by default; never cap text size to protect a layout (wrap or scroll so the unit stays visible at AX5);
value and unit as ONE VoiceOver element; never rely on haptics for a safety alert (iOS mutes them in Low
Power Mode and while the camera runs); on Tauri, re-invert clinical images only under
`@media (inverted-colors: inverted)`.

## Engagement rules 20-26 (adopted by Perry 2026-10-05)

From the engagement-mechanics Deep Research (`dev-ops/research/gemini-dr-engagement-mechanics-2026-10-REPORT.md`),
source-checked by Sonnet (52 claims: 30 verified, 10 overreach) and by Sol on the regulatory claims
(`...-ADJUDICATION.md`). Only claims both passes support were proposed; Perry adopted all seven on 2026-10-05. The aim is **habit-forming, not
addictive**: every mechanic below survives rule 19.

| # | Rule | Check | Applies to | Source |
|---|---|---|---|---|
| 20 | **Notifications: default interruption level only.** Time Sensitive only for something happening within the hour, never reminders or marketing. Critical never (needs Apple's entitlement). One notification per event, and none for an update a Live Activity is already showing. | List each notification and its level. | All | Apple HIG, Managing notifications |
| 21 | **Progress forgives.** A missed day never resets a count to zero and no copy frames a lapse as loss. Prefer "days studied" or progress toward a goal the user set. Family apps carry no streaks at all. | Miss a day on a test build; read every lapse string. | Clinical (exam prep), outdoor/life | Gentler Streak (Apple Watch App of the Year 2022) |
| 22 | **Cancel as easily as you subscribed.** No guilt copy, no extra confirmation screens, no fake-urgency or "most picked" badges. Price, period and renewal shown before the purchase tap. | Count taps from paywall to subscribed vs to cancel instructions; read decline copy. | Any app with a subscription | FTC v. ABCmouse (complaint allegation, settled); App Review 3.1.2 *(not yet source-checked)* |
| 23 | **Login only where accounts earn it** (extends rule 14). If an app creates accounts, it deletes them in-app. | Fresh install reaches the core task with no account; find the delete-account path. | All | App Review 5.1.1(v) |
| 24 | **Widgets show changing information or do not ship.** | Widget content differs across a day. | Outdoor/life, clinical *(soft)* | Apple HIG, Widgets |
| 25 | **Android builds: no docked bottom toolbar together with the bottom navigation bar.** | Screen review of each Android screen. | All (Android) | Material 3 toolbars *(page only partly readable)* |
| 26 | **Clinical results show their basis:** the inputs used, the formula or source with its date or version, next to the result. This is good practice and helps clinicians check the output. **It is not, by itself, an FDA determination**: whether a given calculator is non-device clinical decision support is a separate per-function question for Perry (and counsel). The FDA guidance was reissued in January 2026. | Every computed value shows inputs plus a source line. | Clinical | FDA CDS guidance (2026), criterion 4 |

**Not adopted, with reasons.** A parental gate for StoryCue or Retold: Apple requires gates only inside the Kids
Category, and neither app is in it (opting in later would bring them in). Variable rewards and coin mechanics:
they conflict with rule 19. Specific paywall layouts ("trial date without scrolling", "two-tap cancel"): the report
gave no source. Material 3 conventions applied on iOS: that was the report's own extrapolation.

**Known conflicts with 21 and 22, being fixed:** BoardBound's streak chip and "Start your streak today!", its 7-day
coin rewards, and the pulsing "Most picked" paywall tag (`dev-ops/audits/boardbound-house-style-2026-10-04.md`).


## Fetched Apple evidence (developer.apple.com JSON endpoint, 2026-11-09)


### Apple: https://developer.apple.com/design/human-interface-guidelines/buttons
A button initiates an instantaneous action.
Versatile and highly customizable, buttons give people simple, familiar ways to do tasks in your app. In general, a button combines three attributes to clearly communicate its function:
- Style. A visual style based on size, color, and shape.
- Content. A symbol (or icon), text label, or both that a button displays to convey its purpose.
- Role. A system-defined role that identifies a button's semantic meaning and can affect its appearance.
There are also many button-like components that have distinct appearances and behaviors for specific use cases, like , , and .
#### Best practices
When buttons are instantly recognizable and easy to understand, an app tends to feel intuitive and well designed.
Make buttons easy for people to use. It's essential to include enough space around a button so that people can visually distinguish it from surrounding components and content. Giving a button enough space is also critical for helping people select or activate it, regardless of the method of input they use. As a general rule, a button needs a hit region of at least 44x44 pt - in visionOS, 60x60 pt - to ensure that people can select it easily, whether they use a fingertip, a pointer, their eyes, or a remote.
Always include a press state for a custom button. Without a press state, a button can feel unresponsive, making people wonder if it's accepting their input.
#### Style
System buttons offer a range of styles that support customization while providing built-in interaction states, accessibility support, and appearance adaptation. Different platforms define different styles that help you communicate hierarchies of actions in your app.
In general, use a button that has a prominent visual style for the most likely action in a view. To draw people's attention to a specific button, use a prominent button style so the system can apply an accent color to the button's background. Buttons that use color tend to be the most visually distinctive, helping people quickly identify the actions they're most likely to use. Keep the number of prominent buttons to one or two per view. Presenting too many prominent buttons increases cognitive load, requiring people to spend more time considering options before making a choice.
Use style - not size - to visually distinguish the preferred choice among multiple options. When you use buttons of the same size to offer two or more options, you signal that the options form a coherent set of choices. By contrast, placing two buttons of different sizes near each other can make the interface look confusing and inconsistent. If you want to highlight the preferred or most likely option in a set, use a more prominent button style for that option and a less prominent style for the remaining ones.
Avoid applying a similar color to button labels and content layer backgrounds. If your app already has bright, colorful content in the content layer, prefer using the default monochromatic appearance of button labels. For more guidance, see .
#### Content
Ensure that each button clearly communicates its purpose. Depending on the platform, a button can contain a symbol (or icon), a text label, or both to help people understand what it does.
In macOS and visionOS, the system displays a tooltip after people hover over a button for a moment. A tooltip displays a brief phrase that explains what a button does; for guidance, see .
Try to associate familiar actions with familiar icons. For example, people can predict that a button containing the square.and.arrow.up symbol will help them perform share-related activities. If it makes sense to use an icon in your button, consider using an existing or customized . For a list of symbols that represent common actions, see .
Consider using text when a short label communicates more clearly than an icon. To use text, write a few words that succinctly describe what the button does. Using , consider starting the label with a verb to help convey the button's action - for example, a button that lets people add items to their shopping cart might use the label "Add to Cart."
#### Role
A system button can have one of the following roles:
- Normal. No specific meaning.
- Primary. The button is the default button - the button people are most likely to choose.
- Cancel. The button cancels the current action.
- Destructive. The button performs an action that can result in data destruction.
A button's role can have additional effects on its appearance. For example, a primary button uses an app's accent color, whereas a destructive button uses the system red color.
Assign the primary role to the button people are most likely to choose. When a primary button responds to the Return key, it makes it easy for people to quickly confirm their choice. In addition, when the button is in a temporary view - like a , an editable view, or an  - assigning it the primary role means that the view can automatically close when people press Return.
Don't assign
[truncated]


### Apple: https://developer.apple.com/design/human-interface-guidelines/motion
Beautiful, fluid motions bring the interface to life, conveying status, providing feedback and instruction, and enriching the visual experience of your app or game.
Many system components automatically include motion, letting you offer familiar and consistent experiences throughout your app or game. System components might also adjust their motion in response to factors like accessibility settings or different input methods. For example, the movement of  responds to direct touch interaction with greater emphasis to reinforce the feeling of a tactile experience, but produces a more subdued effect when a person interacts using a trackpad.
If you design custom motion, follow the guidelines below.
#### Best practices
Add motion purposefully, supporting the experience without overshadowing it. Don't add motion for the sake of adding motion. Gratuitous or excessive animation can distract people and may make them feel disconnected or physically uncomfortable.
Make motion optional. Not everyone can or wants to experience the motion in your app or game, so it's essential to avoid using it as the only way to communicate important information. To help everyone enjoy your app or game, supplement visual feedback by also using alternatives like  and  to communicate.
#### Providing feedback
Strive for realistic feedback motion that follows people's gestures and expectations. In nongame apps, accurate, realistic motion can help people understand how something works, but feedback motion that doesn't make sense can make them feel disoriented. For example, if someone reveals a view by sliding it down from the top, they don't expect to dismiss the view by sliding it to the side.
Aim for brevity and precision in feedback animations. When animated feedback is brief and precise, it tends to feel lightweight and unobtrusive, and it can often convey information more effectively than prominent animation. For example, when a game displays a succinct animation that's precisely tied to a successful action, players can instantly get the message without being distracted from their gameplay. Another example is in visionOS: When people tap a panorama in Photos, it quickly and smoothly expands to fill the space in front of them, helping them track the transition without making them wait to enjoy the content.
In apps, generally avoid adding motion to UI interactions that occur frequently. The system already provides subtle animations for interactions with standard interface elements. For a custom element, you generally want to avoid making people spend extra time paying attention to unnecessary motion every time they interact with it.
Let people cancel motion. As much as possible, don't make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once.
Consider using animated symbols where it makes sense. When you use SF Symbols 5 or later, you can apply animations to SF Symbols or custom symbols. For guidance, see .
#### Leveraging platform capabilities
Make sure your game's motion looks great by default on each platform you support. In most games, maintaining a consistent frame rate of 30 to 60 fps typically results in a smooth, visually appealing experience. For each platform you support, use the device's graphics capabilities to enable default settings that let people enjoy your game without first having to change those settings.
Let people customize the visual experience of your game to optimize performance or battery life. For example, consider letting people switch between power modes when the system detects the presence of an external power source.
#### Platform considerations
No additional considerations for iOS, iPadOS, macOS, or tvOS.
#### visionOS
In addition to subtly communicating context, drawing attention to information, and enriching immersive experiences, motion in visionOS can combine with  to provide essential feedback when people look at interactive elements. Becaus
[truncated]


### Apple: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
Playing haptics can engage people's sense of touch and bring their familiarity with the physical world into your app or game.
Depending on the platform and the device people are using, the system can play haptics in addition to visual and auditory feedback. For example, components like switches, sliders, and pickers automatically play haptic feedback on supported iPhone models; on Apple Watch, the Taptic Engine generates haptics for a number of built-in feedback patterns, which watchOS combines with an audible tone. On a Mac that's equipped with a Force Touch trackpad, an app can play haptics while people drag content or when they force click to change the speed of media controls.
In addition to built-in haptic capabilities, some external input devices can also play haptics. For example:
- In an iPadOS, macOS, tvOS, or visionOS app or game,  can provide haptic feedback (for developer guidance, see ).
-  and some trackpads can provide haptic feedback when connected to certain iPad models. (For details on Apple Pencil features and compatibility, see .)
#### Best practices
Use system-provided haptic patterns according to their documented meanings. People recognize standard haptics because the system plays them consistently on interactions with standard controls. If the documented use case for a pattern doesn't make sense in your app or game, avoid using the pattern to mean something else. Instead, use a generic pattern or create your own, where supported. For guidance, see .
Use haptics consistently throughout your app or game. It's important to build a clear, causal relationship between each haptic and the action that causes it so people learn to associate certain haptic patterns with certain experiences. If a haptic doesn't reinforce a cause-and-effect relationship, it can be confusing and seem gratuitous. For example, if your game plays a specific haptic pattern when a character fails to finish a mission, people associate that pattern with a negative outcome. If you use the same haptic pattern for a positive outcome like a level completion, people will be confused.
Prefer using haptics to complement other feedback in your app or game. When visual, auditory, and tactile feedback are in harmony - as they generally are in the physical world - the user experience is more coherent and can seem more natural. For example, you generally want to match the intensity and sharpness of a haptic with the intensity and sharpness of the animation it accompanies. You can also synchronize sound with haptics; for developer guidance, see .
Avoid overusing haptics. Sometimes a haptic can feel just right when it happens occasionally, but become tiresome when it plays frequently. Doing user testing can help you discover a balance that most people appreciate. Often, the best haptic experience is one that people may not be conscious of, but miss when it's turned off.
In most apps, prefer playing short haptics that complement discrete events. Although long-running haptics that accompany a gameplay flow can enhance the experience, long-running haptics in an app can dilute the meaning of the feedback and distract people from their task. On Apple Pencil Pro, for example, continuous or long-lasting haptics don't tend to clarify the writing or drawing experience and can even make holding the pencil less pleasant.
Make haptics optional. Let people turn off or mute haptics, and make sure people can still enjoy your app or game without them.
Be aware that playing haptic
[truncated]


### Apple: https://developer.apple.com/design/human-interface-guidelines/loading
The best content-loading experience finishes before people become aware of it.
If your app or game loads assets, levels, or other content, design the behavior so it doesn't disrupt or negatively impact the user experience.
#### Best practices
Show something as soon as possible. If you make people wait for loading to complete before displaying anything, they can interpret the lack of content as a problem with your app or game. Instead, consider showing placeholder text, graphics, or animations as content loads, replacing these elements as content becomes available.
Let people do other things in your app or game while they wait for content to load. Loading content in the background helps give people access to other actions. For example, a game could load content in the background while players learn about the next level or view an in-game menu. For developer guidance, see .
If loading takes an unavoidably long time, give people something interesting to view while they wait. For example, you might provide gameplay hints, display tips, or introduce people to new features. Gauge the remaining loading time as accurately as possible to help you avoid giving people too little time to enjoy your placeholder content or having so much time that you need to repeat it.
Improve installation and launch time by downloading large assets in the background. Consider using the  framework to schedule asset downloads - like game level packs, 3D character models, and textures - to occur immediately after installation, during updates, or at other nondisruptive times.
#### Showing progress
Clearly communicate that content is loading and how long it might take to complete. Ideally, content displays instantly, but for situations where loading takes more than a moment or two, you can use system-provided components - called progress indicators - to show that loading is ongoing. In general, you use a determinate progress indicator when you know how long loading will take, and you use an indeterminate progress indicator when you don't. For guidance, see .
For games, consider creating a custom loading view. Standard progress indicators work well in most apps, but can sometimes feel out of place in a game. Consider designing a more engaging experience by using custom animations and elements that match the style of your game.
#### Platform considerations
No additional considerations for iOS, iPadOS, macOS, tvOS, or visionOS.
#### watchOS
As much as possible, avoid showing a loading indicator in your watchOS experience. People expect quick interactions with their Apple Watch, so aim to display content immediately. In situations where content needs a second or two to load, it's better to display a loading indicator than a blank screen.
#### Resources
#### Related
#### Developer documentation
#### Videos
#### Change log


### Apple: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)
Plays the specified feedback when the provided trigger value changes.
#### Discussion
For example, you could play feedback when a state value changes:
