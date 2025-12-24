import Foundation
import AppKit

class AppScanner {

    func scanApplications() -> [AppInfo] {
        let fileManager = FileManager.default
        let applicationsPath = "/Applications"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: applicationsPath) else {
            return []
        }

        var apps: [AppInfo] = []

        for item in contents where item.hasSuffix(".app") {
            let appPath = "\(applicationsPath)/\(item)"
            let appName = String(item.dropLast(4))

            let bundleId = getBundleIdentifier(appPath: appPath)
            let existingComment = getFinderComment(path: appPath)
            let icon = getAppIcon(appPath: appPath)

            apps.append(AppInfo(
                name: appName,
                path: appPath,
                bundleIdentifier: bundleId,
                finderComment: existingComment,
                icon: icon
            ))
        }

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // Fast scan without icons for quick initial display
    func scanApplicationsWithoutIcons() -> [AppInfo] {
        let fileManager = FileManager.default
        let applicationsPath = "/Applications"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: applicationsPath) else {
            return []
        }

        var apps: [AppInfo] = []

        for item in contents where item.hasSuffix(".app") {
            let appPath = "\(applicationsPath)/\(item)"
            let appName = String(item.dropLast(4))

            let bundleId = getBundleIdentifier(appPath: appPath)
            let existingComment = getFinderComment(path: appPath)
            let isMenuBar = isMenuBarApp(appPath: appPath)

            apps.append(AppInfo(
                name: appName,
                path: appPath,
                bundleIdentifier: bundleId,
                finderComment: existingComment,
                icon: nil,  // Skip icon loading for fast startup
                isMenuBarApp: isMenuBar
            ))
        }

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
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
