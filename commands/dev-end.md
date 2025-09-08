---
name: dev-end
description: Safe development session shutdown with commit and docs
argument-hint: [accomplishment-summary]
allowed-tools: Bash, Write, Edit, Read
---

## Development Session End

### Review Changes
!`git status -s`
!`git diff --stat`

### Update Documentation
!`if [ -f "CHANGELOG.md" ]; then echo "## $(date +%Y-%m-%d)\n- $ARGUMENTS\n$(cat CHANGELOG.md)" > CHANGELOG.md; fi`

### Commit Work
!`git add -A`
!`git commit -m "$ARGUMENTS

Development session complete - $(date)"`

### Verify Clean State
!`git status`

### Session Summary
**Completed**: $ARGUMENTS
**Status**: Repository clean, changes committed
**Next**: Ready for new development session

**Session end successful** ✅