# Instructions for TASKS.md Execution

## 1. Document Structure
- Use hierarchical decimal numbering for all sections (1.1, 1.2, 3.7, etc.)
- Group related tasks into logical phases
- Maintain clear parent-child relationships in section hierarchy

**Full Hierarchy Example:**
```markdown
# Document Title

## 1. EXECUTIVE SUMMARY (Top-level section)

## 2. PRE-MIGRATION BASELINE (Phase)
### 2.1 ✅ [2025-09-06 09:00] Completed task (Task)
#### 2.1.1 Task Description: (Task component)
#### 2.1.2 Completion notes: (Task component)

## 3. PHASE 1: PACKAGE-LEVEL ATOMIC DEPLOYERS (Phase)
### 3.1 ✅ [2025-09-06 10:00] Completed task (Task)
#### 3.1.1 Task Description:
#### 3.1.2 Completion notes:

### 3.2 ⬜ [NOT STARTED] Uncompleted task (Task)
#### 3.2.1 Task Description:

### 3.3 🔄 [IN PROGRESS] Task being worked on (Task)
#### 3.3.1 Task Description:

## 4. PHASE 2: STACK-LEVEL ORCHESTRATORS (Phase)
```

## 2. Task Organization
- Tasks must remain in their original phase sections
- Do NOT move tasks between phases or add new tasks outside of defined phases
- Tasks are numbered sequentially within each phase (3.1, 3.2, 3.3...)

**Phase Organization Example:**
```markdown
## 3. PHASE 1: PACKAGE-LEVEL ATOMIC DEPLOYERS
### 3.1 ✅ First task in this phase
### 3.2 ✅ Second task in this phase
### 3.3 ⬜ Third task in this phase
### 3.4 ⬜ Fourth task in this phase

## 4. PHASE 2: STACK-LEVEL ORCHESTRATORS  
### 4.1 ✅ First task in this phase
### 4.2 ⬜ Second task in this phase

## 5. PHASE 3: GLOBAL DEPLOYMENT COMMAND
### 5.1 ⬜ First task in this phase
```

## 3. Task Format

### 3.1 Not Started Task Format
Use proper markdown formatting for tasks that have not been started:
- H3 heading with white box emoji, number, and status block: `### 3.7 ⬜ [NOT STARTED] Task name`
- H4 heading with number: `#### 3.7.1 Task Description:`
- **MANDATORY: All content must be either bullet points or code blocks**
- Use inline code for commands, flags, and file paths
- Bold text for emphasis on important items

**Template Example:**
```markdown
### 3.7 ⬜ [NOT STARTED] Complete flag implementation in hyly-n8n-openwebui

#### 3.7.1 Task Description:
- Add `--clean` flag functionality to remove .env overrides
- Add before-deployment snapshot creation
- Add after-deployment snapshot creation
- Test the deployer with `--dry-run` and actual deployment

**File to modify:** `/home/mg/src/n8n-env/packages/hyly-n8n-openwebui/docker-deploy.sh`
```

### 3.2 In Progress Task Format
Use proper markdown formatting for tasks currently being worked on:
- H3 heading with cycle emoji, number, and status block: `### 3.8 🔄 [IN PROGRESS] Task name`
- H4 heading with number: `#### 3.8.1 Task Description:`
- **MANDATORY: All content must be either bullet points or code blocks**
- Optionally add partial completion notes if work has started

**Template Example:**
```markdown
### 3.8 🔄 [IN PROGRESS] Test hyly-n8n full stack deployment

#### 3.8.1 Task Description:
- Run `/docker-deploy hyly-n8n` with all flags
- Verify all containers deploy in correct order
- Verify snapshots are created for each container
- Check all containers are healthy after deployment
```

### 3.3 Completed Task Format
Use proper markdown formatting for completed tasks:
- H3 heading with checkmark, number, and timestamp: `### 3.1 ✅ [2025-09-06 13:45] Task name`
- H4 heading with number: `#### 3.1.1 Task Description:`
- **MANDATORY: All content must be either bullet points or code blocks**
- H4 heading with number: `#### 3.1.2 Completion notes:`
- **MANDATORY: All completion content must be either bullet points or code blocks**

**Template Example:**
```markdown
### 3.2 ✅ [2025-09-06 09:45] Create hyly-n8n-app deployer

#### 3.2.1 Task Description:
- Create `/home/mg/src/n8n-env/packages/hyly-n8n-app/docker-deploy.sh`
- Enhance existing script with extensions build and atomic pattern

#### 3.2.2 Completion notes:
- Created with full implementation including --clean flag
- Added before/after snapshot functionality
- Tested deployment with dry-run successfully
```

### 3.4 Content Format Rules
**All content under Task Description and Completion notes MUST be formatted as:**
- Bullet points for text content
- Code blocks with language hints for commands or code
- NO plain paragraph text allowed
- Each bullet point should be a complete, actionable item

**Example with Code Blocks:**
```markdown
#### 2.1.1 Task Description:
- Run the `fix-common-issues.sh` script to ensure Docker environment is clean

```bash
cd /home/mg/src/n8n-env/stacks
./fix-common-issues.sh
```

#### 2.1.2 Completion notes:
- Script executed successfully
- Environment cleaned and ready for migration
- All containers restarted without issues
```

### 3.5 Status Indicators
- ✅ `[YYYY-MM-DD HH:MM]` - Completed task with timestamp
- ⬜ `[NOT STARTED]` - Not started task  
- 🔄 `[IN PROGRESS]` - Currently working on task

## 4. Task Execution Rules

### 4.1 Execution Order
- Execute tasks ONLY from this plan - do not create ad-hoc tasks
- Complete each task fully before marking it done
- After completing a task, proceed to the next uncompleted task marked with ⬜

### 4.2 Task Completion Requirements
When completing a task, you MUST:
- Replace ⬜ with ✅ and add `[YYYY-MM-DD HH:MM]` timestamp
- Add numbered "Completion notes:" section describing what was done
- Document any deviations from the original task description
- Note any issues encountered and how they were resolved

**Transformation Example:**
```markdown
# STATE 1 (Not Started):
### 3.7 ⬜ [NOT STARTED] Complete flag implementation in hyly-n8n-openwebui

#### 3.7.1 Task Description:
- Add `--clean` flag functionality to remove .env overrides
- Test the deployer with `--dry-run` and actual deployment

# STATE 2 (In Progress):
### 3.7 🔄 [IN PROGRESS] Complete flag implementation in hyly-n8n-openwebui

#### 3.7.1 Task Description:
- Add `--clean` flag functionality to remove .env overrides
- Test the deployer with `--dry-run` and actual deployment

# STATE 3 (Completed):
### 3.7 ✅ [2025-09-06 14:30] Complete flag implementation in hyly-n8n-openwebui

#### 3.7.1 Task Description:
- Add `--clean` flag functionality to remove .env overrides
- Test the deployer with `--dry-run` and actual deployment

#### 3.7.2 Completion notes:
- Successfully added --clean flag functionality
- Dry-run test passed without errors
- Actual deployment completed successfully
- Note: Found and fixed issue with .env path resolution
```

### 4.3 Critical Rule
**[CRITICAL]** Continue executing tasks until ALL tasks are complete. Do not stop partway through the list.