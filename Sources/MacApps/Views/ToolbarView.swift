import SwiftUI

struct ToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {
                Task {
                    await appState.scanApplications()
                }
            }) {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .help("Rescan applications (Cmd+R)")
            .disabled(appState.scanStatus == .scanning || appState.isUpdating)

            Divider()

            Button(action: {
                appState.showBatchUpdateSheet = true
            }) {
                Label("Update All", systemImage: "sparkles")
            }
            .help("Generate descriptions for all apps")
            .disabled(!appState.claudeAvailable || appState.scanStatus == .scanning || appState.isUpdating)
        }

        ToolbarItem(placement: .status) {
            StatusView()
        }
    }
}

struct StatusView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.updateStatus {
            case .idle:
                EmptyView()
            case .updating(let name, let current, let total):
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("\(current)/\(total): \(name)")
                        .font(.caption)
                        .lineLimit(1)
                }
            case .completed(let updated, _, let failed):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Done: \(updated) updated, \(failed) failed")
                        .font(.caption)
                }
            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                }
            }
        }
    }
}

struct BatchUpdateSheet: View {
    @EnvironmentObject var appState: AppState
    @State private var onlyMissing = true

    var appsToProcess: Int {
        onlyMissing ? appState.apps.filter { !$0.hasDescription }.count : appState.apps.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                Text("Update All Descriptions")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Generates both short and detailed descriptions for better searchability")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            if appState.isUpdating {
                // Progress view
                UpdateProgressView()
                    .frame(maxHeight: .infinity)
            } else if case .completed = appState.updateStatus {
                // Completed view
                UpdateProgressView()
                    .frame(maxHeight: .infinity)
            } else {
                // Options view
                VStack(alignment: .leading, spacing: 16) {
                    Text("Options")
                        .font(.headline)

                    Toggle("Only apps without description", isOn: $onlyMissing)

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("\(appsToProcess) apps will be processed")
                    }
                    .font(.callout)

                    Spacer()
                }
                .padding(24)
            }

            Divider()

            // Buttons
            HStack {
                Button(appState.isUpdating ? "Stop" : "Cancel") {
                    if appState.isUpdating {
                        appState.stopBatchUpdate()
                    } else {
                        appState.showBatchUpdateSheet = false
                        appState.resetUpdateStatus()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if !appState.isUpdating {
                    if case .completed = appState.updateStatus {
                        Button("Close") {
                            appState.showBatchUpdateSheet = false
                            appState.resetUpdateStatus()
                        }
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Start Update") {
                            Task {
                                await appState.updateAllDescriptions(onlyMissing: onlyMissing)
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(appsToProcess == 0)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 500, height: 400)
    }
}

struct UpdateProgressView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            switch appState.updateStatus {
            case .updating(let name, let current, let total):
                VStack(spacing: 16) {
                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: Double(current) / Double(total))
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: current)

                        VStack(spacing: 2) {
                            Text("\(current)")
                                .font(.system(size: 32, weight: .bold))
                            Text("of \(total)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 100, height: 100)

                    // Current app name
                    Text(name)
                        .font(.headline)

                    // Status text
                    Text(appState.currentUpdateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Last generated description
                    if !appState.lastGeneratedDescription.isEmpty {
                        GroupBox {
                            ScrollView {
                                Text(appState.lastGeneratedDescription)
                                    .font(.system(.caption, design: .rounded))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(height: 80)
                        .padding(.horizontal)
                    }
                }
                .padding()

            case .completed(let updated, let skipped, let failed):
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("Update Complete!")
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 30) {
                        VStack {
                            Text("\(updated)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Updated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if skipped > 0 {
                            VStack {
                                Text("\(skipped)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                Text("Skipped")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if failed > 0 {
                            VStack {
                                Text("\(failed)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                Text("Failed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

            case .idle:
                EmptyView()
            }
        }
    }
}
