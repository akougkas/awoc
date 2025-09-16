# Bug-Fixing Context Primer
*Token Budget: 3000 | Focus: Investigation, Diagnosis, Resolution*

## Investigation Methodology
### Systematic Debugging Approach
1. **Reproduce Issue** - Create minimal test case
2. **Isolate Scope** - Identify affected components
3. **Trace Execution** - Follow code path to failure point
4. **Test Hypothesis** - Validate root cause theories
5. **Implement Fix** - Minimal, targeted solution
6. **Verify Resolution** - Confirm fix + no regressions

### Common Bug Patterns
```bash
# Runtime Errors
- Null/undefined references
- Type mismatches
- Resource exhaustion
- Race conditions
- Permission issues

# Logic Errors  
- Off-by-one errors
- Incorrect conditionals
- Missing edge cases
- State inconsistencies
- Algorithm flaws
```

## Diagnostic Tools & Commands
### System Investigation
```bash
# Process inspection
ps aux | grep <process>
lsof -p <pid>
strace -p <pid>

# Resource monitoring
top -p <pid>
free -h
df -h

# Network issues
netstat -tulpn
ss -tulpn
tcpdump -i <interface>
```

### Code Analysis
```bash
# Static analysis
shellcheck script.sh
pylint file.py
eslint file.js

# Dependency checking
ldd binary
pip check
npm audit

# Version conflicts
which <command>
<command> --version
```

## Error Pattern Recognition
### Log Analysis Patterns
```bash
# Common error signatures
grep -E "(ERROR|FATAL|CRITICAL)" logs/
grep -E "(failed|timeout|refused)" logs/
grep -E "(404|500|502|503)" logs/

# Context extraction
grep -B5 -A5 "error_pattern" logs/
awk '/START/,/END/' logs/
```

### Stack Trace Analysis
```python
# Python debugging
import traceback
import pdb; pdb.set_trace()

# Exception handling
try:
    risky_operation()
except Exception as e:
    print(f"Error: {e}")
    traceback.print_exc()
```

## Testing Strategy for Fixes
### Test-Driven Bug Fixing
```python
def test_bug_reproduction():
    """First: Write test that reproduces the bug"""
    result = buggy_function(edge_case_input)
    assert result == expected_output  # Should fail initially

def test_bug_fixed():
    """After fix: Same test should pass"""
    result = fixed_function(edge_case_input)
    assert result == expected_output  # Should pass after fix
```

### Regression Prevention
```bash
# Run full test suite
pytest tests/
npm test
./validate.sh

# Performance regression checks
time ./script.sh
memory_usage_before=$(ps -o rss= -p $pid)
```

## Quick Fix Templates
### Configuration Issues
```bash
# Environment variables
export VAR_NAME="correct_value"
echo "VAR_NAME=correct_value" >> .env

# File permissions
chmod +x script.sh
chown user:group file

# Path issues
export PATH="$PATH:/new/path"
ln -s /actual/path /expected/path
```

### Dependency Problems
```bash
# Python dependencies
uv add missing_package
uv sync

# System dependencies
sudo apt update && sudo apt install missing_lib
brew install missing_tool
```

## Resolution Documentation
### Change Documentation Template
```markdown
## Bug Fix: [Brief Description]

### Issue
- **Problem**: What was broken
- **Scope**: What was affected
- **Root Cause**: Why it occurred

### Solution
- **Approach**: How it was fixed
- **Changes**: Files/functions modified
- **Testing**: How fix was verified

### Prevention
- **Detection**: How to catch similar issues
- **Monitoring**: What to watch for
- **Process**: Improvements to prevent recurrence
```

### Commit Message Pattern
```bash
git commit -m "fix: [component] - brief description

- Root cause: specific technical reason
- Impact: what was affected
- Solution: how it was resolved
- Testing: verification approach

Fixes #issue_number"
```

## Context-Specific Debugging
### Web Application Bugs
```bash
# Browser debugging
curl -v http://localhost:3000/endpoint
wget --debug http://localhost:3000/endpoint

# Server logs
tail -f /var/log/nginx/error.log
journalctl -fu service_name

# Database issues
mysql -e "SHOW PROCESSLIST;"
psql -c "SELECT * FROM pg_stat_activity;"
```

### Script/CLI Bugs
```bash
# Execution debugging
bash -x script.sh
python -m pdb script.py
node --inspect script.js

# Input/output issues
echo "test input" | ./script.sh
./script.sh < test_input.txt > actual_output.txt
diff expected_output.txt actual_output.txt
```

## Emergency Procedures
### Hotfix Protocol
1. **Create hotfix branch** - `git checkout -b hotfix/critical-issue`
2. **Minimal fix** - Change only what's necessary
3. **Test thoroughly** - Verify fix + no new issues
4. **Fast deployment** - Deploy to staging first
5. **Monitor closely** - Watch for side effects
6. **Document fully** - Record what/why/how

### Rollback Strategy
```bash
# Code rollback
git revert <commit_hash>
git checkout HEAD~1 -- file_with_bug.py

# Service rollback
docker rollback service_name
systemctl stop service && systemctl start service
```

---
**Priming Active**: Bug investigation and resolution patterns loaded. Ready for systematic debugging with enhanced diagnostic capabilities.