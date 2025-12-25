import Foundation

class AppDatabase {
    private let fileManager = FileManager.default
    private var databaseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MacApps", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("apps.json")
    }

    /// Description stored for a specific language
    struct LocalizedDescription: Codable, Equatable {
        let language: String  // e.g., "fi", "en", "sv"
        let shortDescription: String?
        let expandedDescription: String?
        var fetchedAt: Date

        static func == (lhs: LocalizedDescription, rhs: LocalizedDescription) -> Bool {
            lhs.language == rhs.language &&
            lhs.shortDescription == rhs.shortDescription &&
            lhs.expandedDescription == rhs.expandedDescription
        }
    }

    struct StoredApp: Codable {
        let path: String
        let name: String
        let bundleIdentifier: String?
        var finderComment: String?  // Keep for backwards compatibility (written to Finder)
        var originalFinderComment: String?  // Original comment before MacApps modified it
        var lastScanned: Date
        var isMenuBarApp: Bool?
        var source: AppSource?  // Where the app was found
        var categories: [AppCategory]?  // AI-generated categories (usually 1, max 2-3)
        var functions: [String]?  // Action verbs: "edit images", "send messages", etc.

        // Multi-language descriptions
        var descriptions: [LocalizedDescription]?

        /// Get all descriptions combined for search
        var allDescriptionsText: String {
            guard let descriptions = descriptions else { return finderComment ?? "" }
            let texts = descriptions.compactMap { desc -> String? in
                var parts: [String] = []
                if let short = desc.shortDescription { parts.append(short) }
                if let expanded = desc.expandedDescription { parts.append(expanded) }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }
            return texts.joined(separator: " ")
        }

        /// Check if a specific language has been fetched
        func hasDescription(for language: String) -> Bool {
            descriptions?.contains { $0.language == language } ?? false
        }

        /// Get description for a specific language
        func description(for language: String) -> LocalizedDescription? {
            descriptions?.first { $0.language == language }
        }
    }

    /// Get system language code (e.g., "fi", "en")
    static var systemLanguage: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        // Extract just the language code (e.g., "fi" from "fi-FI")
        return String(preferred.prefix(2))
    }

    /// Languages to fetch descriptions for
    static var targetLanguages: [String] {
        let system = systemLanguage
        if system == "en" {
            return ["en"]
        } else {
            return [system, "en"]
        }
    }

    func save(apps: [AppInfo]) {
        // Load existing to preserve descriptions and original comments
        let existing = load()
        let existingByPath = Dictionary(uniqueKeysWithValues: existing.map { ($0.path, $0) })

        let storedApps = apps.map { app in
            // Preserve existing data
            let existingApp = existingByPath[app.path]
            let existingDescriptions = existingApp?.descriptions

            // Preserve original comment - only set on first scan (before we modify it)
            // If app is new (not in existing) and has a finderComment, that's the original
            let originalComment: String?
            if let existing = existingApp {
                // Keep existing original
                originalComment = existing.originalFinderComment
            } else {
                // New app - save current comment as original (if any)
                originalComment = app.finderComment
            }

            // Preserve existing categories and functions if not overwritten
            let categories = app.categories.isEmpty ? existingApp?.categories : app.categories
            let functions = app.functions.isEmpty ? existingApp?.functions : app.functions

            return StoredApp(
                path: app.path,
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                finderComment: app.finderComment,
                originalFinderComment: originalComment,
                lastScanned: Date(),
                isMenuBarApp: app.isMenuBarApp,
                source: app.source,
                categories: categories,
                functions: functions,
                descriptions: app.descriptions ?? existingDescriptions
            )
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(storedApps)
            try data.write(to: databaseURL)
        } catch {
            print("Failed to save database: \(error)")
        }
    }

    func load() -> [StoredApp] {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: databaseURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([StoredApp].self, from: data)
        } catch {
            print("Failed to load database: \(error)")
            return []
        }
    }

    func getStoredComment(for path: String) -> String? {
        let stored = load()
        return stored.first { $0.path == path }?.finderComment
    }

    func updateComment(for path: String, comment: String) {
        var stored = load()
        if let index = stored.firstIndex(where: { $0.path == path }) {
            stored[index].finderComment = comment
            stored[index].lastScanned = Date()

            saveStored(stored)
        }
    }

    /// Update categories for an app
    func updateCategories(for path: String, categories: [AppCategory]) {
        var stored = load()
        if let index = stored.firstIndex(where: { $0.path == path }) {
            stored[index].categories = categories
            stored[index].lastScanned = Date()
            saveStored(stored)
        }
    }

    /// Add a category to an app (if not already present)
    func addCategory(for path: String, category: AppCategory) {
        var stored = load()
        if let index = stored.firstIndex(where: { $0.path == path }) {
            var categories = stored[index].categories ?? []
            if !categories.contains(category) {
                categories.append(category)
                stored[index].categories = categories
                stored[index].lastScanned = Date()
                saveStored(stored)
            }
        }
    }

    /// Update functions for an app
    func updateFunctions(for path: String, functions: [String]) {
        var stored = load()
        if let index = stored.firstIndex(where: { $0.path == path }) {
            stored[index].functions = functions
            stored[index].lastScanned = Date()
            saveStored(stored)
        }
    }

    /// Add functions to an app (merges with existing, no duplicates)
    func addFunctions(for path: String, newFunctions: [String]) {
        var stored = load()
        if let index = stored.firstIndex(where: { $0.path == path }) {
            var functions = stored[index].functions ?? []
            for fn in newFunctions {
                let normalized = fn.lowercased().trimmingCharacters(in: .whitespaces)
                if !functions.contains(where: { $0.lowercased() == normalized }) {
                    functions.append(fn)
                }
            }
            stored[index].functions = functions
            stored[index].lastScanned = Date()
            saveStored(stored)
        }
    }

    /// Add or update description for a specific language
    func updateDescription(for path: String, language: String, short: String?, expanded: String?) {
        var stored = load()
        guard let index = stored.firstIndex(where: { $0.path == path }) else { return }

        let newDesc = LocalizedDescription(
            language: language,
            shortDescription: short,
            expandedDescription: expanded,
            fetchedAt: Date()
        )

        var descriptions = stored[index].descriptions ?? []

        // Remove existing for this language and add new
        descriptions.removeAll { $0.language == language }
        descriptions.append(newDesc)

        stored[index].descriptions = descriptions
        stored[index].lastScanned = Date()

        saveStored(stored)
    }

    /// Check which languages are missing for an app
    func missingLanguages(for path: String) -> [String] {
        let stored = load()
        guard let app = stored.first(where: { $0.path == path }) else {
            return Self.targetLanguages
        }

        return Self.targetLanguages.filter { !app.hasDescription(for: $0) }
    }

    /// Get all descriptions for search
    func getAllDescriptionsText(for path: String) -> String {
        let stored = load()
        return stored.first { $0.path == path }?.allDescriptionsText ?? ""
    }

    private func saveStored(_ stored: [StoredApp]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(stored)
            try data.write(to: databaseURL)
        } catch {
            print("Failed to update database: \(error)")
        }
    }

    func hasCachedData() -> Bool {
        return fileManager.fileExists(atPath: databaseURL.path)
    }

    func clear() {
        try? fileManager.removeItem(at: databaseURL)
    }
}
