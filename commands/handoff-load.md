---
name: handoff-load
description: Restore context state from handoff bundle
argument-hint: [bundle-id or "latest"] [load-mode]
allowed-tools: Bash, Read
---

# Context Handoff Load Command

## Validate Arguments and Environment
```bash
# Set defaults if not provided
BUNDLE_ID="${1:-latest}"
LOAD_MODE="${2:-full}"

# Validate load mode
case "$LOAD_MODE" in
  full|session-only|context-only|agents-only)
    echo "✓ Load mode: $LOAD_MODE"
    ;;
  *)
    echo "❌ Invalid load mode: $LOAD_MODE"
    echo "Valid modes: full, session-only, context-only, agents-only"
    exit 1
    ;;
esac

echo "🔄 Loading handoff bundle: $BUNDLE_ID"
echo "   Load mode: $LOAD_MODE"
echo ""
```

## Initialize Context Monitoring
```bash
# Start context monitoring for handoff operation
if ! "$PROJECT_ROOT/scripts/context-monitor.sh" log handoff-load start "$BUNDLE_ID" "$LOAD_MODE"; then
    echo "⚠️  Context monitoring unavailable - proceeding without telemetry"
fi
```

## Validate Bundle Availability
```bash
# Check if bundle exists and is accessible
if [ "$BUNDLE_ID" = "latest" ]; then
    echo "📋 Finding latest handoff bundle..."
    if ! LATEST_BUNDLE=$("$PROJECT_ROOT/scripts/handoff-manager.sh" list latest 2>/dev/null); then
        echo "❌ No handoff bundles found"
        echo "   Use '/handoff-save' to create a bundle first"
        exit 1
    fi
    BUNDLE_ID="$LATEST_BUNDLE"
    echo "   Latest bundle: $BUNDLE_ID"
fi

# Verify bundle exists and is readable
if ! "$PROJECT_ROOT/scripts/handoff-manager.sh" validate "$BUNDLE_ID"; then
    echo "❌ Bundle validation failed: $BUNDLE_ID"
    echo "   Try '/handoff-load $BUNDLE_ID session-only' for minimal loading"
    echo "   Or check bundle status with: scripts/handoff-manager.sh info $BUNDLE_ID"
    exit 1
fi

echo "✅ Bundle validation passed"
```

## Load and Restore Context
```bash
echo ""
echo "🔄 Restoring context from bundle..."
echo "   Bundle ID: $BUNDLE_ID"
echo "   Load mode: $LOAD_MODE"

# Execute the handoff load via handoff-manager
if LOAD_RESULT=$("$PROJECT_ROOT/scripts/handoff-manager.sh" load "$BUNDLE_ID" "$LOAD_MODE"); then
    echo "✅ Context restored successfully!"
    
    # Parse load result for display
    echo ""
    echo "📊 Restoration Summary:"
    echo "$LOAD_RESULT" | while IFS= read -r line; do
        echo "   $line"
    done
    
    # Log successful completion
    "$PROJECT_ROOT/scripts/context-monitor.sh" log handoff-load complete "$BUNDLE_ID" "$LOAD_MODE" 2>/dev/null || true
    
else
    echo "❌ Failed to restore context from bundle"
    echo "   Bundle ID: $BUNDLE_ID"
    echo "   Check ~/.awoc/logs/ for detailed error information"
    
    # Show recovery options
    echo ""
    echo "🔧 Recovery Options:"
    echo "   1. Try minimal loading: /handoff-load $BUNDLE_ID session-only"
    echo "   2. Load different bundle: /handoff-load latest"
    echo "   3. Check bundle info: scripts/handoff-manager.sh info $BUNDLE_ID"
    echo "   4. Emergency recovery: /recover"
    
    # Log failure
    "$PROJECT_ROOT/scripts/context-monitor.sh" log handoff-load error "$BUNDLE_ID" "$LOAD_MODE" 2>/dev/null || true
    exit 1
fi
```

## Post-Load Context Verification
```bash
echo ""
echo "🔍 Verifying restored context..."

# Check context health after restoration
if CONTEXT_STATUS=$("$PROJECT_ROOT/scripts/context-monitor.sh" status 2>/dev/null); then
    echo "✅ Context verification completed"
    echo ""
    echo "📊 Current Context Status:"
    echo "$CONTEXT_STATUS" | while IFS= read -r line; do
        echo "   $line"
    done
else
    echo "⚠️  Context verification unavailable"
    echo "   Context restored but health check failed"
    echo "   Monitor performance and run /context if issues occur"
fi
```

## Usage Examples
```bash
# Load latest bundle with full restoration
/handoff-load latest full

# Load specific bundle with session-only restoration
/handoff-load 20250108_143000_abc12345 session-only

# Load with context-only restoration
/handoff-load latest context-only

# Load with agents-only restoration (delegation state)
/handoff-load 20250108_143000_abc12345 agents-only
```

## Integration Notes

**Load Modes:**
- `full`: Complete context restoration (default)
- `session-only`: Restore session state and metadata only
- `context-only`: Restore context usage and optimization state
- `agents-only`: Restore agent coordination and delegation state

**Recovery Scenarios:**
- Session interruption: Load latest bundle with full restoration
- Context overflow: Load emergency bundle with session-only mode
- System restart: Load latest bundle, fallback to session-only if issues
- Emergency recovery: Load any valid bundle with minimal restoration

**Performance Targets:**
- Bundle validation: < 1 second
- Context restoration: < 3 seconds
- Verification: < 1 second
- Total operation time: < 5 seconds

**Error Handling:**
- Invalid bundle ID → Show available bundles
- Corrupted bundle → Suggest recovery options
- Missing dependencies → Show dependency status
- Load failure → Offer alternative load modes