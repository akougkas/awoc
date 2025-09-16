---
name: handoff-save
description: Create context handoff bundle for session continuity
argument-hint: [type] [compression] [priority]
allowed-tools: Bash, Write, Read
---

# Context Handoff Save Command

## Validate Arguments and Environment
```bash
# Set defaults if not provided
SAVE_TYPE="${1:-automatic}"
COMPRESSION="${2:-gzip}"
PRIORITY="${3:-medium}"

# Validate save type
case "$SAVE_TYPE" in
  manual|automatic|emergency|scheduled)
    echo "✓ Save type: $SAVE_TYPE"
    ;;
  *)
    echo "❌ Invalid save type: $SAVE_TYPE"
    echo "Valid types: manual, automatic, emergency, scheduled"
    exit 1
    ;;
esac

# Validate compression
case "$COMPRESSION" in
  gzip|brotli|none)
    echo "✓ Compression: $COMPRESSION"
    ;;
  *)
    echo "❌ Invalid compression: $COMPRESSION"
    echo "Valid options: gzip, brotli, none"
    exit 1
    ;;
esac

# Validate priority
case "$PRIORITY" in
  low|medium|high|critical)
    echo "✓ Priority: $PRIORITY"
    ;;
  *)
    echo "❌ Invalid priority: $PRIORITY"
    echo "Valid priorities: low, medium, high, critical"
    exit 1
    ;;
esac
```

## Initialize Context Monitoring
```bash
# Detect AWOC installation directory
AWOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Start context monitoring for handoff operation
if ! "$AWOC_DIR/scripts/context-monitor.sh" log handoff-save start "$SAVE_TYPE" "$COMPRESSION"; then
    echo "⚠️  Context monitoring unavailable - proceeding without telemetry"
fi
```

## Execute Handoff Save Operation
```bash
# Execute the handoff save via handoff-manager
echo "🔄 Creating handoff bundle..."
echo "   Type: $SAVE_TYPE"
echo "   Compression: $COMPRESSION" 
echo "   Priority: $PRIORITY"
echo ""

if BUNDLE_ID=$("$AWOC_DIR/scripts/handoff-manager.sh" save "$SAVE_TYPE" "$COMPRESSION" "$PRIORITY"); then
    echo "✅ Handoff bundle created successfully!"
    echo "   Bundle ID: $BUNDLE_ID"
    echo "   Location: ~/.awoc/handoffs/"
    
    # Log completion
    "$AWOC_DIR/scripts/context-monitor.sh" log handoff-save complete "$BUNDLE_ID" "$SAVE_TYPE" 2>/dev/null || true
    
    # Validate bundle integrity
    echo ""
    echo "🔍 Validating bundle integrity..."
    if "$AWOC_DIR/scripts/bundle-validator.sh" check "$BUNDLE_ID" quick >/dev/null 2>&1; then
        echo "✅ Bundle validation passed"
    else
        echo "⚠️  Bundle validation warnings (check logs for details)"
    fi

    # Show bundle info
    echo ""
    echo "📊 Bundle Information:"
    "$AWOC_DIR/scripts/handoff-manager.sh" info "$BUNDLE_ID" || echo "   Info temporarily unavailable"
else
    echo "❌ Failed to create handoff bundle"
    echo "   Check ~/.awoc/logs/ for details"
    
    # Log failure
    "$AWOC_DIR/scripts/context-monitor.sh" log handoff-save error "$SAVE_TYPE" "$COMPRESSION" 2>/dev/null || true
    exit 1
fi
```

## Usage Examples
```bash
# Manual save with default settings
/handoff-save manual

# Emergency save with maximum compression
/handoff-save emergency brotli critical

# Scheduled save with standard compression
/handoff-save scheduled gzip medium

# Automatic save (triggered by hooks)
/handoff-save automatic gzip medium
```

## Integration Notes

**Automatic Triggers:**
- SessionEnd hook: `/handoff-save automatic gzip medium`
- PreCompact hook: `/handoff-save emergency gzip critical`
- Context threshold 85%: `/handoff-save automatic gzip high`
- Context threshold 90%: `/handoff-save emergency gzip critical`

**Performance Targets:**
- Save operation: < 5 seconds
- Bundle compression: < 2 seconds
- Bundle validation: < 1 second
- Total operation time: < 8 seconds

**Recovery Integration:**
- All bundles include recovery metadata
- Emergency saves prioritize essential context
- Automatic validation ensures integrity
- Compression ratios monitored for efficiency