---
name: session-start
description: Initialize development session with clean state
argument-hint: [task-description]
allowed-tools: Bash, Read
---

## Session Start

### Git State Check
Current branch: !`git branch --show-current`
Status: !`git status -s`

### Verify Clean State
!`if [ -n "$(git status --porcelain)" ]; then echo "⚠️  Uncommitted changes detected - commit or stash first"; exit 1; fi`

### Load Context
@OPUS-PLAN.md (master implementation plan)
@CLAUDE.md (development guide)

### Available Subagents
- `/agents architect` - Design & complex analysis (Opus, 16k thinking)
- `/agents docs-fetcher` - Research & examples (Haiku+MCP)
- `/agents workforce` - Code generation (Sonnet)

### Session Task
$ARGUMENTS

### Ready to Begin
Repository clean. Subagents ready. Development session started.