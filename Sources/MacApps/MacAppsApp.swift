import SwiftUI

/// Global font scale stored in UserDefaults
class FontSettings: ObservableObject {
    static let shared = FontSettings()

    @AppStorage("fontScale") var fontScale: Double = 1.0 {
        didSet { objectWillChange.send() }
    }

    func increase() {
        fontScale = min(fontScale + 0.1, 2.0)
    }

    func decrease() {
        fontScale = max(fontScale - 0.1, 0.6)
    }

    func reset() {
        fontScale = 1.0
    }
}

@main
struct MacAppsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var fontSettings = FontSettings.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    static let version = "0.4.2.0"
    static let buildDate = "2025-12-25"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(fontSettings)
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
            CommandGroup(after: .sidebar) {
                Button("Increase Font Size") {
                    fontSettings.increase()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    fontSettings.decrease()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    fontSettings.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app appears in Dock
        NSApp.setActivationPolicy(.regular)
        // Bring to front
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
