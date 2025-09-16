#!/bin/bash

# AWOC Bundle Validation System
# Validates handoff bundles against schema and performs integrity checks
# Based on schema specifications and security requirements

set -euo pipefail

# Get script directory for robust path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging system
if [ -f "$SCRIPT_DIR/logging.sh" ]; then
    # shellcheck source=./logging.sh
    source "$SCRIPT_DIR/logging.sh"
    init_logging
else
    # Fallback logging
    log_info() { echo "[INFO] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { [ "${DEBUG:-}" = "1" ] && echo "[DEBUG] $1" >&2 || true; }
fi

# Configuration
BUNDLE_SCHEMA="$SCRIPT_DIR/../schemas/handoff-bundle.json"
AWOC_DIR="${AWOC_DIR:-$HOME/.awoc}"
BUNDLE_DIR="$AWOC_DIR/handoffs"

# Validation functions
validate_json_structure() {
    local bundle_file="$1"

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq command not available - cannot validate JSON structure"
        return 1
    fi

    if ! jq empty "$bundle_file" 2>/dev/null; then
        log_error "Bundle contains invalid JSON: $bundle_file"
        return 1
    fi

    log_debug "JSON structure validation passed"
    return 0
}

validate_against_schema() {
    local bundle_file="$1"

    if [ ! -f "$BUNDLE_SCHEMA" ]; then
        log_warning "Schema file not found: $BUNDLE_SCHEMA"
        log_warning "Skipping schema validation"
        return 0
    fi

    # Check if we have a JSON schema validator
    if command -v ajv >/dev/null 2>&1; then
        if ajv validate -s "$BUNDLE_SCHEMA" -d "$bundle_file" 2>/dev/null; then
            log_debug "Schema validation passed with ajv"
            return 0
        else
            log_error "Schema validation failed with ajv"
            return 1
        fi
    fi

    # Fallback to basic jq validation of required fields
    if ! validate_required_fields "$bundle_file"; then
        log_error "Required fields validation failed"
        return 1
    fi

    log_debug "Schema validation passed (fallback method)"
    return 0
}

validate_required_fields() {
    local bundle_file="$1"

    # Check top-level required fields
    local required_fields=("bundle_metadata" "session_state" "context_usage" "knowledge_graph" "agent_coordination")

    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$bundle_file" >/dev/null 2>&1; then
            log_error "Missing required field: $field"
            return 1
        fi
    done

    # Check bundle_metadata required fields
    local metadata_fields=("bundle_id" "created_at" "bundle_type" "version" "compression")
    for field in "${metadata_fields[@]}"; do
        if ! jq -e ".bundle_metadata | has(\"$field\")" "$bundle_file" >/dev/null 2>&1; then
            log_error "Missing required metadata field: $field"
            return 1
        fi
    done

    # Validate bundle_id format (YYYYMMDD_HHMMSS_sessionid)
    local bundle_id
    bundle_id=$(jq -r '.bundle_metadata.bundle_id' "$bundle_file" 2>/dev/null || echo "")
    if ! [[ $bundle_id =~ ^[0-9]{8}_[0-9]{6}_[a-f0-9]{8}$ ]]; then
        log_error "Invalid bundle_id format: $bundle_id"
        return 1
    fi

    log_debug "Required fields validation passed"
    return 0
}

validate_integrity() {
    local bundle_file="$1"

    # Check if bundle has integrity hash
    local integrity_hash
    integrity_hash=$(jq -r '.recovery_metadata.integrity_hash // empty' "$bundle_file" 2>/dev/null)

    if [ -z "$integrity_hash" ]; then
        log_warning "No integrity hash found in bundle"
        return 0
    fi

    # Calculate current hash of essential fields
    local essential_data
    essential_data=$(jq -c '{bundle_metadata, session_state, context_usage}' "$bundle_file" 2>/dev/null)

    local current_hash
    current_hash=$(echo -n "$essential_data" | sha256sum | cut -d' ' -f1)

    if [ "$integrity_hash" != "$current_hash" ]; then
        log_error "Integrity check failed - bundle may be corrupted"
        log_error "Expected: $integrity_hash"
        log_error "Actual: $current_hash"
        return 1
    fi

    log_debug "Integrity validation passed"
    return 0
}

validate_file_dependencies() {
    local bundle_file="$1"

    # Check if any file dependencies exist
    if ! jq -e '.recovery_metadata.dependencies // empty' "$bundle_file" >/dev/null 2>&1; then
        log_debug "No file dependencies to validate"
        return 0
    fi

    local missing_deps=0

    while IFS= read -r dep; do
        local dep_type dep_path dep_required
        dep_type=$(echo "$dep" | jq -r '.type')
        dep_path=$(echo "$dep" | jq -r '.path')
        dep_required=$(echo "$dep" | jq -r '.required')

        if [ "$dep_type" = "file" ] && [ "$dep_required" = "true" ]; then
            if [ ! -f "$dep_path" ] && [ ! -f "$SCRIPT_DIR/../$dep_path" ]; then
                log_warning "Missing required dependency: $dep_path"
                ((missing_deps++))
            fi
        fi
    done < <(jq -c '.recovery_metadata.dependencies[]?' "$bundle_file" 2>/dev/null)

    if [ $missing_deps -gt 0 ]; then
        log_warning "Found $missing_deps missing dependencies"
        log_warning "Bundle may not restore completely"
    else
        log_debug "File dependencies validation passed"
    fi

    return 0
}

validate_compression() {
    local bundle_file="$1"

    # Check compression metadata consistency
    local compression_enabled
    compression_enabled=$(jq -r '.bundle_metadata.compression.enabled // false' "$bundle_file" 2>/dev/null)

    if [ "$compression_enabled" = "true" ]; then
        local original_size compressed_size
        original_size=$(jq -r '.bundle_metadata.compression.original_size // 0' "$bundle_file" 2>/dev/null)
        compressed_size=$(jq -r '.bundle_metadata.compression.compressed_size // 0' "$bundle_file" 2>/dev/null)

        if [ "$compressed_size" -eq 0 ] || [ "$original_size" -eq 0 ]; then
            log_warning "Compression metadata incomplete"
            return 0
        fi

        if [ "$compressed_size" -gt "$original_size" ]; then
            log_warning "Compression size inconsistency detected"
        fi

        log_debug "Compression metadata validation passed"
    fi

    return 0
}

# Main validation function
validate_bundle() {
    local bundle_path="$1"
    local validation_mode="${2:-full}"

    log_info "Validating bundle: $(basename "$bundle_path")"
    log_debug "Validation mode: $validation_mode"

    # Check if bundle file exists and is readable
    if [ ! -f "$bundle_path" ]; then
        log_error "Bundle file does not exist: $bundle_path"
        return 1
    fi

    if [ ! -r "$bundle_path" ]; then
        log_error "Bundle file is not readable: $bundle_path"
        return 1
    fi

    local validation_errors=0

    # JSON structure validation (always required)
    if ! validate_json_structure "$bundle_path"; then
        ((validation_errors++))
    fi

    # Schema validation (skip in quick mode)
    if [ "$validation_mode" != "quick" ]; then
        if ! validate_against_schema "$bundle_path"; then
            ((validation_errors++))
        fi
    fi

    # Required fields validation (always required)
    if ! validate_required_fields "$bundle_path"; then
        ((validation_errors++))
    fi

    # Integrity validation (skip in quick mode)
    if [ "$validation_mode" != "quick" ]; then
        if ! validate_integrity "$bundle_path"; then
            ((validation_errors++))
        fi
    fi

    # File dependencies validation (warning only)
    validate_file_dependencies "$bundle_path" || true

    # Compression metadata validation (warning only)
    validate_compression "$bundle_path" || true

    if [ $validation_errors -eq 0 ]; then
        log_info "Bundle validation PASSED: $(basename "$bundle_path")"
        return 0
    else
        log_error "Bundle validation FAILED: $(basename "$bundle_path")"
        log_error "Found $validation_errors validation errors"
        return 1
    fi
}

# CLI interface
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  validate <bundle-path> [mode]     Validate a specific bundle
                                   Modes: full, quick (default: full)

  check <bundle-id>                 Validate bundle by ID

  list-invalid                      Find all invalid bundles

  repair <bundle-path>              Attempt basic bundle repair

  info <bundle-path>                Show bundle validation info

Examples:
  $0 validate ~/.awoc/handoffs/20240916_143052_abc123ef.json
  $0 check 20240916_143052_abc123ef quick
  $0 list-invalid
  $0 repair ~/.awoc/handoffs/corrupted_bundle.json

EOF
}

# Command implementations
cmd_validate() {
    local bundle_path="$1"
    local mode="${2:-full}"

    validate_bundle "$bundle_path" "$mode"
}

cmd_check() {
    local bundle_id="$1"
    local mode="${2:-full}"

    local bundle_path="$BUNDLE_DIR/${bundle_id}.json"
    validate_bundle "$bundle_path" "$mode"
}

cmd_list_invalid() {
    local invalid_count=0

    if [ ! -d "$BUNDLE_DIR" ]; then
        log_info "No bundles directory found: $BUNDLE_DIR"
        return 0
    fi

    log_info "Scanning for invalid bundles in: $BUNDLE_DIR"

    for bundle in "$BUNDLE_DIR"/*.json; do
        [ -f "$bundle" ] || continue

        if ! validate_bundle "$bundle" "quick" >/dev/null 2>&1; then
            echo "INVALID: $(basename "$bundle")"
            ((invalid_count++))
        fi
    done

    if [ $invalid_count -eq 0 ]; then
        log_info "All bundles are valid"
    else
        log_warning "Found $invalid_count invalid bundles"
    fi

    return 0
}

cmd_repair() {
    local bundle_path="$1"

    log_info "Attempting to repair bundle: $(basename "$bundle_path")"

    # Basic repair attempts
    local repair_needed=false
    local temp_file="${bundle_path}.repair.tmp"

    # Copy original to temp file
    cp "$bundle_path" "$temp_file"

    # Try to fix missing required fields with defaults
    if ! jq -e '.bundle_metadata.version' "$temp_file" >/dev/null 2>&1; then
        jq '.bundle_metadata.version = "2.0.0"' "$temp_file" > "${temp_file}.new"
        mv "${temp_file}.new" "$temp_file"
        repair_needed=true
        log_info "Added missing version field"
    fi

    # Update integrity hash
    local essential_data current_hash
    essential_data=$(jq -c '{bundle_metadata, session_state, context_usage}' "$temp_file" 2>/dev/null)
    current_hash=$(echo -n "$essential_data" | sha256sum | cut -d' ' -f1)

    jq ".recovery_metadata.integrity_hash = \"$current_hash\"" "$temp_file" > "${temp_file}.new"
    mv "${temp_file}.new" "$temp_file"
    repair_needed=true
    log_info "Updated integrity hash"

    # Validate repaired bundle
    if validate_bundle "$temp_file" "full" >/dev/null 2>&1; then
        # Create backup and replace original
        cp "$bundle_path" "${bundle_path}.backup"
        mv "$temp_file" "$bundle_path"
        log_info "Bundle repair successful"
        log_info "Original backed up as: ${bundle_path}.backup"
        return 0
    else
        rm -f "$temp_file"
        log_error "Bundle repair failed"
        return 1
    fi
}

cmd_info() {
    local bundle_path="$1"

    if [ ! -f "$bundle_path" ]; then
        log_error "Bundle not found: $bundle_path"
        return 1
    fi

    echo "=== Bundle Validation Info ==="
    echo "File: $(basename "$bundle_path")"
    echo "Size: $(stat -f%z "$bundle_path" 2>/dev/null || stat -c%s "$bundle_path" 2>/dev/null || echo "unknown") bytes"
    echo ""

    # Extract key information
    local bundle_id created_at bundle_type
    bundle_id=$(jq -r '.bundle_metadata.bundle_id // "unknown"' "$bundle_path" 2>/dev/null)
    created_at=$(jq -r '.bundle_metadata.created_at // "unknown"' "$bundle_path" 2>/dev/null)
    bundle_type=$(jq -r '.bundle_metadata.bundle_type // "unknown"' "$bundle_path" 2>/dev/null)

    echo "Bundle ID: $bundle_id"
    echo "Created: $created_at"
    echo "Type: $bundle_type"
    echo ""

    # Validation results
    if validate_bundle "$bundle_path" "full" >/dev/null 2>&1; then
        echo "Validation Status: ✅ VALID"
    else
        echo "Validation Status: ❌ INVALID"
    fi

    return 0
}

# Main execution
main() {
    case "${1:-}" in
        validate)
            [ $# -ge 2 ] || { show_usage; exit 1; }
            cmd_validate "$2" "${3:-full}"
            ;;
        check)
            [ $# -ge 2 ] || { show_usage; exit 1; }
            cmd_check "$2" "${3:-full}"
            ;;
        list-invalid)
            cmd_list_invalid
            ;;
        repair)
            [ $# -ge 2 ] || { show_usage; exit 1; }
            cmd_repair "$2"
            ;;
        info)
            [ $# -ge 2 ] || { show_usage; exit 1; }
            cmd_info "$2"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"