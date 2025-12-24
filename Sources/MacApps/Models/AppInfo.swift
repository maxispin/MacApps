import Foundation
import SwiftUI

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleIdentifier: String?
    var finderComment: String?  // Primary (written to Finder)
    var icon: NSImage?
    var isMenuBarApp: Bool = false  // LSUIElement = true

    // Multi-language descriptions stored in database
    var descriptions: [AppDatabase.LocalizedDescription]?

    var hasDescription: Bool {
        // Has description if finderComment exists OR any language description exists
        if let comment = finderComment, !comment.isEmpty {
            return true
        }
        return descriptions?.isEmpty == false
    }

    /// Check if all target languages have been fetched
    var hasAllLanguages: Bool {
        let targets = AppDatabase.targetLanguages
        guard let descs = descriptions else { return false }
        let fetched = Set(descs.map { $0.language })
        return targets.allSatisfy { fetched.contains($0) }
    }

    /// Get missing languages that need to be fetched
    var missingLanguages: [String] {
        let targets = AppDatabase.targetLanguages
        guard let descs = descriptions else { return targets }
        let fetched = Set(descs.map { $0.language })
        return targets.filter { !fetched.contains($0) }
    }

    /// Combined text from all languages for searching
    var allDescriptionsText: String {
        var texts: [String] = []

        if let comment = finderComment, !comment.isEmpty {
            texts.append(comment)
        }

        if let descs = descriptions {
            for desc in descs {
                if let short = desc.shortDescription { texts.append(short) }
                if let expanded = desc.expandedDescription { texts.append(expanded) }
            }
        }

        return texts.joined(separator: " ")
    }

    /// Get description for display (prefer system language, then English)
    var displayDescription: String? {
        let systemLang = AppDatabase.systemLanguage

        // First try system language
        if let desc = descriptions?.first(where: { $0.language == systemLang }) {
            if let short = desc.shortDescription, let expanded = desc.expandedDescription {
                return "\(short) | \(expanded)"
            }
            return desc.shortDescription ?? desc.expandedDescription
        }

        // Then try English
        if let desc = descriptions?.first(where: { $0.language == "en" }) {
            if let short = desc.shortDescription, let expanded = desc.expandedDescription {
                return "\(short) | \(expanded)"
            }
            return desc.shortDescription ?? desc.expandedDescription
        }

        // Fall back to finderComment
        return finderComment
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.path == rhs.path
    }
}

enum ScanStatus: Equatable {
    case idle
    case scanning
    case completed(count: Int)
    case error(String)
}

enum UpdateStatus: Equatable {
    case idle
    case updating(appName: String, current: Int, total: Int)
    case completed(updated: Int, skipped: Int, failed: Int)
    case error(String)
}

enum DescriptionType: String, CaseIterable {
    case short = "Short"
    case expanded = "Expanded"

    var description: String {
        switch self {
        case .short:
            return "Brief description (5-10 words)"
        case .expanded:
            return "Detailed description with keywords (20-40 words)"
        }
    }
}
