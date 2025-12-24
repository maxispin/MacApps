import SwiftUI

@main
struct MacAppsApp: App {
    @StateObject private var appState = AppState()

    static let version = "0.2.2.0"
    static let buildDate = "2024-12-24"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
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
