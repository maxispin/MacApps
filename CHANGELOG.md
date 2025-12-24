# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with four levels: `MAJOR.MINOR.PATCH.BUILD`.

## [Unreleased]

## [0.1.1.0] - 2024-12-24

### Changed
- **License**: Changed from MIT to Proprietary (All Rights Reserved)
- Updated README.md for commercial App Store distribution
- Updated CONTRIBUTING.md to reflect proprietary model

### Added
- **EULA.md**: End User License Agreement for App Store distribution
  - Apple-specific terms and conditions
  - Third-party service disclosures (Claude CLI)
  - Warranty disclaimers and liability limitations
- **PRIVACY.md**: Privacy Policy for App Store compliance
  - GDPR-compliant disclosures
  - App Store privacy nutrition label data
  - Third-party service (Claude CLI) data handling
- Proprietary license with full rights reservation
- Legal section in README with links to all policies

### Security
- Added comprehensive privacy disclosures
- Documented data handling practices
- Added App Store privacy compliance information

## [0.1.0.0] - 2024-12-24

### Added
- Initial release of MacApps
- Application scanning for `/Applications` directory
- Claude CLI integration for generating app descriptions
- Finder comment writing via AppleScript
- Skip logic for apps with existing comments
- Bundle identifier extraction from Info.plist
- Multiple Claude CLI path detection
- Progress tracking with emoji indicators
- Summary statistics after processing
- Comprehensive documentation:
  - README.md with full usage instructions
  - CLAUDE.md for AI assistant guidelines
  - LICENSE (MIT - later changed)
  - CHANGELOG.md (this file)
  - CONTRIBUTING.md guidelines
  - SECURITY.md policy

### Security
- Input sanitization for AppleScript strings
- Hardcoded paths for system binaries
- No credential storage
- Read-only file operations (except Finder comments)

---

## Version History Summary

| Version | Date | Description |
|---------|------|-------------|
| 0.1.1.0 | 2024-12-24 | App Store preparation: Proprietary license, EULA, Privacy Policy |
| 0.1.0.0 | 2024-12-24 | Initial public release |

---

## Versioning Scheme

- **MAJOR.MINOR.PATCH.BUILD**
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes
- BUILD: Incremented on every commit
