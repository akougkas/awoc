# AWOC Workflow Coordination Engine
---
name: coordinate-workflow
description: Multi-agent workflow orchestration with intelligent routing and dependency management
argument-hint: [workflow-type] [config-file] [execution-mode] [priority]
allowed-tools: [Task, Bash, Read, Write]
schema: coordinate-workflow-v1.2
---

## Overview
Orchestrates complex workflows across multiple agents with dependency resolution, resource optimization, and intelligent routing based on task characteristics and agent capabilities.

## Usage

### Predefined Workflow Execution
```bash
/coordinate-workflow feature-development feature-auth.json parallel high
/coordinate-workflow api-integration stripe-integration.json sequential medium
/coordinate-workflow bug-investigation critical-auth-bug.json adaptive critical
```

### Custom Workflow Definition
```bash
/coordinate-workflow custom-workflow ./config/custom-research.json parallel medium
/coordinate-workflow code-review security-review.json sequential high
/coordinate-workflow performance-audit perf-optimization.json adaptive high
```

### Interactive Workflow Builder
```bash
/coordinate-workflow build --interactive --save-as=new-feature-workflow.json
/coordinate-workflow template --type=research --agents=3 --output=research-template.json
```

## Execution Flow

### 1. Load and Validate Workflow Configuration
```bash
workflow_type="${1}"
config_file="${2:-}"
execution_mode="${3:-adaptive}"
priority="${4:-medium}"

# Load workflow configuration
if [[ -f "$config_file" ]]; then
    workflow_config=$(cat "$config_file")
elif [[ -f ".awoc/workflows/${workflow_type}.json" ]]; then
    workflow_config=$(cat ".awoc/workflows/${workflow_type}.json")
else
    # Generate workflow from template
    workflow_config=$(scripts/workflow-template-generator.sh generate "$workflow_type")
fi

# Validate configuration
!`scripts/workflow-validator.sh validate "$workflow_config" "$execution_mode" "$priority"`
```

### 2. Analyze Workflow Dependencies
```bash
# Extract dependency graph
dependencies=$(echo "$workflow_config" | jq -r '.workflow.dependencies')

# Validate for circular dependencies
!`scripts/dependency-analyzer.sh check-circular "$dependencies"`

# Generate execution order
execution_order=$(scripts/dependency-resolver.sh resolve "$dependencies" "$execution_mode")

echo "🔄 Workflow execution plan:"
echo "$execution_order" | jq -r '.[] | "  \(.order): \(.agent) -> \(.task)"'
```

### 3. Initialize Workflow Context
```bash
# Generate workflow session ID
workflow_id="workflow-$(date +%s)-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')"

# Create workflow directory
workflow_dir="${HOME}/.awoc/workflows/active/${workflow_id}"
mkdir -p "$workflow_dir"

# Initialize workflow tracking
workflow_metadata="{
    \"workflow_id\": \"$workflow_id\",
    \"workflow_type\": \"$workflow_type\",
    \"execution_mode\": \"$execution_mode\",
    \"priority\": \"$priority\",
    \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"status\": \"initializing\",
    \"total_tasks\": $(echo "$execution_order" | jq length),
    \"completed_tasks\": 0,
    \"failed_tasks\": 0,
    \"parent_session\": \"${AWOC_SESSION_ID:-unknown}\"
}"

echo "$workflow_metadata" > "${workflow_dir}/workflow-metadata.json"
```

### 4. Resource Allocation and Planning
```bash
# Calculate total resource requirements
total_token_budget=$(echo "$workflow_config" | jq '.workflow.tasks[] | .token_budget // 5000' | jq -s 'add')
estimated_duration=$(echo "$workflow_config" | jq '.workflow.tasks[] | .estimated_duration // 300' | jq -s 'add')

# Check resource availability
!`scripts/workflow-resource-planner.sh plan "$total_token_budget" "$estimated_duration" "${execution_mode}"`

echo "📊 Resource Plan:"
echo "  Total Token Budget: $total_token_budget tokens"
echo "  Estimated Duration: ${estimated_duration}s"
echo "  Execution Mode: $execution_mode"
```

### 5. Execute Workflow Based on Mode
Based on execution mode, orchestrate task execution:

```bash
case "$execution_mode" in
    "sequential")
        execute_sequential_workflow "$execution_order" "$workflow_dir"
        ;;
    "parallel")
        execute_parallel_workflow "$execution_order" "$workflow_dir"
        ;;
    "adaptive")
        execute_adaptive_workflow "$execution_order" "$workflow_dir"
        ;;
    "pipeline")
        execute_pipeline_workflow "$execution_order" "$workflow_dir"
        ;;
esac
```

### 6. Monitor and Coordinate Execution
```bash
!`scripts/workflow-monitor.sh start "$workflow_id" "$execution_mode" "$priority"`
```

## Workflow Execution Modes

### Sequential Execution
Execute tasks one after another in dependency order:

```bash
execute_sequential_workflow() {
    local execution_order="$1"
    local workflow_dir="$2"
    
    echo "⏭️  Executing sequential workflow"
    
    echo "$execution_order" | jq -c '.[]' | while IFS= read -r task_spec; do
        local agent=$(echo "$task_spec" | jq -r '.agent')
        local task_description=$(echo "$task_spec" | jq -r '.task')
        local token_budget=$(echo "$task_spec" | jq -r '.token_budget // 5000')
        local task_id=$(echo "$task_spec" | jq -r '.task_id')
        
        echo "🚀 Executing: $agent -> $task_description"
        
        # Update workflow status
        update_workflow_status "$workflow_dir" "running" "$task_id"
        
        # Execute task with delegation
        task_result=$(Task agent="$agent" task="$task_description" max_tokens="$token_budget")
        task_exit_code=$?
        
        # Store task result
        echo "$task_result" > "${workflow_dir}/results/${task_id}.json"
        
        # Update task completion
        update_task_completion "$workflow_dir" "$task_id" "$task_exit_code"
        
        if [[ $task_exit_code -ne 0 ]]; then
            echo "❌ Task failed: $task_id"
            handle_task_failure "$workflow_dir" "$task_id" "$task_exit_code"
            
            # Check failure tolerance
            if ! check_failure_tolerance "$workflow_dir"; then
                echo "🚫 Workflow aborted due to failure tolerance exceeded"
                return 1
            fi
        else
            echo "✅ Task completed: $task_id"
        fi
        
        # Brief pause between tasks
        sleep 1
    done
}
```

### Parallel Execution
Execute independent tasks simultaneously:

```bash
execute_parallel_workflow() {
    local execution_order="$1"
    local workflow_dir="$2"
    
    echo "🔄 Executing parallel workflow"
    
    # Group tasks by dependency level
    local dependency_levels
    dependency_levels=$(scripts/dependency-level-analyzer.sh group "$execution_order")
    
    echo "$dependency_levels" | jq -c '.[]' | while IFS= read -r level_spec; do
        local level=$(echo "$level_spec" | jq -r '.level')
        local tasks=$(echo "$level_spec" | jq -c '.tasks')
        
        echo "📈 Executing level $level tasks in parallel"
        
        # Launch all tasks at this level in parallel
        declare -a task_pids=()
        
        echo "$tasks" | jq -c '.[]' | while IFS= read -r task_spec; do
            {
                local agent=$(echo "$task_spec" | jq -r '.agent')
                local task_description=$(echo "$task_spec" | jq -r '.task')
                local token_budget=$(echo "$task_spec" | jq -r '.token_budget // 5000')
                local task_id=$(echo "$task_spec" | jq -r '.task_id')
                
                echo "🚀 Launching parallel task: $agent -> $task_description"
                
                # Execute task
                task_result=$(Task agent="$agent" task="$task_description" max_tokens="$token_budget")
                task_exit_code=$?
                
                # Store results
                echo "$task_result" > "${workflow_dir}/results/${task_id}.json"
                update_task_completion "$workflow_dir" "$task_id" "$task_exit_code"
                
                # Signal completion
                echo "$task_exit_code" > "${workflow_dir}/task_completion/${task_id}.status"
                
            } &
            
            task_pids+=($!)
        done
        
        # Wait for all tasks at this level to complete
        for pid in "${task_pids[@]}"; do
            wait "$pid"
        done
        
        echo "✅ Level $level completed"
    done
}
```

### Adaptive Execution
Dynamically choose between sequential and parallel based on resource availability:

```bash
execute_adaptive_workflow() {
    local execution_order="$1"
    local workflow_dir="$2"
    
    echo "🧠 Executing adaptive workflow"
    
    # Analyze current system state
    local current_usage
    current_usage=$(scripts/context-monitor.sh get-usage-percentage)
    local available_agents
    available_agents=$(scripts/agent-availability.sh count-available)
    
    echo "📊 System State: ${current_usage}% context, ${available_agents} available agents"
    
    # Dynamic execution strategy selection
    if [[ $current_usage -lt 50 && $available_agents -gt 3 ]]; then
        echo "🔄 Using parallel execution (low usage, high agent availability)"
        execute_parallel_workflow "$execution_order" "$workflow_dir"
    elif [[ $current_usage -gt 80 || $available_agents -lt 2 ]]; then
        echo "⏭️  Using sequential execution (high usage or low agent availability)"
        execute_sequential_workflow "$execution_order" "$workflow_dir"
    else
        echo "🔀 Using hybrid execution (mixed conditions)"
        execute_hybrid_workflow "$execution_order" "$workflow_dir"
    fi
}
```

### Pipeline Execution
Stream outputs between tasks for efficient processing:

```bash
execute_pipeline_workflow() {
    local execution_order="$1"
    local workflow_dir="$2"
    
    echo "🔄 Executing pipeline workflow"
    
    local pipeline_buffer="${workflow_dir}/pipeline_buffer"
    mkdir -p "$pipeline_buffer"
    
    # Create named pipes for task communication
    local previous_output=""
    
    echo "$execution_order" | jq -c '.[]' | while IFS= read -r task_spec; do
        local agent=$(echo "$task_spec" | jq -r '.agent')
        local task_description=$(echo "$task_spec" | jq -r '.task')
        local task_id=$(echo "$task_spec" | jq -r '.task_id')
        
        # Modify task description to include previous output
        if [[ -n "$previous_output" ]]; then
            task_description="$task_description

Previous stage output:
$previous_output"
        fi
        
        echo "🔗 Pipeline stage: $agent -> $(echo "$task_description" | head -n1)"
        
        # Execute task
        task_result=$(Task agent="$agent" task="$task_description")
        
        # Store result and prepare for next stage
        echo "$task_result" > "${workflow_dir}/results/${task_id}.json"
        previous_output="$task_result"
    done
    
    echo "✅ Pipeline execution completed"
}
```

## Workflow Configuration Schema

### Standard Workflow Configuration
```json
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
        "outputs": ["research_report.md"],
        "required_for": ["design_phase", "implementation_phase"]
      },
      {
        "task_id": "design_phase",
        "agent": "architect",
        "description": "Design system architecture and APIs",
        "token_budget": 8000,
        "estimated_duration": 600,
        "priority": "high",
        "dependencies": ["research_phase"],
        "outputs": ["design_document.md", "api_specification.json"],
        "required_for": ["implementation_phase", "testing_phase"]
      },
      {
        "task_id": "implementation_phase",
        "agent": "workforce",
        "description": "Implement feature based on design",
        "token_budget": 10000,
        "estimated_duration": 900,
        "priority": "critical",
        "dependencies": ["research_phase", "design_phase"],
        "outputs": ["implementation/", "unit_tests/"],
        "required_for": ["testing_phase"]
      },
      {
        "task_id": "testing_phase",
        "agent": "workforce",
        "description": "Create comprehensive test suite",
        "token_budget": 6000,
        "estimated_duration": 400,
        "priority": "high",
        "dependencies": ["design_phase", "implementation_phase"],
        "outputs": ["test_suite/", "test_report.md"],
        "required_for": ["documentation_phase"]
      },
      {
        "task_id": "documentation_phase",
        "agent": "docs-fetcher",
        "description": "Create user and developer documentation",
        "token_budget": 4000,
        "estimated_duration": 300,
        "priority": "medium",
        "dependencies": ["implementation_phase", "testing_phase"],
        "outputs": ["user_guide.md", "api_docs.md"],
        "required_for": []
      }
    ],
    
    "dependencies": {
      "research_phase": [],
      "design_phase": ["research_phase"],
      "implementation_phase": ["research_phase", "design_phase"],
      "testing_phase": ["design_phase", "implementation_phase"],
      "documentation_phase": ["implementation_phase", "testing_phase"]
    },
    
    "coordination_rules": {
      "parallel_groups": [
        ["research_phase"],
        ["design_phase"],
        ["implementation_phase"],
        ["testing_phase", "documentation_phase"]
      ],
      "blocking_dependencies": [
        "implementation_phase -> testing_phase",
        "design_phase -> implementation_phase"
      ],
      "optional_dependencies": [
        "research_phase -> documentation_phase"
      ]
    }
  }
}
```

## Intelligent Routing and Coordination

### Agent Capability Matching
```bash
match_task_to_agent() {
    local task_description="$1"
    local required_skills="$2"
    local priority="$3"
    
    # Analyze task characteristics
    local task_complexity
    task_complexity=$(scripts/task-complexity-analyzer.sh analyze "$task_description")
    
    # Match to optimal agent based on capabilities
    local optimal_agent
    optimal_agent=$(scripts/agent-capability-matcher.sh match "$required_skills" "$task_complexity" "$priority")
    
    echo "$optimal_agent"
}
```

### Dynamic Load Balancing
```bash
balance_agent_workload() {
    local available_agents=("$@")
    
    # Get current workload for each agent
    for agent in "${available_agents[@]}"; do
        local current_load
        current_load=$(scripts/agent-workload-monitor.sh get-current-load "$agent")
        echo "$agent:$current_load"
    done | sort -t: -k2 -n | head -n1 | cut -d: -f1
}
```

### Context-Aware Task Routing
```bash
route_task_contextually() {
    local task="$1"
    local current_context="$2"
    local available_agents=("${@:3}")
    
    # Find agent with most relevant context
    local best_agent=""
    local best_relevance=0
    
    for agent in "${available_agents[@]}"; do
        local relevance
        relevance=$(scripts/context-relevance-calculator.sh calculate "$agent" "$current_context")
        
        if [[ $relevance -gt $best_relevance ]]; then
            best_relevance=$relevance
            best_agent=$agent
        fi
    done
    
    echo "$best_agent"
}
```

## Workflow Monitoring and Control

### Real-Time Progress Tracking
```bash
monitor_workflow_progress() {
    local workflow_id="$1"
    local workflow_dir="${HOME}/.awoc/workflows/active/${workflow_id}"
    
    while [[ -d "$workflow_dir" ]]; do
        local metadata
        metadata=$(cat "${workflow_dir}/workflow-metadata.json")
        
        local status completed_tasks total_tasks
        status=$(echo "$metadata" | jq -r '.status')
        completed_tasks=$(echo "$metadata" | jq -r '.completed_tasks')
        total_tasks=$(echo "$metadata" | jq -r '.total_tasks')
        
        local progress=$((completed_tasks * 100 / total_tasks))
        
        echo "📊 Workflow Progress: ${progress}% (${completed_tasks}/${total_tasks}) - Status: $status"
        
        # Check if workflow is complete
        if [[ "$status" == "completed" || "$status" == "failed" ]]; then
            break
        fi
        
        sleep 10
    done
}
```

### Failure Recovery and Retry Logic
```bash
handle_workflow_failure() {
    local workflow_id="$1"
    local failed_task_id="$2"
    local failure_reason="$3"
    
    # Analyze failure and determine recovery strategy
    local recovery_strategy
    recovery_strategy=$(scripts/failure-analyzer.sh analyze "$failure_reason" "$failed_task_id")
    
    case "$recovery_strategy" in
        "retry")
            echo "🔄 Retrying failed task: $failed_task_id"
            retry_workflow_task "$workflow_id" "$failed_task_id"
            ;;
        "skip")
            echo "⏭️  Skipping failed task and continuing: $failed_task_id"
            skip_and_continue "$workflow_id" "$failed_task_id"
            ;;
        "abort")
            echo "🚫 Aborting workflow due to critical failure: $failed_task_id"
            abort_workflow "$workflow_id"
            ;;
        "escalate")
            echo "🆘 Escalating workflow failure for manual intervention"
            escalate_workflow_failure "$workflow_id" "$failed_task_id" "$failure_reason"
            ;;
    esac
}
```

### Resource Optimization During Execution
```bash
optimize_workflow_resources() {
    local workflow_id="$1"
    
    # Monitor resource usage patterns
    local resource_usage
    resource_usage=$(scripts/workflow-resource-monitor.sh get-current-usage "$workflow_id")
    
    # Adjust execution strategy if needed
    if [[ $(echo "$resource_usage" | jq '.token_usage_percentage') -gt 85 ]]; then
        echo "⚠️  High resource usage detected, optimizing workflow"
        
        # Switch to sequential execution
        scripts/workflow-execution-controller.sh switch-mode "$workflow_id" "sequential"
        
        # Reduce token budgets for remaining tasks
        scripts/workflow-budget-optimizer.sh reduce-budgets "$workflow_id" 0.8
    fi
    
    # Scale agent pool if needed
    local active_agents
    active_agents=$(scripts/agent-pool-manager.sh get-active-count)
    
    if [[ $active_agents -lt 2 ]]; then
        echo "🔧 Scaling up agent pool"
        scripts/agent-pool-manager.sh scale-up 2
    fi
}
```

## Integration Examples

### Complete Feature Development Workflow
```bash
# Launch comprehensive feature development
/coordinate-workflow feature-development auth-system.json adaptive high

# This orchestrates:
# 1. Research phase (docs-fetcher)
# 2. Design phase (architect) 
# 3. Implementation phase (workforce)
# 4. Testing phase (workforce)
# 5. Documentation phase (docs-fetcher)
```

### API Integration Workflow
```bash
# API integration with dependency management
/coordinate-workflow api-integration stripe-payment.json parallel medium

# Coordinates:
# 1. API research (docs-fetcher)
# 2. Security analysis (architect) [parallel with research]
# 3. Implementation (workforce) [depends on both above]
# 4. Testing (workforce) [depends on implementation]
```

### Bug Investigation Workflow  
```bash
# Critical bug investigation
/coordinate-workflow bug-investigation auth-bug.json sequential critical

# Orchestrates:
# 1. Problem analysis (architect)
# 2. Root cause investigation (docs-fetcher) 
# 3. Solution research (docs-fetcher) [parallel with #2]
# 4. Fix implementation (workforce)
# 5. Testing and validation (workforce)
```

### Performance Optimization Workflow
```bash
# Performance optimization pipeline
/coordinate-workflow performance-optimization app-perf.json pipeline high

# Creates pipeline:
# 1. Performance analysis (architect) -> 
# 2. Bottleneck identification (docs-fetcher) ->
# 3. Solution implementation (workforce) ->
# 4. Performance validation (workforce)
```

---

**Workflow Success Metrics:**
- **Execution Efficiency**: Time saved through intelligent coordination
- **Resource Optimization**: Optimal use of agent capabilities and token budgets
- **Success Rate**: Percentage of workflows completed successfully
- **Adaptive Intelligence**: Quality of dynamic execution mode selection