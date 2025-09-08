---
name: dev-start
description: Quick development session startup with context priming
argument-hint: [task-description]
allowed-tools: Read, Bash, Glob
---

## Development Session Start

### Git Status Check
!`git status -s`
!`if [ -n "$(git status --porcelain)" ]; then echo "⚠️ Uncommitted changes - review before starting"; fi`

### Load Project Context
@OPUS-PLAN.md
@CLAUDE.md (development guide)

### Prime Development Context
!`echo "Task: $ARGUMENTS"`

### Available Subagents
- `/agents architect` - Design & complex analysis (Opus)
- `/agents docs-fetcher` - Research & examples (Haiku+MCP) 
- `/agents workforce` - Code generation (Sonnet)

### Quick Commands
- `./validate.sh` - Health check
- `/context` - Token usage
- `/agents list` - Show available agents

**Ready for development on: $ARGUMENTS**