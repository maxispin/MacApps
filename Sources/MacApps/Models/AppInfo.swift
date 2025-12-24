import Foundation
import SwiftUI

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleIdentifier: String?
    var finderComment: String?
    var icon: NSImage?
    var isMenuBarApp: Bool = false  // LSUIElement = true

    var hasDescription: Bool {
        guard let comment = finderComment else { return false }
        return !comment.isEmpty
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
