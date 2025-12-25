import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarView()
        }
        .sheet(isPresented: $appState.showBatchUpdateSheet) {
            BatchUpdateSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showProgressSheet) {
            ProgressSheet()
                .environmentObject(appState)
        }
        .task {
            await appState.loadFromCache()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $appState.searchText)
                .padding()

            // Description filter picker
            Picker(selection: $appState.filterOption) {
                ForEach(AppState.FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Source filter picker
            Picker(selection: $appState.sourceFilter) {
                ForEach(AppState.SourceFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Statistics bar
            StatisticsBar()
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            // App list
            AppListView()

            Divider()

            // Version footer
            HStack {
                Text("MacApps v\(MacAppsApp.version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if !appState.claudeAvailable {
                    Label("Claude CLI not found", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 350)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search apps or descriptions...", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StatisticsBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let stats = appState.statistics
        HStack(spacing: 16) {
            Label("\(stats.total)", systemImage: "app.fill")
                .foregroundColor(.primary)
            Label("\(stats.withDescription)", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("\(stats.withoutDescription)", systemImage: "circle")
                .foregroundColor(.orange)
        }
        .font(.caption)
    }
}

struct AppListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(appState.filteredApps, selection: $appState.selectedApp) { app in
            AppRowView(app: app)
                .tag(app)
        }
        .listStyle(.inset)
        .overlay {
            if appState.scanStatus == .scanning {
                ProgressView("Scanning applications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            } else if appState.filteredApps.isEmpty {
                ContentUnavailableView {
                    Label("No Applications", systemImage: "app.dashed")
                } description: {
                    if !appState.searchText.isEmpty {
                        Text("No apps match '\(appState.searchText)'")
                    } else {
                        Text("No applications found")
                    }
                }
            }
        }
    }
}

struct AppRowView: View {
    let app: AppInfo
    @EnvironmentObject var appState: AppState
    @ObservedObject var iconManager = IconManager.shared
    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            // App icon - updates when iconManager.loadedCount changes
            Image(nsImage: icon ?? iconManager.icon(for: app.path))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)

                if let description = app.displayDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No description")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }
            }

            Spacer()

            // Source indicator
            if app.source != .applications {
                Image(systemName: app.source.icon)
                    .foregroundColor(.secondary)
                    .font(.caption2)
                    .help(app.source.rawValue)
            }

            // Menu bar app indicator
            if app.isMenuBarApp {
                Image(systemName: "menubar.rectangle")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .help("Menu bar app")
            }

            // Status indicator
            if app.hasDescription {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .task(id: app.path) {
            // Load icon immediately when row appears
            icon = await iconManager.loadIcon(for: app.path)
        }
        .onChange(of: iconManager.loadedCount) { _, _ in
            // Refresh icon from cache when any icon loads
            if icon == nil {
                icon = iconManager.icon(for: app.path)
            }
        }
        .onTapGesture(count: 2) {
            // Double-click to launch app
            appState.launchApp(app)
        }
        .onTapGesture(count: 1) {
            // Single click to select
            appState.selectedApp = app
        }
        .contextMenu {
            Button("Open in Finder") {
                appState.openInFinder(app)
            }
            Button("Launch App") {
                appState.launchApp(app)
            }
            if app.isMenuBarApp {
                Button("Open Preferences") {
                    appState.openAppPreferences(app)
                }
            }
            Divider()
            Button("Generate Description") {
                Task {
                    await appState.updateSingleApp(app)
                }
            }
        }
    }
}

// MARK: - Progress Sheet

struct ProgressSheet: View {
    @EnvironmentObject var appState: AppState

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
        VStack(spacing: 20) {
            Text("Haetaan kuvauksia")
                .font(.headline)

            ProgressView()
                .scaleEffect(1.5)

            // Current status
            Text(appState.currentUpdateText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 40)

            // Timing display
            if appState.lastRequestDuration > 0 {
                HStack {
                    Text("Viimeisin pyyntö:")
                    Text(formatDuration(appState.lastRequestDuration))
                        .fontWeight(.bold)
                        .foregroundColor(durationColor(appState.lastRequestDuration))
                }
                .font(.caption)
            }

            // Generated text preview
            if !appState.lastGeneratedDescription.isEmpty {
                GroupBox {
                    Text(appState.lastGeneratedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                }
                .frame(maxWidth: 400)
            }

            Divider()

            Button("Sulje") {
                appState.showProgressSheet = false
            }
            .keyboardShortcut(.escape)
        }
        .padding(30)
        .frame(minWidth: 450, minHeight: 300)
    }
}
