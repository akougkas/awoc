#!/bin/bash

# AWOC Enterprise Configuration Validator
# Validates enterprise settings, policies, and compliance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS_FILE="$PROJECT_ROOT/settings.json"
MANAGED_SETTINGS_PATH="/Library/Application Support/ClaudeCode/managed-settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
VALIDATIONS_PASSED=0
VALIDATIONS_FAILED=0
WARNINGS=0

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; ((VALIDATIONS_PASSED++)); }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; ((WARNINGS++)); }
log_error() { echo -e "${RED}❌ $1${NC}"; ((VALIDATIONS_FAILED++)); }

# Validate enterprise configuration structure
validate_enterprise_config() {
    log_info "Validating enterprise configuration structure"
    
    if ! jq -e '.enterprise' "$SETTINGS_FILE" >/dev/null 2>&1; then
        log_error "Enterprise configuration section missing"
        return 1
    fi
    
    local required_keys=(
        "enabled"
        "policy_enforcement" 
        "managed_settings_path"
        "telemetry"
        "security"
    )
    
    for key in "${required_keys[@]}"; do
        if ! jq -e ".enterprise.$key" "$SETTINGS_FILE" >/dev/null 2>&1; then
            log_error "Enterprise config missing required key: $key"
        else
            log_success "Enterprise config has required key: $key"
        fi
    done
}

# Validate security framework
validate_security_framework() {
    log_info "Validating security framework"
    
    # Check permissions structure
    local permission_types=("allow" "deny" "ask")
    for perm_type in "${permission_types[@]}"; do
        if ! jq -e ".permissions.$perm_type" "$SETTINGS_FILE" >/dev/null 2>&1; then
            log_error "Missing permissions section: $perm_type"
        else
            log_success "Permissions section present: $perm_type"
        fi
    done
    
    # Validate security rules
    local security_denials=(
        "Read(.env)"
        "Write(.env)"
        "Read(**/secrets/**)"
        "Write(**/secrets/**)"
        "Bash(sudo:*)"
    )
    
    for denial in "${security_denials[@]}"; do
        if jq -e ".permissions.deny | index(\"$denial\")" "$SETTINGS_FILE" >/dev/null 2>&1; then
            log_success "Security denial rule present: $denial"
        else
            log_warning "Missing security denial rule: $denial"
        fi
    done
    
    # Check enterprise security settings
    local enterprise_security_keys=(
        "sandbox_delegations"
        "validate_agent_sources"
        "max_delegation_depth"
        "resource_limits"
    )
    
    for key in "${enterprise_security_keys[@]}"; do
        if jq -e ".enterprise.security.$key" "$SETTINGS_FILE" >/dev/null 2>&1; then
            log_success "Enterprise security setting present: $key"
        else
            log_error "Missing enterprise security setting: $key"
        fi
    done
}

# Validate hook reliability
validate_hook_reliability() {
    log_info "Validating hook system reliability"
    
    if ! jq -e '.hooks.enabled' "$SETTINGS_FILE" | grep -q true; then
        log_error "Hook system is not enabled"
        return 1
    fi
    
    log_success "Hook system is enabled"
    
    # Check hook error handling
    local hook_sections=(
        "PreToolUse"
        "UserPromptSubmit" 
        "SessionEnd"
        "PreCompact"
    )
    
    for section in "${hook_sections[@]}"; do
        local hooks_with_error_handling=0
        local total_hooks=0
        
        if jq -e ".hooks.$section" "$SETTINGS_FILE" >/dev/null 2>&1; then
            total_hooks=$(jq ".hooks.$section | length" "$SETTINGS_FILE")
            hooks_with_error_handling=$(jq ".hooks.$section[] | select(contains(\"2>/dev/null\"))" "$SETTINGS_FILE" | wc -l)
            
            if [ "$hooks_with_error_handling" -eq "$total_hooks" ]; then
                log_success "All hooks in $section have error handling ($total_hooks/$total_hooks)"
            else
                log_warning "Some hooks in $section lack error handling ($hooks_with_error_handling/$total_hooks)"
            fi
        fi
    done
}

# Validate environment variable resolution
validate_environment_resolution() {
    log_info "Validating environment variable resolution"
    
    # Check that environment variables are properly resolved
    local env_vars=(
        "PROJECT_ROOT"
        "HANDOFF_DIR"
        "CONTEXT_DIR"
        "INTELLIGENCE_DIR"
    )
    
    for var in "${env_vars[@]}"; do
        local value
        value=$(jq -r ".env.$var" "$SETTINGS_FILE")
        
        if [[ "$value" =~ \$\{.*\} ]]; then
            log_warning "Environment variable $var contains unresolved variable: $value"
        elif [ -z "$value" ] || [ "$value" = "null" ]; then
            log_error "Environment variable $var is missing or null"
        else
            log_success "Environment variable $var properly resolved: $value"
        fi
    done
}

# Test managed settings integration
test_managed_settings() {
    log_info "Testing managed settings integration"
    
    local managed_path
    managed_path=$(jq -r '.enterprise.managed_settings_path' "$SETTINGS_FILE")
    
    if [ "$managed_path" = "null" ]; then
        log_warning "Managed settings path not configured"
        return 0
    fi
    
    if [ ! -f "$managed_path" ]; then
        log_info "Managed settings file does not exist (expected for non-enterprise): $managed_path"
    else
        if jq empty "$managed_path" 2>/dev/null; then
            log_success "Managed settings file is valid JSON: $managed_path"
        else
            log_error "Managed settings file contains invalid JSON: $managed_path"
        fi
    fi
}

# Validate delegation security
validate_delegation_security() {
    log_info "Validating delegation security framework"
    
    # Check delegation validator script
    local validator_script="$PROJECT_ROOT/scripts/delegation-validator.sh"
    if [ -f "$validator_script" ]; then
        if [ -x "$validator_script" ]; then
            log_success "Delegation validator script is executable"
        else
            log_error "Delegation validator script is not executable"
        fi
    else
        log_error "Delegation validator script is missing"
    fi
    
    # Check delegation configuration
    local delegation_config_keys=(
        "enabled"
        "max_concurrent_delegations"
        "token_budget_limits"
        "priority_weights"
    )
    
    for key in "${delegation_config_keys[@]}"; do
        if jq -e ".hierarchical_agents.delegation.$key" "$SETTINGS_FILE" >/dev/null 2>&1; then
            log_success "Delegation config present: $key"
        else
            log_error "Missing delegation config: $key"
        fi
    done
}

# Test script execution paths
test_script_execution() {
    log_info "Testing script execution paths"
    
    local critical_scripts=(
        "context-monitor.sh"
        "handoff-manager.sh"
        "overflow-prevention.sh"
        "context-optimizer.sh"
    )
    
    for script in "${critical_scripts[@]}"; do
        local script_path="$PROJECT_ROOT/scripts/$script"
        if [ -f "$script_path" ]; then
            if [ -x "$script_path" ]; then
                log_success "Critical script executable: $script"
            else
                log_error "Critical script not executable: $script"
            fi
        else
            log_error "Critical script missing: $script"
        fi
    done
}

# Main validation function
main() {
    echo -e "${BLUE}🔍 AWOC Enterprise Configuration Validation${NC}"
    echo "=========================================="
    echo ""
    
    # Check if settings file exists
    if [ ! -f "$SETTINGS_FILE" ]; then
        log_error "Settings file not found: $SETTINGS_FILE"
        exit 1
    fi
    
    # Validate JSON structure
    if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
        log_error "Settings file contains invalid JSON"
        exit 1
    fi
    
    log_success "Settings file is valid JSON"
    
    # Run validation tests
    validate_enterprise_config
    validate_security_framework
    validate_hook_reliability
    validate_environment_resolution
    test_managed_settings
    validate_delegation_security
    test_script_execution
    
    # Summary
    echo ""
    echo -e "${BLUE}📊 Validation Summary${NC}"
    echo "===================="
    echo "✅ Passed: $VALIDATIONS_PASSED"
    echo "❌ Failed: $VALIDATIONS_FAILED"
    echo "⚠️  Warnings: $WARNINGS"
    echo ""
    
    if [ $VALIDATIONS_FAILED -gt 0 ]; then
        echo -e "${RED}❌ Enterprise validation failed${NC}"
        echo "Critical issues must be resolved before enterprise deployment"
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Enterprise validation passed with warnings${NC}"
        echo "Review warnings before enterprise deployment"
        exit 0
    else
        echo -e "${GREEN}🎉 Enterprise validation passed${NC}"
        echo "Configuration is ready for enterprise deployment"
        exit 0
    fi
}

# Allow sourcing
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi