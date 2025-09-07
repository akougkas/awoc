#!/bin/bash

# AWOC Uninstall Script
# Completely removes AWOC from the system

set -euo pipefail

# Configuration
LOG_FILE="${HOME}/.awoc-uninstall.log"
BACKUP_ON_UNINSTALL=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}" >&2
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO: $1"
}

# Detect installation location
detect_installation() {
    local install_locations=(
        "$HOME/.claude"
        "$HOME/.opencode"
        "$HOME/.gemini"
        "/usr/local/share/awoc"
        "/opt/awoc"
    )

    for location in "${install_locations[@]}"; do
        if [ -d "$location" ] && [ -f "$location/settings.json" ]; then
            echo "$location"
            return 0
        fi
    done

    return 1
}

# Create uninstall backup
create_uninstall_backup() {
    local install_dir="$1"
    local backup_name="awoc-uninstall-backup-$(date '+%Y%m%d_%H%M%S')"
    local backup_path="${HOME}/.awoc/uninstall-backups/$backup_name"

    info "Creating uninstall backup..."

    mkdir -p "$backup_path" 2>/dev/null || {
        warning "Cannot create backup directory"
        return 1
    }

    # Copy installation files
    if cp -r "$install_dir"/* "$backup_path/" 2>/dev/null; then
        success "Uninstall backup created: $backup_path"
        echo "$backup_path"
        return 0
    else
        warning "Failed to create uninstall backup"
        return 1
    fi
}

# Remove AWOC files
remove_awoc_files() {
    local install_dir="$1"
    local removed_files=0
    local total_files=0

    info "Removing AWOC files from: $install_dir"

    # List of files/directories to remove
    local awoc_files=(
        "settings.json"
        "agents/"
        "commands/"
        "output-styles/"
        "templates/"
        "scripts/"
        "docs/"
        "awoc"
        "install.sh"
        "validate.sh"
        "backup.sh"
        "uninstall.sh"
        ".awoc/"
    )

    # Count total files first
    for file in "${awoc_files[@]}"; do
        if [ -e "$install_dir/$file" ]; then
            if [ -d "$install_dir/$file" ]; then
                total_files=$((total_files + $(find "$install_dir/$file" -type f 2>/dev/null | wc -l || echo 0)))
            else
                ((total_files++))
            fi
        fi
    done

    info "Found $total_files AWOC files to remove"

    # Remove files
    for file in "${awoc_files[@]}"; do
        if [ -e "$install_dir/$file" ]; then
            if rm -rf "$install_dir/$file" 2>/dev/null; then
                if [ -d "$install_dir/$file" ]; then
                    local file_count=$(find "$install_dir/$file" -type f 2>/dev/null | wc -l 2>/dev/null || echo 0)
                    removed_files=$((removed_files + file_count))
                    success "Removed directory: $file ($file_count files)"
                else
                    ((removed_files++))
                    success "Removed file: $file"
                fi
            else
                warning "Failed to remove: $install_dir/$file"
            fi
        fi
    done

    success "Removed $removed_files AWOC files"
}

# Clean up system-wide files
cleanup_system_files() {
    info "Cleaning up system-wide files..."

    # Remove from PATH if installed globally
    local global_install_paths=(
        "/usr/local/bin/awoc"
        "/usr/bin/awoc"
        "/opt/bin/awoc"
    )

    for path in "${global_install_paths[@]}"; do
        if [ -L "$path" ] || [ -f "$path" ]; then
            if rm -f "$path" 2>/dev/null; then
                success "Removed global symlink: $path"
            fi
        fi
    done

    # Remove desktop entries if they exist
    local desktop_files=(
        "$HOME/.local/share/applications/awoc.desktop"
        "/usr/share/applications/awoc.desktop"
    )

    for desktop_file in "${desktop_files[@]}"; do
        if [ -f "$desktop_file" ]; then
            if rm -f "$desktop_file" 2>/dev/null; then
                success "Removed desktop entry: $desktop_file"
            fi
        fi
    done

    # Remove man pages if they exist
    local man_paths=(
        "/usr/local/share/man/man1/awoc.1"
        "/usr/share/man/man1/awoc.1"
    )

    for man_path in "${man_paths[@]}"; do
        if [ -f "$man_path" ]; then
            if rm -f "$man_path" 2>/dev/null; then
                success "Removed man page: $man_path"
            fi
        fi
    done
}

# Clean up user data
cleanup_user_data() {
    local keep_backups="${1:-true}"

    info "Cleaning up user data..."

    # Remove log files
    local log_files=(
        "$HOME/.awoc/backup.log"
        "$HOME/.awoc-uninstall.log"
        "$HOME/.awoc-install.log"
        "$HOME/.awoc-validation.log"
    )

    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            rm -f "$log_file" 2>/dev/null && success "Removed log file: $log_file"
        fi
    done

    # Handle backups directory
    local backups_dir="$HOME/.awoc"
    if [ -d "$backups_dir" ]; then
        if [ "$keep_backups" = "true" ]; then
            info "Keeping backups directory: $backups_dir"
            echo "You can manually remove it later with: rm -rf $backups_dir"
        else
            if rm -rf "$backups_dir" 2>/dev/null; then
                success "Removed backups directory: $backups_dir"
            else
                warning "Failed to remove backups directory"
            fi
        fi
    fi

    # Remove temporary files
    local temp_files=(
        "/tmp/awoc-*"
        "$HOME/.cache/awoc"
    )

    for temp_file in "${temp_files[@]}"; do
        if [ -e "$temp_file" ]; then
            rm -rf "$temp_file" 2>/dev/null && success "Removed temporary files: $temp_file"
        fi
    done
}

# Verify uninstallation
verify_uninstallation() {
    local install_dir="$1"

    info "Verifying uninstallation..."

    # Check for remaining AWOC files
    local remaining_files=()

    if [ -d "$install_dir" ]; then
        while IFS= read -r -d '' file; do
            case "$file" in
                *settings.json*|*agents/*|*commands/*|*output-styles/*|*awoc*)
                    remaining_files+=("$file")
                    ;;
            esac
        done < <(find "$install_dir" -type f -print0 2>/dev/null)
    fi

    if [ ${#remaining_files[@]} -gt 0 ]; then
        warning "Found ${#remaining_files[@]} remaining AWOC files:"
        printf '  %s\n' "${remaining_files[@]}"
        return 1
    else
        success "No AWOC files found - uninstallation successful"
        return 0
    fi
}

# Show uninstallation summary
show_summary() {
    local install_dir="$1"
    local backup_path="$2"

    echo ""
    echo -e "${BLUE}📋 Uninstallation Summary${NC}"
    echo "=========================="
    echo "Installation directory: $install_dir"
    if [ -n "$backup_path" ]; then
        echo "Uninstall backup: $backup_path"
    fi
    echo "Log file: $LOG_FILE"
    echo ""
    echo -e "${GREEN}✅ AWOC has been successfully uninstalled!${NC}"
    echo ""
    echo -e "${YELLOW}What was removed:${NC}"
    echo "  • AWOC core files and directories"
    echo "  • AWOC command wrapper"
    echo "  • System-wide symlinks (if any)"
    echo "  • Desktop entries (if any)"
    echo "  • Log files"
    echo ""
    if [ -n "$backup_path" ]; then
        echo -e "${YELLOW}To restore AWOC:${NC}"
        echo "  cp -r $backup_path/* $install_dir/"
        echo "  cd $install_dir && ./install.sh"
        echo ""
    fi
    echo -e "${YELLOW}To reinstall AWOC:${NC}"
    echo "  git clone <awoc-repo> $install_dir"
    echo "  cd $install_dir && ./install.sh"
}

# Interactive confirmation
confirm_uninstall() {
    echo ""
    echo -e "${RED}⚠️  WARNING: This will completely remove AWOC from your system!${NC}"
    echo ""
    echo "This action will:"
    echo "  • Remove all AWOC files and directories"
    echo "  • Delete the AWOC command wrapper"
    echo "  • Clean up system-wide installations"
    echo "  • Remove log files and temporary data"
    echo ""
    echo -e "${YELLOW}Note: Backups will be preserved unless you choose to remove them.${NC}"
    echo ""

    read -p "Are you sure you want to uninstall AWOC? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Uninstallation cancelled by user"
        exit 0
    fi

    if [ "$BACKUP_ON_UNINSTALL" = "true" ]; then
        read -p "Create a backup before uninstalling? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            BACKUP_ON_UNINSTALL=false
        fi
    fi
}

# Main uninstall function
main() {
    echo -e "${BLUE}🗑️  AWOC Uninstaller${NC}"
    echo "=================="

    # Initialize logging
    touch "$LOG_FILE" 2>/dev/null || warning "Cannot create log file: $LOG_FILE"
    log "AWOC Uninstallation started"

    # Detect installation
    local install_dir
    if ! install_dir=$(detect_installation); then
        error "AWOC installation not found. Nothing to uninstall."
    fi

    info "Found AWOC installation at: $install_dir"

    # Confirm uninstallation
    confirm_uninstall

    # Create backup if requested
    local backup_path=""
    if [ "$BACKUP_ON_UNINSTALL" = "true" ]; then
        if backup_path=$(create_uninstall_backup "$install_dir"); then
            log "Uninstall backup created: $backup_path"
        fi
    fi

    # Remove AWOC files
    remove_awoc_files "$install_dir"

    # Clean up system files
    cleanup_system_files

    # Clean up user data (keep backups by default)
    cleanup_user_data true

    # Verify uninstallation
    if verify_uninstallation "$install_dir"; then
        success "Uninstallation completed successfully"
    else
        warning "Some AWOC files may still remain"
    fi

    # Show summary
    show_summary "$install_dir" "$backup_path"

    log "AWOC Uninstallation completed"
}

# Run main function
main "$@"