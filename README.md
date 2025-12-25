# MacApps

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.4.0.0-brightgreen.svg)](CHANGELOG.md)

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

### Core Features
- **Action-Based Descriptions**: AI generates verb-focused descriptions - what you can DO with each app (e.g., "Edit photos, retouch, crop, adjust colors...")
- **App Categories**: Automatic categorization (Productivity, Development, Design, Media, Communication, Utilities, Games, Finance, Education, System)
- **Multi-Language Support**: Descriptions generated in your system language + English for maximum searchability
- **Finder Integration**: Descriptions saved as Finder comments (255 chars max) - searchable in Spotlight

### App Discovery
- **Multi-Location Scanning**: Scans /Applications, ~/Applications, /System/Applications, Homebrew Caskroom, and Setapp
- **Source Filtering**: Filter by source (All, Hide Setapp, Only Setapp)
- **Category Filtering**: Filter by category with dropdown menu
- **Smart Search**: Search by app name, bundle ID, description, or category

### User Interface
- **Visual Browser**: Browse all installed apps with 128x128 icons in detail view
- **Real-Time Progress**: See description generation progress with timing info
- **Menu Bar App Support**: Detect menu bar apps, launch them, open their preferences
- **Context Menu**: Right-click for quick actions (Open in Finder, Launch, Generate Description)

### Data Management
- **Persistent Cache**: Fast startup with local JSON database
- **Original Comments Preserved**: Stores original Finder comments before modification
- **Spotlight Indexing**: CoreSpotlight integration for prefix-free search (requires signed app)

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

1. **Launch MacApps** - The app automatically scans all application folders
2. **Browse or Search** - Use the sidebar to find apps by name, description, or category
3. **Select an App** - Click to view details with large icon (128x128)
4. **Generate Description** - Click "Generate Description" to create AI descriptions and category
5. **Search in Spotlight** - Type `keyword app` (e.g., `calculate app`) to find apps by what they do

### Toolbar Buttons

| Button | Description |
|--------|-------------|
| **Scan** | Rescan all application folders (/Applications, ~/Applications, /System/Applications, Homebrew, Setapp). Use after installing or removing apps. |
| **Update All** | Generate AI descriptions and categories for multiple apps. Shows options dialog with progress tracking. |
| **Reindex Spotlight** | Re-add all descriptions to CoreSpotlight index for prefix-free search. Only works with signed app. |

### Filters

- **Description Filter**: Show All / With Description / Without Description
- **Source Filter**: All Sources / Hide Setapp / Only Setapp
- **Category Filter**: Dropdown menu with all categories (shows count per category)

### Generate Description Button

When you click "Generate Description" for an app, MacApps:
1. Generates a short description (5-10 words) in your system language
2. Generates an expanded description (255 chars) in your system language
3. Generates both in English (if system is not English)
4. Assigns a category (Development, Design, Media, etc.)
5. Saves the description as a Finder comment
6. Indexes for Spotlight search

Each API call takes 2-5 seconds. Progress is shown in real-time.

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+R | Rescan applications |
| Double-click | Launch app |

### Context Menu

Right-click any app in the list for quick actions:
- **Open in Finder** - Reveal the app in Finder
- **Launch App** - Open the application
- **Open Preferences** - For menu bar apps, open settings (Cmd+,)
- **Generate Description** - Create AI description and category

### Categories

Apps are automatically categorized into:
- **Productivity** - Office, notes, documents
- **Development** - IDEs, coding, databases
- **Design** - Graphics, video, UI design
- **Media** - Music, video, photos, streaming
- **Communication** - Email, chat, video calls
- **Utilities** - System tools, file managers
- **Games** - Games, entertainment
- **Finance** - Accounting, trading, banking
- **Education** - Learning, courses, reference
- **System** - OS components, settings

## How It Works

1. **Scan**: Reads all `.app` bundles from multiple locations (Applications, System, Homebrew, Setapp)
2. **Display**: Shows apps in a searchable, filterable list with icons and metadata
3. **Generate**: Sends app name + bundle ID to Claude CLI, receives action-focused description + category
4. **Write**: Saves description to Finder comment (255 chars) + CoreSpotlight index
5. **Search**: Type `keyword app` in Spotlight to find apps by what they do

### Data Storage

- **Database**: `~/Library/Application Support/MacApps/apps.json`
- **Finder Comments**: Written via AppleScript to each app's metadata
- **Spotlight Index**: CoreSpotlight entries (requires signed app for prefix-free search)

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
