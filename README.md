![AWOC Banner](https://via.placeholder.com/1200x300/4A90E2/FFFFFF?text=AWOC+2.0+-+Agentic+Workflows+Orchestration+Cabinet)

# 🚀 AWOC - Agentic Workflows Orchestration Cabinet

**Transform your AI coding assistants into powerhouses of specialized agents, smart workflows, and context-aware orchestration**

AWOC brings enterprise-grade agent orchestration to your favorite AI coding environments. With a simple command, deploy a suite of specialized agents, advanced context management, and intelligent workflows directly into your projects.

## 🎯 Why AWOC?

AI coding assistants are powerful, but they're general-purpose. AWOC transforms them into specialized, context-aware orchestration systems that:

- **Remember Everything**: Smart context management that maintains state across sessions
- **Work in Teams**: Coordinate multiple specialized agents for complex tasks
- **Learn Your Patterns**: Adaptive workflows that improve with usage
- **Stay Organized**: Project-specific configurations that travel with your code
- **Think Efficiently**: Token optimization that reduces costs by up to 70%

## 🌟 Key Features

### Multi-Client Architecture
AWOC isn't tied to a single AI platform. Deploy the same powerful orchestration to:
- **Claude Code** (Available Now)
- **Gemini** (Coming Soon)
- **Codex** (Coming Soon)

### Specialized Agent Suite
Six expert agents, each optimized for specific tasks:
- **api-researcher**: Technical documentation and integration specialist
- **content-writer**: Documentation and content creation expert
- **data-analyst**: Data processing and visualization specialist
- **project-manager**: Task breakdown and timeline coordination
- **learning-assistant**: Educational support and concept explanation
- **creative-assistant**: Brainstorming and innovative problem-solving

### Advanced Context Engineering
- **Smart Handoffs**: Seamlessly transfer work between sessions
- **Token Optimization**: Reduce context usage by 70% with intelligent priming
- **Pattern Learning**: ML-powered optimization that adapts to your workflow
- **Session Recovery**: Never lose work with automatic state preservation

## 📦 Installation

AWOC installs cleanly in your user space - no sudo required, no system files modified.

### Quick Install

```bash
curl -fsSL https://github.com/akougkas/awoc/raw/main/install.sh | bash
```

This installs:
- `~/.local/bin/awoc` - The AWOC command
- `~/.config/awoc/` - Resources and configuration

### Manual Install

```bash
git clone https://github.com/akougkas/awoc
cd awoc
./install.sh
```

## 🚀 Getting Started

### 1. Create a New Project

```bash
mkdir ~/projects/my-app
cd ~/projects/my-app
```

### 2. Deploy AWOC to Your Project

```bash
# For Claude Code
awoc install -c claude -d .

# Future support
# awoc install -c gemini -d .
# awoc install -c codex -d .
```

This creates a clean project structure:
```
my-app/
└── .claude/
    ├── agents/       # Specialized agents
    ├── commands/     # Custom commands
    ├── scripts/      # Automation scripts
    └── settings.json # Project configuration
```

### 3. Open Your AI Assistant

Open Claude Code (or supported client) in your project directory. Your enhanced capabilities are ready!

### 4. Use Your New Powers

```bash
# In Claude Code
/awoc-help              # See all capabilities
/session-start          # Initialize smart session
/context-optimize       # Optimize token usage
/delegate              # Coordinate multiple agents
```

## 🎨 Project-First Philosophy

AWOC believes in project-specific configurations:

```bash
# Install to individual projects (recommended)
cd ~/projects/web-app
awoc install -c claude -d .

cd ~/projects/data-pipeline
awoc install -c claude -d .

# Each project gets its own configuration
# Version control friendly
# No global interference
```

### Global Installation (Use Sparingly)

```bash
# Install to home directory (affects all projects)
awoc install -c claude -d ~/

# ⚠️ You'll see a warning - global installation should be minimal
```

## 🛠️ Commands

```bash
awoc install -c <client> -d <dir>   # Deploy to project
awoc uninstall -d <dir>              # Remove from project
awoc validate -d <dir>               # Check installation
awoc restore -d <dir>                # Restore from backup
awoc list                            # Show available agents
awoc update                          # Update to latest version
awoc doctor                          # Diagnose issues
```

### Supported Clients
- `-c claude` - Claude Code ✅ Available
- `-c gemini` - Gemini (Coming Soon)
- `-c codex` - Codex (Coming Soon)

## 🔄 Smart Workflows

AWOC enables sophisticated multi-agent orchestration:

### Parallel Research
```yaml
Agents work simultaneously:
- api-researcher: "Find authentication patterns"
- data-analyst: "Analyze usage statistics"
- content-writer: "Draft documentation"
All results synthesized automatically
```

### Context Handoffs
```yaml
Morning session:
- Complete feature implementation
- Save context with /handoff-save

Evening session:
- Load context with /handoff-load
- Continue exactly where you left off
```

### Adaptive Learning
```yaml
AWOC learns from your patterns:
- Frequently used commands
- Common agent combinations
- Optimization opportunities
Automatically suggests improvements
```

## 🏗️ Architecture

AWOC uses a clean, modular design:

```
~/.local/bin/          # User binaries
└── awoc              # CLI tool

~/.config/awoc/        # AWOC configuration
├── resources/        # Agents, commands, scripts
├── backups/          # Automatic backups
└── config.json       # Global settings

~/projects/my-app/     # Your project
└── .claude/          # Project-specific AWOC
    ├── agents/
    ├── commands/
    └── settings.json
```

## 🔐 Safety & Control

- **Automatic Backups**: Every change is backed up
- **Easy Restoration**: `awoc restore -d .` to rollback
- **Non-Invasive**: No system files modified
- **Complete Removal**: `rm -rf ~/.config/awoc ~/.local/bin/awoc`
- **Project Isolation**: Each project is independent

## 🚦 Roadmap

### Available Now
- ✅ Claude Code integration
- ✅ 6 specialized agents
- ✅ Smart context management
- ✅ Project-specific deployment
- ✅ Automatic backups

### Coming Soon
- 🔄 Gemini support
- 🔄 Codex support
- 🔄 Custom agent builder
- 🔄 Cloud sync
- 🔄 Team sharing

## 🤝 Contributing

AWOC is open source and welcomes contributions:

1. Fork the repository
2. Create your feature branch
3. Test thoroughly with `awoc validate`
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE)

## 🙏 Credits

Created by Anthony Kougkas

---

**Ready to amplify your AI coding experience?**

```bash
# Install AWOC
curl -fsSL https://github.com/akougkas/awoc/raw/main/install.sh | bash

# Deploy to your project
cd ~/projects/my-app
awoc install -c claude -d .

# Start building with superpowers
```

Join the future of AI-assisted development with AWOC 2.0! 🚀