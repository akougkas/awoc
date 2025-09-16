---
name: awoc-help
description: Show AWOC command reference and quick help
allowed-tools: Bash, Read
---

# AWOC Help - Quick Reference

## 🚀 Quick Start Examples

### Basic Agent Usage
```bash
# Research and documentation
"Use api-researcher to explain OAuth2 flow"
"Use content-writer to create a user guide"

# Data analysis
"Use data-analyst to analyze metrics.csv"
"Use data-analyst to find patterns in logs"

# Project planning
"Use project-manager to break down this feature"
"Use learning-assistant to explain Docker"
```

## 📋 Available Agents

| Agent | Purpose | Example Usage |
|-------|---------|---------------|
| **api-researcher** | API docs & technical research | "Find Stripe payment examples" |
| **content-writer** | Documentation & guides | "Write README for this project" |
| **data-analyst** | Analyze CSV/JSON data | "Analyze error rates in logs" |
| **project-manager** | Task planning | "Create sprint tasks" |
| **learning-assistant** | Teaching & tutorials | "Explain React hooks" |
| **creative-assistant** | Brainstorming | "Suggest UI improvements" |

## 🛠️ Core Commands

### Session Management (Optional)
- `/session-start [description]` - Start tracking work
- `/session-end [summary]` - Save and commit work

### Help & Status
- `/awoc-help` - Show this help (you're here!)
- `./validate.sh` - Check system health (run from ~/.awoc)

### Recovery (If Needed)
- `/recover` - Fix context overflow issues
- `/handoff-save` - Save session for later
- `/handoff-load latest` - Resume previous work

## 💡 Common Workflows

### Starting a New Feature
```bash
# 1. Get research
"Use api-researcher to find best practices for user authentication"

# 2. Plan the work
"Use project-manager to create tasks for JWT authentication"

# 3. Document it
"Use content-writer to update the README with auth details"
```

### Analyzing Project Data
```bash
# For CSV files
"Use data-analyst to summarize data/sales.csv"
"Use data-analyst to find trends in metrics.csv"

# For logs
"Use data-analyst to analyze error patterns in app.log"
"Use data-analyst to create usage report from access.log"
```

### Learning Something New
```bash
"Use learning-assistant to explain microservices architecture"
"Use learning-assistant to create a study plan for Kubernetes"
"Use creative-assistant to suggest project ideas for learning Go"
```

## ❓ What to Do If...

### "Agent not found" error
```bash
# Use exact agent names:
✅ "Use api-researcher to..."
❌ "Use API agent to..."

# Check agents are installed:
ls ~/.claude/agents/  # Should show .md files
```

### Commands not working
```bash
# Slash commands (like /awoc-help) work in AI CLI
# Script commands need to run from AWOC directory:
cd ~/.awoc
./validate.sh  # This should work now
```

### Token/context limits hit
```bash
# Use the recover command:
/recover

# Or start fresh:
/session-end "Saving work"
/session-start "Continuing"
```

### Git errors with sessions
```bash
# Option 1: Don't use session commands (they're optional!)
# Just use agents directly without /session-start

# Option 2: Clean git state first:
git stash  # or git commit
/session-start "Now it works"
```

## 📊 System Status Check

Run validation to see what's working:
```bash
cd ~/.awoc && ./validate.sh
```

Expected output:
```
✅ Core files found
✅ All agents installed
✅ Commands available
✅ Scripts executable
```

## 🎯 Tips for Success

### DO:
- ✅ Use agent exact names (api-researcher, not "API agent")
- ✅ Be specific about what you want
- ✅ Run validate.sh if something seems wrong
- ✅ Check QUICKSTART.md for more examples

### DON'T:
- ❌ Overcomplicate - start with basic agent usage
- ❌ Skip validation when things break
- ❌ Use agents outside their specialty

## 📚 More Resources

- **Quick examples**: See `QUICKSTART.md` in the AWOC directory
- **Full docs**: Check `README.md` for complete details
- **Troubleshooting**: Run `./validate.sh` for system check

## 🔧 Advanced Features (Optional)

### Context Priming (Experimental)
Load specialized context for specific tasks:
- `/prime-dev bug-fixing` - Load debugging context
- `/prime-dev feature-dev` - Load development context
- `/prime-dev research` - Load research context

### Delegation (Experimental)
Create sub-agents for parallel work:
- `/delegate [task]` - Delegate to sub-agent
- `/create-subagent [type]` - Create custom sub-agent

**Note**: These are experimental. Stick to basic agents for reliable results.

---

**Need more help?**
- Check `QUICKSTART.md` for interactive examples
- Run `./validate.sh` to diagnose issues
- Use basic agents - they're simple and they work!

*AWOC: Making AI assistants more capable, one agent at a time.*