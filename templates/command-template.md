---
name: command-name
description: Brief description of what this command does and when to use it
argument-hint: [command-description]
allowed-tools: Bash(git status), Read, Write
---

## [Command Display Name]

### Command Logic
[Brief description of what this command accomplishes]

### Git Integration
```bash
# Check repository state
!`git status -s`
!`git branch --show-current`
```

### Main Operations
```bash
# Core command functionality
[Tool operations for main work]

# Document results or changes
Write("output-file.md", results)
```

### Completion
**Command complete:** [Success message or next steps]

*Version: 1.0.0 | Last Updated: 2025-01-07 | Author: AWOC Team*