# AWOC Parallel Delegation Command
---
name: delegate-parallel
description: Execute multiple independent tasks concurrently across specialized sub-agents
argument-hint: [config-file] or [agent1:task1] [agent2:task2] [...]
allowed-tools: [Task, Bash, Read, Write]
schema: delegate-parallel-v1.0
---

## Overview
Orchestrates parallel execution of independent tasks using multiple sub-agents with intelligent resource management and result aggregation.

## Usage

### Configuration File Mode
```bash
/delegate-parallel tasks.json
/delegate-parallel .awoc/parallel/feature-dev-tasks.json
```

### Inline Task Mode
```bash  
/delegate-parallel "docs-fetcher:Research API docs" "architect:Design system" "workforce:Setup tests"
/delegate-parallel "workforce:Implement auth" "docs-fetcher:Find examples" --max-parallel=3 --timeout=600
```

### Mixed Priority Mode
```bash
/delegate-parallel --priority=high "architect:Critical security review" --priority=medium "docs-fetcher:Performance research"
```

## Execution Flow

### 1. Parse and Validate Tasks
```bash
!`scripts/parallel-task-parser.sh validate "${@}"`
```

### 2. Resource Allocation Planning
```bash
!`scripts/parallel-resource-planner.sh plan-execution "${PARSED_TASKS}" "${MAX_PARALLEL:-5}" "${TOTAL_TOKEN_BUDGET:-15000}"`
```

### 3. Initialize Parallel Context Monitoring
```bash
!`scripts/context-monitor.sh track parallel-start ${TOTAL_TASKS} ${TOTAL_TOKEN_BUDGET}`
```

### 4. Launch Parallel Sub-Agents
Execute tasks concurrently with resource isolation:

```bash
declare -A TASK_PIDS=()
declare -A TASK_RESULTS=()

for task in ${TASK_LIST[@]}; do
    agent=$(echo "$task" | cut -d: -f1)
    task_desc=$(echo "$task" | cut -d: -f2-)
    token_budget=$(get_budget_for_agent "$agent")
    
    {
        scripts/context-monitor.sh track parallel-task-start ${agent} ${task_desc}
        
        # Execute in isolated context
        task_result=$(execute_isolated_task "$agent" "$task_desc" "$token_budget")
        task_exit_code=$?
        
        # Store result with metadata
        echo "{
            \"agent\": \"$agent\",
            \"task\": \"$task_desc\",
            \"result\": \"$task_result\",
            \"exit_code\": $task_exit_code,
            \"tokens_used\": ${ACTUAL_TOKENS:-0},
            \"duration\": ${TASK_DURATION:-0}
        }" > ".awoc/parallel/results/task_${agent}_$$_result.json"
        
        scripts/context-monitor.sh track parallel-task-complete ${agent} ${ACTUAL_TOKENS:-0}
        
    } &
    
    TASK_PIDS[$agent]=$!
done
```

### 5. Monitor Parallel Execution
```bash
!`scripts/parallel-task-monitor.sh monitor "${!TASK_PIDS[@]}" "${MAX_TIMEOUT:-600}"`
```

### 6. Collect and Integrate Results
```bash
# Wait for all tasks to complete
for agent in "${!TASK_PIDS[@]}"; do
    wait ${TASK_PIDS[$agent]}
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        TASK_RESULTS[$agent]=$(cat ".awoc/parallel/results/task_${agent}_$$_result.json")
    else
        scripts/parallel-error-handler.sh handle-task-failure "$agent" "$exit_code"
    fi
done

# Aggregate results intelligently
!`scripts/parallel-result-aggregator.sh aggregate "${TASK_RESULTS[@]}"`
```

### 7. Generate Integrated Report
```bash
!`scripts/parallel-report-generator.sh create-report "${AGGREGATED_RESULTS}" "${EXECUTION_METADATA}"`
```

## Configuration Schema

### Task Configuration File Format
```json
{
  "parallel_config": {
    "max_concurrent": 5,
    "total_timeout": 600,
    "total_token_budget": 20000,
    "failure_tolerance": 1,
    "result_format": "structured"
  },
  "tasks": [
    {
      "agent": "architect",
      "description": "Design microservices architecture",
      "token_budget": 6000,
      "priority": "high",
      "dependencies": [],
      "timeout": 300
    },
    {
      "agent": "docs-fetcher", 
      "description": "Research container orchestration patterns",
      "token_budget": 4000,
      "priority": "medium",
      "dependencies": [],
      "timeout": 180
    },
    {
      "agent": "workforce",
      "description": "Implement service discovery mechanism",
      "token_budget": 8000,
      "priority": "high", 
      "dependencies": ["architect"],
      "timeout": 400
    }
  ]
}
```

## Resource Management

### Token Budget Distribution
```bash
# Automatic budget allocation based on agent type and priority
calculate_token_budget() {
    local agent="$1"
    local priority="$2"
    local total_budget="$3"
    
    case "$agent" in
        "architect")
            base_budget=6000
            ;;
        "docs-fetcher")
            base_budget=4000
            ;;
        "workforce")
            base_budget=8000
            ;;
        *)
            base_budget=5000
            ;;
    esac
    
    # Apply priority multiplier
    case "$priority" in
        "critical") multiplier=1.3 ;;
        "high") multiplier=1.1 ;;
        "medium") multiplier=1.0 ;;
        "low") multiplier=0.8 ;;
    esac
    
    echo $(( $(echo "$base_budget * $multiplier" | bc -l | cut -d. -f1) ))
}
```

### Concurrent Agent Limits
- **Maximum parallel agents**: 10 (configurable)
- **Token budget per batch**: 25,000 tokens
- **Memory allocation per agent**: Isolated contexts
- **CPU resource sharing**: Fair scheduling

### Priority Queue Management
```bash
# High-priority tasks get resource preference
priority_queue_manager() {
    # Sort tasks by priority: critical > high > medium > low
    # Allocate resources to higher priority tasks first
    # Queue lower priority tasks until resources available
}
```

## Dependency Management

### Task Dependencies
```json
{
  "task_id": "implement_auth",
  "agent": "workforce", 
  "dependencies": ["design_auth", "research_auth_libs"],
  "dependency_mode": "all_complete"
}
```

### Dependency Resolution
- **Sequential**: Wait for all dependencies before starting
- **Partial**: Start when critical dependencies complete
- **Conditional**: Start based on dependency outcomes

### Circular Dependency Detection
```bash
!`scripts/dependency-validator.sh check-circular "${TASK_DEPENDENCIES}"`
```

## Error Handling and Recovery

### Individual Task Failures
```bash
handle_task_failure() {
    local failed_agent="$1"
    local error_code="$2" 
    local error_message="$3"
    
    # Log failure
    scripts/context-monitor.sh track parallel-task-failed ${failed_agent} ${error_code}
    
    # Check failure tolerance
    if [[ $FAILED_TASKS -lt $FAILURE_TOLERANCE ]]; then
        # Retry with reduced scope
        scripts/parallel-task-retry.sh retry-reduced "$failed_agent" "$error_message"
    else
        # Abort parallel execution
        scripts/parallel-execution-aborter.sh abort-with-partial-results
    fi
}
```

### Resource Exhaustion
```bash
handle_resource_exhaustion() {
    local resource_type="$1"  # tokens, memory, time
    
    case "$resource_type" in
        "tokens")
            # Reduce scope of remaining tasks
            scripts/token-budget-reducer.sh reduce-remaining-tasks 20%
            ;;
        "memory") 
            # Queue tasks for sequential execution
            scripts/parallel-to-sequential.sh convert-remaining-tasks
            ;;
        "time")
            # Prioritize critical tasks, cancel low priority
            scripts/task-prioritizer.sh emergency-prioritization
            ;;
    esac
}
```

### Partial Success Scenarios
- Continue with completed tasks
- Report which tasks failed and why
- Provide recommendations for manual completion
- Save state for later retry

## Performance Optimization

### Intelligent Task Batching
```bash
# Group compatible tasks to minimize context switching
batch_compatible_tasks() {
    # Group by agent type
    # Group by similar context requirements  
    # Group by priority level
    # Minimize total context loading
}
```

### Context Sharing Optimization
- Share common context between similar tasks
- Pre-load frequently used contexts
- Cache agent-specific contexts
- Deduplicate redundant information

### Resource Pool Management
```bash
# Maintain pool of ready agents
maintain_agent_pool() {
    # Keep warm instances of frequently used agents
    # Pre-allocate token budgets
    # Monitor resource utilization
    # Scale pool based on demand patterns
}
```

## Integration Examples

### Feature Development Workflow
```json
{
  "workflow": "feature_development",
  "tasks": [
    {
      "agent": "docs-fetcher",
      "description": "Research best practices for user authentication",
      "priority": "medium",
      "token_budget": 3500
    },
    {
      "agent": "architect", 
      "description": "Design authentication system architecture",
      "priority": "high",
      "token_budget": 6000,
      "dependencies": ["docs-fetcher"]
    },
    {
      "agent": "workforce",
      "description": "Implement authentication backend",
      "priority": "high", 
      "token_budget": 8000,
      "dependencies": ["architect"]
    },
    {
      "agent": "workforce",
      "description": "Create authentication tests",
      "priority": "medium",
      "token_budget": 4000,
      "dependencies": ["architect"]
    }
  ]
}
```

### Research and Analysis Pipeline
```bash
/delegate-parallel \
    "docs-fetcher:Research GraphQL performance patterns" \
    "docs-fetcher:Find REST API rate limiting examples" \  
    "architect:Analyze current API performance bottlenecks" \
    --max-parallel=3 \
    --timeout=300 \
    --format=research_report
```

### Bug Investigation Swarm
```bash
/delegate-parallel bug-investigation.json
# Where bug-investigation.json contains:
# - architect: Root cause analysis
# - docs-fetcher: Find similar issues and solutions  
# - workforce: Create minimal reproduction case
# - workforce: Implement and test fix
```

## Success Metrics and Reporting

### Performance Metrics
- **Parallel efficiency**: Time saved vs sequential execution
- **Resource utilization**: Token usage optimization
- **Success rate**: Percentage of tasks completed successfully
- **Dependency resolution**: Accuracy of dependency management

### Quality Metrics
- **Result coherence**: How well parallel results integrate
- **Context consistency**: Maintained context across tasks
- **Error recovery**: Effectiveness of failure handling
- **User satisfaction**: Quality of final integrated output

### Reporting Format
```json
{
  "execution_summary": {
    "total_tasks": 5,
    "completed_successfully": 4,
    "failed_tasks": 1,
    "total_time": "4m 23s",
    "sequential_estimate": "12m 15s",
    "time_saved": "7m 52s",
    "efficiency_gain": "64%"
  },
  "resource_usage": {
    "total_tokens": 18750,
    "average_per_task": 3750,
    "budget_utilization": "75%"
  },
  "task_results": [...]
}
```

---

**Advanced Usage Examples:**

### Large-Scale Code Refactoring
```bash
/delegate-parallel refactor-config.json
# Parallel analysis of different modules
# Concurrent implementation of refactoring
# Parallel test creation and validation
```

### Multi-API Integration Project
```bash  
/delegate-parallel \
    "docs-fetcher:Research Stripe API integration" \
    "docs-fetcher:Research SendGrid email API" \
    "docs-fetcher:Research Twilio SMS API" \
    "architect:Design unified communication service" \
    --wait-for-research \
    "workforce:Implement Stripe integration" \
    "workforce:Implement email service" \
    "workforce:Implement SMS service"
```

### Comprehensive Testing Suite
```bash
/delegate-parallel testing-suite.json
# Parallel unit test creation
# Concurrent integration test development  
# Parallel performance test implementation
# Simultaneous documentation updates
```