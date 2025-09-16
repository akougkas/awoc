# AWOC Dynamic Sub-Agent Creator
---
name: create-subagent
description: Dynamically generate specialized sub-agents for specific task domains
argument-hint: [agent-name] [specialization] [model] [token-budget] [tools]
allowed-tools: [Write, Read, Task, Bash]
schema: create-subagent-v1.0
---

## Overview
Creates task-specific sub-agents on-demand with optimized configurations for specialized workflows.

## Usage

### Basic Agent Creation
```bash
/create-subagent payment-specialist "Stripe API integration" sonnet 8000 "WebFetch,Read,Write"
/create-subagent test-generator "Unit test creation" haiku 4000 "Read,Write,Bash"
/create-subagent security-auditor "Security vulnerability analysis" opus 12000 "Read,Grep,Bash"
```

### Template-Based Creation
```bash
/create-subagent api-integrator --template=api-specialist --budget=6000
/create-subagent bug-hunter --template=debugging-specialist --model=opus
/create-subagent performance-optimizer --template=optimization-specialist
```

### Custom Configuration
```bash
/create-subagent database-migrator \
    --specialization="Database schema migrations" \
    --model=sonnet \
    --budget=10000 \
    --tools="Read,Write,Bash,Task" \
    --max-depth=3 \
    --context-limit=8000
```

## Execution Flow

### 1. Validate Creation Parameters
```bash
!`scripts/subagent-validator.sh validate-params "${1}" "${2}" "${3:-sonnet}" "${4:-5000}" "${5}"`
```

### 2. Analyze Task Domain
```bash
!`scripts/task-domain-analyzer.sh analyze "${2}" "${1}"`

# Extract domain characteristics:
# - Required tools and capabilities
# - Expected token usage patterns
# - Context requirements
# - Integration points
```

### 3. Generate Agent Configuration
Based on domain analysis, create optimized agent definition:

```bash
# Generate agent configuration
agent_config=$(cat << EOF
---
name: ${1}
description: ${2}
model: ${3:-sonnet}
max_tokens: ${4:-5000}
tools: [${5:-"Read,Write,Bash"}]
specialization: "${2}"
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
parent_session: "${AWOC_SESSION_ID}"
optimization_level: "task-specific"
context_isolation: true
---

# Specialized Agent: ${1}
You are a ${2} specialist created for focused task execution.

## Core Competencies
$(scripts/competency-generator.sh generate "${2}")

## Task Scope
- **Primary Focus**: ${2}
- **Token Budget**: ${4:-5000} tokens maximum
- **Context Limit**: Maintain focus on current task only
- **Tools Available**: ${5:-"Read,Write,Bash"}

## Operating Principles
1. **Focused Execution**: Stay within specialized domain
2. **Efficient Communication**: Provide clear, actionable outputs
3. **Budget Awareness**: Monitor token usage continuously
4. **Quality Output**: Deliver production-ready results

$(scripts/domain-specific-instructions.sh generate "${2}")

## Integration Protocol
- Report findings in structured format
- Provide clear next steps and dependencies
- Flag issues requiring escalation
- Maintain compatibility with parent workflow

EOF
)
```

### 4. Create Agent Definition File
```bash
echo "$agent_config" > ".claude/agents/${1}.md"
```

### 5. Initialize Agent Context
```bash
!`scripts/subagent-context-initializer.sh init "${1}" "${2}" "${4:-5000}"`
```

### 6. Register Agent in System
```bash
!`scripts/subagent-registry.sh register "${1}" "${agent_config}" "${AWOC_SESSION_ID}"`
```

### 7. Test Agent Functionality
```bash
!`scripts/subagent-tester.sh quick-test "${1}" "${2}"`
```

## Agent Templates

### API Integration Specialist
```markdown
---
name: api-integrator-template
specialization: API integration and documentation
model: sonnet
max_tokens: 6000
tools: [WebFetch, Read, Write, Bash]
context_focus: ["API documentation", "integration patterns", "error handling"]
---

You specialize in API integration tasks:
- Research API documentation and capabilities
- Design integration patterns and error handling
- Implement authentication and rate limiting
- Create comprehensive test suites
- Document integration specifications
```

### Security Analysis Specialist  
```markdown
---
name: security-auditor-template
specialization: Security vulnerability analysis
model: opus
max_tokens: 10000
tools: [Read, Grep, Bash, WebFetch]
context_focus: ["security patterns", "vulnerability detection", "threat modeling"]
---

You specialize in security analysis:
- Identify potential security vulnerabilities
- Analyze authentication and authorization flows
- Review data handling and privacy compliance
- Recommend security improvements
- Generate security test scenarios
```

### Performance Optimization Specialist
```markdown
---
name: performance-optimizer-template  
specialization: Performance analysis and optimization
model: sonnet
max_tokens: 8000
tools: [Read, Write, Bash, Grep]
context_focus: ["performance metrics", "optimization patterns", "profiling"]
---

You specialize in performance optimization:
- Analyze performance bottlenecks
- Recommend optimization strategies
- Implement performance improvements
- Create performance monitoring
- Generate performance test suites
```

### Database Migration Specialist
```markdown
---
name: database-migrator-template
specialization: Database schema and data migrations
model: sonnet
max_tokens: 7000
tools: [Read, Write, Bash]
context_focus: ["database schemas", "migration patterns", "data integrity"]
---

You specialize in database migrations:
- Design schema migration strategies
- Implement safe migration scripts
- Handle data transformation and validation
- Create rollback procedures
- Generate migration documentation
```

## Specialization Domains

### Development Domains
- **API Integration**: REST, GraphQL, webhooks, authentication
- **Database Work**: Migrations, queries, optimization, design
- **Testing**: Unit, integration, performance, security testing
- **DevOps**: CI/CD, deployment, monitoring, infrastructure
- **Security**: Vulnerability analysis, compliance, threat modeling

### Research Domains
- **Technology Research**: Framework comparison, best practices
- **Documentation**: API docs, technical writing, tutorials
- **Code Analysis**: Code review, refactoring, architecture analysis
- **Performance Analysis**: Profiling, optimization, benchmarking
- **Compliance**: Standards compliance, regulatory requirements

### Creative Domains
- **UI/UX Design**: Interface design, user experience optimization
- **Content Creation**: Technical writing, documentation, examples
- **Prototyping**: Proof-of-concept development, rapid iteration
- **Innovation**: New feature design, experimental implementations

## Dynamic Configuration

### Context-Aware Optimization
```bash
optimize_agent_for_context() {
    local agent_name="$1"
    local current_context="$2"
    local task_complexity="$3"
    
    # Adjust token budget based on complexity
    case "$task_complexity" in
        "simple")
            token_budget=3000
            model="haiku"
            ;;
        "moderate")
            token_budget=6000
            model="sonnet" 
            ;;
        "complex")
            token_budget=10000
            model="opus"
            ;;
    esac
    
    # Update agent configuration
    scripts/agent-config-updater.sh update "$agent_name" "budget=$token_budget" "model=$model"
}
```

### Tool Selection Logic
```bash
select_optimal_tools() {
    local specialization="$1"
    local tools=()
    
    # Base tools for all agents
    tools+=("Read" "Write")
    
    # Specialization-specific tools
    case "$specialization" in
        *"API"*|*"web"*|*"integration"*)
            tools+=("WebFetch")
            ;;
        *"analysis"*|*"search"*|*"audit"*)
            tools+=("Grep" "Glob")
            ;;
        *"implementation"*|*"development"*)
            tools+=("Bash" "Task")
            ;;
        *"testing"*|*"deployment"*)
            tools+=("Bash")
            ;;
    esac
    
    echo "${tools[@]}"
}
```

## Agent Lifecycle Management

### Creation Workflow
1. **Domain Analysis**: Analyze task requirements
2. **Template Selection**: Choose best-fit template
3. **Configuration Generation**: Create optimized config
4. **Validation**: Test agent functionality
5. **Registration**: Add to agent registry
6. **Integration**: Configure with parent workflow

### Runtime Management
- **Performance Monitoring**: Track token usage and efficiency
- **Quality Assessment**: Monitor output quality
- **Resource Management**: Manage concurrent agent limits
- **Context Cleanup**: Clean up after task completion

### Cleanup and Archival
```bash
cleanup_subagent() {
    local agent_name="$1"
    local cleanup_mode="${2:-archive}"
    
    case "$cleanup_mode" in
        "archive")
            # Move to archive directory
            mv ".claude/agents/${agent_name}.md" ".awoc/archived/agents/"
            ;;
        "delete")
            # Permanent deletion
            rm ".claude/agents/${agent_name}.md"
            ;;
        "preserve")
            # Keep for future use
            scripts/agent-registry.sh mark-inactive "$agent_name"
            ;;
    esac
    
    # Clean up context and temporary files
    scripts/subagent-context-cleaner.sh clean "$agent_name"
}
```

## Integration with Delegation System

### Automatic Agent Creation
```bash
# When delegating unknown specializations, create specialized agent
auto_create_specialist() {
    local task_description="$1"
    local domain=$(scripts/task-domain-extractor.sh extract "$task_description")
    
    if ! agent_exists_for_domain "$domain"; then
        create_specialized_agent "$domain" "$task_description"
    fi
    
    # Delegate to the specialized agent
    delegate_to_specialist "$domain" "$task_description"
}
```

### Multi-Agent Coordination
```bash
# Create team of specialized agents for complex tasks
create_agent_team() {
    local project_type="$1"
    shift
    local requirements=("$@")
    
    case "$project_type" in
        "full-stack-app")
            create_subagent "frontend-specialist" "Frontend development" sonnet 8000 "Read,Write,WebFetch"
            create_subagent "backend-specialist" "Backend API development" sonnet 8000 "Read,Write,Bash"
            create_subagent "database-specialist" "Database design" sonnet 6000 "Read,Write"
            create_subagent "test-specialist" "Testing strategy" haiku 4000 "Read,Write,Bash"
            ;;
        "api-service")
            create_subagent "api-designer" "API design and documentation" sonnet 6000 "Read,Write,WebFetch"
            create_subagent "implementation-specialist" "API implementation" sonnet 8000 "Read,Write,Bash"
            create_subagent "security-reviewer" "Security analysis" opus 8000 "Read,Grep"
            ;;
    esac
}
```

## Quality Assurance and Testing

### Agent Validation Tests
```bash
# Test agent creation and functionality
test_subagent_creation() {
    local test_agent="test-agent-$$"
    
    # Create test agent
    create_subagent "$test_agent" "Simple task execution" haiku 2000 "Read,Write"
    
    # Test basic functionality
    if [[ -f ".claude/agents/${test_agent}.md" ]]; then
        echo "✓ Agent file created successfully"
    else
        echo "✗ Agent file creation failed"
        return 1
    fi
    
    # Test agent execution
    local result=$(Task agent="$test_agent" task="Generate a simple greeting")
    if [[ -n "$result" ]]; then
        echo "✓ Agent execution successful"
    else
        echo "✗ Agent execution failed"
        return 1
    fi
    
    # Cleanup
    cleanup_subagent "$test_agent" delete
}
```

### Performance Benchmarking
```bash
# Benchmark agent performance
benchmark_agent_performance() {
    local agent_name="$1"
    local test_tasks=("$@")
    
    for task in "${test_tasks[@]}"; do
        start_time=$(date +%s.%N)
        start_tokens=$(scripts/context-monitor.sh get-current-usage)
        
        # Execute task
        result=$(Task agent="$agent_name" task="$task")
        
        end_time=$(date +%s.%N)
        end_tokens=$(scripts/context-monitor.sh get-current-usage)
        
        # Calculate metrics
        duration=$(echo "$end_time - $start_time" | bc -l)
        tokens_used=$(echo "$end_tokens - $start_tokens" | bc -l)
        
        echo "Task: $task"
        echo "Duration: ${duration}s"
        echo "Tokens: $tokens_used"
        echo "Efficiency: $(echo "scale=2; $tokens_used / $duration" | bc -l) tokens/s"
        echo "---"
    done
}
```

## Success Metrics and Analytics

### Creation Success Rate
- Percentage of agents created successfully
- Time to create and validate new agents  
- Agent functionality test pass rate

### Performance Metrics
- Token efficiency per specialization domain
- Task completion success rates
- Average execution time by agent type

### Quality Metrics
- Output quality scores
- Integration success rates
- User satisfaction with specialized agents

---

**Example Usage Scenarios:**

### E-commerce Project
```bash
# Create specialized team
/create-subagent payment-handler "Payment processing integration" sonnet 8000 "WebFetch,Read,Write"
/create-subagent inventory-manager "Inventory management system" sonnet 7000 "Read,Write,Bash"
/create-subagent order-processor "Order processing workflow" sonnet 6000 "Read,Write"
/create-subagent email-notifier "Email notification system" haiku 4000 "WebFetch,Write"
```

### Security Audit Project
```bash
# Create security-focused agents
/create-subagent vulnerability-scanner "Security vulnerability analysis" opus 10000 "Read,Grep,Bash"
/create-subagent compliance-checker "Compliance and standards verification" sonnet 8000 "Read,Grep"
/create-subagent penetration-tester "Security testing and validation" sonnet 7000 "Bash,WebFetch"
```

### Performance Optimization Project
```bash
# Create performance-focused specialists
/create-subagent profiler "Application performance profiling" sonnet 8000 "Read,Bash"
/create-subagent optimizer "Code optimization recommendations" opus 9000 "Read,Write,Grep"
/create-subagent load-tester "Load testing and benchmarking" haiku 5000 "Bash,Write"
```