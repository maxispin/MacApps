# Architecture

## Project Structure

```
Sources/MacApps/
├── MacAppsApp.swift          # App entry point, version info
├── Models/
│   └── AppInfo.swift         # Data models, enums (AppInfo, AppCategory, AppSource)
├── Services/
│   ├── AppScanner.swift      # App discovery from multiple locations
│   ├── AppDatabase.swift     # JSON persistence (~/.../MacApps/apps.json)
│   ├── ClaudeService.swift   # Claude CLI integration for AI
│   ├── MetadataWriter.swift  # Finder comments + CoreSpotlight indexing
│   └── IconManager.swift     # NSCache-based icon management
├── ViewModels/
│   └── AppState.swift        # Main state (@MainActor, @Published)
└── Views/
    ├── ContentView.swift     # Main UI, sidebar, filters
    ├── DetailView.swift      # App detail panel
    └── ToolbarView.swift     # Toolbar buttons, batch update sheet
```

## Technology Stack

- **SwiftUI** - UI framework (macOS 14.0+)
- **Swift 5.9+** - Language
- **CoreSpotlight** - Spotlight indexing (requires signed app)
- **Claude CLI** - External AI for descriptions
- **AppleScript** - Finder comment writing via osascript

## Data Flow

```
User Action
    ↓
AppState (ViewModel)
    ↓
┌─────────────┬─────────────┬─────────────┐
│ AppScanner  │ClaudeService│MetadataWriter│
│ (discovery) │ (AI)        │ (persistence)│
└─────────────┴─────────────┴─────────────┘
    ↓               ↓               ↓
File System    Claude CLI     Finder + Spotlight
```

## Key Data Models

### AppInfo
Main model for an application:
- `path`, `name`, `bundleIdentifier`
- `categories: [AppCategory]` - AI-generated (usually 1)
- `functions: [String]` - Action verbs ("edit images")
- `descriptions: [LocalizedDescription]` - Multi-language

### AppCategory (11 types)
Productivity, Development, Design, Media, Communication, Utilities, Games, Finance, Education, System, Other

### AppSource (5 locations)
- `/Applications`
- `~/Applications`
- `/System/Applications`
- `/opt/homebrew/Caskroom`
- `~/Library/Application Support/Setapp/...`

## Database Schema

JSON file at `~/Library/Application Support/MacApps/apps.json`:

```json
{
  "path": "/Applications/App.app",
  "name": "App",
  "bundleIdentifier": "com.example.app",
  "categories": ["Development"],
  "functions": ["edit code", "run tests"],
  "descriptions": [
    {
      "language": "fi",
      "shortDescription": "...",
      "expandedDescription": "...",
      "fetchedAt": "2025-01-01T00:00:00Z"
    }
  ],
  "finderComment": "...",
  "lastScanned": "..."
}
```

## Critical Paths - Do Not Break

### MetadataWriter.setFinderComment()
- AppleScript execution via `/usr/bin/osascript`
- Must escape quotes and backslashes
- Returns Bool for success/failure

### ClaudeService
- All prompts MUST focus on ACTION VERBS
- NO praise words (see DEVELOPMENT.md)
- Include both verb forms in descriptions

### AppDatabase.save() / load()
- Preserves existing data on rescan
- Must keep originalFinderComment intact

### IconManager.loadIcon()
- NSCache with 100MB / 200 icon limit
- Async loading, placeholder icons

## Security Requirements

1. Never execute arbitrary code from applications
2. Always escape user input in AppleScript strings
3. Use hardcoded paths for system binaries
4. Never store credentials - Claude CLI handles auth
