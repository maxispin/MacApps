import Foundation
import AppKit
import CoreSpotlight
import UniformTypeIdentifiers

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

    // MARK: - Spotlight Indexing

    /// Index app for Spotlight search - makes descriptions searchable without prefixes
    func indexForSpotlight(
        path: String,
        name: String,
        bundleIdentifier: String?,
        description: String,
        icon: NSImage? = nil
    ) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.application)

        // These fields are searchable in Spotlight WITHOUT prefixes
        attributeSet.displayName = name
        attributeSet.contentDescription = description
        attributeSet.keywords = extractKeywords(from: description)
        attributeSet.path = path

        // Add app icon if available
        if let icon = icon {
            attributeSet.thumbnailData = icon.tiffRepresentation
        }

        let item = CSSearchableItem(
            uniqueIdentifier: bundleIdentifier ?? path,
            domainIdentifier: "com.tyrvainen.macapps.descriptions",
            attributeSet: attributeSet
        )

        // Index permanently - never expires
        item.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Spotlight indexing failed for \(name): \(error)")
            }
        }
    }

    /// Index multiple apps at once (more efficient for batch operations)
    func indexMultipleForSpotlight(_ items: [(path: String, name: String, bundleIdentifier: String?, description: String, icon: NSImage?)]) {
        let searchableItems = items.map { item -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.application)
            attributeSet.displayName = item.name
            attributeSet.contentDescription = item.description
            attributeSet.keywords = extractKeywords(from: item.description)
            attributeSet.path = item.path

            if let icon = item.icon {
                attributeSet.thumbnailData = icon.tiffRepresentation
            }

            let searchItem = CSSearchableItem(
                uniqueIdentifier: item.bundleIdentifier ?? item.path,
                domainIdentifier: "com.tyrvainen.macapps.descriptions",
                attributeSet: attributeSet
            )
            searchItem.expirationDate = .distantFuture
            return searchItem
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Spotlight batch indexing failed: \(error)")
            }
        }
    }

    /// Remove app from Spotlight index
    func removeFromSpotlight(bundleIdentifier: String?, path: String) {
        let identifier = bundleIdentifier ?? path
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error = error {
                print("Spotlight removal failed: \(error)")
            }
        }
    }

    /// Clear all MacApps entries from Spotlight index
    func clearSpotlightIndex() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.tyrvainen.macapps.descriptions"]) { error in
            if let error = error {
                print("Spotlight index clear failed: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    private func extractKeywords(from description: String) -> [String] {
        // Split into words, filter short ones
        description
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }
}
