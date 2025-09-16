#!/usr/bin/env bash

# AWOC System Uninstaller
# Removes AWOC from ~/.awoc and optionally from Claude Code directories

set -euo pipefail

# Configuration
readonly AWOC_HOME="${AWOC_HOME:-$HOME/.awoc}"
readonly AWOC_BIN="${AWOC_HOME}/bin"
readonly AWOC_LIB="${AWOC_HOME}/lib"
readonly AWOC_BACKUPS="${AWOC_HOME}/backups"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}ℹ️${NC}  $*"; }
log_success() { echo -e "${GREEN}✅${NC} $*"; }
log_error() { echo -e "${RED}❌${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}⚠️${NC}  $*" >&2; }

# Check if AWOC is installed
check_installation() {
    if [[ ! -d "$AWOC_HOME" ]]; then
        log_error "AWOC is not installed at $AWOC_HOME"
        exit 1
    fi

    log_info "Found AWOC installation at: ${BOLD}$AWOC_HOME${NC}"

    # Show installation details
    if [[ -f "$AWOC_HOME/VERSION" ]]; then
        local version=$(jq -r '.version' "$AWOC_HOME/VERSION" 2>/dev/null)
        local installed=$(jq -r '.installed' "$AWOC_HOME/VERSION" 2>/dev/null)
        echo "  Version: $version"
        echo "  Installed: $installed"
    fi
}

# Find AWOC installations in Claude Code directories
find_awoc_installations() {
    log_info "Searching for AWOC installations..."

    local installations=()

    # Search common locations and projects
    while IFS= read -r awoc_file; do
        local dir=$(dirname "$awoc_file")
        installations+=("$dir")
    done < <(find ~ -name ".awoc" -type f 2>/dev/null | head -20)

    if [[ ${#installations[@]} -gt 0 ]]; then
        echo ""
        echo "Found AWOC in the following locations:"
        for dir in "${installations[@]}"; do
            local version=$(jq -r '.version' "$dir/.awoc" 2>/dev/null)
            echo "  • $dir (v$version)"
        done

        echo ""
        read -p "Remove AWOC from all locations? (y/N): " -r
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            for dir in "${installations[@]}"; do
                remove_awoc_from_directory "$dir"
            done
        fi
    else
        log_info "No AWOC installations found in Claude Code directories"
    fi
}

# Remove AWOC from a specific directory
remove_awoc_from_directory() {
    local target_dir="$1"

    log_info "Removing AWOC from: $target_dir"

    # Check for backup
    local backup_path=$(jq -r '.backup // "none"' "$target_dir/.awoc" 2>/dev/null)

    if [[ "$backup_path" != "none" ]] && [[ -d "$backup_path" ]]; then
        read -p "Restore original configuration from backup? (Y/n): " -r
        if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
            # Restore from backup
            rm -rf "$target_dir"/* 2>/dev/null || true
            cp -r "$backup_path"/* "$target_dir/" 2>/dev/null || true
            rm -f "$target_dir/.backup_info"
            log_success "Original configuration restored"
        fi
    fi

    # Remove AWOC files
    local awoc_files=(
        ".awoc"
        "settings.awoc.json"
        "agents/api-researcher.md"
        "agents/content-writer.md"
        "agents/creative-assistant.md"
        "agents/data-analyst.md"
        "agents/learning-assistant.md"
        "agents/project-manager.md"
        "commands/awoc-help.md"
        "commands/session-start.md"
        "commands/session-end.md"
        "output-styles/development.md"
    )

    for file in "${awoc_files[@]}"; do
        rm -f "$target_dir/$file" 2>/dev/null || true
    done

    # Remove AWOC scripts directory
    rm -rf "$target_dir/scripts" 2>/dev/null || true

    log_success "AWOC removed from $target_dir"
}

# Remove from shell configuration
remove_from_shell() {
    log_info "Removing AWOC from shell configuration..."

    local shell_configs=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.config/fish/config.fish"
    )

    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            # Remove AWOC PATH entries
            if grep -q "/.awoc/bin" "$config"; then
                # Create backup
                cp "$config" "$config.awoc-backup"

                # Remove AWOC lines
                sed -i '/# AWOC - Agentic Workflows Orchestration Cabinet/d' "$config"
                sed -i '/\.awoc\/bin/d' "$config"

                log_success "Removed from $config (backup: $config.awoc-backup)"
            fi
        fi
    done
}

# Show backups before deletion
show_backups() {
    if [[ -d "$AWOC_BACKUPS" ]]; then
        local backup_count=$(find "$AWOC_BACKUPS" -name ".backup_info" -type f 2>/dev/null | wc -l)

        if [[ $backup_count -gt 0 ]]; then
            echo ""
            log_warning "Found $backup_count backup(s) that will be deleted:"

            find "$AWOC_BACKUPS" -name ".backup_info" -type f | while read -r info_file; do
                local backup_dir=$(dirname "$info_file")
                local original=$(jq -r '.original_path' "$info_file" 2>/dev/null)
                local date=$(jq -r '.backup_date' "$info_file" 2>/dev/null)
                echo "  • $(basename "$backup_dir") - $original ($date)"
            done

            echo ""
            read -p "Delete all backups? (y/N): " -r
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                log_info "Preserving backups at: $AWOC_BACKUPS"
                return 1
            fi
        fi
    fi
    return 0
}

# Main uninstallation
main() {
    cat << EOF

╔══════════════════════════════════════════════════╗
║                                                  ║
║       🗑️  AWOC Uninstaller                      ║
║     Agentic Workflows Orchestration Cabinet     ║
║                                                  ║
╚══════════════════════════════════════════════════╝

${BOLD}This will remove AWOC from your system${NC}

EOF

    # Check installation
    check_installation

    # Find and optionally remove from Claude Code directories
    find_awoc_installations

    echo ""
    log_warning "This will completely remove AWOC from: ${BOLD}$AWOC_HOME${NC}"

    # Show backups
    local preserve_backups=false
    if ! show_backups; then
        preserve_backups=true
    fi

    read -p "Proceed with complete uninstallation? (yes/N): " -r
    echo

    if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi

    # Remove from shell configuration
    remove_from_shell

    # Remove AWOC home directory
    if [[ "$preserve_backups" == true ]]; then
        # Preserve backups, remove everything else
        find "$AWOC_HOME" -mindepth 1 -maxdepth 1 ! -name "backups" -exec rm -rf {} \;
        log_info "AWOC removed (backups preserved at $AWOC_BACKUPS)"
    else
        # Remove everything
        rm -rf "$AWOC_HOME"
        log_success "AWOC completely removed"
    fi

    cat << EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}✅ AWOC uninstalled successfully${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

Thank you for using AWOC!

To reinstall:
  ${BLUE}curl -fsSL https://github.com/akougkas/awoc/raw/main/install.sh | bash${NC}

Note: You may need to restart your shell or remove AWOC from PATH manually.

EOF
}

# Run uninstaller
main "$@"