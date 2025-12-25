import Foundation
import AppKit

class AppScanner {

    // MARK: - Scan Locations

    /// All locations to scan for applications
    private var scanLocations: [(path: String, source: AppSource)] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            ("/Applications", .applications),
            ("\(homeDir)/Applications", .userApplications),
            ("/System/Applications", .systemApplications),
            ("/opt/homebrew/Caskroom", .homebrew),
            ("\(homeDir)/Library/Application Support/Setapp/Setapp/Applications", .setapp)
        ]
    }

    func scanApplications() -> [AppInfo] {
        var apps: [AppInfo] = []

        for location in scanLocations {
            let scannedApps = scanDirectory(path: location.path, source: location.source, withIcons: true)
            apps.append(contentsOf: scannedApps)
        }

        // Remove duplicates (same bundle ID from different locations)
        apps = removeDuplicates(apps)

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // Fast scan without icons for quick initial display
    func scanApplicationsWithoutIcons() -> [AppInfo] {
        var apps: [AppInfo] = []

        for location in scanLocations {
            let scannedApps = scanDirectory(path: location.path, source: location.source, withIcons: false)
            apps.append(contentsOf: scannedApps)
        }

        // Remove duplicates (same bundle ID from different locations)
        apps = removeDuplicates(apps)

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Scan a single directory for .app bundles
    private func scanDirectory(path: String, source: AppSource, withIcons: Bool) -> [AppInfo] {
        let fileManager = FileManager.default

        // For Homebrew Caskroom, we need to scan subdirectories
        if source == .homebrew {
            return scanHomebrewCaskroom(path: path, withIcons: withIcons)
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        var apps: [AppInfo] = []

        for item in contents where item.hasSuffix(".app") {
            let appPath = "\(path)/\(item)"
            let appName = String(item.dropLast(4))

            let bundleId = getBundleIdentifier(appPath: appPath)
            let existingComment = getFinderComment(path: appPath)
            let isMenuBar = isMenuBarApp(appPath: appPath)
            let icon = withIcons ? getAppIcon(appPath: appPath) : nil

            apps.append(AppInfo(
                name: appName,
                path: appPath,
                bundleIdentifier: bundleId,
                finderComment: existingComment,
                icon: icon,
                isMenuBarApp: isMenuBar,
                source: source
            ))
        }

        return apps
    }

    /// Scan Homebrew Caskroom structure: /opt/homebrew/Caskroom/{cask}/{version}/{App}.app
    private func scanHomebrewCaskroom(path: String, withIcons: Bool) -> [AppInfo] {
        let fileManager = FileManager.default
        var apps: [AppInfo] = []

        guard let casks = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        for cask in casks {
            let caskPath = "\(path)/\(cask)"
            guard let versions = try? fileManager.contentsOfDirectory(atPath: caskPath) else {
                continue
            }

            for version in versions {
                let versionPath = "\(caskPath)/\(version)"
                guard let items = try? fileManager.contentsOfDirectory(atPath: versionPath) else {
                    continue
                }

                for item in items where item.hasSuffix(".app") {
                    let appPath = "\(versionPath)/\(item)"
                    let appName = String(item.dropLast(4))

                    let bundleId = getBundleIdentifier(appPath: appPath)
                    let existingComment = getFinderComment(path: appPath)
                    let isMenuBar = isMenuBarApp(appPath: appPath)
                    let icon = withIcons ? getAppIcon(appPath: appPath) : nil

                    apps.append(AppInfo(
                        name: appName,
                        path: appPath,
                        bundleIdentifier: bundleId,
                        finderComment: existingComment,
                        icon: icon,
                        isMenuBarApp: isMenuBar,
                        source: .homebrew
                    ))
                }
            }
        }

        return apps
    }

    /// Remove duplicate apps (same bundle ID), keeping the one from most specific source
    private func removeDuplicates(_ apps: [AppInfo]) -> [AppInfo] {
        var seen: [String: AppInfo] = [:]

        // Priority: Applications > User Apps > Homebrew > System > Setapp
        let priority: [AppSource: Int] = [
            .applications: 5,
            .userApplications: 4,
            .homebrew: 3,
            .systemApplications: 2,
            .setapp: 1
        ]

        for app in apps {
            let key = app.bundleIdentifier ?? app.path

            if let existing = seen[key] {
                // Keep the one with higher priority
                let existingPriority = priority[existing.source] ?? 0
                let newPriority = priority[app.source] ?? 0
                if newPriority > existingPriority {
                    seen[key] = app
                }
            } else {
                seen[key] = app
            }
        }

        return Array(seen.values)
    }

    private func getInfoPlist(appPath: String) -> [String: Any]? {
        let plistPath = "\(appPath)/Contents/Info.plist"
        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    private func getBundleIdentifier(appPath: String) -> String? {
        return getInfoPlist(appPath: appPath)?["CFBundleIdentifier"] as? String
    }

    /// Check if app is a menu bar app (LSUIElement = true)
    func isMenuBarApp(appPath: String) -> Bool {
        guard let plist = getInfoPlist(appPath: appPath) else { return false }
        // LSUIElement can be Bool or String "1"
        if let value = plist["LSUIElement"] as? Bool {
            return value
        }
        if let value = plist["LSUIElement"] as? String {
            return value == "1" || value.lowercased() == "true"
        }
        if let value = plist["LSUIElement"] as? Int {
            return value == 1
        }
        return false
    }

    func getFinderComment(path: String) -> String? {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(escapedPath)" as alias
            return comment of theFile
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == true ? nil : output
        } catch {
            return nil
        }
    }

    private func getAppIcon(appPath: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        return workspace.icon(forFile: appPath)
    }
}
