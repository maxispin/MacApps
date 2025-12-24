import SwiftUI

@main
struct MacAppsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Scan Applications") {
                    Task {
                        await appState.scanApplications()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
