# Claude Code Workflow & Checklist

Step-by-step guide for every Claude Code session on MacApps.

## Quick Reference

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Project structure, data models, critical paths |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Build commands, AI prompt rules, code style |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [README.md](README.md) | User-facing documentation |

---

## Session Workflow

### 1. Before Making Changes

- [ ] Read the relevant code files first
- [ ] Understand existing patterns before modifying
- [ ] Check if feature already exists

### 2. During Development

- [ ] Follow code style (see DEVELOPMENT.md)
- [ ] Keep methods focused and short
- [ ] Use guard statements for early returns
- [ ] No force unwraps (!)

### 3. Before Commit

- [ ] Run `swift build -c release` - must pass
- [ ] **MANDATORY**: Kill and launch app: `pkill -9 -f MacApps; .build/release/MacApps &`
- [ ] Verify the change works as expected
- [ ] Check UI updates correctly

> **CRITICAL**: ALWAYS launch the app after every code change. Never commit without testing!

### 4. Commit Process

1. Increment version in `MacAppsApp.swift`
2. Update `CHANGELOG.md`
3. Update `README.md` version badge if needed
4. Commit with conventional format:
   ```
   feat: Description
   fix: Description
   docs: Description
   ```
5. Push to remote

---

## Common Tasks Checklist

### Adding a New Field to AppInfo

- [ ] Add property to `AppInfo` struct
- [ ] Add to `AppInfo.Equatable` (==)
- [ ] Add to `AppDatabase.StoredApp`
- [ ] Add to `AppDatabase.save()` mapping
- [ ] Add to `AppState.loadFromCache()` mapping
- [ ] Update UI views as needed
- [ ] Update DetailView `.id()` if needed for refresh

### Modifying AI Prompts

- [ ] Edit prompts in `ClaudeService.swift`
- [ ] NO praise words (DEVELOPMENT.md)
- [ ] Focus on ACTION VERBS
- [ ] Test with various apps
- [ ] Check 255 char limit for Finder comments

### Adding a New Filter

- [ ] Add filter state to `AppState` (@Published)
- [ ] Add filter logic to `filteredApps` computed property
- [ ] Add UI menu to `ContentView.swift` SidebarView
- [ ] Test filter works correctly

---

## Critical Reminders

### Always Test Before Commit
```bash
pkill -f MacApps; swift build -c release && .build/release/MacApps
```

### Check UI Refresh
If UI doesn't update after changes:
1. Is field in `AppInfo.Equatable`?
2. Is `selectedApp` being updated?
3. Is view `.id()` including the changed field?

### AppleScript Security
Always escape in `MetadataWriter`:
```swift
comment.replacingOccurrences(of: "\\", with: "\\\\")
       .replacingOccurrences(of: "\"", with: "\\\"")
```

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| UI not refreshing | Add field to Equatable, update selectedApp |
| Category not showing | Check loadFromCache maps categories |
| Build fails | Check for missing imports, syntax errors |
| App not launching | Check for runtime errors in terminal |
| Finder comment not writing | Check Automation permission |

---

## Session End Checklist

- [ ] All changes tested
- [ ] Build passes
- [ ] Version incremented
- [ ] CHANGELOG updated
- [ ] Committed and pushed
