---
name: session-end
description: Clean up and commit session work
argument-hint: [what-was-accomplished]
allowed-tools: Bash(git status), Bash(git add), Bash(git commit), Write, Edit
---

## Session End

### Review Changes
Status: !`git status -s`
Changes: !`git diff --stat HEAD`

### Update Documentation
!`if [ -f "CHANGELOG.md" ]; then echo "## $(date +%Y-%m-%d)\n- $ARGUMENTS\n$(cat CHANGELOG.md)" > CHANGELOG.md; fi`

### Stage and Commit
!`git add -A`
!`git commit -m "$ARGUMENTS

Development session complete - $(date)"`

### Verify Clean State
!`git status`

**Session complete:** Work committed, docs updated, ready for next development cycle.