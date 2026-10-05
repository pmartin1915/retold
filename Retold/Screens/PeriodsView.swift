import SwiftData
import SwiftUI

/// The Periods page (R7b section 7.5): rename and add. No reordering, no delete in 1.0.
struct PeriodsView: View {
    @Query private var periods: [Period]

    @State private var sheet: PeriodSheetTarget?

    private var ordered: [Period] {
        periods.sorted { (a: Period, b: Period) -> Bool in
            (a.sortOrder, a.id.uuidString) < (b.sortOrder, b.id.uuidString)
        }
    }

    var body: some View {
        List {
            ForEach(ordered) { period in
                Button(period.title) {
                    sheet = .rename(period)
                }
                .buttonStyle(.plain)
            }
            Button(AppCopy.addPeriod) {
                sheet = .add
            }
        }
        .navigationTitle(AppCopy.periodsTitle)
        .sheet(item: $sheet) { target in
            PeriodEditSheet(target: target)
        }
    }
}

enum PeriodSheetTarget: Identifiable {
    case add
    case rename(Period)

    var id: String {
        switch self {
        case .add: return "add"
        case .rename(let period): return period.id.uuidString
        }
    }
}

/// The rename / add sheet. Save is disabled while the trimmed text is empty; a duplicate keeps
/// the sheet open with a footnote. No alerts.
struct PeriodEditSheet: View {
    let target: PeriodSheetTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isDuplicate = false

    init(target: PeriodSheetTarget) {
        self.target = target
        switch target {
        case .add:
            _text = State(initialValue: "")
        case .rename(let period):
            _text = State(initialValue: period.title)
        }
    }

    private var isAdd: Bool {
        if case .add = target { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppCopy.newPeriodPlaceholder, text: $text)
                    if isDuplicate {
                        Text(AppCopy.duplicatePeriod)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isAdd ? AppCopy.addPeriod : AppCopy.renamePeriod)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancelButton) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppCopy.saveButton) {
                        save()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: text) { _, _ in
                isDuplicate = false
            }
        }
    }

    private func save() {
        do {
            switch target {
            case .add:
                _ = try PeriodEditor.add(title: text, in: modelContext)
            case .rename(let period):
                try PeriodEditor.rename(period, to: text, in: modelContext)
            }
            dismiss()
        } catch PeriodEditError.duplicateTitle {
            isDuplicate = true
        } catch {
            // .emptyTitle and save failures keep the sheet open, with no alert.
        }
    }
}
