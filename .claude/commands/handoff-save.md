---
name: handoff-save
description: Create context handoff bundle for session continuity
argument-hint: [type] [compression] [priority]
allowed-tools: Bash, Write
completion-instructions: |
  Create comprehensive context handoff bundle capturing current session state,
  token usage, knowledge graph, and agent coordination for seamless recovery.
---

# Context Handoff Save

Create a complete context handoff bundle for session continuity and recovery.

## Parameters
- **type**: Bundle type (manual, automatic, emergency, scheduled) - default: manual
- **compression**: Compression method (gzip, none) - default: gzip  
- **priority**: Storage priority (low, medium, high, critical) - default: medium

## Execution

### Initialize Handoff System
!`if [ ! -x "./scripts/handoff-manager.sh" ]; then`
!`    echo "❌ ERROR: Handoff manager script not found"`
!`    echo "💡 TIP: Ensure you're in the AWOC project directory"`
!`    echo "📖 HELP: Run from /path/to/awoc-claude-v2/"`
!`    exit 1`
!`fi`
!`./scripts/handoff-manager.sh init`

### Create Handoff Bundle
!`./scripts/handoff-manager.sh save "${ARGUMENTS_0:-manual}" "${ARGUMENTS_1:-gzip}" "${ARGUMENTS_2:-medium}"`

## Bundle Contents

The handoff bundle captures:

### Session Metadata
- Unique session identifier
- Timestamp and duration
- Active agent state
- Project context and Git state

### Context Usage
- Token consumption tracking
- File access history  
- Search patterns performed
- Tool usage statistics

### Knowledge Graph
- Discoveries and patterns identified
- Decisions made and rationale
- Learning outcomes and insights
- Cross-project connections

### Agent Coordination
- Active and suspended agents
- Sub-agent task queues
- Background process states
- Performance metrics

### Recovery Metadata
- Bundle integrity validation
- Dependency tracking
- Compatibility information
- Restoration instructions

## Performance Monitoring

The system tracks:
- Bundle creation time (target: <5 seconds)
- Bundle size (target: <50MB)
- Compression efficiency
- Validation success rate

## Usage Examples

```bash
# Manual handoff (interactive session end)
/handoff-save manual gzip medium

# Automatic handoff (scheduled or threshold-based)
/handoff-save automatic gzip high  

# Emergency handoff (context overflow)
/handoff-save emergency gzip critical

# Scheduled handoff (periodic backup)
/handoff-save scheduled gzip low
```

## Integration Points

- **Context Monitor**: Real-time token usage data
- **Token Logger**: Detailed attribution tracking  
- **Agent Orchestration**: Active coordination state
- **Priming System**: Scenario loading state
- **Settings Hooks**: Automatic trigger integration

## Output

Returns bundle identifier for future restoration:
```
✅ Handoff bundle created: 20250108_143022_abc12345
```

Bundle stored in: `~/.awoc/handoffs/active/`

## Error Handling

- Schema validation ensures bundle integrity
- Compression fallback if algorithm fails
- Performance warnings if thresholds exceeded
- Atomic operations prevent partial saves
- Emergency storage for critical situations

---

*This command is part of the AWOC 1.3 Context Engineering Framework*