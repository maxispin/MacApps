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
    @Published var showBatchUpdateSheet = false

    // For real-time update display
    @Published var currentUpdateText: String = ""
    @Published var lastGeneratedDescription: String = ""

    private let scanner = AppScanner()
    private let claude = ClaudeService()
    private let writer = MetadataWriter()
    private let database = AppDatabase()
    private var shouldStopUpdate = false

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case withDescription = "With Description"
        case withoutDescription = "Without Description"
    }

    var filteredApps: [AppInfo] {
        var result = apps

        switch filterOption {
        case .all:
            break
        case .withDescription:
            result = result.filter { $0.hasDescription }
        case .withoutDescription:
            result = result.filter { !$0.hasDescription }
        }

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

    var isUpdating: Bool {
        if case .updating = updateStatus {
            return true
        }
        return false
    }

    var statistics: (total: Int, withDescription: Int, withoutDescription: Int) {
        let withDesc = apps.filter { $0.hasDescription }.count
        return (apps.count, withDesc, apps.count - withDesc)
    }

    var hasCachedData: Bool {
        database.hasCachedData()
    }

    // Fast startup: load data immediately, icons load on-demand via IconManager
    func loadFromCache() async {
        scanStatus = .scanning

        let cached = database.load()
        if !cached.isEmpty {
            // Load apps immediately WITHOUT icons (fast)
            // Icons are loaded on-demand by IconManager when rows appear
            let loadedApps: [AppInfo] = cached.map { stored in
                AppInfo(
                    name: stored.name,
                    path: stored.path,
                    bundleIdentifier: stored.bundleIdentifier,
                    finderComment: stored.finderComment,
                    icon: nil  // Icons loaded on-demand by IconManager
                )
            }.sorted { $0.name.lowercased() < $1.name.lowercased() }

            apps = loadedApps
            scanStatus = .completed(count: apps.count)
        } else {
            await scanApplications()
        }
    }

    func scanApplications() async {
        scanStatus = .scanning
        apps = []

        // Clear icon cache on rescan
        IconManager.shared.clearCache()

        // Get app list quickly (without icons)
        // Icons are loaded on-demand by IconManager when rows appear
        let scannedApps = await Task.detached(priority: .userInitiated) { [scanner] in
            return scanner.scanApplicationsWithoutIcons()
        }.value

        apps = scannedApps
        scanStatus = .completed(count: scannedApps.count)
        database.save(apps: apps)
    }

    func refreshApp(_ app: AppInfo) {
        if let index = apps.firstIndex(where: { $0.path == app.path }) {
            let newComment = scanner.getFinderComment(path: app.path)
            apps[index].finderComment = newComment
            if selectedApp?.path == app.path {
                selectedApp = apps[index]
            }
            if let comment = newComment {
                database.updateComment(for: app.path, comment: comment)
            }
        }
    }

    // Update single app with both short + expanded descriptions
    func updateSingleApp(_ app: AppInfo) async {
        currentUpdateText = "Generating description for \(app.name)..."

        let description = await generateCombinedDescription(for: app)

        if let desc = description {
            let success = writer.setFinderComment(path: app.path, comment: desc)
            if success {
                if let index = apps.firstIndex(where: { $0.path == app.path }) {
                    apps[index].finderComment = desc
                    if selectedApp?.path == app.path {
                        selectedApp = apps[index]
                    }
                    database.updateComment(for: app.path, comment: desc)
                }
                lastGeneratedDescription = desc
            }
        }

        currentUpdateText = ""
    }

    // Generate combined description (short + expanded)
    private func generateCombinedDescription(for app: AppInfo) async -> String? {
        let appName = app.name
        let bundleId = app.bundleIdentifier

        // Get short description
        currentUpdateText = "[\(appName)] Getting short description..."
        let shortDesc: String? = await Task.detached(priority: .userInitiated) { [claude] in
            return claude.getDescription(for: appName, bundleId: bundleId, type: .short)
        }.value

        guard let short = shortDesc else { return nil }
        lastGeneratedDescription = short

        // Get expanded description
        currentUpdateText = "[\(appName)] Getting detailed description..."
        let expandedDesc: String? = await Task.detached(priority: .userInitiated) { [claude] in
            return claude.getDescription(for: appName, bundleId: bundleId, type: .expanded)
        }.value

        guard let expanded = expandedDesc else { return short }

        // Combine: Short summary first, then detailed
        let combined = "\(short) | \(expanded)"
        lastGeneratedDescription = combined

        return combined
    }

    func updateAllDescriptions(onlyMissing: Bool) async {
        shouldStopUpdate = false
        let appsToUpdate = onlyMissing ? apps.filter { !$0.hasDescription } : apps
        let total = appsToUpdate.count

        if total == 0 {
            updateStatus = .completed(updated: 0, skipped: 0, failed: 0)
            return
        }

        var updated = 0
        let skipped = 0
        var failed = 0

        for (index, app) in appsToUpdate.enumerated() {
            if shouldStopUpdate {
                updateStatus = .completed(updated: updated, skipped: total - index, failed: failed)
                currentUpdateText = ""
                lastGeneratedDescription = ""
                return
            }

            updateStatus = .updating(appName: app.name, current: index + 1, total: total)
            currentUpdateText = "Processing \(app.name)..."

            let description = await generateCombinedDescription(for: app)

            if let desc = description {
                let success = writer.setFinderComment(path: app.path, comment: desc)
                if success {
                    if let appIndex = apps.firstIndex(where: { $0.path == app.path }) {
                        apps[appIndex].finderComment = desc
                    }
                    updated += 1
                } else {
                    failed += 1
                }
            } else {
                failed += 1
            }

            // Small delay between API calls
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        updateStatus = .completed(updated: updated, skipped: skipped, failed: failed)
        currentUpdateText = ""
        database.save(apps: apps)
    }

    func stopBatchUpdate() {
        shouldStopUpdate = true
        currentUpdateText = "Stopping..."
    }

    func resetUpdateStatus() {
        updateStatus = .idle
        currentUpdateText = ""
        lastGeneratedDescription = ""
    }

    func clearCache() {
        database.clear()
    }

    func openInFinder(_ app: AppInfo) {
        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "/Applications")
    }

    func launchApp(_ app: AppInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
    }
}
