import SwiftUI

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let app = appState.selectedApp {
            AppDetailView(app: app)
        } else {
            ContentUnavailableView {
                Label("Select an Application", systemImage: "app.dashed")
            } description: {
                Text("Choose an app from the list to view details")
            }
        }
    }
}

struct AppDetailView: View {
    let app: AppInfo
    @EnvironmentObject var appState: AppState
    @State private var isUpdating = false
    @State private var showSuccess = false
    @State private var showError = false

    var body: some View {
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
    }
}

struct AppHeaderView: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 16) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .shadow(radius: 4)
            }

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

                HStack {
                    if app.hasDescription {
                        Label("Has Description", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("No Description", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
    }
}

struct DescriptionSection: View {
    let app: AppInfo
    @EnvironmentObject var appState: AppState
    @Binding var isUpdating: Bool
    @Binding var showSuccess: Bool
    @Binding var showError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finder Comment")
                .font(.headline)

            GroupBox {
                if let comment = app.finderComment, !comment.isEmpty {
                    Text(comment)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Text("No description set. Click 'Generate Description' to create one using AI.")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 60)

            Text("Generates both short and detailed descriptions for better Finder searchability")
                .font(.caption)
                .foregroundColor(.secondary)

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
                .disabled(isUpdating || !appState.claudeAvailable)

                Button(action: {
                    appState.refreshApp(app)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh from Finder")

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

            // Show current update status
            if !appState.currentUpdateText.isEmpty {
                Text(appState.currentUpdateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
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

                Button(action: { appState.openInFinder(app) }) {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
        }
    }
}
