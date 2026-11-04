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

=== RUBRIC ===
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

Output a score table first, then findings ordered blocker -> polish.

=== BAR (Perry, 2026-11-04): from Wilderness Survival he likes: motion and transitions, haptics, state clarity, visual polish.
NOTE: veterans are web/React Native (Tauri/Expo), Retold is SwiftUI. Cite the veteran BEHAVIOR and file:line; the fix must be expressed in SwiftUI/UIKit terms.

=== TARGET: RETOLD (SwiftUI) screens ===

--- retold/Retold/RetoldApp.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	import UIKit
     4	
     5	@main
     6	struct RetoldApp: App {
     7	    @State private var services: LiveCapture.LiveCaptureServices?
     8	    @State private var startupFailed = false
     9	
    10	    var body: some Scene {
    11	        WindowGroup {
    12	            Group {
    13	                if startupFailed {
    14	                    Text(AppCopy.startupFailed)
    15	                        .padding()
    16	                } else if let services {
    17	                    RootView(services: services)
    18	                } else {
    19	                    ProgressView()
    20	                }
    21	            }
    22	            .task {
    23	                guard services == nil, !startupFailed else { return }
    24	                do {
    25	                    #if DEBUG
    26	                    // `-RetoldDemo` (ScreenshotTests only) launches the seeded mock demo; everything
    27	                    // else is production. The Release build compiles only the production line below.
    28	                    if DemoMode.isActive {
    29	                        services = try DemoMode.makeServices()
    30	                    } else {
    31	                        services = try LiveCapture.makeCoordinator()
    32	                    }
    33	                    #else
    34	                    services = try LiveCapture.makeCoordinator()
    35	                    #endif
    36	                } catch {
    37	                    startupFailed = true
    38	                }
    39	            }
    40	        }
    41	    }
    42	}
    43	
    44	/// Routes between first run, recorder and home, and turns scene / protected-data signals
    45	/// into coordinator events.
    46	private struct RootView: View {
    47	    let services: LiveCapture.LiveCaptureServices
    48	    @Environment(\.scenePhase) private var scenePhase
    49	    @State private var autoPresentID: UUID?
    50	    @State private var playback: AudioPlayback
    51	
    52	    private var coordinator: CaptureCoordinator { services.coordinator }
    53	
    54	    init(services: LiveCapture.LiveCaptureServices) {
    55	        self.services = services
    56	        _playback = State(initialValue: AudioPlayback(files: services.coordinator.files))
    57	    }
    58	
    59	    var body: some View {
    60	        Group {
    61	            if coordinator.state.permission == .undetermined {
    62	                FirstRunView(engine: services.engine, prefetch: services.prefetch) { permission in
    63	                    coordinator.send(.permissionChanged(permission))
    64	                }
    65	            } else {
    66	                switch coordinator.state.phase {
    67	                case .starting, .recording, .interrupted, .stopping:
    68	                    RecorderView(coordinator: coordinator)
    69	                case .idle, .blocked, .aborting:
    70	                    HomeView(coordinator: coordinator, autoPresentID: $autoPresentID)
    71	                }
    72	            }
    73	        }
    74	        .environment(playback)
    75	        .environment(coordinator)
    76	        .modelContainer(services.container)
    77	        .task {
    78	            // The export zip holds the whole library unencrypted in tmp: clear any leftover.
    79	            ExportArchiver.sweep(workDirectory: ExportArchiver.defaultWorkDirectory)
    80	            await coordinator.run()
    81	        }
    82	        .onChange(of: coordinator.state.phase) { oldPhase, newPhase in
    83	            if case .stopping(let id, _) = oldPhase, case .idle = newPhase {
    84	                autoPresentID = id
    85	            }
    86	            // Playback yields to the recorder (covers the Control and the Action button). The
    87	            // recorder's own setCategory supersedes playback, so the session is not deactivated.
    88	            switch newPhase {
    89	            case .idle, .blocked:
    90	                break
    91	            default:
    92	                playback.stop(deactivateSession: false)
    93	            }
    94	        }
    95	        // initial: true -- RootView appears only after the services exist, when the scene is already
    96	        // active; without it a cold launch from the Control never drains the launch inbox.
    97	        .onChange(of: scenePhase, initial: true) { _, newPhase in
    98	            Task { @MainActor in
    99	                switch newPhase {
   100	                case .active:
   101	                    coordinator.send(.sceneDidBecomeActive)
   102	                    await coordinator.drainLaunchInbox()
   103	                case .inactive:
   104	                    coordinator.send(.sceneWillResignActive)
   105	                case .background:
   106	                    coordinator.send(.sceneDidEnterBackground)
   107	                @unknown default:
   108	                    break
   109	                }
   110	            }
   111	        }
   112	        .onReceive(NotificationCenter.default.publisher(
   113	            for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
   114	            Task { @MainActor in coordinator.send(.protectedDataWillBecomeUnavailable) }
   115	        }
   116	        .onReceive(NotificationCenter.default.publisher(
   117	            for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
   118	            Task { @MainActor in coordinator.send(.protectedDataDidBecomeAvailable) }
   119	        }
   120	    }
   121	}

--- retold/Retold/Screens/ConfirmView.swift ---
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
    12	
    13	    @Environment(\.dismiss) private var dismiss
    14	    @Environment(\.modelContext) private var modelContext
    15	    @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
    16	    @Query(sort: \Period.sortOrder) private var periods: [Period]
    17	    @Query(sort: \Person.name) private var people: [Person]
    18	    @Query(sort: \Place.name) private var places: [Place]
    19	
    20	    @State private var draft: ConfirmDraft?
    21	    @State private var mode: FilingMode?
    22	    @State private var suggestionTask: Task<FilingOutcome, Never>?
    23	    @State private var findingSuggestions = false
    24	    @State private var whenMode = WhenMode.year
    25	    @State private var selectedWhenValue: Int?
    26	    @State private var newPersonName = ""
    27	    @State private var newPlaceName = ""
    28	
    29	    private enum WhenMode: Hashable {
    30	        case year, age
    31	    }
    32	
    33	    private enum PeriodPickerValue: Hashable {
    34	        case none
    35	        case existing(UUID)
    36	        case new
    37	    }
    38	
    39	    var body: some View {
    40	        NavigationStack {
    41	            Group {
    42	                if let current = draft {
    43	                    form(current)
    44	                } else if findingSuggestions {
    45	                    VStack(spacing: 16) {
    46	                        ProgressView()
    47	                        Text(AppCopy.findingSuggestions)
    48	                        Button(AppCopy.skipSuggestions) {
    49	                            skipSuggestions()
    50	                        }
    51	                    }
    52	                    .padding()
    53	                } else {
    54	                    Color.clear
    55	                }
    56	            }
    57	            .toolbar {
    58	                ToolbarItem(placement: .cancellationAction) {
    59	                    Button(AppCopy.cancelButton) { dismiss() }
    60	                }
    61	                ToolbarItem(placement: .confirmationAction) {
    62	                    Button(AppCopy.fileButton) {
    63	                        file()
    64	                    }
    65	                    .disabled(!(draft?.canFile ?? false))
    66	                }
    67	            }
    68	        }
    69	        .task {
    70	            await load()
    71	        }
    72	        .onDisappear {
    73	            suggestionTask?.cancel()
    74	        }
    75	    }
    76	
    77	    @ViewBuilder
    78	    private func form(_ current: ConfirmDraft) -> some View {
    79	        Form {
    80	            if case .deck(let reason)? = mode, let copy = reason.copy {
    81	                Section {
    82	                    Text(copy)
    83	                        .font(.footnote)
    84	                        .foregroundStyle(.secondary)
    85	                }
    86	            }
    87	
    88	            Section(AppCopy.titleHeader) {
    89	                switch row {
    90	                case .ready(let excerpt):
    91	                    Text(excerpt)
    92	                case .noTranscript:
    93	                    Text(AppCopy.noTranscriptLabel)
    94	                case .transcribing:
    95	                    Text(AppCopy.transcribingLabel)
    96	                }
    97	                if let chip = current.titleChip {
    98	                    suggestionRow(chip: chip) {
    99	                        mutateDraft { $0.acceptTitle() }
   100	                    } reject: {
   101	                        mutateDraft { $0.rejectTitle() }
   102	                    }
   103	                }
   104	                TextField(AppCopy.titlePlaceholder, text: Binding(
   105	                    get: { draft?.typedTitle ?? "" },
   106	                    set: { value in mutateDraft { $0.typedTitle = value } }
   107	                ))
   108	                if !current.canFile {
   109	                    Text(AppCopy.titleNeededHint)
   110	                        .font(.footnote)
   111	                        .foregroundStyle(.secondary)
   112	                }
   113	            }
   114	
   115	            Section(AppCopy.periodHeader) {
   116	                if let suggested = current.suggestedPeriod,
   117	                   current.periodSuggestionState != .rejected {
   118	                    HStack {
   119	                        Text(suggested.title)
   120	                        if current.periodSuggestionState == .suggested {
   121	                            Text(AppCopy.suggestedLabel)
   122	                                .foregroundStyle(.secondary)
   123	                        }
   124	                        Spacer()
   125	                        Button(AppCopy.acceptButton) {
   126	                            mutateDraft { $0.acceptSuggestedPeriod() }
   127	                        }
   128	                        Button(AppCopy.rejectButton) {
   129	                            mutateDraft { $0.rejectSuggestedPeriod() }
   130	                        }
   131	                    }
   132	                    .buttonStyle(.borderless)
   133	                }
   134	                Picker(AppCopy.periodHeader, selection: periodSelection) {
   135	                    Text(AppCopy.noPeriod).tag(PeriodPickerValue.none)
   136	                    ForEach(periods) { period in
   137	                        Text(period.title).tag(PeriodPickerValue.existing(period.id))
   138	                    }
   139	                    Text(AppCopy.newPeriod).tag(PeriodPickerValue.new)
   140	                }
   141	                if case .new = current.periodPick {
   142	                    TextField(AppCopy.newPeriodPlaceholder, text: Binding(
   143	                        get: {
   144	                            if case .new(let title)? = draft?.periodPick { return title }
   145	                            return ""
   146	                        },
   147	                        set: { title in mutateDraft { $0.pick(.new(title)) } }
   148	                    ))
   149	                }
   150	            }
   151	
   152	            Section(AppCopy.whenHeader) {
   153	                Text(current.whenQuestion.text)
   154	                Picker(AppCopy.whenHeader, selection: $whenMode) {
   155	                    Text(AppCopy.whenYear).tag(WhenMode.year)
   156	                    Text(AppCopy.whenAge).tag(WhenMode.age)
   157	                }
   158	                .pickerStyle(.segmented)
   159	                .onChange(of: whenMode) { _, _ in
   160	                    selectedWhenValue = nil
   161	                    mutateDraft { $0.setWhen(.notSure) }
   162	                }
   163	                Picker(AppCopy.whenHeader, selection: $selectedWhenValue) {
   164	                    Text("-").tag(Int?.none)
   165	                    if whenMode == .year {
   166	                        ForEach(Array(stride(from: Calendar.current.component(.year, from: Date()), through: 1900, by: -1)), id: \.self) { year in
   167	                            Text(String(year)).tag(Int?.some(year))
   168	                        }
   169	                    } else {
   170	                        ForEach(0...100, id: \.self) { age in
   171	                            Text(String(age)).tag(Int?.some(age))
   172	                        }
   173	                    }
   174	                }
   175	                .pickerStyle(.wheel)
   176	                .onChange(of: selectedWhenValue) { _, value in
   177	                    guard let value else {
   178	                        mutateDraft { $0.setWhen(.notSure) }
   179	                        return
   180	                    }
   181	                    mutateDraft {
   182	                        $0.setWhen(whenMode == .year ? .year(value) : .age(value))
   183	                    }
   184	                }
   185	                Button(AppCopy.notSure) {
   186	                    selectedWhenValue = nil
   187	                    mutateDraft { $0.setWhen(.notSure) }
   188	                }
   189	            }
   190	
   191	            Section(AppCopy.peopleHeader) {
   192	                ForEach(current.people) { chip in
   193	                    suggestionRow(chip: chip) {
   194	                        mutateDraft { $0.setChip(chip.id, .accepted) }
   195	                    } reject: {
   196	                        mutateDraft { $0.setChip(chip.id, .rejected) }
   197	                    }
   198	                    if chip.state == .accepted, let match = chip.match {
   199	                        Picker(AppCopy.peopleHeader, selection: Binding(
   200	                            get: {
   201	                                draft?.people.first(where: { $0.id == chip.id })?.useMatch ?? true
   202	                            },
   203	                            set: { useMatch in
   204	                                mutateDraft { $0.setUseMatch(chip.id, useMatch) }
   205	                            }
   206	                        )) {
   207	                            Text("\(AppCopy.sameAs) \(match.name)").tag(true)
   208	                            Text(AppCopy.newPerson).tag(false)
   209	                        }
   210	                        .pickerStyle(.segmented)
   211	                    }
   212	                }
   213	                ForEach(Array(current.typedPeople.enumerated()), id: \.offset) { index, entity in
   214	                    HStack {
   215	                        Text(entityName(entity, known: current.knownPeople))
   216	                        Spacer()
   217	                        Button {
   218	                            mutateDraft { $0.removeTypedPerson(at: index) }
   219	                        } label: {
   220	                            Image(systemName: "trash")
   221	                        }
   222	                    }
   223	                    .buttonStyle(.borderless)
   224	                }
   225	                Menu(AppCopy.addPerson) {
   226	                    ForEach(current.knownPeople, id: \.id) { person in
   227	                        Button(person.name) {
   228	                            mutateDraft { $0.addTypedPerson(.existing(person.id)) }
   229	                        }
   230	                    }
   231	                }
   232	                TextField(AppCopy.newPerson, text: $newPersonName)
   233	                    .onSubmit {
   234	                        let name = newPersonName
   235	                        mutateDraft { $0.addTypedPerson(.new(name)) }
   236	                        newPersonName = ""
   237	                    }
   238	            }
   239	
   240	            Section(AppCopy.placesHeader) {
   241	                ForEach(current.places) { chip in
   242	                    suggestionRow(chip: chip) {
   243	                        mutateDraft { $0.setChip(chip.id, .accepted) }
   244	                    } reject: {
   245	                        mutateDraft { $0.setChip(chip.id, .rejected) }
   246	                    }
   247	                    if chip.state == .accepted, let match = chip.match {
   248	                        Picker(AppCopy.placesHeader, selection: Binding(
   249	                            get: {
   250	                                draft?.places.first(where: { $0.id == chip.id })?.useMatch ?? true
   251	                            },
   252	                            set: { useMatch in
   253	                                mutateDraft { $0.setUseMatch(chip.id, useMatch) }
   254	                            }
   255	                        )) {
   256	                            Text("\(AppCopy.sameAs) \(match.name)").tag(true)
   257	                            Text(AppCopy.newPlace).tag(false)
   258	                        }
   259	                        .pickerStyle(.segmented)
   260	                    }
   261	                }
   262	                if let typedPlace = current.typedPlace {
   263	                    HStack {
   264	                        Text(entityName(typedPlace, known: current.knownPlaces))
   265	                        Spacer()
   266	                        Button {
   267	                            mutateDraft { $0.setTypedPlace(nil) }
   268	                        } label: {
   269	                            Image(systemName: "trash")
   270	                        }
   271	                    }
   272	                    .buttonStyle(.borderless)
   273	                }
   274	                Menu(AppCopy.addPlace) {
   275	                    ForEach(current.knownPlaces, id: \.id) { place in
   276	                        Button(place.name) {
   277	                            mutateDraft { $0.setTypedPlace(.existing(place.id)) }
   278	                        }
   279	                    }
   280	                }
   281	                TextField(AppCopy.newPlace, text: $newPlaceName)
   282	                    .onSubmit {
   283	                        let name = newPlaceName
   284	                        mutateDraft { $0.setTypedPlace(.new(name)) }
   285	                        newPlaceName = ""
   286	                    }
   287	            }
   288	
   289	            Section(AppCopy.followUpsHeader) {
   290	                ForEach(current.followUps.filter { current.isLive($0) }) { row in
   291	                    VStack(alignment: .leading, spacing: 8) {
   292	                        Text(row.question.text)
   293	                        if row.question.templateID != FilingTemplates.broad.id {
   294	                            HStack {
   295	                                choiceButton(
   296	                                    AppCopy.later,
   297	                                    selected: row.choice == .later
   298	                                ) {
   299	                                    mutateDraft { $0.setRow(row.id, .later) }
   300	                                }
   301	                                choiceButton(
   302	                                    AppCopy.notThisOne,
   303	                                    selected: row.choice == .notThisOne
   304	                                ) {
   305	                                    mutateDraft { $0.setRow(row.id, .notThisOne) }
   306	                                }
   307	                            }
   308	                        }
   309	                    }
   310	                }
   311	            }
   312	        }
   313	    }
   314	
   315	    private func suggestionRow(
   316	        chip: SpanChip,
   317	        accept: @escaping () -> Void,
   318	        reject: @escaping () -> Void
   319	    ) -> some View {
   320	        HStack {
   321	            Text(chip.span.text)
   322	            if chip.state == .suggested {
   323	                Text(AppCopy.suggestedLabel)
   324	                    .foregroundStyle(.secondary)
   325	            }
   326	            Spacer()
   327	            Button(AppCopy.acceptButton, action: accept)
   328	            Button(AppCopy.rejectButton, action: reject)
   329	        }
   330	        .buttonStyle(.borderless)
   331	    }
   332	
   333	    private func choiceButton(
   334	        _ title: String,
   335	        selected: Bool,
   336	        action: @escaping () -> Void
   337	    ) -> some View {
   338	        Button(action: action) {
   339	            HStack {
   340	                if selected {
   341	                    Image(systemName: "checkmark")
   342	                }
   343	                Text(title)
   344	            }
   345	        }
   346	        .buttonStyle(.borderless)
   347	    }
   348	
   349	    private var periodSelection: Binding<PeriodPickerValue> {
   350	        Binding(
   351	            get: {
   352	                switch draft?.periodPick ?? .none {
   353	                case .none: return .none
   354	                case .existing(let id): return .existing(id)
   355	                case .new: return .new
   356	                }
   357	            },
   358	            set: { selection in
   359	                mutateDraft {
   360	                    switch selection {
   361	                    case .none: $0.pick(.none)
   362	                    case .existing(let id): $0.pick(.existing(id))
   363	                    case .new: $0.pick(.new(""))
   364	                    }
   365	                }
   366	            }
   367	        )
   368	    }
   369	
   370	    private func entityName(_ entity: TypedEntity, known: [EntityRef]) -> String {
   371	        switch entity {
   372	        case .existing(let id):
   373	            return known.first(where: { $0.id == id })?.name ?? ""
   374	        case .new(let name):
   375	            return name.trimmingCharacters(in: .whitespacesAndNewlines)
   376	        }
   377	    }
   378	
   379	    private func mutateDraft(_ mutation: (inout ConfirmDraft) -> Void) {
   380	        guard var value = draft else { return }
   381	        mutation(&value)
   382	        draft = value
   383	    }
   384	
   385	    @MainActor
   386	    private func load() async {
   387	        guard draft == nil else { return }
   388	        #if DEBUG
   389	        // `-RetoldDemo` only: a simulator has no Apple Intelligence, so the demo files through the
   390	        // production pipeline over a scripted model (DemoMode.filingPipeline). Without the
   391	        // argument this block does nothing; the Release build does not compile it.
   392	        if DemoMode.isActive {
   393	            mode = .model
   394	            if let transcript = capture.completedTranscript {
   395	                let outcome = await DemoMode.filingPipeline()
   396	                    .file(transcript, periodTitles: periods.map(\.title))
   397	                buildDraft(outcome: outcome)
   398	            } else {
   399	                buildDraft(outcome: nil)
   400	            }

--- retold/Retold/Screens/EmptyPage.swift ---
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

--- retold/Retold/Screens/EpisodeView.swift ---
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
    14	            if hasFacts(facts) {
    15	                Section {
    16	                    factRows(facts)
    17	                }
    18	            }
    19	            OfferSection(
    20	                offers: QuestionEngine.queue(for: EpisodeState(episode: episode)),
    21	                target: .episode(episode)
    22	            )
    23	            Section(AppCopy.recordingsHeader) {
    24	                ForEach(sortedCaptures) { capture in
    25	                    captureBlock(capture)
    26	                }
    27	            }
    28	        }
    29	        .navigationTitle(facts.title ?? AppCopy.untitled)
    30	    }
    31	
    32	    private var sortedCaptures: [Capture] {
    33	        episode.captures.sorted { (a: Capture, b: Capture) -> Bool in
    34	            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
    35	        }
    36	    }
    37	
    38	    private func hasFacts(_ facts: EpisodeFacts) -> Bool {
    39	        facts.period != nil || facts.whenDisplay != nil || facts.place != nil
    40	            || !facts.people.isEmpty || !facts.details.isEmpty
    41	    }
    42	
    43	    @ViewBuilder
    44	    private func factRows(_ facts: EpisodeFacts) -> some View {
    45	        if let period = facts.period {
    46	            LabeledContent(AppCopy.periodHeader, value: period.title)
    47	        }
    48	        if let when = facts.whenDisplay {
    49	            LabeledContent(AppCopy.whenHeader, value: when)
    50	        }
    51	        if let ref = facts.place, let place = episode.place {
    52	            NavigationLink(ref.name, destination: PlaceView(place: place))
    53	        }
    54	        ForEach(facts.people, id: \.id) { ref in
    55	            if let person = episode.people.first(where: { $0.id == ref.id }) {
    56	                NavigationLink(ref.name, destination: PersonView(person: person))
    57	            }
    58	        }
    59	        ForEach(Array(facts.details.enumerated()), id: \.offset) { _, text in
    60	            Text("\u{201C}\(text)\u{201D}")
    61	        }
    62	    }
    63	
    64	    @ViewBuilder
    65	    private func captureBlock(_ capture: Capture) -> some View {
    66	        VStack(alignment: .leading, spacing: 8) {
    67	            Text("\(capture.createdAt.formatted(date: .abbreviated, time: .shortened)) \u{00B7} \(ExportManifest.formatClock(capture.duration))")
    68	                .font(.subheadline)
    69	            if playback.canPlay(capture.id) {
    70	                playerRow(capture)
    71	            } else {
    72	                Text(AppCopy.audioMissing)
    73	                    .foregroundStyle(.secondary)
    74	            }
    75	            transcript(capture)
    76	        }
    77	    }
    78	
    79	    private func playerRow(_ capture: Capture) -> some View {
    80	        let isLoaded = playback.captureID == capture.id
    81	        return HStack {
    82	            PlayPauseButton(captureID: capture.id)
    83	            Slider(
    84	                value: Binding(
    85	                    get: { isLoaded ? playback.currentTime : 0 },
    86	                    set: { value in
    87	                        if playback.captureID == capture.id {
    88	                            playback.seek(to: value)
    89	                        } else {
    90	                            playback.play(capture.id, from: value)
    91	                        }
    92	                    }
    93	                ),
    94	                in: 0...max(capture.duration, 1)
    95	            )
    96	            .disabled(capture.duration <= 0)
    97	            Text("\(ExportManifest.formatClock(isLoaded ? playback.currentTime : 0)) / \(ExportManifest.formatClock(capture.duration))")
    98	                .font(.footnote.monospacedDigit())
    99	                .foregroundStyle(.secondary)
   100	        }
   101	        .buttonStyle(.borderless)
   102	    }
   103	
   104	    @ViewBuilder
   105	    private func transcript(_ capture: Capture) -> some View {
   106	        switch CaptureTranscriptState.of(status: capture.transcriptionStatus, segments: capture.transcript) {
   107	        case .transcribing:
   108	            Text(AppCopy.transcribingLabel)
   109	                .foregroundStyle(.secondary)
   110	        case .none:
   111	            Text(AppCopy.noTranscript)
   112	                .foregroundStyle(.secondary)
   113	        case .segments(let segments):
   114	            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
   115	                Button {
   116	                    playback.play(capture.id, from: segment.start)
   117	                } label: {
   118	                    Text("\(ExportManifest.formatClock(segment.start))  \(segment.text)")
   119	                        .frame(maxWidth: .infinity, alignment: .leading)
   120	                }
   121	                .buttonStyle(.borderless)
   122	            }
   123	        }
   124	    }
   125	}

--- retold/Retold/Screens/FirstRunView.swift ---
     1	import SwiftUI
     2	
     3	/// R6b first run: the microphone grant plus asset prefetch (R7 replaces this screen).
     4	struct FirstRunView: View {
     5	    let engine: LiveCaptureEngine
     6	    let prefetch: AssetPrefetch
     7	    let onDone: (MicrophonePermission) -> Void
     8	    @State private var denied = false
     9	
    10	    var body: some View {
    11	        VStack(spacing: 20) {
    12	            Text(AppCopy.micPrompt)
    13	                .multilineTextAlignment(.center)
    14	            if denied {
    15	                Text(AppCopy.micDenied)
    16	                    .font(.footnote)
    17	                    .foregroundStyle(.secondary)
    18	                    .multilineTextAlignment(.center)
    19	            }
    20	            Button(AppCopy.micAllow) {
    21	                Task { @MainActor in
    22	                    let permission = await engine.requestMicrophonePermission()
    23	                    guard permission != .denied else {
    24	                        denied = true
    25	                        return
    26	                    }
    27	                    Task { await prefetch.run() }   // never blocks the UI
    28	                    onDone(permission)
    29	                }
    30	            }
    31	        }
    32	        .padding()
    33	    }
    34	}

--- retold/Retold/Screens/HomeView.swift ---
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
    27	
    28	    private var sections: [TimelineSection] {
    29	        Timeline.sections(
    30	            periods: periods.map { PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder) },
    31	            episodes: episodes.map { TimelineEpisode(id: $0.id, periodID: $0.period?.id, createdAt: $0.createdAt) }
    32	        )
    33	    }
    34	
    35	    var body: some View {
    36	        let periodsByID = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
    37	        let episodesByID = Dictionary(uniqueKeysWithValues: episodes.map { ($0.id, $0) })
    38	        NavigationStack {
    39	            List {
    40	                Section {
    41	                    Button(AppCopy.recordButton) {
    42	                        // Stop playback (deactivating) before the capture starts, while the phase is .idle.
    43	                        playback.stop()
    44	                        Task { @MainActor in
    45	                            await coordinator.startCapture(answering: nil)
    46	                            // A denied microphone used to do nothing visible.
    47	                            if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
    48	                                micBlocked = true
    49	                            }
    50	                        }
    51	                    }
    52	                }
    53	                if !unfiledCaptures.isEmpty {
    54	                    Section(AppCopy.unfiledHeader) {
    55	                        ForEach(unfiledCaptures) { capture in
    56	                            unfiledRow(capture)
    57	                                // Not a full swipe: a full swipe must never delete without the dialog.
    58	                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
    59	                                    Button(AppCopy.deleteAction, role: .destructive) { pendingDeleteID = capture.id }
    60	                                }
    61	                        }
    62	                    }
    63	                }
    64	                Section {
    65	                    NavigationLink(AppCopy.peopleHeader, destination: PeopleView())
    66	                    NavigationLink(AppCopy.placesTitle, destination: PlacesView())
    67	                    NavigationLink(AppCopy.themesTitle, destination: ThemesView())
    68	                    NavigationLink(AppCopy.periodsTitle, destination: PeriodsView())
    69	                    NavigationLink(AppCopy.setAsideTitle, destination: SetAsideView())
    70	                }
    71	                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
    72	                    Section {
    73	                        if let ref = section.period {
    74	                            if let period = periodsByID[ref.id] {
    75	                                NavigationLink(destination: PeriodView(period: period)) {
    76	                                    Text(ref.title)
    77	                                        .font(.headline)
    78	                                }
    79	                            }
    80	                        } else {
    81	                            Text(AppCopy.noPeriod)
    82	                                .font(.headline)
    83	                        }
    84	                        ForEach(section.episodeIDs, id: \.self) { id in
    85	                            if let episode = episodesByID[id] {
    86	                                EpisodeRow(episode: episode)
    87	                            }
    88	                        }
    89	                    }
    90	                }
    91	            }
    92	            .navigationTitle(AppCopy.homeTitle)
    93	            .toolbar {
    94	                ToolbarItem(placement: .topBarTrailing) {
    95	                    Button {
    96	                        showingSettings = true
    97	                    } label: {
    98	                        Image(systemName: "gearshape")
    99	                    }
   100	                }
   101	            }
   102	        }
   103	        .sheet(isPresented: $showingSettings) {
   104	            SettingsView(files: coordinator.files)
   105	        }
   106	        .sheet(item: $selectedCapture) { capture in
   107	            ConfirmView(
   108	                capture: capture,
   109	                row: ConfirmDraft.unfiledRow(
   110	                    status: capture.transcriptionStatus,
   111	                    transcript: capture.completedTranscript
   112	                ),
   113	                cachedOutcome: outcomes[capture.id],
   114	                answeredPeriodID: selectedAnsweredPeriodID
   115	            ) { outcome in
   116	                outcomes[capture.id] = outcome
   117	            }
   118	        }
   119	        .confirmationDialog(
   120	            AppCopy.deleteRecordingTitle,
   121	            isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
   122	            titleVisibility: .visible,
   123	            presenting: pendingDeleteID
   124	        ) { id in
   125	            Button(AppCopy.deleteRecordingConfirm, role: .destructive) { deleteCapture(id) }
   126	        } message: { _ in
   127	            Text(AppCopy.deleteRecordingMessage)
   128	        }
   129	        .alert(AppCopy.deleteFailed, isPresented: $deleteFailed) {
   130	            Button("OK") {}
   131	        }
   132	        .alert(AppCopy.startFailedTitle, isPresented: Binding(
   133	            get: { coordinator.startFailure != nil },
   134	            set: { if !$0 { coordinator.clearStartFailure() } }
   135	        )) {
   136	            Button(AppCopy.okButton, role: .cancel) {}
   137	        } message: {
   138	            Text(AppCopy.startFailedMessage + (coordinator.startFailure ?? ""))
   139	        }
   140	        .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
   141	            Button(AppCopy.openSettings) {
   142	                if let url = URL(string: UIApplication.openSettingsURLString) {
   143	                    openURL(url)
   144	                }
   145	            }
   146	            Button(AppCopy.cancelButton, role: .cancel) {}
   147	        } message: {
   148	            Text(AppCopy.micDenied)
   149	        }
   150	        .onAppear {
   151	            // Order matters: seed periods, then attach answers, then auto-present. Home is created
   152	            // fresh after Stop, so autoPresentID is already set here; an episode answer must attach
   153	            // before auto-present, or it would open a confirm sheet it should not get.
   154	            try? DefaultPeriods.seedIfNeeded(modelContext, defaults: .standard)
   155	            _ = try? AnswerAttacher.attachPending(in: modelContext)
   156	            handleAutoPresent()
   157	        }
   158	        .onChange(of: autoPresentID) { _, _ in
   159	            handleAutoPresent()
   160	        }
   161	        .onChange(of: coordinator.lastImport) { _, _ in
   162	            _ = try? AnswerAttacher.attachPending(in: modelContext)
   163	        }
   164	        // The file pass completes audio-only captures without setting lastImport.
   165	        .onChange(of: scenePhase) { _, newPhase in
   166	            if newPhase == .active {
   167	                _ = try? AnswerAttacher.attachPending(in: modelContext)
   168	            }
   169	        }
   170	    }
   171	
   172	    @ViewBuilder
   173	    private func unfiledRow(_ capture: Capture) -> some View {
   174	        let state = ConfirmDraft.unfiledRow(
   175	            status: capture.transcriptionStatus,
   176	            transcript: capture.completedTranscript
   177	        )
   178	        switch state {
   179	        case .transcribing:
   180	            // Tappable: a recording whose transcript never arrives (no on-device speech for this
   181	            // locale) must still be fileable with a typed title. ConfirmView handles this row.
   182	            Button {
   183	                present(capture)
   184	            } label: {
   185	                captureRow(capture, detail: AppCopy.transcribingLabel)
   186	            }
   187	            .buttonStyle(.plain)
   188	        case .ready(let excerpt):
   189	            Button {
   190	                present(capture)
   191	            } label: {
   192	                captureRow(capture, detail: excerpt)
   193	            }
   194	            .buttonStyle(.plain)
   195	        case .noTranscript:
   196	            Button {
   197	                present(capture)
   198	            } label: {
   199	                captureRow(capture, detail: AppCopy.noTranscriptLabel)
   200	            }
   201	            .buttonStyle(.plain)
   202	        }
   203	    }
   204	
   205	    private func captureRow(_ capture: Capture, detail: String) -> some View {
   206	        VStack(alignment: .leading, spacing: 4) {
   207	            Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
   208	            Text(detail)
   209	                .foregroundStyle(.secondary)
   210	                .lineLimit(2)
   211	        }
   212	        .frame(maxWidth: .infinity, alignment: .leading)
   213	        .contentShape(Rectangle())
   214	    }
   215	
   216	    @MainActor
   217	    private func deleteCapture(_ id: UUID) {
   218	        do {
   219	            try CaptureDeleter.delete(
   220	                captureID: id,
   221	                activeCaptureID: coordinator.activeCaptureID,
   222	                files: coordinator.files,
   223	                in: modelContext.container
   224	            )
   225	            outcomes[id] = nil
   226	        } catch CaptureDeleteError.filed {
   227	            // Attached since the swipe: the row has already left Unfiled.
   228	        } catch {
   229	            deleteFailed = true
   230	        }
   231	    }
   232	
   233	    /// Computes the answered period once per presentation, never in the sheet closure.
   234	    private func present(_ capture: Capture) {
   235	        selectedAnsweredPeriodID = AnswerAttacher.answeredPeriodID(for: capture, in: modelContext)
   236	        selectedCapture = capture
   237	    }
   238	
   239	    private func handleAutoPresent() {
   240	        guard let id = autoPresentID else { return }
   241	        defer { autoPresentID = nil }
   242	        // An answer to an episode's question attaches first, so it never opens a confirm sheet.
   243	        _ = try? AnswerAttacher.attachPending(in: modelContext)
   244	        let wantedID = id
   245	        var descriptor = FetchDescriptor<Capture>(
   246	            predicate: #Predicate { $0.id == wantedID }
   247	        )
   248	        descriptor.fetchLimit = 1
   249	        guard let captures = try? modelContext.fetch(descriptor),
   250	              let capture = captures.first,
   251	              capture.episode == nil
   252	        else { return }
   253	
   254	        switch ConfirmDraft.unfiledRow(
   255	            status: capture.transcriptionStatus,
   256	            transcript: capture.completedTranscript
   257	        ) {
   258	        case .ready, .noTranscript:
   259	            present(capture)
   260	        case .transcribing:
   261	            break
   262	        }
   263	    }
   264	}
   265	
   266	/// A button that plays or pauses one capture. Disabled when its audio file is missing.
   267	struct PlayPauseButton: View {
   268	    let captureID: UUID
   269	
   270	    @Environment(AudioPlayback.self) private var playback
   271	
   272	    var body: some View {
   273	        let isThisPlaying = playback.captureID == captureID && playback.isPlaying
   274	        Button {
   275	            if isThisPlaying {
   276	                playback.pause()
   277	            } else {
   278	                playback.play(captureID)
   279	            }
   280	        } label: {
   281	            Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
   282	        }
   283	        .buttonStyle(.borderless)
   284	        .disabled(!playback.canPlay(captureID))
   285	        .accessibilityLabel(isThisPlaying ? AppCopy.pauseButton : AppCopy.playButton)
   286	    }
   287	}
   288	
   289	/// One episode in a list (R7b section 7.2), reused by the period, person and place pages.
   290	struct EpisodeRow: View {
   291	    let episode: Episode
   292	
   293	    private var firstCapture: Capture? {
   294	        episode.captures.sorted { (a: Capture, b: Capture) -> Bool in
   295	            (a.createdAt, a.id.uuidString) < (b.createdAt, b.id.uuidString)
   296	        }.first
   297	    }
   298	
   299	    var body: some View {
   300	        let facts = EpisodeFacts(episode: episode)
   301	        NavigationLink(destination: EpisodeView(episode: episode)) {
   302	            HStack {
   303	                VStack(alignment: .leading, spacing: 4) {
   304	                    Text(facts.title ?? AppCopy.untitled)
   305	                    // Verbatim user words, the same line the export prints; not a Confirmable.
   306	                    if !episode.excerpt.isEmpty {
   307	                        Text(episode.excerpt)
   308	                            .font(.subheadline)
   309	                            .foregroundStyle(.secondary)
   310	                            .lineLimit(1)
   311	                    }
   312	                    if let when = facts.whenDisplay {
   313	                        Text(when)
   314	                            .font(.subheadline)
   315	                            .foregroundStyle(.secondary)
   316	                    }
   317	                }
   318	                Spacer()
   319	                if let capture = firstCapture {
   320	                    PlayPauseButton(captureID: capture.id)
   321	                }
   322	            }
   323	        }
   324	    }
   325	}
   326	
   327	extension Collection where Element == Episode {
   328	    /// Newest first, by `(createdAt descending, id.uuidString)`.
   329	    func newestFirst() -> [Episode] {
   330	        sorted { (a: Episode, b: Episode) -> Bool in
   331	            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
   332	            return a.id.uuidString < b.id.uuidString
   333	        }
   334	    }
   335	}

--- retold/Retold/Screens/OfferRow.swift ---
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
    22	                Button(AppCopy.answerNow) {
    23	                    answerNow()
    24	                }
    25	                // .dontRemember does nothing on broad.open (Question.record), as on the confirm screen.
    26	                if offer.question.templateID != "broad.open" {
    27	                    Button(AppCopy.notThisOne) {
    28	                        notThisOne()
    29	                    }
    30	                }
    31	            }
    32	            .buttonStyle(.borderless)
    33	        }
    34	        .alert(AppCopy.micBlockedTitle, isPresented: $micBlocked) {
    35	            Button(AppCopy.openSettings) {
    36	                if let url = URL(string: UIApplication.openSettingsURLString) {
    37	                    openURL(url)
    38	                }
    39	            }
    40	            Button(AppCopy.cancelButton, role: .cancel) {}
    41	        } message: {
    42	            Text(AppCopy.micDenied)
    43	        }
    44	        .alert(AppCopy.saveFailedTitle, isPresented: $saveFailed) {
    45	            Button(AppCopy.okButton, role: .cancel) {}
    46	        } message: {
    47	            Text(AppCopy.saveFailedMessage)
    48	        }
    49	    }
    50	
    51	    private func answerNow() {
    52	        playback.stop()
    53	        let id: UUID
    54	        do {
    55	            id = try QuestionActions.prepareAnswer(offer, target: target, in: modelContext)
    56	        } catch {
    57	            saveFailed = true
    58	            return
    59	        }
    60	        let coordinator = coordinator
    61	        Task { @MainActor in
    62	            await coordinator.startCapture(answering: id)
    63	            if case .blocked = coordinator.state.phase, coordinator.state.permission == .denied {
    64	                micBlocked = true
    65	            }
    66	        }
    67	    }
    68	
    69	    private func notThisOne() {
    70	        do {
    71	            try QuestionActions.notThisOne(offer, target: target, in: modelContext)
    72	        } catch {
    73	            saveFailed = true
    74	        }
    75	    }
    76	}
    77	
    78	/// A `Section(questionsHeader)` with one OfferRow per offer, in the engine's queue order.
    79	/// Omitted when the queue is empty.
    80	struct OfferSection: View {
    81	    let offers: [EngineOffer]
    82	    let target: OfferTarget
    83	
    84	    var body: some View {
    85	        if !offers.isEmpty {
    86	            Section(AppCopy.questionsHeader) {
    87	                ForEach(Array(offers.enumerated()), id: \.offset) { _, offer in
    88	                    OfferRow(offer: offer, target: target)
    89	                }
    90	            }
    91	        }
    92	    }
    93	}

--- retold/Retold/Screens/PeopleView.swift ---
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

--- retold/Retold/Screens/PeriodView.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// A period's page (R7b section 7.5): its open questions (for an empty period, the R5 opener),
     5	/// then its episodes, newest first.
     6	struct PeriodView: View {
     7	    let period: Period
     8	
     9	    @Query private var allQuestions: [Question]
    10	
    11	    var body: some View {
    12	        let offers = QuestionEngine.queue(for: PeriodState(period: period, questions: allQuestions))
    13	        Group {
    14	            if offers.isEmpty && period.episodes.isEmpty {
    15	                EmptyPage(title: AppCopy.emptyTitle, message: AppCopy.emptyPeriodMessage)
    16	            } else {
    17	                List {
    18	                    OfferSection(offers: offers, target: .period(period))
    19	                    Section {
    20	                        ForEach(period.episodes.newestFirst()) { episode in
    21	                            EpisodeRow(episode: episode)
    22	                        }
    23	                    }
    24	                }
    25	            }
    26	        }
    27	        .navigationTitle(period.title)
    28	    }
    29	}

--- retold/Retold/Screens/PeriodsView.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// The Periods page (R7b section 7.5): rename and add. No reordering, no delete in 1.0.
     5	struct PeriodsView: View {
     6	    @Query private var periods: [Period]
     7	
     8	    @State private var sheet: PeriodSheetTarget?
     9	
    10	    private var ordered: [Period] {
    11	        periods.sorted { (a: Period, b: Period) -> Bool in
    12	            (a.sortOrder, a.id.uuidString) < (b.sortOrder, b.id.uuidString)
    13	        }
    14	    }
    15	
    16	    var body: some View {
    17	        List {
    18	            ForEach(ordered) { period in
    19	                Button(period.title) {
    20	                    sheet = .rename(period)
    21	                }
    22	                .buttonStyle(.plain)
    23	            }
    24	            Button(AppCopy.addPeriod) {
    25	                sheet = .add
    26	            }
    27	        }
    28	        .navigationTitle(AppCopy.periodsTitle)
    29	        .sheet(item: $sheet) { target in
    30	            PeriodEditSheet(target: target)
    31	        }
    32	    }
    33	}
    34	
    35	enum PeriodSheetTarget: Identifiable {
    36	    case add
    37	    case rename(Period)
    38	
    39	    var id: String {
    40	        switch self {
    41	        case .add: return "add"
    42	        case .rename(let period): return period.id.uuidString
    43	        }
    44	    }
    45	}
    46	
    47	/// The rename / add sheet. Save is disabled while the trimmed text is empty; a duplicate keeps
    48	/// the sheet open with a footnote. No alerts.
    49	struct PeriodEditSheet: View {
    50	    let target: PeriodSheetTarget
    51	
    52	    @Environment(\.modelContext) private var modelContext
    53	    @Environment(\.dismiss) private var dismiss
    54	    @State private var text: String
    55	    @State private var isDuplicate = false
    56	
    57	    init(target: PeriodSheetTarget) {
    58	        self.target = target
    59	        switch target {
    60	        case .add:
    61	            _text = State(initialValue: "")
    62	        case .rename(let period):
    63	            _text = State(initialValue: period.title)
    64	        }
    65	    }
    66	
    67	    private var isAdd: Bool {
    68	        if case .add = target { return true }
    69	        return false
    70	    }
    71	
    72	    var body: some View {
    73	        NavigationStack {
    74	            Form {
    75	                Section {
    76	                    TextField(AppCopy.newPeriodPlaceholder, text: $text)
    77	                    if isDuplicate {
    78	                        Text(AppCopy.duplicatePeriod)
    79	                            .font(.footnote)
    80	                            .foregroundStyle(.secondary)
    81	                    }
    82	                }
    83	            }
    84	            .navigationTitle(isAdd ? AppCopy.addPeriod : AppCopy.renamePeriod)
    85	            .navigationBarTitleDisplayMode(.inline)
    86	            .toolbar {
    87	                ToolbarItem(placement: .cancellationAction) {
    88	                    Button(AppCopy.cancelButton) {
    89	                        dismiss()
    90	                    }
    91	                }
    92	                ToolbarItem(placement: .confirmationAction) {
    93	                    Button(AppCopy.saveButton) {
    94	                        save()
    95	                    }
    96	                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    97	                }
    98	            }
    99	            .onChange(of: text) { _, _ in
   100	                isDuplicate = false
   101	            }
   102	        }
   103	    }
   104	
   105	    private func save() {
   106	        do {
   107	            switch target {
   108	            case .add:
   109	                _ = try PeriodEditor.add(title: text, in: modelContext)
   110	            case .rename(let period):
   111	                try PeriodEditor.rename(period, to: text, in: modelContext)
   112	            }
   113	            dismiss()
   114	        } catch PeriodEditError.duplicateTitle {
   115	            isDuplicate = true
   116	        } catch {
   117	            // .emptyTitle and save failures keep the sheet open, with no alert.
   118	        }
   119	    }
   120	}

--- retold/Retold/Screens/PlacesView.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// The Places list (R7b section 7.5).
     5	struct PlacesView: View {
     6	    @Query(sort: \Place.name) private var places: [Place]
     7	
     8	    var body: some View {
     9	        Group {
    10	            if places.isEmpty {
    11	                EmptyPage(title: AppCopy.noPlacesTitle, message: AppCopy.noPlacesMessage)
    12	            } else {
    13	                List(places) { place in
    14	                    NavigationLink(place.name, destination: PlaceView(place: place))
    15	                }
    16	            }
    17	        }
    18	        .navigationTitle(AppCopy.placesTitle)
    19	    }
    20	}
    21	
    22	/// One place's page: its episodes, newest first. There is no place engine, so no questions.
    23	struct PlaceView: View {
    24	    let place: Place
    25	
    26	    var body: some View {
    27	        Group {
    28	            if place.episodes.isEmpty {
    29	                EmptyPage(title: AppCopy.emptyTitle, message: AppCopy.emptyPlaceMessage)
    30	            } else {
    31	                List {
    32	                    Section {
    33	                        ForEach(place.episodes.newestFirst()) { episode in
    34	                            EpisodeRow(episode: episode)
    35	                        }
    36	                    }
    37	                }
    38	            }
    39	        }
    40	        .navigationTitle(place.name)
    41	    }
    42	}

--- retold/Retold/Screens/RecorderView.swift ---
     1	import Foundation
     2	import SwiftData
     3	import SwiftUI
     4	
     5	/// R6b recorder: red dot, elapsed time, live text, Stop, and Resume while interrupted
     6	/// (R7 replaces this screen; no design pass).
     7	struct RecorderView: View {
     8	    let coordinator: CaptureCoordinator
     9	    /// Approximation of "when the phase became .recording" (spec allows approximate):
    10	    /// the clock starts when this view appears for a capture.
    11	    @State private var startedAt = Date()
    12	    @Environment(\.modelContext) private var modelContext
    13	    /// R7b: the question this capture answers, fetched once on appear. Hidden when not found.
    14	    @State private var answeringText: String?
    15	
    16	    private var isInterrupted: Bool {
    17	        if case .interrupted = coordinator.state.phase { return true }
    18	        return false
    19	    }
    20	
    21	    private var isStopping: Bool {
    22	        if case .stopping = coordinator.state.phase { return true }
    23	        return false
    24	    }
    25	
    26	    var body: some View {
    27	        VStack(spacing: 20) {
    28	            if coordinator.state.answering != nil {
    29	                Text(AppCopy.answeringLabel)
    30	                    .foregroundStyle(.secondary)
    31	                if let answeringText {
    32	                    Text(answeringText)
    33	                }
    34	                Text(AppCopy.reinstatement)
    35	                    .font(.footnote)
    36	            }
    37	            Circle()
    38	                .fill(.red)
    39	                .frame(width: 16, height: 16)
    40	            TimelineView(.periodic(from: startedAt, by: 1)) { context in
    41	                Text(elapsed(at: context.date))
    42	                    .font(.title2.monospacedDigit())
    43	            }
    44	            ScrollView {
    45	                Text(coordinator.liveText)
    46	                    .frame(maxWidth: .infinity, alignment: .leading)
    47	            }
    48	            if isInterrupted {
    49	                Text(AppCopy.pausedLabel)
    50	                    .foregroundStyle(.secondary)
    51	                Button(AppCopy.resumeButton) {
    52	                    Task { @MainActor in coordinator.send(.tapResume) }
    53	                }
    54	            } else if isStopping {
    55	                // The engine is finalizing the file: say so, instead of looking like it still records.
    56	                HStack(spacing: 8) {
    57	                    ProgressView()
    58	                    Text(AppCopy.savingLabel)
    59	                        .foregroundStyle(.secondary)
    60	                }
    61	            } else {
    62	                Text(AppCopy.recordingLabel)
    63	                    .foregroundStyle(.secondary)
    64	            }
    65	            if coordinator.lengthWarning {
    66	                Text(AppCopy.lengthWarning)
    67	                    .font(.footnote)
    68	                    .padding(8)
    69	                    .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    70	            }
    71	            Button(AppCopy.stopButton) {
    72	                Task { @MainActor in coordinator.send(.tapStop) }
    73	            }
    74	            .disabled(isStopping)
    75	        }
    76	        .padding()
    77	        .onAppear {
    78	            loadAnsweringText()
    79	        }
    80	    }
    81	
    82	    private func loadAnsweringText() {
    83	        guard let id = coordinator.state.answering else { return }
    84	        var descriptor = FetchDescriptor<Question>(predicate: #Predicate { $0.id == id })
    85	        descriptor.fetchLimit = 1
    86	        if let question = try? modelContext.fetch(descriptor).first {
    87	            answeringText = QuestionText.display(question)
    88	        }
    89	    }
    90	
    91	    private func elapsed(at now: Date) -> String {
    92	        let total = Int(now.timeIntervalSince(startedAt))
    93	        return String(format: "%02d:%02d", total / 60, total % 60)
    94	    }
    95	}

--- retold/Retold/Screens/SetAsideView.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// Questions the user set aside with Not this one, each with a Bring back action. Set aside is
     5	/// reversible: this page is the way back (house style rule 13).
     6	struct SetAsideView: View {
     7	    @Environment(\.modelContext) private var modelContext
     8	    @Query(sort: \Question.createdAt, order: .reverse) private var allQuestions: [Question]
     9	
    10	    @State private var failed = false
    11	
    12	    private var setAside: [Question] {
    13	        allQuestions.filter { $0.status == .retired && $0.templateID != "broad.open" }
    14	    }
    15	
    16	    var body: some View {
    17	        let items = setAside
    18	        Group {
    19	            if items.isEmpty {
    20	                EmptyPage(title: AppCopy.setAsideEmptyTitle, message: AppCopy.setAsideEmptyMessage)
    21	            } else {
    22	                List {
    23	                    ForEach(items) { question in
    24	                        VStack(alignment: .leading, spacing: 8) {
    25	                            Text(question.text)
    26	                            Button(AppCopy.bringBack) {
    27	                                bringBack(question)
    28	                            }
    29	                            .buttonStyle(.borderless)
    30	                        }
    31	                    }
    32	                }
    33	            }
    34	        }
    35	        .navigationTitle(AppCopy.setAsideTitle)
    36	        .alert(AppCopy.saveFailedTitle, isPresented: $failed) {
    37	            Button(AppCopy.okButton, role: .cancel) {}
    38	        } message: {
    39	            Text(AppCopy.saveFailedMessage)
    40	        }
    41	    }
    42	
    43	    private func bringBack(_ question: Question) {
    44	        guard question.bringBack() else { return }
    45	        do {
    46	            try modelContext.save()
    47	        } catch {
    48	            modelContext.rollback()
    49	            failed = true
    50	        }
    51	    }
    52	}

--- retold/Retold/Screens/SettingsView.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	
     4	enum SettingsKeys {
     5	    static let suggestionsOn = "retold.suggestionsOn"
     6	}
     7	
     8	struct SettingsView: View {
     9	    let files: CaptureFiles
    10	
    11	    @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
    12	    @Environment(\.modelContext) private var modelContext
    13	    @Environment(\.dismiss) private var dismiss
    14	
    15	    private enum ExportState {
    16	        case idle
    17	        case preparing
    18	        case ready(URL)
    19	        case failed
    20	    }
    21	
    22	    @State private var exportState = ExportState.idle
    23	
    24	    var body: some View {
    25	        NavigationStack {
    26	            Form {
    27	                Section {
    28	                    Toggle(AppCopy.suggestionsToggle, isOn: $suggestionsOn)
    29	                    Text(AppCopy.suggestionsFootnote)
    30	                        .font(.footnote)
    31	                        .foregroundStyle(.secondary)
    32	                }
    33	                Section {
    34	                    switch exportState {
    35	                    case .idle, .failed:
    36	                        Button(AppCopy.exportButton) {
    37	                            startExport()
    38	                        }
    39	                    case .preparing:
    40	                        HStack {
    41	                            ProgressView()
    42	                            Text(AppCopy.preparingExport)
    43	                        }
    44	                    case .ready(let url):
    45	                        ShareLink(item: url) {
    46	                            Text(AppCopy.shareExport)
    47	                        }
    48	                    }
    49	                    if case .failed = exportState {
    50	                        Text(AppCopy.exportFailed)
    51	                            .font(.footnote)
    52	                            .foregroundStyle(.secondary)
    53	                    }
    54	                    Text(AppCopy.exportNote)
    55	                        .font(.footnote)
    56	                        .foregroundStyle(.secondary)
    57	                }
    58	            }
    59	            .navigationTitle(AppCopy.settingsTitle)
    60	            .toolbar {
    61	                ToolbarItem(placement: .confirmationAction) {
    62	                    Button(AppCopy.doneButton) { dismiss() }
    63	                }
    64	            }
    65	        }
    66	    }
    67	
    68	    /// Builds the manifest on the main actor, then zips off it. Export is never gated.
    69	    private func startExport() {
    70	        exportState = .preparing
    71	        let manifest: ExportManifest
    72	        do {
    73	            let periods = try modelContext.fetch(FetchDescriptor<Period>())
    74	            let episodes = try modelContext.fetch(FetchDescriptor<Episode>())
    75	            let captures = try modelContext.fetch(FetchDescriptor<Capture>())
    76	            let questions = try modelContext.fetch(FetchDescriptor<Question>())
    77	            let library = ExportLibrary(
    78	                periods: periods, episodes: episodes, captures: captures, questions: questions)
    79	            manifest = ExportManifest.build(library, exportedAt: Date(), timeZone: .current)
    80	        } catch {
    81	            exportState = .failed
    82	            return
    83	        }
    84	        let audioDirectory = files.audioDirectory
    85	        let workDirectory = ExportArchiver.defaultWorkDirectory
    86	        let name = ExportArchiver.exportName(at: Date())
    87	        Task { @MainActor in
    88	            do {
    89	                let url = try await Task.detached {
    90	                    try ExportArchiver.makeArchive(
    91	                        manifest, audioDirectory: audioDirectory, workDirectory: workDirectory, name: name)
    92	                }.value
    93	                exportState = .ready(url)
    94	            } catch {
    95	                exportState = .failed
    96	            }
    97	        }
    98	    }
    99	}

--- retold/Retold/Screens/ThemesView.swift ---
     1	import SwiftData
     2	import SwiftUI
     3	
     4	/// The R5 theme cards (R7b section 7.5): one section per card, its open question rows beneath.
     5	/// A card with no open questions is left out, and when every card is empty the page says so with
     6	/// one action (house style rule 12) instead of showing a blank list.
     7	struct ThemesView: View {
     8	    @Query private var allQuestions: [Question]
     9	
    10	    private struct CardOffers: Identifiable {
    11	        let card: ThemeCard
    12	        let offers: [EngineOffer]
    13	        var id: String { card.id }
    14	    }
    15	
    16	    private var cardsWithOffers: [CardOffers] {
    17	        ThemeCards.all.compactMap { card in
    18	            let offers = QuestionEngine.queue(
    19	                for: card, state: ThemeState(card: card, questions: allQuestions))
    20	            return offers.isEmpty ? nil : CardOffers(card: card, offers: offers)
    21	        }
    22	    }
    23	
    24	    var body: some View {
    25	        let groups = cardsWithOffers
    26	        Group {
    27	            if groups.isEmpty {
    28	                EmptyPage(title: AppCopy.themesEmptyTitle, message: AppCopy.themesEmptyMessage)
    29	            } else {
    30	                List {
    31	                    ForEach(groups) { group in
    32	                        Section(group.card.title) {
    33	                            ForEach(Array(group.offers.enumerated()), id: \.offset) { _, offer in
    34	                                OfferRow(offer: offer, target: .theme)
    35	                            }
    36	                        }
    37	                    }
    38	                }
    39	            }
    40	        }
    41	        .navigationTitle(AppCopy.themesTitle)
    42	    }
    43	}

=== TARGET: Retold recorder state (state clarity evidence) ===
--- retold/Retold/Capture/RecorderMachine.swift ---
     1	import Foundation
     2	
     3	// The recorder reducer: state + event -> state + effects, with the reducer generating the IDs.
     4	// Pure Foundation. Deliberate divergences from StoryCue's SessionMachine: locking is not a pause
     5	// (UIBackgroundModes: audio keeps an active .record session alive), one capture is one audio file,
     6	// and resume is always a user action.
     7	
     8	enum MicrophonePermission: Equatable, Sendable { case undetermined, granted, denied }
     9	
    10	enum CaptureEndReason: String, Codable, Equatable, Sendable {
    11	    case userStop, mediaServicesReset, engineFailed, timeLimit
    12	}
    13	
    14	enum RecorderPhase: Equatable, Sendable {
    15	    case idle
    16	    case blocked                                  // a start was requested without .granted; see state.permission
    17	    case starting(captureID: UUID, stopRequested: Bool)
    18	    case recording(captureID: UUID)
    19	    case interrupted(captureID: UUID)             // file open, engine paused, waiting for tapResume
    20	    case stopping(captureID: UUID, reason: CaptureEndReason)
    21	    case aborting(captureID: UUID)                // failed during .starting; waiting for engineStopped
    22	}
    23	
    24	struct RecorderState: Equatable, Sendable {
    25	    var phase: RecorderPhase
    26	    var permission: MicrophonePermission
    27	    var protectedDataAvailable: Bool
    28	    var route: TranscriptionRoute
    29	    var answering: UUID?                          // the question the active capture answers
    30	    var runOffsets: [Int: TimeInterval]           // transcriber run number -> audio-file time it began at
    31	
    32	    init(permission: MicrophonePermission, protectedDataAvailable: Bool,
    33	         route: TranscriptionRoute = .audioOnly(.notChecked)) {
    34	        self.phase = .idle
    35	        self.permission = permission
    36	        self.protectedDataAvailable = protectedDataAvailable
    37	        self.route = route
    38	        self.answering = nil
    39	        self.runOffsets = [:]
    40	    }
    41	}
    42	
    43	enum RecorderEvent: Equatable, Sendable {
    44	    case startRequested(answering: UUID?)         // Control intent or in-app Record button
    45	    case permissionChanged(MicrophonePermission)
    46	    case routeChanged(TranscriptionRoute)         // only honoured in .idle / .blocked
    47	    case engineStarted(captureID: UUID)
    48	    case engineStartFailed(captureID: UUID)
    49	    case transcriberRunStarted(captureID: UUID, run: Int, audioOffset: TimeInterval)
    50	    case finalSegment(captureID: UUID, run: Int, segment: TranscriptSegment)   // run-relative times
    51	    case transcriberEnded(captureID: UUID, run: Int, completed: Bool)
    52	    case interruptionBegan, interruptionEnded(shouldResume: Bool)
    53	    case tapResume, tapStop
    54	    case timeLimitReached                         // the coordinator's 30-minute timer (spec SS7a)
    55	    case engineStopped(captureID: UUID, duration: TimeInterval)
    56	    case mediaServicesReset, engineFailed
    57	    case protectedDataWillBecomeUnavailable, protectedDataDidBecomeAvailable
    58	    case sceneDidEnterBackground, sceneWillResignActive, sceneDidBecomeActive
    59	}
    60	
    61	enum RecorderEffect: Equatable, Sendable {
    62	    case startEngine(captureID: UUID, route: TranscriptionRoute)
    63	    case pauseEngine(captureID: UUID)
    64	    case resumeEngine(captureID: UUID)
    65	    case stopEngine(captureID: UUID)
    66	    case openJournal(captureID: UUID)
    67	    case journal(JournalRecord)
    68	    case closeJournal(captureID: UUID)
    69	    case importJournals                            // only ever emitted while protectedDataAvailable
    70	}
    71	
    72	enum RecorderMachine {
    73	    /// `newID` is the reducer's only source of capture IDs (injected so tests are deterministic).
    74	    static func reduce(_ state: RecorderState, _ event: RecorderEvent, now: Date,
    75	                       newID: () -> UUID) -> (RecorderState, [RecorderEffect]) {
    76	        var s = state
    77	        switch event {
    78	        case .startRequested(let answering):
    79	            switch s.phase {
    80	            case .idle, .blocked:
    81	                // Without .granted the request is dropped; a later grant does not replay it.
    82	                guard s.permission == .granted else {
    83	                    s.phase = .blocked
    84	                    return (s, [])
    85	                }
    86	                let n = newID()
    87	                s.phase = .starting(captureID: n, stopRequested: false)
    88	                s.answering = answering
    89	                s.runOffsets = [:]
    90	                return (s, [.startEngine(captureID: n, route: s.route)])
    91	            case .starting(let id, _):
    92	                // SS7a: a second Action press stops the recording as soon as it starts.
    93	                s.phase = .starting(captureID: id, stopRequested: true)
    94	                return (s, [])
    95	            case .recording(let id), .interrupted(let id):
    96	                // SS7a: a second Action press behaves like tapStop.
    97	                s.phase = .stopping(captureID: id, reason: .userStop)
    98	                return (s, [.stopEngine(captureID: id)])
    99	            case .stopping, .aborting:
   100	                // Never a second capture.
   101	                return (state, [])
   102	            }
   103	
   104	        case .permissionChanged(let p):
   105	            s.permission = p
   106	            if case .blocked = s.phase, p == .granted {
   107	                s.phase = .idle
   108	            }
   109	            return (s, [])
   110	
   111	        case .routeChanged(let r):
   112	            switch s.phase {
   113	            case .idle, .blocked:
   114	                s.route = r
   115	                return (s, [])
   116	            default:
   117	                return (state, [])
   118	            }
   119	
   120	        case .engineStarted(let id):
   121	            switch s.phase {
   122	            case .starting(let pid, let stopRequested) where pid == id:
   123	                let begin = RecorderEffect.journal(.begin(
   124	                    id,
   125	                    audioFileName: CaptureFiles.audioFileName(for: id),
   126	                    createdAt: now,
   127	                    answering: s.answering,
   128	                    route: s.route
   129	                ))
   130	                if stopRequested {
   131	                    s.phase = .stopping(captureID: id, reason: .userStop)
   132	                    return (s, [.openJournal(captureID: id), begin, .stopEngine(captureID: id)])
   133	                }
   134	                s.phase = .recording(captureID: id)
   135	                return (s, [.openJournal(captureID: id), begin])
   136	            case .aborting(let pid) where pid == id:
   137	                return (state, [.stopEngine(captureID: id)])
   138	            default:
   139	                return (state, [])
   140	            }
   141	
   142	        case .engineStartFailed(let id):
   143	            if case .starting(let pid, _) = s.phase, pid == id {
   144	                s.phase = .idle
   145	                s.answering = nil
   146	                return (s, [])          // nothing was journaled
   147	            }
   148	            return (state, [])
   149	
   150	        case .tapStop:
   151	            switch s.phase {
   152	            case .starting(let id, _):
   153	                s.phase = .starting(captureID: id, stopRequested: true)
   154	                return (s, [])
   155	            case .recording(let id), .interrupted(let id):
   156	                s.phase = .stopping(captureID: id, reason: .userStop)
   157	                return (s, [.stopEngine(captureID: id)])
   158	            default:
   159	                return (state, [])
   160	            }
   161	
   162	        case .timeLimitReached:
   163	            switch s.phase {
   164	            case .recording(let id), .interrupted(let id):
   165	                s.phase = .stopping(captureID: id, reason: .timeLimit)
   166	                return (s, [.stopEngine(captureID: id)])
   167	            default:
   168	                return (state, [])
   169	            }
   170	
   171	        case .mediaServicesReset, .engineFailed:
   172	            let reason: CaptureEndReason = event == .mediaServicesReset ? .mediaServicesReset : .engineFailed
   173	            switch s.phase {
   174	            case .starting(let id, _):
   175	                s.phase = .aborting(captureID: id)
   176	                return (s, [.stopEngine(captureID: id)])
   177	            case .recording(let id), .interrupted(let id):
   178	                s.phase = .stopping(captureID: id, reason: reason)
   179	                return (s, [.stopEngine(captureID: id)])
   180	            default:
   181	                return (state, [])
   182	            }
   183	
   184	        case .transcriberRunStarted(let id, let run, let audioOffset):
   185	            switch s.phase {
   186	            case .recording(let pid) where pid == id,
   187	                 .interrupted(let pid) where pid == id,
   188	                 .stopping(let pid, _) where pid == id:
   189	                s.runOffsets[run] = audioOffset
   190	                return (s, [.journal(.runStarted(id, run: run, audioOffset: audioOffset))])
   191	            default:
   192	                return (state, [])
   193	            }
   194	
   195	        case .finalSegment(let id, let run, let segment):
   196	            switch s.phase {
   197	            case .recording(let pid) where pid == id,
   198	                 .interrupted(let pid) where pid == id,
   199	                 .stopping(let pid, _) where pid == id:
   200	                // SS2.3: shift run-relative times to audio-file time by run.
   201	                let shifted = TranscriptSegment(
   202	                    text: segment.text,
   203	                    start: segment.start + (s.runOffsets[run] ?? 0),
   204	                    end: segment.end + (s.runOffsets[run] ?? 0),
   205	                    isFinal: true
   206	                )
   207	                return (s, [.journal(.segment(id, run: run, segment: shifted))])
   208	            default:
   209	                return (state, [])
   210	            }
   211	
   212	        case .transcriberEnded(let id, let run, let completed):
   213	            switch s.phase {
   214	            case .recording(let pid) where pid == id,
   215	                 .interrupted(let pid) where pid == id,
   216	                 .stopping(let pid, _) where pid == id:
   217	                return (s, [.journal(.transcriberEnded(id, run: run, completed: completed))])
   218	            default:
   219	                return (state, [])
   220	            }
   221	
   222	        case .interruptionBegan:
   223	            if case .recording(let id) = s.phase {
   224	                s.phase = .interrupted(captureID: id)
   225	                return (s, [.pauseEngine(captureID: id), .journal(.paused(id, at: now))])
   226	            }
   227	            return (state, [])
   228	
   229	        case .interruptionEnded:
   230	            // Divergence 3: never auto-resume.
   231	            return (state, [])
   232	
   233	        case .tapResume:
   234	            if case .interrupted(let id) = s.phase {
   235	                s.phase = .recording(captureID: id)
   236	                return (s, [.resumeEngine(captureID: id), .journal(.resumed(id, at: now))])
   237	            }
   238	            return (state, [])
   239	
   240	        case .engineStopped(let id, let duration):
   241	            switch s.phase {
   242	            case .stopping(let pid, let reason) where pid == id:
   243	                return finishCapture(&s, id: id, duration: duration, reason: reason, now: now)
   244	            case .recording(let pid) where pid == id, .interrupted(let pid) where pid == id:
   245	                // An unrequested stop ends the capture as .engineFailed.
   246	                return finishCapture(&s, id: id, duration: duration, reason: .engineFailed, now: now)
   247	            case .aborting(let pid) where pid == id:
   248	                s.phase = .idle
   249	                s.answering = nil
   250	                s.runOffsets = [:]
   251	                return (s, [])
   252	            default:
   253	                return (state, [])
   254	            }
   255	
   256	        case .protectedDataWillBecomeUnavailable:
   257	            s.protectedDataAvailable = false
   258	            return (s, [])
   259	
   260	        case .protectedDataDidBecomeAvailable:
   261	            s.protectedDataAvailable = true
   262	            return (s, [.importJournals])
   263	
   264	        case .sceneDidEnterBackground, .sceneWillResignActive, .sceneDidBecomeActive:
   265	            // Divergence 1: scene events never change the phase.
   266	            return (state, [])
   267	        }
   268	    }
   269	
   270	    /// engineStopped is the last event of a capture: journal the end, close the journal,
   271	    /// then import - but only while protected data is available.
   272	    private static func finishCapture(_ s: inout RecorderState, id: UUID, duration: TimeInterval,
   273	                                      reason: CaptureEndReason, now: Date) -> (RecorderState, [RecorderEffect]) {
   274	        s.phase = .idle
   275	        s.answering = nil
   276	        s.runOffsets = [:]
   277	        var effects: [RecorderEffect] = [
   278	            .journal(.end(id, duration: duration, reason: reason, endedAt: now)),
   279	            .closeJournal(captureID: id),
   280	        ]
   281	        if s.protectedDataAvailable {
   282	            effects.append(.importJournals)
   283	        }
   284	        return (s, effects)
   285	    }
   286	}

=== VETERAN EXCERPTS ===

--- wilderness/src/services/nativeHaptics.ts ---
     1	/**
     2	 * Haptic feedback with a native-iOS path and a web fallback.
     3	 *
     4	 * `navigator.vibrate` is a no-op in iOS WKWebView (where the packaged app runs),
     5	 * so on Tauri/iOS we call a native plugin command backed by
     6	 * `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`. Everywhere
     7	 * else (web PWA, Android) we fall back to `navigator.vibrate`. Both paths are
     8	 * best-effort and never throw - haptics are an enhancement, not a dependency.
     9	 *
    10	 * Native side: see `docs/NATIVE_PLUGINS.md` (plugin name `native`, command `haptic`).
    11	 */
    12	import { invoke } from '@tauri-apps/api/core';
    13	
    14	export type HapticStyle = 'light' | 'medium' | 'heavy' | 'success' | 'warning' | 'error' | 'alarm';
    15	
    16	function isTauri(): boolean {
    17	  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
    18	}
    19	
    20	/** Web-vibration fallback pattern (ms) per semantic style. */
    21	const WEB_FALLBACK: Record<HapticStyle, number | number[]> = {
    22	  light: 20,
    23	  medium: 40,
    24	  heavy: 60,
    25	  success: [40, 60, 40],
    26	  warning: [60, 40, 60],
    27	  error: [80, 40, 80, 40, 80],
    28	  // Sustained check-in alarm - preserves the original Android buzz pattern.
    29	  alarm: [300, 200, 300, 200, 300, 200, 300, 200, 300],
    30	};
    31	
    32	/** Trigger a one-shot haptic. Resolves once dispatched; never rejects. */
    33	export async function haptic(style: HapticStyle = 'medium'): Promise<void> {
    34	  if (isTauri()) {
    35	    try {
    36	      await invoke('plugin:native|haptic', { style });
    37	      return;
    38	    } catch {
    39	      // Native unavailable (e.g. plugin not built) - fall through to web.
    40	    }
    41	  }
    42	  try {
    43	    navigator.vibrate?.(WEB_FALLBACK[style]);
    44	  } catch {
    45	    /* haptics are optional */
    46	  }
    47	}
    48	
    49	/** Cancel any ongoing web vibration pattern (no native equivalent needed). */
    50	export function stopHaptic(): void {
    51	  try {
    52	    navigator.vibrate?.(0);
    53	  } catch {
    54	    /* no-op */
    55	  }
    56	}

--- wilderness/src/components/breathing/BreathingExercise.tsx ---
     1	import React, { useEffect, useRef, useState, useCallback } from 'react';
     2	import { haptic } from '../../services/nativeHaptics';
     3	import { RotateCcw } from 'lucide-react';
     4	import type { BreathingPattern } from '../../calculators/PanicMode.calc';
     5	import { applyVoice } from '../../services/voice';
     6	import { Icon } from '../ui/Icon';
     7	
     8	interface BreathingExerciseProps {
     9	  pattern: BreathingPattern;
    10	  audioCues: boolean;
    11	  onComplete?: () => void;
    12	}
    13	
    14	/**
    15	 * Self-contained breathing driver. Walks a pattern's steps with variable
    16	 * per-step durations (so 4-7-8 works as well as 4-4-4-4), announces each
    17	 * phase via Web Speech API when audioCues is enabled, and lightly vibrates
    18	 * on every phase change (no-op in iOS WKWebView; still helpful on Android).
    19	 *
    20	 * Restart the exercise by remounting the component (use a React `key`).
    21	 */
    22	export function BreathingExercise({
    23	  pattern,
    24	  audioCues,
    25	  onComplete,
    26	}: BreathingExerciseProps) {
    27	  const [phaseIndex, setPhaseIndex] = useState(0);
    28	  const [cycleCount, setCycleCount] = useState(0);
    29	  const [completed, setCompleted] = useState(false);
    30	  const [resetNonce, setResetNonce] = useState(0);
    31	  const timeoutRef = useRef<number | null>(null);
    32	
    33	  const speechSupported =
    34	    typeof window !== 'undefined' && 'speechSynthesis' in window;
    35	
    36	  const currentStep = pattern.steps[phaseIndex] ?? pattern.steps[0];
    37	
    38	  const announce = useCallback(
    39	    (text: string) => {
    40	      if (!audioCues || !speechSupported) return;
    41	      try {
    42	        window.speechSynthesis.cancel();
    43	        const utterance = new SpeechSynthesisUtterance(text);
    44	        utterance.rate = 0.75;
    45	        utterance.pitch = 0.95;
    46	        applyVoice(utterance);
    47	        window.speechSynthesis.speak(utterance);
    48	      } catch {
    49	        /* speech errors are non-fatal */
    50	      }
    51	    },
    52	    [audioCues, speechSupported],
    53	  );
    54	
    55	  // Drive the phase progression.
    56	  useEffect(() => {
    57	    if (completed) return;
    58	
    59	    // Fire vibration + audio cue for the current phase.
    60	    void haptic('medium');
    61	    announce(currentStep.label);
    62	
    63	    timeoutRef.current = window.setTimeout(() => {
    64	      const nextIndex = phaseIndex + 1;
    65	      if (nextIndex >= pattern.steps.length) {
    66	        const nextCycle = cycleCount + 1;
    67	        if (nextCycle >= pattern.totalCycles) {
    68	          setCompleted(true);
    69	          onComplete?.();
    70	          return;
    71	        }
    72	        setCycleCount(nextCycle);
    73	        setPhaseIndex(0);
    74	      } else {
    75	        setPhaseIndex(nextIndex);
    76	      }
    77	    }, currentStep.durationMs);
    78	
    79	    return () => {
    80	      if (timeoutRef.current !== null) {
    81	        window.clearTimeout(timeoutRef.current);
    82	        timeoutRef.current = null;
    83	      }
    84	    };
    85	    // `resetNonce` intentionally included so a manual reset re-triggers the effect.
    86	  }, [phaseIndex, cycleCount, completed, currentStep, pattern, onComplete, announce, resetNonce]);
    87	
    88	  // Cancel any speech when the component unmounts.
    89	  useEffect(() => {
    90	    return () => {
    91	      if (speechSupported) {
    92	        try {
    93	          window.speechSynthesis.cancel();
    94	        } catch {
    95	          /* ignore */
    96	        }
    97	      }
    98	    };
    99	  }, [speechSupported]);
   100	
   101	  const handleReset = () => {
   102	    if (timeoutRef.current !== null) {
   103	      window.clearTimeout(timeoutRef.current);
   104	      timeoutRef.current = null;
   105	    }
   106	    if (speechSupported) {
   107	      try {
   108	        window.speechSynthesis.cancel();
   109	      } catch {
   110	        /* ignore */
   111	      }
   112	    }
   113	    setPhaseIndex(0);
   114	    setCycleCount(0);
   115	    setCompleted(false);
   116	    setResetNonce((n) => n + 1);
   117	  };
   118	
   119	  const transitionSeconds = (currentStep.durationMs / 1000).toFixed(2);
   120	
   121	  return (
   122	    <div
   123	      className="flex flex-col items-center gap-6 py-4"
   124	      data-testid="breathing-exercise"
   125	      data-pattern-id={pattern.id}
   126	    >
   127	      {completed ? (
   128	        <div className="flex flex-col items-center gap-3 py-8 text-center">
   129	          <p className="text-brand-text-primary text-3xl font-semibold">
   130	            You&apos;re ready.
   131	          </p>
   132	          <p className="text-brand-text-secondary text-lg">
   133	            Think clearly. Make a plan.
   134	          </p>
   135	          <button
   136	            type="button"
   137	            onClick={handleReset}
   138	            className="mt-4 flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-accent text-brand-on-accent font-bold text-base uppercase tracking-wide touch-target-critical active:scale-95 transition-transform"
   139	          >
   140	            <Icon icon={RotateCcw} size="md" /> Start Over
   141	          </button>
   142	        </div>
   143	      ) : (
   144	        <>
   145	          <div
   146	            aria-hidden="true"
   147	            data-testid="breathing-circle"
   148	            style={{
   149	              transform: `scale(${currentStep.scale})`,
   150	              transition: `transform ${transitionSeconds}s ease-in-out`,
   151	            }}
   152	            className="w-52 h-52 rounded-full border-4 border-brand-accent bg-brand-accent/20"
   153	          />
   154	
   155	          <p
   156	            aria-live="polite"
   157	            aria-atomic="true"
   158	            data-testid="breathing-label"
   159	            className="text-brand-text-primary text-center text-3xl font-semibold"
   160	          >
   161	            {currentStep.label}
   162	          </p>
   163	
   164	          <p className="text-brand-text-secondary text-center text-base">
   165	            Breath {cycleCount + 1} of {pattern.totalCycles}
   166	          </p>
   167	
   168	          <button
   169	            type="button"
   170	            onClick={handleReset}
   171	            aria-label="Restart breathing exercise"
   172	            className="flex items-center gap-2 px-4 py-2 rounded-xl text-brand-text-secondary hover:bg-brand-accent/10 active:scale-95 transition-transform touch-target-critical"
   173	          >
   174	            <Icon icon={RotateCcw} size="sm" /> <span className="text-sm font-semibold uppercase tracking-wide">Reset</span>
   175	          </button>
   176	        </>
   177	      )}
   178	    </div>
   179	  );
   180	}
   181	
   182	export default BreathingExercise;

--- wilderness/src/components/emergency/PanicOverlay.tsx ---
     1	import React, { useState, useEffect, useCallback } from 'react';
     2	import { haptic } from '../../services/nativeHaptics';
     3	import { X } from 'lucide-react';
     4	import { Icon } from '../ui/Icon';
     5	
     6	interface PanicOverlayProps {
     7	  isOpen: boolean;
     8	  onClose: () => void;
     9	}
    10	
    11	type BreathPhase = 'inhale' | 'hold-in' | 'exhale' | 'hold-out';
    12	
    13	const PHASES: { phase: BreathPhase; label: string; scale: number }[] = [
    14	  { phase: 'inhale', label: 'Breathe In', scale: 1.0 },
    15	  { phase: 'hold-in', label: 'Hold', scale: 1.0 },
    16	  { phase: 'exhale', label: 'Breathe Out', scale: 0.4 },
    17	  { phase: 'hold-out', label: 'Hold', scale: 0.4 },
    18	];
    19	
    20	const PHASE_DURATION_MS = 4000;
    21	const PHASE_DURATION_S = PHASE_DURATION_MS / 1000;
    22	const TOTAL_CYCLES = 10;
    23	
    24	export function PanicOverlay({ isOpen, onClose }: PanicOverlayProps) {
    25	  const [phaseIndex, setPhaseIndex] = useState(0);
    26	  const [cycleCount, setCycleCount] = useState(0);
    27	  const [completed, setCompleted] = useState(false);
    28	
    29	  const advancePhase = useCallback(() => {
    30	    setPhaseIndex((prev) => {
    31	      const next = (prev + 1) % PHASES.length;
    32	      if (next === 0) {
    33	        setCycleCount((c) => {
    34	          const newCount = c + 1;
    35	          if (newCount >= TOTAL_CYCLES) {
    36	            setCompleted(true);
    37	          }
    38	          return newCount;
    39	        });
    40	      }
    41	      return next;
    42	    });
    43	    void haptic('medium');
    44	  }, []);
    45	
    46	  useEffect(() => {
    47	    if (!isOpen || completed) return;
    48	
    49	    const id = setInterval(advancePhase, PHASE_DURATION_MS);
    50	    return () => clearInterval(id);
    51	  }, [isOpen, completed, advancePhase]);
    52	
    53	  useEffect(() => {
    54	    if (!isOpen) {
    55	      setPhaseIndex(0);
    56	      setCycleCount(0);
    57	      setCompleted(false);
    58	    }
    59	  }, [isOpen]);
    60	
    61	  if (!isOpen) return null;
    62	
    63	  const currentPhase = PHASES[phaseIndex];
    64	  const circleScale = currentPhase.scale;
    65	
    66	  return (
    67	    <div
    68	      role="dialog"
    69	      aria-modal="true"
    70	      aria-label="Tactical breathing exercise"
    71	      className="fixed inset-0 z-[110] flex flex-col items-center justify-between bg-brand-bg px-6 py-8"
    72	    >
    73	      {/* Close button */}
    74	      <div className="flex w-full justify-end">
    75	        <button
    76	          onClick={onClose}
    77	          aria-label="Close breathing exercise"
    78	          className="w-14 h-14 rounded-full bg-brand-surface border-2 border-brand-text-secondary/20 text-brand-text-primary flex items-center justify-center"
    79	        >
    80	          <Icon icon={X} size="lg" />
    81	        </button>
    82	      </div>
    83	
    84	      {/* Main content */}
    85	      <div className="flex flex-col items-center gap-6 flex-1 justify-center">
    86	        {/* STOP prompt */}
    87	        <p className="text-brand-text-primary text-center text-xl font-bold tracking-wide">
    88	          STOP. Sit down. Think. Observe. Plan.
    89	        </p>
    90	        <p className="text-brand-text-secondary text-center text-sm">
    91	          Tactical breathing - used by military and search &amp; rescue teams
    92	        </p>
    93	
    94	        {completed ? (
    95	          /* Completion state */
    96	          <div className="flex flex-col items-center gap-4 mt-4">
    97	            <p className="text-brand-text-primary text-center text-2xl font-semibold">
    98	              You're ready.
    99	            </p>
   100	            <p className="text-brand-text-secondary text-center text-lg">
   101	              Think clearly. Make a plan.
   102	            </p>
   103	          </div>
   104	        ) : (
   105	          /* Breathing circle + phase label */
   106	          <div className="flex flex-col items-center gap-8 mt-4">
   107	            {/* Circle */}
   108	            <div
   109	              aria-hidden="true"
   110	              style={{
   111	                transform: `scale(${circleScale})`,
   112	                transition: `transform ${PHASE_DURATION_S}s ease-in-out`,
   113	              }}
   114	              className="w-52 h-52 rounded-full border-4 border-brand-accent bg-brand-accent/20"
   115	            />
   116	
   117	            {/* Phase label */}
   118	            <p
   119	              aria-live="assertive"
   120	              aria-atomic="true"
   121	              className="text-brand-text-primary text-center text-3xl font-semibold"
   122	            >
   123	              {currentPhase.label}
   124	            </p>
   125	
   126	            {/* Cycle counter */}
   127	            <p className="text-brand-text-secondary text-center text-base">
   128	              Breath {cycleCount + 1} of {TOTAL_CYCLES}
   129	            </p>
   130	          </div>
   131	        )}
   132	      </div>
   133	
   134	      {/* 911 reminder + citation */}
   135	      <div className="text-center mt-4 space-y-1">
   136	        <p className="text-brand-text-secondary text-xs font-semibold">
   137	          If in immediate danger, call 911 or your local emergency number.
   138	        </p>
   139	        <p className="text-brand-footer text-xs">
   140	          STOP Protocol (US Forest Service) o FM 21-76
   141	        </p>
   142	      </div>
   143	    </div>
   144	  );
   145	}
   146	
   147	export default PanicOverlay;

--- BoardBound/boardbound/app/quiz/question.tsx ---
     1	import { useEffect, useMemo, useState } from "react";
     2	import { View, Text, Pressable, ScrollView, Alert } from "react-native";
     3	import { useRouter } from "expo-router";
     4	import { Ionicons } from "@expo/vector-icons";
     5	import Animated, { FadeInDown } from "react-native-reanimated";
     6	import * as Haptics from "expo-haptics";
     7	import { useReduceMotion } from "../../lib/hooks/useReduceMotion";
     8	import { useQuizStore } from "../../lib/stores/useQuizStore";
     9	import { useSubscriptionStore } from "../../lib/stores/useSubscriptionStore";
    10	import { useGameModeStore } from "../../lib/stores/useGameModeStore";
    11	import {
    12	  getTodayAnsweredCount,
    13	  getQuestionAttemptStats,
    14	  wasTutorUsedForQuestion,
    15	} from "../../lib/db/progress";
    16	import { FREE_DAILY_QUESTIONS, DOMAIN_LABELS } from "../../lib/utils/constants";
    17	import { canAccessQuestions } from "../../lib/utils/subscription-helpers";
    18	import { earnFromAnswer } from "../../lib/utils/earn-from-answer";
    19	import type { EarnSpec } from "../../lib/utils/coin-rules";
    20	import { QuestionCard } from "../../components/question/QuestionCard";
    21	import { OptionButton } from "../../components/question/OptionButton";
    22	import { FeedbackPanel } from "../../components/question/FeedbackPanel";
    23	import { QuestionSkeleton } from "../../components/question/QuestionSkeleton";
    24	import { QuizErrorBoundary } from "../../components/QuizErrorBoundary";
    25	import { EarnToast } from "../../components/game/EarnToast";
    26	
    27	export default function QuestionScreenWithBoundary() {
    28	  return (
    29	    <QuizErrorBoundary>
    30	      <QuestionScreen />
    31	    </QuizErrorBoundary>
    32	  );
    33	}
    34	
    35	const MODE_LABELS: Record<string, string> = {
    36	  adaptive: "Smart Practice",
    37	  srs_review: "Spaced Review",
    38	  domain_focus: "Domain Focus",
    39	  random: "",
    40	};
    41	
    42	function QuestionScreen() {
    43	  const router = useRouter();
    44	  const reduceMotion = useReduceMotion();
    45	  const {
    46	    status,
    47	    currentQuestion,
    48	    selectedOptionId,
    49	    isAnswered,
    50	    isCorrect,
    51	    questionsAnswered,
    52	    correctCount,
    53	    studyStrategy,
    54	    startTime,
    55	    markedForReview,
    56	    loadQuestion,
    57	    selectOption,
    58	    submitAnswer,
    59	    nextQuestion,
    60	    toggleMarkForReview,
    61	  } = useQuizStore();
    62	  const tier = useSubscriptionStore((s) => s.tier);
    63	  const gameModePreference = useGameModeStore((s) => s.preference);
    64	  const earnCoins = useGameModeStore((s) => s.earn);
    65	  const [upsellDismissed, setUpsellDismissed] = useState(false);
    66	  const [elapsedSeconds, setElapsedSeconds] = useState(0);
    67	  const [latestEarn, setLatestEarn] = useState<EarnSpec | null>(null);
    68	  const [priorAttempts, setPriorAttempts] = useState<{
    69	    attemptCount: number;
    70	    accuracy: number;
    71	  } | null>(null);
    72	  const todayTotal = useMemo(() => getTodayAnsweredCount(), [isAnswered]);
    73	
    74	  // Capture prior-attempt stats when a new question loads. Done BEFORE the
    75	  // user submits so the chip reflects history (Barkley parity: "Seen 3x, 33%
    76	  // correct"), not the current attempt-in-progress.
    77	  useEffect(() => {
    78	    if (!currentQuestion?.id) {
    79	      setPriorAttempts(null);
    80	      return;
    81	    }
    82	    if (isAnswered) return; // freeze chip during answer feedback
    83	    try {
    84	      const stats = getQuestionAttemptStats(currentQuestion.id);
    85	      setPriorAttempts({
    86	        attemptCount: stats.attemptCount,
    87	        accuracy: stats.accuracy,
    88	      });
    89	    } catch (e) {
    90	      console.error("Failed to load attempt stats:", e);
    91	      setPriorAttempts(null);
    92	    }
    93	  }, [currentQuestion?.id, isAnswered]);
    94	
    95	  // Per-question timer. Freeze the displayed value once the question has
    96	  // been answered so feedback time isn't counted against the user.
    97	  useEffect(() => {
    98	    if (!startTime) {
    99	      setElapsedSeconds(0);
   100	      return;
   101	    }
   102	    if (isAnswered) {
   103	      return;
   104	    }
   105	    setElapsedSeconds(0);
   106	    let elapsed = 0;
   107	    const interval = setInterval(() => {
   108	      elapsed += 1;
   109	      setElapsedSeconds(elapsed);
   110	    }, 1000);
   111	    return () => clearInterval(interval);
   112	  }, [startTime, currentQuestion?.id, isAnswered]);
   113	  const showUpsell = tier === "free" && isAnswered && todayTotal >= 5 && todayTotal <= 10 && !upsellDismissed;
   114	
   115	  useEffect(() => {
   116	    loadQuestion();
   117	  }, [loadQuestion]);
   118	
   119	  // Deep-link cover: if the user lands here over the daily limit and the
   120	  // current question has not been answered yet, redirect to the paywall.
   121	  useEffect(() => {
   122	    if (
   123	      currentQuestion &&
   124	      !isAnswered &&
   125	      !canAccessQuestions(tier, getTodayAnsweredCount())
   126	    ) {
   127	      router.replace("/paywall");
   128	    }
   129	  }, [currentQuestion, isAnswered, tier, router]);
   130	
   131	  // Haptic feedback when answer is revealed
   132	  useEffect(() => {
   133	    if (isAnswered && isCorrect !== null) {
   134	      Haptics.notificationAsync(
   135	        isCorrect
   136	          ? Haptics.NotificationFeedbackType.Success
   137	          : Haptics.NotificationFeedbackType.Error
   138	      );
   139	    }
   140	  }, [isAnswered, isCorrect]);
   141	
   142	  // Game Mode: award coins for correct answers (off-mode short-circuits).
   143	  // attemptNumber + usedTutor must reflect the user's real history so the
   144	  // earn rules can classify first_try (+10) vs after_wrong (+3) vs
   145	  // after_tutor (+3). At this point in the lifecycle the new answer has
   146	  // already been inserted into user_answers by submitAnswer, so the
   147	  // attemptCount it returns IS the running attempt number (not prior).
   148	  useEffect(() => {
   149	    if (!isAnswered || isCorrect !== true || !currentQuestion) return;
   150	    if (gameModePreference === "off") return;
   151	    const { attemptCount } = getQuestionAttemptStats(currentQuestion.id);
   152	    const earn = earnFromAnswer({
   153	      questionId: currentQuestion.id,
   154	      isCorrect: true,
   155	      attemptNumber: Math.max(1, attemptCount),
   156	      usedTutor: wasTutorUsedForQuestion(currentQuestion.id),
   157	    });
   158	    if (!earn) return;
   159	    earnCoins(earn.amount, earn.source, currentQuestion.id);
   160	    setLatestEarn(earn);
   161	  }, [isAnswered, isCorrect, currentQuestion, gameModePreference, earnCoins]);
   162	
   163	  if (status === "no_questions") {
   164	    const isSrsMode = studyStrategy === "srs_review";
   165	    return (
   166	      <View className="flex-1 items-center justify-center bg-white dark:bg-gray-900 px-6">
   167	        <Ionicons
   168	          name={isSrsMode ? "checkmark-circle-outline" : "alert-circle-outline"}
   169	          size={48}
   170	          color={isSrsMode ? "#16a34a" : "#f59e0b"}
   171	        />
   172	        <Text className="mt-4 text-center text-lg font-medium text-gray-700 dark:text-gray-300">
   173	          {isSrsMode ? "All caught up" : "No questions available"}
   174	        </Text>
   175	        <Text className="mt-2 text-center text-sm text-gray-500 dark:text-gray-400">
   176	          {isSrsMode
   177	            ? "No cards are due for review right now. Keep practicing to build your review queue."
   178	            : "Questions may not have loaded yet. Try restarting the app."}
   179	        </Text>
   180	        <Pressable
   181	          accessibilityRole="button"
   182	          className="mt-6 rounded-xl bg-brand-600 px-8 py-3 active:bg-brand-700"
   183	          onPress={() => router.back()}
   184	        >
   185	          <Text className="font-bold text-white">Back to Study</Text>
   186	        </Pressable>
   187	      </View>
   188	    );
   189	  }
   190	
   191	  if (!currentQuestion) {
   192	    return <QuestionSkeleton />;
   193	  }
   194	
   195	  const handleEndSession = () => {
   196	    if (questionsAnswered === 0) {
   197	      router.back();
   198	      return;
   199	    }
   200	    Alert.alert(
   201	      "End Session?",
   202	      `You've answered ${questionsAnswered} question${questionsAnswered === 1 ? "" : "s"}. End now and see your results?`,
   203	      [
   204	        { text: "Keep Going", style: "cancel" },
   205	        {
   206	          text: "End Session",
   207	          onPress: () => router.replace("/quiz/results"),
   208	        },
   209	      ]
   210	    );
   211	  };
   212	
   213	  const questionNumber = questionsAnswered + (isAnswered ? 0 : 1);
   214	  const accuracy =
   215	    questionsAnswered > 0
   216	      ? Math.round((correctCount / questionsAnswered) * 100)
   217	      : 0;
   218	
   219	  const sessionTarget =
   220	    studyStrategy === "domain_focus" ? 20 : 12;
   221	
   222	  const timerColorClass =
   223	    elapsedSeconds > 120
   224	      ? "text-red-500"
   225	      : elapsedSeconds >= 90
   226	        ? "text-amber-500"
   227	        : "text-gray-500 dark:text-gray-400";
   228	
   229	  return (
   230	    <View className="flex-1">
   231	    <ScrollView className="flex-1 bg-white dark:bg-gray-900" contentContainerClassName="p-5 pb-12">
   232	      <View className="mb-4 flex-row items-center justify-between">
   233	        <View className="flex-row items-center gap-2">
   234	          <Text className="text-sm text-gray-600 dark:text-gray-400">
   235	            {questionNumber} / {sessionTarget} . {currentQuestion ? DOMAIN_LABELS[currentQuestion.domain] : ""}
   236	          </Text>
   237	        </View>
   238	        <View className="flex-row items-center gap-3">
   239	          {markedForReview.size > 0 && (
   240	            <View className="flex-row items-center gap-1" testID="marked-count-indicator">
   241	              <Ionicons name="bookmark" size={14} color="#1f5c54" />
   242	              <Text className="text-sm font-medium text-brand-600 dark:text-brand-400">
   243	                {markedForReview.size}
   244	              </Text>
   245	            </View>
   246	          )}
   247	          <Text className={`text-sm font-mono ${timerColorClass}`} testID="question-timer">
   248	            {Math.floor(elapsedSeconds / 60)}:{String(elapsedSeconds % 60).padStart(2, "0")}
   249	          </Text>
   250	          {questionsAnswered > 0 && (

--- burn-wizard/app/src/styles/design-system.css ---
     1	@tailwind base;
     2	@tailwind components;
     3	@tailwind utilities;
     4	
     5	@layer base {
     6	  :root {
     7	    /* === MEDICAL WIZARDS UNIFIED DESIGN SYSTEM === */
     8	    /* Professional Medical Design System - Teal-Blue Harmony Theme */
     9	    
    10	    /* Base Colors - Clinical White with Medical Hints */
    11	    --background: 180 20% 98%; /* Clinical white with subtle teal hint */
    12	    --foreground: 192 95% 9%; /* Deep medical teal for text */
    13	    --card: 0 0% 100%; /* Pure white cards for medical clarity */
    14	    --card-foreground: 192 95% 9%;
    15	    --popover: 0 0% 100%;
    16	    --popover-foreground: 192 95% 9%;
    17	    
    18	    /* Primary Medical Palette - Professional Teal-Blue */
    19	    /* WCAG 2.1 AA: 38% measured 2.860:1 on white - it failed even the 3.0:1 large-text
    20	       allowance, so the brand teal was non-compliant at any size (F-01). 27% clears 4.5:1
    21	       against all four light surfaces: card 5.265, background 5.070, secondary 4.776,
    22	       muted 4.660. 28% was considered and rejected - it misses on secondary (4.476) and
    23	       muted (4.367). --ring and --region-stroke below are SEPARATE tokens that happen to
    24	       share this value; they are changed deliberately, not as a consequence of this line. */
    25	    --primary: 174 76% 27%; /* Professional medical teal */
    26	    --primary-light: 174 65% 55%; /* Lighter teal for hover states */
    27	    --primary-dark: 174 85% 28%; /* Darker teal for emphasis */
    28	    --primary-foreground: 0 0% 100%;
    29	    
    30	    /* Secondary Medical Blue (for ECG/Cardio contexts) */
    31	    --secondary-blue: 220 90% 48%; /* Professional medical blue */
    32	    --secondary-blue-light: 220 85% 65%; /* Lighter blue for hover */
    33	    --secondary-blue-dark: 220 95% 35%; /* Darker blue for emphasis */
    34	    
    35	    /* Supporting Colors */
    36	    --secondary: 180 25% 95%; /* Very light teal background */
    37	    --secondary-foreground: 192 95% 9%;
    38	    --muted: 180 15% 94%; /* Subtle neutral background */
    39	    --muted-foreground: 192 30% 35%; /* Darker for WCAG AA contrast (4.5:1+) */
    40	    --accent: 174 45% 85%; /* Soft teal accent */
    41	    --accent-foreground: 192 95% 9%;
    42	    
    43	    /* Medical Status Colors - Clinical Context */
    44	    --success: 142 69% 45%; /* Medical green for positive states */
    45	    --success-light: 142 60% 60%; /* Lighter success */
    46	    --success-dark: 142 75% 35%; /* Darker success */
    47	    --success-foreground: 0 0% 100%;
    48	    
    49	    --warning: 43 89% 58%; /* Amber for caution */
    50	    --warning-light: 43 85% 70%; /* Lighter warning */
    51	    --warning-dark: 43 95% 45%; /* Darker warning */
    52	    --warning-foreground: 43 15% 15%;
    53	    
    54	    --destructive: 0 72% 51%; /* Medical red for critical alerts */
    55	    --destructive-light: 0 65% 65%; /* Lighter destructive */
    56	    --destructive-dark: 0 80% 40%; /* Darker destructive */
    57	    --destructive-foreground: 0 0% 100%;
    58	    
    59	    --info: 207 90% 54%; /* Medical blue for information */
    60	    --info-light: 207 85% 70%; /* Lighter info */
    61	    --info-dark: 207 95% 42%; /* Darker info */
    62	    --info-foreground: 0 0% 100%;
    63	    
    64	    /* Interface Elements */
    65	    --border: 180 25% 87%; /* Refined border color */
    66	    --input: 180 20% 96%; /* Input background */
    67	    /* F-02: independent token, not derived from --primary. 38% gave 2.860:1 against the
    68	       page, below the 3:1 non-text requirement for focus indicators. */
    69	    --ring: 174 76% 27%; /* Focus ring matches primary */
    70	    --radius: 0.75rem; /* Consistent border radius */
    71	    
    72	    /* Medical Severity Palette - Enhanced for Burn Assessment */
    73	    --burn-none: 0 0% 98%; /* No burn - near white */
    74	    --burn-superficial: 0 45% 88%; /* Light pink for superficial */
    75	    --burn-superficial-partial: 25 65% 80%; /* Warm peach */
    76	    --burn-deep-partial: 35 75% 70%; /* Golden amber */
    77	    --burn-full-thickness: 195 15% 75%; /* Cool gray */
    78	    
    79	    /* ECG/Cardiac Specific Colors */
    80	    --ecg-normal: 142 69% 45%; /* Normal rhythm - green */
    81	    --ecg-abnormal: 43 89% 58%; /* Abnormal rhythm - amber */
    82	    --ecg-critical: 0 72% 51%; /* Critical rhythm - red */
    83	    --ecg-trace: 220 90% 48%; /* ECG trace blue */
    84	    
    85	    /* Clinical Risk Levels */
    86	    --risk-low: 142 69% 45%; /* Low risk - green */
    87	    --risk-moderate: 43 89% 58%; /* Moderate risk - amber */
    88	    --risk-high: 25 85% 60%; /* High risk - orange */
    89	    --risk-critical: 0 72% 51%; /* Critical risk - red */
    90	
    91	    /* Body Map Region Colors - Burn Intensity */
    92	    --region-none: 215 20% 96%; /* Slate-100 - unselected region */
    93	    --region-25: 48 96% 89%; /* Amber-100 - 25% burn */
    94	    --region-50: 33 95% 80%; /* Orange-200 - 50% burn */
    95	    --region-75: 0 94% 82%; /* Red-300 - 75% burn */
    96	    --region-100: 0 84% 60%; /* Red-500 - 100% burn */
    97	    /* F-01b: the body-map SELECTED-REGION indicator - a clinical surface. Independent
    98	       token. 38% gave 2.860:1 against a 3:1 non-text requirement.
    99	       The teal alone CANNOT satisfy SC 1.4.11 against these fills at any lightness that
   100	       still reads as teal: against --region-100 (red-500) it is 1.39, and --region-75 is
   101	       2.79. Compliance is carried by --region-stroke-halo, drawn under it, which clears
   102	       3:1 against every one of the five BASE FILLS on its own (min 4.73, vs --region-100).
   103	       The teal is the brand layer on top; the halo is the accessible one. Measure the HALO
   104	       when checking this, not the pair.
   105	       SCOPE, stated precisely because an earlier version of this comment overclaimed: the
   106	       5-fill guarantee does NOT yet cover (a) the fraction/depth PATTERN overlays, which
   107	       paint after the interactive path and composite to ~2.71 light / ~2.38 dark against
   108	       the halo, or (b) shared boundaries where a later-painted neighbouring region can
   109	       overwrite an earlier region's halo. F-01b is therefore still OPEN. */
   110	    --region-stroke: 174 76% 27%; /* Primary teal - selected stroke */
   111	    --region-stroke-halo: 222 47% 11%; /* Slate-900 - outer halo, carries the 3:1 */
   112	    --region-stroke-default: 215 20% 80%; /* Slate-300 - default stroke */
   113	
   114	    /* SVG pattern stroke/fill colors for colorblind-accessibility overlays */
   115	    /* Light mode: dark tones readable on light body-map backgrounds */
   116	    --burn-pattern-25: 22 78% 31%;   /* Amber-900 */
   117	    --burn-pattern-50: 18 88% 40%;   /* Orange-700 */
   118	    --burn-pattern-75: 0 70% 35%;    /* Red-900 */
   119	    --burn-pattern-100: 0 63% 31%;   /* Red-950 */
   120	    --burn-depth-pattern: 0 0% 0%;   /* Black (with alpha applied via var syntax) */
   121	    
   122	    /* Gradient Definitions for Medical UI */
   123	    /* Start stops tracked --primary's old 38%; kept in step for palette consistency.
   124	       Decorative - no WCAG requirement attaches to either gradient. */
   125	    --gradient-primary: linear-gradient(135deg, hsl(174 76% 27%) 0%, hsl(174 65% 55%) 100%);
   126	    --gradient-card: linear-gradient(145deg, hsl(0 0% 100%) 0%, hsl(180 20% 98%) 100%);
   127	    --gradient-accent: linear-gradient(120deg, hsl(174 45% 85%) 0%, hsl(180 25% 95%) 100%);
   128	    --gradient-medical: linear-gradient(135deg, hsl(174 76% 27%) 0%, hsl(220 90% 48%) 100%);
   129	  }
   130	
   131	  .dark {
   132	    /* === DARK MODE - PROFESSIONAL MEDICAL THEME === */
   133	    
   134	    /* Dark Base Colors */
   135	    --background: 192 45% 8%; /* Deep medical teal background */
   136	    --foreground: 180 15% 94%; /* Light text for contrast */
   137	    --card: 192 35% 12%; /* Dark card background */
   138	    --card-foreground: 180 15% 94%;
   139	    --popover: 192 35% 12%;
   140	    --popover-foreground: 180 15% 94%;
   141	    
   142	    /* Dark Mode Primary Palette */
   143	    --primary: 174 65% 55%; /* Bright teal for dark backgrounds */
   144	    --primary-light: 174 55% 70%; /* Even lighter for hover */
   145	    --primary-dark: 174 75% 45%; /* Darker variant */
   146	    --primary-foreground: 192 45% 8%; /* Dark text on teal */
   147	    
   148	    /* Dark Mode Secondary Blue */
   149	    --secondary-blue: 220 85% 65%; /* Brighter blue for dark mode */
   150	    --secondary-blue-light: 220 80% 80%; /* Lighter blue hover */
   151	    --secondary-blue-dark: 220 90% 50%; /* Darker blue emphasis */
   152	    
   153	    /* Dark Mode Supporting Colors */
   154	    --secondary: 192 25% 20%; /* Dark secondary background */
   155	    --secondary-foreground: 180 15% 94%;
   156	    --muted: 192 20% 18%; /* Dark muted background */
   157	    --muted-foreground: 180 10% 65%; /* Muted text */
   158	    --accent: 174 35% 25%; /* Dark accent */
   159	    --accent-foreground: 180 15% 94%;
   160	    
   161	    /* Dark Mode Status Colors */
   162	    --success: 142 60% 50%; /* Brighter green for dark mode */
   163	    --success-light: 142 55% 65%; /* Lighter success */
   164	    --success-dark: 142 70% 40%; /* Darker success */
   165	    --success-foreground: 142 30% 10%;
   166	    
   167	    --warning: 43 85% 65%; /* Brighter amber */
   168	    --warning-light: 43 80% 75%; /* Lighter warning */
   169	    --warning-dark: 43 90% 55%; /* Darker warning */
   170	    --warning-foreground: 43 20% 15%;
   171	    
   172	    --destructive: 0 65% 55%; /* Brighter red */
   173	    --destructive-light: 0 60% 70%; /* Lighter destructive */
   174	    --destructive-dark: 0 75% 45%; /* Darker destructive */
   175	    --destructive-foreground: 0 0% 100%;
   176	    
   177	    --info: 207 85% 65%; /* Brighter info blue */
   178	    --info-light: 207 80% 80%; /* Lighter info */
   179	    --info-dark: 207 90% 50%; /* Darker info */
   180	    --info-foreground: 0 0% 100%;
   181	    
   182	    /* Dark Mode Interface */
   183	    --border: 192 25% 25%; /* Visible borders in dark mode */
   184	    --input: 192 25% 20%; /* Input backgrounds */
   185	    --ring: 174 65% 55%; /* Focus ring */
   186	    
   187	    /* Dark Mode Burn Colors */
   188	    --burn-none: 192 45% 8%; /* Same as background */
   189	    --burn-superficial: 0 35% 30%; /* Dark pink */
   190	    --burn-superficial-partial: 25 45% 35%; /* Dark peach */
   191	    --burn-deep-partial: 35 55% 35%; /* Dark amber - lowered from 40% for WCAG AA 4.5:1 contrast */
   192	    --burn-full-thickness: 195 15% 35%; /* Dark gray */
   193	    
   194	    /* Dark Mode ECG/Cardiac Colors */
   195	    --ecg-normal: 142 60% 50%; /* Brighter green */
   196	    --ecg-abnormal: 43 85% 65%; /* Brighter amber */
   197	    --ecg-critical: 0 65% 55%; /* Brighter red */
   198	    --ecg-trace: 220 85% 65%; /* Brighter trace blue */
   199	    
   200	    /* Dark Mode Clinical Risk Levels */
   201	    --risk-low: 142 60% 50%; /* Brighter low risk */
   202	    --risk-moderate: 43 85% 65%; /* Brighter moderate */
   203	    --risk-high: 25 80% 65%; /* Brighter high risk */
   204	    --risk-critical: 0 65% 55%; /* Brighter critical */
   205	
   206	    /* Dark Mode Body Map Region Colors */
   207	    --region-none: 222 47% 11%; /* Slate-900 - dark unselected */
   208	    --region-25: 28 80% 20%; /* Dark amber */
   209	    --region-50: 20 80% 28%; /* Dark orange */
   210	    --region-75: 0 70% 30%; /* Dark red-700 */
   211	    --region-100: 0 84% 60%; /* Red-500 stays bright */
   212	    /* F-01b, dark mode: the halo INVERTS to light here. --region-stroke 174 80% 50% is
   213	       2.38 against --region-100, which stays bright red-500 in dark - so dark mode failed
   214	       the same way light did and no session had measured it. The white halo clears every
   215	       dark fill on its own (min 3.78). 