---
name: list-priming
description: List available priming scenarios
allowed-tools: Bash
---

## Available Priming Scenarios

### Quick Command Reference
Use `/prime-dev [scenario] [budget]` to load development context.

### Scenarios

#### 🐛 bug-fixing
**Focus**: Bug investigation and resolution context
**Includes**: Debugging methodology, diagnostic tools, error patterns, testing strategies
**Usage**: `/prime-dev bug-fixing 3000`

#### ⚡ feature-dev
**Focus**: Feature development and implementation context  
**Includes**: Design patterns, testing strategies, configuration management, performance optimization
**Usage**: `/prime-dev feature-dev 3000`

#### 🔍 research
**Focus**: Research and investigation context
**Includes**: Investigation methodology, analysis techniques, technology evaluation, documentation
**Usage**: `/prime-dev research 3000`

#### 🔌 api-integration
**Focus**: API integration and documentation context
**Includes**: Authentication, request/response handling, error handling, rate limiting, testing
**Usage**: `/prime-dev api-integration 3000`

### Token Budget Guidelines
- **Default**: 3000 tokens per scenario
- **Light**: 1500-2000 tokens (essential patterns only)
- **Full**: 3000-4000 tokens (comprehensive context)
- **Heavy**: 4000+ tokens (maximum context, use carefully)

### Context Status
Current session tokens: !`if [ -f "$HOME/.awoc/context/current_session.json" ]; then jq -r '.current_tokens // "Not monitored"' "$HOME/.awoc/context/current_session.json"; else echo "Not monitored"; fi`

### Examples
```bash
# Load bug-fixing context with default budget
/prime-dev bug-fixing

# Load feature development with custom budget  
/prime-dev feature-dev 2500

# Load research context for investigation work
/prime-dev research

# Load API integration patterns
/prime-dev api-integration 3500
```

### Integration with AWOC Agents
After priming, use specialized agents with enhanced context:
- `/agents architect` - Enhanced design capabilities
- `/agents docs-fetcher` - Research with scenario-specific patterns
- `/agents workforce` - Implementation with best practices loaded