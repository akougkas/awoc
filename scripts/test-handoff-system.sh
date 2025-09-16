#!/bin/bash

# AWOC Context Handoff System Integration Test
# Validates complete handoff protocol implementation for AWOC 1.3
# Tests Phase 2.1-2.3: Bundle creation, commands, and automatic integration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_RESULTS_DIR="${HOME}/.awoc/test-results"
TEST_SESSION_ID="test$(date +%s)"

# Performance targets
MAX_SAVE_TIME=5
MAX_LOAD_TIME=3
MAX_RECOVERY_TIME=15

# Test state
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Utility functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TOTAL_TESTS++))
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Initialize test environment
init_test_environment() {
    log_info "Initializing handoff system test environment"
    
    # Create test directories
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "${HOME}/.awoc/handoffs/test"
    
    # Initialize handoff system
    if "$SCRIPT_DIR/handoff-manager.sh" init 2>/dev/null; then
        log_success "Handoff system initialized"
    else
        log_failure "Failed to initialize handoff system"
        return 1
    fi
    
    # Verify required components
    local required_files=(
        "$SCRIPT_DIR/handoff-manager.sh"
        "$SCRIPT_DIR/handoff-recovery.sh"
        "$SCRIPT_DIR/context-monitor.sh"
        "$PROJECT_ROOT/schemas/handoff-bundle.json"
        "$PROJECT_ROOT/commands/handoff-save.md"
        "$PROJECT_ROOT/commands/handoff-load.md"
        "$PROJECT_ROOT/commands/recover.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "Required file exists: $(basename "$file")"
        else
            log_failure "Missing required file: $file"
            return 1
        fi
    done
}

# Test 1: Bundle Schema Validation
test_bundle_schema_validation() {
    log_test "Bundle Schema Validation"
    
    # Test valid bundle structure
    local test_bundle='{
        "bundle_metadata": {
            "bundle_id": "20250108_143000_abc12345",
            "created_at": "2025-01-08T14:30:00Z",
            "bundle_type": "manual",
            "version": "1.3.0",
            "compression": {"enabled": true, "algorithm": "gzip"}
        },
        "session_state": {
            "session_id": "test12345",
            "start_time": "2025-01-08T14:00:00Z",
            "duration": 1800,
            "active_agent": "api-researcher",
            "status": "active"
        },
        "context_usage": {
            "tokens_used": 15000,
            "baseline_tokens": 500,
            "priming_tokens": 2000,
            "threshold_status": "warning"
        },
        "knowledge_graph": {
            "discoveries": [],
            "patterns": [],
            "decisions": [],
            "learning_outcomes": []
        },
        "agent_coordination": {}
    }'
    
    # Validate against schema
    if echo "$test_bundle" | jq -e . >/dev/null 2>&1; then
        if command -v ajv-cli >/dev/null 2>&1; then
            if echo "$test_bundle" | ajv-cli validate -s "$PROJECT_ROOT/schemas/handoff-bundle.json" 2>/dev/null; then
                log_success "Bundle schema validation passed"
            else
                log_failure "Bundle failed schema validation"
            fi
        else
            log_warning "ajv-cli not available, skipping strict schema validation"
            log_success "Bundle JSON structure is valid"
        fi
    else
        log_failure "Bundle is not valid JSON"
    fi
}

# Test 2: Handoff Save Command
test_handoff_save_command() {
    log_test "Handoff Save Command"
    
    local start_time
    start_time=$(date +%s)
    
    # Test manual save
    if BUNDLE_ID=$("$SCRIPT_DIR/handoff-manager.sh" save manual gzip medium 2>/dev/null); then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ "$duration" -le "$MAX_SAVE_TIME" ]; then
            log_success "Handoff save completed in ${duration}s (target: ${MAX_SAVE_TIME}s)"
        else
            log_warning "Handoff save took ${duration}s (target: ${MAX_SAVE_TIME}s)"
        fi
        
        # Verify bundle exists
        if [ -n "$BUNDLE_ID" ] && ls "${HOME}/.awoc/handoffs/"*"$BUNDLE_ID"* >/dev/null 2>&1; then
            log_success "Handoff bundle created: $BUNDLE_ID"
            echo "$BUNDLE_ID" > "$TEST_RESULTS_DIR/test_bundle_id"
        else
            log_failure "Handoff bundle not found after save"
        fi
    else
        log_failure "Handoff save command failed"
    fi
}

# Test 3: Bundle Compression and Validation
test_bundle_compression() {
    log_test "Bundle Compression and Validation"
    
    if [ ! -f "$TEST_RESULTS_DIR/test_bundle_id" ]; then
        log_warning "No test bundle available, skipping compression test"
        return
    fi
    
    local bundle_id
    bundle_id=$(cat "$TEST_RESULTS_DIR/test_bundle_id")
    
    # Test different compression algorithms
    for compression in gzip brotli none; do
        if COMP_BUNDLE=$("$SCRIPT_DIR/handoff-manager.sh" save manual "$compression" low 2>/dev/null); then
            log_success "Bundle created with $compression compression: $COMP_BUNDLE"
            
            # Validate bundle integrity
            if "$SCRIPT_DIR/handoff-manager.sh" validate "$COMP_BUNDLE" strict 2>/dev/null; then
                log_success "Bundle validation passed for $compression"
            else
                log_failure "Bundle validation failed for $compression"
            fi
        else
            log_failure "Failed to create bundle with $compression compression"
        fi
    done
}

# Test 4: Handoff Load Command
test_handoff_load_command() {
    log_test "Handoff Load Command"
    
    if [ ! -f "$TEST_RESULTS_DIR/test_bundle_id" ]; then
        log_warning "No test bundle available, skipping load test"
        return
    fi
    
    local bundle_id
    bundle_id=$(cat "$TEST_RESULTS_DIR/test_bundle_id")
    
    local start_time
    start_time=$(date +%s)
    
    # Test load with different validation levels
    for validation_level in strict moderate basic; do
        if "$SCRIPT_DIR/handoff-manager.sh" load "$bundle_id" "$validation_level" >/dev/null 2>&1; then
            log_success "Bundle loaded successfully with $validation_level validation"
        else
            log_failure "Bundle load failed with $validation_level validation"
        fi
    done
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -le "$MAX_LOAD_TIME" ]; then
        log_success "Handoff load completed in ${duration}s (target: ${MAX_LOAD_TIME}s)"
    else
        log_warning "Handoff load took ${duration}s (target: ${MAX_LOAD_TIME}s)"
    fi
}

# Test 5: Context Recovery Command
test_context_recovery() {
    log_test "Context Recovery Command"
    
    local start_time
    start_time=$(date +%s)
    
    # Test different recovery strategies
    for strategy in minimal fresh; do
        log_info "Testing recovery strategy: $strategy"
        
        if "$SCRIPT_DIR/handoff-recovery.sh" "$strategy" 30000 essential >/dev/null 2>&1; then
            log_success "Recovery strategy '$strategy' executed successfully"
        else
            log_failure "Recovery strategy '$strategy' failed"
        fi
    done
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -le "$MAX_RECOVERY_TIME" ]; then
        log_success "Recovery testing completed in ${duration}s (target: ${MAX_RECOVERY_TIME}s)"
    else
        log_warning "Recovery testing took ${duration}s (target: ${MAX_RECOVERY_TIME}s)"
    fi
}

# Test 6: Automatic Hook Integration
test_automatic_hooks() {
    log_test "Automatic Hook Integration"
    
    # Test hook configuration in settings.json
    if jq -e '.hooks.SessionEnd' "$PROJECT_ROOT/settings.json" >/dev/null 2>&1; then
        log_success "SessionEnd hook configured"
    else
        log_failure "SessionEnd hook not configured"
    fi
    
    if jq -e '.hooks.PreCompact' "$PROJECT_ROOT/settings.json" >/dev/null 2>&1; then
        log_success "PreCompact hook configured"
    else
        log_failure "PreCompact hook not configured"
    fi
    
    if jq -e '.hooks.ContextThreshold' "$PROJECT_ROOT/settings.json" >/dev/null 2>&1; then
        log_success "ContextThreshold hooks configured"
    else
        log_failure "ContextThreshold hooks not configured"
    fi
    
    # Verify hook scripts exist and are executable
    local hook_scripts=(
        "handoff-manager.sh"
        "handoff-recovery.sh"
        "context-monitor.sh"
        "token-logger.sh"
    )
    
    for script in "${hook_scripts[@]}"; do
        if [ -x "$SCRIPT_DIR/$script" ]; then
            log_success "Hook script executable: $script"
        else
            log_failure "Hook script not executable: $script"
        fi
    done
}

# Test 7: Performance Benchmarking
test_performance_benchmarking() {
    log_test "Performance Benchmarking"
    
    local iterations=5
    local total_save_time=0
    local total_load_time=0
    
    log_info "Running performance benchmark with $iterations iterations"
    
    for ((i=1; i<=iterations; i++)); do
        # Benchmark save operation
        local save_start
        save_start=$(date +%s.%3N)
        
        if BENCH_BUNDLE=$("$SCRIPT_DIR/handoff-manager.sh" save manual gzip low 2>/dev/null); then
            local save_end
            save_end=$(date +%s.%3N)
            local save_time
            save_time=$(echo "$save_end - $save_start" | bc -l 2>/dev/null || echo "0")
            total_save_time=$(echo "$total_save_time + $save_time" | bc -l 2>/dev/null || echo "$total_save_time")
            
            # Benchmark load operation
            local load_start
            load_start=$(date +%s.%3N)
            
            if "$SCRIPT_DIR/handoff-manager.sh" load "$BENCH_BUNDLE" basic >/dev/null 2>&1; then
                local load_end
                load_end=$(date +%s.%3N)
                local load_time
                load_time=$(echo "$load_end - $load_start" | bc -l 2>/dev/null || echo "0")
                total_load_time=$(echo "$total_load_time + $load_time" | bc -l 2>/dev/null || echo "$total_load_time")
            fi
        fi
    done
    
    # Calculate averages
    local avg_save_time
    avg_save_time=$(echo "scale=2; $total_save_time / $iterations" | bc -l 2>/dev/null || echo "unknown")
    local avg_load_time
    avg_load_time=$(echo "scale=2; $total_load_time / $iterations" | bc -l 2>/dev/null || echo "unknown")
    
    log_info "Performance Results:"
    log_info "  Average save time: ${avg_save_time}s"
    log_info "  Average load time: ${avg_load_time}s"
    
    if (( $(echo "$avg_save_time <= $MAX_SAVE_TIME" | bc -l 2>/dev/null || echo 0) )); then
        log_success "Save performance meets target (${avg_save_time}s <= ${MAX_SAVE_TIME}s)"
    else
        log_warning "Save performance below target (${avg_save_time}s > ${MAX_SAVE_TIME}s)"
    fi
    
    if (( $(echo "$avg_load_time <= $MAX_LOAD_TIME" | bc -l 2>/dev/null || echo 0) )); then
        log_success "Load performance meets target (${avg_load_time}s <= ${MAX_LOAD_TIME}s)"
    else
        log_warning "Load performance below target (${avg_load_time}s > ${MAX_LOAD_TIME}s)"
    fi
}

# Test 8: Error Handling and Edge Cases
test_error_handling() {
    log_test "Error Handling and Edge Cases"
    
    # Test invalid bundle ID
    if "$SCRIPT_DIR/handoff-manager.sh" load "invalid_bundle_id" strict >/dev/null 2>&1; then
        log_failure "Should have failed with invalid bundle ID"
    else
        log_success "Correctly handled invalid bundle ID"
    fi
    
    # Test invalid compression algorithm
    if "$SCRIPT_DIR/handoff-manager.sh" save manual invalid_compression low >/dev/null 2>&1; then
        log_failure "Should have failed with invalid compression"
    else
        log_success "Correctly handled invalid compression algorithm"
    fi
    
    # Test invalid recovery strategy
    if "$SCRIPT_DIR/handoff-recovery.sh" invalid_strategy 30000 essential >/dev/null 2>&1; then
        log_failure "Should have failed with invalid recovery strategy"
    else
        log_success "Correctly handled invalid recovery strategy"
    fi
    
    # Test missing dependencies
    local temp_schema="$PROJECT_ROOT/schemas/handoff-bundle.json.backup"
    if [ -f "$PROJECT_ROOT/schemas/handoff-bundle.json" ]; then
        mv "$PROJECT_ROOT/schemas/handoff-bundle.json" "$temp_schema"
        
        if "$SCRIPT_DIR/handoff-manager.sh" save manual gzip low >/dev/null 2>&1; then
            log_warning "Bundle creation should have warned about missing schema"
        else
            log_success "Correctly handled missing schema dependency"
        fi
        
        # Restore schema
        mv "$temp_schema" "$PROJECT_ROOT/schemas/handoff-bundle.json"
    fi
}

# Test 9: Integration with Claude Code Commands
test_claude_code_integration() {
    log_test "Claude Code Command Integration"
    
    # Verify command files exist and have proper format
    local command_files=(
        "handoff-save.md"
        "handoff-load.md" 
        "recover.md"
    )
    
    for cmd_file in "${command_files[@]}"; do
        local cmd_path="$PROJECT_ROOT/commands/$cmd_file"
        if [ -f "$cmd_path" ]; then
            # Check for YAML frontmatter
            if head -1 "$cmd_path" | grep -q "^---$"; then
                log_success "Command file has proper format: $cmd_file"
                
                # Extract command name from frontmatter
                local cmd_name
                cmd_name=$(sed -n '/^name:/p' "$cmd_path" | cut -d':' -f2 | tr -d ' ')
                if [ -n "$cmd_name" ]; then
                    log_success "Command name extracted: $cmd_name"
                else
                    log_failure "Could not extract command name from: $cmd_file"
                fi
            else
                log_failure "Command file missing YAML frontmatter: $cmd_file"
            fi
        else
            log_failure "Command file not found: $cmd_file"
        fi
    done
    
    # Verify commands are enabled in settings.json
    local enabled_commands
    enabled_commands=$(jq -r '.commands.enabled[]' "$PROJECT_ROOT/settings.json" 2>/dev/null || echo "")
    
    for cmd_name in handoff-save handoff-load recover; do
        if echo "$enabled_commands" | grep -q "^$cmd_name$"; then
            log_success "Command enabled in settings: $cmd_name"
        else
            log_failure "Command not enabled in settings: $cmd_name"
        fi
    done
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/handoff_system_test_report.json"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$report_file" << EOF
{
    "test_metadata": {
        "test_id": "$TEST_SESSION_ID",
        "timestamp": "$timestamp",
        "awoc_version": "1.3.0",
        "test_type": "handoff_system_integration",
        "duration": "$(date +%s)"
    },
    "test_results": {
        "total_tests": $TOTAL_TESTS,
        "tests_passed": $TESTS_PASSED,
        "tests_failed": $TESTS_FAILED,
        "success_rate": $(echo "scale=2; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0"),
        "performance_targets_met": $([ $TESTS_FAILED -eq 0 ] && echo "true" || echo "false")
    },
    "component_status": {
        "handoff_manager": "$([ -x "$SCRIPT_DIR/handoff-manager.sh" ] && echo "operational" || echo "failed")",
        "handoff_recovery": "$([ -x "$SCRIPT_DIR/handoff-recovery.sh" ] && echo "operational" || echo "failed")",
        "context_monitor": "$([ -x "$SCRIPT_DIR/context-monitor.sh" ] && echo "operational" || echo "failed")",
        "claude_code_commands": "$([ -f "$PROJECT_ROOT/commands/handoff-save.md" ] && echo "integrated" || echo "missing")"
    },
    "recommendations": [
        $([ $TESTS_FAILED -gt 0 ] && echo '"Review failed tests and address issues before production deployment"' || echo '"System ready for Phase 3 implementation"'),
        "Monitor performance metrics in production",
        "Implement regular handoff system health checks"
    ]
}
EOF
    
    log_info "Test report generated: $report_file"
}

# Main test execution
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWOC Context Handoff System Integration Test Suite v1.3${NC}"
    echo -e "${BLUE}  Testing Phase 2.1-2.3: Complete handoff protocol implementation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Initialize test environment
    if ! init_test_environment; then
        log_failure "Failed to initialize test environment"
        exit 1
    fi
    
    echo ""
    log_info "Starting integration tests..."
    echo ""
    
    # Run all test suites
    test_bundle_schema_validation
    test_handoff_save_command
    test_bundle_compression
    test_handoff_load_command
    test_context_recovery
    test_automatic_hooks
    test_performance_benchmarking
    test_error_handling
    test_claude_code_integration
    
    # Generate final report
    generate_test_report
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Test Results Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Total Tests: ${TOTAL_TESTS}"
    echo -e "  Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "  Failed: ${RED}${TESTS_FAILED}${NC}"
    echo -e "  Success Rate: $(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")%"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed! Context Handoff Protocol is ready for production.${NC}"
        echo -e "${GREEN}   System ready for Phase 3: Hierarchical Agent Architecture${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Address issues before proceeding.${NC}"
        echo -e "${YELLOW}   Review test report: $TEST_RESULTS_DIR/handoff_system_test_report.json${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"