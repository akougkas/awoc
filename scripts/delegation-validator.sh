#!/bin/bash

# AWOC Delegation Validator
# Validates delegation requests and resource availability
# Usage: delegation-validator.sh [agent-name] [token-budget] [priority]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh"

# Set session ID if not provided
AWOC_SESSION_ID="${AWOC_SESSION_ID:-delegation-$(date +%s)}"
AWOC_LOG_LEVEL="${AWOC_LOG_LEVEL:-INFO}"

# Default limits
DEFAULT_MAX_TOKENS=5000
MAX_PARALLEL_AGENTS=10
CRITICAL_TOKEN_THRESHOLD=20000
HIGH_TOKEN_THRESHOLD=15000

# Agent-specific configurations
declare -A AGENT_CONFIGS=(
    ["architect"]="model:opus max_tokens:8000 specialization:design_analysis tools:Read,Write,Task"
    ["docs-fetcher"]="model:haiku max_tokens:5000 specialization:research_documentation tools:WebFetch,Read,Write"
    ["workforce"]="model:sonnet max_tokens:12000 specialization:implementation_testing tools:Read,Write,Edit,Bash"
)

# Agent validation registry
AGENT_REGISTRY_FILE="${HOME}/.awoc/agent-registry.json"
DELEGATION_LOG="${HOME}/.awoc/logs/delegation.log"

validate_agent_exists() {
    local agent_name="$1"
    
    # Check if agent exists in .claude/agents/
    if [[ -f ".claude/agents/${agent_name}.md" ]]; then
        log_info "Agent ${agent_name} found in local registry"
        return 0
    fi
    
    # Check if it's a known agent type
    if [[ -n "${AGENT_CONFIGS[$agent_name]:-}" ]]; then
        log_info "Agent ${agent_name} is a known agent type"
        return 0
    fi
    
    # Check if we can create it dynamically
    if command -v "scripts/create-subagent.md" >/dev/null 2>&1; then
        log_warn "Agent ${agent_name} not found, but can be created dynamically"
        return 0
    fi
    
    log_error "Agent ${agent_name} not found and cannot be created"
    return 1
}

validate_token_budget() {
    local agent_name="$1"
    local requested_budget="$2"
    local priority="${3:-medium}"
    
    # Get agent-specific limits
    local agent_config="${AGENT_CONFIGS[$agent_name]:-}"
    local max_tokens=""
    
    if [[ -n "$agent_config" ]]; then
        max_tokens=$(echo "$agent_config" | grep -o 'max_tokens:[0-9]*' | cut -d: -f2)
    fi
    
    max_tokens=${max_tokens:-$DEFAULT_MAX_TOKENS}
    
    # Validate requested budget doesn't exceed agent limits
    if [[ $requested_budget -gt $max_tokens ]]; then
        log_error "Requested budget ($requested_budget) exceeds agent limit ($max_tokens) for ${agent_name}"
        return 1
    fi
    
    # Check system-wide token availability
    local current_usage
    # For now, use a default low usage since context-monitor doesn't have get-usage-percentage yet
    current_usage="0"
    
    case "$priority" in
        "critical")
            if [[ $current_usage -gt 70 ]]; then
                log_warn "High system usage (${current_usage}%) for critical delegation"
            fi
            ;;
        "high")
            if [[ $current_usage -gt 80 ]]; then
                log_error "System usage too high (${current_usage}%) for high priority delegation"
                return 1
            fi
            ;;
        "medium"|"low")
            if [[ $current_usage -gt 85 ]]; then
                log_error "System usage too high (${current_usage}%) for delegation"
                return 1
            fi
            ;;
    esac
    
    log_info "Token budget validation passed: ${requested_budget} tokens for ${agent_name}"
    return 0
}

validate_concurrent_agents() {
    local current_agents
    current_agents=$(pgrep -f "claude.*agent:" 2>/dev/null | wc -l || echo "0")
    current_agents=$(echo "$current_agents" | tr -d '\n\r\t ')  # Remove all whitespace
    
    if [[ $current_agents -ge $MAX_PARALLEL_AGENTS ]]; then
        log_error "Maximum parallel agents ($MAX_PARALLEL_AGENTS) already running"
        return 1
    fi
    
    log_info "Concurrent agent validation passed: ${current_agents}/${MAX_PARALLEL_AGENTS} agents running"
    return 0
}

validate_task_description() {
    local task_description="$1"
    
    # Check minimum task description length
    if [[ ${#task_description} -lt 10 ]]; then
        log_error "Task description too short (minimum 10 characters): '$task_description'"
        return 1
    fi
    
    # Check maximum task description length
    if [[ ${#task_description} -gt 500 ]]; then
        log_error "Task description too long (maximum 500 characters): '${task_description:0:50}...'"
        return 1
    fi
    
    # Check for potentially harmful patterns
    local dangerous_patterns=("rm -rf" "sudo" "chmod 777" "eval" "exec")
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$task_description" == *"$pattern"* ]]; then
            log_error "Task description contains potentially dangerous pattern: '$pattern'"
            return 1
        fi
    done
    
    log_info "Task description validation passed"
    return 0
}

validate_priority() {
    local priority="$1"
    
    case "$priority" in
        "critical"|"high"|"medium"|"low")
            log_info "Priority validation passed: $priority"
            return 0
            ;;
        *)
            log_error "Invalid priority level: '$priority'. Must be one of: critical, high, medium, low"
            return 1
            ;;
    esac
}

check_resource_conflicts() {
    local agent_name="$1"
    local task_description="$2"
    
    # Check if agent is already working on similar task
    local active_tasks_file="${HOME}/.awoc/active-delegations.json"
    
    if [[ -f "$active_tasks_file" ]]; then
        local similar_tasks
        similar_tasks=$(jq -r ".[] | select(.agent == \"$agent_name\" and (.task | test(\"$(echo "$task_description" | head -c 20)\"))) | .task" "$active_tasks_file" 2>/dev/null || echo "")
        
        if [[ -n "$similar_tasks" ]]; then
            log_warn "Agent $agent_name is already working on similar task: $similar_tasks"
            # Don't fail, just warn
        fi
    fi
    
    return 0
}

generate_delegation_id() {
    local agent_name="$1"
    local timestamp=$(date +%s)
    local random=$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')
    echo "${agent_name}-${timestamp}-${random}"
}

log_delegation_request() {
    local agent_name="$1"
    local task_description="$2"
    local token_budget="$3"
    local priority="$4"
    local delegation_id="$5"
    local status="$6"
    
    local log_entry="{
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"delegation_id\": \"$delegation_id\",
        \"agent\": \"$agent_name\",
        \"task\": \"$(echo "$task_description" | sed 's/"/\\"/g')\",
        \"token_budget\": $token_budget,
        \"priority\": \"$priority\",
        \"status\": \"$status\",
        \"session_id\": \"${AWOC_SESSION_ID:-unknown}\"
    }"
    
    # Append to delegation log
    mkdir -p "$(dirname "$DELEGATION_LOG")"
    echo "$log_entry" >> "$DELEGATION_LOG"
}

main() {
    local agent_name="${1:-}"
    local task_description="${2:-}"
    local token_budget="${3:-$DEFAULT_MAX_TOKENS}"
    local priority="${4:-medium}"
    
    if [[ -z "$agent_name" || -z "$task_description" ]]; then
        log_error "Usage: delegation-validator.sh [agent-name] [task-description] [token-budget] [priority]"
        exit 1
    fi
    
    # Generate delegation ID for tracking
    local delegation_id
    delegation_id=$(generate_delegation_id "$agent_name")
    
    log_info "Validating delegation request: $delegation_id"
    
    # Run all validations
    local validation_status="pending"
    
    if validate_agent_exists "$agent_name" && \
       validate_task_description "$task_description" && \
       validate_token_budget "$agent_name" "$token_budget" "$priority" && \
       validate_priority "$priority" && \
       validate_concurrent_agents && \
       check_resource_conflicts "$agent_name" "$task_description"; then
        
        validation_status="approved"
        log_info "✓ Delegation validation passed: $delegation_id"
        
        # Store delegation metadata for tracking
        local metadata="{
            \"delegation_id\": \"$delegation_id\",
            \"agent\": \"$agent_name\",
            \"task\": \"$(echo "$task_description" | sed 's/"/\\"/g')\",
            \"token_budget\": $token_budget,
            \"priority\": \"$priority\",
            \"status\": \"approved\",
            \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
        
        # Output delegation metadata for caller
        echo "$metadata"
        
    else
        validation_status="rejected"
        log_error "✗ Delegation validation failed: $delegation_id"
        exit 1
    fi
    
    # Log the delegation request
    log_delegation_request "$agent_name" "$task_description" "$token_budget" "$priority" "$delegation_id" "$validation_status"
    
    return 0
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi