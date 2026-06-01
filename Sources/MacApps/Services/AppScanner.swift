import Foundation
import AppKit

final class AppScanner: Sendable {

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
            let version = getAppVersion(appPath: appPath)
            let lastUsed = getLastUsed(appPath: appPath)

            apps.append(AppInfo(
                name: appName,
                path: appPath,
                bundleIdentifier: bundleId,
                finderComment: existingComment,
                icon: icon,
                isMenuBarApp: isMenuBar,
                source: source,
                lastUsed: lastUsed,
                version: version
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
                    let appVersion = getAppVersion(appPath: appPath)
                    let lastUsed = getLastUsed(appPath: appPath)

                    apps.append(AppInfo(
                        name: appName,
                        path: appPath,
                        bundleIdentifier: bundleId,
                        finderComment: existingComment,
                        icon: icon,
                        isMenuBarApp: isMenuBar,
                        source: .homebrew,
                        lastUsed: lastUsed,
                        version: appVersion
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

    /// Get app version from Info.plist
    func getAppVersion(appPath: String) -> String? {
        guard let plist = getInfoPlist(appPath: appPath) else { return nil }
        // Try CFBundleShortVersionString first, then CFBundleVersion
        if let version = plist["CFBundleShortVersionString"] as? String {
            return version
        }
        return plist["CFBundleVersion"] as? String
    }

    /// Get last used date from file attributes (last access time)
    func getLastUsed(appPath: String) -> Date? {
        let fileManager = FileManager.default
        let executablePath = "\(appPath)/Contents/MacOS"

        // Try to get the executable's last access time
        guard let contents = try? fileManager.contentsOfDirectory(atPath: executablePath),
              let executable = contents.first else {
            return nil
        }

        let fullPath = "\(executablePath)/\(executable)"
        guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath) else {
            return nil
        }

        // Use modification date as a proxy (access time is often disabled on macOS)
        return attrs[.modificationDate] as? Date
    }

    /// Get publisher/developer from Info.plist or bundle identifier
    func getPublisher(appPath: String) -> String? {
        guard let plist = getInfoPlist(appPath: appPath) else { return nil }

        // Try NSHumanReadableCopyright first - often contains company name
        if let copyright = plist["NSHumanReadableCopyright"] as? String {
            // Extract company name from copyright string
            // Common formats: "© 2024 Company Name", "Copyright 2024 Company"
            let cleaned = copyright
                .replacingOccurrences(of: "©", with: "")
                .replacingOccurrences(of: "Copyright", with: "")
                .replacingOccurrences(of: "All rights reserved.", with: "")
                .replacingOccurrences(of: "All Rights Reserved.", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove year patterns like "2024" or "2020-2024"
            let yearPattern = #"\d{4}(-\d{4})?\s*"#
            if let regex = try? NSRegularExpression(pattern: yearPattern),
               let result = regex.stringByReplacingMatches(
                   in: cleaned,
                   range: NSRange(cleaned.startIndex..., in: cleaned),
                   withTemplate: ""
               ).trimmingCharacters(in: .whitespacesAndNewlines) as String?,
               !result.isEmpty {
                return result
            }
        }

        // Fall back to bundle identifier - extract company from reverse DNS
        if let bundleId = plist["CFBundleIdentifier"] as? String {
            // com.apple.Safari -> Apple
            // com.microsoft.Word -> Microsoft
            let parts = bundleId.split(separator: ".")
            if parts.count >= 2 {
                var company = String(parts[1])
                // Capitalize first letter
                company = company.prefix(1).uppercased() + company.dropFirst()
                return company
            }
        }

        return nil
    }
}
