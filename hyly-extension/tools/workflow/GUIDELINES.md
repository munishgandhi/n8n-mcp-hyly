# n8n Workflow Script Development Guidelines

## Core Principles

### 1. Self-Documenting Headers
Every `n8nwf-*.sh` script must have a comprehensive header that includes:

```bash
#!/bin/bash
# n8nwf-##-scriptname.sh - Brief description
#
# CATEGORY/PURPOSE - DETAILED STEPS
# =================================
# Total execution time: ~X.X seconds (breakdown of major operations)
#
# Step 1: Input Description
# - File: Input file format and naming convention
# - Content: What the input contains
# - Purpose: Why this input is needed
#
# Step 2: Processing Description  
# - Process: What transformations occur
# - Method: How the processing works (queries, APIs, etc.)
# - Result: What gets produced
#
# Step 3: Output Description
# - File: Output file format and naming convention
# - Content: What the output contains  
# - Purpose: How this feeds into next lifecycle stage
#
# Usage: n8nwf-##-scriptname.sh <required_args> [optional_args]
#
# Examples:
#   ./n8nwf-##-scriptname.sh arg1 arg2
#   ./n8nwf-##-scriptname.sh arg1  # optional arg example
#
```

**ESSENTIAL**: All scripts must document their process as detailed steps showing inputs, transformations, and outputs with timing information.

### 2. Always Source Common Functions
Every script MUST source the common functions:

```bash
# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"
```

**Required Logging Functions** (provided by n8nwf-99-common.sh):
- `info()` - Progress updates and informational messages (10+ uses typical)
- `success()` - Success confirmations with checkmark (5+ uses typical)
- `error()` - Fatal errors with automatic exit (5+ uses typical)
- `warning()` - Non-fatal warnings with warning icon (3+ uses typical)
- `debug()` - Debug output (controlled by DEBUG environment variable)

**Usage Examples:**
```bash
info "Starting workflow execution: $WORKFLOW_ID"
success "Execution completed with status: $status"
error "Docker container 'hyly-n8n-app' is not running"
warning "No new execution detected. Check if workflow triggered properly."
debug "Checked after ${wait_time}s, next check in ${poll_interval}s..."
```

**Critical**: Scripts will fail immediately without n8nwf-99-common.sh due to "command not found" errors.

### 3. Speed is Critical
- No unnecessary sleeps or delays
- Use API calls over CLI when faster (API is ~148x faster)
- Minimize file I/O operations
- Use database queries for verification instead of API re-downloads
- Batch operations when possible

### 4. Simple Atomicity
- Each script should do one thing well
- Operations should be atomic (all succeed or all fail)
- Clean up temp files on exit
- Use `set -euo pipefail` for error handling
- Validate inputs before processing

### 5. Workflow Directory is Sacred
- **NEVER** specify input/output directories as arguments
- All operations use `$WORKFLOW_DIRECTORY` from common functions
- Input files: `*-01-edited.json`, `*-02-uploaded.json`
- Output follows lifecycle naming convention
- PinData stored in `$WORKFLOW_DIRECTORY/pindata/`

## Script Numbering Convention

```
n8nwf-01-upload.sh          # Core workflow upload
n8nwf-90-*.sh              # Utilities (90-99 range)
n8nwf-96-cleanjson.sh      # JSON cleaning utility
n8nwf-97-set-pin-data.sh   # PinData management
n8nwf-98-set-folder.sh     # Folder management
n8nwf-99-common.sh         # Shared functions (always 99)
```

## Lifecycle File Naming

```
YYYYMMDD-HHMMSS-{workflowId}-01-edited.json
YYYYMMDD-HHMMSS-{workflowId}-02-uploaded.json
```

## Required Script Structure

```bash
#!/bin/bash
# Self-documenting header (see above)

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <args>"
    echo "Description..."
    exit 1
fi

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Functions here...

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Main execution logic
exit 0
```

## Error Handling

- Use common logging functions: `info`, `success`, `warning`, `error`, `debug`
- Validate all inputs before processing
- Clean up resources on failure
- Provide meaningful error messages
- Use `error` function for fatal errors (auto-exits)

## Performance Guidelines

- Database operations preferred over API calls for verification
- No unnecessary sleeps - measure actual timing needs
- Use `jq` for JSON processing (faster than API round-trips)
- Minimize file system operations
- Cache expensive operations when possible

## Security

- Never log API keys or sensitive data
- Source environment variables from correct location: `/home/mg/src/n8n-env/.env`
- Validate all external inputs
- Use proper escaping for SQL operations
- Never commit secrets to files

## Testing

- Test with real workflow ID: `KQxYbOJgGEEuzVT0`
- Verify operations with before/after database queries
- Test with various input sizes (simple and complex pinData)
- Validate error conditions and edge cases