import SwiftData
import SwiftUI

/// Questions the user set aside with Not this one, each with a Bring back action. Set aside is
/// reversible: this page is the way back (house style rule 13).
struct SetAsideView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Question.createdAt, order: .reverse) private var allQuestions: [Question]

    @State private var failed = false

    private var setAside: [Question] {
        allQuestions.filter { $0.status == .retired && $0.templateID != "broad.open" }
    }

    var body: some View {
        let items = setAside
        Group {
            if items.isEmpty {
                EmptyPage(title: AppCopy.setAsideEmptyTitle, message: AppCopy.setAsideEmptyMessage)
            } else {
                List {
                    ForEach(items) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.text)
                            Button(AppCopy.bringBack) {
                                bringBack(question)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .paperPage()
        .navigationTitle(AppCopy.setAsideTitle)
        .alert(AppCopy.saveFailedTitle, isPresented: $failed) {
            Button(AppCopy.okButton, role: .cancel) {}
        } message: {
            Text(AppCopy.saveFailedMessage)
        }
    }

    private func bringBack(_ question: Question) {
        guard question.bringBack() else { return }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            failed = true
        }
    }
}
