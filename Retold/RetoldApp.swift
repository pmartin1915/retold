import SwiftUI

@main
struct RetoldApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Retold")
                .font(.largeTitle.bold())
            Text("Week 0 scaffold -- recorder lands in week 1 (docs/PLAN.md section 12)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
