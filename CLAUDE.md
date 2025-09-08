# AWOC 2.0 Context Engineering Framework
## Development Guide for Incremental Implementation

> **Mission**: Transform AWOC from static agent collection to dynamic, context-aware orchestration framework through incremental development.

## Repository Overview

### Current Structure (Clean from Origin/Main)
```
awoc-claude-v2/
├── agents/               # 6 agents (need reduction: 80 lines → 10 lines)
│   ├── api-researcher.md
│   ├── content-writer.md
│   ├── data-analyst.md
│   ├── project-manager.md
│   ├── learning-assistant.md
│   └── creative-assistant.md
├── commands/             # Workflow templates (will expand significantly)
│   ├── session-start.md
│   └── session-end.md
├── scripts/              # Utility scripts (will add context engine)
├── templates/            # Generation templates
├── settings.json         # Core config (will add context/hooks)
├── install.sh           # Installation script
├── validate.sh          # Health checker
└── OPUS-PLAN.md         # Master implementation plan
```

### Tech Stack
- **Infrastructure**: Pure bash scripts + JSON configuration
- **Agent System**: Markdown + YAML frontmatter
- **Commands**: Claude Code slash commands (`.md` files)
- **Hooks**: Claude Code native hook system
- **Settings**: Hierarchical JSON (user/project/enterprise)
- **Context Engine**: NEW - Token monitoring & optimization

## Current State Analysis

### Token Usage (Baseline - Need to Measure)
```
6 agents × ~80 lines each = ~480 lines static content
Estimated: ~16-20k tokens consumed constantly
Target: Reduce to ~350-500 tokens baseline
Savings: 90% context reduction through dynamic priming
```

### Files to Transform
- **All agents**: Reduce to 10-line cores + dynamic priming
- **settings.json**: Add context monitoring + hooks
- **commands/**: Add prime-dev, handoff-save/load, delegate
- **scripts/**: Create context-monitor.sh, token-logger.sh
- **New directories**: .awoc/handoffs, .awoc/cache

## AWOC 2.0 Architecture

### Core Innovation: Context Engineering
Replace static 80-line agents with:
1. **10-line agent cores** (essential identity only)
2. **Dynamic priming** via `/prime-dev` command
3. **Context handoff protocol** for session continuity
4. **Hierarchical delegation** (sub-agents, background agents)
5. **Smart monitoring** with automatic optimization

### Success Metrics
- **70% context reduction** (tokens saved)
- **3x faster execution** (parallel processing)
- **95% success rate** (autonomous operation)
- **10+ concurrent agents** (scalability)

## Development Methodology

### 1. Incremental Development (CRITICAL)
**Build one feature, validate, test thoroughly, then next**

```bash
# Example cycle:
1. Create context-monitor.sh
   ./validate.sh              # Must pass
   Test with current agents   # Must work
   
2. Add one prime command
   ./validate.sh              # Must pass
   Test priming functionality # Must work
   
3. Reduce one agent to core
   ./validate.sh              # Must pass
   Test agent with priming    # Must work

# NEVER build multiple features simultaneously!
```

### 2. Validation-Driven Development
- Run `./validate.sh` after EVERY change
- Test functionality immediately
- Fix issues before proceeding
- Document what works and what doesn't

### 3. Context-Aware Implementation
- Monitor token usage with `/context` command
- Measure before optimizing (establish baselines)
- Track improvements quantitatively
- Never break existing functionality

## Subagent Orchestration Protocol

### Available Subagents

You have three specialized subagents in `.claude/agents/`:

1. **architect** (Opus, 16768 thinking) - Senior engineer for design and complex analysis
2. **docs-fetcher** (Haiku + MCP) - Fast research for APIs, code snippets, solutions
3. **workforce** (Sonnet) - High-performance code generation and testing

### Development Workflow Cycles

#### Standard Feature Development Cycle
```
New Feature X:
1. architect(design X) → produces technical specification
2. docs-fetcher(research X) → finds APIs, examples, best practices
3. workforce(implement X) → generates code and tests
4. architect(review X) → validates implementation
5. workforce(commit X) → finalizes and commits
```

#### Bug Investigation Cycle
```
Bug Y:
1. architect(analyze Y) → investigates root cause
2. docs-fetcher(find solutions Y) → researches fix approaches
3. workforce(fix Y) → implements solution with tests
4. architect(verify fix Y) → confirms resolution
5. workforce(commit fix) → finalizes fix
```

### Agent Orchestration Commands

#### Parallel Research
```bash
# Launch parallel research
/agents exec docs-fetcher "Research Stripe API for payment processing"
/agents exec docs-fetcher "Find React hooks best practices" 
# Agents work simultaneously, report back independently
```

#### Sequential Design-to-Code
```bash
# Design phase
/agents exec architect "Design user authentication system with JWT"

# Wait for design, then implement
/agents exec workforce "Implement authentication based on architect's design"

# Review and finalize
/agents exec architect "Review authentication implementation for security"
```

#### Complex Feature Pipeline
```bash
# Full pipeline for major feature
/agents exec architect "Design shopping cart system with persistence"
# → architect produces: API design, data models, component structure

/agents exec docs-fetcher "Research e-commerce cart patterns and libraries"
# → docs-fetcher produces: recommended libraries, code examples, best practices

/agents exec workforce "Implement shopping cart system using architect design and docs-fetcher research"
# → workforce produces: complete implementation with tests

/agents exec architect "Review shopping cart implementation for scalability and security"
# → architect validates: performance, security, code quality
```

### Communication Protocol

#### Task Handoffs
1. **Clear Specifications**: Each agent receives specific, actionable tasks
2. **Context Sharing**: Agents reference each other's outputs
3. **Iterative Refinement**: Agents can request clarification or additional work
4. **Final Integration**: All outputs merge into working system

#### Result Integration
```markdown
# Example handoff pattern:
1. Architect produces: "Design doc in design-auth-system.md"
2. Docs-fetcher produces: "Research findings in research-auth-libraries.md"  
3. Workforce produces: "Implementation in src/auth/ with tests/"
4. Architect produces: "Review feedback in review-auth-implementation.md"
```

### Subagent Capabilities

#### Architect Strengths
- **Complex Problem Analysis**: Deep investigation of difficult issues
- **System Design**: High-level architecture and component relationships
- **Code Review**: Quality assessment and improvement suggestions
- **Technical Leadership**: Decision making for complex trade-offs

#### Docs-fetcher Strengths  
- **Fast Research**: Quick answers to technical questions
- **API Discovery**: Finding documentation and usage examples
- **Technology Evaluation**: Comparing options and recommending approaches
- **Code Example Finding**: Working snippets for specific functionality

#### Workforce Strengths
- **Rapid Implementation**: Fast, high-quality code generation
- **Test Coverage**: Comprehensive testing strategies
- **Code Integration**: Clean integration with existing codebase
- **Bug Fixes**: Quick resolution of implementation issues

### Optimization Strategies

#### Parallel Processing
- Launch multiple agents simultaneously for independent tasks
- docs-fetcher can research while architect designs
- workforce can implement components in parallel

#### Context Efficiency
- Each subagent has focused, minimal context
- No complex hooks or monitoring overhead
- Fast startup and execution

#### Result Caching
- Subagent outputs are saved as files for reuse
- Future tasks can reference previous work
- Build knowledge base over time

### Usage Examples

#### Simple API Integration
```bash
# Quick research and implementation
/agents exec docs-fetcher "Find Stripe payment integration example"
/agents exec workforce "Implement Stripe payments using docs-fetcher findings"
```

#### Complex System Design
```bash
# Full design-to-implementation cycle
/agents exec architect "Design microservices architecture for user management"
/agents exec docs-fetcher "Research microservices patterns and Docker deployment"
/agents exec workforce "Implement user service based on architect design"
/agents exec workforce "Create deployment configuration using docs-fetcher research"
/agents exec architect "Review complete system for production readiness"
```

### Success Metrics

- **Speed**: 3x faster development through parallel processing
- **Quality**: Architect review ensures high code quality
- **Research**: docs-fetcher provides current best practices
- **Reliability**: workforce generates tested, working code

### Getting Started

1. **Validate Setup**: Ensure all three subagents are available in `.claude/agents/`
2. **Start Simple**: Begin with single agent tasks to understand capabilities
3. **Build Pipelines**: Create longer workflows with multiple agents
4. **Iterate and Improve**: Refine agent cooperation patterns over time

## Claude Code Integration

### Native Features to Leverage
- **Slash Commands**: Every operation is a `.md` file
- **Hooks**: Automatic behaviors in `settings.json`
- **Task Tool**: Sub-agent delegation
- **Settings Hierarchy**: User → project → enterprise
- **CLI Integration**: Background agent spawning

### Hook Strategy
```json
{
  "hooks": {
    "PreToolUse": "Track all tool usage",
    "UserPromptSubmit": "Check context thresholds",
    "SessionEnd": "Save context handoff bundle",
    "PreCompact": "Emergency handoff save"
  }
}
```

## Quality Standards

### Code Quality
- All bash scripts must pass `shellcheck`
- JSON must validate with `jq`
- Markdown must be properly formatted
- All scripts must have error handling

### Testing Protocol
```bash
# After each change:
./validate.sh                    # Health check
/context                         # Token usage check
Test specific functionality      # Feature verification
git add . && git commit -m "..." # Version control
```

### Documentation Requirements
- Update this CLAUDE.md as you learn
- Document all script functions
- Explain configuration options
- Provide troubleshooting guides

## Do's and Don'ts

### ✅ DO
- **Start small**: One script, one command, one test
- **Measure first**: Use `/context` to see current state
- **Test immediately**: `./validate.sh` after every change
- **Follow patterns**: Study existing files structure
- **Use native tools**: Hooks, settings, Task tool
- **Document decisions**: Update guides as you learn
- **Commit working features**: Version control success

### ❌ DON'T
- **Build multiple features**: Incremental only!
- **Skip validation**: Must pass health checks
- **Break existing**: Maintain backward compatibility
- **Ignore token limits**: Monitor context constantly
- **Reinvent wheels**: Use Claude Code native features
- **Rush phases**: Quality over speed
- **Work without tests**: Every feature must be verified

## Current Status

### Established in Main Branch
- Basic agent structure (needs reduction)
- Installation and validation system
- Template generation system
- Git integration

### To Be Built (New Infrastructure)
- Context monitoring system
- Dynamic priming commands
- Handoff protocol
- Sub-agent delegation
- Background orchestration

## Emergency Recovery

### If Things Break
```bash
git status                    # Check current state
git stash                     # Save work
git reset --hard origin/main  # Return to clean state
./validate.sh                # Confirm working
```

### Rollback Strategy
- Each phase is a separate commit
- Can revert to any working state
- Original AWOC remains unaffected
- Clean worktree isolation

## Success Validation

### Phase 1 Complete When:
- `scripts/context-monitor.sh` exists and works
- Can see real-time token usage
- Hooks automatically track context
- `./validate.sh` passes with new monitoring

### Phase 2 Complete When:
- `/prime-dev` command loads context dynamically
- One agent reduced to 10 lines + works with priming
- 70% token reduction demonstrated
- All existing functionality preserved

### Continue for Phases 3-5...

## Commands for Development

```bash
# Start development
./validate.sh                    # Check current state
/context                         # Monitor tokens

# Development cycle
./validate.sh                    # After each change
git add . && git commit -m "..." # Version working features

# Testing
/prime-dev api-integration test   # Test priming
./scripts/context-monitor.sh     # Test monitoring
```

## Key Implementation Notes

### Context Monitoring Priority
- Real-time token tracking is foundation
- Without measurement, can't optimize
- Build this infrastructure FIRST

### Agent Reduction Strategy
- Keep essential identity (name, tools, core purpose)
- Remove all static examples and verbose instructions
- Replace with dynamic priming references
- Test each agent individually

### Priming Command Design
- Scenario-based loading (api, bug-fixing, feature-dev)
- Budget-aware (max tokens per scenario)
- Cacheable results (avoid reloading)
- Fallback for missing scenarios

---

**Remember**: This is a complete reimplementation of AWOC's architecture. Take time to understand each component before building. Quality and reliability over speed.

**First Step**: Create `scripts/context-monitor.sh` and test it works.