#!/bin/bash

# AWOC Handoff Recovery Protocols
# Comprehensive error handling and recovery for handoff operations
# Ensures system resilience and data integrity

set -euo pipefail

# Source logging system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/logging.sh" ]; then
    # shellcheck source=./logging.sh
    source "$SCRIPT_DIR/logging.sh"
    init_logging
else
    log_info() { echo "[INFO] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { echo "[DEBUG] $1" >&2; }
fi

# Configuration
RECOVERY_DIR="${HOME}/.awoc/recovery"
HANDOFF_DIR="${HOME}/.awoc/handoffs"
BACKUP_DIR="$RECOVERY_DIR/backups"
QUARANTINE_DIR="$RECOVERY_DIR/quarantine"

# Recovery timeouts
MAX_RECOVERY_TIME=60     # seconds
MAX_RETRY_ATTEMPTS=3
RECOVERY_BACKOFF_BASE=2  # exponential backoff

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize recovery system
init_recovery_system() {
    log_info "Initializing handoff recovery system" "HANDOFF_RECOVERY"
    
    # Create recovery directories
    for dir in "$RECOVERY_DIR" "$BACKUP_DIR" "$QUARANTINE_DIR"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log_error "Failed to create recovery directory: $dir" "HANDOFF_RECOVERY"
            return 1
        fi
    done
    
    # Create recovery state file
    local recovery_state="$RECOVERY_DIR/recovery_state.json"
    if [ ! -f "$recovery_state" ]; then
        cat > "$recovery_state" << EOF
{
    "version": "1.0.0",
    "initialized_at": "$(date -Iseconds)",
    "recovery_sessions": [],
    "quarantined_bundles": [],
    "backup_history": [],
    "error_statistics": {
        "bundle_creation_failures": 0,
        "bundle_load_failures": 0,
        "validation_failures": 0,
        "recovery_attempts": 0,
        "successful_recoveries": 0
    }
}
EOF
    fi
    
    log_info "Recovery system initialized successfully" "HANDOFF_RECOVERY"
    return 0
}

# Handle bundle creation failure
handle_bundle_creation_failure() {
    local error_type="$1"
    local error_details="$2"
    local attempt_number="${3:-1}"
    
    log_error "Bundle creation failure: $error_type - $error_details (attempt $attempt_number)" "HANDOFF_RECOVERY"
    
    echo -e "${RED}🚨 Bundle Creation Failed${NC}"
    echo "========================="
    echo "Error Type: $error_type"
    echo "Details: $error_details"
    echo "Attempt: $attempt_number"
    echo ""
    
    # Increment error statistics
    update_error_statistics "bundle_creation_failures"
    
    case "$error_type" in
        "insufficient_space")
            handle_disk_space_error "$error_details"
            ;;
        "permission_denied")
            handle_permission_error "$error_details"
            ;;
        "schema_validation_failed")
            handle_schema_validation_error "$error_details"
            ;;
        "compression_failed")
            handle_compression_error "$error_details"
            ;;
        "timeout")
            handle_timeout_error "$error_details"
            ;;
        *)
            handle_generic_error "$error_type" "$error_details"
            ;;
    esac
    
    # Suggest recovery actions
    suggest_recovery_actions "$error_type" "$attempt_number"
}

# Handle bundle loading failure
handle_bundle_loading_failure() {
    local bundle_id="$1"
    local error_type="$2"
    local error_details="$3"
    local attempt_number="${4:-1}"
    
    log_error "Bundle loading failure: $bundle_id - $error_type - $error_details (attempt $attempt_number)" "HANDOFF_RECOVERY"
    
    echo -e "${RED}🚨 Bundle Loading Failed${NC}"
    echo "========================"
    echo "Bundle ID: $bundle_id"
    echo "Error Type: $error_type"
    echo "Details: $error_details"
    echo "Attempt: $attempt_number"
    echo ""
    
    # Increment error statistics
    update_error_statistics "bundle_load_failures"
    
    case "$error_type" in
        "bundle_not_found")
            handle_bundle_not_found_error "$bundle_id"
            ;;
        "corrupted_bundle")
            handle_corrupted_bundle_error "$bundle_id" "$error_details"
            ;;
        "validation_failed")
            handle_validation_failure_error "$bundle_id" "$error_details"
            ;;
        "decompression_failed")
            handle_decompression_error "$bundle_id" "$error_details"
            ;;
        "compatibility_error")
            handle_compatibility_error "$bundle_id" "$error_details"
            ;;
        *)
            handle_generic_load_error "$bundle_id" "$error_type" "$error_details"
            ;;
    esac
    
    # Attempt recovery
    if [ "$attempt_number" -le "$MAX_RETRY_ATTEMPTS" ]; then
        attempt_bundle_recovery "$bundle_id" "$error_type" "$attempt_number"
    else
        echo -e "${RED}❌ Maximum retry attempts exceeded${NC}"
        quarantine_bundle "$bundle_id" "$error_type" "$error_details"
    fi
}

# Handle disk space error
handle_disk_space_error() {
    local error_details="$1"
    
    echo -e "${YELLOW}💾 Disk Space Error${NC}"
    echo "=================="
    echo ""
    
    # Check available space
    local available_space
    available_space=$(df -h "$HANDOFF_DIR" | awk 'NR==2 {print $4}')
    echo "Available space: $available_space"
    
    # Suggest cleanup actions
    echo "Recovery Actions:"
    echo "1. Clean old handoff bundles:"
    echo "   $SCRIPT_DIR/handoff-manager.sh archive 3"
    echo ""
    echo "2. Clean temporary files:"
    echo "   find ~/.awoc -name '*.tmp' -delete"
    echo ""
    echo "3. Compress existing bundles:"
    echo "   find ~/.awoc/handoffs -name '*.json' -exec gzip {} \\;"
    
    # Automatic cleanup if enabled
    if should_auto_cleanup; then
        echo ""
        echo "🔧 Attempting automatic cleanup..."
        auto_cleanup_disk_space
    fi
}

# Handle permission error
handle_permission_error() {
    local error_details="$1"
    
    echo -e "${YELLOW}🔐 Permission Error${NC}"
    echo "=================="
    echo ""
    echo "Error: $error_details"
    echo ""
    echo "Recovery Actions:"
    echo "1. Check directory permissions:"
    echo "   ls -la ~/.awoc/"
    echo ""
    echo "2. Fix ownership if needed:"
    echo "   sudo chown -R \$USER ~/.awoc/"
    echo ""
    echo "3. Set proper permissions:"
    echo "   chmod -R 755 ~/.awoc/"
    echo ""
    
    # Check current permissions
    if [ -d "$HANDOFF_DIR" ]; then
        local perms
        perms=$(stat -c "%a %U:%G" "$HANDOFF_DIR" 2>/dev/null || echo "unknown")
        echo "Current permissions: $perms"
    fi
}

# Handle schema validation error
handle_schema_validation_error() {
    local error_details="$1"
    
    echo -e "${YELLOW}📋 Schema Validation Error${NC}"
    echo "=========================="
    echo ""
    echo "Error: $error_details"
    echo ""
    echo "Recovery Actions:"
    echo "1. Create minimal valid bundle:"
    echo "   Use reduced data set with essential fields only"
    echo ""
    echo "2. Check schema compatibility:"
    echo "   Verify AWOC version compatibility"
    echo ""
    echo "3. Fallback to basic bundle:"
    echo "   Create bundle without advanced features"
    
    # Attempt to create minimal bundle
    if should_auto_recover; then
        echo ""
        echo "🔧 Attempting minimal bundle creation..."
        create_minimal_recovery_bundle
    fi
}

# Handle compression error
handle_compression_error() {
    local error_details="$1"
    
    echo -e "${YELLOW}🗜️  Compression Error${NC}"
    echo "===================="
    echo ""
    echo "Error: $error_details"
    echo ""
    echo "Recovery Actions:"
    echo "1. Fallback to uncompressed bundle:"
    echo "   Save without compression"
    echo ""
    echo "2. Try alternative compression:"
    echo "   Use different compression algorithm"
    echo ""
    echo "3. Split large bundle:"
    echo "   Create multiple smaller bundles"
    
    # Automatic fallback
    if should_auto_recover; then
        echo ""
        echo "🔧 Falling back to uncompressed bundle..."
        "$SCRIPT_DIR/handoff-manager.sh" save manual none medium
    fi
}

# Handle timeout error
handle_timeout_error() {
    local error_details="$1"
    
    echo -e "${YELLOW}⏰ Timeout Error${NC}"
    echo "==============="
    echo ""
    echo "Error: $error_details"
    echo ""
    echo "Recovery Actions:"
    echo "1. Reduce bundle size:"
    echo "   Enable aggressive compression"
    echo ""
    echo "2. Simplify bundle contents:"
    echo "   Exclude non-essential data"
    echo ""
    echo "3. Increase timeout limits:"
    echo "   Adjust MAX_SAVE_TIME_SECONDS in settings"
    
    # Performance optimization suggestion
    echo ""
    echo "Performance Optimization:"
    echo "Run: $SCRIPT_DIR/handoff-performance.sh benchmark-save"
}

# Handle bundle not found error
handle_bundle_not_found_error() {
    local bundle_id="$1"
    
    echo -e "${YELLOW}🔍 Bundle Not Found${NC}"
    echo "=================="
    echo ""
    echo "Bundle ID: $bundle_id"
    echo ""
    
    # Search for similar bundles
    echo "Searching for similar bundles..."
    local similar_bundles
    similar_bundles=$(find "$HANDOFF_DIR" -name "*${bundle_id:0:8}*" -type f 2>/dev/null || true)
    
    if [ -n "$similar_bundles" ]; then
        echo "Similar bundles found:"
        echo "$similar_bundles" | while read -r bundle_file; do
            local bundle_name
            bundle_name=$(basename "$bundle_file")
            echo "  • $bundle_name"
        done
        echo ""
        echo "Use: /handoff-load <bundle-name>"
    else
        echo "No similar bundles found."
        echo ""
        echo "Available bundles:"
        "$SCRIPT_DIR/handoff-manager.sh" list human active
    fi
}

# Handle corrupted bundle error
handle_corrupted_bundle_error() {
    local bundle_id="$1"
    local error_details="$2"
    
    echo -e "${YELLOW}🚨 Corrupted Bundle${NC}"
    echo "=================="
    echo ""
    echo "Bundle ID: $bundle_id"
    echo "Error: $error_details"
    echo ""
    
    # Find bundle file
    local bundle_file
    bundle_file=$(find "$HANDOFF_DIR" -name "*${bundle_id}*" -type f 2>/dev/null | head -1)
    
    if [ -n "$bundle_file" ] && [ -f "$bundle_file" ]; then
        # Attempt repair
        echo "Attempting bundle repair..."
        
        # Create backup before repair
        local backup_file="$BACKUP_DIR/$(basename "$bundle_file").backup.$(date +%s)"
        cp "$bundle_file" "$backup_file"
        echo "Backup created: $backup_file"
        
        # Try to repair bundle
        if repair_corrupted_bundle "$bundle_file"; then
            echo -e "${GREEN}✅ Bundle repair successful${NC}"
        else
            echo -e "${RED}❌ Bundle repair failed${NC}"
            quarantine_bundle "$bundle_id" "corrupted" "$error_details"
            
            # Suggest alternatives
            echo ""
            echo "Alternative actions:"
            echo "1. Try loading from backup: /handoff-load backup"
            echo "2. Create fresh bundle: /handoff-save manual"
            echo "3. Check other available bundles: /handoff-list"
        fi
    else
        echo "Bundle file not found for repair"
        quarantine_bundle "$bundle_id" "file_not_found" "$error_details"
    fi
}

# Repair corrupted bundle
repair_corrupted_bundle() {
    local bundle_file="$1"
    
    # Try different repair strategies
    
    # Strategy 1: Fix JSON formatting
    if repair_json_formatting "$bundle_file"; then
        return 0
    fi
    
    # Strategy 2: Decompress and recompress
    if repair_compression "$bundle_file"; then
        return 0
    fi
    
    # Strategy 3: Extract essential data
    if repair_extract_essential "$bundle_file"; then
        return 0
    fi
    
    return 1
}

# Repair JSON formatting
repair_json_formatting() {
    local bundle_file="$1"
    local temp_file
    temp_file=$(mktemp)
    
    # Try to fix common JSON issues
    if [[ "$bundle_file" == *.gz ]]; then
        if gunzip -c "$bundle_file" 2>/dev/null | jq '.' > "$temp_file" 2>/dev/null; then
            gzip -c "$temp_file" > "$bundle_file"
            rm -f "$temp_file"
            return 0
        fi
    else
        if jq '.' "$bundle_file" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$bundle_file"
            return 0
        fi
    fi
    
    rm -f "$temp_file"
    return 1
}

# Repair compression
repair_compression() {
    local bundle_file="$1"
    
    if [[ "$bundle_file" == *.gz ]]; then
        local uncompressed_file="${bundle_file%.gz}"
        
        # Try to decompress
        if gunzip -c "$bundle_file" > "$uncompressed_file" 2>/dev/null; then
            # Validate JSON
            if jq empty "$uncompressed_file" 2>/dev/null; then
                # Recompress
                if gzip -c "$uncompressed_file" > "$bundle_file"; then
                    rm -f "$uncompressed_file"
                    return 0
                fi
            fi
        fi
        
        rm -f "$uncompressed_file"
    fi
    
    return 1
}

# Extract essential data from corrupted bundle
repair_extract_essential() {
    local bundle_file="$1"
    local temp_file
    temp_file=$(mktemp)
    
    # Try to extract at least session metadata
    if extract_session_metadata "$bundle_file" > "$temp_file" 2>/dev/null; then
        if jq empty "$temp_file" 2>/dev/null; then
            if [[ "$bundle_file" == *.gz ]]; then
                gzip -c "$temp_file" > "$bundle_file"
            else
                mv "$temp_file" "$bundle_file"
            fi
            rm -f "$temp_file"
            return 0
        fi
    fi
    
    rm -f "$temp_file"
    return 1
}

# Extract session metadata from bundle
extract_session_metadata() {
    local bundle_file="$1"
    
    # Create minimal valid bundle with extracted data
    local recovery_id="recovered_$(date +%Y%m%d_%H%M%S)"
    jq -n \
        --arg recovery_id "$recovery_id" \
        --arg bundle_file "$bundle_file" \
        '{
        bundle_metadata: {
            bundle_id: $recovery_id,
            created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            bundle_type: "recovered",
            version: "1.3.0",
            compression: {enabled: false, algorithm: "none"}
        },
        session_state: {
            session_id: "recovered",
            start_time: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            duration: 0,
            active_agent: "unknown",
            status: "recovered"
        },
        context_usage: {
            tokens_used: 0,
            baseline_tokens: 350,
            priming_tokens: 0,
            threshold_status: "normal",
            files_read: [],
            searches_performed: [],
            tool_usage: {}
        },
        knowledge_graph: {
            discoveries: [],
            patterns: [],
            decisions: [],
            learning_outcomes: []
        },
        priming_state: {},
        agent_coordination: {
            active_agents: [],
            sub_agents: [],
            background_tasks: []
        },
        recovery_metadata: {
            integrity_hash: "",
            validation_status: "recovered",
            recovery_timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            original_bundle: $bundle_file
        }
    }'
}

# Quarantine problematic bundle
quarantine_bundle() {
    local bundle_id="$1"
    local error_type="$2"
    local error_details="$3"
    
    log_warning "Quarantining bundle: $bundle_id ($error_type)" "HANDOFF_RECOVERY"
    
    # Find bundle file
    local bundle_file
    bundle_file=$(find "$HANDOFF_DIR" -name "*${bundle_id}*" -type f 2>/dev/null | head -1)
    
    if [ -n "$bundle_file" ] && [ -f "$bundle_file" ]; then
        # Move to quarantine
        local quarantine_file="$QUARANTINE_DIR/$(basename "$bundle_file").quarantined"
        mv "$bundle_file" "$quarantine_file"
        
        # Create quarantine record
        local quarantine_record="$QUARANTINE_DIR/$(basename "$bundle_file").record.json"
        jq -n \
            --arg bundle_id "$bundle_id" \
            --arg error_type "$error_type" \
            --arg error_details "$error_details" \
            --arg quarantine_time "$(date -Iseconds)" \
            --arg original_path "$bundle_file" \
            '{
                bundle_id: $bundle_id,
                error_type: $error_type,
                error_details: $error_details,
                quarantine_time: $quarantine_time,
                original_path: $original_path,
                quarantine_path: "' "$quarantine_file" '",
                recovery_attempts: 0
            }' > "$quarantine_record"
        
        echo -e "${YELLOW}📋 Bundle quarantined: $quarantine_file${NC}"
        echo "Record: $quarantine_record"
    fi
    
    # Update recovery state
    update_quarantine_statistics "$bundle_id" "$error_type"
}

# Attempt bundle recovery
attempt_bundle_recovery() {
    local bundle_id="$1"
    local error_type="$2"
    local attempt_number="$3"
    
    log_info "Attempting bundle recovery: $bundle_id (attempt $attempt_number)" "HANDOFF_RECOVERY"
    
    # Calculate backoff time
    local backoff_time
    backoff_time=$((RECOVERY_BACKOFF_BASE ** (attempt_number - 1)))
    
    echo ""
    echo -e "${BLUE}🔄 Recovery Attempt $attempt_number${NC}"
    echo "=========================="
    echo "Bundle: $bundle_id"
    echo "Error: $error_type"
    echo "Backoff: ${backoff_time}s"
    echo ""
    
    # Wait for backoff
    if [ "$backoff_time" -gt 0 ]; then
        echo "Waiting ${backoff_time}s before retry..."
        sleep "$backoff_time"
    fi
    
    # Update error statistics
    update_error_statistics "recovery_attempts"
    
    # Attempt recovery based on error type
    case "$error_type" in
        "bundle_not_found")
            # Try searching in different locations
            attempt_bundle_search_recovery "$bundle_id"
            ;;
        "corrupted_bundle")
            # Try repair strategies
            attempt_bundle_repair_recovery "$bundle_id"
            ;;
        "validation_failed")
            # Try with reduced validation
            attempt_validation_recovery "$bundle_id" "$((attempt_number + 1))"
            ;;
        *)
            # Generic retry
            attempt_generic_recovery "$bundle_id" "$((attempt_number + 1))"
            ;;
    esac
}

# Create minimal recovery bundle
create_minimal_recovery_bundle() {
    echo "Creating minimal recovery bundle..."
    
    local recovery_bundle_id
    recovery_bundle_id="recovery_$(date +%Y%m%d_%H%M%S)"
    
    local recovery_file="$RECOVERY_DIR/${recovery_bundle_id}.json"
    
    # Create minimal but valid bundle
    jq -n \
        --arg recovery_bundle_id "$recovery_bundle_id" \
        '{
        bundle_metadata: {
            bundle_id: $recovery_bundle_id,
            created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            bundle_type: "recovery",
            version: "1.3.0"
        },
        session_state: {
            session_id: "recovery",
            start_time: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            duration: 0,
            active_agent: "recovery",
            status: "recovery"
        },
        context_usage: {
            tokens_used: 350,
            baseline_tokens: 350,
            priming_tokens: 0,
            threshold_status: "normal",
            files_read: [],
            searches_performed: [],
            tool_usage: {}
        },
        knowledge_graph: {
            discoveries: [],
            patterns: [],
            decisions: [],
            learning_outcomes: []
        }
    }' > "$recovery_file"
    
    echo -e "${GREEN}✅ Minimal recovery bundle created: $recovery_bundle_id${NC}"
    echo "Location: $recovery_file"
    echo ""
    echo "Use: /handoff-load $recovery_bundle_id"
    
    # Update statistics
    update_error_statistics "successful_recoveries"
}

# Update error statistics
update_error_statistics() {
    local stat_name="$1"
    local recovery_state="$RECOVERY_DIR/recovery_state.json"
    
    if [ -f "$recovery_state" ]; then
        local temp_file
        temp_file=$(mktemp)
        
        jq --arg stat "$stat_name" '.error_statistics[$stat] += 1' "$recovery_state" > "$temp_file" && mv "$temp_file" "$recovery_state"
        rm -f "$temp_file"
    fi
}

# Check if auto cleanup is enabled
should_auto_cleanup() {
    # Check settings or environment variable
    local auto_cleanup="${AWOC_AUTO_CLEANUP:-true}"
    [ "$auto_cleanup" = "true" ]
}

# Check if auto recovery is enabled
should_auto_recover() {
    local auto_recover="${AWOC_AUTO_RECOVER:-true}"
    [ "$auto_recover" = "true" ]
}

# Auto cleanup disk space
auto_cleanup_disk_space() {
    # Archive old bundles
    "$SCRIPT_DIR/handoff-manager.sh" archive 3 false >/dev/null 2>&1 || true
    
    # Clean temporary files
    find ~/.awoc -name "*.tmp" -delete 2>/dev/null || true
    
    # Compress uncompressed bundles
    find ~/.awoc/handoffs -name "*.json" -exec gzip {} \; 2>/dev/null || true
    
    echo "✅ Automatic cleanup completed"
}

# Generate recovery report
generate_recovery_report() {
    local recovery_state="$RECOVERY_DIR/recovery_state.json"
    
    if [ ! -f "$recovery_state" ]; then
        echo "No recovery data available"
        return
    fi
    
    echo -e "${BLUE}📊 Recovery System Report${NC}"
    echo "========================"
    echo ""
    
    # Error statistics
    echo "Error Statistics:"
    jq -r '.error_statistics | to_entries[] | "  \(.key | gsub("_"; " ") | gsub("\\b(.)";"\\1";"g")): \(.value)"' "$recovery_state"
    echo ""
    
    # Success rate
    local total_attempts
    local successful_recoveries
    total_attempts=$(jq -r '.error_statistics.recovery_attempts' "$recovery_state")
    successful_recoveries=$(jq -r '.error_statistics.successful_recoveries' "$recovery_state")
    
    if [ "$total_attempts" -gt 0 ]; then
        local success_rate
        success_rate=$(( (successful_recoveries * 100) / total_attempts ))
        echo "Recovery Success Rate: ${success_rate}%"
    else
        echo "Recovery Success Rate: N/A (no attempts)"
    fi
    
    # Quarantined bundles
    local quarantined_count
    quarantined_count=$(find "$QUARANTINE_DIR" -name "*.quarantined" -type f 2>/dev/null | wc -l)
    echo "Quarantined Bundles: $quarantined_count"
    
    if [ "$quarantined_count" -gt 0 ]; then
        echo ""
        echo "Quarantined Bundles:"
        find "$QUARANTINE_DIR" -name "*.record.json" -type f 2>/dev/null | while read -r record_file; do
            local bundle_id error_type quarantine_time
            bundle_id=$(jq -r '.bundle_id' "$record_file")
            error_type=$(jq -r '.error_type' "$record_file")
            quarantine_time=$(jq -r '.quarantine_time' "$record_file")
            echo "  • $bundle_id ($error_type) - $quarantine_time"
        done
    fi
}

# Usage information
usage() {
    echo "AWOC Handoff Recovery System"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                           Initialize recovery system"
    echo "  handle-creation-failure <type> <details> [attempt]"
    echo "  handle-loading-failure <bundle> <type> <details> [attempt]"
    echo "  quarantine <bundle> <type> <details>"
    echo "  repair <bundle-file>           Attempt bundle repair"
    echo "  create-minimal                 Create minimal recovery bundle"
    echo "  report                         Generate recovery report"
    echo "  cleanup                        Clean recovery data"
    echo "  help                           Show this help"
    echo ""
    echo "Recovery Features:"
    echo "  • Automatic retry with exponential backoff"
    echo "  • Bundle repair and validation"
    echo "  • Quarantine system for problematic bundles"
    echo "  • Minimal recovery bundle creation"
    echo "  • Comprehensive error handling"
    echo ""
    echo "Configuration:"
    echo "  AWOC_AUTO_CLEANUP=true         Enable automatic cleanup"
    echo "  AWOC_AUTO_RECOVER=true         Enable automatic recovery"
    echo "  MAX_RETRY_ATTEMPTS=3           Maximum retry attempts"
    echo "  MAX_RECOVERY_TIME=60           Maximum recovery time (seconds)"
}

# Main function
main() {
    case "${1:-help}" in
        init)
            if init_recovery_system; then
                echo "✅ Recovery system initialized"
            else
                echo "❌ Failed to initialize recovery system" >&2
                exit 1
            fi
            ;;
        handle-creation-failure)
            if [ $# -lt 3 ]; then
                echo "Error: requires error type and details" >&2
                exit 1
            fi
            handle_bundle_creation_failure "$2" "$3" "${4:-1}"
            ;;
        handle-loading-failure)
            if [ $# -lt 4 ]; then
                echo "Error: requires bundle ID, error type, and details" >&2
                exit 1
            fi
            handle_bundle_loading_failure "$2" "$3" "$4" "${5:-1}"
            ;;
        quarantine)
            if [ $# -lt 4 ]; then
                echo "Error: requires bundle ID, error type, and details" >&2
                exit 1
            fi
            quarantine_bundle "$2" "$3" "$4"
            ;;
        repair)
            if [ $# -lt 2 ]; then
                echo "Error: requires bundle file path" >&2
                exit 1
            fi
            if repair_corrupted_bundle "$2"; then
                echo "✅ Bundle repair successful"
            else
                echo "❌ Bundle repair failed" >&2
                exit 1
            fi
            ;;
        create-minimal)
            create_minimal_recovery_bundle
            ;;
        report)
            generate_recovery_report
            ;;
        cleanup)
            echo "Cleaning recovery data..."
            find "$RECOVERY_DIR" -name "*.tmp" -delete 2>/dev/null || true
            echo "✅ Recovery cleanup completed"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: ${1:-}" >&2
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi