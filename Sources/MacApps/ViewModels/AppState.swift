import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var searchText: String = ""
    @Published var scanStatus: ScanStatus = .idle
    @Published var updateStatus: UpdateStatus = .idle
    @Published var selectedApp: AppInfo?
    @Published var selectedDescriptionType: DescriptionType = .expanded
    @Published var filterOption: FilterOption = .all

    private let scanner = AppScanner()
    private let claude = ClaudeService()
    private let writer = MetadataWriter()

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case withDescription = "With Description"
        case withoutDescription = "Without Description"
    }

    var filteredApps: [AppInfo] {
        var result = apps

        // Apply filter
        switch filterOption {
        case .all:
            break
        case .withDescription:
            result = result.filter { $0.hasDescription }
        case .withoutDescription:
            result = result.filter { !$0.hasDescription }
        }

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { app in
                app.name.lowercased().contains(query) ||
                (app.finderComment?.lowercased().contains(query) ?? false) ||
                (app.bundleIdentifier?.lowercased().contains(query) ?? false)
            }
        }

        return result
    }

    var claudeAvailable: Bool {
        claude.isAvailable
    }

    var statistics: (total: Int, withDescription: Int, withoutDescription: Int) {
        let withDesc = apps.filter { $0.hasDescription }.count
        return (apps.count, withDesc, apps.count - withDesc)
    }

    func scanApplications() async {
        scanStatus = .scanning
        apps = []

        let scannedApps = await Task.detached(priority: .userInitiated) { [scanner] in
            return scanner.scanApplications()
        }.value

        apps = scannedApps
        scanStatus = .completed(count: scannedApps.count)
    }

    func refreshApp(_ app: AppInfo) {
        if let index = apps.firstIndex(where: { $0.path == app.path }) {
            let newComment = scanner.getFinderComment(path: app.path)
            apps[index].finderComment = newComment
            if selectedApp?.path == app.path {
                selectedApp = apps[index]
            }
        }
    }

    func updateDescription(for app: AppInfo, type: DescriptionType) async -> Bool {
        let appName = app.name
        let bundleId = app.bundleIdentifier
        let appPath = app.path

        let description: String? = await Task.detached(priority: .userInitiated) { [claude] in
            return claude.getDescription(for: appName, bundleId: bundleId, type: type)
        }.value

        guard let desc = description else {
            return false
        }

        let success = writer.setFinderComment(path: appPath, comment: desc)

        if success {
            if let index = apps.firstIndex(where: { $0.path == appPath }) {
                apps[index].finderComment = desc
                if selectedApp?.path == appPath {
                    selectedApp = apps[index]
                }
            }
        }

        return success
    }

    func updateAllDescriptions(onlyMissing: Bool) async {
        let appsToUpdate = onlyMissing ? apps.filter { !$0.hasDescription } : apps
        let total = appsToUpdate.count

        if total == 0 {
            updateStatus = .completed(updated: 0, skipped: 0, failed: 0)
            return
        }

        var updated = 0
        var skipped = 0
        var failed = 0

        for (index, app) in appsToUpdate.enumerated() {
            updateStatus = .updating(appName: app.name, current: index + 1, total: total)

            if !onlyMissing || !app.hasDescription {
                let success = await updateDescription(for: app, type: selectedDescriptionType)
                if success {
                    updated += 1
                } else {
                    failed += 1
                }
                // Small delay between API calls
                try? await Task.sleep(nanoseconds: 500_000_000)
            } else {
                skipped += 1
            }
        }

        updateStatus = .completed(updated: updated, skipped: skipped, failed: failed)
    }

    func openInFinder(_ app: AppInfo) {
        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "/Applications")
    }

    func launchApp(_ app: AppInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
    }
}
