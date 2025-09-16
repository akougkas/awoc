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
!`if [ -n "$(git status --porcelain)" ]; then`
!`    git add -A`
!`    if git commit -m "${ARGUMENTS:-Development session complete}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"; then`
!`        echo "✅ Changes committed successfully"`
!`    else`
!`        echo "❌ ERROR: Failed to commit changes"`
!`        echo "💡 TIP: Check git status and resolve any issues"`
!`        exit 1`
!`    fi`
!`else`
!`    echo "ℹ️  No changes to commit"`
!`fi`

### Verify Clean State
!`git status`

**Session complete:** Work committed, docs updated, ready for next development cycle.