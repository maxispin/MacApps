import SwiftUI

struct ToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Scan button
            Button(action: {
                Task {
                    await appState.scanApplications()
                }
            }) {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .help("Rescan applications (Cmd+R)")
            .disabled(appState.scanStatus == .scanning || appState.updateStatus != .idle)

            Divider()

            // Update all button
            Button(action: {
                appState.showBatchUpdateSheet = true
            }) {
                Label("Update All", systemImage: "sparkles")
            }
            .help("Update descriptions for all apps")
            .disabled(!appState.claudeAvailable || appState.scanStatus == .scanning || appState.updateStatus != .idle)
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
                    Text("Updating \(current)/\(total): \(name)")
                        .font(.caption)
                        .lineLimit(1)
                }
            case .completed(let updated, let skipped, let failed):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Done: \(updated) updated, \(skipped) skipped, \(failed) failed")
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
    @State private var selectedType: DescriptionType = .expanded
    @State private var onlyMissing = true
    @State private var isUpdating = false

    var appsToProcess: Int {
        onlyMissing ? appState.apps.filter { !$0.hasDescription }.count : appState.apps.count
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Update All Descriptions")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            // Options
            VStack(alignment: .leading, spacing: 16) {
                // Description type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description Type")
                        .font(.headline)

                    Picker(selection: $selectedType) {
                        ForEach(DescriptionType.allCases, id: \.self) { type in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(type.rawValue)
                                        .font(.body)
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .tag(type)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                Divider()

                // Scope
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scope")
                        .font(.headline)

                    Toggle("Only apps without description", isOn: $onlyMissing)

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("\(appsToProcess) apps will be processed")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)

            Divider()

            // Progress (when updating)
            if isUpdating {
                VStack(spacing: 8) {
                    if case .updating(let name, let current, let total) = appState.updateStatus {
                        ProgressView(value: Double(current), total: Double(total))
                        Text("Processing \(current)/\(total): \(name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)
            }

            // Buttons
            HStack {
                Button("Cancel") {
                    if isUpdating {
                        appState.cancelBatchUpdate()
                    }
                    appState.showBatchUpdateSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if !isUpdating {
                    Button("Start Update") {
                        isUpdating = true
                        Task {
                            await appState.updateAllDescriptions(onlyMissing: onlyMissing, type: selectedType)
                            isUpdating = false
                            appState.showBatchUpdateSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(appsToProcess == 0)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 450, height: isUpdating ? 420 : 380)
    }
}
