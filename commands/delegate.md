# AWOC Delegation Command
---
name: delegate  
description: Intelligent task delegation to specialized sub-agents
argument-hint: [agent] [task-description] [token-budget] [priority]
allowed-tools: [Task, Bash, Read, Write]
schema: delegate-v2.1
---

## Overview
Delegates tasks to specialized sub-agents with intelligent token budget management and context isolation.

## Usage
```
/delegate [agent-name] [task-description] [max-tokens] [priority-level]
/delegate architect "Design user authentication system" 5000 high
/delegate docs-fetcher "Research React hooks patterns" 3000 medium
/delegate workforce "Implement API endpoints" 8000 high
```

## Execution Flow

### 1. Initialize Delegation Context
```bash
!`scripts/context-monitor.sh track delegation start ${3:-3000} ${4:-medium}`
```

### 2. Validate Agent and Resources
```bash
!`scripts/delegation-validator.sh "${1}" "${2}" "${3:-3000}" "${4:-medium}"`
```

### 3. Prepare Sub-Agent Context
Based on agent type, load appropriate context:

**For architect (design and analysis):**
- Current project structure
- Existing design patterns
- Technical requirements

**For docs-fetcher (research and documentation):**
- Research goals and scope
- Preferred sources and formats
- Output requirements

**For workforce (implementation):**
- Code style guidelines
- Testing requirements
- Integration specifications

### 4. Execute Delegation
```task
agent: ${1}
task: ${2}
max_tokens: ${3:-3000}
priority: ${4:-medium}
isolation_mode: context_isolated
report_format: structured
timeout: 600
```

### 5. Result Integration
Process sub-agent output without absorbing full context:

```bash
!`scripts/delegation-integrator.sh process-result "${1}" "${TASK_OUTPUT}" "${3:-3000}"`
```

### 6. Context Management
```bash
!`scripts/context-monitor.sh track delegation complete ${1} ${ACTUAL_TOKENS_USED:-0}`
```

## Token Budget Management

### Agent-Specific Budgets
- **architect**: 5000-8000 tokens (design work, analysis)  
- **docs-fetcher**: 3000-5000 tokens (research, documentation)
- **workforce**: 8000-12000 tokens (implementation, testing)
- **custom agents**: User-specified budget

### Budget Enforcement
- Pre-task validation of available budget
- Real-time monitoring during execution
- Automatic termination at 95% budget
- Budget reporting and optimization suggestions

### Priority-Based Resource Allocation
- **Critical**: Reserve 20% emergency budget
- **High**: Standard budget allocation
- **Medium**: 80% of standard budget
- **Low**: 60% of standard budget

## Context Isolation Strategies

### Input Context Minimization
Only provide essential context to sub-agent:
- Task-specific requirements
- Relevant code snippets (not full files)
- Configuration parameters
- Expected output format

### Output Context Filtering
Extract only valuable insights from sub-agent:
- Key findings and recommendations
- Code snippets or implementations
- Decision rationales
- Next steps or dependencies

### Knowledge Transfer Protocol
1. **Structured Handoff**: Use JSON format for data exchange
2. **Semantic Compression**: Summarize complex findings
3. **Reference Linking**: Link to full context when needed
4. **Version Tracking**: Maintain audit trail of decisions

## Error Handling and Recovery

### Delegation Failures
```bash
if [[ $TASK_EXIT_CODE -ne 0 ]]; then
    scripts/delegation-recovery.sh handle-failure "${1}" "${2}" "${TASK_ERROR}"
    scripts/context-monitor.sh track delegation failed ${1} error
fi
```

### Budget Overruns
```bash
if [[ $ACTUAL_TOKENS -gt $BUDGET ]]; then
    scripts/token-optimizer.sh suggest-reduction "${1}" "${2}" $ACTUAL_TOKENS $BUDGET
    scripts/delegation-retry.sh with-reduced-context "${1}" "${2}" $BUDGET
fi
```

### Context Pollution Prevention
- Monitor context growth during delegation
- Automatic context cleanup post-delegation
- Prevent recursive delegation loops
- Track delegation depth and breadth

## Performance Optimization

### Parallel Delegation Support
```bash
# Enable parallel execution for independent tasks
export AWOC_PARALLEL_DELEGATION=true
export AWOC_MAX_PARALLEL_AGENTS=5
```

### Caching and Reuse
- Cache common sub-agent responses
- Reuse similar task outputs
- Intelligent context pre-loading
- Result deduplication

### Quality Metrics
- Task completion success rate
- Average token efficiency
- Context pollution levels  
- User satisfaction scores

## Integration Points

### With Context Monitoring
- Real-time delegation tracking
- Budget usage analytics
- Performance trend analysis
- Optimization recommendations

### With Handoff Protocol
- Save delegation state for recovery
- Resume interrupted delegations
- Cross-session delegation continuity
- Historical delegation analysis

### With Background Tasks
- Delegate long-running tasks to background
- Monitor background delegation progress
- Integrate background results seamlessly
- Manage background resource usage

---

**Example Delegation Workflows:**

### API Integration Project
```bash
# 1. Research phase
/delegate docs-fetcher "Research Stripe payment API documentation and examples" 4000 high

# 2. Design phase  
/delegate architect "Design payment processing system using Stripe API" 6000 high

# 3. Implementation phase
/delegate workforce "Implement payment system based on architect design" 10000 critical
```

### Bug Investigation  
```bash
# 1. Analysis phase
/delegate architect "Analyze authentication bug in user login system" 5000 critical

# 2. Research solutions
/delegate docs-fetcher "Find solutions for JWT token validation issues" 3000 high  

# 3. Fix implementation
/delegate workforce "Implement bug fix based on architect analysis" 6000 critical
```

### Feature Development Pipeline
```bash
# Parallel research and design
/delegate docs-fetcher "Research React state management patterns" 4000 medium &
/delegate architect "Design state management architecture" 5000 medium &

# Sequential implementation  
wait # for parallel tasks
/delegate workforce "Implement state management using research and design" 8000 high
```