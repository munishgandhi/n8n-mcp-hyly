# Workflows Directory

This directory contains workflow development artifacts and test files.

## Structure

- **lifecycle/**: Active workflow development files following lifecycle naming convention
- **tests/**: Test workflows and validation results

## File Naming Convention

All lifecycle files follow: `YYYYMMDD-HHMMSS-{workflowId}-{stage}-{description}.{ext}`

### Stage Numbers and Descriptions

| Stage | Description | Example |
|-------|-------------|---------|
| 01-edited | Modified workflow ready for upload | `20250907-130201-KQxYbOJgGEEuzVT0-01-edited.json` |
| 02-uploaded | Successfully uploaded workflow | `20250907-130205-KQxYbOJgGEEuzVT0-02-uploaded.json` |
| 03-verified | Downloaded workflow after upload for verification | `20250907-130210-KQxYbOJgGEEuzVT0-03-verified.json` |
| 04-workflow | Current workflow definition | `20250907-130215-KQxYbOJgGEEuzVT0-04-workflow.json` |
| 05-trace | Execution trace data | `20250907-130220-KQxYbOJgGEEuzVT0-05-trace-676.json` |
| 06-errors | Execution with errors | `20250907-130225-KQxYbOJgGEEuzVT0-06-errors-676.json` |
| 06-noerrors | Execution without errors | `20250907-130225-KQxYbOJgGEEuzVT0-06-noerrors-676.json` |
| 07-fix-draft | Draft fixes (manual creation) | `20250907-130230-KQxYbOJgGEEuzVT0-07-fix-draft.json` |
| 07-fix | Validated fixes ready for merge | `20250907-130235-KQxYbOJgGEEuzVT0-07-fix.json` |
| 09-fix-final | Final fix validation result | `20250907-130240-KQxYbOJgGEEuzVT0-09-fix-final.json` |

### Execution ID Tracking

Files that involve workflow execution include the execution ID in the filename:
- `05-trace-{executionId}.json` - Full execution trace
- `06-errors-{executionId}.json` or `06-noerrors-{executionId}.json` - Status analysis

## Development Workflow

### Complete Lifecycle Process

1. **Download Baseline**
   ```bash
   n8nwf-download KQxYbOJgGEEuzVT0  # Creates 04-workflow.json
   ```

2. **Create Fix Draft** (Manual)
   - Analyze issues in 06-errors files
   - Create 07-fix-draft.json manually

3. **Validate Fixes**
   ```bash
   n8nwf-04-validate  # Validates draft, creates 07-fix.json
   ```

4. **Merge Fixes**
   ```bash
   n8nwf-05-mergefix  # Merges fixes, creates 01-edited.json
   ```

5. **Upload and Test**
   ```bash
   n8nwf-01-upload    # Uploads, creates 02-uploaded.json
   n8nwf-02-execute   # Executes, returns execution ID
   n8nwf-03-analyze   # Analyzes, creates 05-trace, 06-status
   ```

6. **Validate Success**
   - Check for 06-noerrors file
   - Verify workflow completes without errors

## File Organization

### lifecycle/
Active development files for specific workflows. Files are organized chronologically by timestamp, making it easy to track the development progression.

### tests/
Test workflows, validation results, and experimental workflows. Includes:
- MCP integration tests
- CLI execution tests  
- Validation test cases
- Reference workflows

## Cleanup

Old lifecycle files can be archived or removed after successful workflow deployment. Keep the final 04-workflow.json and successful 06-noerrors files for reference.