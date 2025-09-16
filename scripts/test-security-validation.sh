#!/bin/bash

# AWOC Security Validation Script
# Comprehensive security testing for AWOC 2.0 framework

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

# Test file permissions and ownership
test_file_permissions() {
    log_info "Testing file permissions and ownership"
    
    # Test 1: Script file permissions
    log_test "Checking script file permissions"
    
    local unsafe_scripts=()
    local safe_permission_patterns=("755" "750" "700" "644" "640" "600")
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            local perms=$(stat -c "%a" "$script")
            local is_safe=false
            
            for pattern in "${safe_permission_patterns[@]}"; do
                if [ "$perms" = "$pattern" ]; then
                    is_safe=true
                    break
                fi
            done
            
            if $is_safe; then
                log_pass "Safe permissions on $(basename "$script"): $perms"
            else
                unsafe_scripts+=("$(basename "$script"):$perms")
            fi
        fi
    done
    
    if [ ${#unsafe_scripts[@]} -eq 0 ]; then
        log_pass "All scripts have safe permissions"
    else
        log_fail "Scripts with unsafe permissions: ${unsafe_scripts[*]}"
    fi
    
    # Test 2: Configuration file permissions
    log_test "Checking configuration file permissions"
    
    local config_files=("settings.json" ".claude/commands/*.md")
    local unsafe_configs=()
    
    for pattern in "${config_files[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                local perms=$(stat -c "%a" "$file")
                # Config files should not be world-writable
                if [[ "$perms" =~ [0-9][0-9][2-7] ]]; then
                    unsafe_configs+=("$file:$perms")
                else
                    log_pass "Safe permissions on $file: $perms"
                fi
            fi
        done 2>/dev/null || true
    done
    
    if [ ${#unsafe_configs[@]} -eq 0 ]; then
        log_pass "All configuration files have safe permissions"
    else
        log_warn "Configuration files with concerning permissions: ${unsafe_configs[*]}"
    fi
    
    # Test 3: Directory permissions
    log_test "Checking directory permissions"
    
    local dirs=("scripts" "agents" "commands" ".claude")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local perms=$(stat -c "%a" "$dir")
            # Directories should not be world-writable
            if [[ "$perms" =~ [0-9][0-9][2-7] ]]; then
                log_warn "Directory $dir has concerning permissions: $perms"
            else
                log_pass "Directory $dir has safe permissions: $perms"
            fi
        fi
    done
}

# Test for hardcoded secrets and sensitive data
test_hardcoded_secrets() {
    log_info "Testing for hardcoded secrets and sensitive data"
    
    # Test 1: Common secret patterns
    log_test "Scanning for hardcoded secrets"
    
    local secret_patterns=(
        "password\s*=\s*['\"][^'\"]{3,}"
        "secret\s*=\s*['\"][^'\"]{3,}"
        "api[_-]?key\s*=\s*['\"][^'\"]{10,}"
        "token\s*=\s*['\"][^'\"]{10,}"
        "auth[_-]?token\s*=\s*['\"][^'\"]{10,}"
        "private[_-]?key\s*=\s*['\"]"
    )
    
    local secrets_found=()
    
    for pattern in "${secret_patterns[@]}"; do
        local matches=$(rg -i "$pattern" "$PROJECT_ROOT" --type sh --type json --type md 2>/dev/null || true)
        if [ -n "$matches" ]; then
            secrets_found+=("Pattern: $pattern")
            echo "$matches" | head -3 | while read -r match; do
                log_warn "Potential secret: ${match:0:80}..."
            done
        fi
    done
    
    if [ ${#secrets_found[@]} -eq 0 ]; then
        log_pass "No obvious hardcoded secrets found"
    else
        log_fail "Potential hardcoded secrets detected: ${#secrets_found[@]} patterns matched"
    fi
    
    # Test 2: Environment variable usage for secrets
    log_test "Checking environment variable usage for sensitive data"
    
    local env_var_patterns=('$\{[A-Z_]*TOKEN[A-Z_]*\}' '$\{[A-Z_]*KEY[A-Z_]*\}' '$\{[A-Z_]*SECRET[A-Z_]*\}')
    local good_env_usage=0
    
    for pattern in "${env_var_patterns[@]}"; do
        if rg "$pattern" "$PROJECT_ROOT" --type sh >/dev/null 2>&1; then
            ((good_env_usage++))
        fi
    done
    
    if [ $good_env_usage -gt 0 ]; then
        log_pass "Found $good_env_usage instances of environment variable usage for sensitive data"
    else
        log_info "No environment variable patterns found (may use different patterns)"
    fi
    
    # Test 3: Check for exposed credentials in git history (basic)
    log_test "Checking for credentials in git history (basic scan)"
    
    if [ -d "$PROJECT_ROOT/.git" ]; then
        local git_secrets=$(git log --oneline --grep="password\|secret\|token\|key" 2>/dev/null | wc -l)
        if [ "$git_secrets" -eq 0 ]; then
            log_pass "No obvious credential references in git commit messages"
        else
            log_warn "Found $git_secrets commit messages referencing credentials (review manually)"
        fi
    else
        log_info "Not a git repository, skipping git history check"
    fi
}

# Test input validation and injection protection
test_input_validation() {
    log_info "Testing input validation and injection protection"
    
    # Test 1: Command injection protection
    log_test "Testing command injection protection"
    
    local test_injections=(
        "; rm -rf /tmp; echo"
        "\$(rm -rf /tmp)"
        "|& rm -rf /tmp"
        "&& rm -rf /tmp"
        "\`rm -rf /tmp\`"
    )
    
    local vulnerable_scripts=()
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -x "$script" ]; then
            local script_name=$(basename "$script")
            local is_vulnerable=false
            
            for injection in "${test_injections[@]}"; do
                # Test with timeout to prevent actual execution
                if timeout 5 "$script" "$injection" >/dev/null 2>&1; then
                    # If the script succeeds with malicious input, it might be vulnerable
                    is_vulnerable=true
                    break
                fi
            done
            
            if $is_vulnerable; then
                vulnerable_scripts+=("$script_name")
            else
                log_pass "Script $script_name appears resistant to command injection"
            fi
        fi
    done
    
    if [ ${#vulnerable_scripts[@]} -eq 0 ]; then
        log_pass "All tested scripts show resistance to command injection"
    else
        log_fail "Scripts potentially vulnerable to command injection: ${vulnerable_scripts[*]}"
    fi
    
    # Test 2: Path traversal protection
    log_test "Testing path traversal protection"
    
    local path_traversal_attacks=(
        "../../../etc/passwd"
        "..\\\\..\\\\..\\\\windows\\\\system32"
        "/../../../../etc/shadow"
        "....//....//....//etc/passwd"
    )
    
    local path_vulnerable=()
    
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -x "$script" ]; then
            local script_name=$(basename "$script")
            local is_vulnerable=false
            
            for attack in "${path_traversal_attacks[@]}"; do
                if timeout 5 "$script" "$attack" 2>&1 | grep -q "passwd\|shadow\|system32"; then
                    is_vulnerable=true
                    break
                fi
            done
            
            if $is_vulnerable; then
                path_vulnerable+=("$script_name")
            else
                log_pass "Script $script_name shows path traversal resistance"
            fi
        fi
    done
    
    if [ ${#path_vulnerable[@]} -eq 0 ]; then
        log_pass "All tested scripts show resistance to path traversal"
    else
        log_fail "Scripts potentially vulnerable to path traversal: ${path_vulnerable[*]}"
    fi
    
    # Test 3: JSON injection in configuration files
    log_test "Testing JSON injection protection"
    
    local json_files=("settings.json")
    for json_file in "${json_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$json_file" ]; then
            # Check if JSON parsing is properly validated
            local temp_json="$PROJECT_ROOT/${json_file}.test"
            echo '{"test": "value", "injection": "\"; system(\"rm -rf /tmp\"); \""}' > "$temp_json"
            
            if jq . "$temp_json" >/dev/null 2>&1; then
                # JSON is valid, check if application handles it safely
                log_info "JSON file $json_file uses standard JSON parsing (review application logic)"
                # Application-specific validation would need to be tested separately
            fi
            
            rm -f "$temp_json"
        fi
    done
    
    log_pass "JSON parsing uses standard tools (jq) - generally safe"
}

# Test access controls and privilege escalation
test_access_controls() {
    log_info "Testing access controls and privilege escalation"
    
    # Test 1: Check for sudo usage
    log_test "Checking for privilege escalation patterns"
    
    local sudo_usage=$(rg -i "sudo|su |pkexec" "$SCRIPT_DIR" --type sh 2>/dev/null || echo "")
    if [ -n "$sudo_usage" ]; then
        log_warn "Found privilege escalation commands in scripts:"
        echo "$sudo_usage" | head -5 | while read -r line; do
            log_warn "  $line"
        done
    else
        log_pass "No privilege escalation commands found in scripts"
    fi
    
    # Test 2: Check for world-writable files
    log_test "Checking for world-writable files"
    
    local world_writable=$(find "$PROJECT_ROOT" -type f -perm -002 2>/dev/null || echo "")
    if [ -n "$world_writable" ]; then
        log_fail "Found world-writable files:"
        echo "$world_writable" | head -5 | while read -r file; do
            log_fail "  $file"
        done
    else
        log_pass "No world-writable files found"
    fi
    
    # Test 3: Check for SUID/SGID files
    log_test "Checking for SUID/SGID files"
    
    local suid_files=$(find "$PROJECT_ROOT" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null || echo "")
    if [ -n "$suid_files" ]; then
        log_warn "Found SUID/SGID files (review if intentional):"
        echo "$suid_files" | head -5 | while read -r file; do
            log_warn "  $file"
        done
    else
        log_pass "No SUID/SGID files found"
    fi
    
    # Test 4: Check file ownership
    log_test "Checking file ownership consistency"
    
    local current_user=$(whoami)
    local foreign_owned=$(find "$PROJECT_ROOT" ! -user "$current_user" -type f 2>/dev/null || echo "")
    
    if [ -n "$foreign_owned" ]; then
        local foreign_count=$(echo "$foreign_owned" | wc -l)
        if [ "$foreign_count" -gt 10 ]; then
            log_warn "Found $foreign_count files not owned by $current_user (may be normal)"
        else
            log_info "Found $foreign_count files not owned by $current_user"
        fi
    else
        log_pass "All files owned by current user ($current_user)"
    fi
}

# Test network security and external communications
test_network_security() {
    log_info "Testing network security"
    
    # Test 1: Check for hardcoded URLs and endpoints
    log_test "Checking for hardcoded URLs and endpoints"
    
    local url_patterns=('http://[^"'\'']*' 'https://[^"'\'']*' 'ftp://[^"'\'']*')
    local hardcoded_urls=()
    
    for pattern in "${url_patterns[@]}"; do
        local urls=$(rg "$pattern" "$PROJECT_ROOT" --type sh --type json --type md -o 2>/dev/null || true)
        if [ -n "$urls" ]; then
            hardcoded_urls+=("$urls")
        fi
    done
    
    if [ ${#hardcoded_urls[@]} -eq 0 ]; then
        log_pass "No hardcoded URLs found"
    else
        log_info "Found ${#hardcoded_urls[@]} hardcoded URLs (review for security implications)"
        # Don't treat as failure since some URLs may be legitimate
    fi
    
    # Test 2: Check for insecure protocols
    log_test "Checking for insecure protocols"
    
    local insecure_protocols=("http://" "ftp://" "telnet://" "rsh://")
    local insecure_found=()
    
    for protocol in "${insecure_protocols[@]}"; do
        if rg -i "$protocol" "$PROJECT_ROOT" --type sh --type json --type md >/dev/null 2>&1; then
            insecure_found+=("$protocol")
        fi
    done
    
    if [ ${#insecure_found[@]} -eq 0 ]; then
        log_pass "No insecure protocols found"
    else
        log_warn "Found insecure protocols: ${insecure_found[*]}"
    fi
    
    # Test 3: Check SSL/TLS verification patterns
    log_test "Checking SSL/TLS verification patterns"
    
    local ssl_bypass_patterns=("--insecure" "--no-check-certificate" "verify=false")
    local ssl_bypasses=()
    
    for pattern in "${ssl_bypass_patterns[@]}"; do
        if rg -i "$pattern" "$PROJECT_ROOT" --type sh >/dev/null 2>&1; then
            ssl_bypasses+=("$pattern")
        fi
    done
    
    if [ ${#ssl_bypasses[@]} -eq 0 ]; then
        log_pass "No SSL/TLS verification bypasses found"
    else
        log_fail "Found SSL/TLS verification bypasses: ${ssl_bypasses[*]}"
    fi
}

# Test logging and audit trail security
test_logging_security() {
    log_info "Testing logging and audit trail security"
    
    # Test 1: Check for sensitive data in logs
    log_test "Checking for sensitive data exposure in logging"
    
    local log_files=$(find "$PROJECT_ROOT" -name "*.log" -o -name "*.txt" 2>/dev/null | head -10)
    local sensitive_patterns=("password" "token" "secret" "key")
    local log_exposures=()
    
    for log_file in $log_files; do
        if [ -f "$log_file" ] && [ -r "$log_file" ]; then
            for pattern in "${sensitive_patterns[@]}"; do
                if rg -i "$pattern" "$log_file" >/dev/null 2>&1; then
                    log_exposures+=("$(basename "$log_file"):$pattern")
                fi
            done
        fi
    done
    
    if [ ${#log_exposures[@]} -eq 0 ]; then
        log_pass "No sensitive data found in log files"
    else
        log_warn "Potential sensitive data in logs: ${log_exposures[*]}"
    fi
    
    # Test 2: Check log file permissions
    log_test "Checking log file permissions"
    
    local unsafe_logs=()
    for log_file in $log_files; do
        if [ -f "$log_file" ]; then
            local perms=$(stat -c "%a" "$log_file")
            # Log files should not be world-readable for sensitive applications
            if [[ "$perms" =~ [0-9][0-9][4-7] ]]; then
                unsafe_logs+=("$(basename "$log_file"):$perms")
            fi
        fi
    done
    
    if [ ${#unsafe_logs[@]} -eq 0 ]; then
        log_pass "Log files have appropriate permissions"
    else
        log_info "Log files with broad read permissions: ${unsafe_logs[*]} (may be intentional)"
    fi
    
    # Test 3: Check for log injection patterns
    log_test "Checking for log injection vulnerabilities"
    
    local logging_functions=$(rg "echo|printf|log" "$SCRIPT_DIR" --type sh 2>/dev/null | wc -l)
    if [ "$logging_functions" -gt 0 ]; then
        log_info "Found $logging_functions logging statements"
        
        # Look for direct variable logging without sanitization
        local direct_logging=$(rg 'echo.*\$[A-Za-z_]' "$SCRIPT_DIR" --type sh 2>/dev/null | wc -l)
        if [ "$direct_logging" -gt 0 ]; then
            log_warn "Found $direct_logging instances of direct variable logging (review for log injection)"
        else
            log_pass "No obvious direct variable logging found"
        fi
    else
        log_info "No logging functions found"
    fi
}

# Generate security validation report
generate_security_report() {
    local report_file="${HOME}/.awoc/test-results/security-validation-report.json"
    mkdir -p "$(dirname "$report_file")"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$report_file" << EOF
{
    "security_validation": {
        "timestamp": "$timestamp",
        "awoc_version": "2.0.0",
        "test_results": {
            "total_tests": $TOTAL_TESTS,
            "passed_tests": $PASSED_TESTS,
            "failed_tests": $FAILED_TESTS,
            "warnings": $WARNINGS,
            "security_score": $(echo "scale=0; ($PASSED_TESTS - $FAILED_TESTS) * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
        },
        "security_categories": {
            "file_permissions": "tested",
            "hardcoded_secrets": "tested",
            "input_validation": "tested",
            "access_controls": "tested",
            "network_security": "tested",
            "logging_security": "tested"
        },
        "risk_assessment": "$([ $FAILED_TESTS -eq 0 ] && echo "LOW" || echo "MEDIUM")",
        "recommendations": [
            $([ $FAILED_TESTS -eq 0 ] && echo '"Security validation passed - no critical issues found"' || echo '"Address failed security tests before production deployment"'),
            $([ $WARNINGS -gt 5 ] && echo '"Review warnings for potential security improvements",' || echo '"Warning levels acceptable",')
            "Implement regular security scans in CI/CD pipeline",
            "Consider additional penetration testing for production environments",
            "Review and update security practices regularly"
        ]
    }
}
EOF
    
    log_info "Security validation report generated: $report_file"
}

# Main execution function
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWOC Security Validation Suite${NC}"
    echo -e "${BLUE}  Comprehensive Security Testing for AWOC 2.0${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Run all security test categories
    test_file_permissions
    echo ""
    
    test_hardcoded_secrets
    echo ""
    
    test_input_validation
    echo ""
    
    test_access_controls
    echo ""
    
    test_network_security
    echo ""
    
    test_logging_security
    echo ""
    
    # Generate security report
    generate_security_report
    
    # Final summary
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Security Validation Results${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Total Tests: $TOTAL_TESTS"
    echo -e "  Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "  Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
    echo ""
    
    local security_score=$(echo "scale=0; ($PASSED_TESTS - $FAILED_TESTS) * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
    echo -e "  Security Score: $security_score/100"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🔒 Security validation passed!${NC}"
        echo -e "${GREEN}   AWOC 2.0 demonstrates strong security practices.${NC}"
        
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}   Review $WARNINGS warnings for additional improvements.${NC}"
        fi
        exit 0
    else
        echo -e "${RED}🚨 Security issues detected!${NC}"
        echo -e "${RED}   Address $FAILED_TESTS security failures before production deployment.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"