# Hyly Extension Claude Configuration

## Overview

This is the Claude configuration for hyly-extension, providing comprehensive n8n workflow development tools.

## Available Tools

### Workflow Lifecycle Tools
- **n8nwf-01-upload**: Upload and verify workflows with SQLite + API validation
- **n8nwf-02-execute**: Execute workflows via n8n CLI with execution ID tracking
- **n8nwf-03-analyze**: Download and analyze execution results into lifecycle files
- **n8nwf-04-validate**: Validate fix drafts using MCP calls (Claude command)
- **n8nwf-05-mergefix**: Merge validated fixes into workflows (Claude command)

### Supporting Tools
- **PostgreSQL Analysis**: Database queries for workflow analysis
- **Common Utilities**: Shared functions and helpers

## Workflow Development Process

### Complete Lifecycle
1. **Download**: Get workflow as baseline (`04-workflow.json`)
2. **Fix Draft**: Create manual fixes (`07-fix-draft.json`)
3. **Validate**: Use n8nwf-04-validate to check fixes (`07-fix.json`)
4. **Edit**: Use n8nwf-05-mergefix to create edited workflow (`01-edited.json`)
5. **Upload**: Use n8nwf-01-upload to deploy changes (`02-uploaded.json`)
6. **Execute**: Use n8nwf-02-execute to run workflow
7. **Analyze**: Use n8nwf-03-analyze to process results (`05-trace`, `06-errors/noerrors`)
8. **Validate**: Confirm NO ERRORS status achieved

### File Naming Convention
All lifecycle files follow: `YYYYMMDD-HHMMSS-{workflowId}-{stage}-{description}.{ext}`

**Stages:**
- `01-edited`: Modified workflow ready for upload
- `02-uploaded`: Successfully uploaded workflow
- `04-workflow`: Current workflow definition
- `05-trace-{execId}`: Execution trace data
- `06-errors/noerrors-{execId}`: Execution status
- `07-fix-draft`: Draft fixes (manual)
- `07-fix`: Validated fixes

## MCP Integration

The hyly-extension provides MCP tools for:
- Workflow validation and verification
- Node configuration validation
- Execution result analysis
- Fix validation and merging

## Deployment

Tools can be deployed:
- **Globally**: `deploy/install-to-user.sh` → `~/.claude`
- **Per Project**: `deploy/setup-project.sh` → `project/.claude`

## Development Workflow

This configuration supports iterative AI-driven workflow development with:
- Complete automation from download to validation
- Proper error handling and lifecycle tracking
- MCP integration for intelligent validation
- File-based audit trails