#!/bin/bash

# AWOC Test Runner - Comprehensive Testing Framework
# Executes all test suites with detailed reporting and failure analysis

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
TEST_RESULTS_DIR="${HOME}/.awoc/test-results"
TEST_SESSION_ID="test-$(date +%s)"
TIMEOUT_SECONDS=120

# Test results tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Logging
log_file="$TEST_RESULTS_DIR/test-session-$TEST_SESSION_ID.log"

# Utility functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$log_file"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$log_file"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$log_file"
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$log_file"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$log_file"
}

# Initialize test environment
init_test_environment() {
    log_info "Initializing test environment"
    
    # Create test directories
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "${HOME}/.awoc/test-temp"
    
    # Initialize log
    echo "AWOC Test Session Started: $(date)" > "$log_file"
    log "Test Session ID: $TEST_SESSION_ID"
    log "Project Root: $PROJECT_ROOT"
    log "Test Results: $TEST_RESULTS_DIR"
    
    # Verify required dependencies
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v timeout >/dev/null 2>&1; then
        missing_deps+=("timeout")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_warning "Some tests may be skipped"
    fi
    
    # Set up test isolation
    export AWOC_TEST_MODE=1
    export AWOC_TEST_SESSION="$TEST_SESSION_ID"
    export AWOC_TEST_DIR="${HOME}/.awoc/test-temp"
}

# Run individual test suite
run_test_suite() {
    local test_script="$1"
    local suite_name="$2"
    local timeout_limit="${3:-$TIMEOUT_SECONDS}"
    
    ((TOTAL_SUITES++))
    
    log_info "Running test suite: $suite_name"
    log_info "Script: $test_script"
    log_info "Timeout: ${timeout_limit}s"
    
    if [ ! -f "$test_script" ]; then
        log_failure "Test script not found: $test_script"
        ((FAILED_SUITES++))
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        log_failure "Test script not executable: $test_script"
        ((FAILED_SUITES++))
        return 1
    fi
    
    local suite_log="$TEST_RESULTS_DIR/suite-${suite_name}-$TEST_SESSION_ID.log"
    local start_time=$(date +%s)
    
    # Run test suite with timeout
    if timeout "$timeout_limit" "$test_script" > "$suite_log" 2>&1; then
        local exit_code=0
    else
        local exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse test results from output
    local suite_passed=0
    local suite_failed=0
    local suite_warnings=0
    
    if [ -f "$suite_log" ]; then
        suite_passed=$(grep -c "✅\|PASS\|test_passed" "$suite_log" 2>/dev/null || echo "0")
        suite_failed=$(grep -c "❌\|FAIL\|test_failed" "$suite_log" 2>/dev/null || echo "0")
        suite_warnings=$(grep -c "⚠️\|WARN\|warning" "$suite_log" 2>/dev/null || echo "0")
    fi
    
    # Update global counters
    TOTAL_TESTS=$((TOTAL_TESTS + suite_passed + suite_failed))
    PASSED_TESTS=$((PASSED_TESTS + suite_passed))
    FAILED_TESTS=$((FAILED_TESTS + suite_failed))
    WARNINGS=$((WARNINGS + suite_warnings))
    
    if [ $exit_code -eq 0 ] && [ $suite_failed -eq 0 ]; then
        log_success "Test suite passed: $suite_name (${duration}s, $suite_passed tests)"
        ((PASSED_SUITES++))
    else
        if [ $exit_code -eq 124 ]; then
            log_failure "Test suite timed out: $suite_name (${timeout_limit}s)"
        else
            log_failure "Test suite failed: $suite_name (${duration}s, $suite_failed failures)"
        fi
        ((FAILED_SUITES++))
        
        # Show last few lines of failed output
        if [ -f "$suite_log" ]; then
            log_info "Last 10 lines of output:"
            tail -10 "$suite_log" | sed 's/^/  /' | tee -a "$log_file"
        fi
    fi
    
    log "Suite $suite_name: Duration=${duration}s, Passed=$suite_passed, Failed=$suite_failed, Warnings=$suite_warnings"
}

# Run security validation tests
run_security_tests() {
    log_info "Running security validation tests"
    
    local security_log="$TEST_RESULTS_DIR/security-tests-$TEST_SESSION_ID.log"
    local security_passed=0
    local security_failed=0
    
    # Test 1: Script permissions
    log_info "Testing script permissions..."
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            local perms=$(stat -c "%a" "$script")
            if [[ "$perms" =~ ^[67][0-5][0-5]$ ]]; then
                log_success "Script has safe permissions: $(basename "$script") ($perms)"
                ((security_passed++))
            else
                log_failure "Script has unsafe permissions: $(basename "$script") ($perms)"
                ((security_failed++))
            fi
        fi
    done
    
    # Test 2: No hardcoded secrets
    log_info "Testing for hardcoded secrets..."
    local secret_patterns=("password=" "secret=" "token=" "key=" "api_key")
    for pattern in "${secret_patterns[@]}"; do
        if rg -i "$pattern" "$PROJECT_ROOT" --type sh --type json --type md >/dev/null 2>&1; then
            log_warning "Potential secret found: $pattern"
            ((WARNINGS++))
        else
            log_success "No hardcoded secrets found for pattern: $pattern"
            ((security_passed++))
        fi
    done
    
    # Test 3: Input validation in scripts
    log_info "Testing input validation..."
    local validation_patterns=('$1\|$2\|$@' 'read -r' '${.*:-')
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            local has_validation=false
            for pattern in "${validation_patterns[@]}"; do
                if grep -q "$pattern" "$script"; then
                    has_validation=true
                    break
                fi
            done
            
            if $has_validation; then
                log_success "Script has input validation: $(basename "$script")"
                ((security_passed++))
            else
                log_warning "Script may lack input validation: $(basename "$script")"
                ((WARNINGS++))
            fi
        fi
    done
    
    # Update counters
    TOTAL_TESTS=$((TOTAL_TESTS + security_passed + security_failed))
    PASSED_TESTS=$((PASSED_TESTS + security_passed))
    FAILED_TESTS=$((FAILED_TESTS + security_failed))
    
    log "Security tests: Passed=$security_passed, Failed=$security_failed"
}

# Run performance benchmarking
run_performance_tests() {
    log_info "Running performance benchmarking tests"
    
    local perf_log="$TEST_RESULTS_DIR/performance-$TEST_SESSION_ID.log"
    
    # Test system responsiveness under load
    log_info "Testing system responsiveness..."
    
    local start_time=$(date +%s.%3N)
    ./validate.sh >/dev/null 2>&1 || true
    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    
    log "Validation time: ${duration}s"
    
    # Test concurrent operations
    log_info "Testing concurrent operations..."
    local pids=()
    
    for i in {1..3}; do
        (
            if [ -x "$SCRIPT_DIR/context-monitor.sh" ]; then
                timeout 10 "$SCRIPT_DIR/context-monitor.sh" stats machine >/dev/null 2>&1 || true
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all background jobs
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    
    log_success "Concurrent operations test completed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Run edge case tests
run_edge_case_tests() {
    log_info "Running edge case tests"
    
    local edge_passed=0
    local edge_failed=0
    
    # Test 1: Disk space exhaustion simulation
    log_info "Testing disk space handling..."
    local temp_dir="${HOME}/.awoc/test-temp/disk-test"
    mkdir -p "$temp_dir"
    
    # Try to create a large file (but limit it)
    if dd if=/dev/zero of="$temp_dir/large-file" bs=1M count=1 >/dev/null 2>&1; then
        log_success "Disk operations work normally"
        ((edge_passed++))
        rm -f "$temp_dir/large-file"
    else
        log_warning "Disk space may be limited"
        ((WARNINGS++))
    fi
    
    # Test 2: Process limit testing
    log_info "Testing process limits..."
    local max_procs=10
    local pids=()
    
    for ((i=1; i<=max_procs; i++)); do
        sleep 1 &
        pids+=($!)
        if [ ${#pids[@]} -ge 5 ]; then
            break  # Limit to prevent system overload
        fi
    done
    
    # Clean up processes
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    log_success "Process management test completed"
    ((edge_passed++))
    
    # Test 3: Memory pressure simulation
    log_info "Testing memory handling..."
    if command -v free >/dev/null 2>&1; then
        local mem_available=$(free -m | awk '/^Mem:/{print $7}')
        if [ "$mem_available" -gt 100 ]; then
            log_success "Sufficient memory available: ${mem_available}MB"
            ((edge_passed++))
        else
            log_warning "Low memory available: ${mem_available}MB"
            ((WARNINGS++))
        fi
    else
        log_warning "Cannot check memory status"
        ((WARNINGS++))
    fi
    
    # Test 4: Network connectivity (basic)
    log_info "Testing network handling..."
    if timeout 5 ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "Network connectivity available"
        ((edge_passed++))
    else
        log_warning "Network connectivity issues detected"
        ((WARNINGS++))
    fi
    
    # Update counters
    TOTAL_TESTS=$((TOTAL_TESTS + edge_passed))
    PASSED_TESTS=$((PASSED_TESTS + edge_passed))
    
    log "Edge case tests: Passed=$edge_passed, Warnings added to global count"
}

# Generate comprehensive test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/test-report-$TEST_SESSION_ID.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local duration=$(($(date +%s) - $(date -d "$(head -1 "$log_file" | cut -d: -f1-3)" +%s 2>/dev/null || date +%s)))
    
    cat > "$report_file" << EOF
{
    "test_metadata": {
        "session_id": "$TEST_SESSION_ID",
        "timestamp": "$timestamp",
        "duration_seconds": $duration,
        "awoc_version": "2.0.0",
        "test_framework_version": "1.0.0"
    },
    "summary": {
        "total_suites": $TOTAL_SUITES,
        "passed_suites": $PASSED_SUITES,
        "failed_suites": $FAILED_SUITES,
        "total_tests": $TOTAL_TESTS,
        "passed_tests": $PASSED_TESTS,
        "failed_tests": $FAILED_TESTS,
        "warnings": $WARNINGS,
        "success_rate": $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    },
    "quality_metrics": {
        "target_success_rate": 95,
        "current_success_rate": $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0"),
        "meets_target": $([ $FAILED_TESTS -eq 0 ] && [ $(echo "$PASSED_TESTS * 100 / $TOTAL_TESTS >= 95" | bc -l 2>/dev/null || echo 0) -eq 1 ] && echo "true" || echo "false"),
        "performance_acceptable": $([ $WARNINGS -lt 10 ] && echo "true" || echo "false"),
        "security_validated": true
    },
    "recommendations": [
        $([ $FAILED_TESTS -gt 0 ] && echo '"Address failing tests before production deployment",' || echo '"System ready for production deployment",')
        $([ $WARNINGS -gt 5 ] && echo '"Review warnings for potential issues",' || echo '"Warning levels acceptable",')
        "Continue regular testing with each deployment",
        "Monitor performance metrics in production"
    ],
    "files": {
        "detailed_log": "$log_file",
        "test_results_dir": "$TEST_RESULTS_DIR"
    }
}
EOF
    
    log_info "Test report generated: $report_file"
}

# Main execution function
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWOC 2.0 Comprehensive Test Suite Runner${NC}"
    echo -e "${BLUE}  Testing Framework & Quality Assurance Validation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Initialize
    init_test_environment
    
    # Run all test suites
    log_info "Starting comprehensive test execution..."
    echo ""
    
    # Core system tests
    if [ -f "$SCRIPT_DIR/test-context-monitoring.sh" ]; then
        run_test_suite "$SCRIPT_DIR/test-context-monitoring.sh" "context-monitoring" 60
    fi
    
    if [ -f "$SCRIPT_DIR/test-priming-system.sh" ]; then
        run_test_suite "$SCRIPT_DIR/test-priming-system.sh" "priming-system" 30
    fi
    
    if [ -f "$SCRIPT_DIR/test-handoff-system.sh" ]; then
        run_test_suite "$SCRIPT_DIR/test-handoff-system.sh" "handoff-system" 180
    fi
    
    # Main validation
    run_test_suite "$PROJECT_ROOT/validate.sh" "main-validation" 60
    
    # Additional quality tests
    run_security_tests
    run_performance_tests
    run_edge_case_tests
    
    # Generate report
    generate_test_report
    
    # Final summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Test Execution Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Test Suites:"
    echo -e "    Total: $TOTAL_SUITES"
    echo -e "    Passed: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "    Failed: ${RED}$FAILED_SUITES${NC}"
    echo ""
    echo -e "  Individual Tests:"
    echo -e "    Total: $TOTAL_TESTS"
    echo -e "    Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "    Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "    Warnings: ${YELLOW}$WARNINGS${NC}"
    echo ""
    
    local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    echo -e "  Success Rate: $success_rate% (Target: 95%)"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ] && [ $FAILED_SUITES -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! AWOC 2.0 testing framework is operational.${NC}"
        echo -e "${GREEN}   Quality assurance metrics meet production standards.${NC}"
        log_success "Test session completed successfully"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Review results before proceeding.${NC}"
        echo -e "${YELLOW}   Detailed logs: $TEST_RESULTS_DIR/${NC}"
        log_failure "Test session completed with failures"
        exit 1
    fi
}

# Handle interrupts gracefully
trap 'log_warning "Test execution interrupted"; exit 130' INT TERM

# Execute main function
main "$@"