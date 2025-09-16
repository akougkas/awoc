---
name: handoff-load  
description: Restore session context from handoff bundle
argument-hint: [bundle-id] [mode] [validation-level]
allowed-tools: Bash, Read
completion-instructions: |
  Restore complete or partial context from handoff bundle with validation,
  supporting flexible restoration modes and compatibility checks.
---

# Context Handoff Load

Restore session context from a previously saved handoff bundle.

## Parameters
- **bundle-id**: Bundle identifier or 'latest' for most recent - required
- **mode**: Restoration scope (full, session-only, context-only, agents-only) - default: full
- **validation**: Validation level (strict, basic, none) - default: strict

## Execution

### Load Handoff Bundle  
!`if [ ! -x "./scripts/handoff-manager.sh" ]; then`
!`    echo "❌ ERROR: Handoff manager script not found"`
!`    echo "💡 TIP: Ensure you're in the AWOC project directory"`
!`    echo "📖 HELP: Run from /path/to/awoc-claude-v2/"`
!`    exit 1`
!`fi`
!`./scripts/handoff-manager.sh load "${ARGUMENTS_0:-latest}" "${ARGUMENTS_1:-full}" "${ARGUMENTS_2:-strict}"`

## Restoration Modes

### Full Restoration (default)
Restores complete session state:
- Session metadata and timing
- Token usage and context state  
- Knowledge graph and discoveries
- Agent coordination and queues
- Project context and Git state

### Session-Only Restoration
Minimal restoration for quick recovery:
- Session identifier and timing
- Active agent state
- Basic project context
- Working directory alignment

### Context-Only Restoration  
Focus on context data:
- Token usage tracking
- File access history
- Tool usage statistics
- Threshold monitoring state

### Agents-Only Restoration
Agent coordination focus:
- Active agent states
- Task queue restoration  
- Performance metrics
- Sub-agent coordination

## Bundle Discovery

### By Identifier
```bash
# Specific bundle ID
/handoff-load 20250108_143022_abc12345

# Partial ID matching  
/handoff-load abc12345

# Date-based matching
/handoff-load 20250108
```

### Smart Selection
```bash
# Most recent bundle
/handoff-load latest

# Most recent emergency bundle
/handoff-load emergency

# Most recent of specific type
/handoff-load automatic
```

## Validation Levels

### Strict Validation (default)
- Complete JSON schema validation
- Bundle integrity verification
- Dependency availability checks
- Compatibility validation
- Version compatibility checks

### Basic Validation
- JSON structure validation
- Required field presence
- Basic integrity checks

### No Validation
- Direct restoration without checks
- Use only for trusted bundles
- Faster restoration time

## Restoration Process

1. **Bundle Discovery**: Locate bundle file by identifier
2. **Decompression**: Handle gzip/compressed bundles  
3. **Validation**: Verify bundle integrity and schema
4. **Context Restoration**: Apply selected restoration mode
5. **Integration**: Update active systems and monitors
6. **Verification**: Confirm successful restoration

## Performance Monitoring

Tracks restoration metrics:
- Load time (target: <3 seconds)
- Validation time
- Context integration success
- Compatibility warnings
- Performance impact

## Integration Points

### Context Systems
- **Context Monitor**: Updates current usage state
- **Token Logger**: Restores attribution tracking
- **Session Tracking**: Continues session state
- **Agent Orchestration**: Restores coordination

### Validation Checks  
- Working directory compatibility
- Git state alignment  
- File dependency availability
- AWOC version compatibility
- Claude Code integration

## Output Examples

### Successful Restoration
```
🔄 Restoring full context from handoff bundle...
• Restoring session state...
• Restoring context usage data...  
• Restoring agent coordination state...
✅ Full context restoration completed

Context Restoration Summary
==========================
Bundle ID: 20250108_143022_abc12345
Created: 2025-01-08T14:30:22Z
Type: manual
Restore Mode: full
Context Tokens: 15420
Session Duration: 1847s
```

### Compatibility Warnings
```
⚠️  Working directory changed: /old/path → /new/path
⚠️  Git branch changed: feature-x → main
ℹ️  Context restored with minor adjustments
```

## Error Recovery

### Bundle Not Found
- Search across all storage locations
- Suggest similar bundle IDs
- List available alternatives

### Validation Failures
- Detailed error reporting
- Fallback to basic validation
- Partial restoration options

### Compatibility Issues
- Version mismatch handling
- Migration assistance
- Graceful degradation

## Usage Examples

```bash
# Standard restoration
/handoff-load latest

# Emergency recovery
/handoff-load emergency full strict

# Quick session recovery
/handoff-load latest session-only basic

# Context data only
/handoff-load abc12345 context-only

# Agent state restoration
/handoff-load 20250108_143022_abc12345 agents-only
```

---

*This command enables seamless session continuity in the AWOC 1.3 Context Engineering Framework*