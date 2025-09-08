# n8nwf-05-mergefix - Merge Validated Fixes

This Claude command merges validated fixes into workflows and generates new edited files for the next iteration.

## Usage

```
n8nwf-05-mergefix
```

Run this command in a directory containing workflow lifecycle files. It will:
1. Find the latest `*-07-fix.json` validated fix file
2. Find the corresponding `*-04-workflow.json` current workflow
3. Apply the fixes intelligently to create updated workflow
4. Generate new `*-01-edited.json` file for next upload cycle

## Process

I'll help you merge validated fixes into your workflow. Let me find and process your validated fix file.

First, let me check for validated fix files:

```bash
find . -name "*-07-fix.json" -type f | sort -r | head -5
```

Once I find your validated fix, I'll:

### 1. Load Fix and Workflow Data

Read both the validated fix file and current workflow:
- Parse the `07-fix.json` file with validated changes
- Load the corresponding `04-workflow.json` current state
- Verify they match the same workflow ID

### 2. Apply Fix Operations

Process each fix operation based on type:

#### Node Updates (`updateNode`)
```javascript
// Update existing node parameters
const nodeIndex = workflow.nodes.findIndex(n => n.name === fix.nodeName);
if (nodeIndex >= 0) {
  Object.keys(fix.changes).forEach(path => {
    // Apply nested parameter changes like "parameters.jsCode"
    setNestedProperty(workflow.nodes[nodeIndex], path, fix.changes[path]);
  });
}
```

#### Node Additions (`addNode`)
```javascript
// Add new node to workflow
const newNode = {
  id: generateNodeId(),
  name: fix.nodeName,
  type: fix.nodeType,
  ...fix.nodeConfig
};
workflow.nodes.push(newNode);
```

#### Connection Updates (`updateConnections`)
```javascript
// Modify node connections
workflow.connections = {
  ...workflow.connections,
  ...fix.connectionChanges
};
```

#### Settings Updates (`updateSettings`)
```javascript
// Update workflow settings
workflow.settings = {
  ...workflow.settings,
  ...fix.settingsChanges
};
```

### 3. Generate New Edited File

Create timestamped output file:
- Use new timestamp for sequencing
- Name: `YYYYMMDD-HHMMSS-{workflowId}-01-edited.json`
- Include merge metadata and change summary
- Validate JSON structure before saving

### 4. Merge Summary Report

Provide detailed report of changes applied:
- ✅ **Merge Status**: Success/failure with reasons
- 📋 **Changes Applied**: List of all modifications made
- 🔧 **Nodes Modified**: Count and names of affected nodes
- 📝 **Next Steps**: Instructions for next upload cycle

## Fix Types Supported

### updateNode
Updates existing node parameters:
```json
{
  "type": "updateNode",
  "nodeName": "Hello Code",
  "changes": {
    "parameters.jsCode": "return [{ message: 'Hello fixed!' }];",
    "parameters.mode": "runOnceForAllItems"
  },
  "reason": "Fix return format and execution mode"
}
```

### addNode
Adds new node to workflow:
```json
{
  "type": "addNode",
  "nodeName": "New HTTP Request",
  "nodeType": "n8n-nodes-base.httpRequest",
  "position": [400, 200],
  "nodeConfig": {
    "parameters": {
      "url": "https://api.example.com/data",
      "method": "GET"
    }
  },
  "reason": "Add data source for workflow"
}
```

### updateConnections
Modifies workflow connections:
```json
{
  "type": "updateConnections",
  "connectionChanges": {
    "Hello Code": {
      "main": [[{ "node": "New HTTP Request", "type": "main", "index": 0 }]]
    }
  },
  "reason": "Connect fixed code node to new HTTP request"
}
```

### updateSettings
Updates workflow-level settings:
```json
{
  "type": "updateSettings",
  "settingsChanges": {
    "executionOrder": "v1",
    "saveDataErrorExecution": "all"
  },
  "reason": "Enable better error tracking"
}
```

## Merge Algorithm

The merge process follows these steps:

1. **Validation**: Verify fix file references correct workflow ID
2. **Backup**: Create backup reference to original workflow
3. **Sequential Processing**: Apply fixes in the order they appear
4. **Conflict Detection**: Check for overlapping changes
5. **Structure Validation**: Ensure resulting workflow is valid JSON
6. **Node ID Management**: Maintain unique node IDs and proper references
7. **Connection Integrity**: Verify all connections point to valid nodes

## Error Handling

If merge fails:
- Keep original workflow unchanged
- Provide detailed error report with specific failure reason
- Suggest corrections needed in fix file
- No new edited file is created

Common error scenarios:
- **Node Not Found**: Fix references node that doesn't exist
- **Invalid Parameters**: Parameter paths don't match node structure
- **Connection Conflicts**: Connections reference non-existent nodes
- **JSON Structure**: Resulting workflow has invalid structure

## Example Usage

```bash
# 1. Start with validated fix
# Files: 20250907-130235-KQxYbOJgGEEuzVT0-07-fix.json
#        20250907-130235-KQxYbOJgGEEuzVT0-04-workflow.json

# 2. Run merge command
n8nwf-05-mergefix

# 3. Get new edited file for next cycle
# Output: 20250907-130240-KQxYbOJgGEEuzVT0-01-edited.json

# 4. Continue development cycle
# n8nwf-01-upload KQxYbOJgGEEuzVT0
```

## Integration with Development Cycle

This command completes the fix cycle:
```
06-errors/noerrors → 07-fix-draft → 07-fix → 01-edited → 02-uploaded → 03-executed → 04-workflow → 05-trace → 06-status
```

After running n8nwf-05-mergefix:
- New 01-edited file ready for n8nwf-01-upload
- Iteration counter can be tracked via timestamps
- Development cycle can continue seamlessly

## Merge Metadata

Each merged file includes metadata:
```json
{
  "mergeInfo": {
    "sourceFixFile": "20250907-130235-KQxYbOJgGEEuzVT0-07-fix.json",
    "sourceWorkflowFile": "20250907-130235-KQxYbOJgGEEuzVT0-04-workflow.json",
    "mergeTimestamp": "2025-09-07T20:30:00Z",
    "changesApplied": 3,
    "fixesProcessed": ["updateNode", "updateSettings"],
    "mergeStatus": "SUCCESS"
  }
}
```

This ensures full traceability of changes through the development lifecycle and enables rollback if needed.