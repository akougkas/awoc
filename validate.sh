#!/bin/bash

# AWOC Validation Script
# Tests that the installation is working correctly

set -e

echo "🔍 Validating AWOC installation..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if we're in the right directory
if [ ! -f "settings.json" ]; then
    echo -e "${RED}❌ Error: Not in AWOC directory. Run from AWOC installation directory.${NC}"
    exit 1
fi

# Check required files
REQUIRED_FILES=("settings.json" "agents/api-researcher.md" "commands/session-start.md" "commands/session-end.md" "output-styles/development.md")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file found${NC}"
    else
        echo -e "${RED}❌ $file missing${NC}"
        exit 1
    fi
done

# Check JSON syntax
if command -v jq &> /dev/null; then
    if jq . settings.json > /dev/null 2>&1; then
        echo -e "${GREEN}✅ settings.json is valid JSON${NC}"
    else
        echo -e "${RED}❌ settings.json has invalid JSON syntax${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  jq not found - skipping JSON validation${NC}"
fi

# Check if awoc command exists
if [ -f "awoc" ] && [ -x "awoc" ]; then
    echo -e "${GREEN}✅ awoc command is executable${NC}"
else
    echo -e "${YELLOW}⚠️  awoc command not found or not executable${NC}"
fi

echo ""
echo -e "${GREEN}🎉 AWOC validation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Run './install.sh' to install AWOC"
echo "2. Test with: awoc session start \"Test session\""
echo "3. Verify git integration works"