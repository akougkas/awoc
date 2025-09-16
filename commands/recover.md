---
name: recover
description: Emergency context recovery from overflow or corruption
argument-hint: [strategy] [target-tokens] [preserve-level]
allowed-tools: Bash, Write, Read, Task
---

# Emergency Context Recovery Command

## Validate Recovery Strategy
```bash
# Set defaults for recovery strategy
STRATEGY="${1:-cascade}"
TARGET_TOKENS="${2:-50000}"
PRESERVE_LEVEL="${3:-essential}"

# Validate recovery strategy
case "$STRATEGY" in
  cascade|fresh|minimal|hybrid)
    echo "🚨 Emergency Recovery Initiated"
    echo "   Strategy: $STRATEGY"
    echo "   Target tokens: $TARGET_TOKENS"
    echo "   Preserve level: $PRESERVE_LEVEL"
    ;;
  *)
    echo "❌ Invalid recovery strategy: $STRATEGY"
    echo "Valid strategies: cascade, fresh, minimal, hybrid"
    exit 1
    ;;
esac

# Validate preserve level
case "$PRESERVE_LEVEL" in
  essential|important|full|none)
    echo "✓ Preservation level validated"
    ;;
  *)
    echo "❌ Invalid preserve level: $PRESERVE_LEVEL"
    echo "Valid levels: essential, important, full, none"
    exit 1
    ;;
esac
```

## Emergency Context Assessment
```bash
echo ""
echo "🔍 Assessing current context state..."

# Get current context usage
if CONTEXT_INFO=$("$PROJECT_ROOT/scripts/context-monitor.sh" status emergency 2>/dev/null); then
    echo "📊 Current Context Status:"
    echo "$CONTEXT_INFO" | while IFS= read -r line; do
        echo "   $line"
    done
    
    # Extract critical metrics
    CURRENT_TOKENS=$(echo "$CONTEXT_INFO" | grep -oP 'tokens_used:\s*\K\d+' || echo "unknown")
    THRESHOLD=$(echo "$CONTEXT_INFO" | grep -oP 'threshold:\s*\K\w+' || echo "unknown")
    
    echo ""
    echo "🎯 Recovery Requirements:"
    echo "   Current tokens: $CURRENT_TOKENS"
    echo "   Threshold status: $THRESHOLD"
    echo "   Target reduction: $(( CURRENT_TOKENS > 0 && TARGET_TOKENS > 0 ? CURRENT_TOKENS - TARGET_TOKENS : 0 )) tokens"
else
    echo "⚠️  Unable to assess context - assuming emergency state"
    CURRENT_TOKENS="unknown"
    THRESHOLD="critical"
fi
```

## Execute Recovery Strategy
```bash
echo ""
echo "🔄 Executing recovery strategy: $STRATEGY"

case "$STRATEGY" in
  "cascade")
    echo "   Phase 1: Emergency handoff save"
    if ! EMERGENCY_BUNDLE=$("$PROJECT_ROOT/scripts/handoff-manager.sh" save emergency brotli critical 2>/dev/null); then
        echo "   ❌ Emergency save failed - switching to fresh strategy"
        STRATEGY="fresh"
    else
        echo "   ✅ Emergency bundle created: $EMERGENCY_BUNDLE"
        
        echo "   Phase 2: Context optimization"
        if "$PROJECT_ROOT/scripts/context-monitor.sh" optimize aggressive "$TARGET_TOKENS"; then
            echo "   ✅ Context optimized successfully"
            
            # Verify optimization worked
            if NEW_CONTEXT=$("$PROJECT_ROOT/scripts/context-monitor.sh" status brief 2>/dev/null); then
                echo "   📊 Post-optimization status: $NEW_CONTEXT"
                echo "✅ Cascade recovery completed successfully"
                exit 0
            fi
        else
            echo "   ⚠️  Optimization insufficient - proceeding to spawn fresh agent"
        fi
        
        echo "   Phase 3: Spawning fresh agent with essential context"
        if "$PROJECT_ROOT/scripts/handoff-recovery.sh" spawn_fresh "$EMERGENCY_BUNDLE" "$PRESERVE_LEVEL"; then
            echo "✅ Fresh agent spawned with recovered context"
            echo "   Original session context preserved in: $EMERGENCY_BUNDLE"
        else
            echo "❌ Fresh agent spawn failed - manual intervention required"
            exit 1
        fi
    fi
    ;;
    
  "fresh")
    echo "   Creating minimal context backup..."
    if ! MINIMAL_BACKUP=$("$PROJECT_ROOT/scripts/handoff-manager.sh" save manual none low 2>/dev/null); then
        echo "   ⚠️  Backup creation failed - proceeding without backup"
        MINIMAL_BACKUP="none"
    else
        echo "   ✅ Minimal backup created: $MINIMAL_BACKUP"
    fi
    
    echo "   Spawning fresh agent with clean context..."
    if "$PROJECT_ROOT/scripts/handoff-recovery.sh" spawn_fresh "$MINIMAL_BACKUP" "$PRESERVE_LEVEL"; then
        echo "✅ Fresh agent spawned successfully"
        if [ "$MINIMAL_BACKUP" != "none" ]; then
            echo "   Previous context available at: $MINIMAL_BACKUP"
        fi
    else
        echo "❌ Fresh agent spawn failed"
        exit 1
    fi
    ;;
    
  "minimal")
    echo "   Performing aggressive context reduction..."
    if "$PROJECT_ROOT/scripts/context-monitor.sh" optimize emergency "$TARGET_TOKENS"; then
        echo "✅ Minimal recovery completed"
        
        # Show what was preserved
        if PRESERVED_CONTEXT=$("$PROJECT_ROOT/scripts/context-monitor.sh" status preserved 2>/dev/null); then
            echo "📊 Preserved Context:"
            echo "$PRESERVED_CONTEXT" | while IFS= read -r line; do
                echo "   $line"
            done
        fi
    else
        echo "❌ Minimal recovery failed - context too degraded"
        echo "   Try: /recover fresh"
        exit 1
    fi
    ;;
    
  "hybrid")
    echo "   Phase 1: Partial context save"
    if PARTIAL_BUNDLE=$("$PROJECT_ROOT/scripts/handoff-manager.sh" save manual gzip high 2>/dev/null); then
        echo "   ✅ Partial context saved: $PARTIAL_BUNDLE"
        
        echo "   Phase 2: Aggressive optimization"
        if "$PROJECT_ROOT/scripts/context-monitor.sh" optimize emergency "$TARGET_TOKENS"; then
            echo "   ✅ Context optimized"
            
            echo "   Phase 3: Selective context restoration"
            if "$PROJECT_ROOT/scripts/handoff-manager.sh" load_selective "$PARTIAL_BUNDLE" "$PRESERVE_LEVEL"; then
                echo "✅ Hybrid recovery completed"
            else
                echo "⚠️  Selective restoration failed - using optimized context only"
            fi
        else
            echo "   ❌ Optimization failed - falling back to fresh strategy"
            STRATEGY="fresh"
            exec "$0" fresh "$TARGET_TOKENS" "$PRESERVE_LEVEL"
        fi
    else
        echo "   ❌ Partial save failed - using minimal strategy"
        STRATEGY="minimal"
        exec "$0" minimal "$TARGET_TOKENS" "$PRESERVE_LEVEL"
    fi
    ;;
esac
```

## Post-Recovery Verification
```bash
echo ""
echo "🔍 Verifying recovery success..."

# Check context health after recovery
sleep 2  # Allow context to stabilize
if RECOVERY_STATUS=$("$PROJECT_ROOT/scripts/context-monitor.sh" status recovery 2>/dev/null); then
    echo "📊 Post-Recovery Status:"
    echo "$RECOVERY_STATUS" | while IFS= read -r line; do
        echo "   $line"
    done
    
    # Extract success metrics
    FINAL_TOKENS=$(echo "$RECOVERY_STATUS" | grep -oP 'tokens_used:\s*\K\d+' || echo "0")
    if [ "$FINAL_TOKENS" -gt 0 ] && [ "$TARGET_TOKENS" -gt 0 ] && [ "$FINAL_TOKENS" -le "$TARGET_TOKENS" ]; then
        echo "✅ Recovery target achieved"
        echo "   Token reduction: $(( ${CURRENT_TOKENS:-0} - FINAL_TOKENS )) tokens"
    else
        echo "⚠️  Recovery partially successful"
        echo "   Current tokens: $FINAL_TOKENS (target: $TARGET_TOKENS)"
    fi
else
    echo "⚠️  Unable to verify recovery status"
    echo "   Monitor performance and re-run if issues persist"
fi

# Log recovery completion
"$PROJECT_ROOT/scripts/context-monitor.sh" log recovery complete "$STRATEGY" "$PRESERVE_LEVEL" 2>/dev/null || true
```

## Usage Examples
```bash
# Standard cascade recovery (recommended)
/recover cascade 50000 essential

# Emergency fresh agent spawn
/recover fresh 30000 important

# Minimal optimization only
/recover minimal 60000 essential

# Hybrid approach (save + optimize + restore)
/recover hybrid 45000 full

# Complete reset (use with caution)
/recover fresh 20000 none
```

## Recovery Strategy Details

**Cascade Strategy (Recommended):**
1. Emergency handoff save (preserve full context)
2. Aggressive context optimization
3. If insufficient: spawn fresh agent with essential context
4. Original context preserved for manual recovery

**Fresh Strategy:**
1. Minimal backup creation (if possible)
2. Spawn completely new agent instance
3. Load only essential context based on preserve level
4. Clean slate approach for severe corruption

**Minimal Strategy:**
1. Aggressive in-place context reduction
2. Preserve only absolutely essential elements
3. No agent spawning or handoff operations
4. Fastest recovery but most data loss

**Hybrid Strategy:**
1. Selective context save (important elements only)
2. Aggressive optimization of current context
3. Selective restoration from saved bundle
4. Balance between preservation and performance

## Integration with Hooks

**Automatic Triggers:**
- Context threshold 95%: `/recover cascade`
- PreCompact failure: `/recover hybrid`
- Memory allocation error: `/recover fresh`
- Context corruption detected: `/recover minimal`

**Performance Targets:**
- Recovery assessment: < 2 seconds
- Strategy execution: < 10 seconds
- Verification: < 2 seconds
- Total recovery time: < 15 seconds