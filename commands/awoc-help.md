---
name: awoc-help
description: Show AWOC 2.0 command reference and usage guide
allowed-tools: Bash, Read
---

# AWOC 2.0 Command Reference

## Session Management
### `/session-start [task-description]`
Initialize development session with clean state
- ✅ Validates git status  
- 📋 Loads project context
- 🤖 Shows available subagents

### `/session-end [what-was-accomplished]` 
Clean up and commit session work
- 📝 Updates documentation
- 💾 Commits changes with proper format
- ✅ Verifies clean state

## Context Priming
### `/prime-dev [scenario] [budget]`
Load development context dynamically
- **Scenarios**: bug-fixing, feature-dev, research, api-integration
- **Default budget**: 3000 tokens
- **Example**: `/prime-dev bug-fixing 2500`

### `/list-priming`
Show all available priming scenarios with usage examples

## Handoff Protocol
### `/handoff-save [type] [compression] [priority]`
Create context handoff bundle for session continuity
- **Types**: manual (default), automatic, emergency, scheduled
- **Compression**: gzip (default), none
- **Priority**: low, medium (default), high, critical

### `/handoff-load [bundle-id] [mode] [validation]`
Restore session context from handoff bundle  
- **Bundle ID**: Specific ID or 'latest' for most recent
- **Modes**: full (default), session-only, context-only, agents-only
- **Validation**: strict (default), basic, none

## Emergency Recovery
### `/recover [recovery-type] [optimization-level]`
Emergency context overflow recovery and optimization
- **Types**: cascade (default), optimize, restart, emergency
- **Levels**: conservative, balanced (default), aggressive

## Current Status
### System Status
Context monitoring: !`if [ -f "$HOME/.awoc/context/current_session.json" ]; then echo "✅ Active"; else echo "❌ Not initialized"; fi`

Session tokens: !`if [ -f "$HOME/.awoc/context/current_session.json" ]; then jq -r '.current_tokens // "Unknown"' "$HOME/.awoc/context/current_session.json"; else echo "Not monitored"; fi`

### Available Subagents
- `/agents architect` - Design & complex analysis (Opus, 16k thinking)
- `/agents docs-fetcher` - Research & examples (Haiku+MCP)  
- `/agents workforce` - Code generation (Sonnet)

## Quick Start
```bash
# 1. Start development session
/session-start "Implement user authentication"

# 2. Load appropriate context
/prime-dev api-integration 3000

# 3. Use specialized agents
/agents architect "Design JWT authentication system"

# 4. End session and commit
/session-end "Added JWT authentication system with tests"
```

## Advanced Workflows
```bash
# Emergency recovery from context overflow
/recover cascade balanced

# Load previous work session  
/handoff-load latest full strict

# Research-focused session
/prime-dev research 4000
/agents docs-fetcher "Find React testing best practices"
```

## Troubleshooting

### Common Issues
**"Script not found" errors:**
- 💡 Ensure you're in the AWOC project directory
- 📖 Run commands from `/path/to/awoc-claude-v2/`

**Context monitoring not working:**
- 🔧 Run `./scripts/context-monitor.sh init` to initialize
- 📊 Check `~/.awoc/context/` directory exists

**Handoff bundles not loading:**
- 🔍 Run `./scripts/handoff-manager.sh list` to see available bundles
- 🛠️ Try `/recover` if bundles are corrupted

### Getting Help
- 📖 Read project documentation: `CLAUDE.md`, `OPUS-PLAN.md`
- 🔧 Run validation: `./validate.sh`
- 🧪 Test components: `./test-phase4-smart-context.sh`

---

**AWOC 2.0 Context Engineering Framework**  
*Intelligent orchestration through dynamic context management*