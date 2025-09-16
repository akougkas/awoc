# AGENTS.md - AI Agent Instructions for AWOC

> This file provides context and instructions for AI coding assistants working with the AWOC codebase.

## Project Overview

AWOC (Agentic Workflows Orchestration Cabinet) is a framework that enhances AI coding assistants with specialized agents, smart workflows, and context-aware orchestration. It deploys configurations to project directories as `.claude`, `.gemini`, or `.codex` folders.

## Core Architecture

```
awoc/                      # Repository root
├── agents/               # Agent definitions (Markdown with YAML frontmatter)
├── commands/             # Slash commands for AI assistants
│   └── priming/         # Context priming commands
├── domains/              # Community domain packs
│   ├── coding/          # Programming enhancements
│   └── writing/         # Content creation tools
├── scripts/              # Utility bash scripts
├── templates/            # Agent and command templates
├── awoc                  # Main CLI script (no longer missing!)
├── install.sh            # System installer
└── settings.json         # Configuration template
```

## Key Development Patterns

### Agent Creation
Agents are Markdown files with YAML frontmatter:
```yaml
---
name: agent-name
type: specialized
domain: optional-domain
---
# Agent instructions...
```

### Command Structure
Commands follow Claude Code's slash command format:
```markdown
---
name: command-name
allowed-tools: Bash, Read, Task
---
# Command implementation
```

### Settings Format (2025)
Use new hooks format with matchers:
```json
"PreToolUse": [{
  "matcher": {},
  "hooks": [{"type": "command", "command": "script.sh"}]
}]
```

## Testing Workflow

1. **Never edit test directories directly** - Always fix in source
2. **Use reinstall for updates**: `awoc install -d /path -f`
3. **Validate after changes**: `awoc validate -d .`
4. **Test in Claude Code**: Open directory and run `/awoc-help`

## Common Tasks

### Adding a New Agent
1. Create `agents/your-agent.md`
2. Test with `awoc validate`
3. Deploy with `awoc install -d test-dir`
4. Test in AI assistant

### Fixing Installation Issues
1. Edit source files (not deployed copies)
2. Run `./install.sh` to update global installation
3. Use `awoc install -d target -f` to force update
4. Check with `/doctor` in Claude Code

### Creating Domain Packs
1. Create directory: `domains/your-domain/`
2. Add specialized agents and commands
3. Test thoroughly in real projects
4. Document with README.md in your domain folder
5. Submit PR to share with community

Current domains:
- `coding/` - Programming-specific tools
- `writing/` - Content creation workflows

## Important Conventions

- **Incremental Development**: One feature at a time
- **Test Everything**: Use `validate.sh` after every change
- **Document Honestly**: Update FEATURES.md with real status
- **No Sudo Required**: Everything installs to user space
- **Project-First**: Prefer project installations over global

## Token Optimization

AWOC aims for 70% token reduction through:
- Dynamic context priming (load on demand)
- Smart handoff bundles (compressed state)
- Hierarchical delegation (sub-agents)
- Intelligent caching (avoid redundant loads)

## MCP Integration (Future)

AWOC will integrate with Model Context Protocol:
- `awoc-context`: Project awareness server
- `awoc-memory`: Persistent session memory
- `awoc-templates`: Domain template server
- `awoc-orchestrator`: Multi-agent coordination

## Debug Commands

```bash
# Check installation
awoc validate -d .

# View agent token usage
grep -c "tokens" agents/*.md

# Test settings validity
jq '.hooks | keys' settings.json

# Check for issues
awoc doctor
```

## Contributing Guidelines

1. **Fix bugs first**: Stability over features
2. **Test thoroughly**: All changes must pass validation
3. **Document changes**: Update relevant docs
4. **Keep it simple**: Complex can wait
5. **Share successes**: Domain packs welcome

## Common Pitfalls

- ❌ Don't hardcode paths - Use dynamic detection
- ❌ Don't require sudo - User space only
- ❌ Don't break existing installs - Backward compatibility
- ❌ Don't skip validation - Test everything
- ❌ Don't edit test dirs - Fix source, reinstall

## Getting Help

- Check TROUBLESHOOTING.md for common issues
- Read CLAUDE.md for development guidance
- See FEATURES.md for capability status
- Run `awoc doctor` for diagnostics

---

*AGENTS.md follows the standard from https://agents.md - a simple format for guiding AI coding assistants*