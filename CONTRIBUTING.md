# Contributing to MacApps

Thank you for your interest in contributing to MacApps! This document provides guidelines and information for contributors.

## Code of Conduct

Please be respectful and constructive in all interactions. We welcome contributors of all experience levels.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report template if available
3. Include:
   - macOS version
   - Swift version (`swift --version`)
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant log output

### Suggesting Features

1. Check existing issues/discussions first
2. Describe the use case clearly
3. Explain why this would benefit users
4. Consider implementation complexity

### Submitting Code

#### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/MacApps.git
   cd MacApps
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

#### Development

1. Make your changes
2. Follow the code style guidelines below
3. Test your changes thoroughly
4. Update documentation if needed

#### Commit Guidelines

- Use clear, descriptive commit messages
- Reference issues when applicable: `Fix #123`
- Keep commits focused and atomic
- Update version number (BUILD level minimum)

Example commit messages:
```
Add support for scanning ~/Applications directory

- Extend AppScanner to accept custom paths
- Update documentation with new feature
- Bump version to 0.1.1.0
```

#### Pull Request Process

1. Update CHANGELOG.md with your changes
2. Ensure the build succeeds: `swift build`
3. Update README.md if adding user-facing features
4. Submit PR with clear description
5. Respond to review feedback

## Code Style Guidelines

### Swift Conventions

- Use Swift 5.9+ features appropriately
- Follow Swift API Design Guidelines
- Use `// MARK: -` for logical sections
- Prefer `guard` for early exits
- Use meaningful variable names

### Formatting

```swift
// Good
func processApplication(at path: String) -> Result<AppInfo, Error> {
    guard FileManager.default.fileExists(atPath: path) else {
        return .failure(AppError.notFound)
    }
    // ...
}

// Avoid
func process(_ p: String) -> Result<AppInfo, Error> {
    if !FileManager.default.fileExists(atPath: p) {
        return .failure(AppError.notFound)
    }
    // ...
}
```

### Documentation

- Add comments for complex logic
- Update README for user-facing changes
- Document public APIs
- Keep CLAUDE.md updated for AI assistants

## Security Guidelines

This tool has system-level access. Security is critical:

1. **Never execute untrusted code**
2. **Always sanitize inputs** for AppleScript
3. **Use hardcoded paths** for system binaries
4. **Validate all file paths**
5. **Report security issues privately** (see SECURITY.md)

## Testing

Currently, testing is manual. When testing your changes:

1. Test with various application types:
   - Apple system apps
   - Third-party apps
   - Apps with special characters in names

2. Test edge cases:
   - Missing Info.plist
   - Permission denied
   - Claude CLI unavailable
   - Existing Finder comments

3. Verify no regressions in existing functionality

## Questions?

Feel free to open an issue for questions about contributing.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
