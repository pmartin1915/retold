import AppIntents
import SwiftUI
import WidgetKit

// The Action-button / Control Center control (R6 spec section 7). Pressing it runs
// StartCaptureIntent, which opens the app and runs perform() in the app process.

@main
struct RetoldControlsBundle: WidgetBundle {
    var body: some Widget {
        StartCaptureControl()
    }
}

struct StartCaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.pmartin1915.retold.start-capture") {
            ControlWidgetButton(action: StartCaptureIntent()) {
                Label("Record a memory", systemImage: "mic.fill")
            }
        }
        .displayName("Record a memory")
    }
}
