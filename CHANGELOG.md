# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with four levels: `MAJOR.MINOR.PATCH.BUILD`.

## [Unreleased]

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
