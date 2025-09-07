# PRD: Hyly Extension Sandbox for n8n-mcp

## Overview

Create a sandboxed extension system (`hyly-extension/`) within n8n-mcp-hyly that isolates all hyly-specific customizations from the core MCP codebase, enabling clean upstream merges while providing comprehensive n8n workflow development automation tools.

## Problem Statement

Current state has several issues:
1. **Upstream Merge Conflicts**: Direct modifications to `src/` create conflicts when merging updates from czlonkowski/n8n-mcp
2. **Fragmented Tools**: Development tools are scattered across multiple repositories (vc-mgr, n8n-env)  
3. **No Extension System**: No clean way to add hyly-specific functionality without touching core code
4. **Workflow Development Dependencies**: Manual UI dependencies for workflow development and testing

## Solution

### Hyly Extension Sandbox Architecture

```
n8n-mcp-hyly/
├── src/                         # UNTOUCHABLE - upstream code (reset to main-rc)
├── hyly-extension/              # ALL hyly customizations sandboxed here
│   ├── mcp-extensions/         # Extracted MCP functionality
│   │   ├── handlers/           # New handler functions (workflow activation, etc.)
│   │   ├── tools/              # New tool definitions (workflow management)
│   │   └── services/           # API client extensions
│   │
│   ├── tools/                   # Development automation tools
│   │   ├── workflow/           # Workflow lifecycle management
│   │   │   ├── n8nwf-01-upload.sh
│   │   │   ├── n8nwf-02-execute.sh
│   │   │   ├── n8nwf-03-analyze.sh
│   │   │   ├── n8nwf-04-validate.md
│   │   │   └── n8nwf-05-mergefix.md
│   │   ├── postgres/           # Database analysis from pgscripts
│   │   └── common/             # Shared utilities
│   │
│   ├── workflows/              # Workflow development artifacts
│   │   ├── lifecycle/          # Workflow lifecycle files (replaces vc-mgr/n8n-io)
│   │   └── tests/              # Test workflows (mcptest, cli-test)
│   │
│   ├── .claude/                # Claude integration
│   │   ├── commands/           # Links to tools/
│   │   ├── scripts/            # Additional scripts  
│   │   └── agents/             # Complex workflows
│   │
│   ├── docs/                   # Hyly-specific documentation
│   │   ├── dev-guide-implementation-changes.md
│   │   ├── engineering-guide-autonomous-coding.md
│   │   └── tutorial-8-new-tools.md
│   │
│   ├── deploy/                 # Deployment scripts
│   │   ├── install-to-user.sh # Deploy to ~/.claude
│   │   └── setup-project.sh   # Setup new projects
│   │
│   ├── templates/              # Reusable templates
│   │   ├── INSTRUCTIONS-TASKS.md
│   │   ├── TASK-TEMPLATE.md
│   │   └── PRD-TEMPLATE.md
│   │
│   └── change-requests/        # Timestamped change management
│       └── 20250907-175449-init-extension/
│           ├── PRD.md (this file)
│           └── TASKS.md
```

## Key Features

### 1. Clean Separation
- `src/` remains pristine for upstream merges
- All hyly customizations isolated in `hyly-extension/`
- No patches or complex merge management needed

### 2. Comprehensive Tooling
- **MCP Extensions**: 8 new workflow management tools (extracted from main-hyly)
- **Workflow Lifecycle**: Complete automation (upload → execute → analyze → validate → merge)
- **Development Tools**: PostgreSQL analysis, testing frameworks
- **Claude Integration**: Commands, scripts, and agents for AI-driven development

### 3. Centralized Workflow Development
- Replaces scattered workflow artifacts from vc-mgr/n8n-io
- Single location for all workflow development activities
- Proper lifecycle file management with execution ID tracking

### 4. Deployment Flexibility
- Install tools to user's `~/.claude` for global access
- Project-specific deployment options
- Template system for consistent development practices

## Implementation Phases

### Phase 1: Core Infrastructure Setup
- Create hyly-extension directory structure
- Setup templates and change request management
- Establish deployment scripts

### Phase 2: Extract Existing Work
- Extract MCP extensions from src/ (reset to main-rc)
- Move workflow artifacts from vc-mgr/n8n-io
- Migrate documentation from enhancements/

### Phase 3: Tool Development  
- Implement n8nwf-01 through n8nwf-05 tools
- Port postgres analysis scripts
- Setup Claude integration

### Phase 4: Integration & Testing
- Test complete workflow development lifecycle
- Validate MCP extension integration
- Deploy to production environment

## Success Metrics

1. **Clean Upstream Integration**: Ability to merge from upstream without conflicts
2. **Complete Workflow Automation**: End-to-end workflow development without manual UI
3. **Proper File Management**: All files follow lifecycle naming conventions
4. **Centralized Development**: Single repository for all n8n development activities
5. **Template Consistency**: All future changes use standardized templates

## Migration Benefits

- **No More Merge Conflicts**: src/ stays clean
- **Consolidated Tools**: Everything in one place
- **Proper Change Management**: Timestamped change requests
- **Template Consistency**: Reusable patterns for development
- **Deployment Automation**: Easy installation and updates

This architecture transforms n8n-mcp-hyly from just an MCP server into a comprehensive n8n development toolkit while maintaining clean separation from upstream code.