import AppKit
import SwiftUI

/// Manages app icon loading with caching and parallel loading
@MainActor
class IconManager: ObservableObject {
    static let shared = IconManager()

    private let cache = NSCache<NSString, NSImage>()
    private var loadingPaths: Set<String> = []

    // Placeholder icon for apps while loading
    let placeholder: NSImage

    // Track icon updates for SwiftUI refresh
    @Published var loadedCount: Int = 0

    private init() {
        cache.countLimit = 200  // Max 200 icons
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB

        // Create a simple placeholder icon
        placeholder = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App")
            ?? NSImage(size: NSSize(width: 32, height: 32))
    }

    /// Get cached icon or placeholder (synchronous)
    func icon(for path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        return placeholder
    }

    /// Check if icon is already cached
    func hasCachedIcon(for path: String) -> Bool {
        cache.object(forKey: path as NSString) != nil
    }

    /// Load icon with high priority and cache it
    func loadIcon(for path: String) async -> NSImage {
        // Return cached if available
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }

        // Prevent duplicate loading
        guard !loadingPaths.contains(path) else {
            // Wait a bit and check cache again
            try? await Task.sleep(nanoseconds: 50_000_000)
            return cache.object(forKey: path as NSString) ?? placeholder
        }
        loadingPaths.insert(path)

        // Load with HIGH priority for visible icons
        let icon = await Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.icon(forFile: path)
        }.value

        // Cache and notify
        cache.setObject(icon, forKey: path as NSString)
        loadingPaths.remove(path)
        loadedCount += 1

        return icon
    }

    /// Batch load icons in parallel (for visible rows)
    func loadIconsBatch(for paths: [String]) async {
        // Filter out already cached
        let pathsToLoad = paths.filter { !hasCachedIcon(for: $0) && !loadingPaths.contains($0) }

        guard !pathsToLoad.isEmpty else { return }

        // Load all in parallel with high priority
        await withTaskGroup(of: Void.self) { group in
            for path in pathsToLoad {
                group.addTask {
                    _ = await self.loadIcon(for: path)
                }
            }
        }
    }

    /// Preload all icons in parallel batches
    func preloadAllIcons(for paths: [String]) {
        Task {
            // Load in batches of 20 for better parallelism
            let batchSize = 20
            for batchStart in stride(from: 0, to: paths.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, paths.count)
                let batch = Array(paths[batchStart..<batchEnd])
                await loadIconsBatch(for: batch)
            }
        }
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAllObjects()
        loadingPaths.removeAll()
        loadedCount = 0
    }
}
