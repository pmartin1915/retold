import SwiftUI

enum SettingsKeys {
    static let suggestionsOn = "retold.suggestionsOn"
}

struct SettingsView: View {
    @AppStorage(SettingsKeys.suggestionsOn) private var suggestionsOn = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(AppCopy.suggestionsToggle, isOn: $suggestionsOn)
                    Text(AppCopy.suggestionsFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(AppCopy.settingsTitle)
        }
    }
}
