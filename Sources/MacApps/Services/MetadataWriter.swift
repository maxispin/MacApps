import Foundation

class MetadataWriter {

    func setFinderComment(path: String, comment: String) -> Bool {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedComment = comment
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(escapedPath)" as alias
            set comment of theFile to "\(escapedComment)"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
