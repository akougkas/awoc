# MCP Server Template for AWOC

## Instructions for Adding New MCP Servers

When a user asks you to add a new MCP server to AWOC, follow these steps:

### 1. Understand the MCP Server

Ask the user for:
- **Name**: Short identifier for the MCP (e.g., `github`, `notion`)
- **Purpose**: What does this MCP server do?
- **Installation**: How is it installed? (npm package, URL, etc.)
- **Authentication**: Does it need API keys or OAuth?
- **Agents**: Which AWOC agents would benefit from this MCP?

### 2. Add to MCP Registry

Edit `~/.config/awoc/mcp.yaml` and add a new entry following this structure:

```yaml
# Example: Adding a new MCP server
your-mcp-name:
  description: "Brief description of what this MCP does"
  recommended_for: [agent1, agent2]  # Which agents benefit
  category: "Category Name"  # e.g., "Development Tools", "Research", "Data Collection"
  type: stdio  # Can be: stdio, http, or sse

  # For stdio (local) servers:
  command: "npx"
  args: ["-y", "@organization/mcp-package"]

  # For http servers:
  # type: http
  # url: "https://api.example.com/mcp"

  # For SSE servers:
  # type: sse
  # url: "https://api.example.com/sse"

  # Environment variables required (if any):
  env_required: ["API_KEY_NAME", "OTHER_VAR"]  # Empty array if none: []

  # Setup instructions for users:
  setup_notes: "How to get API keys or complete setup"
```

### 3. Categories

Use these standard categories:
- **Development Tools**: GitHub, Sentry, debugging tools
- **Research**: arXiv, Google Scholar, documentation
- **Data Collection**: Web scraping, data extraction
- **Project Management**: Linear, Notion, Jira
- **Databases**: PostgreSQL, MySQL, MongoDB
- **Design**: Figma, Canva
- **System**: Filesystem, shell commands
- **Automation**: Zapier, IFTTT

### 4. Agent Recommendations

Recommend MCPs based on agent type:
- **api-researcher**: Documentation (context7), research (arxiv), GitHub
- **content-writer**: Research (arxiv), Notion, web scraping
- **data-analyst**: Databases, web scraping (brightdata), data sources
- **project-manager**: Linear, Notion, Jira, GitHub issues
- **learning-assistant**: Documentation (context7), research (arxiv)
- **creative-assistant**: Figma, Canva, image generation

### 5. Example: Adding Slack MCP

If a user says "Add Slack integration for project-manager", you would:

```yaml
slack:
  description: "Read and send Slack messages, manage channels and users"
  recommended_for: [project-manager, content-writer]
  category: "Project Management"
  type: stdio
  command: "npx"
  args: ["-y", "@modelcontextprotocol/server-slack"]
  env_required: ["SLACK_BOT_TOKEN", "SLACK_APP_TOKEN"]
  setup_notes: "Create Slack app at api.slack.com, add bot token scopes, get tokens from OAuth page"
```

### 6. Validation

After adding, tell the user to:
1. Run `awoc mcp list` to verify the MCP appears
2. Run `awoc mcp setup -d .` to configure it for their project
3. Set required environment variables in their `.env` file
4. Test in Claude Code with `/mcp` command

### 7. Common MCP Types

**stdio (Local Process)**:
- npm packages: `npx -y @package/name`
- Python scripts: `python3 /path/to/script.py`
- Binary executables: `/usr/local/bin/mcp-server`

**http (REST API)**:
- Remote services with standard HTTP
- Usually require authentication headers

**sse (Server-Sent Events)**:
- Real-time streaming connections
- Often used by cloud services

### 8. Security Notes

Always remind users:
- Never commit API keys to version control
- Use environment variables for sensitive data
- Create `.env.template` without actual values
- Review MCP permissions before enabling

## Quick Template

Copy and modify this for new MCPs:

```yaml
new-mcp:
  description: ""
  recommended_for: []
  category: ""
  type: stdio
  command: "npx"
  args: ["-y", ""]
  env_required: []
  setup_notes: ""
```

## Testing Instructions

After adding a new MCP:

```bash
# 1. Update AWOC
awoc update

# 2. List MCPs to verify
awoc mcp list

# 3. Setup in test project
cd /tmp/test-project
awoc mcp enable new-mcp -d .

# 4. Check generated .mcp.json
cat .claude/.mcp.json

# 5. Test in Claude Code
# Open Claude Code and run /mcp
```