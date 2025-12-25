# Development Guide

## Build Commands

```bash
# Development build
swift build

# Release build (required before commit)
swift build -c release

# Run application
swift run

# Kill and rebuild
pkill -f MacApps; swift build -c release && .build/release/MacApps

# Clean build
swift package clean
```

## Testing Commands

```bash
# Check Finder comment
osascript -e 'tell application "Finder" to get comment of (POSIX file "/Applications/App.app" as alias)'

# Search Finder comments via Spotlight
mdfind "kMDItemFinderComment == '*keyword*'c"

# Check database
cat ~/Library/Application\ Support/MacApps/apps.json | jq '.[] | select(.name == "AppName")'
```

## AI Prompt Rules

### CRITICAL - NO PRAISE WORDS
Descriptions must NEVER contain:
- "popular", "powerful", "best", "great", "amazing", "professional"
- "advanced", "leading", "top", "excellent", "premier", "ultimate"
- "easily", "quickly", "seamlessly", "effortlessly"

These waste character space and help no one find the app.

### CRITICAL - BOTH VERB FORMS (Descriptions only)
For searchability, descriptions include both forms:
- English: "edit editing", "write writing"
- Finnish: "muokkaa muokkaaminen", "kirjoita kirjoittaminen"

### Functions - Keep Simple
Functions are short action phrases (2-3 words):
- "edit images"
- "send messages"
- "manage passwords"

NO duplicate verb forms in functions.

## Code Style

- Swift 5.9+ syntax
- `// MARK: -` for section headers
- Methods under 30 lines when possible
- Guard statements for early returns
- Async/await, not completion handlers
- No force unwraps (!) - use guard/if-let

## UI Updates

If UI doesn't refresh after data change:
1. Check `AppInfo.Equatable` includes the changed field
2. Verify `@Published` properties trigger updates
3. Use `selectedApp = apps[index]` to force refresh
4. Check `.id()` modifier on views

## Version Numbering

Format: `MAJOR.MINOR.PATCH.BUILD`

- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes
- BUILD: Increment on every commit

Files to update:
- `MacAppsApp.swift` - `static let version`
- `CHANGELOG.md` - Add entry
- `README.md` - Version badge

## Common Pitfalls

1. **Forgetting to test** - Always run app after changes
2. **Not updating selectedApp** - Causes stale UI
3. **Missing Equatable fields** - Causes UI not to refresh
4. **AppleScript escaping** - Must escape quotes and backslashes
5. **Finder permission** - User must grant Automation permission
