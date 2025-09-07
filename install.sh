#!/bin/bash

# AWOC Installation Script
# Installs AWOC framework for Claude Code, OpenCode, or Gemini CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Installing AWOC - Agentic Workflows Orchestration Cabinet${NC}"

# Detect CLI environment
if [ -d "$HOME/.claude" ]; then
    TARGET_DIR="$HOME/.claude"
    CLI_NAME="Claude Code"
elif [ -d "$HOME/.opencode" ]; then
    TARGET_DIR="$HOME/.opencode"
    CLI_NAME="OpenCode"
elif [ -d "$HOME/.gemini" ]; then
    TARGET_DIR="$HOME/.gemini"
    CLI_NAME="Gemini CLI"
else
    echo -e "${YELLOW}No CLI directory found. Creating ~/.claude by default.${NC}"
    TARGET_DIR="$HOME/.claude"
    CLI_NAME="Claude Code"
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy AWOC files
echo "📁 Installing to $TARGET_DIR"
cp -r * "$TARGET_DIR/"

# Create awoc command wrapper
cat > "$TARGET_DIR/awoc" << 'EOF'
#!/bin/bash
# AWOC command wrapper

AWOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$1" in
    "init")
        echo "AWOC initialized in $(pwd)"
        # Copy settings to project if needed
        ;;
    "session")
        case "$2" in
            "start")
                echo "Starting session: ${@:3}"
                ;;
            "end")
                echo "Ending session: ${@:3}"
                ;;
            *)
                echo "Usage: awoc session {start|end} [description]"
                ;;
        esac
        ;;
    "help"|*)
        echo "AWOC - Agentic Workflows Orchestration Cabinet"
        echo ""
        echo "Usage:"
        echo "  awoc init                    Initialize AWOC in current project"
        echo "  awoc session start [desc]    Start development session"
        echo "  awoc session end [desc]      End development session"
        echo "  awoc help                    Show this help"
        ;;
esac
EOF

chmod +x "$TARGET_DIR/awoc"

echo -e "${GREEN}✅ AWOC installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Restart your $CLI_NAME session"
echo "2. Run 'awoc init' in your project directory"
echo "3. Start with 'awoc session start \"Your task description\"'"
echo ""
echo -e "${GREEN}Happy coding with AWOC! 🎉${NC}"