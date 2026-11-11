# comeup packet: Retold, run 3 (2026-11-10)

Plain ASCII. Third pass. Perry, 2026-11-10: "it does not look professional or feel smooth yet."
Runs 1 and 2 (2026-11-04, 2026-11-09) merged PRs #21-#31: state clarity, haptics, Reduce Motion fades,
accessibility labels and 44 pt targets, terracotta AccentColor/OnAccent tokens, one full-width primary
action per screen, layout order on Home and the story page, playback failure UX, a branded launch view,
a "Filed" pill, press springs on rows. Run 2 scored Visual system 2/4; it is the lowest dimension left.
Perry's device report (2026-11-10): live transcription misheard words, dropped speech and lagged.

Scope this run: does it LOOK professional and FEEL smooth. Weight dimensions 1 (motion/fluidity),
5 (visual system), 6 (performance, especially the live-text path while recording) and 8 (layout).
Retold is SwiftUI (iOS 26 SDK, Liquid Glass era). StoryCue is the sibling app on the same brand line
(same terracotta accent); the shared SwiftUI tokens will be extracted from StoryCue. The veterans are
web/Expo, so cite their PATTERN (file:line) and translate it to SwiftUI.
Dimension 9 (Android parity) is N/A: Retold is iOS only.
Out of scope: store listings, billing, the 1.0 build, speech-recognition ACCURACY tuning (its own lane),
changes inside the audio engine (LiveCaptureEngine start/stop; a device crash was fixed there),
and Rule 1: the app never rewrites the user's words.
Screenshots: some reviewers receive the five CI simulator screenshots (6.9", demo mode, current main) as
images: 01-home, 02-recorder, 03-confirm, 04-story, 05-browse. If you received them, cite them by name.
If you did not, say "no screenshots" once and review from code.

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

ADDED FOR THIS RUN: after your findings, list up to 5 VETERAN OR SIBLING FEATURES WORTH BORROWING
(things BoardBound, burn-wizard or StoryCue do that Retold lacks and would look or feel better with).
Each: name, the file:line from this packet, what it would look like in Retold in one sentence, effort S/M/L.
This list is the one exception to "do not propose new features"; Perry picks from it.
For any finding where a screenshot shows the problem, name the screenshot in the evidence line.

## Measured probes (counted by Opus 2026-11-10; reviewers do not re-argue these)

| # | Probe | Result | Score 0-3 |
|---|---|---|---|
| M1 | CI on PRs | build.yml last 20 runs: 14 success, 6 cancelled (superseded), 0 failure | 3 |
| M2 | Test floor | 46 files across RetoldTests + RetoldUITests (ScreenshotTests, FlowTests); no coverage threshold | 2 |
| M4 | Crash reporting | none (no Sentry, Crashlytics or MetricKit subscriber) | 0 |
| M7 | Fluidity baseline | no XCTApplicationLaunchMetric, XCTHitchMetric or MetricKit; cold launch and hitches UNMEASURED | 0 |
| M8 | Harness | screenshots.yml + FlowTests on 6.5" and 6.9" simulators, demo mode, light mode only; no dark-mode capture | 2 |
| -- | Audio level | the capture engine publishes NO audio level / power value (grep: none in Retold/Capture) | - |


### Retold/Design/DesignTokens.swift
     1	import SwiftUI
     2	
     3	/// House-style tokens (brand/HOUSE-STYLE.md), the same values StoryCue ships, until the shared
     4	/// SwiftUI package exists. The accent is the family line's terracotta (AccentColor asset).
     5	enum DesignTokens {
     6	    enum Spacing {           // multiples of 4
     7	        static let s: CGFloat = 8
     8	        static let l: CGFloat = 16
     9	        static let xl: CGFloat = 24
    10	    }
    11	    enum Radius {
    12	        static let card: CGFloat = 12
    13	    }
    14	    /// Text and symbols on an accent fill (white in light mode, near-black in dark).
    15	    static let onAccent = Color("OnAccent")
    16	    /// The live-recording dot: system red, kept apart from the accent so "recording" never reads as "tap me".
    17	    static let recordingDot = Color.red
    18	    static let recordingDotSize: CGFloat = 20
    19	}
    20	
    21	extension View {
    22	    /// The one filled primary action of a screen: full width, large, accent fill, OnAccent label
    23	    /// (house style rule 11). Apply to a Button.
    24	    func primaryAction() -> some View {
    25	        self
    26	            .buttonStyle(.borderedProminent)
    27	            .controlSize(.large)
    28	            .foregroundStyle(DesignTokens.onAccent)
    29	    }
    30	
    31	    /// Full-width bar for a screen's primary action, pinned in thumb reach above the home indicator.
    32	    func primaryActionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    33	        safeAreaInset(edge: .bottom) {
    34	            VStack(spacing: DesignTokens.Spacing.s) {
    35	                content()
    36	            }
    37	            .frame(maxWidth: .infinity)
    38	            .padding(.horizontal, DesignTokens.Spacing.l)
    39	            .padding(.vertical, DesignTokens.Spacing.s)
    40	            .background(.bar)
    41	        }
    42	    }
    43	}
    44	
    45	/// comeup run 2, V1 (Perry's pick; BoardBound OptionButton.tsx:71): a custom row button gets a
    46	/// press state, a quick spring to 0.97 and back. Reduce Motion keeps only the dimming.
    47	struct PressableRowStyle: ButtonStyle {
    48	    func makeBody(configuration: Configuration) -> some View {
    49	        PressableBody(configuration: configuration)
    50	    }
    51	
    52	    private struct PressableBody: View {
    53	        let configuration: ButtonStyleConfiguration
    54	        @Environment(\.accessibilityReduceMotion) private var reduceMotion
    55	
    56	        var body: some View {
    57	            configuration.label
    58	                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
    59	                .opacity(configuration.isPressed ? 0.8 : 1)
    60	                .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3), value: configuration.isPressed)
    61	        }
    62	    }
    63	}
    64	
    65	extension ButtonStyle where Self == PressableRowStyle {
    66	    static var pressable: PressableRowStyle { PressableRowStyle() }
    67	}

### Retold/Screens/HomeView.swift
     1	import SwiftData
     2	import SwiftUI
     3	
     4	struct HomeView: View {
     5	    let coordinator: CaptureCoordinator
     6	    @Binding var autoPresentID: UUID?
     7	
     8	    @Environment(\.modelContext) private var modelContext
     9	    @Environment(\.scenePhase) private var scenePhase
    10	    @Environment(AudioPlayback.self) private var playback
    11	    @Environment(\.openURL) private var openURL
    12	    @Query(
    13	        filter: #Predicate<Capture> { $0.episode == nil },
    14	        sort: [SortDescriptor(\Capture.createdAt, order: .reverse)]
    15	    ) private var unfiledCaptures: [Capture]
    16	    @Query(sort: \Period.sortOrder) private var periods: [Period]
    17	    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
    18	
    19	    @State private var selectedCapture: Capture?
    20	    @State private var selectedAnsweredPeriodID: UUID?
    21	    @State private var showingSettings = false
    22	    @State private var outcomes: [UUID: FilingOutcome] = [:]
    23	    // The id, never a Capture: reading a property of a deleted SwiftData model can trap.
    24	    @State private var pendingDeleteID: UUID?
    25	    @State private var deleteFailed = false
    26	    @State private var micBlocked = false
    27	    /// comeup run 2, V2: the title just filed, shown briefly as a pill (BoardBound EarnToast.tsx).
    28	    @State private var filedTitle: String?
    29	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    30	
    31	    private var sections: [TimelineSection] {
    32	        Timeline.sections(
    33	            periods: periods.map { PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder) },
    34	            episodes: episodes.map { TimelineEpisode(id: $0.id, periodID: $0.period?.id, createdAt: $0.createdAt) }
    35	        )
    36	    }
    37	
    38	    var body: some View {
    39	        let periodsByID = Dictionary(periods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    40	        let episodesByID = Dictionary(episodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    41	        NavigationStack {
    42	            List {
    43	                if !unfiledCaptures.isEmpty {
    44	                    Section(AppCopy.unfiledHeader) {
    45	                        ForEach(unfiledCaptures) { capture in
    46	                            unfiledRow(capture)
    47	                                // Not a full swipe: a full swipe must never delete without the dialog.
    48	                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
    49	                                    Button(AppCopy.deleteAction, role: .destructive) { pendingDeleteID = capture.id }
    50	                                }
    51	                        }
    52	                    }
    53	                }
    54	                // comeup run 2: an empty library says what will appear here (house style rule 12).
    55	                // Periods stay below it: an empty period's page is where its opener lives.
    56	                if unfiledCaptures.isEmpty && episodes.isEmpty {
    57	                    Section {
    58	                        ContentUnavailableView {
    59	                            Label(AppCopy.homeEmptyTitle, systemImage: "waveform")
    60	                        } description: {
    61	                            Text(AppCopy.homeEmptyMessage)
    62	                        }
    63	                    }
    64	                }
    65	                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
    66	                    Section {
    67	                        if let ref = section.period {
    68	                            if let period = periodsByID[ref.id] {
    69	                                NavigationLink(destination: PeriodView(period: period)) {
    70	                                    Text(ref.title)
    71	                                        .font(.headline)
    72	                                }
    73	                            }
    74	                        } else {
    75	                            Text(AppCopy.noPeriod)
    76	                                .font(.headline)
    77	                        }
    78	                        ForEach(section.episodeIDs, id: \.self) { id in
    79	                            if let episode = episodesByID[id] {
    80	                                EpisodeRow(episode: episode)
    81	                            }
    82	                        }
    83	                    }
    84	                }
    85	                // comeup run 2: browse links come after the user's own stories, not above them.
    86	                Section(AppCopy.browseHeader) {
    87	                    NavigationLink(AppCopy.peopleHeader, destination: PeopleView())
    88	                    NavigationLink(AppCopy.placesTitle, destination: PlacesView())
    89	                    NavigationLink(AppCopy.themesTitle, destination: ThemesView())
    90	                    NavigationLink(AppCopy.periodsTitle, destination: PeriodsView())
    91	                    NavigationLink(AppCopy.setAsideTitle, destination: SetAsideView())
    92	                }
    93	            }
    94	            // comeup run 2: the app's one primary action is a filled accent button in thumb reach,
    95	            // not a list row with the same weight as every other row.
    96	            .primaryActionBar {
    97	                Button(action: startRecording) {
    98	                    Label(AppCopy.recordButton, systemImage: "mic.fill")
    99	                        .frame(maxWidth: .infinity)
   100	                }
   101	                .primaryAction()
   102	            }
   103	            .navigationTitle(AppCopy.homeTitle)
   104	            .toolbar {
   105	                ToolbarItem(placement: .topBarTrailing) {
   106	                    Button {
   107	                        showingSettings = true
   108	                    } label: {
   109	                        Image(systemName: "gearshape")
   110	                            .accessibilityLabel(AppCopy.settingsTitle)
   111	                    }
   112	                }
   113	            }
   114	        }
   115	        .sheet(isPresented: $showingSettings) {
   116	            SettingsView(files: coordinator.files)
   117	        }
   118	        .sheet(item: $selectedCapture) { capture in
   119	            ConfirmView(
   120	                capture: capture,
   121	                row: ConfirmDraft.unfiledRow(
   122	                    status: capture.transcriptionStatus,
   123	                    transcript: capture.completedTranscript
   124	                ),
   125	                cachedOutcome: outcomes[capture.id],
   126	                answeredPeriodID: selectedAnsweredPeriodID
   127	            ) { outcome in
   128	                outcomes[capture.id] = outcome
   129	            } onFiled: { title in
   130	                filedTitle = title
   131	                AccessibilityNotification.Announcement("\(AppCopy.filedLabel): \(title)").post()
   132	            }
   133	        }
   134	        .overlay(alignment: .top) {
   135	            if let filedTitle {
   136	                Label("\(AppCopy.filedLabel): \(filedTitle)", systemImage: "checkmark.circle.fill")
   137	                    .lineLimit(1)
   138	                    .font(.subheadline.weight(.semibold))
   139	                    .padding(.horizontal, DesignTokens.Spacing.l)
   140	                    .padding(.vertical, DesignTokens.Spacing.s)
   141	                    .background(.regularMaterial, in: Capsule())
   142	                    .padding(.horizontal, DesignTokens.Spacing.l)
   143	                    .padding(.top, DesignTokens.Spacing.s)
   144	                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
   145	            }
   146	        }
   147	        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: filedTitle)
   148	        .sensoryFeedback(.success, trigger: filedTitle) { _, new in new != nil }
   149	        .task(id: filedTitle) {
   150	            guard filedTitle != nil else { return }
   151	            // A cancelled sleep means a newer title replaced this one: leave it showing.
   152	            do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
   153	            filedTitle = nil
   154	        }
   155	        .confirmationDialog(
   156	            AppCopy.deleteRecordingTitle,
   157	            isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
   158	            titleVisibility: .visible,
   159	            presenting: pendingDeleteID
   160	        ) { id in
   161	            Button(AppCopy.deleteRecordingConfirm, role: .destructive) { deleteCapture(id) }
   162	        } message: { _ in
   163	            Text(AppCopy.deleteRecordingMessage)
   164	        }
   165	        .alert(AppCopy.deleteFailed, isPresented: $deleteFailed) {
   166	            Button(AppCopy.okButton, role: .cancel) {}
   167	        }
   168	        .alert(AppCopy.startFailedTitle, isPresented: Binding(
   169	            get: { coordinator.startFailure != nil },
   170	            set: { if !$0 { coordinator.clearStartFailure() } }
   171	        )) {
   172	            Button(AppCopy.okButton, role: .cancel) {}
   173	        } message: {
   174	            Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? ""))
   175	        }
   176	        .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
   177	            Button(AppCopy.openSettings) {
   178	                if let url = URL(string: UIApplication.openSettingsURLString) {
   179	                    openURL(url)
   180	                }
   181	            }
   182	            Button(AppCopy.cancelButton, role: .cancel) {}
   183	        } message: {
   184	            Text(AppCopy.micDenied)
   185	        }
   186	        .onAppear {
   187	            // Order matters: seed periods, then attach answers, then auto-present. Home is created
   188	            // fresh after Stop, so autoPresentID is already set here; an episode answer must attach
   189	            // before auto-present, or it would open a confirm sheet it should not get.
   190	            try? DefaultPeriods.seedIfNeeded(modelContext, defaults: .standard)
   191	            _ = try? AnswerAttacher.attachPending(in: modelContext)
   192	            handleAutoPresent()
   193	        }
   194	        .onChange(of: autoPresentID) { _, _ in
   195	            handleAutoPresent()
   196	        }
   197	        .onChange(of: coordinator.lastImport) { _, _ in
   198	            _ = try? AnswerAttacher.attachPending(in: modelContext)
   199	        }
   200	        // The file pass completes audio-only captures without setting lastImport.
   201	        .onChange(of: scenePhase) { _, newPhase in
   202	            if newPhase == .active {
   203	                _ = try? AnswerAttacher.attachPending(in: modelContext)
   204	            }
   205	        }
   206	    }
   207	
   208	    private func startRecording() {
   209	        // Stop playback (deactivating) before the capture starts, while the phase is .idle.
   210	        playback.stop()
   211	        Task { @MainActor in
   212	            await coordinator.startCapture(answering: nil)
   213	            // A denied microphone used to do nothing visible.
   214	            if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
   215	                micBlocked = true
   216	            }
   217	        }
   218	    }
   219	
   220	    @ViewBuilder
   221	    private func unfiledRow(_ capture: Capture) -> some View {
   222	        let state = ConfirmDraft.unfiledRow(
   223	            status: capture.transcriptionStatus,
   224	            transcript: capture.completedTranscript
   225	        )
   226	        switch state {
   227	        case .transcribing:
   228	            // Tappable: a recording whose transcript never arrives (no on-device speech for this
   229	            // locale) must still be fileable with a typed title. ConfirmView handles this row.
   230	            Button {
   231	                present(capture)
   232	            } label: {
   233	                captureRow(capture, detail: AppCopy.transcribingLabel)
   234	            }
   235	            .buttonStyle(.pressable)
   236	        case .ready(let excerpt):
   237	            Button {
   238	                present(capture)
   239	            } label: {
   240	                captureRow(capture, detail: excerpt)
   241	            }
   242	            .buttonStyle(.pressable)
   243	        case .noTranscript:
   244	            Button {
   245	                present(capture)
   246	            } label: {
   247	                captureRow(capture, detail: AppCopy.noTranscriptLabel)
   248	            }
   249	            .buttonStyle(.pressable)
   250	        }
   251	    }
   252	
   253	    private func captureRow(_ capture: Capture, detail: String) -> some View {
   254	        VStack(alignment: .leading, spacing: 4) {
   255	            Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
   256	            Text(detail)
   257	                .foregroundStyle(.secondary)
   258	                .lineLimit(2)
   259	        }
   260	        .frame(maxWidth: .infinity, alignment: .leading)
   261	        .contentShape(Rectangle())
   262	    }
   263	
   264	    @MainActor
   265	    private func deleteCapture(_ id: UUID) {
   266	        do {
   267	            try CaptureDeleter.delete(
   268	                captureID: id,
   269	                activeCaptureID: coordinator.activeCaptureID,
   270	                files: coordinator.files,
   271	                in: modelContext.container
   272	            )
   273	            outcomes[id] = nil
   274	        } catch CaptureDeleteError.filed {
   275	            // Attached since the swipe: the row has already left Unfiled.
   276	        } catch {
   277	            deleteFailed = true
   278	        }
   279	    }
   280	
   281	    /// Computes the answered period once per presentation, never in the sheet closure.
   282	    private func present(_ capture: Capture) {
   283	        selectedAnsweredPeriodID = AnswerAttacher.answeredPeriodID(for: capture, in: modelContext)
   284	        selectedCapture = capture
   285	    }
   286	
   287	    private func handleAutoPresent() {
   288	        guard let id = autoPresentID else { return }
   289	        defer { autoPresentID = nil }
   290	        // An answer to an episode's question attaches first, so it never opens a confirm sheet.
   291	        _ = try? AnswerAttacher.attachPending(in: modelContext)
   292	        let wantedID = id
   293	        var descriptor = FetchDescriptor<Capture>(
   294	            predicate: #Predicate { $0.id == wantedID }
   295	        )
   296	        descriptor.fetchLimit = 1
   297	        guard let captures = try? modelContext.fetch(descriptor),
   298	              let capture = captures.first,
   299	              capture.episode == nil
   300	        else { return }
   301	
   302	        switch ConfirmDraft.unfiledRow(
   303	            status: capture.transcriptionStatus,
   304	            transcript: capture.completedTranscript
   305	        ) {
   306	        case .ready, .noTranscript:
   307	            present(capture)
   308	        case .transcribing:
   309	            break
   310	        }
   311	    }
   312	}
   313	
   314	/// A button that plays or pauses one capture. Disabled when its audio file is missing.
   315	struct PlayPauseButton: View {
   316	    let captureID: UUID
   317	
   318	    @Environment(AudioPlayback.self) private var playback
   319	
   320	    var body: some View {
   321	        let isThisPlaying = playback.captureID == captureID && playback.isPlaying
   322	        Button {
   323	            if isThisPlaying {
   324	                playback.pause()
   325	            } else {
   326	                playback.play(captureID)
   327	            }
   328	        } label: {
   329	            Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
   330	                .frame(minWidth: 44, minHeight: 44)
   331	                .contentShape(Rectangle())
   332	        }
   333	        .buttonStyle(.borderless)
   334	        .disabled(!playback.canPlay(captureID))
   335	        .accessibilityLabel(isThisPlaying ? AppCopy.pauseButton : AppCopy.playButton)
   336	        .sensoryFeedback(.impact(weight: .light), trigger: isThisPlaying)
   337	        // comeup run 2: a failed play is felt, not a dead tap (AudioPlayback announces it once).
   338	        .sensoryFeedback(.error, trigger: playback.failureCount) { _, _ in playback.failedCaptureID == captureID }
   339	    }
   340	}
   341	
   342	/// One episode in a list (R7b section 7.2), reused by the period, person and place pages.
   343	struct EpisodeRow: View {
   344	    let episode: Episode
   345	
   346	    private var firstCapture: Capture? {
   347	        episode.captures.min { (a: Capture, b: Capture) -> Bool in
   348	            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
   349	        }
   350	    }
   351	
   352	    var body: some View {
   353	        let facts = EpisodeFacts(episode: episode)
   354	        NavigationLink(destination: EpisodeView(episode: episode)) {
   355	            HStack {
   356	                VStack(alignment: .leading, spacing: 4) {
   357	                    Text(facts.title ?? AppCopy.untitled)
   358	                    // Verbatim user words, the same line the export prints; not a Confirmable.
   359	                    if !episode.excerpt.isEmpty {
   360	                        Text(episode.excerpt)
   361	                            .font(.subheadline)
   362	                            .foregroundStyle(.secondary)
   363	                            .lineLimit(1)
   364	                    }
   365	                    if let when = facts.whenDisplay {
   366	                        Text(when)
   367	                            .font(.subheadline)
   368	                            .foregroundStyle(.secondary)
   369	                    }
   370	                }
   371	                Spacer()
   372	                if let capture = firstCapture {
   373	                    PlayPauseButton(captureID: capture.id)
   374	                }
   375	            }
   376	        }
   377	    }
   378	}
   379	
   380	extension Collection where Element == Episode {
   381	    /// Newest first, by `(createdAt descending, id.uuidString)`.
   382	    func newestFirst() -> [Episode] {
   383	        sorted { (a: Episode, b: Episode) -> Bool in
   384	            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
   385	            return a.id.uuidString < b.id.uuidString
   386	        }
   387	    }
   388	}

### Retold/Screens/RecorderView.swift
     1	import Foundation
     2	import SwiftData
     3	import SwiftUI
     4	
     5	/// R6b recorder: red dot, elapsed time, live text, Stop, and Resume while interrupted
     6	/// (comeup run 2: house-style pass; one primary action in thumb reach).
     7	struct RecorderView: View {
     8	    let coordinator: CaptureCoordinator
     9	    /// Anchor for the once-a-second redraw only; the displayed time is accumulated audio time.
    10	    @State private var tickAnchor = Date()
    11	    /// Seconds recorded in earlier .recording stretches (an interruption closes one).
    12	    @State private var accumulated: TimeInterval = 0
    13	    /// When the current .recording stretch began; nil while starting, interrupted or stopping.
    14	    @State private var runningSince: Date?
    15	    @Environment(\.modelContext) private var modelContext
    16	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    17	    /// R7b: the question this capture answers, fetched once on appear. Hidden when not found.
    18	    @State private var answeringText: String?
    19	
    20	    private var isInterrupted: Bool {
    21	        if case .interrupted = coordinator.state.phase { return true }
    22	        return false
    23	    }
    24	
    25	    private var isRecording: Bool {
    26	        if case .recording = coordinator.state.phase { return true }
    27	        return false
    28	    }
    29	
    30	    private var isStarting: Bool {
    31	        if case .starting = coordinator.state.phase { return true }
    32	        return false
    33	    }
    34	
    35	    private var isStopping: Bool {
    36	        if case .stopping = coordinator.state.phase { return true }
    37	        return false
    38	    }
    39	
    40	    var body: some View {
    41	        VStack(spacing: DesignTokens.Spacing.l) {
    42	            if coordinator.state.answering != nil {
    43	                Text(AppCopy.answeringLabel)
    44	                    .foregroundStyle(.secondary)
    45	                if let answeringText {
    46	                    Text(answeringText)
    47	                        .font(.headline)
    48	                }
    49	                Text(AppCopy.reinstatement)
    50	                    .font(.footnote)
    51	            }
    52	            // comeup run 2: the live state is the screen's headline, not a 16 pt dot.
    53	            HStack(spacing: 12) {
    54	                Image(systemName: "circle.fill")
    55	                    .font(.system(size: DesignTokens.recordingDotSize))
    56	                    .foregroundStyle(isRecording ? DesignTokens.recordingDot : Color.secondary)
    57	                    .symbolEffect(.pulse, options: .repeating, isActive: isRecording && !reduceMotion)
    58	                    .accessibilityHidden(true)
    59	                TimelineView(.periodic(from: tickAnchor, by: 1)) { context in
    60	                    Text(elapsed(at: context.date))
    61	                        .font(.largeTitle.monospacedDigit().weight(.semibold))
    62	                }
    63	            }
    64	            statusLine
    65	            ScrollView {
    66	                Text(coordinator.liveText)
    67	                    .font(.title3)
    68	                    .frame(maxWidth: .infinity, alignment: .leading)
    69	            }
    70	            .frame(maxHeight: .infinity)
    71	            if coordinator.lengthWarning {
    72	                Text(AppCopy.lengthWarning)
    73	                    .font(.footnote)
    74	                    .padding(DesignTokens.Spacing.s)
    75	                    .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
    76	            }
    77	        }
    78	        .padding()
    79	        // Stop (or Resume) is the screen's one primary action, full width in thumb reach.
    80	        .primaryActionBar {
    81	            if isInterrupted {
    82	                Button {
    83	                    Task { @MainActor in coordinator.send(.tapResume) }
    84	                } label: {
    85	                    Label(AppCopy.resumeButton, systemImage: "play.fill")
    86	                        .frame(maxWidth: .infinity)
    87	                }
    88	                .primaryAction()
    89	            }
    90	            // Stop is always available; while interrupted it is secondary to Resume but still ends
    91	            // and saves the capture.
    92	            Button {
    93	                Task { @MainActor in coordinator.send(.tapStop) }
    94	            } label: {
    95	                Label(AppCopy.stopButton, systemImage: "stop.fill")
    96	                    .frame(maxWidth: .infinity)
    97	            }
    98	            .modifier(StopButtonStyle(primary: !isInterrupted))
    99	            .disabled(isStopping || isStarting)
   100	        }
   101	        .onAppear {
   102	            loadAnsweringText()
   103	            syncClock()
   104	        }
   105	        .onChange(of: coordinator.state.phase) { _, _ in
   106	            syncClock()
   107	            // A sighted user sees the label change; VoiceOver users need it spoken.
   108	            if isInterrupted {
   109	                AccessibilityNotification.Announcement(AppCopy.pausedLabel).post()
   110	            } else if isStopping {
   111	                AccessibilityNotification.Announcement(AppCopy.savingLabel).post()
   112	            }
   113	        }
   114	        .onChange(of: coordinator.lengthWarning) { _, warning in
   115	            if warning { AccessibilityNotification.Announcement(AppCopy.lengthWarning).post() }
   116	        }
   117	    }
   118	
   119	    @ViewBuilder
   120	    private var statusLine: some View {
   121	        if isInterrupted {
   122	            Text(AppCopy.pausedLabel)
   123	                .foregroundStyle(.secondary)
   124	        } else if isStarting {
   125	            // Engine spin-up: no audio is being captured yet, so do not say "Recording".
   126	            HStack(spacing: DesignTokens.Spacing.s) {
   127	                ProgressView()
   128	                Text(AppCopy.startingLabel)
   129	                    .foregroundStyle(.secondary)
   130	            }
   131	        } else if isStopping {
   132	            // The engine is finalizing the file: say so, instead of looking like it still records.
   133	            HStack(spacing: DesignTokens.Spacing.s) {
   134	                ProgressView()
   135	                Text(AppCopy.savingLabel)
   136	                    .foregroundStyle(.secondary)
   137	            }
   138	        } else {
   139	            Text(AppCopy.recordingLabel)
   140	                .foregroundStyle(.secondary)
   141	        }
   142	    }
   143	
   144	    /// Counts time only while the phase is .recording, so the clock matches the saved file.
   145	    private func syncClock() {
   146	        if isRecording {
   147	            if runningSince == nil { runningSince = Date() }
   148	        } else if let since = runningSince {
   149	            accumulated += Date().timeIntervalSince(since)
   150	            runningSince = nil
   151	        }
   152	    }
   153	
   154	    private func loadAnsweringText() {
   155	        guard let id = coordinator.state.answering else { return }
   156	        var descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.id == id })
   157	        descriptor.fetchLimit = 1
   158	        if let question = try? modelContext.fetch(descriptor).first {
   159	            answeringText = QuestionText.display(question)
   160	        }
   161	    }
   162	
   163	    private func elapsed(at now: Date) -> String {
   164	        let live = runningSince.map { now.timeIntervalSince($0) } ?? 0
   165	        let total = Int(accumulated + live)
   166	        return String(format: "%02d:%02d", total / 60, total % 60)
   167	    }
   168	}
   169	
   170	/// Stop is the primary action while recording, and a secondary (bordered, large) one under Resume
   171	/// while interrupted.
   172	private struct StopButtonStyle: ViewModifier {
   173	    let primary: Bool
   174	
   175	    func body(content: Content) -> some View {
   176	        if primary {
   177	            content.primaryAction()
   178	        } else {
   179	            content
   180	                .buttonStyle(.bordered)
   181	                .controlSize(.large)
   182	        }
   183	    }
   184	}

### Retold/Screens/ConfirmView.swift
     1	import Foundation
     2	import SwiftData
     3	import SwiftUI
     4	
     5	struct ConfirmView: View {
     6	    let capture: Capture
     7	    let row: UnfiledRow
     8	    let cachedOutcome: FilingOutcome?
     9	    /// R7b: the period of the question this capture answers, if any; pre-picked in the draft.
    10	    let answeredPeriodID: UUID?
    11	    let onOutcome: (FilingOutcome) -> Void
    12	    /// comeup run 2, V2: called with the filed title after a successful File it (Home shows a pill).
    13	    var onFiled: (String) -> Void = { _ in }
    14	
    15	    @Environment(\.dismiss) private var dismiss
    16	    @Environment(\.modelContext) private var modelContext
    17	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    18	    @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
    19	    @Query(sort: \Period.sortOrder) private var periods: [Period]
    20	    @Query(sort: \Person.name) private var people: [Person]
    21	    @Query(sort: \Place.name) private var places: [Place]
    22	
    23	    @State private var draft: ConfirmDraft?
    24	    @State private var mode: FilingMode?
    25	    @State private var suggestionTask: Task<FilingOutcome, Never>?
    26	    @State private var findingSuggestions = false
    27	    @State private var whenMode = WhenMode.year
    28	    @State private var selectedWhenValue: Int?
    29	    @State private var newPersonName = ""
    30	    @State private var newPlaceName = ""
    31	    /// comeup run 2: a failed File it used to do nothing visible.
    32	    @State private var fileFailed = false
    33	    /// comeup run 2, V1: bumped by Use this / Not this / choice taps for a selection haptic.
    34	    @State private var choiceTick = 0
    35	
    36	    private enum WhenMode: Hashable {
    37	        case year, age
    38	    }
    39	
    40	    private enum PeriodPickerValue: Hashable {
    41	        case none
    42	        case existing(UUID)
    43	        case new
    44	    }
    45	
    46	    var body: some View {
    47	        NavigationStack {
    48	            Group {
    49	                if let current = draft {
    50	                    form(current)
    51	                } else if findingSuggestions {
    52	                    VStack(spacing: 16) {
    53	                        ProgressView()
    54	                        Text(AppCopy.findingSuggestions)
    55	                        Button(AppCopy.skipSuggestions) {
    56	                            skipSuggestions()
    57	                        }
    58	                    }
    59	                    .padding()
    60	                } else {
    61	                    ProgressView()
    62	                }
    63	            }
    64	            .toolbar {
    65	                ToolbarItem(placement: .cancellationAction) {
    66	                    Button(AppCopy.cancelButton) { dismiss() }
    67	                }
    68	                ToolbarItem(placement: .confirmationAction) {
    69	                    Button(AppCopy.fileButton) {
    70	                        file()
    71	                    }
    72	                    .disabled(!(draft?.canFile ?? false))
    73	                }
    74	            }
    75	        }
    76	        .alert(AppCopy.saveFailedTitle, isPresented: $fileFailed) {
    77	            Button(AppCopy.okButton, role: .cancel) {}
    78	        } message: {
    79	            Text(AppCopy.saveFailedMessage)
    80	        }
    81	        .sensoryFeedback(.error, trigger: fileFailed) { _, failed in failed }
    82	        .sensoryFeedback(.selection, trigger: choiceTick)
    83	        .task {
    84	            await load()
    85	        }
    86	        .onDisappear {
    87	            suggestionTask?.cancel()
    88	        }
    89	    }
    90	
    91	    @ViewBuilder
    92	    private func form(_ current: ConfirmDraft) -> some View {
    93	        Form {
    94	            if case .deck(let reason)? = mode, let copy = reason.copy {
    95	                Section {
    96	                    Text(copy)
    97	                        .font(.footnote)
    98	                        .foregroundStyle(.secondary)
    99	                }
   100	            }
   101	
   102	            Section(AppCopy.titleHeader) {
   103	                switch row {
   104	                case .ready(let excerpt):
   105	                    Text(excerpt)
   106	                case .noTranscript:
   107	                    Text(AppCopy.noTranscriptLabel)
   108	                case .transcribing:
   109	                    Text(AppCopy.transcribingLabel)
   110	                }
   111	                if let chip = current.titleChip {
   112	                    suggestionRow(chip: chip) {
   113	                        mutateDraft { $0.acceptTitle() }
   114	                    } reject: {
   115	                        mutateDraft { $0.rejectTitle() }
   116	                    }
   117	                }
   118	                TextField(AppCopy.titlePlaceholder, text: Binding(
   119	                    get: { draft?.typedTitle ?? "" },
   120	                    set: { value in mutateDraft(animated: false) { $0.typedTitle = value } }
   121	                ))
   122	                if !current.canFile {
   123	                    Text(AppCopy.titleNeededHint)
   124	                        .font(.footnote)
   125	                        .foregroundStyle(.secondary)
   126	                }
   127	            }
   128	
   129	            Section(AppCopy.periodHeader) {
   130	                if let suggested = current.suggestedPeriod,
   131	                   current.periodSuggestionState != .rejected {
   132	                    suggestionRow(
   133	                        text: suggested.title,
   134	                        isSuggested: current.periodSuggestionState == .suggested
   135	                    ) {
   136	                        mutateDraft { $0.acceptSuggestedPeriod() }
   137	                    } reject: {
   138	                        mutateDraft { $0.rejectSuggestedPeriod() }
   139	                    }
   140	                }
   141	                Picker(AppCopy.periodHeader, selection: periodSelection) {
   142	                    Text(AppCopy.noPeriod).tag(PeriodPickerValue.none)
   143	                    ForEach(periods) { period in
   144	                        Text(period.title).tag(PeriodPickerValue.existing(period.id))
   145	                    }
   146	                    Text(AppCopy.newPeriod).tag(PeriodPickerValue.new)
   147	                }
   148	                if case .new = current.periodPick {
   149	                    TextField(AppCopy.newPeriodPlaceholder, text: Binding(
   150	                        get: {
   151	                            if case .new(let title)? = draft?.periodPick { return title }
   152	                            return ""
   153	                        },
   154	                        set: { title in mutateDraft(animated: false) { $0.pick(.new(title)) } }
   155	                    ))
   156	                }
   157	            }
   158	
   159	            Section(AppCopy.whenHeader) {
   160	                Text(current.whenQuestion.text)
   161	                Picker(AppCopy.whenHeader, selection: $whenMode) {
   162	                    Text(AppCopy.whenYear).tag(WhenMode.year)
   163	                    Text(AppCopy.whenAge).tag(WhenMode.age)
   164	                }
   165	                .pickerStyle(.segmented)
   166	                .onChange(of: whenMode) { _, _ in
   167	                    selectedWhenValue = nil
   168	                    mutateDraft { $0.setWhen(.notSure) }
   169	                }
   170	                Picker(AppCopy.whenHeader, selection: $selectedWhenValue) {
   171	                    Text("--").tag(Int?.none)
   172	                    if whenMode == .year {
   173	                        ForEach(Array(stride(from: Calendar.current.component(.year, from: Date()), through: 1900, by: -1)), id: \.self) { year in
   174	                            Text(String(year)).tag(Int?.some(year))
   175	                        }
   176	                    } else {
   177	                        ForEach(0...100, id: \.self) { age in
   178	                            Text(String(age)).tag(Int?.some(age))
   179	                        }
   180	                    }
   181	                }
   182	                .pickerStyle(.wheel)
   183	                .onChange(of: selectedWhenValue) { _, value in
   184	                    guard let value else {
   185	                        mutateDraft { $0.setWhen(.notSure) }
   186	                        return
   187	                    }
   188	                    mutateDraft {
   189	                        $0.setWhen(whenMode == .year ? .year(value) : .age(value))
   190	                    }
   191	                }
   192	                Button(AppCopy.notSure) {
   193	                    selectedWhenValue = nil
   194	                    mutateDraft { $0.setWhen(.notSure) }
   195	                }
   196	            }
   197	
   198	            Section(AppCopy.peopleHeader) {
   199	                ForEach(current.people) { chip in
   200	                    suggestionRow(chip: chip) {
   201	                        mutateDraft { $0.setChip(chip.id, .accepted) }
   202	                    } reject: {
   203	                        mutateDraft { $0.setChip(chip.id, .rejected) }
   204	                    }
   205	                    if chip.state == .accepted, let match = chip.match {
   206	                        Picker(AppCopy.peopleHeader, selection: Binding(
   207	                            get: {
   208	                                draft?.people.first(where: { $0.id == chip.id })?.useMatch ?? true
   209	                            },
   210	                            set: { useMatch in
   211	                                mutateDraft { $0.setUseMatch(chip.id, useMatch) }
   212	                            }
   213	                        )) {
   214	                            Text("\(AppCopy.sameAs) \(match.name)").tag(true)
   215	                            Text(AppCopy.newPerson).tag(false)
   216	                        }
   217	                        .pickerStyle(.segmented)
   218	                    }
   219	                }
   220	                ForEach(Array(current.typedPeople.enumerated()), id: \.offset) { index, entity in
   221	                    HStack {
   222	                        Text(entityName(entity, known: current.knownPeople))
   223	                        Spacer()
   224	                        Button {
   225	                            mutateDraft { $0.removeTypedPerson(at: index) }
   226	                        } label: {
   227	                            Image(systemName: "trash")
   228	                                .frame(minWidth: 44, minHeight: 44)
   229	                                .contentShape(Rectangle())
   230	                        }
   231	                        .accessibilityLabel(removeLabel(entityName(entity, known: current.knownPeople)))
   232	                    }
   233	                    .buttonStyle(.borderless)
   234	                }
   235	                Menu(AppCopy.addPerson) {
   236	                    ForEach(current.knownPeople, id: \.id) { person in
   237	                        Button(person.name) {
   238	                            mutateDraft { $0.addTypedPerson(.existing(person.id)) }
   239	                        }
   240	                    }
   241	                }
   242	                TextField(AppCopy.newPerson, text: $newPersonName)
   243	                    .onSubmit {
   244	                        let name = newPersonName
   245	                        mutateDraft { $0.addTypedPerson(.new(name)) }
   246	                        newPersonName = ""
   247	                    }
   248	            }
   249	
   250	            Section(AppCopy.placesHeader) {
   251	                ForEach(current.places) { chip in
   252	                    suggestionRow(chip: chip) {
   253	                        mutateDraft { $0.setChip(chip.id, .accepted) }
   254	                    } reject: {
   255	                        mutateDraft { $0.setChip(chip.id, .rejected) }
   256	                    }
   257	                    if chip.state == .accepted, let match = chip.match {
   258	                        Picker(AppCopy.placesHeader, selection: Binding(
   259	                            get: {
   260	                                draft?.places.first(where: { $0.id == chip.id })?.useMatch ?? true
   261	                            },
   262	                            set: { useMatch in
   263	                                mutateDraft { $0.setUseMatch(chip.id, useMatch) }
   264	                            }
   265	                        )) {
   266	                            Text("\(AppCopy.sameAs) \(match.name)").tag(true)
   267	                            Text(AppCopy.newPlace).tag(false)
   268	                        }
   269	                        .pickerStyle(.segmented)
   270	                    }
   271	                }
   272	                if let typedPlace = current.typedPlace {
   273	                    HStack {
   274	                        Text(entityName(typedPlace, known: current.knownPlaces))
   275	                        Spacer()
   276	                        Button {
   277	                            mutateDraft { $0.setTypedPlace(nil) }
   278	                        } label: {
   279	                            Image(systemName: "trash")
   280	                                .frame(minWidth: 44, minHeight: 44)
   281	                                .contentShape(Rectangle())
   282	                        }
   283	                        .accessibilityLabel(removeLabel(entityName(typedPlace, known: current.knownPlaces)))
   284	                    }
   285	                    .buttonStyle(.borderless)
   286	                }
   287	                Menu(AppCopy.addPlace) {
   288	                    ForEach(current.knownPlaces, id: \.id) { place in
   289	                        Button(place.name) {
   290	                            mutateDraft { $0.setTypedPlace(.existing(place.id)) }
   291	                        }
   292	                    }
   293	                }
   294	                TextField(AppCopy.newPlace, text: $newPlaceName)
   295	                    .onSubmit {
   296	                        let name = newPlaceName
   297	                        mutateDraft { $0.setTypedPlace(.new(name)) }
   298	                        newPlaceName = ""
   299	                    }
   300	            }
   301	
   302	            Section(AppCopy.followUpsHeader) {
   303	                ForEach(current.followUps.filter { current.isLive($0) }) { row in
   304	                    VStack(alignment: .leading, spacing: 8) {
   305	                        Text(row.question.text)
   306	                        if row.question.templateID != FilingTemplates.broad.id {
   307	                            HStack {
   308	                                choiceButton(
   309	                                    AppCopy.later,
   310	                                    selected: row.choice == .later
   311	                                ) {
   312	                                    mutateDraft { $0.setRow(row.id, .later) }
   313	                                }
   314	                                choiceButton(
   315	                                    AppCopy.notThisOne,
   316	                                    selected: row.choice == .notThisOne
   317	                                ) {
   318	                                    mutateDraft { $0.setRow(row.id, .notThisOne) }
   319	                                }
   320	                            }
   321	                        }
   322	                    }
   323	                }
   324	            }
   325	        }
   326	    }
   327	
   328	    private func suggestionRow(
   329	        chip: SpanChip,
   330	        accept: @escaping () -> Void,
   331	        reject: @escaping () -> Void
   332	    ) -> some View {
   333	        suggestionRow(text: chip.span.text, isSuggested: chip.state == .suggested, accept: accept, reject: reject)
   334	    }
   335	
   336	    /// comeup run 2: the user's words get the full row width; the actions sit on their own line
   337	    /// (they used to squeeze the words into a three-line column). VoiceOver names what each acts on.
   338	    private func suggestionRow(
   339	        text: String,
   340	        isSuggested: Bool,
   341	        accept: @escaping () -> Void,
   342	        reject: @escaping () -> Void
   343	    ) -> some View {
   344	        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
   345	            HStack(alignment: .firstTextBaseline) {
   346	                Text(text)
   347	                    .frame(maxWidth: .infinity, alignment: .leading)
   348	                if isSuggested {
   349	                    Text(AppCopy.suggestedLabel)
   350	                        .font(.footnote)
   351	                        .foregroundStyle(.secondary)
   352	                }
   353	            }
   354	            HStack(spacing: DesignTokens.Spacing.s) {
   355	                Button {
   356	                    accept()
   357	                    choiceTick += 1
   358	                } label: {
   359	                    Label(AppCopy.acceptButton, systemImage: "checkmark")
   360	                        .frame(minHeight: 32)
   361	                }
   362	                .buttonStyle(.bordered)
   363	                .tint(.accentColor)
   364	                .accessibilityLabel("\(AppCopy.acceptButton): \(text)")
   365	                Button {
   366	                    reject()
   367	                    choiceTick += 1
   368	                } label: {
   369	                    Label(AppCopy.rejectButton, systemImage: "xmark")
   370	                        .frame(minHeight: 32)
   371	                }
   372	                .buttonStyle(.bordered)
   373	                .tint(.gray)
   374	                .accessibilityLabel("\(AppCopy.rejectButton): \(text)")
   375	            }
   376	        }
   377	        .padding(.vertical, 4)
   378	    }
   379	
   380	    private func choiceButton(
   381	        _ title: String,
   382	        selected: Bool,
   383	        action: @escaping () -> Void
   384	    ) -> some View {
   385	        Button {
   386	            action()
   387	            choiceTick += 1
   388	        } label: {
   389	            HStack {
   390	                if selected {
   391	                    Image(systemName: "checkmark")
   392	                }
   393	                Text(title)
   394	            }
   395	            .frame(minHeight: 44)
   396	            .contentShape(Rectangle())
   397	        }
   398	        .buttonStyle(.borderless)
   399	    }
   400	
   401	    private var periodSelection: Binding<PeriodPickerValue> {
   402	        Binding(
   403	            get: {
   404	                switch draft?.periodPick ?? .none {
   405	                case .none: return .none
   406	                case .existing(let id): return .existing(id)
   407	                case .new: return .new
   408	                }
   409	            },
   410	            set: { selection in
   411	                mutateDraft {
   412	                    switch selection {
   413	                    case .none: $0.pick(.none)
   414	                    case .existing(let id): $0.pick(.existing(id))
   415	                    case .new: $0.pick(.new(""))
   416	                    }
   417	                }
   418	            }
   419	        )
   420	    }
   421	
   422	    private func removeLabel(_ name: String) -> String {
   423	        name.isEmpty ? AppCopy.removeLabel : "\(AppCopy.removeLabel) \(name)"
   424	    }
   425	
   426	    private func entityName(_ entity: TypedEntity, known: [EntityRef]) -> String {
   427	        switch entity {
   428	        case .existing(let id):
   429	            return known.first(where: { $0.id == id })?.name ?? ""
   430	        case .new(let name):
   431	            return name.trimmingCharacters(in: .whitespacesAndNewlines)
   432	        }
   433	    }
   434	
   435	    /// Animated by default so rows that appear or vanish (a picker, a "Same as" choice) do not
   436	    /// jump; typing passes `animated: false`. Reduce Motion turns the animation off.
   437	    private func mutateDraft(animated: Bool = true, _ mutation: (inout ConfirmDraft) -> Void) {
   438	        guard var value = draft else { return }
   439	        mutation(&value)
   440	        if animated && !reduceMotion {
   441	            withAnimation(.smooth(duration: 0.25)) { draft = value }
   442	        } else {
   443	            draft = value
   444	        }
   445	    }
   446	
   447	    @MainActor
   448	    private func load() async {
   449	        guard draft == nil else { return }
   450	        #if DEBUG
   451	        // `-RetoldDemo` only: a simulator has no Apple Intelligence, so the demo files through the
   452	        // production pipeline over a scripted model (DemoMode.filingPipeline). Without the
   453	        // argument this block does nothing; the Release build does not compile it.
   454	        if DemoMode.isActive {
   455	            mode = .model
   456	            if let transcript = capture.completedTranscript {
   457	                let outcome = await DemoMode.filingPipeline()
   458	                    .file(transcript, periodTitles: periods.map(\.title))
   459	                buildDraft(outcome: outcome)
   460	            } else {
   461	                buildDraft(outcome: nil)
   462	            }
   463	            return
   464	        }
   465	        #endif
   466	        let selectedMode = FilingMode.select(
   467	            availability: ModelAvailability.current,
   468	            suggestionsOn: suggestionsOn
   469	        )
   470	        mode = selectedMode
   471	
   472	        if row == .noTranscript {
   473	            buildDraft(outcome: nil)
   474	            return
   475	        }
   476	        if case .deck = selectedMode {
   477	            buildDraft(outcome: nil)
   478	            return
   479	        }
   480	        if let cachedOutcome {
   481	            buildDraft(outcome: cachedOutcome)
   482	            return
   483	        }
   484	        guard let transcript = capture.completedTranscript else {
   485	            buildDraft(outcome: nil)
   486	            return
   487	        }
   488	
   489	        findingSuggestions = true
   490	        let periodTitles = periods.map(\.title)
   491	        let task = Task {
   492	            await FilingPipeline(
   493	                model: FoundationFilingModel(),
   494	                counter: DeviceTokenCounter()
   495	            ).file(transcript, periodTitles: periodTitles)
   496	        }
   497	        suggestionTask = task
   498	        // The inner Task is unstructured, so forward cancellation to it explicitly.
   499	        let outcome = await withTaskCancellationHandler {
   500	            await task.value
   501	        } onCancel: {
   502	            task.cancel()
   503	        }
   504	        suggestionTask = nil
   505	        findingSuggestions = false
   506	        guard draft == nil else { return }
   507	        if Task.isCancelled {
   508	            // A cancelled load must not strand a blank sheet; show the plain form instead.
   509	            buildDraft(outcome: nil)
   510	            return
   511	        }
   512	        // Only a real proposal is cached: a .noModel failure (cancelled, timeout) retries on the next open.
   513	        if case .proposal = outcome {
   514	            onOutcome(outcome)
   515	        }
   516	        buildDraft(outcome: outcome)
   517	    }
   518	
   519	    private func skipSuggestions() {
   520	        suggestionTask?.cancel()
   521	        suggestionTask = nil
   522	        findingSuggestions = false
   523	        buildDraft(outcome: nil)
   524	    }
   525	
   526	    private func buildDraft(outcome: FilingOutcome?) {
   527	        guard draft == nil else { return }
   528	        var built = ConfirmDraft.make(
   529	            captureID: capture.id,
   530	            outcome: outcome,
   531	            periods: periods.map {
   532	                PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder)
   533	            },
   534	            people: people.map { EntityRef(id: $0.id, name: $0.name) },
   535	            places: places.map { EntityRef(id: $0.id, name: $0.name) }
   536	        )
   537	        // The user chose to answer this period's question: a user act, not a suggestion.
   538	        if let id = answeredPeriodID, periods.contains(where: { $0.id == id }) {
   539	            built.pick(.existing(id))
   540	        }
   541	        draft = built
   542	    }
   543	
   544	    private func file() {
   545	        guard let draft else { return }
   546	        do {
   547	            try ConfirmFiler.file(draft, capture: capture, in: modelContext)
   548	            switch draft.resolvedTitle {
   549	            case .typed(let title)?: onFiled(title)
   550	            case .quote(let span)?: onFiled(span.text)
   551	            case nil: break
   552	            }
   553	            dismiss()
   554	        } catch {
   555	            // Filing failures keep the unchanged draft on screen, per the R7a contract, and say so.
   556	            fileFailed = true
   557	        }
   558	    }
   559	}

### Retold/Screens/OfferRow.swift
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// One engine offer with its two actions (R7b section 7.1). Shows `offer.question.text`, never
     5	/// `Question.text`. A throw from either action shows a short alert, and the row stays.
     6	struct OfferRow: View {
     7	    let offer: EngineOffer
     8	    let target: OfferTarget
     9	
    10	    @Environment(\.modelContext) private var modelContext
    11	    @Environment(AudioPlayback.self) private var playback
    12	    @Environment(CaptureCoordinator.self) private var coordinator
    13	    @Environment(\.openURL) private var openURL
    14	
    15	    @State private var micBlocked = false
    16	    @State private var saveFailed = false
    17	
    18	    var body: some View {
    19	        VStack(alignment: .leading, spacing: 8) {
    20	            Text(offer.question.text)
    21	            HStack {
    22	                // comeup run 2: 44 pt tap height (house style rule 4); the frame sits inside the label.
    23	                Button {
    24	                    answerNow()
    25	                } label: {
    26	                    Text(AppCopy.answerNow).frame(minHeight: 44).contentShape(Rectangle())
    27	                }
    28	                // .dontRemember does nothing on broad.open (Question.record), as on the confirm screen.
    29	                if offer.question.templateID != "broad.open" {
    30	                    Button {
    31	                        notThisOne()
    32	                    } label: {
    33	                        Text(AppCopy.notThisOne).frame(minHeight: 44).contentShape(Rectangle())
    34	                    }
    35	                }
    36	            }
    37	            .buttonStyle(.borderless)
    38	        }
    39	        .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
    40	            Button(AppCopy.openSettings) {
    41	                if let url = URL(string: UIApplication.openSettingsURLString) {
    42	                    openURL(url)
    43	                }
    44	            }
    45	            Button(AppCopy.cancelButton, role: .cancel) {}
    46	        } message: {
    47	            Text(AppCopy.micDenied)
    48	        }
    49	        .alert(AppCopy.saveFailedTitle, isPresented: $saveFailed) {
    50	            Button(AppCopy.okButton, role: .cancel) {}
    51	        } message: {
    52	            Text(AppCopy.saveFailedMessage)
    53	        }
    54	    }
    55	
    56	    private func answerNow() {
    57	        playback.stop()
    58	        let id: UUID
    59	        do {
    60	            id = try QuestionActions.prepareAnswer(offer, target: target, in: modelContext)
    61	        } catch {
    62	            saveFailed = true
    63	            return
    64	        }
    65	        let coordinator = coordinator
    66	        Task { @MainActor in
    67	            await coordinator.startCapture(answering: id)
    68	            if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
    69	                micBlocked = true
    70	            }
    71	        }
    72	    }
    73	
    74	    private func notThisOne() {
    75	        do {
    76	            try QuestionActions.notThisOne(offer, target: target, in: modelContext)
    77	        } catch {
    78	            saveFailed = true
    79	        }
    80	    }
    81	}
    82	
    83	/// A `Section(questionsHeader)` with one OfferRow per offer, in the engine's queue order.
    84	/// Omitted when the queue is empty.
    85	struct OfferSection: View {
    86	    let offers: [EngineOffer]
    87	    let target: OfferTarget
    88	
    89	    var body: some View {
    90	        if !offers.isEmpty {
    91	            Section(AppCopy.questionsHeader) {
    92	                ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
    93	                    OfferRow(offer: offer, target: target)
    94	                }
    95	            }
    96	        }
    97	    }
    98	}

### Retold/Screens/EpisodeView.swift
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// The episode page (R7b section 7.5): confirmed facts, open questions, and the recordings with
     5	/// their verbatim transcripts. Every fact is read through EpisodeFacts.
     6	struct EpisodeView: View {
     7	    let episode: Episode
     8	
     9	    @Environment(AudioPlayback.self) private var playback
    10	
    11	    var body: some View {
    12	        let facts = EpisodeFacts(episode: episode)
    13	        List {
    14	            // comeup run 2: the full title wraps here; the inline nav title may truncate.
    15	            Section {
    16	                Text(facts.title ?? AppCopy.untitled)
    17	                    .font(.title2.bold())
    18	                    .accessibilityAddTraits(.isHeader)
    19	                if hasFacts(facts) {
    20	                    factRows(facts)
    21	                }
    22	            }
    23	            // The user's own voice and words come before the questions (screenshot 04-story had
    24	            // them below the fold under five offers).
    25	            Section(AppCopy.recordingsHeader) {
    26	                ForEach(sortedCaptures) { capture in
    27	                    captureBlock(capture)
    28	                }
    29	            }
    30	            // comeup run 2, V5 (Perry's pick): the questions fold into one row under the recordings.
    31	            let offers = QuestionEngine.queue(for: EpisodeState(episode: episode))
    32	            if !offers.isEmpty {
    33	                Section {
    34	                    DisclosureGroup("\(AppCopy.questionsHeader) (\(offers.count))") {
    35	                        ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
    36	                            OfferRow(offer: offer, target: .episode(episode))
    37	                        }
    38	                    }
    39	                }
    40	            }
    41	        }
    42	        .navigationTitle(facts.title ?? AppCopy.untitled)
    43	        .navigationBarTitleDisplayMode(.inline)
    44	    }
    45	
    46	    private var sortedCaptures: [Capture] {
    47	        episode.captures.sorted { (a: Capture, b: Capture) -> Bool in
    48	            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
    49	        }
    50	    }
    51	
    52	    private func hasFacts(_ facts: EpisodeFacts) -> Bool {
    53	        facts.period != nil || facts.whenDisplay != nil || facts.place != nil
    54	            || !facts.people.isEmpty || !facts.details.isEmpty
    55	    }
    56	
    57	    @ViewBuilder
    58	    private func factRows(_ facts: EpisodeFacts) -> some View {
    59	        if let period = facts.period {
    60	            LabeledContent(AppCopy.periodHeader, value: period.title)
    61	        }
    62	        if let when = facts.whenDisplay {
    63	            LabeledContent(AppCopy.whenHeader, value: when)
    64	        }
    65	        if let ref = facts.place, let place = episode.place {
    66	            NavigationLink(ref.name, destination: PlaceView(place: place))
    67	        }
    68	        ForEach(facts.people, id: \.id) { ref in
    69	            if let person = episode.people.first(where: { $0.id == ref.id }) {
    70	                NavigationLink(ref.name, destination: PersonView(person: person))
    71	            }
    72	        }
    73	        ForEach(Array(facts.details.enumerated()), id: \.offset) { _, text in
    74	            Text("\u{201C}\(text)\u{201D}")
    75	        }
    76	    }
    77	
    78	    @ViewBuilder
    79	    private func captureBlock(_ capture: Capture) -> some View {
    80	        VStack(alignment: .leading, spacing: 8) {
    81	            Text("\(capture.createdAt.formatted(date: .abbreviated, time: .shortened)) \u{00B7} \(ExportManifest.formatClock(capture.duration))")
    82	                .font(.subheadline)
    83	            if playback.canPlay(capture.id) {
    84	                PlayerRow(captureID: capture.id, duration: capture.duration)
    85	            } else {
    86	                Text(AppCopy.audioMissing)
    87	                    .foregroundStyle(.secondary)
    88	            }
    89	            transcript(capture)
    90	        }
    91	    }
    92	
    93	    @ViewBuilder
    94	    private func transcript(_ capture: Capture) -> some View {
    95	        switch CaptureTranscriptState.of(status: capture.transcriptionStatus, segments: capture.transcript) {
    96	        case .transcribing:
    97	            Text(AppCopy.transcribingLabel)
    98	                .foregroundStyle(.secondary)
    99	        case .none:
   100	            Text(AppCopy.noTranscript)
   101	                .foregroundStyle(.secondary)
   102	        case .segments(let segments):
   103	            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
   104	                Button {
   105	                    playback.play(capture.id, from: segment.start)
   106	                } label: {
   107	                    Text("\(ExportManifest.formatClock(segment.start))  \(segment.text)")
   108	                        .frame(maxWidth: .infinity, alignment: .leading)
   109	                }
   110	                .buttonStyle(.borderless)
   111	            }
   112	        }
   113	    }
   114	}
   115	
   116	/// comeup run 2: the play button, scrubber and clock. Only this view reads `currentTime`, so the
   117	/// 4 Hz playback tick redraws one row, not the whole story page. At accessibility text sizes the
   118	/// clock moves under the scrubber so the slider keeps its width.
   119	private struct PlayerRow: View {
   120	    let captureID: UUID
   121	    let duration: TimeInterval
   122	
   123	    @Environment(AudioPlayback.self) private var playback
   124	    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
   125	
   126	    var body: some View {
   127	        let isLoaded = playback.captureID == captureID
   128	        let clock = "\(ExportManifest.formatClock(isLoaded ? playback.currentTime : 0)) / \(ExportManifest.formatClock(duration))"
   129	        VStack(alignment: .leading, spacing: 4) {
   130	            if dynamicTypeSize.isAccessibilitySize {
   131	                HStack {
   132	                    PlayPauseButton(captureID: captureID)
   133	                    slider(isLoaded: isLoaded, clock: clock)
   134	                }
   135	                clockText(clock)
   136	            } else {
   137	                HStack {
   138	                    PlayPauseButton(captureID: captureID)
   139	                    slider(isLoaded: isLoaded, clock: clock)
   140	                    clockText(clock)
   141	                }
   142	            }
   143	            if playback.failedCaptureID == captureID {
   144	                Text(AppCopy.playbackFailed)
   145	                    .font(.footnote)
   146	                    .foregroundStyle(.secondary)
   147	            }
   148	        }
   149	        .buttonStyle(.borderless)
   150	    }
   151	
   152	    private func slider(isLoaded: Bool, clock: String) -> some View {
   153	        Slider(
   154	            value: Binding(
   155	                get: { isLoaded ? playback.currentTime : 0 },
   156	                set: { value in
   157	                    if playback.captureID == captureID {
   158	                        playback.seek(to: value)
   159	                    } else {
   160	                        playback.play(captureID, from: value)
   161	                    }
   162	                }
   163	            ),
   164	            in: 0...max(duration, 1)
   165	        )
   166	        .disabled(duration <= 0)
   167	        .accessibilityLabel(AppCopy.playbackPosition)
   168	        .accessibilityValue(clock)
   169	    }
   170	
   171	    private func clockText(_ clock: String) -> some View {
   172	        Text(clock)
   173	            .font(.footnote.monospacedDigit())
   174	            .foregroundStyle(.secondary)
   175	            .accessibilityHidden(true)
   176	    }
   177	}

### Retold/Screens/PeopleView.swift
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// The People list (R7b section 7.5).
     5	struct PeopleView: View {
     6	    @Query(sort: \Person.name) private var people: [Person]
     7	
     8	    var body: some View {
     9	        Group {
    10	            if people.isEmpty {
    11	                EmptyPage(title: AppCopy.noPeopleTitle, message: AppCopy.noPeopleMessage)
    12	            } else {
    13	                List(people) { person in
    14	                    NavigationLink(person.name, destination: PersonView(person: person))
    15	                }
    16	            }
    17	        }
    18	        .navigationTitle(AppCopy.peopleHeader)
    19	    }
    20	}
    21	
    22	/// One person's page: the person engine's open questions, then their episodes, newest first.
    23	struct PersonView: View {
    24	    let person: Person
    25	
    26	    var body: some View {
    27	        let offers = QuestionEngine.queue(for: PersonState(person: person))
    28	        Group {
    29	            if offers.isEmpty && person.episodes.isEmpty {
    30	                EmptyPage(title: AppCopy.emptyTitle, message: AppCopy.emptyPersonMessage)
    31	            } else {
    32	                List {
    33	                    OfferSection(offers: offers, target: .person(person))
    34	                    Section {
    35	                        ForEach(person.episodes.newestFirst()) { episode in
    36	                            EpisodeRow(episode: episode)
    37	                        }
    38	                    }
    39	                }
    40	            }
    41	        }
    42	        .navigationTitle(person.name)
    43	    }
    44	}

### Retold/Screens/EmptyPage.swift
     1	import SwiftUI
     2	
     3	/// The one designed empty state (house style rule 12): a title, a sentence on what will appear,
     4	/// and one action. Used wherever a page can end up with no questions and no stories, so rejecting
     5	/// the last question never leaves a blank page.
     6	struct EmptyPage: View {
     7	    let title: String
     8	    let message: String
     9	
    10	    @Environment(\.dismiss) private var dismiss
    11	
    12	    var body: some View {
    13	        ContentUnavailableView {
    14	            Label(title, systemImage: "text.bubble")
    15	        } description: {
    16	            Text(message)
    17	        } actions: {
    18	            Button(AppCopy.goBack) {
    19	                dismiss()
    20	            }
    21	        }
    22	    }
    23	}

### Retold/Playback/AudioPlayback.swift
     1	import AVFoundation
     2	import Foundation
     3	import Observation
     4	import SwiftUI
     5	
     6	/// The one shared audio player (R7b section 2). A thin device adapter over AVAudioPlayer, so it
     7	/// has no unit tests; the device sitting checks it. One instance lives in RootView.
     8	@MainActor @Observable
     9	final class AudioPlayback {
    10	    private(set) var captureID: UUID?          // the loaded capture, nil when stopped
    11	    private(set) var isPlaying = false
    12	    private(set) var currentTime: TimeInterval = 0
    13	    private(set) var duration: TimeInterval = 0
    14	    /// comeup run 2: the capture whose last play attempt failed (decode, session or missing file),
    15	    /// so its row can say so instead of looking like a dead tap. Cleared by the next play.
    16	    private(set) var failedCaptureID: UUID?
    17	    /// Bumped on every failure, so a retry that fails again still triggers the error haptic.
    18	    private(set) var failureCount = 0
    19	    /// The capture that was failing when the current play() began (repeat failures, e.g. a slider
    20	    /// drag over a broken file, are not announced again).
    21	    @ObservationIgnored private var wasFailing: UUID?
    22	
    23	    @ObservationIgnored private let files: CaptureFiles
    24	    @ObservationIgnored private var player: AVAudioPlayer?
    25	    @ObservationIgnored private var updateTask: Task<Void, Never>?
    26	
    27	    init(files: CaptureFiles) {
    28	        self.files = files
    29	    }
    30	
    31	    /// The audio file exists. One FileManager call, cheap enough per row.
    32	    func canPlay(_ captureID: UUID) -> Bool {
    33	        FileManager.default.fileExists(atPath: files.audioURL(for: captureID).path)
    34	    }
    35	
    36	    /// Plays `captureID`, from `time` if given. The same capture, loaded and paused, resumes
    37	    /// (seeking first if `time` is given); a different capture loaded is stopped first. Any
    38	    /// failure (a missing file, a decode failure, a session error) stops and sets
    39	    /// `failedCaptureID`; the row shows a line, not an alert.
    40	    func play(_ captureID: UUID, from time: TimeInterval? = nil) {
    41	        wasFailing = failedCaptureID
    42	        failedCaptureID = nil
    43	        if self.captureID == captureID, let player {
    44	            if let time { seek(to: time) }
    45	            guard player.play() else {
    46	                fail(captureID)
    47	                return
    48	            }
    49	            isPlaying = true
    50	            currentTime = player.currentTime
    51	            startUpdates()
    52	            return
    53	        }
    54	        if self.captureID != nil {
    55	            stop(deactivateSession: false)
    56	        }
    57	        do {
    58	            // The URL is always files.audioURL(for:); nothing else builds an audio path.
    59	            let newPlayer = try AVAudioPlayer(contentsOf: files.audioURL(for: captureID))
    60	            self.player = newPlayer
    61	            self.captureID = captureID
    62	            duration = newPlayer.duration
    63	            let session = AVAudioSession.sharedInstance()
    64	            try session.setCategory(.playback)
    65	            try session.setActive(true)
    66	            if let time {
    67	                newPlayer.currentTime = min(max(time, 0), newPlayer.duration)
    68	            }
    69	            guard newPlayer.play() else {
    70	                fail(captureID)
    71	                return
    72	            }
    73	            isPlaying = true
    74	            currentTime = newPlayer.currentTime
    75	            startUpdates()
    76	        } catch {
    77	            fail(captureID)
    78	        }
    79	    }
    80	
    81	    private func fail(_ captureID: UUID) {
    82	        stop()
    83	        failedCaptureID = captureID
    84	        failureCount += 1
    85	        // Spoken here, once: several rows (Home under a pushed story page) may show the same
    86	        // capture, and a slider drag over a broken file would otherwise repeat it on every tick.
    87	        if wasFailing != captureID {
    88	            AccessibilityNotification.Announcement(AppCopy.playbackFailed).post()
    89	        }
    90	    }
    91	
    92	    /// Cancels the update task and keeps the capture loaded.
    93	    func pause() {
    94	        guard let player else { return }
    95	        updateTask?.cancel()
    96	        updateTask = nil
    97	        player.pause()
    98	        isPlaying = false
    99	        currentTime = player.currentTime
   100	    }
   101	
   102	    /// Clamps to 0...duration.
   103	    func seek(to time: TimeInterval) {
   104	        guard let player else { return }
   105	        let clamped = min(max(time, 0), duration)
   106	        player.currentTime = clamped
   107	        currentTime = clamped
   108	    }
   109	
   110	    /// Strictly a no-op when nothing is loaded: it touches neither the session nor any property.
   111	    /// Otherwise it stops the player, cancels the update task, resets every property and, if
   112	    /// `deactivateSession`, deactivates the session (ignoring the error).
   113	    func stop(deactivateSession: Bool = true) {
   114	        guard captureID != nil else { return }
   115	        player?.stop()
   116	        player = nil
   117	        updateTask?.cancel()
   118	        updateTask = nil
   119	        captureID = nil
   120	        isPlaying = false
   121	        currentTime = 0
   122	        duration = 0
   123	        if deactivateSession {
   124	            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
   125	        }
   126	    }
   127	
   128	    /// One task updates currentTime every 0.25 s while playing. Seeing the player stopped without a
   129	    /// pause() call (pause cancels this task) means it reached the end.
   130	    private func startUpdates() {
   131	        updateTask?.cancel()
   132	        updateTask = Task { [weak self] in
   133	            while !Task.isCancelled {
   134	                try? await Task.sleep(for: .milliseconds(250))
   135	                guard !Task.isCancelled, let self, let player = self.player else { return }
   136	                if player.isPlaying {
   137	                    self.currentTime = player.currentTime
   138	                } else {
   139	                    self.stop()
   140	                    return
   141	                }
   142	            }
   143	        }
   144	    }
   145	}

### Retold/Capture/CaptureCoordinator.swift (lines 1-260: state, entry points, live text)
     1	import Foundation
     2	import Observation
     3	import SwiftData
     4	
     5	// Owns the recorder loop: reduces engine events through RecorderMachine, runs journal effects
     6	// synchronously in a FIFO drain, and hands engine effects to one serial task so a pause can never
     7	// overtake a start. The store is touched only inside importJournals/retranscribePending and only
     8	// while protectedDataAvailable.
     9	
    10	/// S7a: recorded-time thresholds for one capture. Time spent interrupted does not count.
    11	/// Injectable so tests can run the real timer in milliseconds.
    12	struct CaptureLengthLimits: Equatable, Sendable {
    13	    var warning: TimeInterval
    14	    var limit: TimeInterval
    15	
    16	    static let standard = CaptureLengthLimits(warning: 20 * 60, limit: 30 * 60)
    17	}
    18	
    19	@MainActor @Observable
    20	final class CaptureCoordinator {
    21	    private(set) var state: RecorderState
    22	    private(set) var liveText: String = ""        // UI only: journaled finals joined by " " + current volatile; reset at startEngine
    23	    private(set) var journalError: Error?         // last journal failure, for the UI
    24	    private(set) var startFailure: String?        // why the last start failed, for the UI alert
    25	    private(set) var processedEventCount = 0      // incremented after each handled event (tests)
    26	    private(set) var lastImport: JournalImporter.Report?
    27	    private(set) var lengthWarning = false        // S7a: the recorder screen's banner, from limits.warning
    28	
    29	    let files: CaptureFiles
    30	    let importer: JournalImporter
    31	
    32	    @ObservationIgnored private let engine: any CaptureEngine
    33	    @ObservationIgnored private let fileTranscriber: any FileTranscriber
    34	    @ObservationIgnored private let routeProvider: @Sendable () async -> TranscriptionRoute
    35	    @ObservationIgnored private let container: ModelContainer
    36	    @ObservationIgnored private let inbox: CaptureLaunchInbox
    37	    @ObservationIgnored private var startInFlight = false
    38	    @ObservationIgnored private let makeWriter: (CaptureFiles, UUID) throws -> any JournalAppending
    39	    @ObservationIgnored private let now: () -> Date
    40	    @ObservationIgnored private let newID: () -> UUID
    41	    @ObservationIgnored private let lengthLimits: CaptureLengthLimits
    42	
    43	    @ObservationIgnored private var effectQueue: [RecorderEffect] = []
    44	    @ObservationIgnored private var isDraining = false
    45	    @ObservationIgnored private var writers: [UUID: any JournalAppending] = [:]
    46	    @ObservationIgnored private let effectContinuation: AsyncStream<RecorderEffect>.Continuation
    47	    @ObservationIgnored private var outstandingEngineCalls = 0
    48	    @ObservationIgnored private var filePassTask: Task<Void, Never>?
    49	    @ObservationIgnored private var rerunRequested = false
    50	    @ObservationIgnored private var journaledFinalTexts: [String] = []
    51	    @ObservationIgnored private var currentVolatile: String = ""
    52	    @ObservationIgnored private var degradedCaptures: Set<UUID> = []   // a journal append failed
    53	    @ObservationIgnored private var recordedBeforeSegment: TimeInterval = 0   // closed .recording stretches
    54	    @ObservationIgnored private var segmentStart: Date?                       // the open .recording stretch
    55	    @ObservationIgnored private var lengthTask: Task<Void, Never>?
    56	    @ObservationIgnored private var hasRun = false
    57	
    58	    init(engine: any CaptureEngine,
    59	         fileTranscriber: any FileTranscriber,
    60	         routeProvider: @escaping @Sendable () async -> TranscriptionRoute,
    61	         files: CaptureFiles,
    62	         importer: JournalImporter,
    63	         container: ModelContainer,
    64	         initialPermission: MicrophonePermission,
    65	         protectedDataAvailable: Bool,
    66	         inbox: CaptureLaunchInbox = .shared,
    67	         makeWriter: @escaping (CaptureFiles, UUID) throws -> any JournalAppending,
    68	         now: @escaping () -> Date = Date.init,
    69	         newID: @escaping () -> UUID = UUID.init,
    70	         lengthLimits: CaptureLengthLimits = .standard) {
    71	        self.engine = engine
    72	        self.fileTranscriber = fileTranscriber
    73	        self.routeProvider = routeProvider
    74	        self.files = files
    75	        self.importer = importer
    76	        self.container = container
    77	        self.inbox = inbox
    78	        self.makeWriter = makeWriter
    79	        self.now = now
    80	        self.newID = newID
    81	        self.lengthLimits = lengthLimits
    82	        self.state = RecorderState(permission: initialPermission,
    83	                                   protectedDataAvailable: protectedDataAvailable)
    84	
    85	        let (stream, continuation) = AsyncStream<RecorderEffect>.makeStream()
    86	        self.effectContinuation = continuation
    87	        // One serial consumer: engine effects are awaited one at a time, in order.
    88	        Task { [weak self] in
    89	            for await effect in stream {
    90	                guard let self else { return }
    91	                await self.performEngineEffect(effect)
    92	            }
    93	        }
    94	
    95	        inbox.onRequest = { [weak self] in
    96	            Task { await self?.drainLaunchInbox() }
    97	        }
    98	    }
    99	
   100	    /// The capture ID of the active phase, if any (excluded from import and the file pass).
   101	    var activeCaptureID: UUID? {
   102	        switch state.phase {
   103	        case .starting(let id, _), .recording(let id), .interrupted(let id),
   104	             .stopping(let id, _), .aborting(let id):
   105	            return id
   106	        case .idle, .blocked:
   107	            return nil
   108	        }
   109	    }
   110	
   111	    // MARK: - Event intake
   112	
   113	    /// files.prepare(); then, if protectedDataAvailable, one import + file pass; then
   114	    /// `for await e in engine.events { handle(e) }`. Returns when the stream finishes.
   115	    func run() async {
   116	        // engine.events has a single consumer; a re-created view's .task must not start a second loop.
   117	        guard !hasRun else { return }
   118	        hasRun = true
   119	        try? files.prepare()
   120	        if state.protectedDataAvailable {
   121	            lastImport = importer.importAll(into: container, excluding: activeCaptureID)
   122	            // In the background: an Action press during a long launch pass must not wait on it.
   123	            kickFilePass()
   124	        }
   125	        for await event in engine.events {
   126	            handle(event)
   127	        }
   128	    }
   129	
   130	    func handle(_ event: CaptureEngineEvent) {
   131	        switch event {
   132	        case .recorder(let recorderEvent):
   133	            if case .engineStartFailed = recorderEvent {
   134	                startFailure = engine.lastStartFailure ?? "unknown"
   135	            }
   136	            send(recorderEvent)
   137	        case .volatile(_, let text):
   138	            currentVolatile = text
   139	            rebuildLiveText()
   140	        }
   141	    }
   142	
   143	    /// reduce, enqueue effects, drain.
   144	    func send(_ event: RecorderEvent) {
   145	        let oldPhase = state.phase
   146	        let (newState, effects) = RecorderMachine.reduce(state, event, now: now(), newID: newID)
   147	        state = newState
   148	        updateLengthTimer(from: oldPhase)
   149	        processedEventCount += 1
   150	        effectQueue.append(contentsOf: effects)
   151	        drain()
   152	    }
   153	
   154	    /// Awaits until the effect queue is empty and every engine call has returned (tests).
   155	    func drainEffects() async {
   156	        var iterations = 0
   157	        while (isDraining || !effectQueue.isEmpty || outstandingEngineCalls > 0) && iterations < 10_000 {
   158	            await Task.yield()
   159	            iterations += 1
   160	        }
   161	    }
   162	
   163	    // MARK: - Effect queue
   164	
   165	    /// FIFO drain. A send made during a drain only enqueues. Journal effects run synchronously;
   166	    /// engine effects are handed to the one serial effect task.
   167	    private func drain() {
   168	        guard !isDraining else { return }
   169	        isDraining = true
   170	        while !effectQueue.isEmpty {
   171	            let effect = effectQueue.removeFirst()
   172	            switch effect {
   173	            case .openJournal(let captureID):
   174	                do {
   175	                    writers[captureID] = try makeWriter(files, captureID)
   176	                } catch {
   177	                    // The audio survives and pass 2 adopts it; stop cleanly.
   178	                    journalError = error
   179	                    send(.tapStop)
   180	                }
   181	            case .journal(var record):
   182	                guard let writer = writers[record.captureID] else { continue }
   183	                if record.kind == .transcriberEnded, degradedCaptures.contains(record.captureID) {
   184	                    record.completed = false     // a segment may be missing: force the file pass
   185	                }
   186	                do {
   187	                    try writer.append(record)
   188	                    if record.kind == .segment, let text = record.text {
   189	                        journaledFinalTexts.append(text)
   190	                        rebuildLiveText()
   191	                    }
   192	                } catch {
   193	                    journalError = error        // the audio is the record; recording continues
   194	                    degradedCaptures.insert(record.captureID)
   195	                }
   196	            case .closeJournal(let captureID):
   197	                writers[captureID]?.close()
   198	                writers[captureID] = nil
   199	                degradedCaptures.remove(captureID)
   200	            case .importJournals:
   201	                guard state.protectedDataAvailable else { continue }
   202	                lastImport = importer.importAll(into: container, excluding: activeCaptureID)
   203	                kickFilePass()
   204	            case .startEngine, .pauseEngine, .resumeEngine, .stopEngine:
   205	                outstandingEngineCalls += 1
   206	                effectContinuation.yield(effect)
   207	            }
   208	        }
   209	        isDraining = false
   210	    }
   211	
   212	    private func performEngineEffect(_ effect: RecorderEffect) async {
   213	        switch effect {
   214	        case .startEngine(let captureID, let route):
   215	            do {
   216	                try files.prepare()
   217	            } catch {
   218	                journalError = error
   219	                startFailure = String(describing: error)
   220	                send(.engineStartFailed(captureID: captureID))
   221	                outstandingEngineCalls -= 1
   222	                return
   223	            }
   224	            journaledFinalTexts = []
   225	            currentVolatile = ""
   226	            liveText = ""
   227	            await engine.start(captureID: captureID, audioURL: files.audioURL(for: captureID), route: route)
   228	        case .pauseEngine(let captureID):
   229	            await engine.pause(captureID: captureID)
   230	        case .resumeEngine(let captureID):
   231	            await engine.resume(captureID: captureID)
   232	        case .stopEngine(let captureID):
   233	            await engine.stop(captureID: captureID)
   234	        case .openJournal, .journal, .closeJournal, .importJournals:
   235	            break   // handled synchronously in the drain
   236	        }
   237	        outstandingEngineCalls -= 1
   238	    }
   239	
   240	    private func rebuildLiveText() {
   241	        let joined = journaledFinalTexts.joined(separator: " ")
   242	        liveText = joined.isEmpty ? currentVolatile
   243	            : (currentVolatile.isEmpty ? joined : joined + " " + currentVolatile)
   244	    }
   245	
   246	    // MARK: - Length limit (S7a)
   247	
   248	    private static func isRecording(_ phase: RecorderPhase) -> Bool {
   249	        if case .recording = phase { return true }
   250	        return false
   251	    }
   252	
   253	    /// Counts recorded time only: a stretch opens on entering .recording and closes on leaving it,
   254	    /// so .interrupted time does not count. A new capture (.starting) resets the count and the banner.
   255	    private func updateLengthTimer(from oldPhase: RecorderPhase) {
   256	        let wasRecording = Self.isRecording(oldPhase)
   257	        let isRecording = Self.isRecording(state.phase)
   258	        if case .starting = state.phase {
   259	            recordedBeforeSegment = 0
   260	            segmentStart = nil

### Retold/Capture/Device/SpeechModules.swift
     1	import CoreMedia
     2	import Foundation
     3	import Speech
     4	
     5	/// One place that maps a TranscriptionRoute to its SpeechAnalyzer module, so the route probe,
     6	/// the file transcriber and the live engine agree. Also the one place that maps a Speech result
     7	/// to a plain value, so Rule 1 (verbatim final text) lives in a single helper.
     8	enum SpeechModules {
     9	    /// The module for `route`, or nil for .audioOnly. `live` adds .volatileResults to the
    10	    /// reporting options; both module kinds always ask for .audioTimeRange so segment times
    11	    /// are audio-file time.
    12	    static func module(for route: TranscriptionRoute, live: Bool) -> (any SpeechModule)? {
    13	        switch route {
    14	        case .speech(let id):
    15	            return SpeechTranscriber(
    16	                locale: Locale(identifier: id),
    17	                transcriptionOptions: [],
    18	                reportingOptions: live ? [.volatileResults] : [],
    19	                attributeOptions: [.audioTimeRange])
    20	        case .dictation(let id):
    21	            return DictationTranscriber(
    22	                locale: Locale(identifier: id),
    23	                contentHints: [],
    24	                transcriptionOptions: [],
    25	                reportingOptions: live ? [.volatileResults] : [],
    26	                attributeOptions: [.audioTimeRange])
    27	        case .audioOnly:
    28	            return nil
    29	        }
    30	    }
    31	
    32	    /// A route-agnostic result value; callers never switch on the module type twice.
    33	    struct SpeechResultValue: Sendable {
    34	        let text: String       // String(result.text.characters), verbatim (Rule 1)
    35	        let start: TimeInterval
    36	        let end: TimeInterval
    37	        let isFinal: Bool
    38	    }
    39	
    40	    /// The module's result stream mapped to SpeechResultValue. Ends by throwing on error.
    41	    static func results(of module: any SpeechModule) -> AsyncThrowingStream<SpeechResultValue, Error> {
    42	        if let transcriber = module as? SpeechTranscriber {
    43	            return mapped(transcriber.results) { result in
    44	                SpeechResultValue(text: String(result.text.characters),
    45	                                  start: result.range.start.seconds,
    46	                                  end: CMTimeRangeGetEnd(result.range).seconds,
    47	                                  isFinal: result.isFinal)
    48	            }
    49	        }
    50	        if let transcriber = module as? DictationTranscriber {
    51	            return mapped(transcriber.results) { result in
    52	                SpeechResultValue(text: String(result.text.characters),
    53	                                  start: result.range.start.seconds,
    54	                                  end: CMTimeRangeGetEnd(result.range).seconds,
    55	                                  isFinal: result.isFinal)
    56	            }
    57	        }
    58	        return AsyncThrowingStream { $0.finish() }
    59	    }
    60	
    61	    /// Generic over the SDK's result sequence type; `sending` moves it into the task, so it need
    62	    /// not be Sendable.
    63	    private static func mapped<S: AsyncSequence>(
    64	        _ stream: sending S,
    65	        _ transform: @escaping @Sendable (S.Element) -> SpeechResultValue
    66	    ) -> AsyncThrowingStream<SpeechResultValue, Error> {
    67	        let (output, continuation) = AsyncThrowingStream<SpeechResultValue, Error>.makeStream()
    68	        let task = Task {
    69	            do {
    70	                for try await result in stream {
    71	                    continuation.yield(transform(result))
    72	                }
    73	                continuation.finish()
    74	            } catch {
    75	                continuation.finish(throwing: error)
    76	            }
    77	        }
    78	        continuation.onTermination = { _ in task.cancel() }
    79	        return output
    80	    }
    81	}

### Retold/Capture/Device/LiveCaptureEngine.swift (lines 170-215: volatile results path, read-only context)
   170	        }
   171	        tapInstalled = true
   172	
   173	        startStep = "engine start"
   174	        engine.prepare()
   175	        try engine.start()
   176	        activeFlag.withLockUnchecked { $0 = (true, inputFormat) }
   177	
   178	        // Order matters (spec 4.1): both yields precede any result the task can produce.
   179	        eventsContinuation.yield(.recorder(.engineStarted(captureID: captureID)))
   180	        guard let results else { return }
   181	        eventsContinuation.yield(.recorder(
   182	            .transcriberRunStarted(captureID: captureID, run: 0, audioOffset: 0)))
   183	
   184	        let continuation = eventsContinuation
   185	        capture.resultsTask = Task {
   186	            do {
   187	                for try await result in results {
   188	                    if result.isFinal {
   189	                        continuation.yield(.recorder(.finalSegment(
   190	                            captureID: captureID, run: 0,
   191	                            segment: TranscriptSegment(text: result.text,
   192	                                                       start: result.start,
   193	                                                       end: result.end,
   194	                                                       isFinal: true))))
   195	                    } else {
   196	                        continuation.yield(.volatile(captureID: captureID, text: result.text))
   197	                    }
   198	                }
   199	            } catch {
   200	                capture.resultsFailed.withLock { $0 = true }
   201	            }
   202	        }
   203	    }
   204	
   205	    /// iOS rejects some category and mode pairs with OSStatus -50, and which pairs it accepts can
   206	    /// differ by device and OS. Try the preferred pair, then pairs that are always valid for recording.
   207	    private func configureSession() throws {
   208	        let attempts: [(AVAudioSession.Category, AVAudioSession.Mode)] = [
   209	            (.record, .spokenAudio),
   210	            (.playAndRecord, .spokenAudio),
   211	            (.playAndRecord, .default),
   212	            (.record, .default),
   213	        ]
   214	        var firstError: Error?
   215	        for (category, mode) in attempts {

### Retold/Copy/AppCopy.swift
     1	import Foundation
     2	
     3	/// The user-facing strings PLAN already fixes, verbatim, so WellnessLint has real copy to
     4	/// check before any string catalog exists. Not wired to any view in R3.
     5	enum AppCopy {
     6	    /// PLAN section 8: why suggestions are unavailable on a phone without Apple Intelligence.
     7	    static let newerPhoneReason = "Suggestions need a newer iPhone; everything else works"
     8	    /// PLAN section 8: why suggestions are unavailable while Apple Intelligence is off.
     9	    static let appleIntelligenceOffReason = "Turn on Apple Intelligence in Settings to get suggested questions"
    10	    /// PLAN section 8: why suggestions are unavailable while models are downloading.
    11	    static let modelsDownloadingReason = "Suggestions will appear once your phone finishes downloading them"
    12	
    13	    /// PLAN section 7: the line that reinstates an interrupted open question.
    14	    static let reinstatement = "Take a second. Where were you, what time of year, who was around \u{2014} then talk."
    15	    /// PLAN section 5.2: the nudge notification body.
    16	    static let nudgeWaiting = "One question waiting"
    17	    /// PLAN section 9: the fallback explanation for unsupported phones.
    18	    static let fallback = "Suggested questions use Apple Intelligence on supported iPhones; recording, filing and browsing work on every iPhone running iOS 26."
    19	
    20	    /// R6b: first-run microphone prompt.
    21	    static let micPrompt = "Retold records your voice while you talk through a memory."
    22	    /// R6b: first-run grant button.
    23	    static let micAllow = "Allow microphone"
    24	    /// R6b: shown when the microphone grant is denied.
    25	    static let micDenied = "Microphone access is off. Turn it on in Settings to record."
    26	    /// R6b: home screen record button.
    27	    static let recordButton = "Record a memory"
    28	    /// R6b: recorder stop button.
    29	    static let stopButton = "Stop"
    30	    /// R6b: recorder resume button while interrupted.
    31	    static let resumeButton = "Resume"
    32	    /// R6b: recorder state label while recording.
    33	    static let recordingLabel = "Recording"
    34	    /// Recorder state label while the engine is starting, before audio is captured.
    35	    static let startingLabel = "Getting ready..."
    36	    /// Recorder state label while the file is being finalized after Stop.
    37	    static let savingLabel = "Saving..."
    38	    /// VoiceOver label for the playback scrubber.
    39	    static let playbackPosition = "Playback position"
    40	    /// VoiceOver label prefix for a remove (trash) button; the item name follows.
    41	    static let removeLabel = "Remove"
    42	    /// Settings sheet dismiss button.
    43	    static let doneButton = "Done"
    44	    /// Confirm flow: why File it is unavailable.
    45	    static let titleNeededHint = "Add a title to file this memory."
    46	    /// R6b: recorder state label while interrupted.
    47	    static let pausedLabel = "Paused"
    48	    /// R6b: the store failed to open at launch.
    49	    static let startupFailedTitle = "Retold could not start"
    50	    static let startupFailed = "Retold could not open its storage. Try again, or restart the app."
    51	    static let tryAgain = "Try again"
    52	    /// R6b: home screen title (the week-0 scaffold's, moved here so views carry no literals).
    53	    static let homeTitle = "Retold"
    54	    static let filedLabel = "Filed"
    55	    static let homeEmptyTitle = "Your stories will gather here"
    56	    static let homeEmptyMessage = "Tap Record a memory and tell one story, in your own words."
    57	    static let browseHeader = "Browse"
    58	    /// R6b spec 7a: the recorder banner after 20 minutes of recording.
    59	    static let lengthWarning = "Retold stops this recording at 30 minutes."
    60	
    61	    /// R7a: heading for captures that have not been filed.
    62	    static let unfiledHeader = "Unfiled"
    63	    /// R7a: state shown while a capture is being transcribed.
    64	    static let transcribingLabel = "Transcribing..."
    65	    /// R7a: state shown when a capture has no transcript.
    66	    static let noTranscriptLabel = "No transcript -- you can still file it"
    67	    /// R7a: confirm-flow filing action.
    68	    static let fileButton = "File it"
    69	    /// R7a: label for an unaccepted suggestion.
    70	    static let suggestedLabel = "suggested"
    71	    /// R7a: accepts a suggested value.
    72	    static let acceptButton = "Use this"
    73	    /// R7a: rejects a suggested value.
    74	    static let rejectButton = "Not this"
    75	    /// R7a: confirm-flow title section.
    76	    static let titleHeader = "Title"
    77	    /// R7a: prompt for a user-authored title.
    78	    static let titlePlaceholder = "Type a title"
    79	    /// R7a: confirm-flow period section.
    80	    static let periodHeader = "Period"
    81	    /// R7a: period picker option for no period.
    82	    static let noPeriod = "Not in a period"
    83	    /// R7a: period picker option for a new period.
    84	    static let newPeriod = "New period..."
    85	    /// R7a: prompt for a new period title.
    86	    static let newPeriodPlaceholder = "Name the period"
    87	    /// R7a: confirm-flow when section.
    88	    static let whenHeader = "When"
    89	    /// R7a: year mode for the when answer.
    90	    static let whenYear = "Year"
    91	    /// R7a: age mode for the when answer.
    92	    static let whenAge = "Age"
    93	    /// R7a: action for leaving the when answer open.
    94	    static let notSure = "Not sure"
    95	    /// R7a: confirm-flow people section.
    96	    static let peopleHeader = "People"
    97	    /// R7a: confirm-flow place section.
    98	    static let placesHeader = "Place"
    99	    /// R7a: action for adding a person.
   100	    static let addPerson = "Add a person"
   101	    /// R7a: action for adding a place.
   102	    static let addPlace = "Add a place"
   103	    /// R7a: prefix for reusing an existing entity.
   104	    static let sameAs = "Same as"
   105	    /// R7a: option for creating a person.
   106	    static let newPerson = "New person"
   107	    /// R7a: option for creating a place.
   108	    static let newPlace = "New place"
   109	    /// R7a: confirm-flow follow-up section.
   110	    static let followUpsHeader = "Questions for later"
   111	    /// R7a: keeps a follow-up question open.
   112	    static let later = "Later"
   113	    /// R7a: retires a follow-up question.
   114	    static let notThisOne = "Not this one"
   115	    /// R7a: progress copy while suggestions are generated.
   116	    static let findingSuggestions = "Looking for names and places..."
   117	    /// R7a: action for cancelling suggestion generation.
   118	    static let skipSuggestions = "Skip suggestions"
   119	    /// R7a: settings screen title.
   120	    static let settingsTitle = "Settings"
   121	    /// R7a: setting that enables filing suggestions.
   122	    static let suggestionsToggle = "Suggestions"
   123	    /// R7a: explanation of where suggestions are generated.
   124	    static let suggestionsFootnote = "Suggestions are made on this iPhone."
   125	
   126	    /// R7b: title shown for an episode whose title is not confirmed.
   127	    static let untitled = "Untitled"
   128	    /// R7b: title of the Places list.
   129	    static let placesTitle = "Places"
   130	    /// R7b: title of the Themes page.
   131	    static let themesTitle = "Themes"
   132	    /// R7b: title of the Periods page.
   133	    static let periodsTitle = "Periods"
   134	    /// R7b: action for adding a period.
   135	    static let addPeriod = "Add a period"
   136	    /// R7b: action for renaming a period.
   137	    static let renamePeriod = "Rename"
   138	    /// R7b: footnote shown when a period title is a duplicate.
   139	    static let duplicatePeriod = "There is already a period with that name."
   140	    /// R7b: save action in the period sheet.
   141	    static let saveButton = "Save"
   142	    /// R7b: cancel action in the period sheet.
   143	    static let cancelButton = "Cancel"
   144	    /// Empty page: title when a page has no questions and no stories yet.
   145	    static let emptyTitle = "Nothing here yet"
   146	    /// Empty page: the one action, to leave an empty page.
   147	    static let goBack = "Go back"
   148	    /// Empty period page: what will appear.
   149	    static let emptyPeriodMessage = "Stories you file under this period will appear here."
   150	    /// Empty person page: what will appear.
   151	    static let emptyPersonMessage = "Stories that mention this person will appear here."
   152	    /// Empty place page: what will appear.
   153	    static let emptyPlaceMessage = "Stories filed at this place will appear here."
   154	    /// Empty People list: title.
   155	    static let noPeopleTitle = "No people yet"
   156	    /// Empty People list: what will appear.
   157	    static let noPeopleMessage = "People you confirm while filing a story will appear here."
   158	    /// Empty Places list: title.
   159	    static let noPlacesTitle = "No places yet"
   160	    /// Empty Places list: what will appear.
   161	    static let noPlacesMessage = "Places you confirm while filing a story will appear here."
   162	    /// Themes page: title when every question has been answered or set aside.
   163	    static let themesEmptyTitle = "All caught up"
   164	    /// Themes page: why the list is empty and what brings questions back.
   165	    static let themesEmptyMessage = "You have been through every question for now. New ones appear as you record more memories."
   166	    /// Alert title when recording cannot start because the microphone is off.
   167	    static let micBlockedTitle = "Microphone is off"
   168	    /// Alert action that opens the iOS Settings page for this app.
   169	    static let openSettings = "Open Settings"
   170	    /// Alert title when a question action could not be saved.
   171	    static let saveFailedTitle = "That did not save"
   172	    /// Alert message when a question action could not be saved.
   173	    static let saveFailedMessage = "Try again in a moment."
   174	    /// Alert dismiss button.
   175	    static let okButton = "OK"
   176	    /// Set-aside page: title, also the Home link.
   177	    static let setAsideTitle = "Set-aside questions"
   178	    /// Set-aside page: empty title.
   179	    static let setAsideEmptyTitle = "Nothing set aside"
   180	    /// Set-aside page: empty message.
   181	    static let setAsideEmptyMessage = "Questions you choose Not this one on appear here, so you can bring them back."
   182	    /// Set-aside page: action that reopens a question.
   183	    static let bringBack = "Bring back"
   184	    /// Alert title when a recording could not start.
   185	    static let startFailedTitle = "Recording could not start"
   186	    /// Alert message prefix; the technical detail follows it.
   187	    static let startFailedMessage = "Nothing was recorded. Close Retold and try again. Details: "
   188	    /// R7b: heading for the open questions on a page.
   189	    static let questionsHeader = "Questions"
   190	    /// R7b: action for answering a question by recording.
   191	    static let answerNow = "Answer now"
   192	    /// R7b: heading for an episode's recordings.
   193	    static let recordingsHeader = "Recordings"
   194	    /// R7b: state shown when a recording has no transcript.
   195	    static let noTranscript = "No transcript"
   196	    /// R7b: state shown when a recording's audio file is gone.
   197	    static let audioMissing = "The recording file is missing."
   198	    static let playbackFailed = "This recording could not play. Try again in a moment."
   199	    /// R7b: play action.
   200	    static let playButton = "Play"
   201	    /// R7b: pause action.
   202	    static let pauseButton = "Pause"
   203	    /// R7b: recorder label while a capture answers a question.
   204	    static let answeringLabel = "Answering"
   205	    /// R7b: settings action that builds the export.
   206	    static let exportButton = "Export everything"
   207	    /// R7b: fixed line shown beside the export action.
   208	    static let exportNote = "Recordings may name other people."
   209	    /// R7b: progress copy while the export is built.
   210	    static let preparingExport = "Preparing the export..."
   211	    /// R7b: footnote shown when the export fails.
   212	    static let exportFailed = "The export could not be made. Try again."
   213	    /// R7b: label of the share link for a finished export.
   214	    static let shareExport = "Share the export"
   215	    /// R7c: swipe action that deletes an unfiled recording.
   216	    static let deleteAction = "Delete"
   217	    /// R7c: title of the delete confirmation.
   218	    static let deleteRecordingTitle = "Delete this recording?"
   219	    /// R7c: message of the delete confirmation.
   220	    static let deleteRecordingMessage = "The recording and its transcript will be removed from this phone. This can't be undone."
   221	    /// R7c: label of the confirming delete button.
   222	    static let deleteRecordingConfirm = "Delete recording"
   223	    /// R7c: alert shown when a delete fails.
   224	    static let deleteFailed = "The recording couldn't be deleted. Try again."
   225	
   226	    static let all: [String] = [
   227	        newerPhoneReason,
   228	        appleIntelligenceOffReason,
   229	        modelsDownloadingReason,
   230	        reinstatement,
   231	        nudgeWaiting,
   232	        fallback,
   233	        micPrompt,
   234	        micAllow,
   235	        micDenied,
   236	        recordButton,
   237	        stopButton,
   238	        resumeButton,
   239	        recordingLabel,
   240	        startingLabel,
   241	        savingLabel,
   242	        playbackPosition,
   243	        playbackFailed,
   244	        removeLabel,
   245	        doneButton,
   246	        titleNeededHint,
   247	        pausedLabel,
   248	        startupFailed,
   249	        homeTitle,
   250	        filedLabel,
   251	        homeEmptyTitle,
   252	        homeEmptyMessage,
   253	        browseHeader,
   254	        lengthWarning,
   255	        unfiledHeader,
   256	        transcribingLabel,
   257	        noTranscriptLabel,
   258	        fileButton,
   259	        suggestedLabel,
   260	        acceptButton,
   261	        rejectButton,
   262	        titleHeader,
   263	        titlePlaceholder,
   264	        periodHeader,
   265	        noPeriod,
   266	        newPeriod,
   267	        newPeriodPlaceholder,
   268	        whenHeader,
   269	        whenYear,
   270	        whenAge,
   271	        notSure,
   272	        peopleHeader,
   273	        placesHeader,
   274	        addPerson,
   275	        addPlace,
   276	        sameAs,
   277	        newPerson,
   278	        newPlace,
   279	        followUpsHeader,
   280	        later,
   281	        notThisOne,
   282	        findingSuggestions,
   283	        skipSuggestions,
   284	        settingsTitle,
   285	        suggestionsToggle,
   286	        suggestionsFootnote,
   287	        untitled,
   288	        placesTitle,
   289	        themesTitle,
   290	        startFailedTitle,
   291	        startFailedMessage,
   292	        setAsideTitle,
   293	        setAsideEmptyTitle,
   294	        setAsideEmptyMessage,
   295	        bringBack,
   296	        micBlockedTitle,
   297	        openSettings,
   298	        saveFailedTitle,
   299	        saveFailedMessage,
   300	        okButton,
   301	        emptyTitle,
   302	        goBack,
   303	        emptyPeriodMessage,
   304	        emptyPersonMessage,
   305	        emptyPlaceMessage,
   306	        noPeopleTitle,
   307	        noPeopleMessage,
   308	        noPlacesTitle,
   309	        noPlacesMessage,
   310	        themesEmptyTitle,
   311	        themesEmptyMessage,
   312	        periodsTitle,
   313	        addPeriod,
   314	        renamePeriod,
   315	        duplicatePeriod,
   316	        saveButton,
   317	        cancelButton,
   318	        questionsHeader,
   319	        answerNow,
   320	        recordingsHeader,
   321	        noTranscript,
   322	        audioMissing,
   323	        playButton,
   324	        pauseButton,
   325	        answeringLabel,
   326	        exportButton,
   327	        exportNote,
   328	        preparingExport,
   329	        exportFailed,
   330	        shareExport,
   331	        deleteAction,
   332	        deleteRecordingTitle,
   333	        deleteRecordingMessage,
   334	        deleteRecordingConfirm,
   335	        deleteFailed,
   336	        startupFailedTitle,
   337	        tryAgain,
   338	    ]
   339	}

## Sibling counterpart: StoryCue (same brand line, SwiftUI)

### storycue/StoryCue/DesignTokens.swift
     1	import SwiftUI
     2	
     3	enum DesignTokens {
     4	    enum Spacing {           // multiples of 4
     5	        static let xs: CGFloat = 4
     6	        static let s: CGFloat = 8
     7	        static let m: CGFloat = 12
     8	        static let l: CGFloat = 16
     9	        static let xl: CGFloat = 24
    10	    }
    11	    enum Radius {
    12	        static let card: CGFloat = 12      // cards, banners, callouts
    13	        static let tile: CGFloat = 10      // deck tiles
    14	    }
    15	    enum Motion {                          // nothing over 0.5 s
    16	        static let morph = Animation.spring(duration: 0.3)
    17	        static let fade = Animation.easeOut(duration: 0.2)
    18	    }
    19	    enum RecordButton {
    20	        static let outer: CGFloat = 72
    21	        static let ringWidth: CGFloat = 4
    22	        static let dot: CGFloat = 58
    23	        static let square: CGFloat = 28
    24	        static let squareRadius: CGFloat = 6
    25	    }
    26	    /// The serif trial (design review row 6). Revert to `.default` in this one line.
    27	    static let questionFontDesign: Font.Design = .serif
    28	    static let onAccent = Color("OnAccent")
    29	    /// Deck tiles: one terracotta family, never a rainbow (WW-0103 disagreement 4).
    30	    static let tileFill = Color.accentColor.opacity(0.15)
    31	    static let tileSymbol = Color.accentColor
    32	    static func deckSymbol(_ deckID: String) -> String {
    33	        switch deckID {
    34	        case "grandparents": "house"
    35	        case "parents": "figure.2.and.child.holdinghands"
    36	        case "kids": "questionmark.bubble"
    37	        case "couples": "heart"
    38	        case "holiday-table": "fork.knife"
    39	        default: "text.bubble"
    40	        }
    41	    }
    42	    /// Translucent black behind text over the camera (>= 7:1 white text over a white feed).
    43	    static let overCameraFill = Color.black.opacity(0.7)
    44	    /// The recording pill: darker than system red so white text clears 4.5:1.
    45	    static let recordingFill = Color(red: 0.78, green: 0.10, blue: 0.10)
    46	    /// The recording pill in the last minute before the answer cap: amber with black ink
    47	    /// (about 12:1), always paired with the "1 min left" word.
    48	    static let capWarningFill = Color(red: 1.0, green: 0.76, blue: 0.03)
    49	    static let capWarningInk = Color.black
    50	    #if DEBUG
    51	    static let demoBackdropTop = Color(red: 0.20, green: 0.13, blue: 0.09)
    52	    static let demoBackdropBottom = Color(red: 0.06, green: 0.04, blue: 0.03)
    53	    #endif
    54	}
    55	
    56	extension View {
    57	    /// The one filled primary action of a screen: full width, large, accent fill,
    58	    /// `OnAccent` label. Apply to a `Button` whose label is `Text`.
    59	    func primaryAction() -> some View {
    60	        self
    61	            .buttonStyle(.borderedProminent)
    62	            .controlSize(.large)
    63	            .foregroundStyle(DesignTokens.onAccent)
    64	    }
    65	}

### storycue/StoryCue/Views/RecorderView.swift (lines 230-330: question type, record button)
   230	        }
   231	        .buttonStyle(.plain)
   232	        .padding(.vertical, -8)              // 44 pt to touch, 28 pt of card height
   233	        .accessibilitySortPriority(-1)       // VoiceOver reads the question first
   234	        .accessibilityLabel(questionIsLow ? UICopy.moveQuestionToTop : UICopy.moveQuestionToBottom)
   235	        .accessibilityIdentifier("questionHandle")
   236	    }
   237	
   238	    private func questionPanel(movable: Bool) -> some View {
   239	        VStack(alignment: .leading, spacing: 8) {
   240	            if movable { questionHandle }
   241	            Text(UICopy.questionCounter(store.state.questionIndex, store.state.deck.questions.count))
   242	                .font(.footnote)
   243	                .foregroundStyle(.white.opacity(0.85))
   244	            Text(store.currentQuestion.text)
   245	                .font(.largeTitle.bold())
   246	                .fontDesign(DesignTokens.questionFontDesign)
   247	                .foregroundStyle(.white)
   248	            if let next = store.nextQuestionPreview {
   249	                Text(next.text)
   250	                    .font(.callout)
   251	                    .fontDesign(DesignTokens.questionFontDesign)
   252	                    .foregroundStyle(.white.opacity(0.85))
   253	            }
   254	        }
   255	        .frame(maxWidth: .infinity, alignment: .leading)
   256	        .padding()
   257	        // Translucent black backing: white text stays >=7:1 even over a pure-white feed
   258	        // (70% black over white  8.5:1; 60% was only  5.7:1). Secondary lines use opaque-ish white, not .secondary, which
   259	        // is translucent gray and drops below 3:1 over a bright feed.
   260	        .background(DesignTokens.overCameraFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
   261	        .accessibilityElement(children: .contain)
   262	        .accessibilityIdentifier("questionPanel")
   263	    }
   264	
   265	    // MARK: - Recording indicator
   266	
   267	    /// Top right, red, only while the camera is actually writing: the filmer and the subject
   268	    /// can both tell at a glance whether it is on.
   269	    @ViewBuilder
   270	    private var recordingIndicator: some View {
   271	        if presentation.showsRecordingDot, let timerText = presentation.timerText {
   272	            // Near the cap the pill turns amber AND says so in words (not color alone).
   273	            let word = nearsCap ? UICopy.nearCapIndicator : UICopy.recordingIndicator
   274	            let ink = nearsCap ? DesignTokens.capWarningInk : Color.white
   275	            HStack(spacing: 6) {
   276	                Circle()
   277	                    .fill(ink)
   278	                    .frame(width: 8, height: 8)
   279	                Text(word)
   280	                    .fontWeight(.semibold)
   281	                Text(timerText)
   282	                    .monospacedDigit()
   283	            }
   284	            .lineLimit(1)
   285	            // The toolbar item proposes less than the pill needs and the word truncated to
   286	            // "Recordi..." (comeup-04 review shot, 2026-11-09): take the ideal width instead.
   287	            .fixedSize()
   288	            .font(.subheadline)
   289	            .foregroundStyle(ink)
   290	            .padding(.horizontal, 10)
   291	            .padding(.vertical, 4)
   292	            .background(nearsCap ? DesignTokens.capWarningFill : DesignTokens.recordingFill, in: Capsule())
   293	            // The nav bar has a fixed height; past AX1 the pill would clip.
   294	            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
   295	            .accessibilityElement(children: .ignore)
   296	            .accessibilityLabel("\(word), \(timerText)")
   297	            .accessibilityIdentifier("recordingIndicator")
   298	        }
   299	    }
   300	
   301	    // MARK: - Banner
   302	
   303	    @ViewBuilder
   304	    private var bannerRow: some View {
   305	        if let text = bannerString(presentation.banner) {
   306	            bannerText(text)
   307	        }
   308	    }
   309	
   310	    private func bannerText(_ text: String) -> some View {
   311	        Text(text)
   312	            .font(.callout)
   313	            // Wrap, never truncate: the read-aloud banner quotes the consent line, and at AX5
   314	            // it was cut to "First, have them..." (review screenshot ax5-03-recorder). Capped
   315	            // at AX2 so the banner can't crowd out the question card.
   316	            .fixedSize(horizontal: false, vertical: true)
   317	            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
   318	            .foregroundStyle(.white)
   319	            .frame(maxWidth: .infinity)
   320	            .padding()
   321	            .background(DesignTokens.overCameraFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
   322	    }
   323	
   324	    // MARK: - Controls
   325	
   326	    @ViewBuilder
   327	    private var controlsRow: some View {
   328	        if dynamicTypeSize.isAccessibilitySize {
   329	            // Side by side, no spacer column: stacking cost the question card most of its
   330	            // height at AX5 (review screenshot ax5-03-recorder). Control labels cap at AX2;

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
