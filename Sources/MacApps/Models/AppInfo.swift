import Foundation
import SwiftUI

/// Application category based on functionality
enum AppCategory: String, Codable, CaseIterable {
    case productivity = "Productivity"
    case development = "Development"
    case design = "Design"
    case media = "Media"
    case communication = "Communication"
    case utilities = "Utilities"
    case games = "Games"
    case finance = "Finance"
    case education = "Education"
    case system = "System"
    case other = "Other"

    var icon: String {
        switch self {
        case .productivity: return "doc.text.fill"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush.fill"
        case .media: return "play.circle.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .games: return "gamecontroller.fill"
        case .finance: return "dollarsign.circle.fill"
        case .education: return "graduationcap.fill"
        case .system: return "gearshape.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .productivity: return .blue
        case .development: return .orange
        case .design: return .purple
        case .media: return .red
        case .communication: return .green
        case .utilities: return .gray
        case .games: return .pink
        case .finance: return .mint
        case .education: return .indigo
        case .system: return .secondary
        case .other: return .secondary
        }
    }
}

/// Source location where an application was found
enum AppSource: String, Codable, CaseIterable {
    case applications = "Applications"          // /Applications
    case userApplications = "User Apps"         // ~/Applications
    case systemApplications = "System"          // /System/Applications
    case homebrew = "Homebrew"                  // /opt/homebrew/Caskroom
    case setapp = "Setapp"                      // ~/Library/Application Support/Setapp

    var icon: String {
        switch self {
        case .applications: return "folder.fill"
        case .userApplications: return "person.fill"
        case .systemApplications: return "gearshape.fill"
        case .homebrew: return "mug.fill"
        case .setapp: return "s.square.fill"
        }
    }
}

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleIdentifier: String?
    var finderComment: String?  // Primary (written to Finder)
    var originalFinderComment: String?  // Original comment before MacApps modified it
    var icon: NSImage?
    var isMenuBarApp: Bool = false  // LSUIElement = true
    var source: AppSource = .applications  // Where the app was found
    var categories: [AppCategory] = []  // AI-generated categories (usually 1, max 2-3)
    var functions: [String] = []  // Action verbs: "edit images", "send messages", etc.

    // Multi-language descriptions stored in database
    var descriptions: [AppDatabase.LocalizedDescription]?

    /// Primary category (first one)
    var category: AppCategory? {
        categories.first
    }

    /// Check if app has a specific category
    func hasCategory(_ category: AppCategory) -> Bool {
        categories.contains(category)
    }

    var hasDescription: Bool {
        // Has description if finderComment exists OR any language description exists
        if let comment = finderComment, !comment.isEmpty {
            return true
        }
        return descriptions?.isEmpty == false
    }

    /// Check if language has COMPLETE description (both short AND expanded)
    func hasCompleteDescription(for language: String) -> Bool {
        guard let desc = descriptions?.first(where: { $0.language == language }) else {
            return false
        }
        // Must have both short AND expanded
        return desc.shortDescription != nil && desc.expandedDescription != nil
    }

    /// Check if all target languages have COMPLETE descriptions
    var hasAllLanguages: Bool {
        let targets = AppDatabase.targetLanguages
        return targets.allSatisfy { hasCompleteDescription(for: $0) }
    }

    /// Get languages that need fetching (missing or incomplete)
    var missingLanguages: [String] {
        let targets = AppDatabase.targetLanguages
        return targets.filter { !hasCompleteDescription(for: $0) }
    }

    /// Get what's missing for a specific language
    func missingTypes(for language: String) -> (needsShort: Bool, needsExpanded: Bool) {
        guard let desc = descriptions?.first(where: { $0.language == language }) else {
            return (true, true)  // Both missing
        }
        return (desc.shortDescription == nil, desc.expandedDescription == nil)
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
        lhs.path == rhs.path &&
        lhs.finderComment == rhs.finderComment &&
        lhs.descriptions == rhs.descriptions &&
        lhs.categories == rhs.categories &&
        lhs.functions == rhs.functions
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
