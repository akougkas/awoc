#!/bin/bash

# Test script for context monitoring infrastructure
# Validates that both context-monitor.sh and token-logger.sh work correctly

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}🧪 Testing AWOC Context Monitoring Infrastructure${NC}"
echo "=================================================="
echo ""

# Helper functions
test_passed() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

test_failed() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

test_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Test 1: Scripts exist and are executable
test_info "Testing script availability..."

if [ -x "./scripts/context-monitor.sh" ]; then
    test_passed "Context monitor script exists and is executable"
else
    test_failed "Context monitor script not found or not executable"
fi

if [ -x "./scripts/token-logger.sh" ]; then
    test_passed "Token logger script exists and is executable"
else
    test_failed "Token logger script not found or not executable"
fi

# Test 2: Initialization
test_info "Testing initialization..."

if ./scripts/context-monitor.sh init >/dev/null 2>&1; then
    test_passed "Context monitor initializes successfully"
else
    test_failed "Context monitor initialization failed"
fi

if ./scripts/token-logger.sh init >/dev/null 2>&1; then
    test_passed "Token logger initializes successfully"
else
    test_failed "Token logger initialization failed"
fi

# Test 3: Directory structure created
test_info "Testing directory structure..."

if [ -d "${HOME}/.awoc/context" ]; then
    test_passed "Context directory created"
else
    test_failed "Context directory not created"
fi

if [ -d "${HOME}/.awoc/context/logs" ]; then
    test_passed "Logs directory created"
else
    test_failed "Logs directory not created"
fi

# Test 4: Configuration files
test_info "Testing configuration files..."

if [ -f "${HOME}/.awoc/context/monitor.json" ]; then
    test_passed "Monitor configuration file created"
else
    test_failed "Monitor configuration file not created"
fi

if [ -f "${HOME}/.awoc/context/budgets.json" ]; then
    test_passed "Budget configuration file created"
else
    test_failed "Budget configuration file not created"
fi

# Test 5: Basic functionality
test_info "Testing basic functionality..."

# Test context tracking with timeout
if timeout 10 ./scripts/context-monitor.sh track test-agent test-operation 1000 test >/dev/null 2>&1; then
    test_passed "Context tracking works"
else
    test_failed "Context tracking failed or timed out"
fi

# Test token logging with timeout
if timeout 10 ./scripts/token-logger.sh log test-agent test-operation 1000 test user >/dev/null 2>&1; then
    test_passed "Token logging works"
else
    test_failed "Token logging failed or timed out"
fi

# Test 6: Statistics and reporting
test_info "Testing statistics and reporting..."

# Test context stats with timeout
if timeout 10 ./scripts/context-monitor.sh stats human >/dev/null 2>&1; then
    test_passed "Context statistics generation works"
else
    test_failed "Context statistics generation failed or timed out"
fi

# Test budget status with timeout
if timeout 10 ./scripts/token-logger.sh budget >/dev/null 2>&1; then
    test_passed "Budget status reporting works"
else
    test_failed "Budget status reporting failed or timed out"
fi

# Test report generation with timeout
if timeout 10 ./scripts/token-logger.sh report human today >/dev/null 2>&1; then
    test_passed "Token usage reporting works"
else
    test_failed "Token usage reporting failed or timed out"
fi

# Test 7: JSON validation
test_info "Testing JSON configuration validation..."

if command -v jq >/dev/null 2>&1; then
    # Validate monitor config
    if jq . "${HOME}/.awoc/context/monitor.json" >/dev/null 2>&1; then
        test_passed "Monitor configuration is valid JSON"
    else
        test_failed "Monitor configuration is invalid JSON"
    fi
    
    # Validate budget config
    if jq . "${HOME}/.awoc/context/budgets.json" >/dev/null 2>&1; then
        test_passed "Budget configuration is valid JSON"
    else
        test_failed "Budget configuration is invalid JSON"
    fi
    
    # Validate settings.json
    if jq . "settings.json" >/dev/null 2>&1; then
        test_passed "Settings.json is valid JSON"
    else
        test_failed "Settings.json is invalid JSON"
    fi
else
    echo -e "${YELLOW}⚠️  jq not available - skipping JSON validation${NC}"
fi

# Test 8: Error handling
test_info "Testing error handling..."

# Test invalid token count - should fail gracefully
if timeout 5 ./scripts/context-monitor.sh track test-agent test-operation invalid-tokens 2>/dev/null; then
    test_failed "Context monitor should reject invalid token counts"
else
    test_passed "Context monitor handles invalid token counts gracefully"
fi

# Test nonexistent agent - should handle gracefully
if timeout 5 ./scripts/token-logger.sh log "" test 100 2>/dev/null; then
    test_failed "Token logger should reject empty agent names"
else
    test_passed "Token logger handles invalid agent names gracefully"
fi

# Test edge case: extremely large token count
if timeout 5 ./scripts/context-monitor.sh track test-agent test-operation 999999999 test 2>/dev/null; then
    test_passed "Context monitor handles large token counts"
else
    test_failed "Context monitor fails with large token counts"
fi

# Test edge case: negative token count
if timeout 5 ./scripts/context-monitor.sh track test-agent test-operation -100 test 2>/dev/null; then
    test_failed "Context monitor should reject negative token counts"
else
    test_passed "Context monitor rejects negative token counts"
fi

# Summary
echo ""
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo "======================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Context monitoring infrastructure is ready.${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Please review the output above.${NC}"
    exit 1
fi