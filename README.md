# MacApps

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.3.2.0-brightgreen.svg)](CHANGELOG.md)

## The Problem

You know what you want to **do**, but you can't remember which app does it.

- *"I need to edit a spreadsheet"* → Which app? Numbers? Excel? LibreOffice?
- *"I want to draw a diagram"* → OmniGraffle? Sketch? Figma?
- *"I need to calculate something"* → Calculator? Soulver? PCalc?

**MacApps solves this** by adding action-based descriptions to every application.

## The Solution

MacApps uses AI to generate **verb-focused descriptions** for each app:

```
Numbers: Laske, taulukoi, analysoi dataa, luo kaavioita, graafeja, budjetteja...
Photoshop: Muokkaa kuvia, retusoi, rajaa, säädä värejä, poista taustoja...
Terminal: Suorita komentoja, hallitse tiedostoja, automatisoi, skriptaa...
```

Now you can search in Finder/Spotlight by **what you want to do**:
- Type "laske" → Find all calculation apps
- Type "piirrä" → Find all drawing apps
- Type "analysoi" → Find data analysis apps

## Features

- **Action-Based Descriptions**: Focus on verbs - what you can DO with each app
- **Multi-Language Support**: Descriptions in your system language + English
- **Visual Application Browser**: Browse all installed apps with icons
- **Smart Search**: Search by actions across ALL languages
- **AI-Powered**: Uses Claude AI to generate intelligent, searchable descriptions
- **Finder Integration**: Descriptions saved as Finder comments (255 chars)
- **Menu Bar App Support**: Detect and launch menu bar apps
- **Batch Processing**: Update all apps at once
- **Persistent Cache**: Fast startup with local database

## Screenshots

The application features a clean, native macOS interface with:
- Sidebar listing all applications with icons
- Search and filter controls
- Detailed view for selected application
- One-click description generation

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
3. **Select an App** - Click to view details and current Finder comment
4. **Generate Description** - Choose Short or Expanded, then click "Generate Description"
5. **Search in Finder** - Use Spotlight or Finder to search by description

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+R | Rescan applications |

### Context Menu

Right-click any app in the list for quick actions:
- Open in Finder
- Launch App
- Update Description
- Refresh Comment

### Batch Update

Use the "Update All" toolbar button to:
- Update all apps at once
- Update only apps without descriptions
- Choose between Short and Expanded descriptions

## How It Works

1. **Scan**: Reads all `.app` bundles from `/Applications` with icons
2. **Display**: Shows apps in a searchable, filterable list
3. **Generate**: Sends app info to Claude CLI for AI description
4. **Write**: Saves description to Finder comment metadata
5. **Search**: Finder and Spotlight can now find apps by functionality

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
│   │   ├── ClaudeService.swift   # AI integration
│   │   └── MetadataWriter.swift  # Finder comments
│   ├── ViewModels/
│   │   └── AppState.swift        # App state management
│   └── Views/
│       ├── ContentView.swift     # Main UI
│       ├── DetailView.swift      # App detail panel
│       └── ToolbarView.swift     # Toolbar controls
├── README.md
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

## Legal

- **License**: [Proprietary - All Rights Reserved](LICENSE)
- **EULA**: [End User License Agreement](EULA.md)
- **Privacy**: [Privacy Policy](PRIVACY.md)
- **Security**: [Security Policy](SECURITY.md)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Author

**Japo Tyrväinen**

Copyright © 2024 Japo Tyrväinen. All rights reserved.

## Acknowledgments

- [Anthropic](https://anthropic.com) for Claude AI
- Apple for macOS and Swift
