# MacApps

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.3.5.0-brightgreen.svg)](CHANGELOG.md)

## The Problem

You know what you want to **do**, but you can't remember which app does it.

- *"I need to edit a spreadsheet"* → Which app? Numbers? Excel? LibreOffice?
- *"I want to draw a diagram"* → OmniGraffle? Sketch? Figma?
- *"I need to calculate something"* → Calculator? Soulver? PCalc?

**MacApps solves this** by adding action-based descriptions to every application.

## The Solution

MacApps uses AI to generate **verb-focused descriptions** for each app:

```
Numbers: Calculate, create spreadsheets, analyze data, build charts, budgets...
Photoshop: Edit images, retouch photos, crop, adjust colors, remove backgrounds...
Terminal: Run commands, manage files, automate tasks, write scripts...
```

Now you can search in Spotlight by **what you want to do**:
- Type `calculate app` → Find all calculation apps
- Type `draw app` → Find all drawing apps
- Type `edit images app` → Find image editing apps

Or use the `comment:` prefix for exact matches:
- `comment:calculate` → Apps with "calculate" in description

## Features

- **Action-Based Descriptions**: Focus on verbs - what you can DO with each app
- **Multi-Language Support**: Descriptions in your system language + English
- **Visual Application Browser**: Browse all installed apps with icons (128x128 in detail view)
- **Smart Search**: Search by actions across ALL languages
- **AI-Powered**: Uses Claude AI to generate intelligent, searchable descriptions
- **Finder Integration**: Descriptions saved as Finder comments (255 chars)
- **Spotlight Indexing**: CoreSpotlight integration for prefix-free search (App Store version)
- **Menu Bar App Support**: Detect and launch menu bar apps
- **Batch Processing**: Update all apps at once with progress tracking
- **Persistent Cache**: Fast startup with local database
- **Original Comments Preserved**: Stores original Finder comments before modification

## Screenshots

The application features a clean, native macOS interface with:
- Sidebar listing all applications with icons
- Search and filter controls
- Detailed view with large app icon
- One-click description generation with progress display
- Reindex Spotlight button

## Requirements

- macOS 14.0 (Sonoma) or later
- [Claude CLI](https://github.com/anthropics/claude-code) installed and configured
- Finder automation permissions

## Installation

### From Mac App Store

Download MacApps from the [Mac App Store](#) (coming soon).

### From Source (Development Only)

```bash
git clone https://github.com/maxispin/MacApps.git
cd MacApps
swift build -c release
swift run
```

## Usage

### Basic Workflow

1. **Launch MacApps** - The app automatically scans your `/Applications` folder
2. **Browse or Search** - Use the sidebar to find apps, or search by name/description
3. **Select an App** - Click to view details with large icon
4. **Generate Description** - Click "Generate Description" to create AI descriptions
5. **Search in Spotlight** - Type `keyword app` (e.g., `calculate app`) to find apps

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+R | Rescan applications |

### Context Menu

Right-click any app in the list for quick actions:
- Open in Finder
- Launch App
- Open Preferences (for menu bar apps)
- Generate Description

### Batch Update

Use the "Update All" toolbar button to:
- Update all apps at once
- Update only apps with missing descriptions
- View real-time progress with timing info

### Reindex Spotlight

Use the "Reindex Spotlight" toolbar button to:
- Index all existing descriptions for Spotlight
- Shows progress during indexing
- Note: Requires signed app for prefix-free search

## How It Works

1. **Scan**: Reads all `.app` bundles from `/Applications` with icons
2. **Display**: Shows apps in a searchable, filterable list
3. **Generate**: Sends app info to Claude CLI for AI description
4. **Write**: Saves description to Finder comment + CoreSpotlight index
5. **Search**: Type `keyword app` in Spotlight to find apps by what they do

## Security & Privacy

- Only reads application metadata (Info.plist) - no application code execution
- Uses AppleScript through `/usr/bin/osascript` for Finder integration
- Requires explicit user permission for Finder automation
- **No personal data collection** - see [Privacy Policy](PRIVACY.md)
- All file operations are read-only except for Finder comments

## Permissions

On first run, macOS will prompt for:
- **Finder automation**: Required to read/write Finder comments
- **Full Disk Access** (optional): May be needed for some protected applications

To grant permissions:
1. Go to System Settings → Privacy & Security → Automation
2. Enable MacApps to control Finder

## Configuration

Claude CLI is searched in these locations:
- `/usr/local/bin/claude`
- `/opt/homebrew/bin/claude`
- `~/.local/bin/claude`
- `~/bin/claude`
- Falls back to `which claude` if not found

## Project Structure

```
MacApps/
├── Package.swift
├── Sources/MacApps/
│   ├── MacAppsApp.swift          # App entry point
│   ├── Models/
│   │   └── AppInfo.swift         # Data models
│   ├── Services/
│   │   ├── AppScanner.swift      # App discovery
│   │   ├── AppDatabase.swift     # JSON persistence
│   │   ├── ClaudeService.swift   # AI integration
│   │   ├── MetadataWriter.swift  # Finder comments + Spotlight
│   │   └── IconManager.swift     # Icon caching
│   ├── ViewModels/
│   │   └── AppState.swift        # App state management
│   └── Views/
│       ├── ContentView.swift     # Main UI
│       ├── DetailView.swift      # App detail panel
│       └── ToolbarView.swift     # Toolbar controls
├── README.md
├── CLAUDE.md
├── LICENSE
├── EULA.md
├── PRIVACY.md
└── CHANGELOG.md
```

## Troubleshooting

### "Claude CLI not found"
Ensure Claude CLI is installed and in your PATH:
```bash
which claude
```

### "Permission denied" for Finder comments
Grant automation permissions in System Settings → Privacy & Security → Automation.

### Some apps fail to update
- System applications may have additional protections
- Apps with special characters in names may need escaping
- Some apps may not have valid Info.plist files

### Spotlight search tips
- Use `keyword app` format (e.g., `calculate app`, `edit images app`)
- For exact matches, use `comment:keyword` prefix
- CoreSpotlight prefix-free search requires signed/notarized app (App Store version)

## Legal

- **License**: [Proprietary - All Rights Reserved](LICENSE)
- **EULA**: [End User License Agreement](EULA.md)
- **Privacy**: [Privacy Policy](PRIVACY.md)
- **Security**: [Security Policy](SECURITY.md)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Author

**J.I.Edelmann**

Copyright © 2025 J.I.Edelmann. All rights reserved.

## Acknowledgments

- [Anthropic](https://anthropic.com) for Claude AI
- Apple for macOS and Swift
