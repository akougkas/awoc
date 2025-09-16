#!/bin/bash

# AWOC Context Handoff Manager
# Complete session continuity and context overflow recovery system
# Implements comprehensive handoff protocol for AWOC 1.3

set -euo pipefail

# Source logging and context monitoring
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
HANDOFF_DIR="${HOME}/.awoc/handoffs"
CONTEXT_DIR="${HOME}/.awoc/context"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_FILE="$PROJECT_ROOT/schemas/handoff-bundle.json"

# Bundle format version
BUNDLE_VERSION="1.3.0"

# Performance thresholds
MAX_BUNDLE_SIZE_MB=50
MAX_SAVE_TIME_SECONDS=5
MAX_LOAD_TIME_SECONDS=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize handoff system
init_handoff_system() {
    log_info "Initializing context handoff system" "HANDOFF_MANAGER"
    
    # Create required directories
    for dir in "$HANDOFF_DIR" "$HANDOFF_DIR/active" "$HANDOFF_DIR/archive" "$HANDOFF_DIR/emergency"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log_error "Failed to create directory: $dir" "HANDOFF_MANAGER"
            return 1
        fi
    done
    
    # Validate schema file exists
    if [ ! -f "$SCHEMA_FILE" ]; then
        log_error "Bundle schema file not found: $SCHEMA_FILE" "HANDOFF_MANAGER"
        return 1
    fi
    
    # Test JSON schema validator
    if ! command -v ajv &> /dev/null; then
        log_warning "ajv validator not found - bundle validation will be limited" "HANDOFF_MANAGER"
    fi
    
    # Test compression tools
    if ! command -v gzip &> /dev/null; then
        log_error "gzip not available - compression disabled" "HANDOFF_MANAGER"
        return 1
    fi
    
    log_info "Context handoff system initialized successfully" "HANDOFF_MANAGER"
    return 0
}

# Generate unique bundle ID
generate_bundle_id() {
    local session_id="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    echo "${timestamp}_${session_id}"
}

# Create handoff bundle
create_handoff_bundle() {
    local bundle_type="${1:-manual}"
    local compression="${2:-gzip}"
    local priority="${3:-medium}"
    
    log_info "Creating handoff bundle: type=$bundle_type, compression=$compression" "HANDOFF_MANAGER"
    
    local start_time
    start_time=$(date +%s)
    
    # Get current session state
    local session_id
    session_id=$(get_current_session_id)
    
    local bundle_id
    bundle_id=$(generate_bundle_id "$session_id")
    
    local bundle_file="$HANDOFF_DIR/active/${bundle_id}.json"
    local temp_file
    temp_file=$(mktemp)
    
    # Build bundle data
    if ! build_bundle_data "$bundle_id" "$bundle_type" "$compression" "$priority" > "$temp_file"; then
        log_error "Failed to build bundle data" "HANDOFF_MANAGER"
        rm -f "$temp_file"
        return 1
    fi
    
    # Validate bundle against schema
    if ! validate_bundle_schema "$temp_file"; then
        log_error "Bundle validation failed" "HANDOFF_MANAGER"
        rm -f "$temp_file"
        return 1
    fi
    
    # Apply compression if requested
    case "$compression" in
        "gzip")
            if ! gzip -c "$temp_file" > "${bundle_file}.gz"; then
                log_error "Compression failed" "HANDOFF_MANAGER"
                rm -f "$temp_file"
                return 1
            fi
            bundle_file="${bundle_file}.gz"
            ;;
        "none")
            mv "$temp_file" "$bundle_file"
            ;;
        *)
            log_error "Unsupported compression: $compression" "HANDOFF_MANAGER"
            rm -f "$temp_file"
            return 1
            ;;
    esac
    
    rm -f "$temp_file"
    
    # Performance check
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -gt "$MAX_SAVE_TIME_SECONDS" ]; then
        log_warning "Bundle creation took ${duration}s (threshold: ${MAX_SAVE_TIME_SECONDS}s)" "HANDOFF_MANAGER"
    fi
    
    # Size check
    local bundle_size_kb
    bundle_size_kb=$(du -k "$bundle_file" | cut -f1)
    local bundle_size_mb=$((bundle_size_kb / 1024))
    
    if [ "$bundle_size_mb" -gt "$MAX_BUNDLE_SIZE_MB" ]; then
        log_warning "Bundle size ${bundle_size_mb}MB exceeds threshold (${MAX_BUNDLE_SIZE_MB}MB)" "HANDOFF_MANAGER"
    fi
    
    # Update context monitor
    if [ -f "$SCRIPT_DIR/context-monitor.sh" ]; then
        "$SCRIPT_DIR/context-monitor.sh" track handoff save_bundle "$bundle_size_kb" handoff
    fi
    
    # Update token logger
    if [ -f "$SCRIPT_DIR/token-logger.sh" ]; then
        "$SCRIPT_DIR/token-logger.sh" log handoff save_bundle 100 handoff system
    fi
    
    log_info "Handoff bundle created: $bundle_id (${bundle_size_kb}KB, ${duration}s)" "HANDOFF_MANAGER"
    echo "$bundle_id"
}

# Build bundle data structure
build_bundle_data() {
    local bundle_id="$1"
    local bundle_type="$2"
    local compression="$3"
    local priority="$4"
    
    local session_data
    local stats_data
    local context_data
    local project_state
    local git_state
    
    # Gather all required data
    session_data=$(get_session_state_data)
    stats_data=$(get_context_usage_data)
    context_data=$(get_knowledge_graph_data)
    project_state=$(get_project_state_data)
    git_state=$(get_git_state_data)
    
    # Build the complete bundle
    jq -n \
        --arg bundle_id "$bundle_id" \
        --arg created_at "$(date -Iseconds)" \
        --arg bundle_type "$bundle_type" \
        --arg version "$BUNDLE_VERSION" \
        --arg compression "$compression" \
        --arg priority "$priority" \
        --argjson session_data "$session_data" \
        --argjson stats_data "$stats_data" \
        --argjson context_data "$context_data" \
        --argjson project_state "$project_state" \
        --argjson git_state "$git_state" \
        '{
            bundle_metadata: {
                bundle_id: $bundle_id,
                created_at: $created_at,
                bundle_type: $bundle_type,
                version: $version,
                compression: {
                    enabled: ($compression != "none"),
                    algorithm: $compression,
                    compression_ratio: 0,
                    original_size: 0,
                    compressed_size: 0
                },
                retention_policy: {
                    expires_at: (now + 604800 | strftime("%Y-%m-%dT%H:%M:%SZ")),
                    priority: $priority,
                    auto_archive: true
                }
            },
            session_state: $session_data,
            context_usage: $stats_data,
            knowledge_graph: $context_data,
            priming_state: {
                scenarios_loaded: [],
                budget_allocation: {
                    total_budget: 10000,
                    used_budget: 0,
                    remaining_budget: 10000,
                    efficiency_score: 1.0
                },
                cache_state: {
                    cached_scenarios: [],
                    cache_hits: 0,
                    cache_misses: 0,
                    cache_expiry: (now + 3600 | strftime("%Y-%m-%dT%H:%M:%SZ"))
                }
            },
            agent_coordination: {
                active_agents: [],
                sub_agents: [],
                background_tasks: []
            },
            recovery_metadata: {
                integrity_hash: "",
                validation_status: "valid",
                dependencies: [],
                compatibility: {
                    awoc_version: $version,
                    claude_code_version: "latest",
                    required_features: ["context-monitor", "token-logger", "handoff-system"],
                    breaking_changes: []
                }
            }
        }'
}

# Get session state data
get_session_state_data() {
    local session_file="$CONTEXT_DIR/current_session.json"
    local session_id
    session_id=$(get_current_session_id)
    
    if [ -f "$session_file" ]; then
        local session_data
        session_data=$(cat "$session_file")
        
        # Enhance with additional context
        jq --arg session_id "$session_id" \
           --arg working_dir "$PWD" \
           --arg git_branch "$(git branch --show-current 2>/dev/null || echo 'unknown')" \
           --arg git_commit "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
           '. + {
               session_id: $session_id,
               duration: (.duration // 0),
               active_agents: (if .active_agents == null then [] else .active_agents end),
               project_context: {
                   working_directory: $working_dir,
                   git_branch: $git_branch,
                   git_commit: $git_commit,
                   project_name: ($working_dir | split("/") | .[-1]),
                   environment: env
               },
               claude_code_state: {
                   model: "claude-sonnet-4-20250514",
                   settings: {},
                   active_commands: [],
                   hooks_enabled: true
               }
           }' <<< "$session_data"
    else
        # Create minimal session state
        jq -n \
            --arg session_id "$session_id" \
            --arg working_dir "$PWD" \
            '{
                session_id: $session_id,
                start_time: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                duration: 0,
                active_agent: "unknown",
                status: "active",
                project_context: {
                    working_directory: $working_dir,
                    git_branch: "unknown",
                    git_commit: "unknown",
                    project_name: ($working_dir | split("/") | .[-1]),
                    environment: {}
                },
                claude_code_state: {
                    model: "claude-sonnet-4-20250514",
                    settings: {},
                    active_commands: [],
                    hooks_enabled: true
                }
            }'
    fi
}

# Get context usage data
get_context_usage_data() {
    if [ -f "$SCRIPT_DIR/context-monitor.sh" ]; then
        local stats_data
        stats_data=$("$SCRIPT_DIR/context-monitor.sh" stats json 2>/dev/null || echo '{}')
        echo "$stats_data" | jq '.stats // {
            tokens_used: 0,
            baseline_tokens: 350,
            priming_tokens: 0,
            dynamic_tokens: 0,
            peak_usage: 0,
            threshold_status: "normal",
            files_read: [],
            searches_performed: [],
            tool_usage: {}
        }'
    else
        jq -n '{
            tokens_used: 0,
            baseline_tokens: 350,
            priming_tokens: 0,
            dynamic_tokens: 0,
            peak_usage: 0,
            threshold_status: "normal",
            files_read: [],
            searches_performed: [],
            tool_usage: {}
        }'
    fi
}

# Get knowledge graph data
get_knowledge_graph_data() {
    # This would integrate with actual knowledge tracking system
    # For now, return empty structure
    jq -n '{
        discoveries: [],
        patterns: [],
        decisions: [],
        learning_outcomes: []
    }'
}

# Get current session ID
get_current_session_id() {
    local session_file="$CONTEXT_DIR/current_session.json"
    
    if [ -f "$session_file" ] && jq -e '.session_id' "$session_file" >/dev/null 2>&1; then
        jq -r '.session_id' "$session_file"
    else
        # Generate new session ID
        echo "$(date +%Y%m%d)$(openssl rand -hex 4 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | fold -w 8 | head -n 1)"
    fi
}

# Get project state data
get_project_state_data() {
    jq -n \
        --arg pwd "$PWD" \
        --argjson file_count "$(find . -type f -name '*.md' -o -name '*.json' -o -name '*.sh' 2>/dev/null | wc -l)" \
        '{
            working_directory: $pwd,
            file_count: $file_count,
            last_modified: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }'
}

# Get git state data
get_git_state_data() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        jq -n \
            --arg branch "$(git branch --show-current 2>/dev/null || echo 'unknown')" \
            --arg commit "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
            --arg status "$(git status --porcelain 2>/dev/null | wc -l)" \
            '{
                branch: $branch,
                commit: $commit,
                dirty_files: ($status | tonumber),
                is_git_repo: true
            }'
    else
        jq -n '{is_git_repo: false}'
    fi
}

# Validate bundle against schema
validate_bundle_schema() {
    local bundle_file="$1"
    
    # Basic JSON validation
    if ! jq empty "$bundle_file" 2>/dev/null; then
        log_error "Invalid JSON in bundle file" "HANDOFF_MANAGER"
        return 1
    fi
    
    # Advanced schema validation (if ajv available)
    if command -v ajv &> /dev/null && [ -f "$SCHEMA_FILE" ]; then
        if ! ajv validate -s "$SCHEMA_FILE" -d "$bundle_file" 2>/dev/null; then
            log_error "Bundle schema validation failed" "HANDOFF_MANAGER"
            return 1
        fi
    fi
    
    # Basic structure validation
    local required_fields=("bundle_metadata" "session_state" "context_usage" "knowledge_graph")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$bundle_file" >/dev/null 2>&1; then
            log_error "Missing required field: $field" "HANDOFF_MANAGER"
            return 1
        fi
    done
    
    return 0
}

# Load handoff bundle
load_handoff_bundle() {
    local bundle_identifier="${1:-latest}"
    local restore_mode="${2:-full}"
    local validation_level="${3:-strict}"
    
    log_info "Loading handoff bundle: $bundle_identifier (mode=$restore_mode)" "HANDOFF_MANAGER"
    
    local start_time
    start_time=$(date +%s)
    
    # Find bundle file
    local bundle_file
    bundle_file=$(find_bundle_file "$bundle_identifier")
    
    if [ -z "$bundle_file" ] || [ ! -f "$bundle_file" ]; then
        log_error "Bundle not found: $bundle_identifier" "HANDOFF_MANAGER"
        return 1
    fi
    
    # Decompress if necessary
    local temp_file
    temp_file=$(mktemp)
    
    if [[ "$bundle_file" == *.gz ]]; then
        if ! gunzip -c "$bundle_file" > "$temp_file"; then
            log_error "Failed to decompress bundle" "HANDOFF_MANAGER"
            rm -f "$temp_file"
            return 1
        fi
    else
        cp "$bundle_file" "$temp_file"
    fi
    
    # Validate bundle
    if [ "$validation_level" = "strict" ] && ! validate_bundle_schema "$temp_file"; then
        log_error "Bundle validation failed" "HANDOFF_MANAGER"
        rm -f "$temp_file"
        return 1
    fi
    
    # Extract bundle data
    local bundle_data
    bundle_data=$(cat "$temp_file")
    
    # Restore based on mode
    case "$restore_mode" in
        "full")
            restore_full_context "$bundle_data"
            ;;
        "session-only")
            restore_session_context "$bundle_data"
            ;;
        "context-only")
            restore_context_data "$bundle_data"
            ;;
        "agents-only")
            restore_agent_state "$bundle_data"
            ;;
        *)
            log_error "Unknown restore mode: $restore_mode" "HANDOFF_MANAGER"
            rm -f "$temp_file"
            return 1
            ;;
    esac
    
    rm -f "$temp_file"
    
    # Performance check
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -gt "$MAX_LOAD_TIME_SECONDS" ]; then
        log_warning "Bundle loading took ${duration}s (threshold: ${MAX_LOAD_TIME_SECONDS}s)" "HANDOFF_MANAGER"
    fi
    
    # Update monitoring
    if [ -f "$SCRIPT_DIR/context-monitor.sh" ]; then
        "$SCRIPT_DIR/context-monitor.sh" track handoff load_bundle 500 handoff
    fi
    
    if [ -f "$SCRIPT_DIR/token-logger.sh" ]; then
        "$SCRIPT_DIR/token-logger.sh" log handoff load_bundle 50 handoff system
    fi
    
    log_info "Handoff bundle loaded successfully: $bundle_identifier (${duration}s)" "HANDOFF_MANAGER"
    
    # Display restoration summary
    show_restoration_summary "$bundle_data" "$restore_mode"
}

# Find bundle file by identifier
find_bundle_file() {
    local identifier="$1"
    
    case "$identifier" in
        "latest")
            # Find most recent bundle
            find "$HANDOFF_DIR/active" -name "*.json*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
            ;;
        *"_"*)
            # Full bundle ID
            find "$HANDOFF_DIR" -name "${identifier}.json*" -type f 2>/dev/null | head -1
            ;;
        *)
            # Partial match
            find "$HANDOFF_DIR" -name "*${identifier}*.json*" -type f 2>/dev/null | head -1
            ;;
    esac
}

# Restore full context
restore_full_context() {
    local bundle_data="$1"
    
    echo -e "${BLUE}🔄 Restoring full context from handoff bundle...${NC}"
    
    # Restore session state
    restore_session_context "$bundle_data"
    
    # Restore context usage data
    restore_context_data "$bundle_data"
    
    # Restore agent coordination
    restore_agent_state "$bundle_data"
    
    echo -e "${GREEN}✅ Full context restoration completed${NC}"
}

# Restore session context
restore_session_context() {
    local bundle_data="$1"
    local session_file="$CONTEXT_DIR/current_session.json"
    
    echo "• Restoring session state..."
    
    # Extract and restore session data
    echo "$bundle_data" | jq '.session_state' > "$session_file"
    
    # Update project context if needed
    local bundle_working_dir
    bundle_working_dir=$(echo "$bundle_data" | jq -r '.session_state.project_context.working_directory')
    
    if [ "$bundle_working_dir" != "$PWD" ]; then
        echo -e "${YELLOW}⚠️  Working directory changed: $bundle_working_dir → $PWD${NC}"
    fi
}

# Restore context usage data
restore_context_data() {
    local bundle_data="$1"
    
    echo "• Restoring context usage data..."
    
    # Update context monitor if available
    if [ -f "$SCRIPT_DIR/context-monitor.sh" ]; then
        local context_tokens
        context_tokens=$(echo "$bundle_data" | jq -r '.context_usage.tokens_used')
        "$SCRIPT_DIR/context-monitor.sh" track restored restore_context "$context_tokens" handoff
    fi
}

# Restore agent state
restore_agent_state() {
    local bundle_data="$1"
    
    echo "• Restoring agent coordination state..."
    
    # Extract active agents
    local active_agents
    active_agents=$(echo "$bundle_data" | jq -r '.agent_coordination.active_agents[]?.agent_name // empty')
    
    if [ -n "$active_agents" ]; then
        echo "  Active agents to restore:"
        echo "$active_agents" | sed 's/^/    - /'
    fi
}

# Show restoration summary
show_restoration_summary() {
    local bundle_data="$1"
    local restore_mode="$2"
    
    echo ""
    echo -e "${GREEN}Context Restoration Summary${NC}"
    echo "=========================="
    
    # Bundle information
    local bundle_id
    local created_at
    local bundle_type
    bundle_id=$(echo "$bundle_data" | jq -r '.bundle_metadata.bundle_id')
    created_at=$(echo "$bundle_data" | jq -r '.bundle_metadata.created_at')
    bundle_type=$(echo "$bundle_data" | jq -r '.bundle_metadata.bundle_type')
    
    echo "Bundle ID: $bundle_id"
    echo "Created: $created_at"
    echo "Type: $bundle_type"
    echo "Restore Mode: $restore_mode"
    
    # Context information
    local tokens_used
    tokens_used=$(echo "$bundle_data" | jq -r '.context_usage.tokens_used // 0')
    echo "Context Tokens: $tokens_used"
    
    # Session information
    local session_duration
    session_duration=$(echo "$bundle_data" | jq -r '.session_state.duration // 0')
    echo "Session Duration: ${session_duration}s"
    
    echo ""
}

# Emergency context optimization
emergency_context_optimization() {
    local optimization_level="${1:-aggressive}"
    
    log_info "Triggering emergency context optimization: level=$optimization_level" "HANDOFF_MANAGER"
    
    echo -e "${RED}🚨 EMERGENCY CONTEXT OPTIMIZATION${NC}"
    echo "================================="
    echo ""
    
    # Create emergency handoff bundle
    echo "1. Creating emergency handoff bundle..."
    local emergency_bundle_id
    emergency_bundle_id=$(create_handoff_bundle "emergency" "gzip" "critical")
    
    if [ -n "$emergency_bundle_id" ]; then
        echo -e "${GREEN}   ✅ Emergency bundle saved: $emergency_bundle_id${NC}"
        
        # Move to emergency directory
        local bundle_file="$HANDOFF_DIR/active/${emergency_bundle_id}.json.gz"
        local emergency_file="$HANDOFF_DIR/emergency/${emergency_bundle_id}.json.gz"
        
        if [ -f "$bundle_file" ]; then
            mv "$bundle_file" "$emergency_file"
            echo "   📁 Bundle moved to emergency storage"
        fi
    else
        echo -e "${RED}   ❌ Failed to create emergency bundle${NC}"
    fi
    
    # Clear non-essential context
    echo "2. Clearing non-essential context..."
    if [ -f "$SCRIPT_DIR/context-monitor.sh" ]; then
        "$SCRIPT_DIR/context-monitor.sh" optimize "$optimization_level"
    fi
    
    # Reset session tracking
    echo "3. Resetting session tracking..."
    if [ -f "$SCRIPT_DIR/context-monitor.sh" ]; then
        "$SCRIPT_DIR/context-monitor.sh" reset
    fi
    
    echo ""
    echo -e "${GREEN}Emergency optimization completed${NC}"
    echo "To restore context: $0 load $emergency_bundle_id"
}

# List available handoff bundles
list_handoff_bundles() {
    local format="${1:-human}"
    local filter="${2:-all}"
    
    echo "Available Handoff Bundles"
    echo "========================"
    echo ""
    
    case "$format" in
        "json")
            list_bundles_json "$filter"
            ;;
        "csv")
            list_bundles_csv "$filter"
            ;;
        "human"|*)
            list_bundles_human "$filter"
            ;;
    esac
}

# List bundles in human format
list_bundles_human() {
    local filter="$1"
    
    for dir in "$HANDOFF_DIR/active" "$HANDOFF_DIR/emergency" "$HANDOFF_DIR/archive"; do
        if [ ! -d "$dir" ]; then
            continue
        fi
        
        local dir_name
        dir_name=$(basename "$dir")
        
        case "$filter" in
            "all"|"$dir_name")
                echo "${dir_name^} Bundles:"
                echo "$(printf '%*s' ${#dir_name} '' | tr ' ' '-')--------"
                
                find "$dir" -name "*.json*" -type f -printf '%T@ %p %s\n' 2>/dev/null | sort -nr | while read -r timestamp path size; do
                    local bundle_name
                    bundle_name=$(basename "$path" | sed 's/\.\(json\|gz\)$//g')
                    local date_str
                    date_str=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
                    local size_kb=$((size / 1024))
                    
                    echo "  $bundle_name"
                    echo "    Date: $date_str"
                    echo "    Size: ${size_kb}KB"
                    echo ""
                done
                ;;
        esac
    done
}

# Archive old bundles
archive_old_bundles() {
    local retention_days="${1:-7}"
    local dry_run="${2:-false}"
    
    log_info "Archiving bundles older than $retention_days days (dry_run=$dry_run)" "HANDOFF_MANAGER"
    
    local archived_count=0
    local deleted_count=0
    
    # Archive active bundles
    find "$HANDOFF_DIR/active" -name "*.json*" -type f -mtime +"$retention_days" | while read -r bundle_file; do
        local bundle_name
        bundle_name=$(basename "$bundle_file")
        
        if [ "$dry_run" = "true" ]; then
            echo "Would archive: $bundle_name"
        else
            if mv "$bundle_file" "$HANDOFF_DIR/archive/"; then
                echo "Archived: $bundle_name"
                archived_count=$((archived_count + 1))
            fi
        fi
    done
    
    # Delete very old archived bundles
    local archive_retention=$((retention_days * 4))
    find "$HANDOFF_DIR/archive" -name "*.json*" -type f -mtime +"$archive_retention" | while read -r bundle_file; do
        local bundle_name
        bundle_name=$(basename "$bundle_file")
        
        if [ "$dry_run" = "true" ]; then
            echo "Would delete: $bundle_name"
        else
            if rm -f "$bundle_file"; then
                echo "Deleted: $bundle_name"
                deleted_count=$((deleted_count + 1))
            fi
        fi
    done
    
    if [ "$dry_run" = "false" ]; then
        log_info "Archive completed: $archived_count archived, $deleted_count deleted" "HANDOFF_MANAGER"
    fi
}

# Usage information
usage() {
    echo "AWOC Context Handoff Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                           Initialize handoff system"
    echo "  save [type] [compression]      Create handoff bundle"
    echo "  load <bundle-id> [mode]        Load handoff bundle"
    echo "  emergency [level]              Emergency context optimization"
    echo "  list [format] [filter]         List available bundles"
    echo "  archive [days] [dry-run]       Archive old bundles"
    echo "  validate <bundle-id>           Validate bundle integrity"
    echo "  help                           Show this help"
    echo ""
    echo "Save Options:"
    echo "  type: manual (default), automatic, emergency, scheduled"
    echo "  compression: gzip (default), none"
    echo ""
    echo "Load Options:"
    echo "  mode: full (default), session-only, context-only, agents-only"
    echo ""
    echo "List Options:"
    echo "  format: human (default), json, csv"
    echo "  filter: all (default), active, emergency, archive"
    echo ""
    echo "Examples:"
    echo "  $0 save manual gzip"
    echo "  $0 load latest full"
    echo "  $0 load 20250108_143022_abc12345"
    echo "  $0 emergency aggressive"
    echo "  $0 list human active"
    echo ""
    echo "Files:"
    echo "  Handoff Dir: $HANDOFF_DIR"
    echo "  Schema: $SCHEMA_FILE"
}

# Main function
main() {
    case "${1:-help}" in
        init)
            if init_handoff_system; then
                echo "✅ Context handoff system initialized"
            else
                echo "❌ Failed to initialize handoff system" >&2
                exit 1
            fi
            ;;
        save)
            local bundle_id
            bundle_id=$(create_handoff_bundle "${2:-manual}" "${3:-gzip}" "${4:-medium}")
            if [ -n "$bundle_id" ]; then
                echo "✅ Handoff bundle created: $bundle_id"
            else
                echo "❌ Failed to create handoff bundle" >&2
                exit 1
            fi
            ;;
        load)
            if [ $# -lt 2 ]; then
                echo "Error: load requires bundle identifier" >&2
                echo "Usage: $0 load <bundle-id> [mode]" >&2
                exit 1
            fi
            load_handoff_bundle "$2" "${3:-full}" "${4:-strict}"
            ;;
        emergency)
            emergency_context_optimization "${2:-aggressive}"
            ;;
        list)
            list_handoff_bundles "${2:-human}" "${3:-all}"
            ;;
        archive)
            archive_old_bundles "${2:-7}" "${3:-false}"
            ;;
        validate)
            if [ $# -lt 2 ]; then
                echo "Error: validate requires bundle identifier" >&2
                exit 1
            fi
            local bundle_file
            bundle_file=$(find_bundle_file "$2")
            if [ -n "$bundle_file" ] && validate_bundle_schema "$bundle_file"; then
                echo "✅ Bundle validation successful: $2"
            else
                echo "❌ Bundle validation failed: $2" >&2
                exit 1
            fi
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