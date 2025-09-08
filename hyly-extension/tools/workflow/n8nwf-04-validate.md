# n8nwf-04-validate - Fix Draft Validation

This Claude command validates fix draft files and promotes them to validated fixes ready for merging.

## Usage

```
n8nwf-04-validate
```

Run this command in a directory containing workflow lifecycle files. It will:
1. Find the latest `*-07-fix-draft.json` file
2. Validate the fix using MCP workflow validation calls
3. Check for JSON schema validity and node configurations
4. Promote to `*-07-fix.json` if validation passes

## Process

I'll help you validate your workflow fix draft using MCP calls. Let me find and validate your draft file.

First, let me check for fix draft files:

```bash
find . -name "*-07-fix-draft.json" -type f | sort -r | head -5
```

Once I find your fix draft, I'll:

### 1. Load and Parse Fix Draft

Read the fix draft file and validate JSON structure:
- Check JSON syntax is valid  
- Verify fix structure has required fields
- Validate fix operations are properly formatted

### 2. MCP Workflow Validation

Use MCP calls to validate the proposed fixes:

```typescript
// Validate complete workflow with fixes applied
mcp__n8n-mcp__validate_workflow({
  workflow: mergedWorkflowData
})

// Validate individual node operations  
mcp__n8n-mcp__validate_node_operation({
  nodeType: "nodes-base.code",
  config: nodeConfiguration
})

// Check node configurations
mcp__n8n-mcp__validate_node_minimal({
  nodeType: nodeType,
  config: {}
})
```

### 3. Fix Validation Checks

Perform comprehensive validation:
- **JSON Schema**: Ensure fix follows proper structure
- **Node Types**: Verify all referenced node types exist
- **Parameters**: Check parameter names and values are valid
- **Connections**: Validate node connections are maintained
- **Dependencies**: Check for missing dependencies or conflicts

### 4. Promote Valid Fixes

If validation passes:
- Create timestamped `*-07-fix.json` file
- Include validation results and metadata
- Provide summary of validated changes

## Fix Draft Format

Your `07-fix-draft.json` should follow this structure:

```json
{
  "fixes": [
    {
      "type": "updateNode",
      "nodeName": "Hello Code",  
      "changes": {
        "parameters.jsCode": "// Fixed code here\nreturn [{ message: 'Hello fixed!' }];"
      },
      "reason": "Fix return value to be array instead of object"
    }
  ],
  "summary": "Fix code node to return array for proper n8n flow",
  "workflowId": "KQxYbOJgGEEuzVT0"
}
```

## Validation Results

After validation, I'll provide:

- ✅ **Validation Status**: Pass/fail with detailed reasons
- 📋 **Fix Summary**: What changes will be applied  
- ⚠️ **Warnings**: Potential issues or recommendations
- 📝 **Next Steps**: Instructions for merging (n8nwf-05-mergefix)

## Error Handling

If validation fails:
- Keep draft file unchanged
- Provide detailed error report
- Suggest corrections needed
- No validated fix file is created

## Example Usage

```bash
# 1. Create your fix draft manually
# Edit: 20250907-130230-KQxYbOJgGEEuzVT0-07-fix-draft.json

# 2. Run validation  
n8nwf-04-validate

# 3. If successful, you'll get:
# → 20250907-130235-KQxYbOJgGEEuzVT0-07-fix.json

# 4. Then merge the validated fix:
# n8nwf-05-mergefix
```

This command ensures all fixes are properly validated before being applied to workflows, preventing invalid configurations from breaking your workflow development cycle.