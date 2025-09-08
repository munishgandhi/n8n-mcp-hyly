# N8N Operations Summary

This document lists all scripts and agents that directly interact with the n8n instance (not just file manipulation).

## Operations Table

| Script Name | Method | Call Details |
|-------------|--------|--------------|
| **n8n-100-workflow-extract.sh** | API | `curl -H "X-N8N-API-KEY: $N8N_API_KEY" "http://localhost:5678/api/v1/workflows/$WORKFLOW_ID"` - Extract workflow JSON via REST API |
| **n8n-11-execution-extract.sh** | API | Multiple API calls:<br/>• `GET /api/v1/executions?workflowId=$WORKFLOW_ID&limit=1`<br/>• `GET /api/v1/workflows/$WORKFLOW_ID`<br/>• `GET /api/v1/executions/$EXECUTION_ID` |
| **n8n-120-workflow-upload.sh** | Direct DB + API | • **SQLite**: `docker exec -i n8n node -e "sqlite3.Database('/home/node/.n8n/database.sqlite')"` - Direct workflow update<br/>• **API**: `curl "http://localhost:5678/api/v1/workflows/$WORKFLOW_ID"` - Verification only |
| **n8n-mcp-00-test** (agent) | MCP | • `mcp__n8n-mcp__n8n_list_available_tools`<br/>• `mcp__n8n-mcp__tools_documentation` |
| **n8n-mcp-docs-fetcher** (agent) | MCP | `mcp__n8n-mcp__tools_documentation` - Retrieve n8n MCP documentation |

## Method Types Explained

### API (REST API)
- **Usage**: Read-only operations, verification
- **Access**: Via `curl` with `X-N8N-API-KEY` header
- **Endpoint**: `http://localhost:5678/api/v1/`
- **Pros**: Clean, documented, follows HTTP standards
- **Cons**: Slower, includes activation side effects for updates

### Direct DB (SQLite)
- **Usage**: Fast workflow updates without activation
- **Access**: Via `docker exec n8n` with Node.js SQLite operations  
- **Database**: `/home/node/.n8n/database.sqlite` inside container
- **Pros**: Fastest possible updates, bypasses all processing
- **Cons**: Requires restart for activation, no validation

### MCP (Model Context Protocol)
- **Usage**: Documentation retrieval, tool discovery
- **Access**: Via MCP server tools (`mcp__n8n-mcp__*`)
- **Pros**: Rich toolset, integrated with n8n features
- **Cons**: Limited to available MCP tools

## Key Insights

1. **Hybrid Approach**: The upload script uses the most efficient pattern - direct SQLite for speed + API verification
2. **No CLI Usage**: All scripts bypass n8n CLI for better programmatic control
3. **Read vs Write**: Extract operations use API (read-only), uploads use direct DB (write-heavy)
4. **MCP Integration**: Available but primarily used for documentation/discovery, not core operations

## File Locations

- **Toolbox Scripts**: `/home/mg/src/vc-mgr/.claude/toolbox-n8n/`
- **Agent Definitions**: `/home/mg/src/vc-mgr/.claude/agents/n8n-*.md`
- **Agent Shell Scripts**: `/home/mg/src/vc-mgr/.claude/agents/n8n-*.sh`

---
*Generated: $(date +"%Y-%m-%d %H:%M:%S")*