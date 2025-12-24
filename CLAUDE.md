# CLAUDE.md - Project Guidelines for AI Assistants

This file provides context and guidelines for AI assistants (like Claude) working on this project.

## Project Overview

**MacApps** is a macOS command-line utility written in Swift that:
1. Scans `/Applications` for installed applications
2. Generates short descriptions using Claude CLI
3. Writes descriptions as Finder comments for searchability

## Architecture

### Single-File Design
The entire application is in `Sources/main.swift` with three main components:
- `AppScanner`: Discovers apps and reads existing metadata
- `ClaudeDescriber`: Interfaces with Claude CLI for descriptions
- `MetadataWriter`: Writes Finder comments via AppleScript

### Key Dependencies
- **Foundation**: File system operations
- **Claude CLI**: External dependency for AI descriptions
- **osascript**: AppleScript execution for Finder integration

## Version Numbering

This project uses **four-level semantic versioning**: `MAJOR.MINOR.PATCH.BUILD`

- **MAJOR**: Breaking changes or significant rewrites
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, small improvements
- **BUILD**: Any commit/change increment

Example: `0.1.0.0` → `0.1.0.1` (small fix) → `0.1.1.0` (new feature)

**Always increment BUILD for every commit.**

## Development Guidelines

### Code Style
- Swift 5.9+ syntax
- Use `// MARK: -` comments for section headers
- Keep methods focused and under 30 lines when possible
- Use guard statements for early returns
- Prefer descriptive variable names

### Security Requirements

**CRITICAL**: This tool interacts with system files and runs AppleScript:

1. **Never execute arbitrary code** from applications
2. **Always escape user input** in AppleScript strings
3. **Validate file paths** before operations
4. **Use hardcoded paths** for system binaries (`/usr/bin/osascript`)
5. **Never store credentials** - rely on Claude CLI's authentication

### AppleScript Security
When constructing AppleScript strings:
```swift
// ALWAYS escape quotes and special characters
let escapedComment = comment.replacingOccurrences(of: "\"", with: "\\\"")
let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
```

### Error Handling
- Use optional chaining for potentially nil values
- Log errors to stdout with descriptive prefixes
- Never crash on individual app failures - continue processing

## Build Commands

```bash
# Development
swift build

# Release
swift build -c release

# Run
swift run

# Clean
swift package clean
```

## Common Tasks

### Adding New Features
1. Update version in CHANGELOG.md
2. Increment appropriate version segment
3. Update README.md if user-facing
4. Commit with descriptive message
5. Push to remote

### Modifying AI Prompts
The Claude CLI prompt is in `ClaudeDescriber.getDescription()`. When modifying:
- Keep prompts concise for faster responses
- Specify output format explicitly
- Test with various app names

### Adding New Metadata Types
Beyond Finder comments, consider:
- Spotlight metadata (mdimport)
- Extended attributes (xattr)
- Note: Each requires different APIs and permissions

## Testing Considerations

- Test with apps containing special characters in names
- Test with apps missing Info.plist
- Test permission denied scenarios
- Test Claude CLI unavailability

## Git Workflow

1. All changes must be committed with descriptive messages
2. Version number must be incremented for each commit
3. Push automatically after commit
4. Use conventional commit format when appropriate

## Files to Update on Changes

When making changes, remember to update:
- [ ] `CHANGELOG.md` - Document the change
- [ ] `README.md` - If user-facing behavior changes
- [ ] Version badge in README.md
- [ ] This file if development process changes

## Known Limitations

1. Only scans top-level `/Applications` (not subdirectories)
2. Requires GUI session for Finder automation
3. Some system apps may reject comment writes
4. Rate limited by Claude CLI response time
