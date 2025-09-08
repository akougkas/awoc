---
name: prime-dev
description: Dynamic context priming for development scenarios
argument-hint: [scenario] [budget]
allowed-tools: Bash, Read
---

## Dynamic Context Priming System

### Pre-Priming Context Check
Current context usage: !`if [ -f "$HOME/.awoc/context/current_session.json" ]; then jq -r '.current_tokens // "Unknown"' "$HOME/.awoc/context/current_session.json"; else echo "Not monitored"; fi` tokens

### Scenario Selection
Available scenarios:
- `bug-fixing` - Bug investigation and resolution context
- `feature-dev` - Feature development and implementation context  
- `research` - Research and investigation context
- `api-integration` - API integration and documentation context

### Arguments Processing
Scenario: `$ARGUMENTS_0` (default: feature-dev)
Token Budget: `$ARGUMENTS_1` (default: 3000)

### Context Loading
!`SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`
!`SCENARIO="${ARGUMENTS_0:-feature-dev}"`
!`BUDGET="${ARGUMENTS_1:-3000}"`

### Validate Scenario
!`PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"`
!`if [ ! -f "$PROJECT_ROOT/.claude/commands/priming/prime-$SCENARIO.md" ]; then echo "❌ Invalid scenario: $SCENARIO"; echo "Available: bug-fixing, feature-dev, research, api-integration"; exit 1; fi`

### Check Token Budget
!`if command -v jq >/dev/null && [ -f "$HOME/.awoc/context/current_session.json" ]; then CURRENT=$(jq -r '.current_tokens // 0' "$HOME/.awoc/context/current_session.json"); if [ "$CURRENT" -gt 0 ] && [ $((CURRENT + BUDGET)) -gt 180000 ]; then echo "⚠️  Budget check: Adding $BUDGET tokens would exceed safe limits (current: $CURRENT)"; echo "Consider using a smaller budget or optimizing current context"; fi; fi`

### Load Scenario Context
Loading scenario: **$SCENARIO** with budget: **$BUDGET** tokens

!`cat "$PROJECT_ROOT/.claude/commands/priming/prime-$SCENARIO.md"`

### Update Context Tracking
!`if [ -f "$PROJECT_ROOT/scripts/context-monitor.sh" ]; then "$PROJECT_ROOT/scripts/context-monitor.sh" log_priming "$SCENARIO" "$BUDGET" 2>/dev/null || echo "Context monitoring logged"; fi`

### Post-Priming Status
Context after priming: !`if [ -f "$HOME/.awoc/context/current_session.json" ]; then jq -r '.current_tokens // "Unknown"' "$HOME/.awoc/context/current_session.json"; else echo "Not monitored"; fi` tokens

### Ready for Development
✅ Context primed for **$SCENARIO** development
🎯 Focus: Scenario-specific patterns and best practices loaded
⚡ Enhanced capabilities activated for current task type