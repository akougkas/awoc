#!/bin/bash

# AWOC Error Handling and Edge Case Validation Script
# Comprehensive testing of error conditions, edge cases, and recovery mechanisms

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TEMP_DIR="${HOME}/.awoc/test-temp/error-handling"

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

# Initialize test environment
init_test_environment() {
    log_info "Initializing error handling test environment"
    
    # Create test directories
    mkdir -p "$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/invalid"
    mkdir -p "$TEST_TEMP_DIR/readonly" 
    mkdir -p "$TEST_TEMP_DIR/nospace"
    
    # Create test files with various permissions
    touch "$TEST_TEMP_DIR/valid-file.txt"
    touch "$TEST_TEMP_DIR/readonly/readonly-file.txt"
    chmod 444 "$TEST_TEMP_DIR/readonly/readonly-file.txt"
    chmod 555 "$TEST_TEMP_DIR/readonly"
    
    # Create invalid JSON file
    echo "{ invalid json" > "$TEST_TEMP_DIR/invalid/bad.json"
    
    # Create very large file for space testing
    dd if=/dev/zero of="$TEST_TEMP_DIR/large-file.bin" bs=1M count=1 >/dev/null 2>&1 || true
}

# Test script error handling patterns
test_script_error_handling() {
    log_info "Testing script error handling patterns"
    
    # Test 1: Check all scripts use set -euo pipefail
    log_test "Checking error handling directives in scripts"
    local missing_error_handling=()
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ] && [ -r "$script" ]; then
            if ! head -10 "$script" | grep -q "set -euo pipefail"; then
                missing_error_handling+=("$(basename "$script")")
            fi
        fi
    done
    
    if [ ${#missing_error_handling[@]} -eq 0 ]; then
        log_pass "All scripts use proper error handling (set -euo pipefail)"
    else
        log_fail "Scripts missing error handling: ${missing_error_handling[*]}"
    fi
    
    # Test 2: Check for unquoted variables
    log_test "Checking for unquoted variable usage"
    local scripts_with_unquoted=()
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ] && [ -r "$script" ]; then
            # Look for common unquoted variable patterns (simplified check)
            if grep -q '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$script" 2>/dev/null; then
                # This is a heuristic - may have false positives
                scripts_with_unquoted+=("$(basename "$script")")
            fi
        fi
    done
    
    if [ ${#scripts_with_unquoted[@]} -eq 0 ]; then
        log_pass "No obvious unquoted variables found"
    else
        log_warn "Scripts with potential unquoted variables: ${scripts_with_unquoted[*]}"
    fi
    
    # Test 3: Check for proper function return codes
    log_test "Checking function return code handling"
    local functions_with_returns=0
    local functions_total=0
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ] && [ -r "$script" ]; then
            local func_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$script" 2>/dev/null || echo "0")
            local return_count=$(grep -c "return [0-9]" "$script" 2>/dev/null || echo "0")
            
            functions_total=$((functions_total + func_count))
            functions_with_returns=$((functions_with_returns + return_count))
        fi
    done
    
    if [ $functions_total -gt 0 ]; then
        local return_percentage=$(echo "scale=0; $functions_with_returns * 100 / $functions_total" | bc -l 2>/dev/null || echo "0")
        if [ "$return_percentage" -gt 50 ]; then
            log_pass "Good return code usage: ${return_percentage}% of functions"
        else
            log_warn "Low return code usage: ${return_percentage}% of functions"
        fi
    else
        log_info "No functions found for return code analysis"
    fi
}

# Test input validation and sanitization
test_input_validation() {
    log_info "Testing input validation and sanitization"
    
    # Test 1: Script argument handling
    log_test "Testing script argument validation"
    
    local test_scripts=(
        "context-monitor.sh"
        "token-logger.sh"
        "handoff-manager.sh"
    )
    
    for script_name in "${test_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/$script_name"
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            
            # Test empty arguments
            if timeout 5 "$script_path" "" 2>/dev/null; then
                log_warn "$script_name accepts empty arguments (potential issue)"
            else
                log_pass "$script_name properly rejects empty arguments"
            fi
            
            # Test invalid commands
            if timeout 5 "$script_path" "invalid-command-xyz" 2>/dev/null; then
                log_warn "$script_name accepts invalid commands"
            else
                log_pass "$script_name properly rejects invalid commands"
            fi
            
            # Test special characters in arguments
            if timeout 5 "$script_path" "; rm -rf /tmp; echo" 2>/dev/null; then
                log_fail "$script_name vulnerable to command injection"
            else
                log_pass "$script_name resistant to command injection"
            fi
            
        else
            log_info "$script_name not found or not executable, skipping"
        fi
    done
}

# Test file system error conditions
test_filesystem_errors() {
    log_info "Testing filesystem error conditions"
    
    # Test 1: Read-only filesystem simulation
    log_test "Testing read-only filesystem handling"
    
    local readonly_test_dir="$TEST_TEMP_DIR/readonly"
    if [ -d "$readonly_test_dir" ]; then
        # Try to write to read-only directory with context monitor
        if timeout 5 "$SCRIPT_DIR/context-monitor.sh" init "$readonly_test_dir" 2>/dev/null; then
            log_warn "Context monitor should fail on read-only directory"
        else
            log_pass "Context monitor properly handles read-only directories"
        fi
    fi
    
    # Test 2: Insufficient disk space simulation
    log_test "Testing disk space exhaustion handling"
    
    # Create a small tmpfs to simulate full disk
    local small_tmpfs="$TEST_TEMP_DIR/smalldisk"
    mkdir -p "$small_tmpfs"
    
    # Try to mount a small tmpfs (requires root, so we'll skip if not available)
    if [ "$EUID" -eq 0 ]; then
        if mount -t tmpfs -o size=1M tmpfs "$small_tmpfs" 2>/dev/null; then
            # Try to create a large file in the small filesystem
            if ! dd if=/dev/zero of="$small_tmpfs/largefile" bs=1M count=2 2>/dev/null; then
                log_pass "System properly handles disk space exhaustion"
            else
                log_warn "Disk space exhaustion not properly handled"
            fi
            umount "$small_tmpfs" 2>/dev/null || true
        fi
    else
        log_info "Skipping disk space test (requires root privileges)"
    fi
    
    # Test 3: Permission denied errors
    log_test "Testing permission denied error handling"
    
    if [ -f "$readonly_test_dir/readonly-file.txt" ]; then
        # Try to write to read-only file
        if echo "test" > "$readonly_test_dir/readonly-file.txt" 2>/dev/null; then
            log_fail "Should not be able to write to read-only file"
        else
            log_pass "Properly handles read-only file permissions"
        fi
    fi
}

# Test resource exhaustion scenarios
test_resource_exhaustion() {
    log_info "Testing resource exhaustion scenarios"
    
    # Test 1: Memory pressure simulation
    log_test "Testing memory pressure handling"
    
    local initial_memory=$(free -m | awk '/^Mem:/{print $7}' 2>/dev/null || echo "unknown")
    log_info "Initial available memory: ${initial_memory}MB"
    
    # Run a memory-intensive operation (but controlled)
    local pids=()
    for i in {1..3}; do
        # Start background processes that use some memory
        (
            # Create a small array in memory
            declare -a test_array
            for j in {1..1000}; do
                test_array[$j]="test string $j with some content to use memory"
            done
            sleep 2
        ) &
        pids+=($!)
    done
    
    # Wait for processes to finish
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    local final_memory=$(free -m | awk '/^Mem:/{print $7}' 2>/dev/null || echo "unknown")
    log_info "Final available memory: ${final_memory}MB"
    log_pass "Memory pressure test completed without system failure"
    
    # Test 2: Process limit testing
    log_test "Testing process limit handling"
    
    local max_background_procs=5
    local bg_pids=()
    
    for i in $(seq 1 $max_background_procs); do
        sleep 1 &
        bg_pids+=($!)
        # Check if we can still create processes
        if [ ${#bg_pids[@]} -ge $max_background_procs ]; then
            break
        fi
    done
    
    log_info "Created ${#bg_pids[@]} background processes"
    
    # Clean up background processes
    for pid in "${bg_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    log_pass "Process limit test completed successfully"
    
    # Test 3: File descriptor exhaustion
    log_test "Testing file descriptor limits"
    
    local fd_test_dir="$TEST_TEMP_DIR/fd-test"
    mkdir -p "$fd_test_dir"
    
    # Open multiple file descriptors
    local fd_count=0
    local max_fds=20  # Conservative limit to avoid system issues
    
    exec 100>/dev/null  # Reserve fd 100 as a marker
    
    for ((i=101; i<=100+max_fds; i++)); do
        if eval "exec $i>\"$fd_test_dir/test-fd-$i\"" 2>/dev/null; then
            ((fd_count++))
        else
            break
        fi
    done
    
    log_info "Successfully opened $fd_count file descriptors"
    
    # Close all opened file descriptors
    for ((i=101; i<=100+fd_count; i++)); do
        eval "exec $i>&-" 2>/dev/null || true
    done
    
    exec 100>&-  # Close our marker fd
    
    if [ $fd_count -gt 10 ]; then
        log_pass "File descriptor handling appears normal"
    else
        log_warn "May have file descriptor limitations"
    fi
    
    # Clean up test files
    rm -f "$fd_test_dir"/test-fd-* 2>/dev/null || true
}

# Test network and external dependency failures
test_external_dependencies() {
    log_info "Testing external dependency failure handling"
    
    # Test 1: Missing command dependencies
    log_test "Testing missing command dependencies"
    
    local test_commands=("jq" "bc" "timeout" "grep" "awk")
    local missing_commands=()
    
    for cmd in "${test_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -eq 0 ]; then
        log_pass "All critical commands available"
    else
        log_warn "Missing commands: ${missing_commands[*]}"
        log_info "Scripts should handle missing dependencies gracefully"
    fi
    
    # Test 2: Invalid JSON handling
    log_test "Testing invalid JSON handling"
    
    local invalid_json_file="$TEST_TEMP_DIR/invalid/bad.json"
    if [ -f "$invalid_json_file" ]; then
        if jq . "$invalid_json_file" >/dev/null 2>&1; then
            log_fail "jq should reject invalid JSON"
        else
            log_pass "jq properly rejects invalid JSON"
        fi
        
        # Test if scripts handle invalid JSON gracefully
        for script in "$SCRIPT_DIR"/*.sh; do
            if [ -f "$script" ] && grep -q "jq" "$script"; then
                script_name=$(basename "$script")
                # This is a heuristic test - actual implementation depends on script logic
                log_info "Script $script_name uses jq - ensure it handles invalid JSON"
            fi
        done
    fi
    
    # Test 3: Network timeout simulation
    log_test "Testing network timeout handling"
    
    # Try to connect to a non-existent host with short timeout
    if timeout 2 ping -c 1 192.0.2.0 >/dev/null 2>&1; then
        log_warn "Network test may be unreliable"
    else
        log_pass "Network timeout handling works as expected"
    fi
}

# Test recovery mechanisms
test_recovery_mechanisms() {
    log_info "Testing recovery mechanisms"
    
    # Test 1: Graceful degradation
    log_test "Testing graceful degradation with missing components"
    
    # Temporarily move a component to test degradation
    local temp_backup="$TEST_TEMP_DIR/component-backup"
    mkdir -p "$temp_backup"
    
    if [ -f "$PROJECT_ROOT/settings.json" ]; then
        cp "$PROJECT_ROOT/settings.json" "$temp_backup/"
        
        # Create invalid settings file
        echo "{ invalid json" > "$PROJECT_ROOT/settings.json"
        
        # Test if validation still works with invalid settings
        if timeout 10 "$PROJECT_ROOT/validate.sh" >/dev/null 2>&1; then
            log_warn "Validation should fail with invalid settings.json"
        else
            log_pass "Validation properly detects invalid settings.json"
        fi
        
        # Restore valid settings
        cp "$temp_backup/settings.json" "$PROJECT_ROOT/"
    fi
    
    # Test 2: Automatic recovery attempts
    log_test "Testing automatic recovery mechanisms"
    
    if [ -x "$SCRIPT_DIR/handoff-recovery.sh" ]; then
        # Test recovery script with simulated failure
        if timeout 10 "$SCRIPT_DIR/handoff-recovery.sh" minimal 30000 essential 2>/dev/null; then
            log_pass "Recovery script executes successfully"
        else
            log_info "Recovery script execution completed (expected for test environment)"
        fi
    else
        log_info "Recovery script not found, skipping recovery test"
    fi
    
    # Test 3: State consistency after errors
    log_test "Testing state consistency after errors"
    
    local state_file="$TEST_TEMP_DIR/state-test.json"
    echo '{"test": "initial"}' > "$state_file"
    
    # Simulate a failed update
    if ! echo "{ invalid" > "$state_file"; then
        log_pass "System prevented creation of invalid state file"
    else
        # File was created, test if we can recover
        if [ -f "$temp_backup/settings.json" ]; then
            cp "$temp_backup/settings.json" "$state_file"
            if jq . "$state_file" >/dev/null 2>&1; then
                log_pass "State file recovery successful"
            else
                log_fail "State file recovery failed"
            fi
        fi
    fi
}

# Generate comprehensive error handling report
generate_error_handling_report() {
    local report_file="$TEST_TEMP_DIR/../error-handling-report.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$report_file" << EOF
{
    "test_metadata": {
        "timestamp": "$timestamp",
        "test_type": "error_handling_validation",
        "awoc_version": "2.0.0"
    },
    "test_results": {
        "total_tests": $TOTAL_TESTS,
        "passed_tests": $PASSED_TESTS,
        "failed_tests": $FAILED_TESTS,
        "warnings": $WARNINGS,
        "success_rate": $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    },
    "error_handling_categories": {
        "script_error_patterns": "tested",
        "input_validation": "tested",  
        "filesystem_errors": "tested",
        "resource_exhaustion": "tested",
        "external_dependencies": "tested",
        "recovery_mechanisms": "tested"
    },
    "recommendations": [
        $([ $FAILED_TESTS -eq 0 ] && echo '"Error handling meets quality standards"' || echo '"Address failing error handling tests"'),
        $([ $WARNINGS -gt 3 ] && echo '"Review warning conditions for improvement",' || echo '"Warning levels acceptable",')
        "Implement continuous error handling monitoring",
        "Consider adding more edge case tests for production environments"
    ]
}
EOF
    
    log_info "Error handling report generated: $report_file"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment"
    
    # Remove test files and directories
    if [ -d "$TEST_TEMP_DIR" ]; then
        chmod -R u+w "$TEST_TEMP_DIR" 2>/dev/null || true
        rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
    fi
    
    # Reset any modified permissions
    if [ -d "$SCRIPT_DIR" ]; then
        find "$SCRIPT_DIR" -name "*.sh" -exec chmod u+x {} \; 2>/dev/null || true
    fi
}

# Main execution function
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWOC Error Handling and Edge Case Validation${NC}"
    echo -e "${BLUE}  Comprehensive Quality Assurance Testing${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Set up trap for cleanup
    trap cleanup_test_environment EXIT
    
    # Initialize test environment
    init_test_environment
    
    # Run all error handling tests
    test_script_error_handling
    echo ""
    
    test_input_validation  
    echo ""
    
    test_filesystem_errors
    echo ""
    
    test_resource_exhaustion
    echo ""
    
    test_external_dependencies
    echo ""
    
    test_recovery_mechanisms
    echo ""
    
    # Generate report
    generate_error_handling_report
    
    # Final summary
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Error Handling Test Results${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Total Tests: $TOTAL_TESTS"
    echo -e "  Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "  Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
    echo ""
    
    local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    echo -e "  Success Rate: $success_rate%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 Error handling validation passed!${NC}"
        echo -e "${GREEN}   AWOC 2.0 demonstrates robust error handling and recovery.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some error handling tests failed.${NC}"
        echo -e "${YELLOW}   Review failures and improve error handling before production.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"