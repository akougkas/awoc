# AWOC - Agentic Workflows Orchestration Cabinet

**AWOC** is a lightweight, developer-first framework for orchestrating AI agents in Claude Code, OpenCode, and Gemini CLI environments. Designed for professional developers who want predictable, efficient AI collaboration without complexity.

## Philosophy

AWOC follows **incremental development** principles:
- Start with what works today  
- Add complexity only when needed
- Focus on developer experience
- Keep it simple, make it reliable

## Quick Start

```bash
# 1. Clone and install
git clone https://github.com/yourusername/awoc.git ~/.awoc
cd ~/.awoc && ./install.sh

# 2. Verify installation
./validate.sh

# 3. Start working in your project
cd /path/to/your/project
awoc session start "Building a FastAPI service"
```

## Core Features

- **🤖 Focused Agents**: Six specialized agents for common development tasks
- **📋 Session Management**: Git-integrated workflows with clean state tracking
- **🔒 Security First**: Granular permissions model protects sensitive data
- **✅ Production Ready**: Comprehensive validation and error handling
- **🔄 Git Native**: Seamless integration with existing development workflow

## Available Agents

| Agent | Purpose | Common Use Cases |
|-------|---------|------------------|
| **api-researcher** | Technical documentation and API research | API integration, framework research, best practices |
| **content-writer** | Documentation, blog posts, marketing materials | README files, technical blogs, user guides |
| **data-analyst** | CSV/JSON analysis, statistics, reporting | Log analysis, performance metrics, A/B testing |
| **project-manager** | Task breakdown, progress tracking, coordination | Sprint planning, milestone tracking, team updates |
| **learning-assistant** | Study plans, concept explanations, guidance | Code reviews, skill development, training materials |
| **creative-assistant** | Brainstorming, ideation, problem-solving | Feature ideation, UX concepts, technical solutions |

## Installation

### Automatic Installation (Recommended)

The installer automatically detects your AI CLI environment and installs AWOC correctly:

```bash
# Clone the repository
git clone https://github.com/yourusername/awoc.git ~/.awoc

# Run the installer (with automatic CLI detection)
cd ~/.awoc && ./install.sh

# Verify installation
./validate.sh
```

**Supported Environments:**
- Claude Code (`~/.claude/`)
- OpenCode (`~/.opencode/`)  
- Gemini CLI (`~/.gemini/`)

### Manual Installation

If you prefer manual installation:

```bash
# For Claude Code users
cp -r ~/.awoc ~/.claude/

# For OpenCode users  
cp -r ~/.awoc ~/.opencode/

# For Gemini CLI users
cp -r ~/.awoc ~/.gemini/
```

### Verification

After installation, verify everything works:

```bash
# Check AWOC command is available
awoc help

# Validate installation integrity
awoc validate

# Test session management
cd /tmp && mkdir test-project && cd test-project
awoc session start "Testing AWOC installation"
awoc session end "Installation verified successfully"
```

## Usage Guide

### Basic Workflow

```bash
# 1. Navigate to your project
cd /path/to/your/project

# 2. Start a session with clear description
awoc session start "Implementing user authentication system"

# 3. Work normally - AWOC integrates automatically
# Your AI assistant will now have access to AWOC agents and commands

# 4. End session with summary
awoc session end "Completed OAuth2 integration with unit tests"
```

### Session Management

AWOC provides git-integrated session management:

```bash
# Start session (checks clean git state)
awoc session start "Feature: Add user dashboard"

# End session (commits changes automatically)  
awoc session end "Dashboard complete with responsive design"

# Initialize AWOC in new project
awoc init  # Creates project-specific configuration
```

### Working with Agents

Agents are automatically available in your AI CLI environment. Reference them by name:

```bash
# Example interactions (in your AI CLI):
"api-researcher, help me understand the Stripe API for subscriptions"
"content-writer, create a README for this FastAPI project" 
"data-analyst, analyze the performance metrics in logs/access.log"
"project-manager, break down this feature into development tasks"
```

### Advanced Configuration

```bash
# Generate custom agent
awoc generate agent my-specialist -d "Custom agent for specific needs"

# Generate custom command  
awoc generate command my-workflow -d "Custom workflow command"

# Create project-specific settings
awoc generate settings my-project
```

## Project Structure

```
~/.awoc/
├── agents/               # AI agent definitions
│   ├── api-researcher.md
│   ├── content-writer.md
│   ├── data-analyst.md
│   ├── project-manager.md
│   ├── learning-assistant.md
│   └── creative-assistant.md
├── commands/             # Workflow commands
│   ├── session-start.md
│   └── session-end.md
├── templates/            # Generation templates
│   ├── agent-template.md
│   ├── command-template.md
│   └── settings-template.json
├── scripts/              # Utility scripts
│   └── generate-template.sh
├── settings.json         # Core configuration
├── install.sh           # Installation script
├── validate.sh          # Validation script
└── README.md            # This file
```

## Troubleshooting

### Common Issues

**"awoc command not found"**
```bash
# Check installation path
ls ~/.claude/awoc ~/.opencode/awoc ~/.gemini/awoc 2>/dev/null

# Reinstall if needed
cd ~/.awoc && ./install.sh
```

**"Git state not clean" during session start**
```bash
# Commit or stash your changes first
git add . && git commit -m "WIP: checkpoint before AWOC session"
# or
git stash

# Then start session
awoc session start "Continue working on feature"
```

**Permission errors**
```bash
# Check file permissions
chmod +x ~/.awoc/*.sh ~/.awoc/scripts/*.sh

# Verify configuration
awoc validate
```

### Getting Help

```bash
# Show available commands
awoc help

# Validate installation
awoc validate  

# Check logs for issues
tail -f ~/.awoc-*.log
```

## Development

### For Contributors

```bash
# Clone for development
git clone https://github.com/yourusername/awoc.git
cd awoc

# Make changes to agents, templates, or scripts
# Test changes
./validate.sh

# Generate new components
./scripts/generate-template.sh agent my-test-agent -d "Test agent"
```

### Architecture

- **Agents**: Markdown files with YAML frontmatter defining AI assistant behaviors
- **Commands**: Markdown templates for common workflows with tool restrictions
- **Templates**: Base templates for generating new components consistently
- **Configuration**: JSON-based settings with granular permissions

### Extension Points

- Add new agents by creating markdown files in `agents/`
- Create custom commands in `commands/`
- Extend templates for consistent component generation
- Modify `settings.json` for project-specific configurations

## Contributing

We welcome contributions! This project is designed for the developer community.

### Process

1. **Fork** the repository on GitHub
2. **Clone** your fork locally  
3. **Create** a feature branch (`git checkout -b feature/amazing-improvement`)
4. **Make** your changes and test with `./validate.sh`
5. **Commit** with clear messages (`git commit -m "Add amazing improvement"`)
6. **Push** to your fork (`git push origin feature/amazing-improvement`)
7. **Submit** a pull request with description of changes

### Guidelines

- Keep agents focused and lightweight (~80 lines)
- Follow existing patterns and conventions
- Test all changes thoroughly
- Update documentation for new features
- Maintain the "lightweight, developer-first" philosophy

## License

MIT License - Free for personal and commercial use.

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/awoc/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/awoc/discussions)  
- **Documentation**: See files in `docs/` directory

---

**Built for developers, by developers.** AWOC enhances your existing workflow without getting in the way.