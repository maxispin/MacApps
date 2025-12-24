# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Security Considerations

MacApps is a command-line tool that interacts with system files and executes AppleScript. We take security seriously.

### What MacApps Does

- **Reads**: Application metadata (Info.plist files)
- **Writes**: Finder comments only
- **Executes**: AppleScript via `/usr/bin/osascript`
- **External calls**: Claude CLI for AI descriptions

### What MacApps Does NOT Do

- Execute application code
- Modify application files
- Store or transmit credentials
- Access network directly (only via Claude CLI)
- Run with elevated privileges

## Security Design

### Input Sanitization

All user-controllable input is sanitized before use in AppleScript:

```swift
// Quotes are escaped to prevent injection
let escapedComment = comment.replacingOccurrences(of: "\"", with: "\\\"")
```

### Hardcoded Paths

System binaries use absolute paths:
- `/usr/bin/osascript` for AppleScript
- `/usr/bin/which` for path resolution

### No Credential Storage

Authentication is delegated entirely to Claude CLI. MacApps never handles API keys or tokens.

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **Do NOT** open a public issue
2. Email the maintainers directly (if contact available)
3. Or open a private security advisory on GitHub

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 1 week
- **Fix timeline**: Depends on severity

### Severity Levels

| Severity | Description | Response |
|----------|-------------|----------|
| Critical | Code execution, privilege escalation | Immediate patch |
| High | Data exposure, bypass security controls | Patch within 1 week |
| Medium | Limited impact vulnerabilities | Patch in next release |
| Low | Minor issues, hardening | Tracked for future |

## Security Best Practices for Users

1. **Review the source code** before running
2. **Grant minimal permissions** when prompted
3. **Run in user context** - never run as root
4. **Keep Claude CLI updated** for latest security patches
5. **Review generated descriptions** before trusting

## Audit Trail

The tool outputs progress to stdout. For auditing:

```bash
# Log output to file
swift run 2>&1 | tee macapps-$(date +%Y%m%d).log
```

## Known Limitations

1. **AppleScript Injection**: While we escape quotes, extremely malformed app names could potentially cause issues. We recommend reviewing `/Applications` for suspicious entries before running.

2. **Claude CLI Trust**: We trust Claude CLI's security model. Ensure you're using an official Claude CLI installation.

3. **Finder Comment Visibility**: Finder comments are not encrypted and are visible to all users with file access.

## Changelog

Security-related changes are marked with `### Security` in CHANGELOG.md.
