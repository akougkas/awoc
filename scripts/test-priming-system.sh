#!/bin/bash

# Test script for dynamic priming system
# Validates that all priming scenarios are accessible and well-formed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}🧪 Testing AWOC Priming System${NC}"
echo "Project root: $PROJECT_ROOT"
echo

# Test scenarios
SCENARIOS=("bug-fixing" "feature-dev" "research" "api-integration")
PRIMING_DIR="$PROJECT_ROOT/.claude/commands/priming"
PRIME_COMMAND="$PROJECT_ROOT/.claude/commands/prime-dev.md"

# Check if main prime-dev command exists
echo -e "${BLUE}📋 Testing main prime-dev command...${NC}"
if [ -f "$PRIME_COMMAND" ]; then
    echo -e "${GREEN}✅ prime-dev.md found${NC}"
else
    echo -e "${RED}❌ prime-dev.md not found at $PRIME_COMMAND${NC}"
    exit 1
fi

# Check if priming directory exists
echo -e "${BLUE}📁 Testing priming directory...${NC}"
if [ -d "$PRIMING_DIR" ]; then
    echo -e "${GREEN}✅ Priming directory found${NC}"
else
    echo -e "${RED}❌ Priming directory not found at $PRIMING_DIR${NC}"
    exit 1
fi

# Test each scenario
echo -e "${BLUE}🔍 Testing individual scenarios...${NC}"
for scenario in "${SCENARIOS[@]}"; do
    scenario_file="$PRIMING_DIR/prime-$scenario.md"
    
    if [ -f "$scenario_file" ]; then
        echo -e "${GREEN}  ✅ $scenario scenario found${NC}"
        
        # Check file is not empty
        if [ -s "$scenario_file" ]; then
            echo -e "${GREEN}    📄 Contains content${NC}"
        else
            echo -e "${RED}    ❌ File is empty${NC}"
        fi
        
        # Check for proper markdown structure
        if grep -q "^#" "$scenario_file"; then
            echo -e "${GREEN}    📝 Has markdown headers${NC}"
        else
            echo -e "${YELLOW}    ⚠️  No markdown headers found${NC}"
        fi
        
        # Count approximate tokens (rough estimate: ~4 chars per token)
        word_count=$(wc -w < "$scenario_file")
        estimated_tokens=$((word_count * 4 / 3))
        if [ $estimated_tokens -gt 1000 ] && [ $estimated_tokens -lt 5000 ]; then
            echo -e "${GREEN}    🎯 Token estimate: ~$estimated_tokens (reasonable)${NC}"
        else
            echo -e "${YELLOW}    ⚠️  Token estimate: ~$estimated_tokens (check size)${NC}"
        fi
        
    else
        echo -e "${RED}  ❌ $scenario scenario not found at $scenario_file${NC}"
    fi
    echo
done

# Test syntax of prime-dev command
echo -e "${BLUE}📋 Testing prime-dev command structure...${NC}"

# Check for required frontmatter
if grep -q "^---" "$PRIME_COMMAND" && grep -q "^name: prime-dev" "$PRIME_COMMAND"; then
    echo -e "${GREEN}✅ Valid Claude Code command structure${NC}"
else
    echo -e "${RED}❌ Invalid command frontmatter${NC}"
fi

# Check for argument handling
if grep -q "ARGUMENTS_0" "$PRIME_COMMAND"; then
    echo -e "${GREEN}✅ Argument handling present${NC}"
else
    echo -e "${YELLOW}⚠️  No argument handling found${NC}"
fi

# Check for scenario validation
if grep -q "Invalid scenario" "$PRIME_COMMAND"; then
    echo -e "${GREEN}✅ Scenario validation present${NC}"
else
    echo -e "${YELLOW}⚠️  No scenario validation found${NC}"
fi

# Test list-priming command if exists
echo -e "${BLUE}📋 Testing list-priming command...${NC}"
LIST_COMMAND="$PROJECT_ROOT/.claude/commands/list-priming.md"
if [ -f "$LIST_COMMAND" ]; then
    echo -e "${GREEN}✅ list-priming command found${NC}"
else
    echo -e "${YELLOW}⚠️  list-priming command not found (optional)${NC}"
fi

# Test context monitoring integration
echo -e "${BLUE}🔍 Testing context monitoring integration...${NC}"
CONTEXT_MONITOR="$PROJECT_ROOT/scripts/context-monitor.sh"
if [ -f "$CONTEXT_MONITOR" ]; then
    echo -e "${GREEN}✅ Context monitor found${NC}"
    
    # Check if it has log_priming function
    if grep -q "log_priming" "$CONTEXT_MONITOR"; then
        echo -e "${GREEN}✅ log_priming function available${NC}"
    else
        echo -e "${YELLOW}⚠️  log_priming function not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Context monitor not found (priming will still work)${NC}"
fi

echo
echo -e "${GREEN}🎉 Priming system test completed!${NC}"
echo
echo -e "${BLUE}Usage examples:${NC}"
echo "  /prime-dev bug-fixing      # Load bug-fixing context"
echo "  /prime-dev feature-dev     # Load feature development context"
echo "  /prime-dev research 2500   # Load research context with custom budget"
echo "  /list-priming              # Show all available scenarios"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Install AWOC to test in Claude Code: ./install.sh"
echo "2. Test priming commands in Claude Code interface"
echo "3. Verify context monitoring integration"
echo "4. Use with AWOC agents for enhanced capabilities"