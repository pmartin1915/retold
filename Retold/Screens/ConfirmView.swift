import Foundation
import SwiftData
import SwiftUI

struct ConfirmView: View {
    let capture: Capture
    let row: UnfiledRow
    let cachedOutcome: FilingOutcome?
    let onOutcome: (FilingOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
                    Color.clear
                }
            }
            .toolbar {
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
                    set: { value in mutateDraft { $0.typedTitle = value } }
                ))
            }

            Section(AppCopy.periodHeader) {
                if let suggested = current.suggestedPeriod,
                   current.periodSuggestionState != .rejected {
                    HStack {
                        Text(suggested.title)
                        if current.periodSuggestionState == .suggested {
                            Text(AppCopy.suggestedLabel)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(AppCopy.acceptButton) {
                            mutateDraft { $0.acceptSuggestedPeriod() }
                        }
                        Button(AppCopy.rejectButton) {
                            mutateDraft { $0.rejectSuggestedPeriod() }
                        }
                    }
                    .buttonStyle(.borderless)
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
                        set: { title in mutateDraft { $0.pick(.new(title)) } }
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
                        }
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
                        }
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
        HStack {
            Text(chip.span.text)
            if chip.state == .suggested {
                Text(AppCopy.suggestedLabel)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(AppCopy.acceptButton, action: accept)
            Button(AppCopy.rejectButton, action: reject)
        }
        .buttonStyle(.borderless)
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

    private func entityName(_ entity: TypedEntity, known: [EntityRef]) -> String {
        switch entity {
        case .existing(let id):
            return known.first(where: { $0.id == id })?.name ?? ""
        case .new(let name):
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func mutateDraft(_ mutation: (inout ConfirmDraft) -> Void) {
        guard var value = draft else { return }
        mutation(&value)
        draft = value
    }

    @MainActor
    private func load() async {
        guard draft == nil else { return }
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
        let outcome = await task.value
        guard !Task.isCancelled, draft == nil else { return }
        suggestionTask = nil
        findingSuggestions = false
        onOutcome(outcome)
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
        draft = ConfirmDraft.make(
            captureID: capture.id,
            outcome: outcome,
            periods: periods.map {
                PeriodRef(id: $0.id, title: $0.title, sortOrder: $0.sortOrder)
            },
            people: people.map { EntityRef(id: $0.id, name: $0.name) },
            places: places.map { EntityRef(id: $0.id, name: $0.name) }
        )
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
