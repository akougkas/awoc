# AWOC 2.0 - Developer Documentation

## Project Status: Partially Implemented

AWOC is a working agent orchestration system with ambitious plans for context-aware features. Currently, the **basic agents work reliably**, while advanced features are experimental.

## What Actually Works ✅

### Core Features (Reliable)
- **6 Specialized Agents**: All work as intended
  - api-researcher, content-writer, data-analyst
  - project-manager, learning-assistant, creative-assistant
- **Basic Commands**: `/awoc-help`, `./validate.sh`, `./install.sh`
- **Session Management**: Works with clean git state
- **Installation**: Auto-detects Claude/OpenCode/Gemini

### What to Use
```bash
# These work reliably:
"Use api-researcher to explain OAuth2"
"Use content-writer to create documentation"
"Use data-analyst to analyze data.csv"
/awoc-help  # In AI CLI
./validate.sh  # From ~/.awoc directory
```

## What's Experimental ⚠️

### Partially Working
- **Context Recovery** (`/recover`) - Basic functionality only
- **Handoff System** - Save/load may not persist properly
- **Context Priming** - Commands exist but limited effect

### Not Yet Functional
- Context prediction/learning
- Background task processing
- True parallel agent execution
- Enterprise features

## Repository Structure

```
awoc-claude-v2/
├── agents/            # 6 working AI agents (✅ stable)
├── commands/          # Mix of working and experimental
│   ├── awoc-help.md   # ✅ Works
│   ├── session-*.md   # ✅ Works with git
│   ├── recover.md     # ⚠️ Experimental
│   ├── handoff-*.md   # ⚠️ Experimental
│   └── priming/       # ⚠️ Limited effect
├── scripts/           # Mix of working and placeholder
│   ├── validate.sh    # ✅ Works
│   ├── install.sh     # ✅ Works
│   └── [others]       # ⚠️ Various states
├── QUICKSTART.md      # ✅ User guide - accurate
├── README.md          # ✅ User docs - simplified
├── FEATURES.md        # ✅ Honest feature status
├── TROUBLESHOOTING.md # ✅ Common fixes
└── settings.json      # Configuration file
```

## Development Guidelines

### For Contributors

#### Working on Core Features
If improving basic agents or commands:
```bash
# 1. Test current behavior
./validate.sh

# 2. Make small changes
# Edit agents/*.md or commands/awoc-help.md

# 3. Test immediately
./validate.sh

# 4. Document honestly
# Update FEATURES.md with actual status
```

#### Working on Experimental Features
If trying to fix context management or advanced features:
```bash
# 1. Understand current state
grep -r "TODO\|FIXME\|XXX" .

# 2. Pick ONE feature to fix
# Don't try to fix everything

# 3. Test thoroughly
# Create specific test cases

# 4. Update documentation
# Move from "experimental" to "working" in FEATURES.md
```

### Code Quality Standards

#### Must Have
- ✅ Error handling in all scripts
- ✅ Input validation/sanitization
- ✅ Work with existing installations
- ✅ Clear error messages

#### Should Have
- Pass `shellcheck` for bash scripts
- Validate JSON with `jq`
- Helpful comments in complex sections
- Update relevant documentation

#### Nice to Have
- Unit tests for new features
- Performance benchmarks
- Migration scripts for breaking changes

## Technical Details

### How Agents Work
Agents are Markdown files with YAML frontmatter that define specialized behaviors:
```markdown
---
name: api-researcher
type: specialized
---
# Instructions for the agent...
```

### How Commands Work
Commands are Markdown files that Claude Code loads as slash commands:
```markdown
---
name: awoc-help
allowed-tools: Bash, Read
---
# Command implementation...
```

### Settings Structure
`settings.json` defines configuration, though many features aren't connected:
```json
{
  "version": "2.0",
  "agents": { /* agent config */ },
  "context": { /* mostly unused */ }
}
```

## Current Development Priorities

### Priority 1: Maintain What Works
- Keep basic agents functioning
- Don't break existing installations
- Fix critical bugs in core features

### Priority 2: Improve Documentation
- Keep docs honest about what works
- Add more examples that actually work
- Improve troubleshooting guides

### Priority 3: Stabilize Experimental Features
- Pick ONE experimental feature
- Make it actually work
- Move to production status
- Repeat

### Not Priorities
- Adding more experimental features
- Complex multi-agent orchestration
- Enterprise features
- Complete rewrites

## Testing Checklist

Before committing changes:
```bash
# 1. Basic validation passes
./validate.sh

# 2. Agents still work
echo "Use api-researcher to explain REST APIs" | Check output is relevant

# 3. Help is accessible
/awoc-help  # Shows help

# 4. Installation works
./install.sh  # Doesn't break

# 5. Documentation is accurate
# Update FEATURES.md if feature status changed
```

## Known Issues

### Won't Fix (By Design)
- Agents don't remember context - stateless by design
- Session commands require git - intentional for tracking
- Some scripts are placeholders - gradual implementation

### Should Fix
- Handoff system doesn't reliably persist
- Context recovery is too basic
- Many scripts aren't integrated
- Token monitoring incomplete

### Want to Fix (Eventually)
- True parallel agent execution
- Context learning from patterns
- Background task processing
- Enterprise policy support

## Quick Reference for Developers

### Find Work to Do
```bash
# Find TODOs
grep -r "TODO\|FIXME" . --include="*.sh" --include="*.md"

# Find experimental features
grep -r "experimental\|alpha\|beta" commands/

# Find disconnected scripts
grep -l "Not yet integrated" scripts/*.sh
```

### Test Your Changes
```bash
# Quick test
./validate.sh

# Full test
./install.sh && ./validate.sh

# Manual test
"Use api-researcher to test something"
```

### Update Documentation
When changing feature status:
1. Update `FEATURES.md` - Feature reliability matrix
2. Update `TROUBLESHOOTING.md` - If fixing an issue
3. Update `QUICKSTART.md` - If changing basic usage
4. Update this file - If changing development approach

## Development & Debug Workflow

### The Fix-Ship-Test Cycle

When users report issues (like the hooks format problem):

#### 1. Understand the Environment
```bash
# Two key directories:
# Repository: /home/akougkas/projects/awoc-claude-v2  (source code)
# Test: /tmp/awoc-testing                            (deployed instance)
```

#### 2. Fix in Repository
Always fix issues in the source repository, never in test directories:
```bash
# Fix the source files
edit settings.json      # Fix configuration issues
edit awoc              # Update CLI logic
edit install.sh        # Improve installation
```

#### 3. Smart Reinstallation
The `awoc` CLI now supports intelligent reinstallation:
```bash
# Automatic fix propagation on reinstall
awoc install -d /tmp/awoc-testing    # Auto-updates settings on reinstall

# Force update for stubborn issues
awoc install -d /tmp/awoc-testing -f # Force replaces settings
```

#### 4. Test Without Cheating
- NEVER manually edit files in test directories
- If installer doesn't propagate fixes, FIX THE INSTALLER
- Keep the development cycle clean and reproducible

### Key Lessons Learned

#### Hooks Format Evolution (September 2025)
Claude Code changed hooks format from simple strings to matcher objects:
```json
// Old (broken):
"PreToolUse": ["command.sh"]

// New (working):
"PreToolUse": [{
  "matcher": {},
  "hooks": [{"type": "command", "command": "command.sh"}]
}]
```

#### Installer Intelligence
The `awoc` installer now detects reinstallations via `.awoc` marker files and automatically updates settings.json to ensure fixes propagate to users.

## MCP Integration Opportunities

AWOC can leverage Model Context Protocol (MCP) for enhanced capabilities:

### Current MCP Ecosystem
- **context7**: Provides real-time, version-specific documentation
- **claude-context**: Makes entire codebase searchable context
- **Enterprise MCP**: Microsoft and others building A2A protocols

### Future AWOC+MCP Integration
```yaml
Potential MCP Servers for AWOC:
- awoc-context: Full project awareness server
- awoc-orchestrator: Multi-agent coordination via MCP
- awoc-memory: Persistent context across sessions
- awoc-templates: Domain-specific template server
- awoc-domains: Serve domain packs dynamically
```

## Domain Packs Structure

AWOC now includes a `domains/` directory for community contributions:
```
domains/
├── coding/       # Programming-specific enhancements
├── writing/      # Content creation tools
└── [your-domain] # Your specialized configurations
```

Each domain can contain agents, commands, and workflows tailored to specific fields.

## Philosophy

**Keep it honest**: Document what actually works, not what we hope will work.

**Incremental progress**: One working feature is better than ten broken ones.

**User-first**: If users can't use it easily, it doesn't matter how clever it is.

**Simplicity wins**: Complex orchestration can wait. Make basics rock-solid first.

**Community-driven**: The best features come from real users solving real problems.

---

Remember: **AWOC's basic agents work great. Focus on keeping them great while slowly improving the rest.**