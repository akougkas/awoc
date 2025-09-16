#!/bin/bash

# Quick AWOC Validation Script
# Fast validation of core components without complex dependencies

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Utility functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TOTAL_TESTS++))
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test script existence and basic syntax
test_script_availability() {
    log_info "Testing script availability and basic syntax"
    
    local core_scripts=(
        "context-monitor.sh"
        "token-logger.sh"
        "handoff-manager.sh"
        "handoff-recovery.sh"
    )
    
    for script in "${core_scripts[@]}"; do
        log_test "Checking $script"
        
        if [ -f "scripts/$script" ]; then
            if [ -x "scripts/$script" ]; then
                # Basic syntax check
                if bash -n "scripts/$script" 2>/dev/null; then
                    log_pass "$script exists, is executable, and has valid syntax"
                else
                    log_fail "$script has syntax errors"
                fi
            else
                log_warn "$script exists but is not executable"
            fi
        else
            log_fail "$script not found"
        fi
    done
}

# Test basic file structure
test_file_structure() {
    log_info "Testing AWOC 2.0 file structure"
    
    local required_dirs=(
        "agents"
        "commands"
        "scripts"
        "templates"
        "output-styles"
    )
    
    for dir in "${required_dirs[@]}"; do
        log_test "Checking directory: $dir"
        if [ -d "$dir" ]; then
            log_pass "Directory $dir exists"
        else
            log_fail "Directory $dir missing"
        fi
    done
    
    # Check for AWOC 2.0 specific directories
    local awoc2_dirs=(
        ".claude"
        ".claude/commands"
        ".claude/agents"
    )
    
    for dir in "${awoc2_dirs[@]}"; do
        log_test "Checking AWOC 2.0 directory: $dir"
        if [ -d "$dir" ]; then
            log_pass "AWOC 2.0 directory $dir exists"
        else
            log_warn "AWOC 2.0 directory $dir missing (may not be installed yet)"
        fi
    done
}

# Test configuration files
test_configuration_files() {
    log_info "Testing configuration files"
    
    log_test "Checking settings.json"
    if [ -f "settings.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            if jq . "settings.json" >/dev/null 2>&1; then
                log_pass "settings.json exists and is valid JSON"
            else
                log_fail "settings.json has invalid JSON syntax"
            fi
        else
            log_pass "settings.json exists (jq not available for validation)"
        fi
    else
        log_fail "settings.json missing"
    fi
    
    # Test schema files if they exist
    if [ -d "schemas" ]; then
        log_test "Checking schema files"
        local schema_count=$(find schemas -name "*.json" 2>/dev/null | wc -l)
        if [ "$schema_count" -gt 0 ]; then
            log_pass "Found $schema_count schema files"
        else
            log_warn "No schema files found in schemas directory"
        fi
    fi
}

# Test agent files
test_agent_files() {
    log_info "Testing agent files"
    
    local agents=(
        "api-researcher.md"
        "content-writer.md"
        "data-analyst.md"
        "project-manager.md"
        "learning-assistant.md"
        "creative-assistant.md"
    )
    
    for agent in "${agents[@]}"; do
        log_test "Checking agent: $agent"
        if [ -f "agents/$agent" ]; then
            # Check for YAML frontmatter
            if head -1 "agents/$agent" | grep -q "^---$"; then
                log_pass "Agent $agent has proper structure"
            else
                log_warn "Agent $agent missing YAML frontmatter"
            fi
        else
            log_fail "Agent $agent missing"
        fi
    done
}

# Test command files
test_command_files() {
    log_info "Testing command files"
    
    local basic_commands=(
        "session-start.md"
        "session-end.md"
    )
    
    for cmd in "${basic_commands[@]}"; do
        log_test "Checking command: $cmd"
        if [ -f "commands/$cmd" ]; then
            if head -1 "commands/$cmd" | grep -q "^---$"; then
                log_pass "Command $cmd has proper structure"
            else
                log_warn "Command $cmd missing YAML frontmatter"
            fi
        else
            log_fail "Command $cmd missing"
        fi
    done
    
    # Check AWOC 2.0 commands if they exist
    if [ -d ".claude/commands" ]; then
        local awoc2_commands=(
            "prime-dev.md"
            "handoff-save.md"
            "handoff-load.md"
        )
        
        for cmd in "${awoc2_commands[@]}"; do
            log_test "Checking AWOC 2.0 command: $cmd"
            if [ -f ".claude/commands/$cmd" ]; then
                log_pass "AWOC 2.0 command $cmd exists"
            else
                log_warn "AWOC 2.0 command $cmd missing (may not be installed)"
            fi
        done
    fi
}

# Test basic script functionality without hanging
test_basic_functionality() {
    log_info "Testing basic script functionality"
    
    # Test help/usage functions
    local test_scripts=(
        "context-monitor.sh"
        "token-logger.sh"
    )
    
    for script in "${test_scripts[@]}"; do
        if [ -x "scripts/$script" ]; then
            log_test "Testing $script help function"
            
            # Try various help flags with short timeout
            if timeout 5 "scripts/$script" --help >/dev/null 2>&1 || \
               timeout 5 "scripts/$script" -h >/dev/null 2>&1 || \
               timeout 5 "scripts/$script" help >/dev/null 2>&1 || \
               timeout 5 "scripts/$script" usage >/dev/null 2>&1; then
                log_pass "$script responds to help requests"
            else
                log_info "$script may not have help function (or uses different interface)"
            fi
        fi
    done
    
    # Test installation script
    log_test "Testing installation script syntax"
    if [ -f "install.sh" ] && [ -x "install.sh" ]; then
        if bash -n "install.sh" 2>/dev/null; then
            log_pass "install.sh has valid syntax"
        else
            log_fail "install.sh has syntax errors"
        fi
    else
        log_fail "install.sh missing or not executable"
    fi
    
    # Test main validation script (but don't run it to avoid recursion)
    log_test "Testing main validation script syntax"
    if [ -f "validate.sh" ] && [ -x "validate.sh" ]; then
        if bash -n "validate.sh" 2>/dev/null; then
            log_pass "validate.sh has valid syntax"
        else
            log_fail "validate.sh has syntax errors"
        fi
    else
        log_fail "validate.sh missing or not executable"
    fi
}

# Test dependencies
test_dependencies() {
    log_info "Testing system dependencies"
    
    local required_commands=(
        "bash"
        "mkdir"
        "chmod"
        "find"
        "grep"
    )
    
    local optional_commands=(
        "jq"
        "bc"
        "timeout"
        "rg"
    )
    
    for cmd in "${required_commands[@]}"; do
        log_test "Checking required command: $cmd"
        if command -v "$cmd" >/dev/null 2>&1; then
            log_pass "Required command $cmd available"
        else
            log_fail "Required command $cmd missing"
        fi
    done
    
    for cmd in "${optional_commands[@]}"; do
        log_test "Checking optional command: $cmd"
        if command -v "$cmd" >/dev/null 2>&1; then
            log_pass "Optional command $cmd available"
        else
            log_info "Optional command $cmd not available (some features may be limited)"
        fi
    done
}

# Generate quick validation report
generate_quick_report() {
    local report_dir="${HOME}/.awoc/test-results"
    mkdir -p "$report_dir"
    local report_file="$report_dir/quick-validation-$(date +%s).json"
    
    cat > "$report_file" << EOF
{
    "quick_validation": {
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
        "test_results": {
            "total_tests": $TOTAL_TESTS,
            "passed_tests": $PASSED_TESTS,
            "failed_tests": $FAILED_TESTS,
            "warnings": $WARNINGS,
            "success_rate": $(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
        },
        "validation_status": "$([ $FAILED_TESTS -eq 0 ] && echo "PASSED" || echo "FAILED")",
        "recommendations": [
            $([ $FAILED_TESTS -eq 0 ] && echo '"Basic validation passed - system appears functional"' || echo '"Address failed tests before proceeding"'),
            $([ $WARNINGS -gt 3 ] && echo '"Review warnings for potential improvements",' || echo '"Warning levels acceptable",')
            "Run comprehensive test suite for production validation",
            "Consider installing missing optional components for full functionality"
        ]
    }
}
EOF
    
    log_info "Quick validation report: $report_file"
}

# Main execution
main() {
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWOC Quick Validation${NC}"
    echo -e "${BLUE}  Fast system health check without complex dependencies${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Run all quick tests
    test_script_availability
    echo ""
    
    test_file_structure
    echo ""
    
    test_configuration_files
    echo ""
    
    test_agent_files
    echo ""
    
    test_command_files
    echo ""
    
    test_basic_functionality
    echo ""
    
    test_dependencies
    echo ""
    
    # Generate report
    generate_quick_report
    
    # Final summary
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Quick Validation Results${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo -e "  Total Tests: $TOTAL_TESTS"
    echo -e "  Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "  Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
    echo ""
    
    local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    echo -e "  Success Rate: $success_rate%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✅ Quick validation passed!${NC}"
        echo -e "${GREEN}   AWOC appears to be properly structured and functional.${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo -e "  1. Run comprehensive tests: ./scripts/test-runner.sh"
        echo -e "  2. Test error handling: ./scripts/test-error-handling.sh"
        echo -e "  3. Validate security: ./scripts/test-security-validation.sh"
        echo -e "  4. Install AWOC: ./install.sh"
        exit 0
    else
        echo -e "${RED}❌ Quick validation found issues.${NC}"
        echo -e "${RED}   Address $FAILED_TESTS failed tests before proceeding.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"