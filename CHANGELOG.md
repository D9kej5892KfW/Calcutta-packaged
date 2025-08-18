# Changelog

All notable changes to the Claude Agent Telemetry project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.3] - 2025-08-18

### 📚 Documentation Updates - Installation Guide

#### Enhanced Installation Methods
- **Local Installation Method**: Added npx-based local installation as primary recommended method
- **Installation Guide Restructure**: Updated Quick Start section with three clear methods
- **Command Reference Updates**: Comprehensive command tables for local vs global installations
- **Troubleshooting Guidance**: Added guidance for "command not found" errors with global installations

#### Installation Methods Added
- **Method 1**: Local NPM installation with npx commands (now recommended)
- **Method 2**: Global NPM installation (alternative)
- **Method 3**: Direct repository installation (existing)

#### Command Documentation
- **npx Command Tables**: Complete reference for local installation users
- **Global Command Tables**: Reference for successful global installations
- **Session Management**: Updated to use npx prefix for reliability
- **Repository Commands**: Maintained npm run script references

#### User Experience Improvements
- **Reliability**: Local installation more reliable than global installation
- **No Global Permissions**: Local installation doesn't require global npm permissions
- **Troubleshooting**: Clear guidance when global installation fails

## [1.1.2] - 2025-08-17

### 🔧 Fixed - Documentation Template

#### Fixed Documentation Generation
- **CLAUDE.md Template**: Fixed outdated command paths in project documentation template
- **Command References**: Updated from `~/tools/agent-telemetry/scripts/` to `claude-telemetry` CLI commands
- **Session Commands**: Added new session management commands to documentation template
- **Installation References**: Updated installation details to reflect NPM package structure

#### Template Fixes
- Fixed `claude-telemetry dashboard` command (was `open http://localhost:3000`)
- Fixed `claude-telemetry status` command (was `~/tools/agent-telemetry/scripts/status.sh`)
- Fixed `claude-telemetry projects` command (was `~/tools/agent-telemetry/scripts/list-connected-projects.sh`)
- Fixed disconnect/connect commands to use new CLI syntax
- Added session management commands section

#### Updated References
- NPM Package reference updated to v1.1.2+
- Installation method now correctly shows global npm package
- Removed references to legacy `~/tools/agent-telemetry/` installation paths

## [1.1.0] - 2025-08-17

### 🆕 Added - Session Management System

**Major New Feature**: Central session tracking and orphaned process management

#### New Commands
- **`session-status`** - Show all active telemetry sessions with their processes and health status
- **`cleanup-orphaned`** - Detect and clean up orphaned processes from test installations  
- **`registry-repair`** - Synchronize registry with actual .claude configurations

#### Enhanced Registry Format
- **Process Tracking**: Track Loki and Grafana PIDs for each session
- **Installation Paths**: Know where each telemetry instance is installed
- **Session Grouping**: Group projects by shared Loki/Grafana instances
- **Health Status**: Track session health (active/degraded/failed)

#### Session Management Features
- **Central Process Tracking** - Know which Loki/Grafana serves which projects
- **Orphaned Process Detection** - Automatically find forgotten test installations
- **One-Command Cleanup** - Migrate projects from orphaned sessions to main installation
- **Registry Synchronization** - Keep tracking in sync with actual .claude configurations
- **Health Monitoring** - Color-coded session status indicators

#### NPM Script Integration
- `npm run session-status` - Check session health
- `npm run cleanup-orphaned` - Clean up orphaned processes
- `npm run registry-repair` - Repair registry sync

#### CLI Enhancements
- **Dry-run support** for all session management commands (`--dry-run`)
- **Verbose output** for detailed debugging (`--verbose`)
- **Force operations** for automated scripts (`--force`)
- **Orphaned filtering** to focus on problem sessions (`--orphaned`)

### 📚 Documentation
- **Comprehensive README updates** with session management documentation
- **Usage examples** for all new commands
- **Troubleshooting section** for session management issues
- **Architecture documentation** for enhanced registry format

### 🛠️ Technical Improvements
- **Enhanced registry migration** with automatic backup and validation
- **Process detection algorithms** to identify running Loki/Grafana instances  
- **Session health scoring** with degradation detection
- **Installation path tracking** to identify orphaned vs. main installations

### 🔧 Internal Changes
- **Registry helper functions** for consistent data manipulation
- **Unified logging** across all session management scripts
- **Error handling** with graceful degradation and recovery
- **Configuration validation** for registry consistency

### 🎯 Problem Solved
This release directly addresses the issue of losing track of orphaned telemetry processes from test installations (like `/tmp/test-claude-telemetry-local/`). Users can now:

1. **See all active sessions**: `npm run session-status`
2. **Clean up orphaned processes**: `npm run cleanup-orphaned` 
3. **Keep registry in sync**: `npm run registry-repair`

## [1.0.8] - 2025-08-16

### Fixed
- Version synchronization across package components
- CLI version display accuracy

### Changed
- Updated package version to 1.0.8
- Improved NPM package compatibility

## [1.0.7] - 2025-08-16

### Fixed
- Critical stop command functionality
- Comprehensive cleanup documentation
- CLI version display issues

### Added
- Enhanced stop command reliability
- Better error handling for service shutdown
- Improved cleanup procedures

## [1.0.6] - 2025-08-13

### Added
- Comprehensive project connection documentation
- Enhanced README with detailed setup instructions
- Project connection workflow improvements

### Fixed
- Project connection reliability
- Documentation accuracy and completeness

---

## Upgrade Guide

### From 1.0.x to 1.1.0

The 1.1.0 upgrade is **fully backward compatible**. Your existing projects and telemetry data will continue to work unchanged.

#### Automatic Migration
- Registry format is automatically migrated on first use of session commands
- Existing project connections remain functional
- No manual intervention required

#### New Features Available
After upgrading, you can immediately use:

```bash
# Check your current telemetry sessions
npx claude-telemetry session-status

# Clean up any orphaned processes  
npx claude-telemetry cleanup-orphaned --dry-run
npx claude-telemetry cleanup-orphaned

# Repair registry if needed
npx claude-telemetry registry-repair
```

#### Breaking Changes
- **None** - Full backward compatibility maintained

#### Recommended Actions After Upgrade
1. Run `npx claude-telemetry session-status` to see your current setup
2. If you have orphaned processes, run `npx claude-telemetry cleanup-orphaned`
3. Use `npx claude-telemetry registry-repair` if registry gets out of sync

---

## Support

- **Issues**: [GitHub Issues](https://github.com/D9kej5892KfW/Calcutta-npm/issues)
- **Documentation**: See README.md for comprehensive usage guide
- **Session Management**: New troubleshooting section in README.md