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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                } else if findingSuggestions {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(AppCopy.findingSuggestions)
                        Button(AppCopy.skipSuggestions) {
                            skipSuggestions()
                        }
                    }
                    .padding()
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancelButton) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppCopy.fileButton) {
                        file()
                    }
                    .disabled(!(draft?.canFile ?? false))
                }
            }
        }
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

            Section(AppCopy.titleHeader) {
                switch row {
                case .ready(let excerpt):
                    Text(excerpt)
                case .noTranscript:
                    Text(AppCopy.noTranscriptLabel)
                case .transcribing:
                    Text(AppCopy.transcribingLabel)
                }
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
                if !current.canFile {
                    Text(AppCopy.titleNeededHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(AppCopy.periodHeader) {
                if let suggested = current.suggestedPeriod,
                   current.periodSuggestionState != .rejected {
                    suggestionRow(
                        text: suggested.title,
                        isSuggested: current.periodSuggestionState == .suggested
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

            Section(AppCopy.whenHeader) {
                Text(current.whenQuestion.text)
                Picker(AppCopy.whenHeader, selection: $whenMode) {
                    Text(AppCopy.whenYear).tag(WhenMode.year)
                    Text(AppCopy.whenAge).tag(WhenMode.age)
                }
                .pickerStyle(.segmented)
                .onChange(of: whenMode) { _, _ in
                    selectedWhenValue = nil
                    mutateDraft { $0.setWhen(.notSure) }
                }
                Picker(AppCopy.whenHeader, selection: $selectedWhenValue) {
                    Text("—").tag(Int?.none)
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
                .onChange(of: selectedWhenValue) { _, value in
                    guard let value else {
                        mutateDraft { $0.setWhen(.notSure) }
                        return
                    }
                    mutateDraft {
                        $0.setWhen(whenMode == .year ? .year(value) : .age(value))
                    }
                }
                Button(AppCopy.notSure) {
                    selectedWhenValue = nil
                    mutateDraft { $0.setWhen(.notSure) }
                }
            }

            Section(AppCopy.peopleHeader) {
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

            Section(AppCopy.placesHeader) {
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

            Section(AppCopy.followUpsHeader) {
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

    private func suggestionRow(
        chip: SpanChip,
        accept: @escaping () -> Void,
        reject: @escaping () -> Void
    ) -> some View {
        suggestionRow(text: chip.span.text, isSuggested: chip.state == .suggested, accept: accept, reject: reject)
    }

    /// comeup run 2: the user's words get the full row width; the actions sit on their own line
    /// (they used to squeeze the words into a three-line column). VoiceOver names what each acts on.
    private func suggestionRow(
        text: String,
        isSuggested: Bool,
        accept: @escaping () -> Void,
        reject: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSuggested {
                    Text(AppCopy.suggestedLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: DesignTokens.Spacing.s) {
                Button(action: accept) {
                    Label(AppCopy.acceptButton, systemImage: "checkmark")
                        .frame(minHeight: 32)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .accessibilityLabel("\(AppCopy.acceptButton): \(text)")
                Button(action: reject) {
                    Label(AppCopy.rejectButton, systemImage: "xmark")
                        .frame(minHeight: 32)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .accessibilityLabel("\(AppCopy.rejectButton): \(text)")
            }
        }
        .padding(.vertical, 4)
    }

    private func choiceButton(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
            withAnimation(.smooth(duration: 0.25)) { draft = value }
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
            dismiss()
        } catch {
            // Filing failures keep the unchanged draft on screen, per the R7a contract.
        }
    }
}
