import SwiftUI

/// The one designed empty state (house style rule 12): a title, a sentence on what will appear,
/// and one action. Used wherever a page can end up with no questions and no stories, so rejecting
/// the last question never leaves a blank page.
struct EmptyPage: View {
    let title: String
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "text.bubble")
        } description: {
            Text(message)
        } actions: {
            Button(AppCopy.goBack) {
                dismiss()
            }
        }
    }
}
