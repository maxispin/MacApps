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
                // Search in name
                app.name.lowercased().contains(query) ||
                // Search in bundle ID
                (app.bundleIdentifier?.lowercased().contains(query) ?? false) ||
                // Search in ALL language descriptions
                app.allDescriptionsText.lowercased().contains(query)
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

    // Fast startup: load data immediately, then preload all icons in parallel
    func loadFromCache() async {
        scanStatus = .scanning

        let cached = database.load()
        if !cached.isEmpty {
            // Load apps immediately WITHOUT icons (fast)
            let loadedApps: [AppInfo] = cached.map { stored in
                AppInfo(
                    name: stored.name,
                    path: stored.path,
                    bundleIdentifier: stored.bundleIdentifier,
                    finderComment: stored.finderComment,
                    icon: nil,
                    isMenuBarApp: stored.isMenuBarApp ?? false,
                    descriptions: stored.descriptions
                )
            }.sorted { $0.name.lowercased() < $1.name.lowercased() }

            apps = loadedApps
            scanStatus = .completed(count: apps.count)

            // Preload all icons in parallel batches (non-blocking)
            IconManager.shared.preloadAllIcons(for: apps.map { $0.path })
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
        let scannedApps = await Task.detached(priority: .userInitiated) { [scanner] in
            return scanner.scanApplicationsWithoutIcons()
        }.value

        apps = scannedApps
        scanStatus = .completed(count: scannedApps.count)
        database.save(apps: apps)

        // Preload all icons in parallel batches (non-blocking)
        IconManager.shared.preloadAllIcons(for: apps.map { $0.path })
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

    // Update single app with descriptions for all target languages
    func updateSingleApp(_ app: AppInfo) async {
        currentUpdateText = "Generating descriptions for \(app.name)..."

        let result = await generateMultiLanguageDescriptions(for: app)

        if let index = apps.firstIndex(where: { $0.path == app.path }) {
            // Update descriptions in memory
            apps[index].descriptions = result.descriptions

            // Write primary description to Finder comment
            if let finderComment = result.finderComment {
                let success = writer.setFinderComment(path: app.path, comment: finderComment)
                if success {
                    apps[index].finderComment = finderComment
                    database.updateComment(for: app.path, comment: finderComment)
                }
                lastGeneratedDescription = finderComment
            }

            if selectedApp?.path == app.path {
                selectedApp = apps[index]
            }
        }

        currentUpdateText = ""
    }

    // Generate descriptions for all target languages
    private func generateMultiLanguageDescriptions(for app: AppInfo) async -> (finderComment: String?, descriptions: [AppDatabase.LocalizedDescription]) {
        let appName = app.name
        let bundleId = app.bundleIdentifier
        let missingLanguages = app.missingLanguages

        var allDescriptions = app.descriptions ?? []
        var primaryDescription: String? = nil

        for language in missingLanguages {
            let langName = language == "en" ? "English" : (language == "fi" ? "Finnish" : language.uppercased())

            // Get short description
            currentUpdateText = "[\(appName)] Getting \(langName) short description..."
            let shortDesc: String? = await Task.detached(priority: .userInitiated) { [claude] in
                return claude.getDescription(for: appName, bundleId: bundleId, type: .short, language: language)
            }.value

            guard let short = shortDesc else { continue }
            lastGeneratedDescription = "[\(langName)] \(short)"

            // Get expanded description
            currentUpdateText = "[\(appName)] Getting \(langName) detailed description..."
            let expandedDesc: String? = await Task.detached(priority: .userInitiated) { [claude] in
                return claude.getDescription(for: appName, bundleId: bundleId, type: .expanded, language: language)
            }.value

            let expanded = expandedDesc

            // Store this language's description
            let localizedDesc = AppDatabase.LocalizedDescription(
                language: language,
                shortDescription: short,
                expandedDescription: expanded,
                fetchedAt: Date()
            )
            allDescriptions.removeAll { $0.language == language }
            allDescriptions.append(localizedDesc)

            // Save to database immediately
            database.updateDescription(for: app.path, language: language, short: short, expanded: expanded)

            // Use system language (or English if system) for Finder comment
            let systemLang = AppDatabase.systemLanguage
            if language == systemLang || (language == "en" && primaryDescription == nil) {
                if let exp = expanded {
                    primaryDescription = "\(short) | \(exp)"
                } else {
                    primaryDescription = short
                }
                lastGeneratedDescription = primaryDescription ?? short
            }

            // Small delay between languages
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return (primaryDescription, allDescriptions)
    }

    // Legacy method for backwards compatibility
    private func generateCombinedDescription(for app: AppInfo) async -> String? {
        let result = await generateMultiLanguageDescriptions(for: app)
        return result.finderComment
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
        let url = URL(fileURLWithPath: app.path)

        if app.isMenuBarApp {
            // For menu bar apps, use special launch configuration
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.hides = false

            NSWorkspace.shared.openApplication(at: url, configuration: config) { runningApp, error in
                if let runningApp = runningApp {
                    // Try to activate the app and bring any windows to front
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        runningApp.activate()
                    }
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open preferences/settings window for menu bar apps
    func openAppPreferences(_ app: AppInfo) {
        guard let bundleId = app.bundleIdentifier else { return }

        // First launch/activate the app
        let url = URL(fileURLWithPath: app.path)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: config) { runningApp, error in
            guard let runningApp = runningApp else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Activate the app
                runningApp.activate()

                // Try to open preferences via AppleScript
                let script = """
                tell application id "\(bundleId)"
                    activate
                    try
                        tell application "System Events"
                            tell process "\(app.name)"
                                click menu item "Settings…" of menu "\(app.name)" of menu bar 1
                            end tell
                        end tell
                    end try
                end tell
                """

                var errorDict: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&errorDict)
                }
            }
        }
    }
}
