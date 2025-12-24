import SwiftUI

struct ToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @State private var showUpdateSheet = false
    @State private var showUpdateProgress = false

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
            .disabled(appState.scanStatus == .scanning)

            Divider()

            // Update all button
            Button(action: {
                showUpdateSheet = true
            }) {
                Label("Update All", systemImage: "sparkles")
            }
            .help("Update descriptions for all apps")
            .disabled(!appState.claudeAvailable || appState.scanStatus == .scanning)
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

struct UpdateOptionsSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var onlyMissing = true
    @State private var isUpdating = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Update Descriptions")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Picker("Description Type", selection: $appState.selectedDescriptionType) {
                    ForEach(DescriptionType.allCases, id: \.self) { type in
                        VStack(alignment: .leading) {
                            Text(type.rawValue)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.radioGroup)

                Toggle("Only apps without description", isOn: $onlyMissing)

                let count = onlyMissing ?
                    appState.apps.filter { !$0.hasDescription }.count :
                    appState.apps.count

                Text("\(count) apps will be processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Start") {
                    isUpdating = true
                    Task {
                        await appState.updateAllDescriptions(onlyMissing: onlyMissing)
                        isUpdating = false
                        isPresented = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isUpdating)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
