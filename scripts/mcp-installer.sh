#!/usr/bin/env bash

# AWOC MCP Installer Script
# Configures Model Context Protocol servers for Claude Code projects
# Run: awoc mcp setup -d /path/to/project

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Icons
readonly CHECK="✅"
readonly CROSS="❌"
readonly INFO="ℹ️"
readonly WARNING="⚠️"

# Configuration
readonly AWOC_CONFIG_DIR="${HOME}/.config/awoc"
readonly MCP_REGISTRY="${AWOC_CONFIG_DIR}/mcp.yaml"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging
log_info() { echo -e "${BLUE}${INFO}${NC} $*"; }
log_success() { echo -e "${GREEN}${CHECK}${NC} $*"; }
log_error() { echo -e "${RED}${CROSS}${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}${WARNING}${NC} $*" >&2; }

# Check prerequisites
check_prerequisites() {
    # Check for MCP registry
    if [[ ! -f "$MCP_REGISTRY" ]]; then
        log_error "MCP registry not found at $MCP_REGISTRY"
        log_info "Run 'awoc update' to get the latest MCP registry"
        exit 1
    fi

    # Check for required tools
    if ! command -v yq &> /dev/null && ! command -v python3 &> /dev/null; then
        log_warning "Neither 'yq' nor 'python3' found. Installing yq is recommended:"
        echo "  brew install yq  # macOS"
        echo "  apt-get install yq  # Ubuntu/Debian"
        echo ""
        log_info "Falling back to basic parsing (limited functionality)"
    fi
}

# Parse YAML (with fallback)
parse_yaml() {
    local file="$1"
    local query="$2"

    if command -v yq &> /dev/null; then
        yq eval "$query" "$file"
    elif command -v python3 &> /dev/null; then
        python3 -c "
import yaml, sys
with open('$file', 'r') as f:
    data = yaml.safe_load(f)
    # Simple query support
    keys = \"$query\".replace('.[', '[').strip('.').split('.')
    result = data
    for key in keys:
        if '[' in key:
            key = key.split('[')[0]
        result = result.get(key, {})
    if isinstance(result, list):
        for item in result:
            print(item)
    elif result:
        print(result)
"
    else
        # Basic grep fallback
        grep -A5 "^[a-z]" "$file" | grep -v "^--$"
    fi
}

# Get list of available MCPs
get_mcp_list() {
    if command -v yq &> /dev/null; then
        yq eval 'keys | .[]' "$MCP_REGISTRY" | grep -v "^#"
    else
        # Fallback: extract top-level keys using awk which is more reliable
        awk '/^[a-zA-Z0-9][a-zA-Z0-9_-]*:/ {sub(/:.*/, ""); print}' "$MCP_REGISTRY"
    fi
}

# Get MCP details
get_mcp_details() {
    local mcp_name="$1"
    local field="$2"
    parse_yaml "$MCP_REGISTRY" ".${mcp_name}.${field}"
}

# Show available MCPs
show_available_mcps() {
    echo ""
    echo -e "${BOLD}Available MCP Servers:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local index=1
    for mcp in $(get_mcp_list); do
        local desc=$(get_mcp_details "$mcp" "description")
        local category=$(get_mcp_details "$mcp" "category")
        echo -e "${BOLD}[$index]${NC} ${BLUE}$mcp${NC} - $desc"
        echo "    Category: $category"
        index=$((index + 1))
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check environment variables
check_env_vars() {
    local mcp_name="$1"
    local env_vars=$(get_mcp_details "$mcp_name" "env_required[].name" 2>/dev/null)

    if [[ -n "$env_vars" ]]; then
        log_info "Checking environment variables for $mcp_name:"
        local missing_vars=""
        for var in $env_vars; do
            # Clean up the variable name
            var=$(echo "$var" | tr -d ' ')
            if [[ -z "${!var:-}" ]]; then
                log_warning "  $var is not set"
                missing_vars="$missing_vars $var"
            else
                log_success "  $var is set"
            fi
        done

        if [[ -n "$missing_vars" ]]; then
            echo ""
            echo "    To set required environment variables:"
            for var in $missing_vars; do
                echo "    export $var='your-value-here'"
            done
            return 1
        fi
    fi
    return 0
}

# Generate .mcp.json for a single MCP
generate_mcp_json_entry() {
    local mcp_name="$1"
    local type=$(get_mcp_details "$mcp_name" "type")

    case "$type" in
        stdio)
            local command=$(get_mcp_details "$mcp_name" "command")

            # Get args as array
            local args_json=""
            local args_raw=$(get_mcp_details "$mcp_name" "args[]")

            if [[ -n "$args_raw" ]]; then
                local first_arg=true
                while IFS= read -r arg; do
                    [[ -z "$arg" ]] && continue
                    if [[ "$first_arg" == "false" ]]; then
                        args_json="${args_json}, "
                    fi
                    # Clean up the arg and quote it properly
                    arg=$(echo "$arg" | tr -d '[]"' | xargs)
                    args_json="${args_json}\"${arg}\""
                    first_arg=false
                done <<< "$args_raw"
            fi

            # Build env object
            local env_json="{}"
            local env_vars=$(get_mcp_details "$mcp_name" "env_required[].name" 2>/dev/null)

            if [[ -n "$env_vars" ]]; then
                env_json="{\n"
                local first=true
                for var in $env_vars; do
                    var=$(echo "$var" | tr -d ' ')
                    if [[ -n "${!var:-}" ]]; then
                        if [[ "$first" == "false" ]]; then
                            env_json="${env_json},\n"
                        fi
                        env_json="${env_json}        \"${var}\": \"${!var}\""
                        first=false
                    fi
                done
                env_json="${env_json}\n      }"
            fi

            cat <<EOF
    "$mcp_name": {
      "command": "$command",
      "args": [${args_json}],
      "env": $env_json
    }
EOF
            ;;
        http)
            local url=$(get_mcp_details "$mcp_name" "url")
            cat <<EOF
    "$mcp_name": {
      "type": "http",
      "url": "$url"
    }
EOF
            ;;
        sse)
            local url=$(get_mcp_details "$mcp_name" "url")
            cat <<EOF
    "$mcp_name": {
      "type": "sse",
      "url": "$url"
    }
EOF
            ;;
    esac
}

# Interactive MCP selection
select_mcps() {
    show_available_mcps >&2

    echo "" >&2
    echo -e "${BOLD}Select MCP servers to enable:${NC}" >&2
    echo "Enter numbers separated by commas (e.g., 1,3,5) or 'all' for all:" >&2
    echo "Press Enter with no selection to skip MCP setup." >&2
    echo "" >&2
    read -p "> " selection

    if [[ -z "$selection" ]]; then
        log_info "Skipping MCP setup" >&2
        return 1
    fi

    local mcp_list=($(get_mcp_list))
    local selected_mcps=()

    if [[ "$selection" == "all" ]]; then
        selected_mcps=("${mcp_list[@]}")
    else
        IFS=',' read -ra selections <<< "$selection"
        for sel in "${selections[@]}"; do
            sel=$(echo "$sel" | tr -d ' ')
            if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel > 0 && sel <= ${#mcp_list[@]} )); then
                selected_mcps+=("${mcp_list[$((sel-1))]}")
            fi
        done
    fi

    # Only output the selected MCPs to stdout
    printf '%s\n' "${selected_mcps[@]}"
}

# Generate .mcp.json file
generate_mcp_json() {
    local project_dir="$1"
    shift
    local mcps=("$@")

    local mcp_file="${project_dir}/.claude/.mcp.json"

    # Start JSON
    echo "{" > "$mcp_file"
    echo '  "mcpServers": {' >> "$mcp_file"

    # Add each MCP
    local first=true
    for mcp in "${mcps[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo "," >> "$mcp_file"
        fi
        generate_mcp_json_entry "$mcp" >> "$mcp_file"
        first=false
    done

    # Close JSON
    echo "" >> "$mcp_file"
    echo "  }" >> "$mcp_file"
    echo "}" >> "$mcp_file"

    log_success "Generated $mcp_file"
}

# Generate .env.template
generate_env_template() {
    local project_dir="$1"
    shift
    local mcps=("$@")

    local env_file="${project_dir}/.env.template"
    local has_env_vars=false

    echo "# AWOC MCP Environment Variables" > "$env_file"
    echo "# Copy to .env and fill in your values" >> "$env_file"
    echo "" >> "$env_file"

    for mcp in "${mcps[@]}"; do
        local env_vars=$(get_mcp_details "$mcp" "env_required[].name" 2>/dev/null)
        if [[ -n "$env_vars" ]]; then
            has_env_vars=true
            echo "# === $mcp ===" >> "$env_file"
            local setup_notes=$(get_mcp_details "$mcp" "setup_notes" 2>/dev/null)
            [[ -n "$setup_notes" ]] && echo "# $setup_notes" >> "$env_file"
            while IFS= read -r var; do
                [[ -z "$var" ]] && continue
                var=$(echo "$var" | tr -d ' ')
                echo "${var}=your_${var,,}_here" >> "$env_file"
            done <<< "$env_vars"
            echo "" >> "$env_file"
        fi
    done

    if [[ "$has_env_vars" == "true" ]]; then
        log_success "Generated $env_file"
        log_info "Remember to copy .env.template to .env and add your API keys"
    else
        rm -f "$env_file"  # Remove if no env vars needed
    fi
}

# Show setup summary
show_summary() {
    local project_dir="$1"
    shift
    local mcps=("$@")

    echo ""
    echo -e "${BOLD}MCP Setup Summary:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Project: $project_dir"
    echo "Enabled MCPs:"
    for mcp in "${mcps[@]}"; do
        echo "  - $mcp"
    done
    echo ""
    echo "Next steps:"
    echo "  1. Check for required environment variables (if any)"
    echo "  2. cd $project_dir"
    echo "  3. Open Claude Code"
    echo "  4. Use /mcp to verify servers are connected"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main setup function
setup_mcps() {
    local project_dir="$1"

    # Validate project directory
    if [[ ! -d "${project_dir}/.claude" ]]; then
        log_error "Not an AWOC project: ${project_dir}/.claude not found"
        log_info "Run 'awoc install -d $project_dir' first"
        exit 1
    fi

    # Check for existing .mcp.json
    if [[ -f "${project_dir}/.claude/.mcp.json" ]]; then
        log_warning "Existing .mcp.json found"
        read -p "Replace existing MCP configuration? (y/N): " -r
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing configuration"
            exit 0
        fi
    fi

    # Select MCPs
    local selected_mcps=()
    while IFS= read -r mcp; do
        [[ -n "$mcp" ]] && selected_mcps+=("$mcp")
    done < <(select_mcps)

    if [[ ${#selected_mcps[@]} -eq 0 ]]; then
        exit 0
    fi

    log_info "Setting up ${#selected_mcps[@]} MCP server(s)..."

    # Check environment variables
    local env_missing=false
    for mcp in "${selected_mcps[@]}"; do
        if ! check_env_vars "$mcp"; then
            env_missing=true
        fi
    done

    # Generate configurations
    generate_mcp_json "$project_dir" "${selected_mcps[@]}"
    generate_env_template "$project_dir" "${selected_mcps[@]}"

    # Show summary
    show_summary "$project_dir" "${selected_mcps[@]}"

    if [[ "$env_missing" == "true" ]]; then
        log_warning "Some environment variables are missing"
        log_info "Set them before using the MCPs in Claude Code"
    fi
}

# Quick enable function
quick_enable() {
    local mcp_name="$1"
    local project_dir="$2"

    # Check if MCP exists
    if ! get_mcp_list | grep -q "^$mcp_name$"; then
        log_error "Unknown MCP: $mcp_name"
        log_info "Run 'awoc mcp list' to see available MCPs"
        exit 1
    fi

    log_info "Enabling $mcp_name for $project_dir"

    # Check environment variables
    check_env_vars "$mcp_name"

    # Generate configuration
    generate_mcp_json "$project_dir" "$mcp_name"
    generate_env_template "$project_dir" "$mcp_name"

    log_success "MCP $mcp_name enabled successfully"
}

# List available MCPs
list_mcps() {
    echo -e "${BOLD}AWOC MCP Registry${NC}"
    show_available_mcps
    echo ""
    echo "To enable MCPs for a project, run:"
    echo "  awoc mcp setup -d /path/to/project"
}

# Main entry point
main() {
    local command="${1:-setup}"
    shift || true

    check_prerequisites

    case "$command" in
        setup)
            local project_dir="${1:-$(pwd)}"
            setup_mcps "$project_dir"
            ;;
        enable)
            local mcp_name="$1"
            local project_dir="${2:-$(pwd)}"
            quick_enable "$mcp_name" "$project_dir"
            ;;
        list)
            list_mcps
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Usage: $0 {setup|enable|list} [args]"
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi