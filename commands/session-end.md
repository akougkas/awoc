---
name: session-end
description: Clean up and commit session work
argument-hint: [what-was-accomplished]
allowed-tools: Bash(git status), Bash(git add), Bash(git commit), Write
---

## Session End

### Review Changes
Status: !`git status -s`
Changes: !`git diff --stat HEAD`

### Stage and Commit
!`git add -A`

Create commit:
!`git commit -m "$ARGUMENTS

Session complete - repository in clean state"`

### Verify Clean State
!`git status`

**Session complete:** Ready for next development cycle.