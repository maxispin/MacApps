# CLAUDE.md - Project Guidelines for AI Assistants

This file provides context and guidelines for AI assistants (like Claude) working on this project.

## Project Overview

**MacApps** is a macOS SwiftUI application that:
1. Scans multiple locations for installed applications
2. Generates action-focused descriptions using Claude CLI
3. Assigns categories to apps (Development, Design, Media, etc.)
4. Writes descriptions as Finder comments for searchability
5. Stores multi-language descriptions (system language + English)
6. Indexes descriptions for Spotlight search (CoreSpotlight)

## Feature Reference

### Toolbar Buttons
- **Scan (Cmd+R)**: Rescans all application folders and updates the app list
- **Update All**: Opens dialog to generate descriptions for multiple apps
- **Reindex Spotlight**: Re-indexes all descriptions for Spotlight search

### Filters
- **Description Filter**: All / With Description / Without Description
- **Source Filter**: All Sources / Hide Setapp / Only Setapp
- **Category Filter**: Dropdown with all categories + uncategorized count

### Generate Description
When triggered for an app:
1. Fetches short description (5-10 words) in system language
2. Fetches expanded description (255 chars) in system language
3. Fetches both in English (if system is not English)
4. Fetches category (if not already set)
5. Writes to Finder comment
6. Indexes for Spotlight

### Categories
11 predefined categories with icons and colors:
- Productivity (doc.text.fill, blue)
- Development (chevron.left.forwardslash.chevron.right, orange)
- Design (paintbrush.fill, purple)
- Media (play.circle.fill, red)
- Communication (bubble.left.and.bubble.right.fill, green)
- Utilities (wrench.and.screwdriver.fill, gray)
- Games (gamecontroller.fill, pink)
- Finance (dollarsign.circle.fill, mint)
- Education (graduationcap.fill, indigo)
- System (gearshape.fill, secondary)
- Other (square.grid.2x2.fill, secondary)

## Architecture

### SwiftUI Application Structure
```
Sources/MacApps/
├── MacAppsApp.swift          # App entry point, version info
├── Models/
│   └── AppInfo.swift         # Data models, enums
├── Services/
│   ├── AppScanner.swift      # App discovery, icon loading
│   ├── AppDatabase.swift     # JSON persistence, multi-language storage
│   ├── ClaudeService.swift   # Claude CLI integration
│   ├── MetadataWriter.swift  # Finder comments + Spotlight indexing
│   └── IconManager.swift     # Icon caching with NSCache
├── ViewModels/
│   └── AppState.swift        # Main state management (@MainActor)
└── Views/
    ├── ContentView.swift     # Main UI, sidebar, app list
    ├── DetailView.swift      # App detail panel
    └── ToolbarView.swift     # Toolbar, batch update sheet
```

### Key Dependencies
- **SwiftUI**: UI framework
- **Foundation**: File system operations
- **CoreSpotlight**: Spotlight indexing (requires signed app)
- **Claude CLI**: External dependency for AI descriptions
- **osascript**: AppleScript execution for Finder integration

## Validation Practices

### Before Every Commit
- `swift build -c release` must pass
- Application starts without errors
- Finder comment writing works (test with one app)
- Version number updated in MacAppsApp.swift

### Manual Testing Checklist
```
1. Launch application
2. Select one app from list
3. Click "Generate Description"
4. Verify progress sheet appears
5. Check Finder comment updated (Get Info on app)
6. Verify "Missing" indicator disappears after update
```

## Critical Paths - Do Not Break

### MetadataWriter.setFinderComment()
- AppleScript call to write Finder comments
- Must escape quotes and backslashes properly
- Returns Bool for success/failure

### ClaudeService.getDescriptionWithTiming()
- Claude CLI integration
- Must handle CLI not found gracefully
- Returns timing info for UI feedback

### AppScanner.scanApplicationsWithoutIcons()
- Discovers apps in /Applications
- Must not block UI (runs in Task.detached)
- Returns array of AppInfo

### AppDatabase.save() / load()
- JSON persistence to ~/Library/Application Support/MacApps/
- Must preserve originalFinderComment on first scan
- Must preserve descriptions across rescans

### IconManager.loadIcon()
- Async icon loading with NSCache
- Must return placeholder if icon not found
- Memory limit: 100MB, 200 icons max

## Version Numbering

This project uses **four-level semantic versioning**: `MAJOR.MINOR.PATCH.BUILD`

- **MAJOR**: Breaking changes or significant rewrites
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, small improvements
- **BUILD**: Any commit/change increment

**Always increment BUILD for every commit.**

Files to update:
- `MacAppsApp.swift` - static let version
- `CHANGELOG.md` - add entry
- `README.md` - version badge

## Code Quality

### Before Commit Checklist
- [ ] No force unwraps (!) - use guard/if-let
- [ ] All errors handled gracefully
- [ ] Clear error messages for user-facing failures
- [ ] No hardcoded Finnish strings in code (use English)
- [ ] UI updates on MainActor

### Swift Style
- Swift 5.9+ syntax
- Use `// MARK: -` comments for section headers
- Keep methods focused and under 30 lines when possible
- Use guard statements for early returns
- Prefer descriptive variable names
- Use async/await, not completion handlers

### Security Requirements

**CRITICAL**: This tool interacts with system files and runs AppleScript:

1. **Never execute arbitrary code** from applications
2. **Always escape user input** in AppleScript strings
3. **Validate file paths** before operations
4. **Use hardcoded paths** for system binaries (`/usr/bin/osascript`)
5. **Never store credentials** - rely on Claude CLI's authentication

### AppleScript Security
```swift
// ALWAYS escape quotes and special characters
let escapedComment = comment
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
```

## Build Commands

```bash
# Development build
swift build

# Release build (required before commit)
swift build -c release

# Run application
swift run

# Clean build artifacts
swift package clean

# Kill running instances before rebuild
pkill -f "MacApps" 2>/dev/null; swift build && swift run
```

## Testing Commands

```bash
# Check Finder comment was written
osascript -e 'tell application "Finder" to get comment of (POSIX file "/Applications/AppName.app" as alias)'

# Search Finder comments via Spotlight
mdfind "kMDItemFinderComment == '*searchterm*'c"

# Check database content
cat ~/Library/Application\ Support/MacApps/apps.json | jq '.[] | select(.name == "AppName")'
```

## Common Tasks

### Adding New Features
1. Implement feature
2. Update version in MacAppsApp.swift
3. Add CHANGELOG.md entry
4. Update README.md if user-facing
5. Build and test manually
6. Commit with descriptive message
7. Push to remote

### Modifying AI Prompts
The Claude CLI prompts are in `ClaudeService.swift`. When modifying:
- Focus on ACTION VERBS (what user can DO)
- Keep within 255 char limit for Finder comments
- Test with various app types
- Generate both short and expanded versions

### Debugging UI Updates
If UI doesn't refresh after data change:
- Check AppInfo.Equatable includes changed fields
- Verify @Published properties trigger updates
- Use selectedApp = apps[index] to force refresh

## Git Workflow

1. All changes must be committed with descriptive messages
2. Version number must be incremented for each commit
3. Push after commit
4. Use conventional commit format: `feat:`, `fix:`, `docs:`

**IMPORTANT**: After completing any task successfully (build passes, tests work):
1. Increment version in MacAppsApp.swift
2. Update CHANGELOG.md with changes
3. Update README.md version badge if needed
4. `git add -A && git commit -m "..."` with descriptive message
5. `git push` to remote repository

Always commit and push when the task is complete and working!

## Known Limitations

1. Requires GUI session for Finder automation
2. Some system apps may reject comment writes (protected)
3. CoreSpotlight indexing requires signed/notarized app
4. Claude CLI must be installed and authenticated
5. Rate limited by Claude CLI response time (~2-5 sec per request)

## Scan Locations

Applications are scanned from multiple locations:
- `/Applications` - Standard macOS applications
- `~/Applications` - User-installed applications
- `/System/Applications` - System applications (Finder, Safari, etc.)
- `/opt/homebrew/Caskroom` - Homebrew Cask applications
- `~/Library/Application Support/Setapp/Setapp/Applications` - Setapp applications

Duplicate apps (same bundle ID from multiple locations) are automatically deduplicated.
