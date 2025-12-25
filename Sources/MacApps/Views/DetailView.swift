import SwiftUI

struct DetailView: View {
    @EnvironmentObject var appState: AppState
    @State private var isUpdating = false
    @State private var showSuccess = false
    @State private var showError = false

    var body: some View {
        if let app = appState.selectedApp {
            ScrollView {
                VStack(spacing: 24) {
                    AppHeaderView(app: app)

                    Divider()

                    DescriptionSection(
                        app: app,
                        isUpdating: $isUpdating,
                        showSuccess: $showSuccess,
                        showError: $showError
                    )

                    Divider()

                    AppInfoSection(app: app)

                    Divider()

                    ActionsSection(app: app)

                    Spacer()
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .id("\(app.path)-\(app.categories.map { $0.rawValue }.joined())-\(app.descriptions?.count ?? 0)")  // Force refresh when app data changes
        } else {
            ContentUnavailableView {
                Label("Select an Application", systemImage: "app.dashed")
            } description: {
                Text("Choose an app from the list to view details")
            }
        }
    }
}

struct AppHeaderView: View {
    let app: AppInfo
    @ObservedObject var iconManager = IconManager.shared
    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: 20) {
            // Large app icon (128x128)
            Image(nsImage: icon ?? iconManager.icon(for: app.path))
                .resizable()
                .frame(width: 128, height: 128)
                .shadow(radius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let bundleId = app.bundleIdentifier {
                    Text(bundleId)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    if let category = app.category {
                        Label(category.rawValue, systemImage: category.icon)
                            .foregroundColor(category.color)
                    } else {
                        Label("Uncategorized", systemImage: "questionmark.circle")
                            .foregroundColor(.secondary)
                    }

                    if app.hasDescription {
                        Label("Has Description", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("No Description", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }

                    if app.isMenuBarApp {
                        Label("Menu Bar App", systemImage: "menubar.rectangle")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .task(id: app.path) {
            icon = await iconManager.loadIcon(for: app.path)
        }
    }
}

struct DescriptionSection: View {
    let app: AppInfo
    @EnvironmentObject var appState: AppState
    @Binding var isUpdating: Bool
    @Binding var showSuccess: Bool
    @Binding var showError: Bool

    private func languageName(for code: String) -> String {
        switch code {
        case "fi": return "Suomi"
        case "en": return "English"
        case "sv": return "Svenska"
        case "de": return "Deutsch"
        case "fr": return "Français"
        default: return code.uppercased()
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            let seconds = Double(ms) / 1000.0
            return String(format: "%.1fs", seconds)
        }
    }

    private func durationColor(_ ms: Int) -> Color {
        if ms < 2000 { return .green }
        if ms < 5000 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Descriptions")
                .font(.headline)

            // Show descriptions for each language
            if let descriptions = app.descriptions, !descriptions.isEmpty {
                ForEach(descriptions, id: \.language) { desc in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(languageName(for: desc.language))
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)

                            if let short = desc.shortDescription {
                                Text(short)
                                    .fontWeight(.medium)
                            }
                            if let expanded = desc.expandedDescription {
                                Text(expanded)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    }
                }
            } else if let comment = app.finderComment, !comment.isEmpty {
                GroupBox {
                    Text(comment)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            } else {
                GroupBox {
                    Text("No description set. Click 'Generate Description' to create one using AI.")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Show missing languages
            if !app.missingLanguages.isEmpty {
                Text("Missing: \(app.missingLanguages.map { languageName(for: $0) }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if app.hasDescription {
                Text("All languages fetched (\(AppDatabase.targetLanguages.map { languageName(for: $0) }.joined(separator: ", ")))")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            HStack {
                Button(action: {
                    Task {
                        isUpdating = true
                        showSuccess = false
                        showError = false

                        await appState.updateSingleApp(app)

                        isUpdating = false
                        if app.hasDescription || appState.lastGeneratedDescription.isEmpty == false {
                            showSuccess = true
                        } else {
                            showError = true
                        }
                    }
                }) {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isUpdating ? "Generating..." : "Generate Description")
                    }
                }
                .help("Use Claude AI to generate action-focused descriptions (what you can DO with this app) and assign a category. Creates short + expanded description in system language and English. Saves to Finder comment for Spotlight search.")
                .disabled(isUpdating || !appState.claudeAvailable)

                Spacer()

                if showSuccess {
                    Label("Updated!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                if showError {
                    Label("Failed", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }

            if !appState.claudeAvailable {
                Label("Claude CLI not found. Install it to generate descriptions.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Show current update status with timing
            if !appState.currentUpdateText.isEmpty {
                HStack {
                    Text(appState.currentUpdateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if appState.lastRequestDuration > 0 {
                        Text(formatDuration(appState.lastRequestDuration))
                            .font(.caption)
                            .foregroundColor(durationColor(appState.lastRequestDuration))
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

struct AppInfoSection: View {
    let app: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application Info")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Path:")
                        .foregroundColor(.secondary)
                    Text(app.path)
                        .textSelection(.enabled)
                }

                if let bundleId = app.bundleIdentifier {
                    GridRow {
                        Text("Bundle ID:")
                            .foregroundColor(.secondary)
                        Text(bundleId)
                            .textSelection(.enabled)
                    }
                }

                GridRow {
                    Text("Source:")
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: app.source.icon)
                        Text(app.source.rawValue)
                    }
                }

                GridRow {
                    Text("Category:")
                        .foregroundColor(.secondary)
                    if let category = app.category {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                            Text(category.rawValue)
                        }
                    } else {
                        Text("Not categorized")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                if let original = app.originalFinderComment, !original.isEmpty {
                    GridRow {
                        Text("Original Comment:")
                            .foregroundColor(.secondary)
                        Text(original)
                            .textSelection(.enabled)
                            .foregroundColor(.orange)
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
        }
    }
}

struct ActionsSection: View {
    let app: AppInfo
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: { appState.launchApp(app) }) {
                    Label("Launch", systemImage: "play.fill")
                }
                .help("Open the application. For menu bar apps, also tries to show the menu bar icon.")

                if app.isMenuBarApp {
                    Button(action: { appState.openAppPreferences(app) }) {
                        Label("Open Preferences", systemImage: "gearshape")
                    }
                    .help("Open the app's preferences/settings window (sends Cmd+, after launching)")
                }

                Button(action: { appState.openInFinder(app) }) {
                    Label("Show in Finder", systemImage: "folder")
                }
                .help("Reveal the application in Finder. Opens the folder containing the app.")
            }
        }
    }
}
