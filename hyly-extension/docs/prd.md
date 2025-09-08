# PRD: n8n Workflow Development Toolchain

## Overview

A comprehensive toolkit for automating n8n workflow development using file-based lifecycle management with MCP (Model Context Protocol) operations. This system eliminates manual UI dependency and enables complete AI-driven workflow development.

## Problem Statement

Current n8n workflow development requires:
- Manual UI interactions for testing and validation
- Inconsistent file naming and tracking
- No systematic approach to iterative development
- Manual execution and result verification
- Fragmented tooling across different lifecycle stages

## Solution

A unified toolchain that automates the complete workflow development lifecycle:
1. **Upload workflows** with validation and verification
2. **Execute workflows** via CLI with proper result capture  
3. **Analyze executions** with automatic error detection and file generation
4. **Validate fixes** before application
5. **Merge fixes** back into the workflow definition

## Architecture

### File Naming Convention

All files follow the pattern: `YYYYMMDD-HHMMSS-{workflowId}-{stage}-{description}.{ext}`

**Stages:**
- `01-edited`: Modified workflow ready for upload
- `02-uploaded`: Successfully uploaded workflow with verification 
- `03-verified`: Downloaded workflow after upload for verification
- `04-workflow`: Current workflow definition
- `05-trace`: Execution trace data
- `06-errors/noerrors`: Execution status and error analysis
- `07-fix-draft`: Draft fixes (manual creation)
- `07-fix`: Validated fixes ready for merge
- `09-fix-final`: Final fix validation result

### Directory Structure

```
workflow_dir/
├── lifecycle/           # Active development files
│   ├── 20250907-130235-{id}-01-edited.json
│   ├── 20250907-130238-{id}-02-uploaded.json
│   ├── 20250907-130245-{id}-04-workflow.json
│   ├── 20250907-130248-{id}-05-trace-676.json
│   └── 20250907-130250-{id}-06-noerrors-676.json
└── context/             # Reference files (--context mode)
```

## Component Specifications

### n8nwf-01-upload (Upload & Verify)

**Purpose:** Take edited workflow, upload to n8n, verify successful upload

**Input:** Latest `*-01-edited.json` file (or specified with `--input`)
**Output:** `02-uploaded.json`, `03-verified.json`

**Key Features:**
- Direct SQLite upload (fast, proven method from existing `n8n-120-workflow-upload.sh`)
- API verification with node count validation
- Automatic workflow name timestamping (adds `v20250907-130235`)
- Fix validation (checks if previous fixes were applied correctly)
- HTML report generation with browser opening

**Implementation Options:**
1. **Shell Script** (`n8nwf-01-upload.sh`) - Direct port of existing toolbox script
2. **Claude Command** (`n8nwf-01-upload.md`) - MCP-based implementation
3. **Hybrid** - Shell script with MCP validation calls

**Existing Reference:** `/home/mg/src/vc-mgr/.claude/toolbox-n8n/n8n-120-workflow-upload.sh`

---

### n8nwf-02-execute (Execute Workflow) 

**Purpose:** Execute workflow via n8n CLI and capture results

**Input:** Workflow ID
**Output:** Execution started (gets execution ID for next step)

**Key Features:**
- Uses `docker exec hyly-n8n-app n8n execute --id={workflowId} --rawOutput`
- Captures execution ID from CLI output
- Lightweight - just triggers execution
- No file generation (handled by analyze step)

**Implementation Options:**
1. **Shell Script** (`n8nwf-02-execute.sh`) - Simple CLI wrapper
2. **Claude Command** (`n8nwf-02-execute.md`) - MCP execution calls

**CLI Reference:** `/home/mg/src/n8n-env/.claude/commands/helpers/hyly-n8n-app-cli.sh`

---

### n8nwf-03-analyze (Download & Analyze Execution)

**Purpose:** Download executed workflow into three analysis files

**Input:** Workflow ID, Execution ID (from step 2)
**Output:** `04-workflow.json`, `05-trace-{execId}.json`, `06-errors/noerrors-{execId}.json`

**Key Features:**
- Downloads current workflow definition (04-workflow)
- Extracts detailed execution trace with full node data (05-trace) 
- Analyzes execution for errors/success status (06-errors/noerrors)
- Uses existing error detection logic
- Proper execution ID naming in files

**Implementation Options:**
1. **Shell Script** (`n8nwf-03-analyze.sh`) - Port of existing extraction logic
2. **Claude Command** (`n8nwf-03-analyze.md`) - MCP-based extraction

**Existing Reference:** `/home/mg/src/vc-mgr/.claude/toolbox-n8n/n8n-11-execution-extract.sh`

---

### n8nwf-04-validate (Validate Fix Draft)

**Purpose:** Validate manually created fix draft and promote to ready state

**Input:** `07-fix-draft.json` (manually created)
**Output:** `07-fix.json` (validated and ready for merge)

**Key Features:**
- MCP workflow validation calls 
- Node configuration validation
- Connection verification
- JSON schema validation
- Promotes draft to final only if validation passes

**Implementation Options:**
1. **Claude Command** (`n8nwf-04-validate.md`) - MCP validation focused
2. **Shell + MCP** (`n8nwf-04-validate.sh`) - Shell wrapper with MCP calls

**MCP Operations:**
```javascript
mcp__n8n-mcp__validate_workflow({workflow: fixData})
mcp__n8n-mcp__validate_node_operation({nodeType: "...", config: {...}})
```

---

### n8nwf-05-mergefix (Merge Fix into Workflow)

**Purpose:** Take validated fix and merge with current workflow to create new edited version

**Input:** `07-fix.json`, `04-workflow.json`  
**Output:** `01-edited.json` (next iteration ready)

**Key Features:**
- Intelligent merge of fix operations into workflow definition
- Preserves workflow metadata (connections, settings, etc.)
- Creates properly formatted edited file for next upload cycle
- Handles different fix types: node updates, additions, parameter changes
- Validates merge result before saving

**Implementation Options:**
1. **Claude Command** (`n8nwf-05-mergefix.md`) - Smart merging with validation
2. **Shell + jq** (`n8nwf-05-mergefix.sh`) - Pure shell implementation with jq manipulation

## Integration Points

### MCP Integration
- All validation operations use MCP calls for consistency
- Workflow and node validation before any upload/execution
- Results stored in lifecycle files for audit trail

### CLI Integration  
- n8n CLI execution via Docker containers
- Proper execution ID capture and file naming
- Compatible with existing hyly-n8n-app patterns

### Existing Toolbox Integration
- Reuses proven upload logic from `n8n-120-workflow-upload.sh`
- Leverages extraction patterns from `n8n-11-execution-extract.sh`  
- Maintains file lifecycle compatibility with `n8n-100-workflow-extract.sh`

## Implementation Decision Matrix

| Component | Shell Script | Claude Command | Recommendation |
|-----------|--------------|----------------|----------------|
| n8nwf-01-upload | ✅ Fast, proven | ✅ MCP integration | **Shell** - proven upload logic |
| n8nwf-02-execute | ✅ Simple CLI | ✅ MCP calls | **Shell** - minimal complexity |
| n8nwf-03-analyze | ✅ Existing code | ✅ MCP extraction | **Shell** - complex extraction logic |
| n8nwf-04-validate | ❌ Complex validation | ✅ MCP focused | **Claude Command** - validation heavy |
| n8nwf-05-mergefix | ❌ Complex merging | ✅ Smart merging | **Claude Command** - intelligent merge |

## Success Metrics

1. **Complete Lifecycle Automation:** Full workflow development cycle without manual UI interaction
2. **Proper File Tracking:** All files follow naming convention with execution IDs
3. **Error Prevention:** Validation catches issues before upload
4. **Audit Trail:** Complete file-based record of all operations
5. **MCP + CLI Integration:** Seamless combination of MCP operations and CLI execution

## Next Steps

1. **Create Shell Scripts** for upload, execute, analyze (n8nwf-01, 02, 03)
2. **Create Claude Commands** for validate, mergefix (n8nwf-04, 05)
3. **Test Integration** with existing MCP + CLI lifecycle
4. **Document Usage Patterns** for common workflow development scenarios
5. **Add Error Handling** and recovery mechanisms

## File Dependencies

The toolchain builds on these existing proven implementations:
- Upload logic: `/home/mg/src/vc-mgr/.claude/toolbox-n8n/n8n-120-workflow-upload.sh`
- Extraction logic: `/home/mg/src/vc-mgr/.claude/toolbox-n8n/n8n-11-execution-extract.sh`
- CLI patterns: `/home/mg/src/n8n-env/.claude/commands/helpers/hyly-n8n-app-cli.sh`
- Workflow export: `/home/mg/src/vc-mgr/.claude/toolbox-n8n/n8n-100-workflow-extract.sh`

This PRD provides the foundation for creating a complete n8n workflow development automation system that eliminates manual dependencies while maintaining full audit trails and validation.