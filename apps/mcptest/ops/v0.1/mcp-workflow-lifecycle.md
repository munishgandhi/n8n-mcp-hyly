# MCP-Only Workflow Lifecycle Script

## Overview
Complete n8n workflow development lifecycle using only MCP tools, following the timestamped file pattern documented in `n8n-file-lifecycle.md`.

## Workflow Target
- **Workflow ID**: `KQxYbOJgGEEuzVT0` (t.HelloWorld v20250718-190747)
- **Change**: Modify "Hello World" to "Hello mcpA" (iteration A) or "Hello mcpB" (iteration B)
- **Storage**: `/home/mg/src/vc-mgr/n8n-io/mcptest/ops/v0.1/lifecycle/`

## Lifecycle Steps

### 1. Download Current Workflow (Stage 04)
```
mcp__n8n-mcp__n8n_get_workflow({id: "KQxYbOJgGEEuzVT0"})
→ Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-04-workflow.json
```

### 2. Create Fix (Stage 07)  
```
- Read downloaded workflow
- Modify jsCode: "Hello World" → "Hello mcpA"
- Validate with: mcp__n8n-mcp__validate_workflow()
→ Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-07-fix-draft.json
→ Document: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-07-fix.md
```

### 3. Copy to Edit Stage (Stage 01)
```
→ Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-01-edited.json
```

### 4. Patch Upload (Stage 02)
```
mcp__n8n-mcp__n8n_update_partial_workflow({
  id: "KQxYbOJgGEEuzVT0",
  operations: [{
    type: "updateNode",
    nodeName: "Hello Code", 
    changes: {"parameters.jsCode": "new code with Hello mcpA"}
  }]
})
→ Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-02-uploaded.json
```

### 5. Execute Workflow
```
- Manual execution via n8n UI or webhook trigger
- Record execution ID for trace retrieval
```

### 6. Download Results
```
A. mcp__n8n-mcp__n8n_get_workflow({id: "KQxYbOJgGEEuzVT0"})
   → Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-04-workflow.json

B. mcp__n8n-mcp__n8n_get_execution({id: "execution_id"})  
   → Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-05-trace-{execId}.json

C. Analyze execution for errors
   → Save as: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-06-errors-{execId}.json
   → OR: YYYYMMDD-HHMMSS-KQxYbOJgGEEuzVT0-06-noerrors-{execId}.json
```

## Implementation Notes

### MCP Tools Used
- `mcp__n8n-mcp__n8n_get_workflow` - Download workflow
- `mcp__n8n-mcp__validate_workflow` - Validate changes
- `mcp__n8n-mcp__n8n_update_partial_workflow` - Apply patches
- `mcp__n8n-mcp__n8n_get_execution` - Get execution data
- `mcp__n8n-mcp__n8n_list_executions` - Find latest execution

### Timestamping
- Use Eastern timezone: `YYYYMMDD-HHMMSS`
- Generate once at script start, reuse for all files in cycle

### Iteration Support
- Pass parameter `mcpA` or `mcpB` to vary the message
- Script can be run multiple times with different iterations

### Error Handling
- Validate at each stage using MCP validation tools
- Capture validation errors in lifecycle files
- Continue cycle even if non-critical errors occur

---

**Next**: Execute this lifecycle manually step by step, then convert to automated script.