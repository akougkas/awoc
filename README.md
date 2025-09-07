# AWOC - Agentic Workflows Orchestration Cabinet

**AWOC** is a lightweight, developer-first framework for orchestrating AI agents in Claude Code, OpenCode, and Gemini CLI environments. Designed for professional developers who want predictable, efficient AI collaboration without the complexity.

## Quick Start

```bash
# Clone and setup
git clone <your-repo-url> ~/.awoc
cd ~/.awoc

# Initialize your project
awoc init

# Start working
awoc session start "Building a FastAPI service"
```

## Philosophy

AWOC follows **incremental development** principles:
- Start with what works today
- Add complexity only when needed
- Focus on developer experience
- Keep it simple, make it reliable

## Core Features

- **Single Agent Focus**: One agent per task type
- **Session Management**: Clean start/end workflows
- **Tool Integration**: Real MCP server support
- **Security First**: Granular permissions model
- **Git Native**: Works with your existing workflow

## Project Status

🚧 **Early Development** - Currently in MVP phase with core functionality.

### Roadmap
- [x] Basic agent framework
- [x] Session management
- [ ] Multi-agent orchestration
- [ ] Advanced tool integrations
- [ ] Plugin ecosystem

## Installation

### Automatic Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/awoc.git ~/.awoc

# Run the installer
cd ~/.awoc && ./install.sh
```

The installer will automatically detect your CLI environment (Claude Code, OpenCode, or Gemini CLI) and install AWOC appropriately.

### Manual Installation

```bash
# For Claude Code users
cp -r awoc ~/.claude/

# For OpenCode users
cp -r awoc ~/.opencode/

# For Gemini CLI users
cp -r awoc ~/.gemini/
```

## Usage

```bash
# Initialize in a project
awoc init

# Start a development session
awoc session start "Implementing user authentication"

# End session with summary
awoc session end "Completed OAuth2 integration with tests"
```

## Contributing

This is an open-source project designed for the developer community. Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - Free for personal and commercial use.