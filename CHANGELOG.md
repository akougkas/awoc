# AWOC Changelog

All notable changes to AWOC will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-07 - Initial MVP Release

### Added
- **Core Framework**: Basic AWOC directory structure and configuration
- **Agent System**: api-researcher agent for technical documentation research
- **Session Management**: session-start and session-end commands for clean workflows
- **Output Styles**: development mode for consistent coding standards
- **Installation**: Automated installer with CLI detection (Claude Code, OpenCode, Gemini CLI)
- **Validation**: Installation verification script
- **Documentation**: Comprehensive README with quick start guide
- **Security**: Granular permissions model with allow/deny/ask patterns
- **Git Integration**: Native git workflow support with clean state management

### Technical Details
- Minimal viable product with single agent focus
- JSON-based configuration with local overrides
- Markdown-based agent and command definitions
- Cross-platform bash scripts for installation
- Comprehensive .gitignore for development environments

### Known Limitations
- Single agent (api-researcher) - multi-agent orchestration planned
- Basic session management - advanced workflows in development
- No plugin ecosystem yet - planned for future releases

### Next Steps
- Add code-architect agent for system design
- Implement multi-agent orchestration
- Add more output styles for different development contexts
- Create plugin system for extensibility