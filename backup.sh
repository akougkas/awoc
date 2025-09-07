#!/bin/bash

# AWOC Backup and Recovery Script
# Manages configuration backups and system recovery

set -euo pipefail

# Configuration
BACKUP_ROOT="${HOME}/.awoc/backups"
LOG_FILE="${HOME}/.awoc/backup.log"
MAX_BACKUPS=10

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

# Initialize backup system
init_backup_system() {
    mkdir -p "$BACKUP_ROOT" 2>/dev/null || error "Cannot create backup directory: $BACKUP_ROOT"
    touch "$LOG_FILE" 2>/dev/null || warning "Cannot create log file: $LOG_FILE"
    log "AWOC Backup system initialized"
}

# Generate backup filename
generate_backup_name() {
    echo "awoc-backup-$(date '+%Y%m%d_%H%M%S')"
}

# Create backup
create_backup() {
    local backup_name="${1:-$(generate_backup_name)}"
    local backup_path="$BACKUP_ROOT/$backup_name"

    info "Creating backup: $backup_name"

    # Create backup directory
    mkdir -p "$backup_path" 2>/dev/null || error "Cannot create backup path: $backup_path"

    # Backup metadata
    cat > "$backup_path/backup-info.json" << EOF
{
  "name": "$backup_name",
  "created": "$(date '+%Y-%m-%dT%H:%M:%S%z')",
  "awoc_version": "$(grep '"version"' settings.json | cut -d'"' -f4 2>/dev/null || echo "unknown")",
  "system": "$(uname -s)",
  "user": "$(whoami)",
  "working_directory": "$(pwd)"
}
EOF

    # Backup core files
    local files_to_backup=(
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
    )

    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ]; then
            if [ -d "$file" ]; then
                cp -r "$file" "$backup_path/" 2>/dev/null && success "Backed up directory: $file" || warning "Failed to backup directory: $file"
            else
                cp "$file" "$backup_path/" 2>/dev/null && success "Backed up file: $file" || warning "Failed to backup file: $file"
            fi
        else
            warning "File/directory not found for backup: $file"
        fi
    done

    # Create backup manifest
    cat > "$backup_path/manifest.txt" << EOF
AWOC Backup Manifest
====================
Backup Name: $backup_name
Created: $(date)
Location: $backup_path

Contents:
$(ls -la "$backup_path")

System Information:
- OS: $(uname -s)
- User: $(whoami)
- Working Directory: $(pwd)
- AWOC Version: $(grep '"version"' settings.json 2>/dev/null | cut -d'"' -f4 || echo "unknown")

To restore this backup, run:
  ./backup.sh restore $backup_name
EOF

    # Compress backup for storage efficiency
    info "Compressing backup..."
    if command -v tar >/dev/null 2>&1; then
        cd "$BACKUP_ROOT" && tar -czf "${backup_name}.tar.gz" "$backup_name" 2>/dev/null && \
        rm -rf "$backup_name" && \
        success "Backup compressed: ${backup_name}.tar.gz" || \
        warning "Failed to compress backup"
    else
        warning "tar not available - backup not compressed"
    fi

    success "Backup created successfully: $backup_name"
    log "Backup created: $backup_name at $backup_path"
}

# List available backups
list_backups() {
    info "Available backups:"

    if [ ! -d "$BACKUP_ROOT" ]; then
        warning "No backup directory found"
        return
    fi

    local count=0
    for backup in "$BACKUP_ROOT"/*; do
        if [ -d "$backup" ] || [[ "$backup" == *.tar.gz ]]; then
            ((count++))
            local backup_name=$(basename "$backup")
            local backup_info=""

            # Try to get backup info
            if [ -f "$backup/backup-info.json" ]; then
                backup_info=$(jq -r '"Created: \(.created) | Version: \(.awoc_version)"' "$backup/backup-info.json" 2>/dev/null || echo "")
            elif [[ "$backup" == *.tar.gz ]]; then
                backup_info="Compressed archive"
            fi

            echo "  $count. $backup_name"
            [ -n "$backup_info" ] && echo "     $backup_info"
            echo ""
        fi
    done

    if [ $count -eq 0 ]; then
        warning "No backups found"
    else
        success "Found $count backup(s)"
    fi
}

# Restore from backup
restore_backup() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        error "Backup name required for restore"
    fi

    local backup_path="$BACKUP_ROOT/$backup_name"
    local compressed_backup="$BACKUP_ROOT/${backup_name}.tar.gz"

    # Check if backup exists
    if [ -d "$backup_path" ]; then
        info "Found uncompressed backup: $backup_name"
    elif [ -f "$compressed_backup" ]; then
        info "Found compressed backup: $backup_name"
        # Decompress backup
        cd "$BACKUP_ROOT" && tar -xzf "${backup_name}.tar.gz" 2>/dev/null || error "Failed to decompress backup"
    else
        error "Backup not found: $backup_name"
    fi

    # Confirm restore
    echo ""
    warning "This will overwrite existing AWOC files!"
    read -p "Are you sure you want to restore from '$backup_name'? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Restore cancelled"
        exit 0
    fi

    # Create pre-restore backup
    info "Creating pre-restore backup..."
    create_backup "pre-restore-$(date '+%Y%m%d_%H%M%S')"

    # Restore files
    info "Restoring from backup: $backup_name"

    local files_to_restore=(
        "settings.json"
        "agents/"
        "commands/"
        "output-styles/"
        "templates/"
        "scripts/"
        "docs/"
        "awoc"
    )

    for file in "${files_to_restore[@]}"; do
        if [ -e "$backup_path/$file" ]; then
            if [ -d "$backup_path/$file" ]; then
                cp -r "$backup_path/$file" . 2>/dev/null && success "Restored directory: $file" || warning "Failed to restore directory: $file"
            else
                cp "$backup_path/$file" . 2>/dev/null && success "Restored file: $file" || warning "Failed to restore file: $file"
            fi
        else
            warning "File not found in backup: $file"
        fi
    done

    success "Restore completed from: $backup_name"
    log "Restored from backup: $backup_name"

    # Validate restoration
    info "Validating restoration..."
    if [ -f "validate.sh" ] && [ -x "validate.sh" ]; then
        ./validate.sh
    else
        warning "Cannot validate restoration - validate.sh not available"
    fi
}

# Clean old backups
clean_backups() {
    local keep_count="${1:-$MAX_BACKUPS}"

    if [ ! -d "$BACKUP_ROOT" ]; then
        warning "No backup directory found"
        return
    fi

    info "Cleaning old backups (keeping $keep_count most recent)..."

    # Get list of backups sorted by modification time (newest first)
    local backups=($(ls -t "$BACKUP_ROOT" 2>/dev/null | grep -E '(awoc-backup|pre-restore)' | head -n "$keep_count"))

    # Remove old backups
    local removed=0
    for backup in "$BACKUP_ROOT"/*; do
        if [ -e "$backup" ]; then
            local backup_name=$(basename "$backup")
            local should_keep=false

            for keep_backup in "${backups[@]}"; do
                if [[ "$backup_name" == "$keep_backup"* ]]; then
                    should_keep=true
                    break
                fi
            done

            if [ "$should_keep" = false ]; then
                rm -rf "$backup" 2>/dev/null && ((removed++)) && log "Removed old backup: $backup_name" || warning "Failed to remove: $backup_name"
            fi
        fi
    done

    if [ $removed -gt 0 ]; then
        success "Cleaned up $removed old backup(s)"
    else
        info "No old backups to clean"
    fi
}

# Show backup information
show_info() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        # Show general backup system info
        echo "AWOC Backup System Information"
        echo "=============================="
        echo "Backup Root: $BACKUP_ROOT"
        echo "Log File: $LOG_FILE"
        echo "Max Backups: $MAX_BACKUPS"
        echo ""

        if [ -d "$BACKUP_ROOT" ]; then
            local backup_count=$(find "$BACKUP_ROOT" -maxdepth 1 \( -type d -o -name "*.tar.gz" \) | wc -l)
            echo "Current Backups: $((backup_count - 1))"  # Subtract 1 for the root directory
            echo "Disk Usage: $(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)"
        else
            echo "Status: Backup system not initialized"
        fi
        return
    fi

    # Show specific backup info
    local backup_path="$BACKUP_ROOT/$backup_name"

    if [ -f "$backup_path/backup-info.json" ]; then
        echo "Backup Information: $backup_name"
        echo "=================================="
        jq . "$backup_path/backup-info.json" 2>/dev/null || cat "$backup_path/backup-info.json"
    elif [ -f "$backup_path/manifest.txt" ]; then
        cat "$backup_path/manifest.txt"
    else
        error "Backup information not found for: $backup_name"
    fi
}

# Show usage
usage() {
    echo "AWOC Backup and Recovery Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create [name]     Create a new backup (optional custom name)"
    echo "  list              List all available backups"
    echo "  restore <name>    Restore from specified backup"
    echo "  clean [count]     Clean old backups (default: keep $MAX_BACKUPS)"
    echo "  info [name]       Show backup system or specific backup information"
    echo "  help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create                    # Create backup with auto-generated name"
    echo "  $0 create my-backup         # Create backup with custom name"
    echo "  $0 list                     # List all backups"
    echo "  $0 restore awoc-backup-20231201_120000  # Restore specific backup"
    echo "  $0 clean 5                  # Keep only 5 most recent backups"
    echo "  $0 info                     # Show backup system information"
    echo "  $0 info my-backup           # Show specific backup details"
}

# Main script
main() {
    init_backup_system

    case "${1:-help}" in
        create)
            create_backup "${2:-}"
            ;;
        list)
            list_backups
            ;;
        restore)
            if [ -z "${2:-}" ]; then
                error "Backup name required for restore. Use '$0 list' to see available backups."
            fi
            restore_backup "$2"
            ;;
        clean)
            clean_backups "${2:-$MAX_BACKUPS}"
            ;;
        info)
            show_info "${2:-}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: ${1:-}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"