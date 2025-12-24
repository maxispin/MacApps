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

    struct StoredApp: Codable {
        let path: String
        let name: String
        let bundleIdentifier: String?
        var finderComment: String?
        var lastScanned: Date
        var isMenuBarApp: Bool?  // Optional for backwards compatibility
    }

    func save(apps: [AppInfo]) {
        let storedApps = apps.map { app in
            StoredApp(
                path: app.path,
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                finderComment: app.finderComment,
                lastScanned: Date(),
                isMenuBarApp: app.isMenuBarApp
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
    }

    func hasCachedData() -> Bool {
        return fileManager.fileExists(atPath: databaseURL.path)
    }

    func clear() {
        try? fileManager.removeItem(at: databaseURL)
    }
}
