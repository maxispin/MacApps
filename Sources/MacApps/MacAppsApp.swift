import SwiftUI

/// Global font settings stored in UserDefaults
@MainActor
class FontSettings: ObservableObject {
    static let shared = FontSettings()

    // Overall scale (legacy, still used)
    @AppStorage("fontScale") var fontScale: Double = 1.0 {
        didSet { objectWillChange.send() }
    }

    // Individual font sizes
    @AppStorage("fontSize_appName") var appNameSize: Double = 15 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSize_description") var descriptionSize: Double = 12 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSize_detail") var detailSize: Double = 13 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSize_caption") var captionSize: Double = 11 {
        didSet { objectWillChange.send() }
    }

    @Published var showSettingsSheet = false

    func increase() {
        fontScale = min(fontScale + 0.1, 2.0)
    }

    func decrease() {
        fontScale = max(fontScale - 0.1, 0.6)
    }

    func reset() {
        fontScale = 1.0
        appNameSize = 15
        descriptionSize = 12
        detailSize = 13
        captionSize = 11
    }
}

@main
struct MacAppsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var fontSettings = FontSettings.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    static let version = "0.5.0"
    static let buildDate = "2025-12-26"

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

                Divider()

                Button("Font Settings...") {
                    fontSettings.showSettingsSheet = true
                }
            }
        }
    }
}

struct FontSettingsSheet: View {
    @EnvironmentObject var fontSettings: FontSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                Text("Font Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Adjust font sizes for different UI elements")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Settings
            Form {
                Section("Sidebar (App List)") {
                    FontSizeRow(
                        title: "App Name",
                        description: "Name of each app in the list",
                        size: $fontSettings.appNameSize,
                        range: 10...24
                    )
                    FontSizeRow(
                        title: "Description",
                        description: "Short description text under app name",
                        size: $fontSettings.descriptionSize,
                        range: 9...20
                    )
                }

                Section("Detail View") {
                    FontSizeRow(
                        title: "Detail Text",
                        description: "Main text in app detail view",
                        size: $fontSettings.detailSize,
                        range: 10...22
                    )
                    FontSizeRow(
                        title: "Captions",
                        description: "Labels and small info text",
                        size: $fontSettings.captionSize,
                        range: 8...16
                    )
                }

                Section("Global Scale") {
                    HStack {
                        Text("Overall Scale")
                        Spacer()
                        Text("\(Int(fontSettings.fontScale * 100))%")
                            .foregroundColor(.secondary)
                        Slider(value: $fontSettings.fontScale, in: 0.6...2.0, step: 0.1)
                            .frame(width: 150)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)

            Divider()

            // Buttons
            HStack {
                Button("Reset to Defaults") {
                    fontSettings.reset()
                }

                Spacer()

                Button("Done") {
                    fontSettings.showSettingsSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 450, height: 500)
    }
}

struct FontSizeRow: View {
    let title: String
    let description: String
    @Binding var size: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(size))pt")
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                Stepper("", value: $size, in: range, step: 1)
                    .labelsHidden()
            }
            Text("Preview: The quick brown fox")
                .font(.system(size: size))
                .foregroundColor(.secondary)
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
