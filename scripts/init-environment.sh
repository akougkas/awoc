#!/bin/bash

# AWOC Environment Initialization
# Sets up required directories and environment variables for AWOC 2.0

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/logging.sh" ]; then
    # shellcheck source=./logging.sh
    source "$SCRIPT_DIR/logging.sh"
    init_logging
else
    log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"; }
    log_warning() { echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }
    log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }
fi

# Configuration - Dynamic PROJECT_ROOT detection
if [ -n "${PROJECT_ROOT:-}" ]; then
    # Use provided PROJECT_ROOT if set
    PROJECT_ROOT="$PROJECT_ROOT"
elif [ -f "${SCRIPT_DIR}/../settings.json" ]; then
    # Derive from script location (scripts/ directory)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    # Fallback: try to find settings.json upwards
    current_dir="$SCRIPT_DIR"
    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/settings.json" ]; then
            PROJECT_ROOT="$current_dir"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done

    # Final fallback
    if [ -z "${PROJECT_ROOT:-}" ]; then
        log_error "Cannot determine PROJECT_ROOT. Please set PROJECT_ROOT environment variable or ensure settings.json exists."
        exit 1
    fi
fi
AWOC_HOME="${HOME}/.awoc"

# Required directories
declare -a REQUIRED_DIRS=(
    "${AWOC_HOME}"
    "${AWOC_HOME}/handoffs"
    "${AWOC_HOME}/handoffs/active" 
    "${AWOC_HOME}/handoffs/archive"
    "${AWOC_HOME}/handoffs/emergency"
    "${AWOC_HOME}/context"
    "${AWOC_HOME}/intelligence"
    "${AWOC_HOME}/intelligence/patterns"
    "${AWOC_HOME}/intelligence/models"
    "${AWOC_HOME}/intelligence/predictions"
    "${AWOC_HOME}/cache"
    "${AWOC_HOME}/logs"
    "${AWOC_HOME}/sessions"
)

# Initialize environment
init_awoc_environment() {
    log_info "Initializing AWOC environment"
    
    # Create required directories
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            if mkdir -p "$dir" 2>/dev/null; then
                log_info "Created directory: $dir"
            else
                log_error "Failed to create directory: $dir"
                return 1
            fi
        else
            log_info "Directory exists: $dir"
        fi
    done
    
    # Set proper permissions
    chmod 750 "${AWOC_HOME}" 2>/dev/null || true
    chmod -R 750 "${AWOC_HOME}"/{handoffs,context,intelligence} 2>/dev/null || true
    
    # Create initial configuration files
    create_initial_configs
    
    # Validate environment
    validate_environment
    
    log_info "AWOC environment initialization completed"
    return 0
}

# Create initial configuration files
create_initial_configs() {
    log_info "Creating initial configuration files"
    
    # Context monitoring configuration
    local context_config="${AWOC_HOME}/context/monitor.json"
    if [ ! -f "$context_config" ]; then
        cat > "$context_config" << 'EOF'
{
  "version": "1.3.0",
  "monitoring": {
    "enabled": true,
    "auto_track": true,
    "real_time": true
  },
  "thresholds": {
    "warning": 70,
    "optimization": 80,
    "critical": 90,
    "emergency": 95,
    "max_tokens": 200000
  },
  "agents": {},
  "sessions": {},
  "statistics": {
    "total_tokens_tracked": 0,
    "peak_usage": 0,
    "optimization_events": 0,
    "emergency_recoveries": 0
  }
}
EOF
        log_info "Created context monitoring config"
    fi
    
    # Intelligence system configuration
    local intelligence_config="${AWOC_HOME}/intelligence/config.json"
    if [ ! -f "$intelligence_config" ]; then
        cat > "$intelligence_config" << 'EOF'
{
  "version": "1.3.0",
  "enabled": true,
  "pattern_recognition": {
    "enabled": true,
    "confidence_threshold": 0.80,
    "learning_rate": 0.1
  },
  "predictive_analytics": {
    "enabled": true,
    "accuracy_target": 0.85,
    "prediction_horizon": 300
  },
  "models": {
    "overflow_prediction": "simple_regression",
    "optimization_trigger": "pattern_matching",
    "agent_selection": "rule_based"
  }
}
EOF
        log_info "Created intelligence config"
    fi
    
    # Session tracking
    local session_file="${AWOC_HOME}/context/current_session.json"
    if [ ! -f "$session_file" ]; then
        cat > "$session_file" << EOF
{
  "session_id": "awoc-init-$(date +%s)",
  "start_time": "$(date -Iseconds)",
  "active_agents": [],
  "token_usage": {
    "current": 0,
    "peak": 0
  },
  "last_update": "$(date -Iseconds)"
}
EOF
        log_info "Created session tracking file"
    fi
}

# Validate environment setup
validate_environment() {
    log_info "Validating AWOC environment"
    
    local validation_failed=0
    
    # Check directories
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Missing directory: $dir"
            ((validation_failed++))
        elif [ ! -r "$dir" ]; then
            log_error "Directory not readable: $dir"
            ((validation_failed++))
        fi
    done
    
    # Check script executability
    local scripts=(
        "context-monitor.sh"
        "context-intelligence.sh"
        "handoff-manager.sh"
        "overflow-prevention.sh"
        "context-optimizer.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="${PROJECT_ROOT}/scripts/${script}"
        if [ -f "$script_path" ]; then
            if [ ! -x "$script_path" ]; then
                log_warning "Script not executable: $script_path"
                chmod +x "$script_path" 2>/dev/null || log_error "Failed to make executable: $script_path"
            fi
        else
            log_warning "Script not found: $script_path"
        fi
    done
    
    # Check configuration validity
    if command -v jq >/dev/null 2>&1; then
        local configs=(
            "${AWOC_HOME}/context/monitor.json"
            "${AWOC_HOME}/intelligence/config.json"
            "${AWOC_HOME}/context/current_session.json"
        )
        
        for config in "${configs[@]}"; do
            if [ -f "$config" ]; then
                if ! jq empty "$config" 2>/dev/null; then
                    log_error "Invalid JSON in config: $config"
                    ((validation_failed++))
                else
                    log_info "Valid config: $config"
                fi
            fi
        done
    else
        log_warning "jq not available - skipping JSON validation"
    fi
    
    if [ $validation_failed -gt 0 ]; then
        log_error "Environment validation failed with $validation_failed errors"
        return 1
    else
        log_info "Environment validation passed"
        return 0
    fi
}

# Export environment variables
export_environment_vars() {
    export AWOC_SESSION_ID="awoc-$(date +%s)"
    export AWOC_LOG_LEVEL="${AWOC_LOG_LEVEL:-INFO}"
    export PROJECT_ROOT="${PROJECT_ROOT}"
    export HANDOFF_DIR="${AWOC_HOME}/handoffs"
    export CONTEXT_DIR="${AWOC_HOME}/context"
    export INTELLIGENCE_DIR="${AWOC_HOME}/intelligence"
    export AWOC_MAINTAIN_PROJECT_WORKING_DIR="1"
    export BASH_MAX_TIMEOUT_MS="120000"
    export AWOC_MAX_OUTPUT_TOKENS="8192"
    
    log_info "Environment variables exported"
}

# Main execution
main() {
    log_info "Starting AWOC environment initialization"
    
    if ! init_awoc_environment; then
        log_error "Failed to initialize AWOC environment"
        exit 1
    fi
    
    export_environment_vars
    
    echo "AWOC environment initialized successfully"
    echo "Required directories created in: $AWOC_HOME"
    echo "Scripts location: $PROJECT_ROOT/scripts"
    echo ""
    echo "Next steps:"
    echo "1. Run './validate.sh' to check system health"
    echo "2. Test with a simple command like '/session-start'"
    echo "3. Monitor with './scripts/context-monitor.sh status'"
}

# Allow script to be sourced or executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi