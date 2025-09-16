#!/usr/bin/env bash

# AWOC Installation Script
# Installs AWOC to ~/.local/bin and ~/.config/awoc

set -euo pipefail

# Configuration
readonly AWOC_VERSION="2.0.0"
readonly AWOC_BIN_DIR="${HOME}/.local/bin"
readonly AWOC_CONFIG_DIR="${HOME}/.config/awoc"
readonly AWOC_RESOURCES="${AWOC_CONFIG_DIR}/resources"
readonly AWOC_BACKUPS="${AWOC_CONFIG_DIR}/backups"
readonly REPO_URL="https://github.com/akougkas/awoc"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Detect OS and shell
readonly OS="$(uname -s)"
readonly SHELL_NAME="$(basename "${SHELL}")"

# Logging
log_info() { echo -e "${BLUE}ℹ️${NC}  $*"; }
log_success() { echo -e "${GREEN}✅${NC} $*"; }
log_error() { echo -e "${RED}❌${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}⚠️${NC}  $*" >&2; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check OS compatibility
    case "$OS" in
        Linux|Darwin)
            log_success "Operating system: $OS"
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    # Check for required tools
    local missing_tools=()

    for tool in bash git; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install them and try again"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Download AWOC from GitHub
download_awoc() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    log_info "Downloading AWOC from GitHub..."

    # Try git clone first
    if command -v git &> /dev/null; then
        if ! git clone --depth 1 "$REPO_URL" "$temp_dir/awoc" 2>/dev/null; then
            log_error "Failed to clone repository"
            log_info "Trying alternative download method..."

            # Fallback to tarball download
            local tarball_url="${REPO_URL}/archive/main.tar.gz"
            if command -v curl &> /dev/null; then
                curl -L "$tarball_url" | tar -xz -C "$temp_dir"
                mv "$temp_dir"/awoc-main "$temp_dir/awoc"
            elif command -v wget &> /dev/null; then
                wget -qO- "$tarball_url" | tar -xz -C "$temp_dir"
                mv "$temp_dir"/awoc-main "$temp_dir/awoc"
            else
                log_error "No download tool available (git/curl/wget)"
                exit 1
            fi
        fi
    else
        log_error "Git is required for installation"
        exit 1
    fi

    echo "$temp_dir/awoc"
}

# Install AWOC
install_awoc() {
    local source_dir="$1"

    log_info "Installing AWOC..."

    # Create directory structure
    mkdir -p "$AWOC_BIN_DIR"
    mkdir -p "$AWOC_CONFIG_DIR"
    mkdir -p "$AWOC_RESOURCES"
    mkdir -p "$AWOC_BACKUPS"

    # Install CLI binary
    if [[ -f "$source_dir/awoc" ]]; then
        # Update paths in awoc script to use new locations
        sed -e "s|~/.awoc|${AWOC_CONFIG_DIR}|g" \
            -e "s|\$HOME/.awoc|${AWOC_CONFIG_DIR}|g" \
            -e "s|AWOC_HOME:-\$HOME/.awoc|AWOC_HOME:-${AWOC_CONFIG_DIR}|g" \
            "$source_dir/awoc" > "$AWOC_BIN_DIR/awoc"
        chmod +x "$AWOC_BIN_DIR/awoc"
        log_success "AWOC CLI installed to ${BOLD}~/.local/bin${NC}"
    else
        log_error "AWOC CLI script not found in repository"
        exit 1
    fi

    # Install resources
    log_info "Installing AWOC resources..."

    # Copy all resources
    for dir in agents commands output-styles scripts templates schemas; do
        if [[ -d "$source_dir/$dir" ]]; then
            cp -r "$source_dir/$dir" "$AWOC_RESOURCES/"
            log_success "Installed: $dir"
        fi
    done

    # Copy configuration files
    for file in settings.json; do
        if [[ -f "$source_dir/$file" ]]; then
            cp "$source_dir/$file" "$AWOC_RESOURCES/"
        fi
    done

    # Make scripts executable
    if [[ -d "$AWOC_RESOURCES/scripts" ]]; then
        chmod +x "$AWOC_RESOURCES"/scripts/*.sh 2>/dev/null || true
    fi

    # Create AWOC config
    cat > "$AWOC_CONFIG_DIR/config.json" << EOF
{
    "version": "$AWOC_VERSION",
    "installed": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "bin_dir": "$AWOC_BIN_DIR",
    "config_dir": "$AWOC_CONFIG_DIR",
    "resources_dir": "$AWOC_RESOURCES",
    "default_client": "claude",
    "trust_warnings": true
}
EOF

    log_success "AWOC resources installed to ${BOLD}~/.config/awoc${NC}"
}

# Setup PATH configuration
setup_path() {
    log_info "Setting up PATH configuration..."

    # Check if ~/.local/bin is already in PATH
    if echo "$PATH" | grep -q "$HOME/.local/bin"; then
        log_info "~/.local/bin already in PATH"
        return
    fi

    local shell_rc=""
    case "$SHELL_NAME" in
        bash)
            shell_rc="$HOME/.bashrc"
            ;;
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        fish)
            shell_rc="$HOME/.config/fish/config.fish"
            ;;
        *)
            shell_rc=""
            ;;
    esac

    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local fish_path_line='set -gx PATH $HOME/.local/bin $PATH'

    if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
        if ! grep -q "/.local/bin" "$shell_rc"; then
            log_info "Adding ~/.local/bin to PATH in $shell_rc"
            echo "" >> "$shell_rc"
            echo "# User-specific binaries" >> "$shell_rc"
            if [[ "$SHELL_NAME" == "fish" ]]; then
                echo "$fish_path_line" >> "$shell_rc"
            else
                echo "$path_line" >> "$shell_rc"
            fi
            log_success "PATH configuration updated"
        fi
    else
        log_warning "Could not determine shell configuration file"
        cat << EOF

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${YELLOW}⚠️  Manual PATH configuration required${NC}
${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

Add the following line to your shell configuration file:

${BOLD}$path_line${NC}

Then reload your shell configuration:
${BOLD}source ~/.bashrc${NC}  (or ~/.zshrc, etc.)

EOF
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    # Check if awoc is accessible
    if [[ -x "$AWOC_BIN_DIR/awoc" ]]; then
        log_success "AWOC CLI is installed"
        "$AWOC_BIN_DIR/awoc" version
    else
        log_error "AWOC CLI not found"
        exit 1
    fi

    # Check resources
    if [[ -d "$AWOC_RESOURCES" ]]; then
        local agent_count=$(find "$AWOC_RESOURCES/agents" -name "*.md" 2>/dev/null | wc -l)
        local cmd_count=$(find "$AWOC_RESOURCES/commands" -name "*.md" 2>/dev/null | wc -l)
        log_success "Found $agent_count agents and $cmd_count commands"
    else
        log_error "AWOC resources not found"
        exit 1
    fi
}

# Main installation flow
main() {
    cat << EOF

╔══════════════════════════════════════════════════╗
║                                                  ║
║     🚀 AWOC Installation v$AWOC_VERSION         ║
║     Agentic Workflows Orchestration Cabinet     ║
║                                                  ║
╚══════════════════════════════════════════════════╝

${BOLD}Installation locations:${NC}
  • CLI: ~/.local/bin/awoc
  • Config: ~/.config/awoc/
  • No sudo required!

EOF

    # Check if already installed
    if [[ -f "$AWOC_BIN_DIR/awoc" ]] || [[ -d "$AWOC_CONFIG_DIR" ]]; then
        log_warning "AWOC appears to be already installed"
        read -p "Do you want to reinstall/update? (y/N): " -r
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi

        # Backup existing installation
        if [[ -d "$AWOC_CONFIG_DIR" ]]; then
            local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
            local backup_dir="${AWOC_BACKUPS}/${backup_name}"
            log_info "Backing up existing installation..."
            mkdir -p "$backup_dir"
            cp -r "$AWOC_CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
            log_success "Backup created: $backup_dir"
        fi
    fi

    # Run installation steps
    check_prerequisites

    # Use local directory if running from repo, otherwise download
    if [[ -f "./awoc" ]] && [[ -d "./agents" ]]; then
        log_info "Installing from local repository..."
        install_awoc "."
    else
        local source_dir
        source_dir=$(download_awoc)
        install_awoc "$source_dir"
    fi

    setup_path
    verify_installation

    # Show success message
    cat << EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}✅ AWOC installed successfully!${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BOLD}Quick Start:${NC}

1. Reload your shell or run:
   ${BLUE}export PATH="\$HOME/.local/bin:\$PATH"${NC}

2. Create a new project:
   ${BLUE}mkdir -p ~/projects/my-project${NC}
   ${BLUE}cd ~/projects/my-project${NC}

3. Deploy AWOC to your project:
   ${BLUE}awoc install -c claude -d .${NC}

${BOLD}Commands:${NC}
  ${BLUE}awoc help${NC}                       - Show all commands
  ${BLUE}awoc install -c claude -d .${NC}     - Install to current project
  ${BLUE}awoc install -c claude -d ~/${NC}   - Install globally (not recommended)
  ${BLUE}awoc list${NC}                       - List available agents
  ${BLUE}awoc uninstall -d .${NC}             - Remove AWOC from project

${BOLD}Installation complete:${NC}
  • CLI: ${BOLD}~/.local/bin/awoc${NC}
  • Config: ${BOLD}~/.config/awoc/${NC}
  • Backups: ${BOLD}~/.config/awoc/backups/${NC}

Documentation: ${REPO_URL}

EOF

    # Check if PATH needs manual configuration
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        log_warning "Don't forget to reload your shell or add ~/.local/bin to PATH!"
    fi
}

# Run main installation
main "$@"