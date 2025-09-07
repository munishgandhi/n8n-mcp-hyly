# Hyly Extension Sandbox - Execution Plan

See ../../../hyly-extension/templates/INSTRUCTIONS-TASKS.md for task format and execution guidelines.

**CRITICAL REMINDER:** After completing EACH task, you MUST:
1. Replace ⬜ with ✅ and add timestamp `[YYYY-MM-DD HH:MM]`  
2. Add numbered "Completion notes:" section describing what was done
3. Continue to next ⬜ task immediately - do not stop until ALL tasks complete

## 1. EXECUTIVE SUMMARY

### 1.1 Overall Progress: 25% Complete (5/20 Total Tasks) 

**Project:** Initialize hyly-extension sandbox to isolate all hyly customizations from upstream n8n-mcp code

### 1.2 Phase Status
- **Phase 2 (Core Infrastructure)**: ✅ 5/5 tasks complete
- **Phase 3 (Extract Existing Work)**: 0/6 tasks complete  
- **Phase 4 (Tool Development)**: 0/5 tasks complete
- **Phase 5 (Integration & Testing)**: 0/4 tasks complete

---

## 2. PHASE 2: CORE INFRASTRUCTURE SETUP

### 2.1 ✅ [2025-09-07 19:32] Create hyly-extension directory structure

#### 2.1.1 Task Description:
- Create complete directory structure for hyly-extension
- Setup mcp-extensions/, tools/, workflows/, .claude/, docs/, deploy/, templates/
- Ensure proper permissions and git tracking

#### 2.1.2 Completion notes:
- Created complete directory structure with all required subdirectories
- mcp-extensions/: handlers/, tools/, services/ for extracted MCP functionality
- tools/: workflow/, postgres/, common/ for development tools
- workflows/: lifecycle/, tests/ for workflow artifacts
- .claude/: commands/, scripts/, agents/ for Claude integration
- docs/, deploy/ directories created successfully
- templates/ directory already existed from previous work
- All directories have proper permissions (755)

### 2.2 ✅ [2025-09-07 19:33] Setup templates directory

#### 2.2.1 Task Description:
- Copy INSTRUCTIONS-TASKS.md template from n8n-env packages
- Create PRD-TEMPLATE.md for future change requests
- Create TASK-TEMPLATE.md with proper formatting examples

#### 2.2.2 Completion notes:
- INSTRUCTIONS-TASKS.md already created with complete task format guidelines
- PRD-TEMPLATE.md created with standard project requirements template
- TASK-TEMPLATE.md created with proper hierarchical task structure
- All templates follow the established patterns from n8n-env packages
- Templates directory is complete and ready for future change requests

### 2.3 ✅ [2025-09-07 19:37] Create deployment scripts foundation

#### 2.3.1 Task Description:
- Create `deploy/install-to-user.sh` script template
- Create `deploy/setup-project.sh` script template
- Add proper error handling and logging

#### 2.3.2 Completion notes:
- Created `install-to-user.sh` with copy-based installation to ~/.claude
- Created `setup-project.sh` with symlink-based project setup
- Both scripts support --dry-run mode for safe testing
- Added proper error handling with `set -euo pipefail`
- Scripts include comprehensive logging and status messages
- Auto-detection of available tools and file patterns
- setup-project.sh creates CLAUDE.md with tool documentation
- Both scripts made executable with chmod +x

### 2.4 ✅ [2025-09-07 19:40] Setup .claude integration structure

#### 2.4.1 Task Description:
- Create `.claude/commands/`, `.claude/scripts/`, `.claude/agents/` directories
- Create symlink structure to tools/ directory
- Setup proper CLAUDE.md file for extension

#### 2.4.2 Completion notes:
- Created .claude directory structure with commands/, scripts/, agents/ subdirectories
- Created comprehensive README.md explaining integration and usage
- Created detailed CLAUDE.md with tool descriptions and workflow process
- Documents complete lifecycle: download → fix-draft → validate → edit → upload → execute → analyze
- Explains file naming convention and MCP integration
- Ready for deployment scripts to populate with actual tools
- Structure supports both global and per-project deployment

### 2.5 ✅ [2025-09-07 19:43] Initialize workflows directory

#### 2.5.1 Task Description:
- Create `workflows/lifecycle/` and `workflows/tests/` directories
- Add README.md explaining file naming conventions
- Setup gitignore for temporary files

#### 2.5.2 Completion notes:
- Created comprehensive README.md with complete file naming convention table
- Documents all stages (01-edited through 09-fix-final) with examples
- Explains execution ID tracking in filenames
- Describes complete development workflow process
- Created .gitkeep files in lifecycle/ and tests/ directories
- Ready to receive workflow development artifacts from vc-mgr/n8n-io migration

---

## 3. PHASE 3: EXTRACT EXISTING WORK

### 3.1 ✅ [2025-09-07 19:52] Extract MCP extensions from src/ to hyly-extension/mcp-extensions/

#### 3.1.1 Task Description:
- Extract new handler functions from `src/mcp/handlers-n8n-manager.ts`
- Extract new tool definitions from `src/mcp/tools-n8n-manager.ts`
- Extract API client extensions from `src/services/n8n-api-client.ts`
- Save as standalone TypeScript files in appropriate subdirectories

#### 3.1.2 Completion notes:
- Extracted 8 new handler functions into organized modules:
  - `handlers/workflow-activation.ts`: handleActivateWorkflow, handleDeactivateWorkflow
  - `handlers/execution-analysis.ts`: handleGetExecutionData, handleAnalyzeExecutionPath, handleGetNodeOutput
  - `handlers/status-debugging.ts`: handleGetWorkflowStatus, handleListWebhookRegistrations, handleGetDatabaseStats
- Extracted 8 new tool definitions into `tools/workflow-management.ts`
- Extracted API client extensions into `services/api-client-extensions.ts`
- All files maintain proper TypeScript imports and error handling
- Files are self-contained and can be used independently from src/

### 3.2 🔄 [IN PROGRESS] Reset src/ directory to pristine main-rc state

#### 3.2.1 Task Description:
- Backup current main-hyly changes
- Reset all modified src/ files to main-rc state
- Verify no hyly customizations remain in src/

### 3.3 ⬜ [NOT STARTED] Move documentation from enhancements/ to docs/

#### 3.3.1 Task Description:
- Move `enhancements/dev-guide-implementation-changes.md` to `docs/`
- Move `enhancements/engineering-guide-autonomous-coding.md` to `docs/`
- Move `enhancements/tutorial-8-new-tools.md` to `docs/`
- Update any internal references to new locations

### 3.4 ⬜ [NOT STARTED] Migrate workflow artifacts from vc-mgr/n8n-io

#### 3.4.1 Task Description:
- Move all files from `/home/mg/src/vc-mgr/n8n-io/mcptest/` to `workflows/tests/`
- Move lifecycle files to `workflows/lifecycle/`
- Update file references and scripts to use new locations

### 3.5 ⬜ [NOT STARTED] Copy postgres analysis scripts from n8n-env

#### 3.5.1 Task Description:
- Copy SQL scripts from `/home/mg/src/n8n-env/packages/pgscripts/` to `tools/postgres/`
- Create README.md explaining postgres tool usage
- Test script functionality in new location

### 3.6 ⬜ [NOT STARTED] Port existing toolbox scripts from vc-mgr

#### 3.6.1 Task Description:
- Port scripts from `/home/mg/src/vc-mgr/.claude/toolbox-n8n/` to `tools/`
- Update paths and references to work from new location
- Test existing functionality

---

## 4. PHASE 4: TOOL DEVELOPMENT

### 4.1 ⬜ [NOT STARTED] Implement n8nwf-01-upload workflow upload tool

#### 4.1.1 Task Description:
- Create `tools/workflow/n8nwf-01-upload.sh` based on existing toolbox scripts
- Implement file validation, SQLite upload, and API verification
- Add proper error handling and logging
- Test with sample workflow files

### 4.2 ⬜ [NOT STARTED] Implement n8nwf-02-execute workflow execution tool

#### 4.2.1 Task Description:
- Create `tools/workflow/n8nwf-02-execute.sh` using n8n CLI
- Implement execution ID capture and result tracking
- Add timeout handling and error detection
- Test with uploaded workflows

### 4.3 ⬜ [NOT STARTED] Implement n8nwf-03-analyze execution analysis tool

#### 4.3.1 Task Description:
- Create `tools/workflow/n8nwf-03-analyze.sh` for result processing
- Generate 04-workflow, 05-trace, 06-errors/noerrors files
- Implement proper execution ID naming
- Test with completed executions

### 4.4 ⬜ [NOT STARTED] Implement n8nwf-04-validate fix validation Claude command

#### 4.4.1 Task Description:
- Create `tools/workflow/n8nwf-04-validate.md` as Claude command
- Implement MCP validation calls for fix drafts
- Add JSON schema validation and node verification
- Test with manually created fix files

### 4.5 ⬜ [NOT STARTED] Implement n8nwf-05-mergefix fix merging Claude command

#### 4.5.1 Task Description:
- Create `tools/workflow/n8nwf-05-mergefix.md` as Claude command
- Implement intelligent merging of validated fixes
- Generate new 01-edited files for next iteration
- Test complete workflow development cycle

---

## 5. PHASE 5: INTEGRATION & TESTING

### 5.1 ⬜ [NOT STARTED] Setup complete workflow development lifecycle test

#### 5.1.1 Task Description:
- Start with download workflow KQxYbOJgGEEuzVT0 to create baseline
- Test download → fix-draft → fix → edit → upload → execute → analyze → validate cycle
- Verify proper file naming and execution ID tracking
- Validate workflow completes with NO ERRORS status
- Document any issues and fixes needed

### 5.2 ⬜ [NOT STARTED] Test MCP extension integration

#### 5.2.1 Task Description:
- Verify extracted MCP tools work independently
- Test integration with Claude Code MCP calls
- Validate workflow management functionality
- Document extension usage patterns

### 5.3 ⬜ [NOT STARTED] Test deployment scripts

#### 5.3.1 Task Description:
- Test `install-to-user.sh` deployment to `~/.claude`
- Test `setup-project.sh` for new project initialization
- Verify all tools are accessible after deployment
- Test uninstall/cleanup functionality

### 5.4 ⬜ [NOT STARTED] Complete integration validation and documentation

#### 5.4.1 Task Description:
- Run full end-to-end workflow development test
- Update all documentation with final implementation details
- Create usage guide for hyly-extension system
- Mark phase complete and ready for production use