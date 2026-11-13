import Foundation
import SwiftData
import SwiftUI

struct ConfirmView: View {
    let capture: Capture
    let row: UnfiledRow
    let cachedOutcome: FilingOutcome?
    /// R7b: the period of the question this capture answers, if any; pre-picked in the draft.
    let answeredPeriodID: UUID?
    let onOutcome: (FilingOutcome) -> Void
    /// comeup run 2, V2: called with the filed title after a successful File it (Home shows a pill).
    var onFiled: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true
    @Query(sort: \Period.sortOrder) private var periods: [Period]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Place.name) private var places: [Place]

    @State private var draft: ConfirmDraft?
    @State private var mode: FilingMode?
    @State private var suggestionTask: Task<FilingOutcome, Never>?
    @State private var findingSuggestions = false
    @State private var whenMode = WhenMode.year
    @State private var selectedWhenValue: Int?
    @State private var newPersonName = ""
    @State private var newPlaceName = ""
    /// comeup run 2: a failed File it used to do nothing visible.
    @State private var fileFailed = false
    /// comeup run 2, V1: bumped by Use this / Not this / choice taps for a selection haptic.
    @State private var choiceTick = 0
    /// Perry 2026-11-12: a greyed File it left him unsure what was required. File it stays tappable;
    /// without a title it moves the cursor to the title field instead of filing.
    @FocusState private var titleFocused: Bool
    @State private var titleNudge = 0
    /// comeup run 3 (F4, Perry's pick): people, places and questions for later sit behind a fold,
    /// so the File it bar is near the top. Opened by the user; suggestions inside are counted.
    @State private var showMoreDetails = false

    private enum WhenMode: Hashable {
        case year, age
    }

    private enum PeriodPickerValue: Hashable {
        case none
        case existing(UUID)
        case new
    }

    var body: some View {
        NavigationStack {
            Group {
                if let current = draft {
                    form(current)
                        .transition(.opacity)
                        // comeup run 3 (C8): File it is the sheet's one primary action, in thumb
                        // reach, with the reason it is unavailable right above it.
                        .primaryActionBar {
                            // Always laid out, shown only while File it is unavailable, so the
                            // bar does not change height as the first letter of a title is typed.
                            Text(AppCopy.titleNeededHint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .opacity(current.canFile ? 0 : 1)
                                .accessibilityHidden(current.canFile)
                            Button {
                                if current.canFile {
                                    file()
                                } else {
                                    titleFocused = true
                                    titleNudge += 1
                                }
                            } label: {
                                Text(AppCopy.fileButton)
                                    .frame(maxWidth: .infinity)
                            }
                            .primaryAction()
                            .accessibilityHint(current.canFile ? "" : AppCopy.titleNeededHint)
                        }
                } else {
                    // comeup run 3 (C6, F3): placeholder rows in the form's shape while the draft
                    // builds, instead of a bare spinner that the whole form then replaces.
                    ConfirmPlaceholder(
                        finding: findingSuggestions,
                        skip: skipSuggestions
                    )
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : DesignTokens.Motion.change, value: draft == nil)
            .paperPage()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancelButton) { dismiss() }
                }
            }
        }
        .alert(AppCopy.saveFailedTitle, isPresented: $fileFailed) {
            Button(AppCopy.okButton, role: .cancel) {}
        } message: {
            Text(AppCopy.saveFailedMessage)
        }
        .sensoryFeedback(.error, trigger: fileFailed) { _, failed in failed }
        .sensoryFeedback(.selection, trigger: choiceTick)
        .sensoryFeedback(.warning, trigger: titleNudge)
        .task {
            await load()
        }
        .onDisappear {
            suggestionTask?.cancel()
        }
    }

    @ViewBuilder
    private func form(_ current: ConfirmDraft) -> some View {
        Form {
            if case .deck(let reason)? = mode, let copy = reason.copy {
                Section {
                    Text(copy)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // comeup run 3 (O-1): the recording's own words, set apart, so they are not read as
            // the title. Shown verbatim (Rule 1), only shortened for the sheet.
            EyebrowSection(AppCopy.whatYouSaidHeader) {
                switch row {
                case .ready(let excerpt):
                    Text(excerpt)
                        .fontDesign(DesignTokens.wordsFontDesign)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                case .noTranscript:
                    Text(AppCopy.noTranscriptLabel)
                        .foregroundStyle(.secondary)
                case .transcribing:
                    Text(AppCopy.transcribingLabel)
                        .foregroundStyle(.secondary)
                }
            }

            EyebrowSection(AppCopy.titleHeader) {
                if let chip = current.titleChip {
                    suggestionRow(chip: chip) {
                        mutateDraft { $0.acceptTitle() }
                    } reject: {
                        mutateDraft { $0.rejectTitle() }
                    }
                }
                TextField(AppCopy.titlePlaceholder, text: Binding(
                    get: { draft?.typedTitle ?? "" },
                    set: { value in mutateDraft(animated: false) { $0.typedTitle = value } }
                ))
                .focused($titleFocused)
            }

            EyebrowSection(AppCopy.periodHeader) {
                if let suggested = current.suggestedPeriod,
                   current.periodSuggestionState != .rejected {
                    suggestionRow(
                        text: suggested.title,
                        state: current.periodSuggestionState
                    ) {
                        mutateDraft { $0.acceptSuggestedPeriod() }
                    } reject: {
                        mutateDraft { $0.rejectSuggestedPeriod() }
                    }
                }
                Picker(AppCopy.periodHeader, selection: periodSelection) {
                    Text(AppCopy.noPeriod).tag(PeriodPickerValue.none)
                    ForEach(periods) { period in
                        Text(period.title).tag(PeriodPickerValue.existing(period.id))
                    }
                    Text(AppCopy.newPeriod).tag(PeriodPickerValue.new)
                }
                if case .new = current.periodPick {
                    TextField(AppCopy.newPeriodPlaceholder, text: Binding(
                        get: {
                            if case .new(let title)? = draft?.periodPick { return title }
                            return ""
                        },
                        set: { title in mutateDraft(animated: false) { $0.pick(.new(title)) } }
                    ))
                }
            }

            EyebrowSection(AppCopy.whenHeader) {
                Text(current.whenQuestion.text)
                // Perry 2026-11-12, an "Age" pick did not stick. The mode, the wheel's value and the
                // draft now change together in the bindings' setters (Sol review on PR #38: the old
                // onChange pair cleared the value one update after the wheel was rebuilt).
                Picker(AppCopy.whenHeader, selection: Binding(
                    get: { whenMode },
                    set: { mode in
                        guard mode != whenMode else { return }
                        whenMode = mode
                        selectedWhenValue = nil
                        mutateDraft { $0.setWhen(.notSure) }
                    }
                )) {
                    Text(AppCopy.whenYear).tag(WhenMode.year)
                    Text(AppCopy.whenAge).tag(WhenMode.age)
                }
                .pickerStyle(.segmented)
                Picker(AppCopy.whenHeader, selection: Binding(
                    get: { selectedWhenValue },
                    set: { value in
                        selectedWhenValue = value
                        mutateDraft {
                            guard let value else { return $0.setWhen(.notSure) }
                            $0.setWhen(whenMode == .year ? .year(value) : .age(value))
                        }
                    }
                )) {
                    Text(AppCopy.notSure).tag(Int?.none)
                    if whenMode == .year {
                        ForEach(Array(stride(from: Calendar.current.component(.year, from: Date()), through: 1900, by: -1)), id: \.self) { year in
                            Text(String(year)).tag(Int?.some(year))
                        }
                    } else {
                        ForEach(0...100, id: \.self) { age in
                            Text(String(age)).tag(Int?.some(age))
                        }
                    }
                }
                .pickerStyle(.wheel)
                // A wheel whose rows are swapped in place (years <-> ages) can keep stale
                // UIPickerView state, so it is rebuilt on each mode change.
                .id(whenMode)
                Button(AppCopy.notSure) {
                    selectedWhenValue = nil
                    mutateDraft { $0.setWhen(.notSure) }
                }
            }

            Section {
                Button {
                    withAnimation(reduceMotion ? nil : DesignTokens.Motion.change) {
                        showMoreDetails.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(AppCopy.moreDetails)
                                .foregroundStyle(.primary)
                            let waiting = waitingSuggestions(current)
                            if waiting > 0 {
                                Text(AppCopy.suggestionsWaiting(waiting))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showMoreDetails ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityValue(showMoreDetails ? AppCopy.expandedValue : AppCopy.collapsedValue)
            }

            if showMoreDetails {
                EyebrowSection(AppCopy.peopleHeader) {
                    ForEach(current.people) { chip in
                        suggestionRow(chip: chip) {
                            mutateDraft { $0.setChip(chip.id, .accepted) }
                        } reject: {
                            mutateDraft { $0.setChip(chip.id, .rejected) }
                        }
                        if chip.state == .accepted, let match = chip.match {
                            Picker(AppCopy.peopleHeader, selection: Binding(
                                get: {
                                    draft?.people.first(where: { $0.id == chip.id })?.useMatch ?? true
                                },
                                set: { useMatch in
                                    mutateDraft { $0.setUseMatch(chip.id, useMatch) }
                                }
                            )) {
                                Text("\(AppCopy.sameAs) \(match.name)").tag(true)
                                Text(AppCopy.newPerson).tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    ForEach(Array(current.typedPeople.enumerated()), id: \.offset) { index, entity in
                        HStack {
                            Text(entityName(entity, known: current.knownPeople))
                            Spacer()
                            Button {
                                mutateDraft { $0.removeTypedPerson(at: index) }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(removeLabel(entityName(entity, known: current.knownPeople)))
                        }
                        .buttonStyle(.borderless)
                    }
                    Menu(AppCopy.addPerson) {
                        ForEach(current.knownPeople, id: \.id) { person in
                            Button(person.name) {
                                mutateDraft { $0.addTypedPerson(.existing(person.id)) }
                            }
                        }
                    }
                    TextField(AppCopy.newPerson, text: $newPersonName)
                        .onSubmit {
                            let name = newPersonName
                            mutateDraft { $0.addTypedPerson(.new(name)) }
                            newPersonName = ""
                        }
                }

                EyebrowSection(AppCopy.placesHeader) {
                    ForEach(current.places) { chip in
                        suggestionRow(chip: chip) {
                            mutateDraft { $0.setChip(chip.id, .accepted) }
                        } reject: {
                            mutateDraft { $0.setChip(chip.id, .rejected) }
                        }
                        if chip.state == .accepted, let match = chip.match {
                            Picker(AppCopy.placesHeader, selection: Binding(
                                get: {
                                    draft?.places.first(where: { $0.id == chip.id })?.useMatch ?? true
                                },
                                set: { useMatch in
                                    mutateDraft { $0.setUseMatch(chip.id, useMatch) }
                                }
                            )) {
                                Text("\(AppCopy.sameAs) \(match.name)").tag(true)
                                Text(AppCopy.newPlace).tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    if let typedPlace = current.typedPlace {
                        HStack {
                            Text(entityName(typedPlace, known: current.knownPlaces))
                            Spacer()
                            Button {
                                mutateDraft { $0.setTypedPlace(nil) }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(removeLabel(entityName(typedPlace, known: current.knownPlaces)))
                        }
                        .buttonStyle(.borderless)
                    }
                    Menu(AppCopy.addPlace) {
                        ForEach(current.knownPlaces, id: \.id) { place in
                            Button(place.name) {
                                mutateDraft { $0.setTypedPlace(.existing(place.id)) }
                            }
                        }
                    }
                    TextField(AppCopy.newPlace, text: $newPlaceName)
                        .onSubmit {
                            let name = newPlaceName
                            mutateDraft { $0.setTypedPlace(.new(name)) }
                            newPlaceName = ""
                        }
                }

                EyebrowSection(AppCopy.followUpsHeader) {
                    ForEach(current.followUps.filter { current.isLive($0) }) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.question.text)
                            if row.question.templateID != FilingTemplates.broad.id {
                                HStack {
                                    choiceButton(
                                        AppCopy.later,
                                        selected: row.choice == .later
                                    ) {
                                        mutateDraft { $0.setRow(row.id, .later) }
                                    }
                                    choiceButton(
                                        AppCopy.notThisOne,
                                        selected: row.choice == .notThisOne
                                    ) {
                                        mutateDraft { $0.setRow(row.id, .notThisOne) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func suggestionRow(
        chip: SpanChip,
        accept: @escaping () -> Void,
        reject: @escaping () -> Void
    ) -> some View {
        suggestionRow(text: chip.span.text, state: chip.state, accept: accept, reject: reject)
    }

    /// comeup run 2: the user's words get the full row width; the actions sit on their own line
    /// (they used to squeeze the words into a three-line column). VoiceOver names what each acts on.
    /// comeup run 3 (C4, C5): an accepted suggestion shows as chosen ("Using this", filled) with
    /// Not this still there to undo it; both buttons are 44 pt and stack at large text sizes.
    private func suggestionRow(
        text: String,
        state: ChipState,
        accept: @escaping () -> Void,
        reject: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(text)
                    .fontDesign(DesignTokens.wordsFontDesign)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if state == .suggested {
                    Text(AppCopy.suggestedLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            // Side by side normally; stacked at accessibility text sizes so neither label clips.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.s))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.s))
            layout {
                suggestionButtons(text: text, state: state, accept: accept, reject: reject)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    @ViewBuilder
    private func suggestionButtons(
        text: String,
        state: ChipState,
        accept: @escaping () -> Void,
        reject: @escaping () -> Void
    ) -> some View {
        let accepted = state == .accepted
        let acceptTitle = accepted ? AppCopy.acceptedButton : AppCopy.acceptButton
        Button {
            accept()
            choiceTick += 1
        } label: {
            Label(acceptTitle, systemImage: accepted ? "checkmark.circle.fill" : "checkmark")
                .frame(minHeight: 44)
        }
        .modifier(ChoiceStyle(chosen: accepted))
        .accessibilityLabel("\(acceptTitle): \(text)")
        .accessibilityAddTraits(accepted ? .isSelected : [])
        Button {
            reject()
            choiceTick += 1
        } label: {
            Label(AppCopy.rejectButton, systemImage: "xmark")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .accessibilityLabel("\(AppCopy.rejectButton): \(text)")
    }

    /// Suggestions not yet accepted or rejected inside the More details fold.
    private func waitingSuggestions(_ current: ConfirmDraft) -> Int {
        current.people.filter { $0.state == .suggested }.count
            + current.places.filter { $0.state == .suggested }.count
    }

    private func choiceButton(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            choiceTick += 1
        } label: {
            HStack {
                if selected {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private var periodSelection: Binding<PeriodPickerValue> {
        Binding(
            get: {
                switch draft?.periodPick ?? .none {
                case .none: return .none
                case .existing(let id): return .existing(id)
                case .new: return .new
                }
            },
            set: { selection in
                mutateDraft {
                    switch selection {
                    case .none: $0.pick(.none)
                    case .existing(let id): $0.pick(.existing(id))
                    case .new: $0.pick(.new(""))
                    }
                }
            }
        )
    }

    private func removeLabel(_ name: String) -> String {
        name.isEmpty ? AppCopy.removeLabel : "\(AppCopy.removeLabel) \(name)"
    }

    private func entityName(_ entity: TypedEntity, known: [EntityRef]) -> String {
        switch entity {
        case .existing(let id):
            return known.first(where: { $0.id == id })?.name ?? ""
        case .new(let name):
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Animated by default so rows that appear or vanish (a picker, a "Same as" choice) do not
    /// jump; typing passes `animated: false`. Reduce Motion turns the animation off.
    private func mutateDraft(animated: Bool = true, _ mutation: (inout ConfirmDraft) -> Void) {
        guard var value = draft else { return }
        mutation(&value)
        if animated && !reduceMotion {
            withAnimation(DesignTokens.Motion.change) { draft = value }
        } else {
            draft = value
        }
    }

    @MainActor
    private func load() async {
        guard draft == nil else { return }
        #if DEBUG
        // `-RetoldDemo` only: a simulator has no Apple Intelligence, so the demo files through the
        // production pipeline over a scripted model (DemoMode.filingPipeline). Without the
        // argument this block does nothing; the Release build does not compile it.
        if DemoMode.isActive {
            mode = .model
            if let transcript = capture.completedTranscript {
                let outcome = await DemoMode.filingPipeline()
                    .file(transcript, periodTitles: periods.map(\.title))
                buildDraft(outcome: outcome)
            } else {
                buildDraft(outcome: nil)
            }
            return
        }
        #endif
        let selectedMode = FilingMode.select(
            availability: ModelAvailability.current,
            suggestionsOn: suggestionsOn
        )
        mode = selectedMode

        if row == .noTranscript {
            buildDraft(outcome: nil)
            return
        }
        if case .deck = selectedMode {
            buildDraft(outcome: nil)
            return
        }
        if let cachedOutcome {
            buildDraft(outcome: cachedOutcome)
            return
        }
        guard let transcript = capture.completedTranscript else {
            buildDraft(outcome: nil)
            return
        }

        findingSuggestions = true
        let periodTitles = periods.map(\.title)
        let task = Task {
            await FilingPipeline(
                model: FoundationFilingModel(),
                counter: DeviceTokenCounter()
            ).file(transcript, periodTitles: periodTitles)
        }
        suggestionTask = task
        // The inner Task is unstructured, so forward cancellation to it explicitly.
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        suggestionTask = nil
        findingSuggestions = false
        guard draft == nil else { return }
        if Task.isCancelled {
            // A cancelled load must not strand a blank sheet; show the plain form instead.
            buildDraft(outcome: nil)
            return
        }
        // Only a real proposal is cached: a .noModel failure (cancelled, timeout) retries on the next open.
        if case .proposal = outcome {
            onOutcome(outcome)
        }
        buildDraft(outcome: outcome)
    }

    private func skipSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = nil
        findingSuggestions = false
        buildDraft(outcome: nil)
    }

    private func buildDraft(outcome: FilingOutcome?) {
        guard draft == nil else { return }
        var built = ConfirmDraft.make(
            captureID: capture.id,
            outcome: outcome,
            periods: periods.map {
                PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder)
            },
            people: people.map { EntityRef(id: $0.id, name: $0.name) },
            places: places.map { EntityRef(id: $0.id, name: $0.name) }
        )
        // The user chose to answer this period's question: a user act, not a suggestion.
        if let id = answeredPeriodID, periods.contains(where: { $0.id == id }) {
            built.pick(.existing(id))
        }
        draft = built
    }

    private func file() {
        guard let draft else { return }
        do {
            try ConfirmFiler.file(draft, capture: capture, in: modelContext)
            switch draft.resolvedTitle {
            case .typed(let title)?: onFiled(title)
            case .quote(let span)?: onFiled(span.text)
            case nil: break
            }
            dismiss()
        } catch {
            // Filing failures keep the unchanged draft on screen, per the R7a contract, and say so.
            fileFailed = true
        }
    }
}

/// The accept button: bordered while it is an offer, filled once it is the choice.
private struct ChoiceStyle: ViewModifier {
    let chosen: Bool

    func body(content: Content) -> some View {
        if chosen {
            content
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.onAccent)
        } else {
            content
                .buttonStyle(.bordered)
                .tint(.accentColor)
        }
    }
}

/// The confirm sheet while its draft builds (comeup run 3, C6 and F3, Perry's pick; BoardBound
/// Skeleton.tsx): grey rows in the form's shape that breathe slowly, still under Reduce Motion,
/// with what is happening and the way to skip it on top.
private struct ConfirmPlaceholder: View {
    let finding: Bool
    let skip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        Form {
            if finding {
                Section {
                    HStack(spacing: DesignTokens.Spacing.s) {
                        ProgressView()
                        Text(AppCopy.findingSuggestions)
                    }
                    Button(AppCopy.skipSuggestions, action: skip)
                }
            }
            Group {
                EyebrowSection(AppCopy.whatYouSaidHeader) {
                    Text("A few lines of what you said, shown while this loads.")
                    Text("A second line of words.")
                }
                EyebrowSection(AppCopy.titleHeader) {
                    Text("A suggested title")
                    Text("Type a title")
                }
                EyebrowSection(AppCopy.periodHeader) {
                    Text("A period of your life")
                }
            }
            .redacted(reason: .placeholder)
            .opacity(dim ? 0.4 : 1)
            .accessibilityHidden(true)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
        }
    }
}
