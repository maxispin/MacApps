import AppKit

/// Manages app icon loading with caching and placeholder support
@MainActor
class IconManager {
    static let shared = IconManager()

    private let cache = NSCache<NSString, NSImage>()
    private var loadingPaths: Set<String> = []

    // Placeholder icon for apps while loading
    let placeholder: NSImage

    private init() {
        cache.countLimit = 200  // Max 200 icons
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB

        // Create a simple placeholder icon
        placeholder = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App")
            ?? NSImage(size: NSSize(width: 32, height: 32))
    }

    /// Get cached icon or placeholder
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

    /// Load icon asynchronously and cache it
    func loadIcon(for path: String) async -> NSImage {
        // Return cached if available
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }

        // Prevent duplicate loading
        guard !loadingPaths.contains(path) else {
            return placeholder
        }
        loadingPaths.insert(path)

        // Load in background
        let icon = await Task.detached(priority: .background) {
            NSWorkspace.shared.icon(forFile: path)
        }.value

        // Cache and return
        cache.setObject(icon, forKey: path as NSString)
        loadingPaths.remove(path)

        return icon
    }

    /// Preload icons for multiple paths in background
    func preloadIcons(for paths: [String]) {
        Task.detached(priority: .background) {
            for path in paths {
                _ = await self.loadIcon(for: path)
            }
        }
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAllObjects()
        loadingPaths.removeAll()
    }
}
