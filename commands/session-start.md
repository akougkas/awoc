---
name: session-start
description: Initialize development session with clean state
argument-hint: [task-description]
allowed-tools: Bash(git status), Bash(git branch), Read
---

## Session Start

### Git State Check
Current branch: !`git branch --show-current`
Status: !`git status -s`

### Verify Clean State
!`if [ -n "$(git status --porcelain)" ]; then echo "⚠️  Uncommitted changes detected - commit or stash first"; exit 1; fi`

### Load Context
@README.md (project overview)

### Session Task
$ARGUMENTS

### Ready to Begin
Repository is clean and ready for development.