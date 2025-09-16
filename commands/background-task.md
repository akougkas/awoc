# AWOC Background Task Orchestration
---
name: background-task
description: Launch independent background agents for long-running or parallel tasks
argument-hint: [task-type] [output-file] [model] [token-budget] [timeout]
allowed-tools: [Bash, Write, Read, Task]
schema: background-task-v1.1
---

## Overview
Spawns independent Claude instances for background processing, enabling parallel execution without context pollution in the main session.

## Usage

### Basic Background Execution
```bash
/background-task research report.md sonnet 5000 600
/background-task analysis analysis-results.json opus 8000 900  
/background-task testing test-report.md haiku 3000 300
```

### Structured Task Execution
```bash
/background-task "api-research:Stripe payment integration" research-stripe.json sonnet 6000 420
/background-task "performance-analysis:Database query optimization" perf-analysis.md opus 10000 800
/background-task "test-generation:Unit tests for authentication" auth-tests.md haiku 4000 240
```

### Parallel Task Batch
```bash
/background-task "code-review:Security analysis" security-review.json opus 8000 600 &
/background-task "documentation:API documentation update" api-docs.md sonnet 5000 300 &
/background-task "testing:Integration test suite" integration-tests.md haiku 4000 400 &
wait  # Wait for all background tasks to complete
```

## Execution Flow

### 1. Initialize Background Task Context  
```bash
!`scripts/background-task-manager.sh initialize "${1}" "${2}" "${3:-sonnet}" "${4:-5000}" "${5:-600}"`
```

### 2. Prepare Isolated Task Environment
```bash
# Create task-specific directory
task_id=$(date +%s)-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')
task_dir="${HOME}/.awoc/background/tasks/${task_id}"
mkdir -p "$task_dir"

# Set up task configuration
cat > "$task_dir/task-config.json" << EOF
{
    "task_id": "$task_id",
    "task_type": "${1}",
    "output_file": "${2}",
    "model": "${3:-sonnet}",
    "token_budget": ${4:-5000},
    "timeout": ${5:-600},
    "parent_session": "${AWOC_SESSION_ID:-unknown}",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "initializing"
}
EOF
```

### 3. Generate Task Prompt
Based on task type, create specialized prompt:

```bash
task_prompt=$(cat << 'PROMPT_EOF'
You are an independent background agent executing a focused task.

## Task Configuration
- **Task ID**: ${task_id}
- **Task Type**: ${1}  
- **Output File**: ${2}
- **Token Budget**: ${4:-5000} tokens maximum
- **Time Limit**: ${5:-600} seconds
- **Model**: ${3:-sonnet}

## Task Execution Protocol
1. **Stay Focused**: Execute only the specified task
2. **Monitor Resources**: Track token usage and time
3. **Structured Output**: Save results to specified output file
4. **Error Handling**: Log errors and partial results
5. **Status Updates**: Update task status throughout execution

## Task Details
$(scripts/task-prompt-generator.sh generate "${1}")

## Expected Output Format
$(scripts/output-format-generator.sh generate "${1}" "${2}")

## Execution Context
- Working Directory: $(pwd)
- Available Tools: Read, Write, Bash, WebFetch, Grep, Glob
- Context Isolation: Full isolation from parent session
- Resource Limits: ${4:-5000} tokens, ${5:-600} seconds

Execute the task efficiently and save results to: ${2}

When complete, update task status to 'completed' in: ${task_dir}/task-config.json
PROMPT_EOF
)
```

### 4. Launch Independent Claude Instance
```bash
# Create background execution script
cat > "$task_dir/execute-task.sh" << 'EXEC_EOF'
#!/bin/bash
set -euo pipefail

# Task configuration
source "${task_dir}/task-config.json" 2>/dev/null || true
task_id="${task_id:-unknown}"
output_file="${2}"
token_budget="${4:-5000}"
timeout="${5:-600}"

# Update status
jq '.status = "running" | .started_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
    "${task_dir}/task-config.json" > "${task_dir}/task-config.json.tmp" && \
    mv "${task_dir}/task-config.json.tmp" "${task_dir}/task-config.json"

# Execute task with timeout and resource limits  
timeout ${timeout} claude \
    --model "${3:-sonnet}" \
    --max-tokens ${token_budget} \
    --output "${output_file}" \
    --prompt-file "${task_dir}/task-prompt.txt" \
    --log-file "${task_dir}/execution.log" \
    2>&1

exit_code=$?

# Update final status
if [[ $exit_code -eq 0 ]]; then
    final_status="completed"
else
    final_status="failed"
fi

jq --argjson exit_code $exit_code \
   '.status = "'$final_status'" | .completed_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'" | .exit_code = $exit_code' \
    "${task_dir}/task-config.json" > "${task_dir}/task-config.json.tmp" && \
    mv "${task_dir}/task-config.json.tmp" "${task_dir}/task-config.json"

exit $exit_code
EXEC_EOF

chmod +x "$task_dir/execute-task.sh"

# Save task prompt
echo "$task_prompt" > "$task_dir/task-prompt.txt"

# Launch background execution
nohup "$task_dir/execute-task.sh" > "$task_dir/background.log" 2>&1 &
background_pid=$!
```

### 5. Register Background Task
```bash
!`scripts/background-task-registry.sh register "$task_id" "$background_pid" "${1}" "${2}" "${3:-sonnet}"`
```

### 6. Setup Monitoring
```bash
!`scripts/background-task-monitor.sh start "$task_id" "$background_pid" "${5:-600}"`
```

## Task Type Specializations

### Research Tasks
**Task Types**: `research`, `api-research`, `technology-research`, `competitive-analysis`

**Generated Prompt Additions**:
```markdown
## Research Methodology
1. **Information Gathering**: Use WebFetch to gather comprehensive information
2. **Source Validation**: Verify information accuracy and recency  
3. **Synthesis**: Organize findings into structured format
4. **Recommendations**: Provide actionable insights and next steps

## Research Output Structure
- Executive Summary (2-3 sentences)
- Key Findings (bullet points)
- Detailed Analysis (structured sections)
- Sources and References
- Recommendations
```

### Analysis Tasks  
**Task Types**: `analysis`, `code-analysis`, `performance-analysis`, `security-analysis`

**Generated Prompt Additions**:
```markdown
## Analysis Framework
1. **Data Collection**: Gather relevant data and metrics
2. **Pattern Identification**: Identify trends, issues, and opportunities
3. **Root Cause Analysis**: Determine underlying causes
4. **Impact Assessment**: Evaluate significance and urgency
5. **Solution Recommendations**: Propose concrete actions

## Analysis Output Structure
- Summary of Findings
- Detailed Analysis by Category
- Risk Assessment
- Priority Recommendations
- Implementation Considerations
```

### Testing Tasks
**Task Types**: `testing`, `test-generation`, `test-automation`, `qa-validation`

**Generated Prompt Additions**:
```markdown
## Testing Strategy
1. **Test Planning**: Define test scope and objectives
2. **Test Design**: Create comprehensive test cases
3. **Test Implementation**: Write executable tests
4. **Test Execution**: Run tests and capture results
5. **Results Analysis**: Analyze outcomes and identify issues

## Testing Output Structure
- Test Plan Summary
- Test Cases and Scenarios
- Implementation Code
- Execution Results
- Issue Summary and Recommendations
```

### Documentation Tasks
**Task Types**: `documentation`, `api-docs`, `user-guides`, `technical-writing`

**Generated Prompt Additions**:
```markdown
## Documentation Standards
1. **Audience Analysis**: Identify target users and their needs
2. **Content Organization**: Structure information logically
3. **Clarity and Conciseness**: Use clear, accessible language
4. **Examples and Code**: Include practical examples
5. **Maintenance**: Ensure accuracy and freshness

## Documentation Output Structure
- Document Overview
- Detailed Content Sections  
- Code Examples and Snippets
- Usage Instructions
- FAQ and Troubleshooting
```

## Background Task Management

### Task Status Monitoring
```bash
# Check task status
/background-status [task-id]
/background-status all
/background-status running

# Get task output  
/background-output [task-id]
/background-logs [task-id]
```

### Resource Management
```bash
# Monitor resource usage
scripts/background-resource-monitor.sh status
scripts/background-resource-monitor.sh limit-check

# Clean up completed tasks
scripts/background-cleanup.sh completed
scripts/background-cleanup.sh older-than 24h
```

### Progress Tracking
```bash
# Real-time progress monitoring
tail -f "${HOME}/.awoc/background/tasks/${task_id}/execution.log"

# Progress summary
scripts/background-progress-tracker.sh summary [task-id]
scripts/background-progress-tracker.sh estimate-completion [task-id]
```

## Integration and Result Handling

### Automatic Result Integration  
```bash
!`scripts/background-result-integrator.sh auto-integrate "${task_id}" "${2}" "${1}"`

# Integration strategies:
# - append: Add results to existing file
# - merge: Intelligent content merging
# - reference: Create reference links
# - summarize: Extract key points only
```

### Manual Result Review
```bash
/integrate-background [task-id] [integration-mode]
/integrate-background abc123-def456 merge
/integrate-background research-task append
/integrate-background analysis-789 summarize
```

### Cross-Task Coordination
```bash
# Wait for specific tasks before proceeding
wait_for_background_tasks() {
    local task_ids=("$@")
    
    for task_id in "${task_ids[@]}"; do
        while ! scripts/background-task-status.sh is-complete "$task_id"; do
            sleep 10
            echo "Waiting for task: $task_id"
        done
    done
}
```

## Error Handling and Recovery

### Task Failure Recovery
```bash
handle_background_failure() {
    local task_id="$1"
    local failure_reason="$2"
    
    case "$failure_reason" in
        "timeout")
            # Extend timeout and retry
            scripts/background-task-retry.sh extend-timeout "$task_id" 900
            ;;
        "token_exceeded")
            # Reduce scope and retry  
            scripts/background-task-retry.sh reduce-scope "$task_id"
            ;;
        "resource_unavailable")
            # Queue for later execution
            scripts/background-task-queue.sh defer "$task_id" 300
            ;;
        *)
            # Manual intervention required
            scripts/background-task-alerts.sh notify-failure "$task_id" "$failure_reason"
            ;;
    esac
}
```

### Partial Result Recovery
```bash
recover_partial_results() {
    local task_id="$1"
    local task_dir="${HOME}/.awoc/background/tasks/${task_id}"
    
    # Check for partial output
    if [[ -f "${task_dir}/partial-results.txt" ]]; then
        echo "Partial results available for task: $task_id"
        
        # Offer integration options
        echo "Options:"
        echo "1. Use partial results as-is"
        echo "2. Resume task from checkpoint"  
        echo "3. Restart with reduced scope"
        
        # Handle user choice...
    fi
}
```

## Performance Optimization

### Task Batching
```bash
# Execute related tasks in optimized batches
batch_related_tasks() {
    local task_type="$1"
    shift
    local tasks=("$@")
    
    # Group tasks by similarity
    # Optimize resource allocation
    # Execute in parallel where possible
    # Share common context efficiently
}
```

### Resource Pool Management
```bash
# Maintain pool of ready background instances
maintain_background_pool() {
    local pool_size=3
    local current_ready=$(scripts/background-pool-manager.sh count-ready)
    
    if [[ $current_ready -lt $pool_size ]]; then
        local needed=$((pool_size - current_ready))
        scripts/background-pool-manager.sh create-ready-instances $needed
    fi
}
```

### Context Caching
```bash
# Cache frequently used contexts for faster startup
cache_common_contexts() {
    local context_types=("api-research" "code-analysis" "testing" "documentation")
    
    for context_type in "${context_types[@]}"; do
        scripts/background-context-cache.sh warm-cache "$context_type"
    done
}
```

## Integration Examples

### Feature Development Workflow
```bash
# Launch parallel background tasks for feature development
/background-task "research:Authentication best practices" auth-research.md sonnet 5000 300 &
/background-task "analysis:Current auth implementation" auth-analysis.md opus 8000 600 &  
/background-task "testing:Auth test scenarios" auth-test-plan.md haiku 4000 200 &

# Wait for research and analysis
wait

# Use results to implement feature
echo "Background research and analysis complete. Beginning implementation..."
```

### Code Review Process
```bash
# Parallel code review tasks
/background-task "security-analysis:Review authentication code" security-review.json opus 8000 900 &
/background-task "performance-analysis:Profile authentication flow" perf-analysis.md sonnet 6000 600 &
/background-task "test-analysis:Evaluate test coverage" test-coverage.md haiku 3000 300 &

# Continue with other work while reviews run
echo "Code reviews running in background..."
```

### Documentation Generation
```bash
# Generate multiple documentation pieces simultaneously
/background-task "api-docs:Generate API documentation" api-docs.md sonnet 6000 400 &
/background-task "user-guide:Create user guide" user-guide.md haiku 4000 300 &
/background-task "deployment-guide:Document deployment process" deploy-guide.md sonnet 5000 350 &

# All documentation generated in parallel
```

---

**Success Metrics:**
- **Parallel Efficiency**: Time saved through background execution
- **Resource Utilization**: Optimal use of available compute resources
- **Task Success Rate**: Percentage of background tasks completed successfully  
- **Integration Quality**: How well background results integrate with main workflow