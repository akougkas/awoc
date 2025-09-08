# MCP Setup for AWOC 2.0

## Installed MCP Servers

### Context7 (@upstash/context7-mcp)
- **Purpose**: Documentation search and retrieval
- **Tools**: `mcp__context7__search`, `mcp__context7__get_docs`
- **Usage**: Fast documentation lookup and code examples

### Bright Data (@brightdata/mcp)
- **Purpose**: Advanced web scraping and search
- **Tools**: `mcp__brightdata__web_search`, `mcp__brightdata__scrape_url` 
- **Usage**: High-quality web data extraction
- **Configuration**: API token loaded from `.env` file

## CLI Tools

### Repomix
- **Installation**: `npm install -g repomix`
- **Usage**: `repomix` in project directory
- **Purpose**: Generate AI-friendly codebase summaries
- **Output**: `repomix-output.xml`

## Configuration Files

- **`.mcp.json`**: Project MCP server definitions
- **`.claude/settings.local.json`**: Local permissions and model settings
- **`enableAllProjectMcpServers: true`**: Auto-approve project MCPs

## docs-fetcher Integration

The docs-fetcher subagent is configured to use:
- Context7 for documentation search
- Bright Data for web scraping
- Repomix CLI for codebase analysis
- Standard WebSearch/WebFetch as fallback

## Environment Setup

- **`.env`**: Contains `BRIGHTDATA_API_TOKEN` (excluded from git)
- **`.gitignore`**: Prevents accidental commit of sensitive data
- **Environment variable expansion**: MCP config uses `${BRIGHTDATA_API_TOKEN}`

## Next Steps

1. Test MCP connections with `/mcp` command  
2. Verify docs-fetcher can access all tools
3. Confirm Bright Data authentication works

## Usage Example

```bash
# Test MCP servers
/mcp

# Use docs-fetcher with MCP tools
/agents exec docs-fetcher "Research FastAPI authentication patterns"
```