#!/bin/bash

# AWOC Template Generator
# Generates new components from standardized templates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"
OUTPUT_DIR="$SCRIPT_DIR/.."

# Helper functions
print_usage() {
    echo -e "${BLUE}AWOC Template Generator${NC}"
    echo ""
    echo "Usage: $0 [type] [name] [options]"
    echo ""
    echo "Types:"
    echo "  agent       Create a new agent"
    echo "  command     Create a new command"
    echo "  settings    Create a new settings configuration"
    echo ""
    echo "Options:"
    echo "  -d, --description TEXT    Description for the component"
    echo "  -c, --category TEXT       Category for the component"
    echo "  -t, --tools TEXT          Comma-separated list of tools (for agents)"
    echo "  -f, --force               Overwrite existing files"
    echo "  -h, --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 agent my-agent -d 'My custom agent'"
    echo "  $0 command my-command -d 'My custom command'"
    echo "  $0 settings my-project"
}

print_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validate inputs
validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        print_error "Name must start with lowercase letter and contain only lowercase letters, numbers, and hyphens"
        exit 1
    fi
}

# Generate agent from template
generate_agent() {
    local name="$1"
    local description="${2:-"Custom agent for $name"}"
    local category="${3:-research}"
    local tools="${4:-Read,Write,Grep}"
    local output_file="$OUTPUT_DIR/agents/$name.md"

    print_info "Generating agent: $name"

    # Check if template exists
    if [ ! -f "$TEMPLATE_DIR/agent-template.md" ]; then
        print_error "Agent template not found at $TEMPLATE_DIR/agent-template.md"
        exit 1
    fi

    # Check if output file exists
    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        print_error "Agent file already exists: $output_file"
        print_info "Use --force to overwrite"
        exit 1
    fi

    # Generate agent from template
    sed -e "s/agent-name/$name/g" \
        -e "s/\[Role Title\]/$name Agent/g" \
        -e "s/Brief description of agent's primary function and value proposition/$description/g" \
        -e "s/Tool1, Tool2, Tool3/$tools/g" \
        "$TEMPLATE_DIR/agent-template.md" > "$output_file"

    print_success "Agent generated: $output_file"
}

# Generate command from template
generate_command() {
    local name="$1"
    local description="${2:-"Custom command for $name"}"
    local output_file="$OUTPUT_DIR/commands/$name.md"

    print_info "Generating command: $name"

    # Check if template exists
    if [ ! -f "$TEMPLATE_DIR/command-template.md" ]; then
        print_error "Command template not found at $TEMPLATE_DIR/command-template.md"
        exit 1
    fi

    # Check if output file exists
    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        print_error "Command file already exists: $output_file"
        print_info "Use --force to overwrite"
        exit 1
    fi

    # Generate command from template
    sed -e "s/command-name/$name/g" \
        -e "s/\[Command Display Name\]/$name/g" \
        -e "s/Brief description of what this command does and when to use it/$description/g" \
        "$TEMPLATE_DIR/command-template.md" > "$output_file"

    print_success "Command generated: $output_file"
}

# Generate settings from template
generate_settings() {
    local name="$1"
    local output_file="$OUTPUT_DIR/$name-settings.json"

    print_info "Generating settings configuration: $name"

    # Check if template exists
    if [ ! -f "$TEMPLATE_DIR/settings-template.json" ]; then
        print_error "Settings template not found at $TEMPLATE_DIR/settings-template.json"
        exit 1
    fi

    # Check if output file exists
    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        print_error "Settings file already exists: $output_file"
        print_info "Use --force to overwrite"
        exit 1
    fi

    # Copy template
    cp "$TEMPLATE_DIR/settings-template.json" "$output_file"

    print_success "Settings generated: $output_file"
}

# Main script logic
main() {
    local type=""
    local name=""
    local description=""
    local category=""
    local tools=""
    local force="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            agent|command|settings)
                type="$1"
                shift
                name="$1"
                shift
                ;;
            -d|--description)
                description="$2"
                shift 2
                ;;
            -c|--category)
                category="$2"
                shift 2
                ;;
            -t|--tools)
                tools="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$type" ] || [ -z "$name" ]; then
        print_error "Type and name are required"
        print_usage
        exit 1
    fi

    # Validate name format
    validate_name "$name"

    # Create output directories if they don't exist
    mkdir -p "$OUTPUT_DIR/agents"
    mkdir -p "$OUTPUT_DIR/commands"

    # Generate component based on type
    case $type in
        agent)
            generate_agent "$name" "$description" "$category" "$tools"
            ;;
        command)
            generate_command "$name" "$description"
            ;;
        settings)
            generate_settings "$name"
            ;;
        *)
            print_error "Unknown type: $type"
            print_usage
            exit 1
            ;;
    esac

    print_success "Template generation complete!"
}

# Run main function with all arguments
main "$@"
