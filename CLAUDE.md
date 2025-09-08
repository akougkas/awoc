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

## Phase-by-Phase Implementation

### Phase 1: Context Monitoring Infrastructure
**Goal**: Build measurement foundation

**Tasks**:
1. **Create `scripts/context-monitor.sh`**
   - Track token usage in real-time
   - Log context state transitions
   - Generate usage reports
   - Trigger warnings at thresholds

2. **Create `scripts/token-logger.sh`**
   - Log operations with agent attribution
   - Budget tracking per agent
   - Usage analytics and reporting

3. **Update `settings.json`**
   - Add context monitoring config
   - Add hooks for automatic tracking
   - Enable real-time monitoring

4. **Test Infrastructure**
   - Validate scripts work correctly
   - Confirm hooks trigger properly
   - Verify data accuracy

**Success Criteria**: Can see real-time token usage per operation

### Phase 2: Dynamic Priming System
**Goal**: Replace static context with on-demand loading

**Tasks**:
1. **Create `commands/prime-dev.md`**
   - Master priming command
   - Scenario-specific loading
   - Context budget management

2. **Create priming scenarios**
   - `commands/priming/prime-api-integration.md`
   - `commands/priming/prime-bug-fixing.md`
   - `commands/priming/prime-feature-dev.md`

3. **Reduce one agent to core**
   - Choose simplest agent first
   - Reduce to 10 lines essential
   - Test with priming system

4. **Validate 70% reduction**
   - Measure token savings
   - Confirm functionality preserved
   - Document improvement

**Success Criteria**: One agent works with 70% fewer tokens

### Phase 3: Context Handoff Protocol
**Goal**: Enable session continuity

**Tasks**:
1. **Design handoff bundle format**
   - JSON schema for context state
   - Knowledge graph representation
   - Compression and storage

2. **Create handoff commands**
   - `commands/handoff-save.md`
   - `commands/handoff-load.md`
   - Automatic handoff hooks

3. **Test session continuity**
   - Save context mid-session
   - Restore in fresh session
   - Verify 60-70% context recovery

**Success Criteria**: Can pause/resume work seamlessly

### Phase 4: Hierarchical Delegation
**Goal**: Parallel agent processing

**Tasks**:
1. **Create sub-agent templates**
   - Lightweight 3k token agents
   - Specialized for single tasks
   - Report-only communication

2. **Implement delegation system**
   - `commands/delegate.md` using Task tool
   - Background agent launcher
   - Result integration without context bloat

3. **Test parallel execution**
   - Multiple sub-agents simultaneously
   - Background task processing
   - Resource coordination

**Success Criteria**: Can run 3+ agents concurrently

### Phase 5: Production Hardening
**Goal**: Enterprise-ready deployment

**Tasks**:
1. Enterprise policy integration
2. Security validations
3. Performance optimization
4. Migration tools and documentation

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