# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with four levels: `MAJOR.MINOR.PATCH.BUILD`.

## [Unreleased]

## [0.4.3.0] - 2025-12-25

### Added
- **Regenerate All**: New toolbar button to force regenerate ALL data for ALL apps (descriptions, categories, functions, pricing)

### Changed
- Functions now include both verb and noun forms for searchability (e.g., "muokkaa kuvia, kuvankäsittely")

## [0.4.2.0] - 2025-12-25

### Added
- **Pricing info**: New field showing app pricing model (Free, Freemium, Paid, Subscription, Open Source)
- **Font size control**: Cmd+/Cmd- to increase/decrease font size, Cmd+0 to reset
- **Hide button**: Batch update modal can now be hidden while update continues in background

### Fixed
- Batch update modal height increased to prevent buttons being cut off

## [0.4.1.4] - 2025-12-25

### Changed
- AI prompts: Simplified to "NO ADJECTIVES" rule instead of listing forbidden words
- Functions now shown in Application Info section

## [0.4.1.3] - 2025-12-25

### Fixed
- AI prompts: Extended forbidden word list with Finnish adjectives (tehokas, monipuolinen, kätevä, etc.)
- Descriptions now focus purely on action verbs, no adjectives

## [0.4.1.2] - 2025-12-25

### Changed
- Documentation: Added mandatory app testing rule to CLAUDE.md workflow

## [0.4.1.1] - 2025-12-25

### Changed
- Documentation restructure: CLAUDE.md as workflow checklist, new ARCHITECTURE.md and DEVELOPMENT.md

## [0.4.1.0] - 2025-12-25

### Added
- **Functions filter**: Dropdown menu to filter apps by function (e.g., "edit images")
- **Clickable function tags**: Click any function in app details to filter by it
- **Regenerate button**: Force regenerate all data for an app (descriptions, category, functions)

### Changed
- Functions displayed in green color (was blue/purple)
- Function prompts simplified - no more duplicate verb forms in function names

### Fixed
- Functions now stored and loaded correctly from database

## [0.4.0.0] - 2025-12-25

### Added
- **Functions/Actions**: New feature to list what you can DO with each app
  - AI generates 5-15 action verbs per app (e.g., "edit images", "send messages")
  - Displayed as tags in the app detail view with FlowLayout
  - Searchable - find apps by what they can do
  - Stored in database, fetched along with descriptions and categories

## [0.3.10.1] - 2025-12-25

### Fixed
- **UI now updates immediately after category fetch**: DetailView now uses dynamic id based on categories and descriptions to force SwiftUI refresh

## [0.3.10.0] - 2025-12-25

### Added
- **Multiple categories support**: Apps can now have multiple categories (used sparingly, most apps have 1)

### Changed
- Data model changed from `category: AppCategory?` to `categories: [AppCategory]`
- Category filter now shows apps with that category (even if they have multiple)
- Search now matches any of the app's categories

## [0.3.9.0] - 2025-12-25

### Changed
- **Categorize button now also fetches descriptions**: If an app has no description, it fetches descriptions first, then category. Apps with existing descriptions only get category.

## [0.3.8.0] - 2025-12-25

### Added
- **Categorize All button**: New toolbar button to categorize all uncategorized apps without generating descriptions (faster)
- **Dropdown filter menus**: All three filters (Description, Source, Category) now use consistent dropdown menus
- **Source counts in filter**: Source filter dropdown shows app count per source location

### Changed
- Filter UI redesigned with three dropdown menus in a single row
- CLAUDE.md updated with mandatory commit/push workflow after successful tasks

## [0.3.7.0] - 2025-12-25

### Added
- **Detailed tooltips**: All buttons now have descriptive help text explaining what they do
- **Comprehensive documentation**: README and CLAUDE.md updated with full feature descriptions

### Changed
- Update All dialog now shows detailed explanation of what happens during update
- README reorganized with sections: Core Features, App Discovery, User Interface, Data Management
- Added Categories section to README explaining all 11 category types

## [0.3.6.0] - 2025-12-25

### Added
- **App Categories**: AI-generated categories for apps (Productivity, Development, Design, Media, Communication, Utilities, Games, Finance, Education, System, Other)
- **Category filter**: Dropdown menu to filter apps by category
- **Category icons**: Color-coded category icons in app list and detail view
- **Category in search**: Search also matches category names

### Changed
- Description generation now also fetches category (if not already set)
- Category shown in app header and info section

## [0.3.5.0] - 2025-12-25

### Added
- **Multi-location scanning**: Now scans apps from multiple sources:
  - `/Applications` (standard apps)
  - `~/Applications` (user-installed apps)
  - `/System/Applications` (system apps)
  - `/opt/homebrew/Caskroom` (Homebrew Cask apps)
  - `~/Library/Application Support/Setapp/Setapp/Applications` (Setapp apps)
- **Source filtering**: Filter apps by source (All Sources, Hide Setapp, Only Setapp)
- **Source indicator**: Shows source icon in app list for non-standard locations
- **Source display in detail view**: Shows where each app was found

### Changed
- App list now shows icons for different sources (folder, person, gear, mug, S)
- "Open in Finder" now opens correct parent directory for any source
- Duplicate apps (same bundle ID) are automatically removed, keeping highest priority

## [0.3.4.0] - 2025-12-25

### Added
- **Large app icon**: Detail view now shows 128x128 app icon next to name
- **Reindex Spotlight with progress**: Shows indexing progress in sheet
- **Original Finder comment preservation**: Stores original comments before modification
- **CLAUDE.md updated**: Comprehensive AI assistant guidelines with validation practices

### Changed
- Removed "Refresh from Finder" button (not useful)
- Updated all copyright years to 2025
- Updated README with accurate Spotlight search instructions (`comment:keyword`)
- Author name corrected to J.I.Edelmann in all files

## [0.3.3.0] - 2024-12-24

### Added
- **CoreSpotlight integration**: Descriptions now indexed for Spotlight search
  - Search "laske" in Spotlight to find calculation apps - no prefixes needed!
  - Keywords extracted automatically from descriptions
  - Permanent index (never expires)

### Fixed
- **UI refresh after update**: AppInfo Equatable now compares descriptions, so UI updates properly
- **UI counter uses hasAllLanguages**: BatchUpdateSheet shows correct count
- **Batch update uses hasAllLanguages**: Finds apps missing ANY language or description type

## [0.3.2.0] - 2024-12-24

### Added
- **Progress Sheet**: Separate window shows fetch progress for single app updates
- **Timing display**: Each API call shows duration with color coding (green/orange/red)
- **Smart fetching**: Only fetches missing descriptions (checks both short AND expanded)

### Changed
- Skip already fetched descriptions with "jo haettu" status
- Show "Kaikki kuvaukset jo haettu!" when nothing to fetch

## [0.3.1.0] - 2024-12-24

### Changed
- **Action-focused prompts**: Descriptions now emphasize VERBS (what you can DO)
  - "Muokkaa kuvia, retusoi, rajaa, säädä värejä..." instead of "Image editor"
  - Uses full 255 characters for maximum searchability
- **System language to Finder**: Finder comment saved in system language (not English)
- **README rewrite**: Explains the core problem - finding apps by what you want to DO

### Fixed
- **Menu bar app activation**: Now tries to click the menu bar icon
- **Preferences shortcut**: Uses Cmd+, to open preferences

## [0.3.0.0] - 2024-12-24

### Added
- **Multi-language descriptions**: Descriptions now fetched in system language + English
  - Automatically detects system language (fi, sv, de, fr, etc.)
  - English always fetched as secondary language (unless system is English)
  - Each language stored separately in database
- **LocalizedDescription model**: Stores short + expanded description per language
- **All-language search**: Search matches text in ALL stored languages
- **Language indicator in Detail view**: Shows which languages have been fetched
- **Missing language warning**: Shows which languages still need to be fetched

### Changed
- Database schema extended with `descriptions` array for multi-language support
- AppInfo model now has `descriptions`, `missingLanguages`, `hasAllLanguages` properties
- `displayDescription` shows system language first, then English fallback
- ClaudeService accepts language parameter for localized prompts
- Detail view shows all language descriptions in separate boxes

### Fixed
- Descriptions no longer re-fetched if language already exists in database

## [0.2.6.0] - 2024-12-24

### Added
- **Menu bar app detection**: Identifies apps with LSUIElement=true (menu bar only apps)
- **Menu bar indicator**: Blue menubar icon shown in app list for menu bar apps
- **Open Preferences action**: New button/menu item for menu bar apps to open their settings
- **Improved menu bar app launching**: Uses NSWorkspace.OpenConfiguration with activation

### Changed
- AppInfo model now includes `isMenuBarApp` property
- Database stores menu bar app status for faster loading
- Context menu shows "Open Preferences" option for menu bar apps
- Detail view shows "Menu Bar App" badge and preferences button

## [0.2.5.0] - 2024-12-24

### Fixed
- **Icon loading speed**: Icons now load in parallel batches (20 at a time) instead of one by one
- **UI refresh**: Icons now appear immediately when loaded (ObservableObject pattern)
- **Priority boost**: Visible row icons load with `userInitiated` priority instead of `background`

### Changed
- IconManager now uses `@Published` to trigger SwiftUI updates when icons load
- Preload all icons immediately after app list loads (parallel batches)
- Use `.task(id:)` modifier for more reliable icon loading per row

## [0.2.4.0] - 2024-12-24

### Added
- **IconManager**: New centralized icon management with NSCache
  - Memory-efficient caching (100MB limit, 200 icons max)
  - Placeholder icons while loading
  - On-demand lazy loading when rows appear
- **Double-click to launch**: Double-click any app in the list to launch it directly
- **Single-click selection**: Click to select and view details

### Changed
- **Improved icon loading**: Icons now load lazily per-row instead of all at once
- **Faster perceived startup**: UI appears instantly with placeholder icons
- **Reduced memory usage**: Icons cached with automatic eviction

### Removed
- Removed bulk icon preloading (replaced with on-demand loading)

## [0.2.3.0] - 2024-12-24

### Added
- **Dock icon visibility**: App now appears in the Dock for easy access
- **AppDelegate**: Proper application lifecycle management
- **Bring to front on launch**: App activates and comes to front when launched

### Changed
- **Optimized startup performance**: App data loads immediately without icons, icons load asynchronously in background
- **Faster cache loading**: Cached apps display instantly, then icons populate progressively
- **Background icon loading**: Icons load in low-priority background tasks to not block UI

### Fixed
- App no longer gets lost behind other windows
- Significantly reduced startup time when loading from cache

## [0.2.2.0] - 2024-12-24

### Added
- **Version number** displayed in sidebar footer
- **Combined descriptions**: Now generates both short AND expanded descriptions
  - Short description shown first for quick overview
  - Detailed description with keywords for better Finder search
  - Format: "Short summary | Detailed description with keywords"
- **Real-time progress display** during batch update
  - Shows current app being processed
  - Displays generated description text live
  - Progress circle with count
- **Stop button** to cancel batch updates mid-process

### Changed
- Simplified batch update dialog (removed description type picker - now always generates both)
- Improved update progress UI with live text preview
- Better status messages during generation

### Fixed
- Start Update button now works correctly
- Stop button properly cancels ongoing updates

## [0.2.1.0] - 2024-12-24

### Added
- **Persistent Database**: App data is now cached locally
  - Fast startup - no need to rescan every time
  - Data stored in ~/Library/Application Support/MacApps/apps.json
  - Comments synced to database when updated
- **Batch Update Dialog**: New sheet for updating all apps at once
  - Choose between Short and Expanded description types
  - Option to update only apps without descriptions
  - Progress bar with current app name
  - Cancel button to stop batch processing

### Changed
- Removed "Filter" label from segmented picker (cleaner UI)
- App loads from cache on startup, scans only when needed
- Improved batch update flow with dedicated dialog

### Fixed
- Filter picker no longer shows redundant label

## [0.2.0.0] - 2024-12-24

### Added
- **Full SwiftUI GUI Application**
  - Native macOS app with modern interface
  - Navigation split view with sidebar and detail panel
  - Application list with icons and descriptions
  - Search bar for filtering apps by name, description, or bundle ID
  - Filter options: All, With Description, Without Description
  - Statistics bar showing app counts

- **Enhanced Description Generation**
  - Two description types: Short (5-10 words) and Expanded (20-40 words)
  - Expanded descriptions include keywords for better Finder searchability
  - Per-app description generation with visual feedback
  - Batch update for all apps or only those without descriptions

- **App Detail View**
  - Large app icon and name display
  - Bundle identifier display
  - Current Finder comment preview
  - Generate description button with type selection
  - Refresh comment from Finder
  - Launch app and Show in Finder actions

- **Toolbar Actions**
  - Scan/rescan applications (Cmd+R)
  - Update all descriptions button
  - Status indicator for batch operations

- **Context Menu**
  - Right-click on any app for quick actions
  - Open in Finder, Launch App
  - Update Description, Refresh Comment

### Changed
- Migrated from CLI to SwiftUI application
- Requires macOS 14.0 (Sonoma) or later
- Reorganized source code into modular structure:
  - Models: AppInfo, ScanStatus, UpdateStatus, DescriptionType
  - Services: AppScanner, ClaudeService, MetadataWriter
  - ViewModels: AppState
  - Views: ContentView, DetailView, ToolbarView

### Improved
- Better error handling and user feedback
- Async/await for non-blocking operations
- App icons displayed from actual applications
- More detailed AI prompts for better descriptions

## [0.1.1.1] - 2024-12-24

### Changed
- Updated contact email to maxispin@gmail.com

## [0.1.1.0] - 2024-12-24

### Changed
- **License**: Changed from MIT to Proprietary (All Rights Reserved)
- Updated README.md for commercial App Store distribution
- Updated CONTRIBUTING.md to reflect proprietary model

### Added
- **EULA.md**: End User License Agreement for App Store distribution
  - Apple-specific terms and conditions
  - Third-party service disclosures (Claude CLI)
  - Warranty disclaimers and liability limitations
- **PRIVACY.md**: Privacy Policy for App Store compliance
  - GDPR-compliant disclosures
  - App Store privacy nutrition label data
  - Third-party service (Claude CLI) data handling
- Proprietary license with full rights reservation
- Legal section in README with links to all policies

### Security
- Added comprehensive privacy disclosures
- Documented data handling practices
- Added App Store privacy compliance information

## [0.1.0.0] - 2024-12-24

### Added
- Initial release of MacApps
- Application scanning for `/Applications` directory
- Claude CLI integration for generating app descriptions
- Finder comment writing via AppleScript
- Skip logic for apps with existing comments
- Bundle identifier extraction from Info.plist
- Multiple Claude CLI path detection
- Progress tracking with emoji indicators
- Summary statistics after processing
- Comprehensive documentation:
  - README.md with full usage instructions
  - CLAUDE.md for AI assistant guidelines
  - LICENSE (MIT - later changed)
  - CHANGELOG.md (this file)
  - CONTRIBUTING.md guidelines
  - SECURITY.md policy

### Security
- Input sanitization for AppleScript strings
- Hardcoded paths for system binaries
- No credential storage
- Read-only file operations (except Finder comments)

---

## Version History Summary

| Version | Date | Description |
|---------|------|-------------|
| 0.4.0.0 | 2025-12-25 | Functions/Actions - list what you can DO with each app |
| 0.3.10.0 | 2025-12-25 | Multiple categories support, UI update fix |
| 0.3.4.0 | 2025-12-25 | Large icons, Reindex progress, original comments preserved |
| 0.3.3.0 | 2024-12-24 | CoreSpotlight integration for prefix-free search |
| 0.3.2.0 | 2024-12-24 | Progress sheet, timing display, smart fetching |
| 0.3.1.0 | 2024-12-24 | Action verbs, system lang to Finder, menu bar fix |
| 0.3.0.0 | 2024-12-24 | Multi-language descriptions (system lang + English) |
| 0.2.6.0 | 2024-12-24 | Menu bar app detection, indicator, and preferences |
| 0.2.5.0 | 2024-12-24 | Fast parallel icon loading, UI refresh fix |
| 0.2.4.0 | 2024-12-24 | IconManager with NSCache, double-click launch, lazy loading |
| 0.2.3.0 | 2024-12-24 | Dock icon, optimized startup, async icon loading |
| 0.2.2.0 | 2024-12-24 | Version display, combined descriptions, real-time progress |
| 0.2.1.0 | 2024-12-24 | Database caching, batch update dialog |
| 0.2.0.0 | 2024-12-24 | SwiftUI GUI with expanded descriptions and search |
| 0.1.1.1 | 2024-12-24 | Contact email update |
| 0.1.1.0 | 2024-12-24 | App Store preparation: Proprietary license, EULA, Privacy Policy |
| 0.1.0.0 | 2024-12-24 | Initial public release |

---

## Versioning Scheme

- **MAJOR.MINOR.PATCH.BUILD**
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes
- BUILD: Incremented on every commit
