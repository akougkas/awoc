#!/bin/bash

# AWOC Installation Script
# Installs AWOC framework for Claude Code, OpenCode, or Gemini CLI

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="${HOME}/.awoc-install.log"
BACKUP_DIR="${HOME}/.awoc-backup-$(date +%Y%m%d_%H%M%S)"

# Error handling function
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    echo "$(date): ERROR - $1" >> "$LOG_FILE"
    # Attempt cleanup on error
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Attempting to restore from backup...${NC}"
        restore_backup
    fi
    exit 1
}

# Warning function
warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}" >&2
    echo "$(date): WARNING - $1" >> "$LOG_FILE"
}

# Success function
success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "$(date): SUCCESS - $1" >> "$LOG_FILE"
}

# Info function
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    echo "$(date): INFO - $1" >> "$LOG_FILE"
}

# Backup existing installation
create_backup() {
    if [ -d "$TARGET_DIR/awoc" ]; then
        info "Creating backup of existing AWOC installation..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$TARGET_DIR/awoc" "$BACKUP_DIR/" 2>/dev/null || warning "Failed to backup some files"
        success "Backup created at $BACKUP_DIR"
    fi
}

# Restore from backup
restore_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        info "Restoring from backup..."
        cp -r "$BACKUP_DIR/awoc" "$TARGET_DIR/" 2>/dev/null || error_exit "Failed to restore backup"
        success "Backup restored successfully"
    fi
}

# Check system requirements
check_requirements() {
    info "Checking system requirements..."

    # Check if running on supported OS
    case "$(uname -s)" in
        Linux|Darwin)
            success "Supported operating system detected"
            ;;
        *)
            error_exit "Unsupported operating system: $(uname -s)"
            ;;
    esac

    # Check available disk space (need at least 10MB)
    local available_space
    available_space=$(df -m "$HOME" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 10 ]; then
        error_exit "Insufficient disk space. Need at least 10MB available."
    fi

    # Check if target directory is writable
    if [ ! -w "$(dirname "$TARGET_DIR")" ]; then
        error_exit "Cannot write to target directory: $(dirname "$TARGET_DIR")"
    fi
}

# Detect CLI environment
detect_cli() {
    info "Detecting CLI environment..."

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
        warning "No CLI directory found. Creating ~/.claude by default."
        TARGET_DIR="$HOME/.claude"
        CLI_NAME="Claude Code"
    fi

    success "Detected $CLI_NAME environment"
}

# Initialize logging
init_logging() {
    touch "$LOG_FILE" 2>/dev/null || warning "Cannot create log file at $LOG_FILE"
    echo "$(date): AWOC Installation started" >> "$LOG_FILE"
}

# Main installation function
main() {
    echo -e "${GREEN}🚀 Installing AWOC - Agentic Workflows Orchestration Cabinet${NC}"
    echo "Installation log: $LOG_FILE"

    # Initialize
    init_logging
    detect_cli
    check_requirements

    # Create target directory if it doesn't exist
    mkdir -p "$TARGET_DIR" 2>/dev/null || error_exit "Failed to create target directory: $TARGET_DIR"

    # Backup existing installation
    create_backup

    # Copy AWOC files with error handling
    info "Installing AWOC files to $TARGET_DIR"
    if ! cp -r . "$TARGET_DIR/" 2>>"$LOG_FILE"; then
        error_exit "Failed to copy AWOC files to $TARGET_DIR"
    fi

    # Create awoc command wrapper with error handling
    info "Creating AWOC command wrapper..."
    cat > "$TARGET_DIR/awoc" << 'EOF' || error_exit "Failed to create AWOC command wrapper"
#!/bin/bash
# AWOC command wrapper

AWOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Error handling for wrapper
error() {
    echo "Error: $1" >&2
    exit 1
}

case "$1" in
    "init")
        if [ ! -f "settings.json" ]; then
            echo "Initializing AWOC in $(pwd)"
            # Copy default settings to project if needed
            cp "$AWOC_DIR/settings.json" "./awoc-settings.json" 2>/dev/null || error "Failed to copy settings"
        else
            echo "AWOC already initialized in $(pwd)"
        fi
        ;;
    "session")
        case "$2" in
            "start")
                [ -z "${3:-}" ] && error "Session description required"
                echo "Starting session: ${@:3}"
                ;;
            "end")
                [ -z "${3:-}" ] && error "Session summary required"
                echo "Ending session: ${@:3}"
                ;;
            *)
                error "Usage: awoc session {start|end} [description]"
                ;;
        esac
        ;;
    "validate")
        if [ -f "$AWOC_DIR/validate.sh" ]; then
            bash "$AWOC_DIR/validate.sh"
        else
            error "Validation script not found"
        fi
        ;;
    "backup")
        BACKUP_PATH="${HOME}/.awoc-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_PATH"
        cp -r "$AWOC_DIR"/* "$BACKUP_PATH/" 2>/dev/null
        echo "AWOC backed up to: $BACKUP_PATH"
        ;;
    "help"|*)
        echo "AWOC - Agentic Workflows Orchestration Cabinet"
        echo ""
        echo "Usage:"
        echo "  awoc init                    Initialize AWOC in current project"
        echo "  awoc session start [desc]    Start development session"
        echo "  awoc session end [desc]      End development session"
        echo "  awoc validate               Validate AWOC installation"
        echo "  awoc backup                 Create backup of AWOC installation"
        echo "  awoc help                   Show this help"
        echo ""
        echo "For more information, see: $AWOC_DIR/README.md"
        ;;
esac
EOF

    chmod +x "$TARGET_DIR/awoc" 2>/dev/null || error_exit "Failed to make AWOC command executable"

    # Validate installation
    info "Validating installation..."
    if [ ! -f "$TARGET_DIR/settings.json" ]; then
        error_exit "Settings file not found after installation"
    fi

    if [ ! -x "$TARGET_DIR/awoc" ]; then
        error_exit "AWOC command not executable"
    fi

    # Test basic functionality
    if ! "$TARGET_DIR/awoc" help >/dev/null 2>&1; then
        warning "AWOC command test failed - may not work correctly"
    fi

    success "AWOC installed successfully!"
    echo ""
    echo -e "${YELLOW}Installation Details:${NC}"
    echo "📁 Installed to: $TARGET_DIR"
    echo "📝 Log file: $LOG_FILE"
    if [ -d "$BACKUP_DIR" ]; then
        echo "💾 Backup created: $BACKUP_DIR"
    fi
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Restart your $CLI_NAME session"
    echo "2. Run 'awoc init' in your project directory"
    echo "3. Run 'awoc validate' to verify installation"
    echo "4. Start with 'awoc session start \"Your task description\"'"
    echo ""
    echo -e "${GREEN}Happy coding with AWOC! 🎉${NC}"

    # Final log entry
    echo "$(date): AWOC Installation completed successfully" >> "$LOG_FILE"
}

# Trap errors
trap 'error_exit "Installation failed with error code $?"' ERR

# Run main installation
main "$@"