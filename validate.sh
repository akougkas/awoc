#!/bin/bash

# AWOC Validation Script
# Tests that the installation is working correctly

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation results
VALIDATION_PASSED=0
VALIDATION_FAILED=0
WARNINGS=0

# Logging
LOG_FILE="${HOME}/.awoc-validation.log"

# Helper functions
log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    log "ERROR: $1"
    ((VALIDATION_FAILED++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
    log "WARNING: $1"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
    ((VALIDATION_PASSED++))
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO: $1"
}

# Validate file exists and is readable
validate_file() {
    local file="$1"
    local description="${2:-File}"

    if [ ! -f "$file" ]; then
        error "$description not found: $file"
        return 1
    fi

    if [ ! -r "$file" ]; then
        error "$description not readable: $file"
        return 1
    fi

    success "$description found: $file"
    return 0
}

# Validate directory exists and is accessible
validate_directory() {
    local dir="$1"
    local description="${2:-Directory}"

    if [ ! -d "$dir" ]; then
        error "$description not found: $dir"
        return 1
    fi

    if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
        error "$description not accessible: $dir"
        return 1
    fi

    success "$description accessible: $dir"
    return 0
}

# Validate JSON file
validate_json() {
    local file="$1"

    if ! command -v jq &> /dev/null; then
        warning "jq not found - skipping detailed JSON validation for $file"
        return 0
    fi

    if ! jq . "$file" > /dev/null 2>&1; then
        error "$file contains invalid JSON"
        return 1
    fi

    success "$file contains valid JSON"
    return 0
}

# Validate YAML frontmatter
validate_yaml_frontmatter() {
    local file="$1"
    local expected_fields=("${@:2}")

    # Check if file has YAML frontmatter
    if ! head -1 "$file" | grep -q "^---$"; then
        warning "$file does not have YAML frontmatter"
        return 1
    fi

    # Extract frontmatter
    local frontmatter=""
    local in_frontmatter=false
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))
        if [ "$line" = "---" ]; then
            if [ "$in_frontmatter" = true ]; then
                break
            else
                in_frontmatter=true
                continue
            fi
        fi

        if [ "$in_frontmatter" = true ]; then
            frontmatter+="$line"$'\n'
        fi
    done < "$file"

    # Check for required fields
    local missing_fields=()
    for field in "${expected_fields[@]}"; do
        if ! echo "$frontmatter" | grep -q "^${field}:"; then
            missing_fields+=("$field")
        fi
    done

    if [ ${#missing_fields[@]} -gt 0 ]; then
        error "$file missing required YAML fields: ${missing_fields[*]}"
        return 1
    fi

    success "$file has valid YAML frontmatter"
    return 0
}

# Validate executable
validate_executable() {
    local file="$1"
    local description="${2:-Executable}"

    if [ ! -f "$file" ]; then
        error "$description not found: $file"
        return 1
    fi

    if [ ! -x "$file" ]; then
        warning "$description not executable: $file"
        return 1
    fi

    success "$description is executable: $file"
    return 0
}

# Main validation function
main() {
    echo -e "${BLUE}🔍 Validating AWOC installation...${NC}"
    echo "Validation log: $LOG_FILE"
    log "AWOC Validation started"

    # Initialize log
    echo "$(date): AWOC Validation started" > "$LOG_FILE"

    # Check if we're in the right directory
    if [ ! -f "settings.json" ]; then
        error "Not in AWOC directory. Run from AWOC installation directory."
        echo -e "${YELLOW}Expected files:${NC}"
        echo "  - settings.json"
        echo "  - agents/ directory"
        echo "  - commands/ directory"
        echo "  - output-styles/ directory"
        exit 1
    fi

    info "AWOC directory detected"

    # Validate core directories
    validate_directory "agents" "Agents directory"
    validate_directory "commands" "Commands directory"
    validate_directory "output-styles" "Output styles directory"
    validate_directory "templates" "Templates directory" || warning "Templates directory missing - some features may not work"

    # Validate core files
    validate_file "settings.json" "Settings configuration"
    validate_json "settings.json"

    # Validate agents
    info "Validating agents..."
    local agent_files=("agents/api-researcher.md" "agents/content-writer.md" "agents/data-analyst.md" "agents/project-manager.md" "agents/learning-assistant.md" "agents/creative-assistant.md")

    for agent_file in "${agent_files[@]}"; do
        if validate_file "$agent_file" "Agent file"; then
            validate_yaml_frontmatter "$agent_file" "name" "description" "tools" "model"
        fi
    done

    # Validate commands
    info "Validating commands..."
    local command_files=("commands/session-start.md" "commands/session-end.md")

    for command_file in "${command_files[@]}"; do
        if validate_file "$command_file" "Command file"; then
            validate_yaml_frontmatter "$command_file" "name" "description" "argument-hint" "allowed-tools"
        fi
    done

    # Validate output styles
    info "Validating output styles..."
    local output_files=("output-styles/development.md")

    for output_file in "${output_files[@]}"; do
        if validate_file "$output_file" "Output style file"; then
            validate_yaml_frontmatter "$output_file" "name" "description"
        fi
    done

    # Validate scripts
    info "Validating scripts..."
    validate_file "install.sh" "Installation script"
    validate_file "validate.sh" "Validation script"
    validate_executable "awoc" "AWOC command" || warning "AWOC command not properly installed"

    # Validate templates
    info "Validating templates..."
    local template_files=("templates/agent-template.md" "templates/command-template.md" "templates/settings-template.json")

    for template_file in "${template_files[@]}"; do
        validate_file "$template_file" "Template file" || warning "Template missing: $template_file"
    done

    # Validate scripts directory
    if [ -d "scripts" ]; then
        validate_executable "scripts/generate-template.sh" "Template generator" || warning "Template generator not executable"
    fi

    # Summary
    echo ""
    echo -e "${BLUE}📊 Validation Summary:${NC}"
    echo "✅ Passed: $VALIDATION_PASSED"
    echo "❌ Failed: $VALIDATION_FAILED"
    echo "⚠️  Warnings: $WARNINGS"

    if [ $VALIDATION_FAILED -gt 0 ]; then
        echo ""
        echo -e "${RED}❌ Validation failed!${NC}"
        echo "Check the log file for details: $LOG_FILE"
        echo ""
        echo -e "${YELLOW}Common fixes:${NC}"
        echo "1. Run './install.sh' to reinstall AWOC"
        echo "2. Check file permissions: chmod +x *.sh"
        echo "3. Verify all required files are present"
        exit 1
    else
        echo ""
        echo -e "${GREEN}🎉 AWOC validation complete!${NC}"
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}Some optional features may not work correctly.${NC}"
        fi
        echo ""
        echo "Next steps:"
        echo "1. Test with: awoc session start \"Test session\""
        echo "2. Verify git integration works"
        echo "3. Explore available agents: awoc help"
    fi

    log "AWOC Validation completed - Passed: $VALIDATION_PASSED, Failed: $VALIDATION_FAILED, Warnings: $WARNINGS"
}

# Run validation
main "$@"