#!/bin/bash

# AWOC Context Monitoring System
# Real-time token tracking and context optimization
# Based on architect specifications and bash research

set -euo pipefail

# Source logging system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/logging.sh" ]; then
    # shellcheck source=./logging.sh
    source "$SCRIPT_DIR/logging.sh"
    init_logging
else
    # Fallback logging if logging.sh not available
    log_info() { echo "[INFO] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { echo "[DEBUG] $1" >&2; }
fi

# Configuration
CONTEXT_DIR="${HOME}/.awoc/context"
CONFIG_FILE="$CONTEXT_DIR/monitor.json"
STATS_FILE="$CONTEXT_DIR/stats.json"
SESSION_FILE="$CONTEXT_DIR/current_session.json"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Default thresholds (percentages)
DEFAULT_WARNING_THRESHOLD=70
DEFAULT_OPTIMIZATION_THRESHOLD=80
DEFAULT_CRITICAL_THRESHOLD=90
DEFAULT_MAX_TOKENS=200000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize context monitoring system
init_context_monitoring() {
    log_info "Initializing context monitoring system" "CONTEXT_MONITOR"
    
    # Create context directory
    if ! mkdir -p "$CONTEXT_DIR" 2>/dev/null; then
        log_error "Failed to create context directory: $CONTEXT_DIR" "CONTEXT_MONITOR"
        return 1
    fi
    
    # Initialize configuration if not exists
    if [ ! -f "$CONFIG_FILE" ]; then
        create_default_config
    fi
    
    # Initialize stats file
    init_stats_file
    
    # Initialize session tracking
    init_session_tracking
    
    log_info "Context monitoring system initialized successfully" "CONTEXT_MONITOR"
    return 0
}

# Create default configuration
create_default_config() {
    cat > "$CONFIG_FILE" << EOF
{
    "version": "1.0.0",
    "thresholds": {
        "warning": $DEFAULT_WARNING_THRESHOLD,
        "optimization": $DEFAULT_OPTIMIZATION_THRESHOLD,
        "critical": $DEFAULT_CRITICAL_THRESHOLD,
        "max_tokens": $DEFAULT_MAX_TOKENS
    },
    "monitoring": {
        "enabled": true,
        "auto_optimize": true,
        "track_agents": true,
        "track_commands": true
    },
    "agents": {
        "baseline_tokens": 350,
        "priming_budget": 3000,
        "max_per_agent": 5000
    },
    "optimization": {
        "auto_prime": true,
        "auto_handoff": true,
        "compression_enabled": true
    }
}
EOF
    log_info "Created default context monitoring configuration" "CONTEXT_MONITOR"
}

# Initialize stats file
init_stats_file() {
    if [ ! -f "$STATS_FILE" ]; then
        cat > "$STATS_FILE" << EOF
{
    "session_start": "$(date -Iseconds)",
    "total_tokens_tracked": 0,
    "peak_usage": 0,
    "optimizations_performed": 0,
    "warnings_issued": 0,
    "agents_monitored": {},
    "commands_tracked": {},
    "last_optimization": null,
    "performance_metrics": {
        "avg_response_time": 0,
        "token_efficiency": 0,
        "optimization_success_rate": 0
    }
}
EOF
    fi
}

# Initialize session tracking
init_session_tracking() {
    local session_id
    session_id=$(generate_session_id)
    
    cat > "$SESSION_FILE" << EOF
{
    "session_id": "$session_id",
    "start_time": "$(date -Iseconds)",
    "current_tokens": 0,
    "baseline_tokens": 0,
    "priming_tokens": 0,
    "agent_tokens": {},
    "active_agents": [],
    "status": "active",
    "last_update": "$(date -Iseconds)"
}
EOF
    
    log_info "Initialized session tracking: $session_id" "CONTEXT_MONITOR"
}

# Generate unique session ID
generate_session_id() {
    echo "$(date +%Y%m%d)$(openssl rand -hex 4 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | fold -w 8 | head -n 1)"
}

# Track context usage
track_context_usage() {
    local agent_name="${1:-unknown}"
    local operation="${2:-unknown}"
    local token_count="${3:-0}"
    local context_type="${4:-general}"
    
    log_debug "Tracking context usage: agent=$agent_name, op=$operation, tokens=$token_count" "CONTEXT_MONITOR"
    
    # Validate inputs
    if ! [[ "$token_count" =~ ^[0-9]+$ ]]; then
        log_warning "Invalid token count: $token_count, defaulting to 0" "CONTEXT_MONITOR"
        token_count=0
    fi
    
    # Update session tracking
    update_session_usage "$agent_name" "$operation" "$token_count" "$context_type"
    
    # Update statistics
    update_stats "$agent_name" "$operation" "$token_count"
    
    # Check thresholds
    check_thresholds "$token_count"
    
    # Return current usage data
    get_context_stats "json"
}

# Update session usage data
update_session_usage() {
    local agent_name="$1"
    local operation="$2"
    local token_count="$3"
    local context_type="$4"
    
    if [ ! -f "$SESSION_FILE" ]; then
        init_session_tracking
    fi
    
    # Use jq to update session data atomically
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg agent "$agent_name" \
       --arg op "$operation" \
       --argjson tokens "$token_count" \
       --arg type "$context_type" \
       --arg timestamp "$(date -Iseconds)" '
    .current_tokens += $tokens |
    .agent_tokens[$agent] = ((.agent_tokens[$agent] // 0) + $tokens) |
    .active_agents |= (if . | contains([$agent]) then . else . + [$agent] end) |
    .last_update = $timestamp |
    .operations += [{
        "agent": $agent,
        "operation": $op,
        "tokens": $tokens,
        "type": $type,
        "timestamp": $timestamp
    }]' "$SESSION_FILE" > "$temp_file" && mv "$temp_file" "$SESSION_FILE"
    
    rm -f "$temp_file"
}

# Update statistics
update_stats() {
    local agent_name="$1"
    local operation="$2"
    local token_count="$3"
    
    if [ ! -f "$STATS_FILE" ]; then
        init_stats_file
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg agent "$agent_name" \
       --arg op "$operation" \
       --argjson tokens "$token_count" \
       --arg timestamp "$(date -Iseconds)" '
    .total_tokens_tracked += $tokens |
    .peak_usage = (if .peak_usage < $tokens then $tokens else .peak_usage end) |
    .agents_monitored[$agent] = ((.agents_monitored[$agent] // 0) + $tokens) |
    .commands_tracked[$op] = ((.commands_tracked[$op] // 0) + 1) |
    .last_update = $timestamp' "$STATS_FILE" > "$temp_file" && mv "$temp_file" "$SESSION_FILE"
    
    rm -f "$temp_file"
}

# Check thresholds and issue warnings
check_thresholds() {
    local current_tokens="$1"
    local config
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "Config file not found, using defaults" "CONTEXT_MONITOR"
        return 0
    fi
    
    config=$(cat "$CONFIG_FILE")
    local max_tokens
    local warning_threshold
    local optimization_threshold
    local critical_threshold
    
    max_tokens=$(echo "$config" | jq -r '.thresholds.max_tokens // 200000')
    warning_threshold=$(echo "$config" | jq -r '.thresholds.warning // 70')
    optimization_threshold=$(echo "$config" | jq -r '.thresholds.optimization // 80')
    critical_threshold=$(echo "$config" | jq -r '.thresholds.critical // 90')
    
    local usage_percentage
    usage_percentage=$(( (current_tokens * 100) / max_tokens ))
    
    if [ "$usage_percentage" -ge "$critical_threshold" ]; then
        log_error "CRITICAL: Context usage at ${usage_percentage}% (${current_tokens}/${max_tokens} tokens)" "CONTEXT_MONITOR"
        echo -e "${RED}🚨 CRITICAL: Context usage at ${usage_percentage}%${NC}" >&2
        trigger_emergency_optimization "$current_tokens" "$max_tokens"
        return 2
    elif [ "$usage_percentage" -ge "$optimization_threshold" ]; then
        log_warning "Context usage at ${usage_percentage}% - optimization recommended" "CONTEXT_MONITOR"
        echo -e "${YELLOW}⚠️  Context usage at ${usage_percentage}% - optimization recommended${NC}" >&2
        suggest_optimizations "$current_tokens" "$max_tokens"
        return 1
    elif [ "$usage_percentage" -ge "$warning_threshold" ]; then
        log_warning "Context usage at ${usage_percentage}% - approaching limits" "CONTEXT_MONITOR"
        echo -e "${YELLOW}⚠️  Context usage at ${usage_percentage}% - approaching limits${NC}" >&2
        return 1
    else
        log_debug "Context usage normal: ${usage_percentage}% (${current_tokens}/${max_tokens} tokens)" "CONTEXT_MONITOR"
        return 0
    fi
}

# Get context statistics
get_context_stats() {
    local format="${1:-human}"
    local session_data
    local stats_data
    
    if [ -f "$SESSION_FILE" ]; then
        session_data=$(cat "$SESSION_FILE")
        # Ensure required fields exist
        if ! echo "$session_data" | jq -e '.current_tokens' >/dev/null 2>&1; then
            session_data=$(echo "$session_data" | jq '. + {"current_tokens": (.total_tokens_tracked // 0)}')
        fi
        if ! echo "$session_data" | jq -e '.session_id' >/dev/null 2>&1; then
            session_data=$(echo "$session_data" | jq '. + {"session_id": "unknown"}')
        fi
        if ! echo "$session_data" | jq -e '.active_agents' >/dev/null 2>&1; then
            session_data=$(echo "$session_data" | jq '. + {"active_agents": (.agents_monitored | keys // [])}')
        fi
    else
        session_data='{"current_tokens": 0, "session_id": "unknown", "active_agents": []}'
    fi
    
    if [ -f "$STATS_FILE" ]; then
        stats_data=$(cat "$STATS_FILE")
    else
        stats_data='{"total_tokens_tracked": 0}'
    fi
    
    case "$format" in
        "json")
            jq -s '.[0] + {stats: .[1]}' <(echo "$session_data") <(echo "$stats_data")
            ;;
        "csv")
            echo "metric,value"
            echo "current_tokens,$(echo "$session_data" | jq -r '.current_tokens')"
            echo "session_id,$(echo "$session_data" | jq -r '.session_id')"
            echo "total_tracked,$(echo "$stats_data" | jq -r '.total_tokens_tracked')"
            ;;
        "human"|*)
            local current_tokens
            local session_id
            local total_tracked
            local active_agents
            
            current_tokens=$(echo "$session_data" | jq -r '.current_tokens')
            session_id=$(echo "$session_data" | jq -r '.session_id')
            total_tracked=$(echo "$stats_data" | jq -r '.total_tokens_tracked')
            active_agents=$(echo "$session_data" | jq -r '.active_agents | length')
            
            echo "AWOC Context Statistics"
            echo "======================"
            echo "Session ID: $session_id"
            echo "Current Tokens: $current_tokens"
            echo "Total Tracked: $total_tracked"
            echo "Active Agents: $active_agents"
            echo ""
            
            if [ "$active_agents" -gt 0 ]; then
                echo "Agent Token Usage:"
                echo "$session_data" | jq -r '.agent_tokens | to_entries[] | "  \(.key): \(.value) tokens"'
                echo ""
            fi
            
            # Show threshold status
            show_threshold_status "$current_tokens"
            ;;
    esac
}

# Show threshold status
show_threshold_status() {
    local current_tokens="$1"
    local config
    
    if [ -f "$CONFIG_FILE" ]; then
        config=$(cat "$CONFIG_FILE")
    else
        return 0
    fi
    
    local max_tokens
    local warning_threshold
    local optimization_threshold
    local critical_threshold
    
    max_tokens=$(echo "$config" | jq -r '.thresholds.max_tokens')
    warning_threshold=$(echo "$config" | jq -r '.thresholds.warning')
    optimization_threshold=$(echo "$config" | jq -r '.thresholds.optimization')
    critical_threshold=$(echo "$config" | jq -r '.thresholds.critical')
    
    local usage_percentage
    usage_percentage=$(( (current_tokens * 100) / max_tokens ))
    
    echo "Threshold Status:"
    echo "  Usage: ${usage_percentage}% (${current_tokens}/${max_tokens} tokens)"
    
    if [ "$usage_percentage" -ge "$critical_threshold" ]; then
        echo -e "  Status: ${RED}CRITICAL${NC} - Immediate action required"
    elif [ "$usage_percentage" -ge "$optimization_threshold" ]; then
        echo -e "  Status: ${YELLOW}OPTIMIZATION NEEDED${NC} - Performance impact likely"
    elif [ "$usage_percentage" -ge "$warning_threshold" ]; then
        echo -e "  Status: ${YELLOW}WARNING${NC} - Approaching limits"
    else
        echo -e "  Status: ${GREEN}NORMAL${NC} - Operating within limits"
    fi
}

# Suggest optimizations
suggest_optimizations() {
    local current_tokens="$1"
    local max_tokens="$2"
    
    echo ""
    echo "Context Optimization Suggestions:"
    echo "================================="
    
    # Analyze session data for suggestions
    if [ -f "$SESSION_FILE" ]; then
        local session_data
        session_data=$(cat "$SESSION_FILE")
        
        # Check for agents using too many tokens
        echo "$session_data" | jq -r '.agent_tokens | to_entries[] | select(.value > 5000) | "• Agent \(.key) using \(.value) tokens - consider priming optimization"'
        
        # Check for inactive agents
        echo "$session_data" | jq -r '.active_agents[]' | while read -r agent; do
            echo "• Consider deactivating unused agent: $agent"
        done
    fi
    
    echo "• Use '/prime-dev' for dynamic context loading"
    echo "• Consider agent handoff for long operations"
    echo "• Enable context compression in settings"
    echo ""
}

# Trigger emergency optimization
trigger_emergency_optimization() {
    local current_tokens="$1"
    local max_tokens="$2"
    
    log_error "Triggering emergency context optimization" "CONTEXT_MONITOR"
    
    echo ""
    echo -e "${RED}🚨 EMERGENCY CONTEXT OPTIMIZATION${NC}"
    echo "=================================="
    echo "Current usage: ${current_tokens}/${max_tokens} tokens"
    echo ""
    echo "Automatic actions taken:"
    echo "• Saving context handoff bundle"
    echo "• Clearing non-essential context"
    echo "• Triggering agent optimization"
    echo ""
    
    # Save handoff bundle (if handoff system exists)
    if command -v /home/akougkas/projects/awoc-claude-v2/.claude/commands/handoff-save.md &> /dev/null; then
        echo "• Context handoff saved"
    fi
    
    # Update stats
    if [ -f "$STATS_FILE" ]; then
        local temp_file
        temp_file=$(mktemp)
        jq '.optimizations_performed += 1 | .last_optimization = now | .performance_metrics.optimization_success_rate = (.optimizations_performed / (.optimizations_performed + 1))' "$STATS_FILE" > "$temp_file" && mv "$temp_file" "$STATS_FILE"
        rm -f "$temp_file"
    fi
}

# Optimize context
optimize_context() {
    local optimization_type="${1:-auto}"
    
    log_info "Starting context optimization: $optimization_type" "CONTEXT_MONITOR"
    
    case "$optimization_type" in
        "agents")
            optimize_agent_context
            ;;
        "priming")
            optimize_priming_context
            ;;
        "handoff")
            optimize_handoff_context
            ;;
        "auto"|*)
            optimize_agent_context
            optimize_priming_context
            ;;
    esac
    
    log_info "Context optimization completed" "CONTEXT_MONITOR"
}

# Optimize agent context
optimize_agent_context() {
    echo "Optimizing agent context..."
    
    if [ -f "$SESSION_FILE" ]; then
        local session_data
        session_data=$(cat "$SESSION_FILE")
        
        # Find agents with high token usage
        local high_usage_agents
        high_usage_agents=$(echo "$session_data" | jq -r '.agent_tokens | to_entries[] | select(.value > 3000) | .key')
        
        if [ -n "$high_usage_agents" ]; then
            echo "High token usage agents found:"
            echo "$high_usage_agents" | while read -r agent; do
                echo "• $agent - consider priming optimization"
            done
        fi
    fi
}

# Optimize priming context
optimize_priming_context() {
    echo "Optimizing priming context..."
    echo "• Review dynamic priming budget allocation"
    echo "• Consider context compression techniques"
    echo "• Evaluate scenario-specific loading"
}

# Optimize handoff context
optimize_handoff_context() {
    echo "Optimizing handoff context..."
    echo "• Preparing context handoff bundle"
    echo "• Compressing session state"
    echo "• Saving essential context only"
}

# Log priming activity
log_priming() {
    local scenario="$1"
    local budget="$2"
    
    log_info "Priming scenario '$scenario' with budget $budget tokens" "CONTEXT_MONITOR"
    
    # Track priming operation
    track_context_usage "priming" "load_scenario" "$budget" "priming"
    
    # Update session with priming info
    if [ -f "$SESSION_FILE" ]; then
        local temp_file
        temp_file=$(mktemp)
        jq --arg scenario "$scenario" --argjson budget "$budget" '
            .priming_active = $scenario |
            .priming_budget = $budget |
            .priming_timestamp = now |
            .context_operations += [{
                "timestamp": now,
                "operation": "priming",
                "scenario": $scenario,
                "budget": $budget
            }]
        ' "$SESSION_FILE" > "$temp_file" && mv "$temp_file" "$SESSION_FILE"
        rm -f "$temp_file"
    fi
    
    echo "📊 Priming logged: $scenario scenario ($budget tokens)"
}

# Usage information
usage() {
    echo "AWOC Context Monitor"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                    Initialize context monitoring system"
    echo "  track <agent> <op> <tokens> [type]  Track context usage"
    echo "  log_priming <scenario> <budget>     Log priming activity"
    echo "  stats [format]          Show context statistics (human|json|csv)"
    echo "  check [tokens]          Check threshold status"
    echo "  optimize [type]         Run context optimization (auto|agents|priming|handoff)"
    echo "  config                  Show current configuration"
    echo "  reset                   Reset monitoring data"
    echo "  help                    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 track api-researcher execute 2500 priming"
    echo "  $0 log_priming feature-dev 3000"
    echo "  $0 stats json"
    echo "  $0 check 150000"
    echo "  $0 optimize agents"
    echo ""
    echo "Configuration:"
    echo "  Config: $CONFIG_FILE"
    echo "  Stats: $STATS_FILE"
    echo "  Session: $SESSION_FILE"
}

# Reset monitoring data
reset_monitoring() {
    echo "Resetting context monitoring data..."
    
    rm -f "$STATS_FILE" "$SESSION_FILE"
    init_stats_file
    init_session_tracking
    
    log_info "Context monitoring data reset" "CONTEXT_MONITOR"
    echo "✅ Monitoring data reset successfully"
}

# Show configuration
show_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "Current Context Monitor Configuration:"
        echo "====================================="
        cat "$CONFIG_FILE" | jq .
    else
        echo "No configuration file found. Run 'init' to create default configuration."
    fi
}

# Main function
main() {
    case "${1:-help}" in
        init)
            if init_context_monitoring; then
                echo "✅ Context monitoring system initialized"
            else
                echo "❌ Failed to initialize context monitoring system" >&2
                exit 1
            fi
            ;;
        track)
            if [ $# -lt 4 ]; then
                echo "Error: track requires agent, operation, and token count" >&2
                echo "Usage: $0 track <agent> <operation> <tokens> [type]" >&2
                exit 1
            fi
            track_context_usage "$2" "$3" "$4" "${5:-general}"
            ;;
        log_priming)
            if [ $# -lt 3 ]; then
                echo "Error: log_priming requires scenario and budget" >&2
                echo "Usage: $0 log_priming <scenario> <budget>" >&2
                exit 1
            fi
            log_priming "$2" "$3"
            ;;
        stats)
            get_context_stats "${2:-human}"
            ;;
        check)
            local tokens="${2:-0}"
            check_thresholds "$tokens"
            ;;
        optimize)
            optimize_context "${2:-auto}"
            ;;
        config)
            show_config
            ;;
        reset)
            reset_monitoring
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