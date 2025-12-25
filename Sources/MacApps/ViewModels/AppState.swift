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
    @Published var sourceFilter: SourceFilter = .all
    @Published var categoryFilter: CategoryFilter = .all
    @Published var functionFilter: String? = nil  // Filter by specific function
    @Published var showBatchUpdateSheet = false
    @Published var showProgressSheet = false  // Show progress for single app too

    // For real-time update display
    @Published var currentUpdateText: String = ""
    @Published var lastGeneratedDescription: String = ""
    @Published var lastRequestDuration: Int = 0  // milliseconds

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

    enum SourceFilter: Hashable, CaseIterable {
        case all
        case hideSetapp
        case onlySetapp
        case source(AppSource)

        static var allCases: [SourceFilter] {
            return [.all, .hideSetapp, .onlySetapp]
        }

        var displayName: String {
            switch self {
            case .all: return "All Sources"
            case .hideSetapp: return "Hide Setapp"
            case .onlySetapp: return "Only Setapp"
            case .source(let s): return s.rawValue
            }
        }
    }

    enum CategoryFilter: Hashable {
        case all
        case category(AppCategory)
        case uncategorized

        var displayName: String {
            switch self {
            case .all: return "All Categories"
            case .category(let c): return c.rawValue
            case .uncategorized: return "Uncategorized"
            }
        }
    }

    var filteredApps: [AppInfo] {
        var result = apps

        // Apply source filter first
        switch sourceFilter {
        case .all:
            break
        case .hideSetapp:
            result = result.filter { $0.source != .setapp }
        case .onlySetapp:
            result = result.filter { $0.source == .setapp }
        case .source(let source):
            result = result.filter { $0.source == source }
        }

        // Apply category filter
        switch categoryFilter {
        case .all:
            break
        case .category(let category):
            result = result.filter { $0.hasCategory(category) }
        case .uncategorized:
            result = result.filter { $0.categories.isEmpty }
        }

        // Apply description filter
        switch filterOption {
        case .all:
            break
        case .withDescription:
            result = result.filter { $0.hasDescription }
        case .withoutDescription:
            result = result.filter { !$0.hasDescription }
        }

        // Apply function filter
        if let fn = functionFilter {
            result = result.filter { $0.functions.contains { $0.lowercased() == fn.lowercased() } }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { app in
                // Search in name
                app.name.lowercased().contains(query) ||
                // Search in bundle ID
                (app.bundleIdentifier?.lowercased().contains(query) ?? false) ||
                // Search in ALL language descriptions
                app.allDescriptionsText.lowercased().contains(query) ||
                // Search in any category
                app.categories.contains { $0.rawValue.lowercased().contains(query) } ||
                // Search in functions
                app.functions.contains { $0.lowercased().contains(query) }
            }
        }

        return result
    }

    /// Get count of apps per source
    var sourceCounts: [AppSource: Int] {
        var counts: [AppSource: Int] = [:]
        for source in AppSource.allCases {
            counts[source] = apps.filter { $0.source == source }.count
        }
        return counts
    }

    /// Get count of apps per category (apps can be in multiple categories)
    var categoryCounts: [AppCategory: Int] {
        var counts: [AppCategory: Int] = [:]
        for category in AppCategory.allCases {
            counts[category] = apps.filter { $0.hasCategory(category) }.count
        }
        return counts
    }

    /// Categories that have apps
    var availableCategories: [AppCategory] {
        AppCategory.allCases.filter { category in
            apps.contains { $0.hasCategory(category) }
        }
    }

    /// Count of uncategorized apps
    var uncategorizedCount: Int {
        apps.filter { $0.categories.isEmpty }.count
    }

    /// All unique functions with counts, sorted by count
    var functionCounts: [(function: String, count: Int)] {
        var counts: [String: Int] = [:]
        for app in apps {
            for fn in app.functions {
                let key = fn.lowercased()
                counts[key, default: 0] += 1
            }
        }
        return counts.map { (function: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
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
                    originalFinderComment: stored.originalFinderComment,
                    icon: nil,
                    isMenuBarApp: stored.isMenuBarApp ?? false,
                    source: stored.source ?? .applications,
                    categories: stored.categories ?? [],
                    functions: stored.functions ?? [],
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

    /// Force regenerate all data for an app (clears existing first)
    func regenerateApp(_ app: AppInfo) async {
        showProgressSheet = true
        currentUpdateText = "Regenerating \(app.name)..."
        lastRequestDuration = 0

        guard let index = apps.firstIndex(where: { $0.path == app.path }) else {
            showProgressSheet = false
            return
        }

        // Clear existing data
        apps[index].descriptions = nil
        apps[index].categories = []
        apps[index].functions = []

        // Generate fresh descriptions
        currentUpdateText = "[\(app.name)] Descriptions..."
        let result = await generateMultiLanguageDescriptions(for: apps[index])
        apps[index].descriptions = result.descriptions

        if let finderComment = result.finderComment {
            let success = writer.setFinderComment(path: app.path, comment: finderComment)
            if success {
                apps[index].finderComment = finderComment
                database.updateComment(for: app.path, comment: finderComment)
            }
            writer.indexForSpotlight(
                path: app.path,
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                description: finderComment
            )
        }

        // Generate fresh category
        currentUpdateText = "[\(app.name)] Category..."
        let categoryResult = await Task.detached(priority: .userInitiated) { [claude] in
            return claude.getCategoryWithTiming(for: app.name, bundleId: app.bundleIdentifier)
        }.value

        if let category = categoryResult.category {
            apps[index].categories = [category]
            database.updateCategories(for: app.path, categories: [category])
            currentUpdateText = "[\(app.name)] Category: \(category.rawValue) ✓"
        }

        // Generate fresh functions
        currentUpdateText = "[\(app.name)] Functions..."
        let functionsResult = await Task.detached(priority: .userInitiated) { [claude] in
            return claude.getFunctionsWithTiming(for: app.name, bundleId: app.bundleIdentifier, language: AppDatabase.systemLanguage)
        }.value

        if !functionsResult.functions.isEmpty {
            apps[index].functions = functionsResult.functions
            database.updateFunctions(for: app.path, functions: functionsResult.functions)
            currentUpdateText = "[\(app.name)] \(functionsResult.functions.count) functions ✓"
        }

        if selectedApp?.path == app.path {
            selectedApp = apps[index]
        }

        currentUpdateText = "Done!"
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        showProgressSheet = false
        currentUpdateText = ""
    }

    // Update single app with descriptions for all target languages
    func updateSingleApp(_ app: AppInfo) async {
        showProgressSheet = true
        currentUpdateText = "Aloitetaan \(app.name)..."
        lastRequestDuration = 0

        // Get LATEST version from apps array (with current descriptions from database)
        let currentApp: AppInfo
        if let index = apps.firstIndex(where: { $0.path == app.path }) {
            currentApp = apps[index]
        } else {
            currentApp = app
        }

        let result = await generateMultiLanguageDescriptions(for: currentApp)

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

                // Index for Spotlight - searchable without prefixes!
                writer.indexForSpotlight(
                    path: app.path,
                    name: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    description: finderComment
                )
            }

            // Fetch category if missing
            if apps[index].categories.isEmpty {
                currentUpdateText = "[\(app.name)] Kategoria..."
                let categoryResult = await Task.detached(priority: .userInitiated) { [claude] in
                    return claude.getCategoryWithTiming(for: app.name, bundleId: app.bundleIdentifier)
                }.value

                if let category = categoryResult.category {
                    apps[index].categories = [category]
                    database.updateCategories(for: app.path, categories: [category])
                    currentUpdateText = "[\(app.name)] Kategoria: \(category.rawValue) ✓"
                    lastRequestDuration = categoryResult.durationMs
                }
            }

            // Fetch functions if missing
            if apps[index].functions.isEmpty {
                currentUpdateText = "[\(app.name)] Toiminnot..."
                let functionsResult = await Task.detached(priority: .userInitiated) { [claude] in
                    return claude.getFunctionsWithTiming(for: app.name, bundleId: app.bundleIdentifier, language: AppDatabase.systemLanguage)
                }.value

                if !functionsResult.functions.isEmpty {
                    apps[index].functions = functionsResult.functions
                    database.updateFunctions(for: app.path, functions: functionsResult.functions)
                    currentUpdateText = "[\(app.name)] \(functionsResult.functions.count) toimintoa ✓"
                    lastRequestDuration = functionsResult.durationMs
                }
            }

            if selectedApp?.path == app.path {
                selectedApp = apps[index]
            }
        }

        currentUpdateText = "Valmis!"

        // Auto-close after 1 second
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        showProgressSheet = false
        currentUpdateText = ""
    }

    // Generate descriptions for all target languages (only missing ones)
    private func generateMultiLanguageDescriptions(for app: AppInfo) async -> (finderComment: String?, descriptions: [AppDatabase.LocalizedDescription]) {
        let appName = app.name
        let bundleId = app.bundleIdentifier
        let targetLanguages = AppDatabase.targetLanguages

        var allDescriptions = app.descriptions ?? []
        var primaryDescription: String? = nil
        var fetchedAnything = false

        for language in targetLanguages {
            let langName = language == "en" ? "English" : (language == "fi" ? "Suomi" : language.uppercased())
            let missing = app.missingTypes(for: language)

            // Skip if both already exist
            if !missing.needsShort && !missing.needsExpanded {
                currentUpdateText = "[\(appName)] \(langName) ✓ jo haettu"
                try? await Task.sleep(nanoseconds: 300_000_000)
                continue
            }

            // Get existing description for this language (to preserve what we have)
            let existingDesc = allDescriptions.first { $0.language == language }
            var short = existingDesc?.shortDescription
            var expanded = existingDesc?.expandedDescription

            // Fetch short if missing
            if missing.needsShort {
                currentUpdateText = "[\(appName)] \(langName) lyhyt..."
                let shortResult = await Task.detached(priority: .userInitiated) { [claude] in
                    return claude.getDescriptionWithTiming(for: appName, bundleId: bundleId, type: .short, language: language)
                }.value

                lastRequestDuration = shortResult.durationMs
                if let text = shortResult.text {
                    short = text
                    lastGeneratedDescription = "[\(langName)] \(text)"
                    currentUpdateText = "[\(appName)] \(langName) lyhyt ✓ \(shortResult.durationMs)ms"
                    fetchedAnything = true
                }
            } else {
                currentUpdateText = "[\(appName)] \(langName) lyhyt ✓ (jo haettu)"
            }

            // Fetch expanded if missing
            if missing.needsExpanded {
                currentUpdateText = "[\(appName)] \(langName) pitkä..."
                let expandedResult = await Task.detached(priority: .userInitiated) { [claude] in
                    return claude.getDescriptionWithTiming(for: appName, bundleId: bundleId, type: .expanded, language: language)
                }.value

                lastRequestDuration = expandedResult.durationMs
                if let text = expandedResult.text {
                    expanded = text
                    currentUpdateText = "[\(appName)] \(langName) pitkä ✓ \(expandedResult.durationMs)ms"
                    fetchedAnything = true
                }
            } else {
                currentUpdateText = "[\(appName)] \(langName) pitkä ✓ (jo haettu)"
            }

            // Update stored description if we have anything
            if short != nil || expanded != nil {
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
            }

            // Use SYSTEM LANGUAGE for Finder comment (255 char limit)
            let systemLang = AppDatabase.systemLanguage
            if language == systemLang, let s = short {
                if let exp = expanded {
                    let combined = "\(s) | \(exp)"
                    primaryDescription = String(combined.prefix(255))
                } else {
                    primaryDescription = String(s.prefix(255))
                }
                lastGeneratedDescription = primaryDescription ?? s
            }

            // Small delay between languages
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        if !fetchedAnything {
            currentUpdateText = "Kaikki kuvaukset jo haettu!"
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
        // Use hasAllLanguages to check for COMPLETE descriptions (all languages, both short AND expanded)
        let appsToUpdate = onlyMissing ? apps.filter { !$0.hasAllLanguages } : apps
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
                    // Index for Spotlight
                    writer.indexForSpotlight(
                        path: app.path,
                        name: app.name,
                        bundleIdentifier: app.bundleIdentifier,
                        description: desc
                    )
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
        writer.clearSpotlightIndex()
    }

    /// Categorize all uncategorized apps
    /// If app has no description, fetches description too
    func categorizeAllApps() async {
        let uncategorized = apps.filter { $0.categories.isEmpty }
        let total = uncategorized.count

        if total == 0 {
            currentUpdateText = "All apps already categorized!"
            showProgressSheet = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showProgressSheet = false
            currentUpdateText = ""
            return
        }

        showProgressSheet = true
        var categorized = 0
        var described = 0

        for (index, app) in uncategorized.enumerated() {
            guard let appIndex = apps.firstIndex(where: { $0.path == app.path }) else { continue }

            // If app has no description, fetch descriptions first
            if !app.hasAllLanguages {
                currentUpdateText = "[\(app.name)] Fetching descriptions... (\(index + 1)/\(total))"

                let result = await generateMultiLanguageDescriptions(for: app)

                // Update descriptions in memory
                apps[appIndex].descriptions = result.descriptions

                // Write primary description to Finder comment
                if let finderComment = result.finderComment {
                    let success = writer.setFinderComment(path: app.path, comment: finderComment)
                    if success {
                        apps[appIndex].finderComment = finderComment
                        database.updateComment(for: app.path, comment: finderComment)
                        described += 1
                    }
                    lastGeneratedDescription = finderComment

                    // Index for Spotlight
                    writer.indexForSpotlight(
                        path: app.path,
                        name: app.name,
                        bundleIdentifier: app.bundleIdentifier,
                        description: finderComment
                    )
                }
            }

            // Fetch category
            currentUpdateText = "[\(app.name)] Categorizing... (\(index + 1)/\(total))"

            let categoryResult = await Task.detached(priority: .userInitiated) { [claude] in
                return claude.getCategoryWithTiming(for: app.name, bundleId: app.bundleIdentifier)
            }.value

            if let category = categoryResult.category {
                apps[appIndex].categories = [category]
                database.updateCategories(for: app.path, categories: [category])
                lastGeneratedDescription = "\(app.name): \(category.rawValue)"
                lastRequestDuration = categoryResult.durationMs
                categorized += 1
            }

            // Fetch functions if missing
            if apps[appIndex].functions.isEmpty {
                currentUpdateText = "[\(app.name)] Functions... (\(index + 1)/\(total))"

                let functionsResult = await Task.detached(priority: .userInitiated) { [claude] in
                    return claude.getFunctionsWithTiming(for: app.name, bundleId: app.bundleIdentifier, language: AppDatabase.systemLanguage)
                }.value

                if !functionsResult.functions.isEmpty {
                    apps[appIndex].functions = functionsResult.functions
                    database.updateFunctions(for: app.path, functions: functionsResult.functions)
                    lastRequestDuration = functionsResult.durationMs
                }
            }

            // Update selected app if it's the one being processed
            if selectedApp?.path == app.path {
                selectedApp = apps[appIndex]
            }

            // Small delay between API calls
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        if described > 0 {
            currentUpdateText = "Done! Categorized \(categorized), described \(described) apps."
        } else {
            currentUpdateText = "Done! Categorized \(categorized) apps."
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        showProgressSheet = false
        currentUpdateText = ""
        lastGeneratedDescription = ""
        database.save(apps: apps)
    }

    /// Reindex all apps with descriptions to Spotlight
    func reindexSpotlight() async {
        let appsWithDescriptions = apps.filter { $0.hasDescription }
        let total = appsWithDescriptions.count

        if total == 0 {
            currentUpdateText = "No apps to index"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            currentUpdateText = ""
            return
        }

        showProgressSheet = true
        var indexedCount = 0

        for app in appsWithDescriptions {
            if let description = app.displayDescription {
                currentUpdateText = "Indexing \(app.name)... (\(indexedCount + 1)/\(total))"

                writer.indexForSpotlight(
                    path: app.path,
                    name: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    description: description
                )
                indexedCount += 1
            }
        }

        currentUpdateText = "Indexed \(indexedCount) apps for Spotlight!"
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        showProgressSheet = false
        currentUpdateText = ""
    }

    func openInFinder(_ app: AppInfo) {
        // Get the parent directory of the app
        let parentPath = (app.path as NSString).deletingLastPathComponent
        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: parentPath)
    }

    func launchApp(_ app: AppInfo) {
        let url = URL(fileURLWithPath: app.path)

        if app.isMenuBarApp {
            // For menu bar apps, launch and try to show UI
            launchMenuBarApp(app)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Launch menu bar app and try to trigger its UI
    private func launchMenuBarApp(_ app: AppInfo) {
        let url = URL(fileURLWithPath: app.path)

        // First, check if already running
        let runningApps = NSWorkspace.shared.runningApplications
        if let running = runningApps.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            // Already running - try to activate
            running.activate()

            // Try clicking its menu bar icon via AppleScript
            clickMenuBarIcon(for: app)
            return
        }

        // Launch the app
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] runningApp, error in
            guard runningApp != nil else { return }

            // Wait for app to initialize, then try to click menu bar icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.clickMenuBarIcon(for: app)
            }
        }
    }

    /// Try to click the app's menu bar icon
    private func clickMenuBarIcon(for app: AppInfo) {
        // AppleScript to click the menu bar icon
        let script = """
        tell application "System Events"
            tell process "\(app.name)"
                try
                    -- Try to click menu bar item (status item)
                    if exists menu bar 2 then
                        click menu bar item 1 of menu bar 2
                    end if
                end try
            end tell
        end tell
        """

        var errorDict: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&errorDict)
        }
    }

    /// Open preferences/settings window for menu bar apps
    func openAppPreferences(_ app: AppInfo) {
        // First make sure app is running
        launchMenuBarApp(app)

        // Then try Cmd+, shortcut after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let bundleId = app.bundleIdentifier else { return }

            let script = """
            tell application id "\(bundleId)"
                activate
            end tell
            delay 0.3
            tell application "System Events"
                keystroke "," using command down
            end tell
            """

            var errorDict: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&errorDict)
            }
        }
    }
}
