#!/bin/bash

# AWOC Background Task Manager
# Manages lifecycle of background Claude instances
# Usage: background-task-manager.sh [command] [args...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh"

# Directories
BACKGROUND_DIR="${HOME}/.awoc/background"
TASKS_DIR="${BACKGROUND_DIR}/tasks"
REGISTRY_FILE="${BACKGROUND_DIR}/task-registry.json"
POOL_DIR="${BACKGROUND_DIR}/pool"

# Limits and defaults
MAX_BACKGROUND_TASKS=10
DEFAULT_TIMEOUT=600
DEFAULT_TOKEN_BUDGET=5000
CLEANUP_RETENTION_HOURS=24

# Initialize background infrastructure
initialize_background_system() {
    log_info "Initializing AWOC background task system"
    
    # Create directory structure
    mkdir -p "$TASKS_DIR" "$POOL_DIR" "${BACKGROUND_DIR}/logs" "${BACKGROUND_DIR}/cache"
    
    # Initialize registry if not exists
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo '{"tasks": {}, "metadata": {"created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "version": "1.0"}}' > "$REGISTRY_FILE"
    fi
    
    # Setup background monitoring
    if ! pgrep -f "background-monitor.sh" >/dev/null; then
        nohup "${SCRIPT_DIR}/background-monitor.sh" daemon >/dev/null 2>&1 &
        log_info "Background monitor daemon started"
    fi
}

# Generate unique task ID
generate_task_id() {
    local task_type="${1:-generic}"
    local timestamp=$(date +%s)
    local random=$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')
    echo "${task_type}-${timestamp}-${random}"
}

# Initialize specific background task
initialize_task() {
    local task_type="$1"
    local output_file="$2"
    local model="${3:-sonnet}"
    local token_budget="${4:-$DEFAULT_TOKEN_BUDGET}"
    local timeout="${5:-$DEFAULT_TIMEOUT}"
    
    # Generate task ID and create directory
    local task_id
    task_id=$(generate_task_id "$task_type")
    local task_dir="${TASKS_DIR}/${task_id}"
    
    log_info "Initializing background task: $task_id"
    
    # Create task directory
    mkdir -p "$task_dir"
    
    # Create task configuration
    local task_config
    task_config=$(cat << EOF
{
    "task_id": "$task_id",
    "task_type": "$task_type",
    "output_file": "$output_file",
    "model": "$model",
    "token_budget": $token_budget,
    "timeout": $timeout,
    "parent_session": "${AWOC_SESSION_ID:-unknown}",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "initializing",
    "priority": "medium",
    "working_directory": "$(pwd)",
    "environment": {
        "PROJECT_ROOT": "${PROJECT_ROOT:-$(pwd)}",
        "AWOC_VERSION": "${AWOC_VERSION:-2.0}",
        "USER": "${USER:-unknown}"
    },
    "resource_limits": {
        "max_memory": "2GB",
        "max_disk": "1GB",
        "max_network": "100MB"
    },
    "metadata": {
        "created_by": "background-task-manager",
        "parent_pid": $$,
        "execution_mode": "isolated"
    }
}
EOF
)
    
    echo "$task_config" > "${task_dir}/task-config.json"
    
    # Register task in global registry
    register_task_in_registry "$task_id" "$task_config"
    
    # Output task metadata for caller
    echo "$task_config"
}

# Register task in global registry
register_task_in_registry() {
    local task_id="$1"
    local task_config="$2"
    
    # Update registry file
    local temp_registry
    temp_registry=$(mktemp)
    
    jq --arg task_id "$task_id" --argjson config "$task_config" \
       '.tasks[$task_id] = $config' "$REGISTRY_FILE" > "$temp_registry"
    
    mv "$temp_registry" "$REGISTRY_FILE"
    
    log_debug "Task $task_id registered in registry"
}

# Launch background Claude instance
launch_background_instance() {
    local task_id="$1"
    local task_dir="${TASKS_DIR}/${task_id}"
    
    if [[ ! -d "$task_dir" ]]; then
        log_error "Task directory not found: $task_dir"
        return 1
    fi
    
    # Load task configuration
    local task_config
    task_config=$(cat "${task_dir}/task-config.json")
    
    local model output_file token_budget timeout task_type
    model=$(echo "$task_config" | jq -r '.model')
    output_file=$(echo "$task_config" | jq -r '.output_file')
    token_budget=$(echo "$task_config" | jq -r '.token_budget')
    timeout=$(echo "$task_config" | jq -r '.timeout')
    task_type=$(echo "$task_config" | jq -r '.task_type')
    
    log_info "Launching background instance for task: $task_id"
    
    # Generate task prompt
    local task_prompt
    task_prompt=$(generate_task_prompt "$task_type" "$output_file" "$token_budget" "$timeout")
    echo "$task_prompt" > "${task_dir}/task-prompt.txt"
    
    # Create execution wrapper
    create_execution_wrapper "$task_id" "$task_dir" "$model" "$token_budget" "$timeout" "$output_file"
    
    # Update task status to 'launching'
    update_task_status "$task_id" "launching"
    
    # Launch background execution
    local wrapper_script="${task_dir}/execute-task.sh"
    local log_file="${task_dir}/execution.log"
    
    nohup "$wrapper_script" > "$log_file" 2>&1 &
    local background_pid=$!
    
    # Store PID and update status
    echo "$background_pid" > "${task_dir}/task.pid"
    update_task_status "$task_id" "running" "$background_pid"
    
    log_info "Background task $task_id launched with PID: $background_pid"
    
    # Return task metadata
    echo "$task_id"
}

# Generate task-specific prompt
generate_task_prompt() {
    local task_type="$1"
    local output_file="$2"
    local token_budget="$3"
    local timeout="$4"
    
    local base_prompt="You are an independent background agent executing a focused task.

## Task Configuration
- **Task Type**: $task_type
- **Output File**: $output_file
- **Token Budget**: $token_budget tokens maximum
- **Time Limit**: $timeout seconds
- **Execution Mode**: Isolated background processing

## Core Operating Principles
1. **Focus**: Execute only the specified task, ignore unrelated work
2. **Efficiency**: Optimize for token usage and execution time
3. **Quality**: Deliver production-ready, well-structured results
4. **Autonomy**: Work independently without requiring user input
5. **Completeness**: Provide comprehensive results within constraints

## Resource Management
- Monitor token usage continuously
- Respect time limits and fail gracefully if approaching timeout
- Use available tools efficiently: Read, Write, Bash, WebFetch, Grep, Glob
- Save intermediate progress for recovery if interrupted

## Output Requirements
- Save all results to the specified output file: $output_file
- Use structured format appropriate for the task type
- Include metadata about execution (completion status, resource usage)
- Provide clear summary of work completed and any issues encountered"

    # Add task-type specific instructions
    case "$task_type" in
        "research"|"api-research"|"technology-research")
            echo "$base_prompt

## Research Task Instructions
- Gather comprehensive, accurate, and current information
- Validate sources and cross-reference findings  
- Organize results with clear categorization
- Provide actionable recommendations
- Include source citations and references

## Expected Output Structure
- Executive Summary (2-3 sentences)
- Key Findings (bullet points)
- Detailed Analysis (structured sections)
- Recommendations and Next Steps
- Sources and References"
            ;;
            
        "analysis"|"code-analysis"|"performance-analysis"|"security-analysis")
            echo "$base_prompt

## Analysis Task Instructions
- Perform thorough, systematic analysis
- Identify patterns, issues, and opportunities
- Provide root cause analysis where applicable
- Quantify findings with metrics when possible
- Generate actionable recommendations

## Expected Output Structure  
- Analysis Summary
- Methodology Used
- Key Findings by Category
- Risk Assessment and Priority
- Detailed Recommendations
- Implementation Considerations"
            ;;
            
        "testing"|"test-generation"|"qa-validation")
            echo "$base_prompt

## Testing Task Instructions
- Create comprehensive test strategies and cases
- Focus on edge cases and error conditions
- Ensure test coverage and quality
- Provide clear test documentation
- Include both automated and manual test scenarios

## Expected Output Structure
- Test Strategy Overview
- Test Cases and Scenarios  
- Test Implementation (code/scripts)
- Expected Results and Validation
- Test Execution Instructions"
            ;;
            
        "documentation"|"api-docs"|"user-guides")
            echo "$base_prompt

## Documentation Task Instructions
- Write clear, concise, and comprehensive documentation
- Use appropriate structure and formatting
- Include practical examples and use cases
- Ensure accuracy and completeness
- Follow documentation best practices

## Expected Output Structure
- Document Overview and Purpose
- Detailed Content Sections
- Code Examples and Snippets
- Usage Instructions and Guidelines
- FAQ and Troubleshooting"
            ;;
            
        *)
            echo "$base_prompt

## Generic Task Instructions
- Execute the specified task efficiently and thoroughly
- Provide structured, well-organized results
- Include clear documentation of what was accomplished
- Report any issues or limitations encountered

## Expected Output Structure
- Task Summary
- Results and Findings  
- Methodology or Approach Used
- Issues and Limitations
- Recommendations and Next Steps"
            ;;
    esac
}

# Create execution wrapper script
create_execution_wrapper() {
    local task_id="$1"
    local task_dir="$2"
    local model="$3"
    local token_budget="$4"
    local timeout="$5"
    local output_file="$6"
    
    local wrapper_script="${task_dir}/execute-task.sh"
    
    cat > "$wrapper_script" << 'WRAPPER_EOF'
#!/bin/bash
set -euo pipefail

# Task execution wrapper for AWOC background tasks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_ID="$(basename "$(dirname "$SCRIPT_DIR")")"

# Load configuration
TASK_CONFIG="$SCRIPT_DIR/task-config.json"
if [[ ! -f "$TASK_CONFIG" ]]; then
    echo "Error: Task configuration not found" >&2
    exit 1
fi

# Extract configuration
MODEL="$(jq -r '.model' "$TASK_CONFIG")"
TOKEN_BUDGET="$(jq -r '.token_budget' "$TASK_CONFIG")"
TIMEOUT="$(jq -r '.timeout' "$TASK_CONFIG")"
OUTPUT_FILE="$(jq -r '.output_file' "$TASK_CONFIG")"
WORKING_DIR="$(jq -r '.working_directory' "$TASK_CONFIG")"

# Change to working directory
cd "$WORKING_DIR" || exit 1

# Update status to running
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Task execution started" >> "$SCRIPT_DIR/execution.log"

# Function to update task status
update_status() {
    local status="$1"
    local exit_code="${2:-0}"
    
    jq --arg status "$status" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson exit_code "$exit_code" \
       '.status = $status | .updated_at = $timestamp | .exit_code = $exit_code' \
       "$TASK_CONFIG" > "${TASK_CONFIG}.tmp" && mv "${TASK_CONFIG}.tmp" "$TASK_CONFIG"
}

# Function to handle cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        update_status "completed" "$exit_code"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Task completed successfully" >> "$SCRIPT_DIR/execution.log"
    else
        update_status "failed" "$exit_code"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Task failed with exit code $exit_code" >> "$SCRIPT_DIR/execution.log"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

# Update status to running
update_status "running"

# Execute task with Claude
if command -v claude >/dev/null 2>&1; then
    # Use Claude CLI directly
    timeout "$TIMEOUT" claude \
        --model "$MODEL" \
        --max-tokens "$TOKEN_BUDGET" \
        --input "$SCRIPT_DIR/task-prompt.txt" \
        --output "$OUTPUT_FILE" \
        --verbose \
        --log-file "$SCRIPT_DIR/claude-execution.log"
else
    # Fallback: use alternative execution method
    echo "Warning: Claude CLI not found, using fallback execution" >> "$SCRIPT_DIR/execution.log"
    
    # Alternative execution (could be integration with MCP servers, etc.)
    timeout "$TIMEOUT" bash -c "
        echo 'Background task execution fallback for: $TASK_ID' > '$OUTPUT_FILE'
        echo 'Task type: $(jq -r '.task_type' '$TASK_CONFIG')' >> '$OUTPUT_FILE'
        echo 'This would normally be executed by Claude with the prompt from $SCRIPT_DIR/task-prompt.txt' >> '$OUTPUT_FILE'
        echo 'Implementation depends on available Claude integration methods.' >> '$OUTPUT_FILE'
    "
fi

exit_code=$?

# Log resource usage
if command -v ps >/dev/null 2>&1; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Resource usage - PID: $$, Memory: $(ps -p $$ -o rss= 2>/dev/null || echo 'unknown')KB" >> "$SCRIPT_DIR/execution.log"
fi

exit $exit_code
WRAPPER_EOF

    chmod +x "$wrapper_script"
    log_debug "Execution wrapper created: $wrapper_script"
}

# Update task status in configuration and registry
update_task_status() {
    local task_id="$1"
    local status="$2"
    local pid="${3:-}"
    local task_dir="${TASKS_DIR}/${task_id}"
    local config_file="${task_dir}/task-config.json"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Task configuration not found: $config_file"
        return 1
    fi
    
    # Update local task configuration
    local temp_config
    temp_config=$(mktemp)
    
    if [[ -n "$pid" ]]; then
        jq --arg status "$status" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg pid "$pid" \
           '.status = $status | .updated_at = $timestamp | .pid = $pid' \
           "$config_file" > "$temp_config"
    else
        jq --arg status "$status" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           '.status = $status | .updated_at = $timestamp' \
           "$config_file" > "$temp_config"
    fi
    
    mv "$temp_config" "$config_file"
    
    # Update global registry
    local temp_registry
    temp_registry=$(mktemp)
    
    jq --arg task_id "$task_id" --arg status "$status" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.tasks[$task_id].status = $status | .tasks[$task_id].updated_at = $timestamp' \
       "$REGISTRY_FILE" > "$temp_registry"
    
    mv "$temp_registry" "$REGISTRY_FILE"
    
    log_debug "Task $task_id status updated to: $status"
}

# Get task status and information
get_task_info() {
    local task_id="$1"
    local task_dir="${TASKS_DIR}/${task_id}"
    
    if [[ ! -d "$task_dir" ]]; then
        echo "Error: Task not found: $task_id" >&2
        return 1
    fi
    
    local config_file="${task_dir}/task-config.json"
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Task configuration not found" >&2
        return 1
    fi
    
    # Get current process status
    local pid_file="${task_dir}/task.pid"
    local is_running="false"
    
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            is_running="true"
        fi
    fi
    
    # Combine configuration with runtime status
    jq --arg is_running "$is_running" '. + {"is_running": ($is_running == "true")}' "$config_file"
}

# List all background tasks
list_tasks() {
    local status_filter="${1:-all}"
    local format="${2:-table}"
    
    case "$format" in
        "json")
            if [[ "$status_filter" == "all" ]]; then
                cat "$REGISTRY_FILE"
            else
                jq --arg status "$status_filter" '.tasks | to_entries | map(select(.value.status == $status)) | from_entries' "$REGISTRY_FILE"
            fi
            ;;
        "table")
            echo "Task ID                    | Type                | Status      | Created                | Output File"
            echo "---------------------------|--------------------|-----------  |------------------------|---------------------------"
            
            local tasks
            if [[ "$status_filter" == "all" ]]; then
                tasks=$(jq -r '.tasks | to_entries[] | [.key, .value.task_type, .value.status, .value.created_at, .value.output_file] | @tsv' "$REGISTRY_FILE")
            else
                tasks=$(jq -r --arg status "$status_filter" '.tasks | to_entries[] | select(.value.status == $status) | [.key, .value.task_type, .value.status, .value.created_at, .value.output_file] | @tsv' "$REGISTRY_FILE")
            fi
            
            echo "$tasks" | while IFS=$'\t' read -r task_id task_type status created_at output_file; do
                printf "%-26s | %-18s | %-10s | %-22s | %s\n" \
                    "${task_id:0:26}" "${task_type:0:18}" "$status" "${created_at:0:22}" "${output_file:0:30}"
            done
            ;;
    esac
}

# Clean up completed or failed tasks
cleanup_tasks() {
    local retention_hours="${1:-$CLEANUP_RETENTION_HOURS}"
    local dry_run="${2:-false}"
    
    log_info "Cleaning up tasks older than $retention_hours hours (dry_run: $dry_run)"
    
    local cutoff_time
    cutoff_time=$(date -d "$retention_hours hours ago" -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Find tasks to clean up
    local tasks_to_cleanup
    tasks_to_cleanup=$(jq -r --arg cutoff "$cutoff_time" \
        '.tasks | to_entries[] | select(.value.created_at < $cutoff and (.value.status == "completed" or .value.status == "failed")) | .key' \
        "$REGISTRY_FILE")
    
    for task_id in $tasks_to_cleanup; do
        local task_dir="${TASKS_DIR}/${task_id}"
        
        if [[ "$dry_run" == "true" ]]; then
            echo "Would clean up task: $task_id ($task_dir)"
        else
            log_info "Cleaning up task: $task_id"
            
            # Archive task if output file exists
            local config_file="${task_dir}/task-config.json"
            if [[ -f "$config_file" ]]; then
                local output_file
                output_file=$(jq -r '.output_file' "$config_file")
                
                if [[ -f "$output_file" ]]; then
                    local archive_dir="${BACKGROUND_DIR}/archive/$(date +%Y-%m)"
                    mkdir -p "$archive_dir"
                    cp "$output_file" "${archive_dir}/${task_id}-$(basename "$output_file")"
                    log_debug "Archived output file: $output_file"
                fi
            fi
            
            # Remove task directory
            rm -rf "$task_dir"
            
            # Remove from registry
            local temp_registry
            temp_registry=$(mktemp)
            jq --arg task_id "$task_id" 'del(.tasks[$task_id])' "$REGISTRY_FILE" > "$temp_registry"
            mv "$temp_registry" "$REGISTRY_FILE"
        fi
    done
    
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run complete. Use 'false' as second argument to actually clean up."
    else
        log_info "Task cleanup complete"
    fi
}

# Kill and clean up a specific task
terminate_task() {
    local task_id="$1"
    local task_dir="${TASKS_DIR}/${task_id}"
    local pid_file="${task_dir}/task.pid"
    
    if [[ ! -d "$task_dir" ]]; then
        log_error "Task not found: $task_id"
        return 1
    fi
    
    # Kill process if running
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Terminating task process: $task_id (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
            sleep 2
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
                log_warn "Force killed task process: $task_id"
            fi
        fi
    fi
    
    # Update status
    update_task_status "$task_id" "terminated"
    
    log_info "Task terminated: $task_id"
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        "initialize")
            shift
            initialize_task "$@"
            ;;
        "launch")
            shift
            launch_background_instance "$@"
            ;;
        "status"|"info")
            shift
            get_task_info "$@"
            ;;
        "list")
            shift
            list_tasks "$@"
            ;;
        "cleanup")
            shift
            cleanup_tasks "$@"
            ;;
        "terminate"|"kill")
            shift
            terminate_task "$@"
            ;;
        "init-system")
            initialize_background_system
            ;;
        "help"|*)
            cat << 'HELP_EOF'
AWOC Background Task Manager

Commands:
  initialize <task-type> <output-file> [model] [token-budget] [timeout]
             Initialize a new background task
             
  launch <task-id>
             Launch an initialized background task
             
  status <task-id>
  info <task-id>
             Get information about a specific task
             
  list [status-filter] [format]
             List background tasks (filter: all|running|completed|failed)
             (format: table|json)
             
  cleanup [retention-hours] [dry-run]
             Clean up old completed/failed tasks
             
  terminate <task-id>
  kill <task-id>
             Terminate a running background task
             
  init-system
             Initialize the background task system
             
Examples:
  background-task-manager.sh initialize research report.md sonnet 5000 600
  background-task-manager.sh launch research-1234567890-abcd
  background-task-manager.sh list running table
  background-task-manager.sh cleanup 24 false
HELP_EOF
            ;;
    esac
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize system on first run
    if [[ ! -d "$BACKGROUND_DIR" ]]; then
        initialize_background_system
    fi
    
    main "$@"
fi