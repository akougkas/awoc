#!/bin/bash

# AWOC Token Attribution Logger
# Detailed token usage tracking with attribution and analytics
# Based on architect specifications

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
LOGS_DIR="$CONTEXT_DIR/logs"
ATTRIBUTION_FILE="$LOGS_DIR/token_attribution.jsonl"
BUDGET_FILE="$CONTEXT_DIR/budgets.json"
SESSION_LOG="$LOGS_DIR/session_$(date +%Y%m%d).jsonl"

# Default budgets (tokens)
DEFAULT_AGENT_BUDGET=5000
DEFAULT_SESSION_BUDGET=200000
DEFAULT_PRIMING_BUDGET=3000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize token logging system
init_token_logging() {
    log_info "Initializing token attribution logging system" "TOKEN_LOGGER"
    
    # Create logs directory
    if ! mkdir -p "$LOGS_DIR" 2>/dev/null; then
        log_error "Failed to create logs directory: $LOGS_DIR" "TOKEN_LOGGER"
        return 1
    fi
    
    # Initialize budget tracking if not exists
    if [ ! -f "$BUDGET_FILE" ]; then
        init_budget_tracking
    fi
    
    # Create attribution file if not exists
    if [ ! -f "$ATTRIBUTION_FILE" ]; then
        touch "$ATTRIBUTION_FILE"
        log_info "Created token attribution log: $ATTRIBUTION_FILE" "TOKEN_LOGGER"
    fi
    
    # Create session log if not exists
    if [ ! -f "$SESSION_LOG" ]; then
        touch "$SESSION_LOG"
        log_info "Created session log: $SESSION_LOG" "TOKEN_LOGGER"
    fi
    
    log_info "Token attribution logging system initialized" "TOKEN_LOGGER"
    return 0
}

# Initialize budget tracking
init_budget_tracking() {
    cat > "$BUDGET_FILE" << EOF
{
    "version": "1.0.0",
    "session_budget": {
        "total": $DEFAULT_SESSION_BUDGET,
        "used": 0,
        "remaining": $DEFAULT_SESSION_BUDGET,
        "reset_date": "$(date -Iseconds)"
    },
    "agent_budgets": {
        "api-researcher": {
            "allocated": $DEFAULT_AGENT_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_AGENT_BUDGET
        },
        "content-writer": {
            "allocated": $DEFAULT_AGENT_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_AGENT_BUDGET
        },
        "data-analyst": {
            "allocated": $DEFAULT_AGENT_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_AGENT_BUDGET
        },
        "project-manager": {
            "allocated": $DEFAULT_AGENT_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_AGENT_BUDGET
        },
        "learning-assistant": {
            "allocated": $DEFAULT_AGENT_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_AGENT_BUDGET
        },
        "creative-assistant": {
            "allocated": $DEFAULT_AGENT_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_AGENT_BUDGET
        }
    },
    "priming_budgets": {
        "api-integration": {
            "allocated": $DEFAULT_PRIMING_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_PRIMING_BUDGET
        },
        "bug-fixing": {
            "allocated": $DEFAULT_PRIMING_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_PRIMING_BUDGET
        },
        "feature-development": {
            "allocated": $DEFAULT_PRIMING_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_PRIMING_BUDGET
        },
        "code-review": {
            "allocated": $DEFAULT_PRIMING_BUDGET,
            "used": 0,
            "remaining": $DEFAULT_PRIMING_BUDGET
        }
    }
}
EOF
    log_info "Initialized budget tracking configuration" "TOKEN_LOGGER"
}

# Log token usage with attribution
log_token_usage() {
    local agent="${1:-unknown}"
    local operation="${2:-unknown}"
    local tokens="${3:-0}"
    local context_type="${4:-general}"
    local source="${5:-user}"
    local metadata="${6:-{}}"
    
    # Validate token count
    if ! [[ "$tokens" =~ ^[0-9]+$ ]]; then
        log_warning "Invalid token count: $tokens, defaulting to 0" "TOKEN_LOGGER"
        tokens=0
    fi
    
    local timestamp
    timestamp=$(date -Iseconds)
    local session_id
    session_id=$(get_current_session_id)
    
    # Create attribution record
    local attribution_record
    attribution_record=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg session_id "$session_id" \
        --arg agent "$agent" \
        --arg operation "$operation" \
        --argjson tokens "$tokens" \
        --arg context_type "$context_type" \
        --arg source "$source" \
        --argjson metadata "$metadata" \
        '{
            timestamp: $timestamp,
            session_id: $session_id,
            agent: $agent,
            operation: $operation,
            tokens: $tokens,
            context_type: $context_type,
            source: $source,
            metadata: $metadata
        }')
    
    # Atomic write to attribution file
    echo "$attribution_record" >> "$ATTRIBUTION_FILE"
    echo "$attribution_record" >> "$SESSION_LOG"
    
    # Update budgets
    update_budget_tracking "$agent" "$operation" "$tokens" "$context_type"
    
    # Check budget limits
    check_budget_limits "$agent" "$operation" "$tokens"
    
    log_debug "Logged token usage: agent=$agent, op=$operation, tokens=$tokens" "TOKEN_LOGGER"
}

# Get current session ID
get_current_session_id() {
    local session_file="${HOME}/.awoc/context/current_session.json"
    
    if [ -f "$session_file" ]; then
        jq -r '.session_id' "$session_file" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Update budget tracking
update_budget_tracking() {
    local agent="$1"
    local operation="$2"
    local tokens="$3"
    local context_type="$4"
    
    if [ ! -f "$BUDGET_FILE" ]; then
        init_budget_tracking
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    # Update session budget
    jq --argjson tokens "$tokens" \
       --arg agent "$agent" \
       --arg context_type "$context_type" \
       '
    .session_budget.used += $tokens |
    .session_budget.remaining = (.session_budget.total - .session_budget.used) |
    
    # Update agent budget if agent exists
    if .agent_budgets[$agent] then
        .agent_budgets[$agent].used += $tokens |
        .agent_budgets[$agent].remaining = (.agent_budgets[$agent].allocated - .agent_budgets[$agent].used)
    else . end |
    
    # Update priming budget if context_type is priming
    if ($context_type == "priming" and .priming_budgets[$agent]) then
        .priming_budgets[$agent].used += $tokens |
        .priming_budgets[$agent].remaining = (.priming_budgets[$agent].allocated - .priming_budgets[$agent].used)
    else . end
    ' "$BUDGET_FILE" > "$temp_file" && mv "$temp_file" "$BUDGET_FILE"
    
    rm -f "$temp_file"
}

# Check budget limits
check_budget_limits() {
    local agent="$1"
    local operation="$2"
    local tokens="$3"
    
    if [ ! -f "$BUDGET_FILE" ]; then
        return 0
    fi
    
    local budget_data
    budget_data=$(cat "$BUDGET_FILE")
    
    # Check session budget
    local session_remaining
    session_remaining=$(echo "$budget_data" | jq -r '.session_budget.remaining')
    
    if [ "$session_remaining" -lt 0 ]; then
        log_error "SESSION BUDGET EXCEEDED: Remaining $session_remaining tokens" "TOKEN_LOGGER"
        echo -e "${RED}🚨 SESSION BUDGET EXCEEDED${NC}" >&2
    elif [ "$session_remaining" -lt 10000 ]; then
        log_warning "Session budget low: $session_remaining tokens remaining" "TOKEN_LOGGER"
        echo -e "${YELLOW}⚠️  Session budget low: $session_remaining tokens remaining${NC}" >&2
    fi
    
    # Check agent budget
    local agent_remaining
    agent_remaining=$(echo "$budget_data" | jq -r ".agent_budgets[\"$agent\"].remaining // 0")
    
    if [ "$agent_remaining" -lt 0 ]; then
        log_warning "Agent $agent budget exceeded: $agent_remaining tokens" "TOKEN_LOGGER"
        echo -e "${YELLOW}⚠️  Agent $agent budget exceeded${NC}" >&2
    elif [ "$agent_remaining" -lt 500 ]; then
        log_info "Agent $agent budget low: $agent_remaining tokens remaining" "TOKEN_LOGGER"
    fi
}

# Generate usage report
generate_usage_report() {
    local format="${1:-human}"
    local period="${2:-today}"
    local output_file="${3:-}"
    
    log_info "Generating usage report: format=$format, period=$period" "TOKEN_LOGGER"
    
    case "$format" in
        "json")
            generate_json_report "$period" "$output_file"
            ;;
        "csv")
            generate_csv_report "$period" "$output_file"
            ;;
        "human"|*)
            generate_human_report "$period" "$output_file"
            ;;
    esac
}

# Generate JSON report
generate_json_report() {
    local period="$1"
    local output_file="$2"
    local report_data
    
    # Get attribution data for period
    local attribution_data
    attribution_data=$(get_attribution_data_for_period "$period")
    
    # Get budget data
    local budget_data
    if [ -f "$BUDGET_FILE" ]; then
        budget_data=$(cat "$BUDGET_FILE")
    else
        budget_data='{}'
    fi
    
    # Generate report
    report_data=$(jq -s '
    {
        "report_metadata": {
            "generated_at": now | strftime("%Y-%m-%d %H:%M:%S"),
            "period": "'$period'",
            "format": "json"
        },
        "summary": {
            "total_tokens": (.[0] | map(.tokens) | add // 0),
            "total_operations": (.[0] | length),
            "unique_agents": (.[0] | map(.agent) | unique | length),
            "unique_operations": (.[0] | map(.operation) | unique | length)
        },
        "attribution_data": .[0],
        "budget_status": .[1],
        "agent_breakdown": (.[0] | group_by(.agent) | map({
            agent: .[0].agent,
            total_tokens: (map(.tokens) | add),
            operations: length,
            avg_tokens_per_operation: ((map(.tokens) | add) / length)
        })),
        "operation_breakdown": (.[0] | group_by(.operation) | map({
            operation: .[0].operation,
            total_tokens: (map(.tokens) | add),
            count: length,
            avg_tokens: ((map(.tokens) | add) / length)
        }))
    }' <(echo "$attribution_data") <(echo "$budget_data"))
    
    if [ -n "$output_file" ]; then
        echo "$report_data" > "$output_file"
        echo "JSON report saved to: $output_file"
    else
        echo "$report_data"
    fi
}

# Generate CSV report
generate_csv_report() {
    local period="$1"
    local output_file="$2"
    local csv_data
    
    # Generate CSV header
    csv_data="timestamp,session_id,agent,operation,tokens,context_type,source"$'\n'
    
    # Get attribution data and convert to CSV
    local attribution_data
    attribution_data=$(get_attribution_data_for_period "$period")
    
    csv_data+=$(echo "$attribution_data" | jq -r '.[] | [
        .timestamp,
        .session_id,
        .agent,
        .operation,
        .tokens,
        .context_type,
        .source
    ] | @csv')
    
    if [ -n "$output_file" ]; then
        echo "$csv_data" > "$output_file"
        echo "CSV report saved to: $output_file"
    else
        echo "$csv_data"
    fi
}

# Generate human-readable report
generate_human_report() {
    local period="$1"
    local output_file="$2"
    local report_text
    
    # Get data
    local attribution_data
    attribution_data=$(get_attribution_data_for_period "$period")
    local total_tokens
    total_tokens=$(echo "$attribution_data" | jq '[.[].tokens] | add // 0')
    local total_operations
    total_operations=$(echo "$attribution_data" | jq 'length')
    
    # Build report
    report_text="AWOC Token Usage Report ($period)"$'\n'
    report_text+="================================"$'\n'
    report_text+="Generated: $(date)"$'\n'
    report_text+=""$'\n'
    report_text+="Summary:"$'\n'
    report_text+="  Total Tokens: $total_tokens"$'\n'
    report_text+="  Total Operations: $total_operations"$'\n'
    report_text+=""$'\n'
    
    # Agent breakdown
    report_text+="Agent Usage:"$'\n'
    report_text+="------------"$'\n'
    echo "$attribution_data" | jq -r '
    group_by(.agent) | 
    map({
        agent: .[0].agent, 
        total: (map(.tokens) | add), 
        ops: length
    }) | 
    sort_by(-.total)[] | 
    "  \(.agent): \(.total) tokens (\(.ops) operations)"'
    
    report_text+=""$'\n'
    
    # Operation breakdown
    report_text+="Operation Usage:"$'\n'
    report_text+="---------------"$'\n'
    echo "$attribution_data" | jq -r '
    group_by(.operation) | 
    map({
        operation: .[0].operation, 
        total: (map(.tokens) | add), 
        count: length
    }) | 
    sort_by(-.total)[] | 
    "  \(.operation): \(.total) tokens (\(.count) times)"'
    
    # Budget status
    if [ -f "$BUDGET_FILE" ]; then
        report_text+=""$'\n'
        report_text+="Budget Status:"$'\n'
        report_text+="-------------"$'\n'
        
        local session_used
        local session_total
        local session_remaining
        session_used=$(jq -r '.session_budget.used' "$BUDGET_FILE")
        session_total=$(jq -r '.session_budget.total' "$BUDGET_FILE")
        session_remaining=$(jq -r '.session_budget.remaining' "$BUDGET_FILE")
        
        report_text+="  Session: $session_used / $session_total tokens ($session_remaining remaining)"$'\n'
        
        # Agent budgets
        jq -r '.agent_budgets | to_entries[] | "  \(.key): \(.value.used) / \(.value.allocated) tokens (\(.value.remaining) remaining)"' "$BUDGET_FILE" | while read -r line; do
            report_text+="$line"$'\n'
        done
    fi
    
    if [ -n "$output_file" ]; then
        echo "$report_text" > "$output_file"
        echo "Report saved to: $output_file"
    else
        echo "$report_text"
    fi
}

# Get attribution data for period
get_attribution_data_for_period() {
    local period="$1"
    local today
    today=$(date +%Y-%m-%d)
    
    if [ ! -f "$ATTRIBUTION_FILE" ]; then
        echo "[]"
        return
    fi
    
    case "$period" in
        "today")
            jq -s 'map(select(.timestamp | startswith("'$today'")))' "$ATTRIBUTION_FILE"
            ;;
        "yesterday")
            local yesterday
            yesterday=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "$today")
            jq -s 'map(select(.timestamp | startswith("'$yesterday'")))' "$ATTRIBUTION_FILE"
            ;;
        "week")
            local week_ago
            week_ago=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "$today")
            jq -s 'map(select(.timestamp >= "'$week_ago'"))' "$ATTRIBUTION_FILE"
            ;;
        "all"|*)
            jq -s '.' "$ATTRIBUTION_FILE"
            ;;
    esac
}

# Track agent usage specifically
track_agent_usage() {
    local agent="$1"
    local operation="$2"
    local tokens="$3"
    local context_type="${4:-execution}"
    
    log_token_usage "$agent" "$operation" "$tokens" "$context_type" "agent" "{\"tracking_type\": \"agent_usage\"}"
    
    # Check if agent needs optimization
    check_agent_optimization_needs "$agent" "$tokens"
}

# Check if agent needs optimization
check_agent_optimization_needs() {
    local agent="$1"
    local tokens="$2"
    
    if [ ! -f "$BUDGET_FILE" ]; then
        return 0
    fi
    
    local agent_used
    agent_used=$(jq -r ".agent_budgets[\"$agent\"].used // 0" "$BUDGET_FILE")
    
    local agent_allocated
    agent_allocated=$(jq -r ".agent_budgets[\"$agent\"].allocated // 0" "$BUDGET_FILE")
    
    if [ "$agent_allocated" -gt 0 ]; then
        local usage_percentage
        usage_percentage=$(( (agent_used * 100) / agent_allocated ))
        
        if [ "$usage_percentage" -gt 80 ]; then
            log_warning "Agent $agent using ${usage_percentage}% of budget - consider optimization" "TOKEN_LOGGER"
            echo -e "${YELLOW}⚠️  Agent $agent budget at ${usage_percentage}% - optimization recommended${NC}" >&2
        fi
    fi
}

# Show budget status
show_budget_status() {
    if [ ! -f "$BUDGET_FILE" ]; then
        echo "No budget file found. Run 'init' to initialize budget tracking."
        return 1
    fi
    
    local budget_data
    budget_data=$(cat "$BUDGET_FILE")
    
    echo "AWOC Token Budget Status"
    echo "========================"
    echo ""
    
    # Session budget
    local session_used
    local session_total
    local session_remaining
    session_used=$(echo "$budget_data" | jq -r '.session_budget.used')
    session_total=$(echo "$budget_data" | jq -r '.session_budget.total')
    session_remaining=$(echo "$budget_data" | jq -r '.session_budget.remaining')
    local session_percentage
    session_percentage=$(( (session_used * 100) / session_total ))
    
    echo "Session Budget:"
    echo "  Used: $session_used / $session_total tokens (${session_percentage}%)"
    echo "  Remaining: $session_remaining tokens"
    
    if [ "$session_percentage" -gt 90 ]; then
        echo -e "  Status: ${RED}CRITICAL${NC}"
    elif [ "$session_percentage" -gt 75 ]; then
        echo -e "  Status: ${YELLOW}WARNING${NC}"
    else
        echo -e "  Status: ${GREEN}NORMAL${NC}"
    fi
    
    echo ""
    echo "Agent Budgets:"
    echo "$budget_data" | jq -r '.agent_budgets | to_entries[] | "  \(.key): \(.value.used) / \(.value.allocated) tokens (\((.value.used * 100) / .value.allocated | floor)%)"'
    
    echo ""
    echo "Priming Budgets:"
    echo "$budget_data" | jq -r '.priming_budgets | to_entries[] | "  \(.key): \(.value.used) / \(.value.allocated) tokens (\((.value.used * 100) / .value.allocated | floor)%)"'
}

# Reset budget tracking
reset_budgets() {
    echo "Resetting budget tracking..."
    rm -f "$BUDGET_FILE"
    init_budget_tracking
    log_info "Budget tracking reset" "TOKEN_LOGGER"
    echo "✅ Budget tracking reset successfully"
}

# Clean old logs
clean_logs() {
    local days="${1:-30}"
    
    echo "Cleaning token logs older than $days days..."
    
    # Archive old session logs
    find "$LOGS_DIR" -name "session_*.jsonl" -mtime +"$days" -exec gzip {} \; 2>/dev/null || true
    
    # Remove very old compressed logs
    find "$LOGS_DIR" -name "session_*.jsonl.gz" -mtime +"$((days * 3))" -delete 2>/dev/null || true
    
    log_info "Token logs cleaned (older than $days days)" "TOKEN_LOGGER"
    echo "✅ Log cleanup completed"
}

# Usage information
usage() {
    echo "AWOC Token Attribution Logger"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                        Initialize token logging system"
    echo "  log <agent> <op> <tokens> [type] [source]  Log token usage"
    echo "  report [format] [period] [file]  Generate usage report"
    echo "  budget                      Show budget status"
    echo "  track <agent> <op> <tokens> [type]  Track agent usage"
    echo "  reset                       Reset budget tracking"
    echo "  clean [days]               Clean logs older than days (default: 30)"
    echo "  help                        Show this help"
    echo ""
    echo "Formats: human (default), json, csv"
    echo "Periods: today (default), yesterday, week, all"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 log api-researcher execute 2500 priming user"
    echo "  $0 report json today usage_report.json"
    echo "  $0 track content-writer generate 1800"
    echo "  $0 budget"
    echo ""
    echo "Files:"
    echo "  Attribution: $ATTRIBUTION_FILE"
    echo "  Budgets: $BUDGET_FILE"
    echo "  Session Log: $SESSION_LOG"
}

# Main function
main() {
    case "${1:-help}" in
        init)
            if init_token_logging; then
                echo "✅ Token attribution logging initialized"
            else
                echo "❌ Failed to initialize token logging" >&2
                exit 1
            fi
            ;;
        log)
            if [ $# -lt 4 ]; then
                echo "Error: log requires agent, operation, and token count" >&2
                echo "Usage: $0 log <agent> <operation> <tokens> [type] [source]" >&2
                exit 1
            fi
            log_token_usage "$2" "$3" "$4" "${5:-general}" "${6:-user}"
            ;;
        report)
            generate_usage_report "${2:-human}" "${3:-today}" "${4:-}"
            ;;
        budget)
            show_budget_status
            ;;
        track)
            if [ $# -lt 4 ]; then
                echo "Error: track requires agent, operation, and token count" >&2
                echo "Usage: $0 track <agent> <operation> <tokens> [type]" >&2
                exit 1
            fi
            track_agent_usage "$2" "$3" "$4" "${5:-execution}"
            ;;
        reset)
            reset_budgets
            ;;
        clean)
            clean_logs "${2:-30}"
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