#!/bin/bash

# AWOC Logging System
# Centralized logging for all AWOC operations

set -euo pipefail

# Configuration
LOG_DIR="${HOME}/.awoc/logs"
LOG_FILE="${LOG_DIR}/awoc.log"
MAX_LOG_SIZE="10M"
MAX_LOG_FILES=5
LOG_LEVEL="${AWOC_LOG_LEVEL:-INFO}"

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log levels
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARNING"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

# Initialize logging system
init_logging() {
    # Create log directory
    mkdir -p "$LOG_DIR" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Warning: Cannot create log directory: $LOG_DIR${NC}" >&2
        return 1
    }

    # Create log file if it doesn't exist
    touch "$LOG_FILE" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Warning: Cannot create log file: $LOG_FILE${NC}" >&2
        return 1
    }

    # Rotate logs if needed
    rotate_logs

    return 0
}

# Rotate log files
rotate_logs() {
    # Check if log file exists and is too large
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        local log_size
        log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

        # Convert MAX_LOG_SIZE to bytes
        local max_size_bytes
        case "$MAX_LOG_SIZE" in
            *M) max_size_bytes=$(( ${MAX_LOG_SIZE%M} * 1024 * 1024 )) ;;
            *K) max_size_bytes=$(( ${MAX_LOG_SIZE%K} * 1024 )) ;;
            *) max_size_bytes="$MAX_LOG_SIZE" ;;
        esac

        if [ "$log_size" -gt "$max_size_bytes" ]; then
            # Rotate existing log files
            for ((i=MAX_LOG_FILES; i>=1; i--)); do
                if [ -f "${LOG_FILE}.$i" ]; then
                    if [ $i -eq $MAX_LOG_FILES ]; then
                        rm -f "${LOG_FILE}.$i"
                    else
                        mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
                    fi
                fi
            done

            # Move current log file
            mv "$LOG_FILE" "${LOG_FILE}.1"
            touch "$LOG_FILE"
        fi
    fi
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Check if log level should be logged
should_log() {
    local level="$1"
    local current_level_num=${LOG_LEVELS[$LOG_LEVEL]:-1}
    local message_level_num=${LOG_LEVELS[$level]:-1}

    [ $message_level_num -ge $current_level_num ]
}

# Core logging function
log_message() {
    local level="$1"
    local message="$2"
    local component="${3:-AWOC}"
    local timestamp
    timestamp=$(get_timestamp)

    # Format log message
    local log_entry="$timestamp [$level] [$component] $message"

    # Write to log file
    echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true

    # Output to console if level is appropriate
    if should_log "$level"; then
        case "$level" in
            "DEBUG") echo -e "${BLUE}🐛 $message${NC}" >&2 ;;
            "INFO") echo -e "${GREEN}ℹ️  $message${NC}" >&2 ;;
            "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" >&2 ;;
            "ERROR") echo -e "${RED}❌ $message${NC}" >&2 ;;
            "CRITICAL") echo -e "${RED}🚨 $message${NC}" >&2 ;;
        esac
    fi
}

# Public logging functions
log_debug() {
    log_message "DEBUG" "$1" "${2:-AWOC}"
}

log_info() {
    log_message "INFO" "$1" "${2:-AWOC}"
}

log_warning() {
    log_message "WARNING" "$1" "${2:-AWOC}"
}

log_error() {
    log_message "ERROR" "$1" "${2:-AWOC}"
}

log_critical() {
    log_message "CRITICAL" "$1" "${2:-AWOC}"
}

# Log with context
log_with_context() {
    local level="$1"
    local message="$2"
    local component="$3"
    local context="$4"

    local full_message="$message"
    if [ -n "$context" ]; then
        full_message="$message | Context: $context"
    fi

    log_message "$level" "$full_message" "$component"
}

# Log command execution
log_command() {
    local command="$1"
    local result="$2"
    local component="${3:-AWOC}"

    if [ "$result" -eq 0 ]; then
        log_info "Command executed successfully: $command" "$component"
    else
        log_error "Command failed (exit code: $result): $command" "$component"
    fi
}

# Log file operations
log_file_operation() {
    local operation="$1"
    local file="$2"
    local result="$3"
    local component="${4:-AWOC}"

    if [ "$result" -eq 0 ]; then
        log_debug "File $operation successful: $file" "$component"
    else
        log_warning "File $operation failed: $file" "$component"
    fi
}

# Log performance metrics
log_performance() {
    local operation="$1"
    local duration="$2"
    local component="${3:-AWOC}"

    log_debug "Performance: $operation took ${duration}ms" "$component"
}

# Show log files
show_logs() {
    local lines="${1:-50}"
    local level="${2:-}"

    echo "AWOC Log Files"
    echo "=============="
    echo "Log Directory: $LOG_DIR"
    echo "Main Log File: $LOG_FILE"
    echo ""

    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file found."
        return
    fi

    echo "Recent Log Entries:"
    echo "-------------------"

    if [ -n "$level" ]; then
        tail -n "$lines" "$LOG_FILE" | grep -i "$level" || echo "No $level entries found."
    else
        tail -n "$lines" "$LOG_FILE"
    fi
}

# Clean log files
clean_logs() {
    local days="${1:-30}"

    echo "Cleaning log files older than $days days..."

    # Remove old rotated logs
    find "$LOG_DIR" -name "awoc.log.*" -mtime +"$days" -delete 2>/dev/null || true

    # Truncate main log file if it's too old
    if [ -f "$LOG_FILE" ]; then
        local file_age
        file_age=$(find "$LOG_FILE" -mtime +"$days" 2>/dev/null | wc -l)
        if [ "$file_age" -gt 0 ]; then
            echo "" > "$LOG_FILE"
            log_info "Main log file truncated (older than $days days)"
        fi
    fi

    log_info "Log cleanup completed"
}

# Get log statistics
get_log_stats() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file found."
        return
    fi

    echo "AWOC Log Statistics"
    echo "==================="
    echo "Log File: $LOG_FILE"
    echo "Size: $(ls -lh "$LOG_FILE" | awk '{print $5}')"
    echo "Last Modified: $(stat -c%y "$LOG_FILE" 2>/dev/null || stat -f%Sm "$LOG_FILE" 2>/dev/null || echo "Unknown")"
    echo ""

    echo "Entries by Level:"
    for level in DEBUG INFO WARNING ERROR CRITICAL; do
        count=$(grep -c "\[$level\]" "$LOG_FILE" 2>/dev/null || echo 0)
        echo "  $level: $count"
    done

    echo ""
    echo "Recent Activity:"
    echo "----------------"
    tail -n 10 "$LOG_FILE" | while read -r line; do
        echo "  $line"
    done
}

# Export logs
export_logs() {
    local output_file="${1:-awoc-logs-$(date '+%Y%m%d_%H%M%S').tar.gz}"

    if [ ! -d "$LOG_DIR" ]; then
        echo "No log directory found to export."
        return 1
    fi

    echo "Exporting logs to: $output_file"

    if command -v tar >/dev/null 2>&1; then
        cd "$(dirname "$LOG_DIR")" && tar -czf "$output_file" "$(basename "$LOG_DIR")" 2>/dev/null
        echo "Logs exported successfully to: $output_file"
        log_info "Logs exported to: $output_file"
    else
        echo "tar command not available. Cannot create compressed export."
        return 1
    fi
}

# Usage information
usage() {
    echo "AWOC Logging System"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init              Initialize logging system"
    echo "  debug <message>   Log debug message"
    echo "  info <message>    Log info message"
    echo "  warning <message> Log warning message"
    echo "  error <message>   Log error message"
    echo "  critical <message> Log critical message"
    echo "  show [lines]      Show recent log entries (default: 50)"
    echo "  show [lines] [level] Show log entries filtered by level"
    echo "  stats             Show log statistics"
    echo "  clean [days]      Clean logs older than days (default: 30)"
    echo "  export [file]     Export logs to compressed file"
    echo "  help              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 info 'AWOC started successfully'"
    echo "  $0 show 100 ERROR"
    echo "  $0 clean 7"
    echo "  $0 export my-logs.tar.gz"
    echo ""
    echo "Configuration:"
    echo "  LOG_DIR: $LOG_DIR"
    echo "  LOG_FILE: $LOG_FILE"
    echo "  MAX_LOG_SIZE: $MAX_LOG_SIZE"
    echo "  LOG_LEVEL: $LOG_LEVEL"
}

# Main function
main() {
    case "${1:-help}" in
        init)
            if init_logging; then
                log_info "Logging system initialized"
                echo "Logging system initialized successfully"
            else
                echo "Failed to initialize logging system" >&2
                exit 1
            fi
            ;;
        debug|info|warning|error|critical)
            if [ -z "${2:-}" ]; then
                echo "Error: Message required for $1 logging" >&2
                exit 1
            fi
            "log_$1" "$2" "${3:-AWOC}"
            ;;
        show)
            show_logs "${2:-50}" "${3:-}"
            ;;
        stats)
            get_log_stats
            ;;
        clean)
            clean_logs "${2:-30}"
            ;;
        export)
            export_logs "${2:-}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: ${1:-}" >&2
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi