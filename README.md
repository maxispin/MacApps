# MacApps

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013+-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0.0-brightgreen.svg)](CHANGELOG.md)

A macOS command-line utility that automatically generates and adds descriptive Finder comments to applications using Claude AI. This makes it easy to search for applications by their functionality in Finder.

## Features

- Scans all applications in `/Applications` directory
- Generates concise, descriptive comments using Claude CLI
- Writes descriptions to Finder comments metadata
- Skips applications that already have comments
- Supports incremental processing (safe to run multiple times)

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- [Claude CLI](https://github.com/anthropics/claude-code) installed and configured
- Finder automation permissions

## Installation

### From Source

```bash
git clone https://github.com/yourusername/MacApps.git
cd MacApps
swift build -c release
```

The compiled binary will be at `.build/release/MacApps`.

### Manual Installation

```bash
# Build and install to /usr/local/bin
swift build -c release
sudo cp .build/release/MacApps /usr/local/bin/macapps
```

## Usage

```bash
# Run from project directory
swift run

# Or if installed globally
macapps
```

### Example Output

```
🔍 MacApps - Application Metadata Update
==================================================

📂 Scanning /Applications directory...
   Found 142 applications

[1/142] Safari
   🤖 Fetching description...
   📝 Description: "Web browser for internet browsing"
   ✅ Metadata updated

[2/142] Xcode
   ⏭️  Skipped - comment exists: "Apple development IDE"
...

==================================================
📊 Summary:
   ✅ Updated: 89
   ⏭️  Skipped: 45
   ❌ Failed: 8

💡 Tip: Search apps in Finder using their descriptions!
```

## How It Works

1. **Scan**: Reads all `.app` bundles from `/Applications`
2. **Check**: Retrieves existing Finder comments (skips if present)
3. **Generate**: Sends app name and bundle ID to Claude CLI for description
4. **Write**: Uses AppleScript to set Finder comment metadata

## Security Considerations

- Only reads application metadata (Info.plist) - no application code execution
- Uses AppleScript through `/usr/bin/osascript` for Finder integration
- Requires explicit user permission for Finder automation
- No network access except through Claude CLI
- All file operations are read-only except for Finder comments

## Permissions

On first run, macOS will prompt for:
- **Finder automation**: Required to read/write Finder comments
- **Full Disk Access** (optional): May be needed for some protected applications

To grant permissions:
1. Go to System Settings → Privacy & Security → Automation
2. Enable Terminal (or your terminal app) to control Finder

## Configuration

The tool searches for Claude CLI in these locations:
- `/usr/local/bin/claude`
- `/opt/homebrew/bin/claude`
- `~/.local/bin/claude`
- `~/bin/claude`
- Falls back to `which claude` if not found

## Building

```bash
# Debug build
swift build

# Release build (optimized)
swift build -c release

# Run tests
swift test
```

## Project Structure

```
MacApps/
├── Package.swift       # Swift package manifest
├── Sources/
│   └── main.swift      # Main application source
├── README.md           # This file
├── LICENSE             # MIT license
├── CHANGELOG.md        # Version history
├── CONTRIBUTING.md     # Contribution guidelines
├── SECURITY.md         # Security policy
└── CLAUDE.md           # AI assistant guidelines
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

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Author

Created with Claude AI assistance.

## Acknowledgments

- [Anthropic](https://anthropic.com) for Claude AI
- Apple for macOS and Swift
