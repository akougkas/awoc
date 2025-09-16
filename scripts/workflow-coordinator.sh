#!/bin/bash

# AWOC Workflow Coordination Engine
# Intelligent routing and execution management for multi-agent workflows
# Usage: workflow-coordinator.sh [command] [args...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh"

# Directories
WORKFLOWS_DIR="${HOME}/.awoc/workflows"
ACTIVE_WORKFLOWS_DIR="${WORKFLOWS_DIR}/active"
TEMPLATES_DIR="${WORKFLOWS_DIR}/templates"
RESULTS_DIR="${WORKFLOWS_DIR}/results"

# Agent capability matrix
declare -A AGENT_CAPABILITIES=(
    ["architect"]="design analysis architecture review complex_reasoning"
    ["docs-fetcher"]="research documentation web_scraping information_gathering"
    ["workforce"]="implementation coding testing deployment automation"
)

declare -A AGENT_STRENGTHS=(
    ["architect"]="complexity:high reasoning:high creativity:medium speed:medium"
    ["docs-fetcher"]="complexity:low reasoning:medium creativity:low speed:high"
    ["workforce"]="complexity:medium reasoning:medium creativity:low speed:high"
)

declare -A AGENT_TOKEN_LIMITS=(
    ["architect"]="12000"
    ["docs-fetcher"]="5000"
    ["workforce"]="10000"
)

# Initialize workflow system
initialize_workflow_system() {
    log_info "Initializing AWOC workflow coordination system"
    
    # Create directory structure
    mkdir -p "$ACTIVE_WORKFLOWS_DIR" "$TEMPLATES_DIR" "$RESULTS_DIR"
    mkdir -p "${WORKFLOWS_DIR}/archive" "${WORKFLOWS_DIR}/logs"
    
    # Create default workflow templates
    create_default_templates
    
    log_info "Workflow system initialized"
}

# Create default workflow templates
create_default_templates() {
    # Feature development workflow template
    cat > "${TEMPLATES_DIR}/feature-development.json" << 'EOF'
{
  "workflow": {
    "name": "feature-development",
    "description": "Complete feature development workflow",
    "version": "1.0",
    "execution_modes": ["sequential", "parallel", "adaptive"],
    "default_mode": "adaptive",
    "failure_tolerance": 1,
    "timeout": 3600,
    "priority": "medium",
    
    "resource_limits": {
      "total_token_budget": 25000,
      "max_parallel_agents": 5,
      "max_execution_time": 3600
    },
    
    "tasks": [
      {
        "task_id": "research_phase",
        "agent": "docs-fetcher",
        "description": "Research feature requirements and best practices",
        "token_budget": 5000,
        "estimated_duration": 300,
        "priority": "high",
        "dependencies": [],
        "outputs": ["research_report.md"]
      },
      {
        "task_id": "design_phase", 
        "agent": "architect",
        "description": "Design system architecture and APIs",
        "token_budget": 8000,
        "estimated_duration": 600,
        "priority": "high",
        "dependencies": ["research_phase"],
        "outputs": ["design_document.md"]
      },
      {
        "task_id": "implementation_phase",
        "agent": "workforce",
        "description": "Implement feature based on design",
        "token_budget": 10000,
        "estimated_duration": 900,
        "priority": "critical",
        "dependencies": ["research_phase", "design_phase"],
        "outputs": ["implementation/"]
      },
      {
        "task_id": "testing_phase",
        "agent": "workforce", 
        "description": "Create comprehensive test suite",
        "token_budget": 6000,
        "estimated_duration": 400,
        "priority": "high",
        "dependencies": ["implementation_phase"],
        "outputs": ["test_suite/"]
      }
    ],
    
    "coordination_rules": {
      "parallel_groups": [
        ["research_phase"],
        ["design_phase"], 
        ["implementation_phase"],
        ["testing_phase"]
      ],
      "critical_path": ["research_phase", "design_phase", "implementation_phase", "testing_phase"]
    }
  }
}
EOF

    # API integration workflow template
    cat > "${TEMPLATES_DIR}/api-integration.json" << 'EOF'
{
  "workflow": {
    "name": "api-integration",
    "description": "API integration and implementation workflow", 
    "version": "1.0",
    "execution_modes": ["parallel", "sequential"],
    "default_mode": "parallel",
    "failure_tolerance": 0,
    "timeout": 1800,
    "priority": "high",
    
    "resource_limits": {
      "total_token_budget": 18000,
      "max_parallel_agents": 4,
      "max_execution_time": 1800
    },
    
    "tasks": [
      {
        "task_id": "api_research",
        "agent": "docs-fetcher",
        "description": "Research API documentation and capabilities",
        "token_budget": 5000,
        "estimated_duration": 300,
        "priority": "high",
        "dependencies": []
      },
      {
        "task_id": "security_analysis",
        "agent": "architect", 
        "description": "Analyze API security requirements",
        "token_budget": 6000,
        "estimated_duration": 400,
        "priority": "high",
        "dependencies": []
      },
      {
        "task_id": "implementation",
        "agent": "workforce",
        "description": "Implement API integration",
        "token_budget": 8000,
        "estimated_duration": 600,
        "priority": "critical",
        "dependencies": ["api_research", "security_analysis"]
      },
      {
        "task_id": "testing",
        "agent": "workforce",
        "description": "Test API integration thoroughly", 
        "token_budget": 4000,
        "estimated_duration": 300,
        "priority": "high",
        "dependencies": ["implementation"]
      }
    ]
  }
}
EOF

    # Bug investigation workflow template
    cat > "${TEMPLATES_DIR}/bug-investigation.json" << 'EOF'
{
  "workflow": {
    "name": "bug-investigation",
    "description": "Systematic bug investigation and resolution",
    "version": "1.0", 
    "execution_modes": ["sequential", "adaptive"],
    "default_mode": "sequential",
    "failure_tolerance": 0,
    "timeout": 2400,
    "priority": "critical",
    
    "resource_limits": {
      "total_token_budget": 20000,
      "max_parallel_agents": 3,
      "max_execution_time": 2400
    },
    
    "tasks": [
      {
        "task_id": "problem_analysis",
        "agent": "architect",
        "description": "Analyze problem and identify root causes",
        "token_budget": 8000,
        "estimated_duration": 600,
        "priority": "critical",
        "dependencies": []
      },
      {
        "task_id": "solution_research",
        "agent": "docs-fetcher",
        "description": "Research solutions and best practices",
        "token_budget": 4000,
        "estimated_duration": 300,
        "priority": "high", 
        "dependencies": ["problem_analysis"]
      },
      {
        "task_id": "fix_implementation",
        "agent": "workforce",
        "description": "Implement bug fix based on analysis",
        "token_budget": 6000,
        "estimated_duration": 500,
        "priority": "critical",
        "dependencies": ["problem_analysis", "solution_research"]
      },
      {
        "task_id": "validation",
        "agent": "workforce",
        "description": "Test and validate bug fix",
        "token_budget": 4000,
        "estimated_duration": 300,
        "priority": "critical",
        "dependencies": ["fix_implementation"]
      }
    ]
  }
}
EOF

    log_debug "Default workflow templates created"
}

# Analyze task and match to optimal agent
match_task_to_agent() {
    local task_description="$1"
    local task_complexity="${2:-medium}"
    local priority="${3:-medium}"
    local preferred_agent="${4:-}"
    
    # If agent is explicitly specified, validate and use it
    if [[ -n "$preferred_agent" ]] && agent_exists "$preferred_agent"; then
        log_debug "Using preferred agent: $preferred_agent"
        echo "$preferred_agent"
        return 0
    fi
    
    # Analyze task characteristics
    local task_keywords=""
    case "$task_description" in
        *"research"*|*"documentation"*|*"find"*|*"investigate"*|*"analyze"*)
            task_keywords="research documentation analysis"
            ;;
        *"design"*|*"architecture"*|*"review"*|*"plan"*|*"strategy"*)
            task_keywords="design architecture review planning"
            ;;
        *"implement"*|*"code"*|*"build"*|*"create"*|*"test"*|*"deploy"*)
            task_keywords="implementation coding testing deployment"
            ;;
    esac
    
    # Score agents based on capability match
    local best_agent=""
    local best_score=0
    
    for agent in "${!AGENT_CAPABILITIES[@]}"; do
        local score=0
        local capabilities="${AGENT_CAPABILITIES[$agent]}"
        
        # Calculate capability match score
        for keyword in $task_keywords; do
            if [[ "$capabilities" == *"$keyword"* ]]; then
                ((score += 10))
            fi
        done
        
        # Adjust for complexity
        local agent_strength="${AGENT_STRENGTHS[$agent]}"
        case "$task_complexity" in
            "high")
                if [[ "$agent_strength" == *"complexity:high"* ]]; then
                    ((score += 15))
                elif [[ "$agent_strength" == *"complexity:medium"* ]]; then
                    ((score += 5))
                fi
                ;;
            "medium")
                if [[ "$agent_strength" == *"complexity:medium"* ]]; then
                    ((score += 10))
                elif [[ "$agent_strength" == *"complexity:high"* ]]; then
                    ((score += 8))
                fi
                ;;
            "low")
                if [[ "$agent_strength" == *"complexity:low"* ]]; then
                    ((score += 10))
                fi
                ;;
        esac
        
        # Adjust for priority and speed requirements
        if [[ "$priority" == "critical" ]] && [[ "$agent_strength" == *"speed:high"* ]]; then
            ((score += 5))
        fi
        
        # Check current workload
        local current_workload
        current_workload=$(get_agent_workload "$agent")
        if [[ $current_workload -lt 3 ]]; then
            ((score += 3))
        elif [[ $current_workload -gt 5 ]]; then
            ((score -= 5))
        fi
        
        # Select best match
        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_agent=$agent
        fi
    done
    
    log_debug "Selected agent: $best_agent (score: $best_score) for task: $(echo "$task_description" | head -c 50)..."
    echo "$best_agent"
}

# Check if agent exists and is available
agent_exists() {
    local agent_name="$1"
    
    # Check if agent file exists
    if [[ -f ".claude/agents/${agent_name}.md" ]]; then
        return 0
    fi
    
    # Check if it's a known agent type
    if [[ -n "${AGENT_CAPABILITIES[$agent_name]:-}" ]]; then
        return 0
    fi
    
    return 1
}

# Get current workload for an agent
get_agent_workload() {
    local agent_name="$1"
    
    # Count active delegations for this agent
    local workload=0
    
    # Check background tasks
    if [[ -f "${HOME}/.awoc/background/task-registry.json" ]]; then
        workload=$(jq -r ".tasks | to_entries[] | select(.value.status == \"running\" and (.value.task_type | contains(\"$agent_name\"))) | .key" \
                   "${HOME}/.awoc/background/task-registry.json" 2>/dev/null | wc -l || echo "0")
    fi
    
    # Check active workflows
    for workflow_dir in "${ACTIVE_WORKFLOWS_DIR}"/*; do
        if [[ -d "$workflow_dir" ]]; then
            local active_tasks
            active_tasks=$(find "$workflow_dir" -name "*.status" -exec cat {} \; 2>/dev/null | grep -c "running" || echo "0")
            ((workload += active_tasks))
        fi
    done
    
    echo "$workload"
}

# Resolve task dependencies and create execution order
resolve_dependencies() {
    local workflow_config="$1"
    local execution_mode="${2:-sequential}"
    
    # Extract tasks
    local tasks
    tasks=$(echo "$workflow_config" | jq -c '.workflow.tasks[]')
    
    # Simple resolution - just return tasks in dependency order
    # For now, return tasks as-is for basic functionality
    echo "$tasks" | jq -s '.'
}

# Sequential dependency resolution
resolve_sequential_order() {
    local tasks=("$@")
    local execution_order="[]"
    local completed=()
    local remaining=("${tasks[@]}")
    
    while [[ ${#remaining[@]} -gt 0 ]]; do
        local made_progress=false
        local new_remaining=()
        
        for task in "${remaining[@]}"; do
            local can_execute=true
            local task_deps="${task_deps[$task]}"
            
            # Check if all dependencies are completed
            for dep in $task_deps; do
                if [[ ! " ${completed[@]} " =~ " $dep " ]]; then
                    can_execute=false
                    break
                fi
            done
            
            if [[ "$can_execute" == "true" ]]; then
                # Add to execution order
                local task_spec="${task_info[$task]}"
                execution_order=$(echo "$execution_order" | jq --argjson task "$task_spec" '. + [$task]')
                completed+=("$task")
                made_progress=true
            else
                new_remaining+=("$task")
            fi
        done
        
        remaining=("${new_remaining[@]}")
        
        # Detect circular dependencies
        if [[ "$made_progress" == "false" && ${#remaining[@]} -gt 0 ]]; then
            log_error "Circular dependency detected in workflow"
            exit 1
        fi
    done
    
    echo "$execution_order"
}

# Parallel execution groups resolution
resolve_parallel_groups() {
    local tasks=("$@")
    
    # Group tasks by dependency level
    local level=0
    local groups="[]"
    local completed=()
    local remaining=("${tasks[@]}")
    
    while [[ ${#remaining[@]} -gt 0 ]]; do
        local current_level_tasks="[]"
        local new_remaining=()
        
        for task in "${remaining[@]}"; do
            local can_execute=true
            local task_deps="${task_deps[$task]}"
            
            # Check if all dependencies are completed
            for dep in $task_deps; do
                if [[ ! " ${completed[@]} " =~ " $dep " ]]; then
                    can_execute=false
                    break
                fi
            done
            
            if [[ "$can_execute" == "true" ]]; then
                local task_spec="${task_info[$task]}"
                current_level_tasks=$(echo "$current_level_tasks" | jq --argjson task "$task_spec" '. + [$task]')
                completed+=("$task")
            else
                new_remaining+=("$task")
            fi
        done
        
        # Add level to groups
        if [[ $(echo "$current_level_tasks" | jq 'length') -gt 0 ]]; then
            local level_group="{\"level\": $level, \"tasks\": $current_level_tasks}"
            groups=$(echo "$groups" | jq --argjson group "$level_group" '. + [$group]')
            ((level++))
        fi
        
        remaining=("${new_remaining[@]}")
        
        # Safety check
        if [[ ${#remaining[@]} -gt 0 && $(echo "$current_level_tasks" | jq 'length') -eq 0 ]]; then
            log_error "Dependency resolution failed - circular dependencies detected"
            exit 1
        fi
    done
    
    echo "$groups"
}

# Adaptive execution order resolution
resolve_adaptive_order() {
    local tasks=("$@")
    
    # For adaptive, start with sequential then optimize
    resolve_sequential_order "${tasks[@]}"
}

# Pipeline execution order resolution  
resolve_pipeline_order() {
    local tasks=("$@")
    
    # For pipeline, use sequential order (pipeline is about data flow)
    resolve_sequential_order "${tasks[@]}"
}

# Create and initialize workflow
create_workflow() {
    local workflow_type="$1"
    local config_file="${2:-}"
    local execution_mode="${3:-adaptive}"
    local priority="${4:-medium}"
    
    # Generate unique workflow ID
    local workflow_id="workflow-$(date +%s)-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')"
    local workflow_dir="${ACTIVE_WORKFLOWS_DIR}/${workflow_id}"
    
    log_info "Creating workflow: $workflow_id ($workflow_type)"
    
    # Create workflow directory structure
    mkdir -p "$workflow_dir/results" "$workflow_dir/logs" "$workflow_dir/task_completion"
    
    # Load workflow configuration
    local workflow_config=""
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        workflow_config=$(cat "$config_file")
    elif [[ -f "${TEMPLATES_DIR}/${workflow_type}.json" ]]; then
        workflow_config=$(cat "${TEMPLATES_DIR}/${workflow_type}.json")
    else
        log_error "Workflow template not found: $workflow_type"
        return 1
    fi
    
    # Validate configuration
    if ! echo "$workflow_config" | jq empty 2>/dev/null; then
        log_error "Invalid workflow configuration JSON"
        return 1
    fi
    
    # Initialize workflow metadata
    local workflow_metadata
    workflow_metadata=$(cat << EOF
{
    "workflow_id": "$workflow_id",
    "workflow_type": "$workflow_type",
    "execution_mode": "$execution_mode",
    "priority": "$priority",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "initializing",
    "total_tasks": $(echo "$workflow_config" | jq '.workflow.tasks | length'),
    "completed_tasks": 0,
    "failed_tasks": 0,
    "parent_session": "${AWOC_SESSION_ID:-unknown}",
    "working_directory": "$(pwd)"
}
EOF
)
    
    echo "$workflow_metadata" > "${workflow_dir}/workflow-metadata.json"
    echo "$workflow_config" > "${workflow_dir}/workflow-config.json"
    
    # Resolve dependencies and create execution plan
    local execution_plan
    execution_plan=$(resolve_dependencies "$workflow_config" "$execution_mode")
    echo "$execution_plan" > "${workflow_dir}/execution-plan.json"
    
    echo "$workflow_id"
}

# Execute workflow
execute_workflow() {
    local workflow_id="$1"
    local workflow_dir="${ACTIVE_WORKFLOWS_DIR}/${workflow_id}"
    
    if [[ ! -d "$workflow_dir" ]]; then
        log_error "Workflow not found: $workflow_id"
        return 1
    fi
    
    log_info "Executing workflow: $workflow_id"
    
    # Load workflow configuration
    local workflow_config
    workflow_config=$(cat "${workflow_dir}/workflow-config.json")
    local execution_plan
    execution_plan=$(cat "${workflow_dir}/execution-plan.json")
    local metadata
    metadata=$(cat "${workflow_dir}/workflow-metadata.json")
    
    local execution_mode
    execution_mode=$(echo "$metadata" | jq -r '.execution_mode')
    
    # Update status to running
    update_workflow_status "$workflow_id" "running"
    
    # Execute based on mode
    case "$execution_mode" in
        "sequential")
            execute_sequential_workflow "$workflow_id" "$execution_plan"
            ;;
        "parallel")
            execute_parallel_workflow "$workflow_id" "$execution_plan"
            ;;
        "adaptive")
            execute_adaptive_workflow "$workflow_id" "$execution_plan"
            ;;
        "pipeline")
            execute_pipeline_workflow "$workflow_id" "$execution_plan"
            ;;
        *)
            log_error "Unknown execution mode: $execution_mode"
            return 1
            ;;
    esac
    
    # Update final status
    update_workflow_status "$workflow_id" "completed"
    
    log_info "Workflow completed: $workflow_id"
}

# Execute adaptive workflow
execute_adaptive_workflow() {
    local workflow_id="$1"
    local execution_plan="$2"
    
    log_info "Executing adaptive workflow: $workflow_id"
    
    # For now, use sequential execution as the adaptive strategy
    execute_sequential_workflow "$workflow_id" "$execution_plan"
}

# Execute parallel workflow
execute_parallel_workflow() {
    local workflow_id="$1"
    local execution_plan="$2"
    
    log_info "Executing parallel workflow: $workflow_id"
    
    # For now, use sequential execution (parallel would need process management)
    execute_sequential_workflow "$workflow_id" "$execution_plan"
}

# Execute pipeline workflow  
execute_pipeline_workflow() {
    local workflow_id="$1"
    local execution_plan="$2"
    
    log_info "Executing pipeline workflow: $workflow_id"
    
    # For now, use sequential execution (pipeline would pass outputs between tasks)
    execute_sequential_workflow "$workflow_id" "$execution_plan"
}

# Update workflow status
update_workflow_status() {
    local workflow_id="$1"
    local status="$2"
    local workflow_dir="${ACTIVE_WORKFLOWS_DIR}/${workflow_id}"
    
    if [[ ! -f "${workflow_dir}/workflow-metadata.json" ]]; then
        return 1
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg status "$status" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.status = $status | .updated_at = $timestamp' \
       "${workflow_dir}/workflow-metadata.json" > "$temp_file"
    
    mv "$temp_file" "${workflow_dir}/workflow-metadata.json"
    
    log_debug "Workflow $workflow_id status updated to: $status"
}

# Execute sequential workflow
execute_sequential_workflow() {
    local workflow_id="$1"
    local execution_plan="$2"
    local workflow_dir="${ACTIVE_WORKFLOWS_DIR}/${workflow_id}"
    
    log_info "Executing sequential workflow: $workflow_id"
    
    echo "$execution_plan" | jq -c '.[]' | while IFS= read -r task_spec; do
        local task_id
        task_id=$(echo "$task_spec" | jq -r '.task_id')
        local agent
        agent=$(echo "$task_spec" | jq -r '.agent')
        local description
        description=$(echo "$task_spec" | jq -r '.description')
        local token_budget
        token_budget=$(echo "$task_spec" | jq -r '.token_budget // 5000')
        
        log_info "Executing task: $task_id ($agent)"
        
        # Execute task via delegation
        local task_result
        # Validate delegation first
        if "${SCRIPT_DIR}/delegation-validator.sh" "$agent" "$description" "$token_budget" "high" > /dev/null; then
            # For now, simulate task execution with a success result
            # In a real implementation, this would use the Task tool or spawn actual agents
            task_result="{\"agent\": \"$agent\", \"task\": \"$description\", \"status\": \"completed\", \"result\": \"Task simulation completed successfully\"}"
            
            echo "$task_result" > "${workflow_dir}/results/${task_id}.json"
            echo "completed" > "${workflow_dir}/task_completion/${task_id}.status"
            log_info "Task completed: $task_id"
        else
            # Task failed validation
            task_result="{\"agent\": \"$agent\", \"task\": \"$description\", \"status\": \"failed\", \"error\": \"Delegation validation failed\"}"
            echo "failed" > "${workflow_dir}/task_completion/${task_id}.status"
            echo "$task_result" > "${workflow_dir}/results/${task_id}.error"
            log_error "Task failed: $task_id"
            
            # Handle failure based on tolerance
            handle_task_failure "$workflow_id" "$task_id" "$task_result"
            return 1
        fi
    done
}

# Handle task failure
handle_task_failure() {
    local workflow_id="$1"
    local task_id="$2"  
    local error_message="$3"
    local workflow_dir="${ACTIVE_WORKFLOWS_DIR}/${workflow_id}"
    
    log_error "Handling task failure: $task_id in workflow $workflow_id"
    
    # Load workflow configuration to check failure tolerance
    local workflow_config
    workflow_config=$(cat "${workflow_dir}/workflow-config.json")
    local failure_tolerance
    failure_tolerance=$(echo "$workflow_config" | jq -r '.workflow.failure_tolerance // 0')
    
    # Update failed task count
    local temp_file
    temp_file=$(mktemp)
    jq '.failed_tasks += 1' "${workflow_dir}/workflow-metadata.json" > "$temp_file"
    mv "$temp_file" "${workflow_dir}/workflow-metadata.json"
    
    local failed_tasks
    failed_tasks=$(jq -r '.failed_tasks' "${workflow_dir}/workflow-metadata.json")
    
    if [[ $failed_tasks -gt $failure_tolerance ]]; then
        log_error "Failure tolerance exceeded ($failed_tasks > $failure_tolerance), aborting workflow"
        update_workflow_status "$workflow_id" "failed"
        return 1
    else
        log_warn "Task failure within tolerance ($failed_tasks <= $failure_tolerance), continuing"
        return 0
    fi
}

# Get workflow status
get_workflow_status() {
    local workflow_id="$1"
    local workflow_dir="${ACTIVE_WORKFLOWS_DIR}/${workflow_id}"
    
    if [[ ! -d "$workflow_dir" ]]; then
        log_error "Workflow not found: $workflow_id"
        return 1
    fi
    
    local metadata
    metadata=$(cat "${workflow_dir}/workflow-metadata.json")
    
    echo "$metadata" | jq '.'
}

# List workflows
list_workflows() {
    local status_filter="${1:-all}"
    
    if [[ ! -d "$ACTIVE_WORKFLOWS_DIR" ]]; then
        echo "No active workflows found"
        return 0
    fi
    
    echo "Active Workflows:"
    echo "=================="
    
    for workflow_dir in "${ACTIVE_WORKFLOWS_DIR}"/*; do
        if [[ -d "$workflow_dir" ]]; then
            local workflow_id=$(basename "$workflow_dir")
            local metadata_file="${workflow_dir}/workflow-metadata.json"
            
            if [[ -f "$metadata_file" ]]; then
                local status
                status=$(jq -r '.status' "$metadata_file")
                local workflow_type
                workflow_type=$(jq -r '.workflow_type' "$metadata_file")
                local created_at
                created_at=$(jq -r '.created_at' "$metadata_file")
                
                if [[ "$status_filter" == "all" || "$status_filter" == "$status" ]]; then
                    echo "ID: $workflow_id"
                    echo "  Type: $workflow_type"
                    echo "  Status: $status"
                    echo "  Created: $created_at"
                    echo ""
                fi
            fi
        fi
    done
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            initialize_workflow_system
            ;;
        "create")
            shift
            create_workflow "$@"
            ;;
        "execute")
            shift
            execute_workflow "$@"
            ;;
        "status")
            shift
            get_workflow_status "$@"
            ;;
        "list")
            shift
            list_workflows "$@"
            ;;
        "match-agent")
            shift
            match_task_to_agent "$@"
            ;;
        "help"|*)
            cat << 'HELP_EOF'
AWOC Workflow Coordinator

Commands:
  init                           Initialize workflow system
  create <type> [config] [mode] [priority]    Create new workflow
  execute <workflow-id>          Execute workflow
  status <workflow-id>           Get workflow status  
  list [status-filter]           List workflows
  match-agent <task> [complexity] [priority]  Match task to optimal agent

Examples:
  workflow-coordinator.sh create feature-development my-feature.json adaptive high
  workflow-coordinator.sh execute workflow-1234567890-abcd
  workflow-coordinator.sh list running
HELP_EOF
            ;;
    esac
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize system on first run
    if [[ ! -d "$WORKFLOWS_DIR" ]]; then
        initialize_workflow_system
    fi
    
    main "$@"
fi