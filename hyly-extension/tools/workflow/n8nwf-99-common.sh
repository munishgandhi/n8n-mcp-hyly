#!/bin/bash
# n8nwf-99-common.sh - Common functions and variable setup for n8n workflow tools
#
# SHARED FUNCTIONS FOR N8N WORKFLOW SCRIPTS
# ========================================
# 
# This script provides common functions, environment setup, and directory management
# for all n8nwf-* workflow automation scripts.
#
# Key Features:
# - Environment variable setup (API keys, host configuration)
# - Logging functions (info, success, warning, error, debug)
# - Directory management (workflow directories, file paths)
# - Timestamp utilities for workflow naming
# - Database and API configuration
#
# Usage:
#   source "$SCRIPT_DIR/n8nwf-99-common.sh"
#
# Environment Variables Required:
#   N8N_HOST - n8n instance URL (default: http://localhost:5678)
#   N8N_API_KEY - JWT authentication token (read from /home/mg/src/n8n-env/.env)
#
# Directory Structure:
#   /home/mg/src/n8n-mcp-hyly/hyly-extension/
#   ├── tools/workflow/        # n8nwf-* scripts
#   ├── test-lifecycle/        # workflow test files
#   └── workflow-directory/    # all workflow operations happen here
#       ├── *-01-edited.json   # edited workflow files
#       ├── *-02-uploaded.json # uploaded workflow files  
#       └── *-02-pindata.json  # pinData files (follows lifecycle naming)
#

# Prevent multiple sourcing
if [[ "${N8NWF_COMMON_LOADED:-}" == "true" ]]; then
    return 0
fi
N8NWF_COMMON_LOADED=true

set -euo pipefail

# =============================================================================
# DIRECTORY SETUP
# =============================================================================

# Script directory detection (works from any n8nwf-* script)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    if [[ "${#BASH_SOURCE[@]}" -gt 1 ]]; then
        # Called from a script
        SCRIPT_DIR="$(dirname "${BASH_SOURCE[1]}")"
    else
        # Sourced directly - use current directory of this common script
        SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    fi
fi

# Extension root directory
if [[ -z "${EXTENSION_ROOT:-}" ]]; then
    EXTENSION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Current workflow directory (where lifecycle files are stored)
WORKFLOW_DIR="$(pwd)"

# DEBUG: Directory variables (disabled for cleaner output)
# echo "🐛 DEBUG: SCRIPT_DIR = '$SCRIPT_DIR'"
# echo "🐛 DEBUG: EXTENSION_ROOT = '$EXTENSION_ROOT'" 
# echo "🐛 DEBUG: WORKFLOW_DIR = '$WORKFLOW_DIR'"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging functions
info() { echo "ℹ️  $*"; }
success() { echo "✅ $*"; }
error() { echo "❌ $*" >&2; exit 1; }
warning() { echo "⚠️  $*"; }
debug() { echo "🐛 DEBUG: $*"; }

# =============================================================================
# N8N ENVIRONMENT SETUP
# =============================================================================

# N8N Host (default to localhost)
N8N_HOST="${N8N_HOST:-http://localhost:5678}"

# N8N API Key (try multiple sources in correct priority order)
if [[ -z "${N8N_API_KEY:-}" ]]; then
    # Try n8n-env .env file first (correct one)
    if [[ -f "/home/mg/src/n8n-env/.env" ]]; then
        N8N_API_KEY="$(grep N8N_API_KEY /home/mg/src/n8n-env/.env 2>/dev/null | cut -d'=' -f2 || echo '')"
    fi
    
    # Try vc-mgr .env file as fallback
    if [[ -z "${N8N_API_KEY:-}" && -f "/home/mg/src/vc-mgr/.env" ]]; then
        N8N_API_KEY="$(grep N8N_API_KEY /home/mg/src/vc-mgr/.env 2>/dev/null | cut -d'=' -f2 || echo '')"
    fi
    
    # Try local .env file
    if [[ -z "${N8N_API_KEY:-}" && -f "$EXTENSION_ROOT/.env" ]]; then
        N8N_API_KEY="$(grep N8N_API_KEY "$EXTENSION_ROOT/.env" 2>/dev/null | cut -d'=' -f2 || echo '')"
    fi
    
    # Try parent project .env
    if [[ -z "${N8N_API_KEY:-}" && -f "$EXTENSION_ROOT/../.env" ]]; then
        N8N_API_KEY="$(grep N8N_API_KEY "$EXTENSION_ROOT/../.env" 2>/dev/null | cut -d'=' -f2 || echo '')"
    fi
fi

# Container name for Docker operations
CONTAINER_NAME="${CONTAINER_NAME:-hyly-n8n-app}"

# DEBUG: Environment variables (disabled for cleaner output)
# debug "N8N_HOST = '$N8N_HOST'"
# debug "N8N_API_KEY = '$(echo ${N8N_API_KEY:-NOTSET} | cut -c1-20)...'"
# debug "CONTAINER_NAME = '$CONTAINER_NAME'"

# Validate API key
if [[ -z "${N8N_API_KEY:-}" ]]; then
    error "N8N_API_KEY environment variable not set! Check .env files."
fi

# =============================================================================
# WORKFLOW PARAMETER SETUP
# =============================================================================

# Function to setup workflow parameters
# Usage: setup_workflow_params <workflow_id> [input_file]
setup_workflow_params() {
    local workflow_id="$1"
    local input_file="${2:-}"
    
    # Set global workflow parameters
    WORKFLOW_ID="$workflow_id"
    INPUT_FILE="$input_file"
    
    # Ensure lifecycle directory exists
    if [[ ! -d "lifecycle" ]]; then
        mkdir -p lifecycle
        info "Created lifecycle directory"
    fi
    
    # Find input file (01-edited.json)
    if [[ -n "$INPUT_FILE" ]]; then
        LATEST_EDITED="$INPUT_FILE"
        if [[ ! -f "$LATEST_EDITED" ]]; then
            error "Specified input file not found: $INPUT_FILE"
        fi
    else
        LATEST_EDITED=$(find . -name "*-${WORKFLOW_ID}-01-edited.json" 2>/dev/null | sort -r | head -1)
        
        if [[ -z "$LATEST_EDITED" ]]; then
            error "No edited file found for workflow $WORKFLOW_ID (pattern: *-${WORKFLOW_ID}-01-edited.json)"
        fi
    fi
    
    # Generate upload name with current timestamp (clean existing timestamps first)
    if [[ -f "$LATEST_EDITED" ]]; then
        BASE_NAME=$(jq -r '.name // "Unknown Workflow"' "$LATEST_EDITED" 2>/dev/null || echo "Unknown Workflow")
        # Clean any existing timestamps (both with and without 'v' prefix) 
        CLEAN_NAME=$(echo "$BASE_NAME" | sed 's/v[0-9]\{8\}-[0-9]\{6\}//g' | sed 's/[0-9]\{8\}-[0-9]\{6\}//g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
        WORKFLOW_NAME_UPLOAD="${CLEAN_NAME} v$(date +%Y%m%d-%H%M%S)"
    else
        WORKFLOW_NAME_UPLOAD="Workflow v$(date +%Y%m%d-%H%M%S)"
    fi
    
    # DEBUG: Workflow parameters
    debug "WORKFLOW_ID = '$WORKFLOW_ID'"
    debug "INPUT_FILE = '$INPUT_FILE'"
    debug "LATEST_EDITED = '$LATEST_EDITED'"
    debug "WORKFLOW_NAME_UPLOAD = '$WORKFLOW_NAME_UPLOAD'"
    
    info "Using input file: $(basename "$LATEST_EDITED")"
    info "Upload name: $WORKFLOW_NAME_UPLOAD"
}

# =============================================================================
# FILE OPERATIONS
# =============================================================================

# Function to generate timestamped filename at operation time
# Usage: generate_lifecycle_filename <workflow_id> <stage>
# Example: generate_lifecycle_filename "KQxYbOJgGEEuzVT0" "02-uploaded" 
generate_lifecycle_filename() {
    local workflow_id="$1"
    local stage="$2"
    local timestamp=$(TZ=America/New_York date +%Y%m%d-%H%M%S)
    
    echo "${timestamp}-${workflow_id}-${stage}.json"
}

# Function to read workflow JSON
read_workflow_json() {
    if [[ -z "${LATEST_EDITED:-}" ]]; then
        error "No input file specified. Call setup_workflow_params first."
    fi
    
    WORKFLOW_JSON=$(cat "$LATEST_EDITED") || error "Failed to read workflow file: $LATEST_EDITED"
    debug "Read workflow JSON ($(echo "$WORKFLOW_JSON" | jq '.nodes | length' 2>/dev/null || echo 0) nodes)"
}

# Function to validate JSON
validate_json() {
    local json_string="$1"
    local description="${2:-JSON}"
    
    if ! echo "$json_string" | jq . >/dev/null 2>&1; then
        error "Invalid $description"
    fi
    debug "$description validation passed"
}

# =============================================================================
# N8N API OPERATIONS  
# =============================================================================

# Function to test n8n connectivity
test_n8n_connection() {
    info "Testing n8n connection..."
    
    local response
    response=$(curl -sf "$N8N_HOST/healthz" 2>/dev/null || echo "FAILED")
    
    if [[ "$response" == *"ok"* ]]; then
        success "n8n server is reachable at $N8N_HOST"
        return 0
    else
        warning "n8n server may not be responding at $N8N_HOST"
        return 1
    fi
}

# Function to get workflow via API
get_workflow_api() {
    local workflow_id="$1"
    local output_file="${2:-}"
    
    info "Fetching workflow $workflow_id via API..."
    
    local api_response
    api_response=$(curl -s "$N8N_HOST/api/v1/workflows/$workflow_id" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" 2>/dev/null)
    
    # Check if API call succeeded
    if ! echo "$api_response" | jq -e '.id' > /dev/null 2>&1; then
        error "Failed to fetch workflow via API. Response: $api_response"
    fi
    
    # Validate response
    validate_json "$api_response" "API response"
    
    # Save to file if specified
    if [[ -n "$output_file" ]]; then
        echo "$api_response" > "$output_file"
        success "Saved workflow to $output_file"
    fi
    
    # Return response for further processing
    echo "$api_response"
}

# Function to update workflow via API
update_workflow_api() {
    local workflow_id="$1"
    local workflow_json="$2"
    
    info "Updating workflow $workflow_id via API..."
    
    # Validate input JSON
    validate_json "$workflow_json" "workflow JSON"
    
    # Make API call (using same pattern as working test scripts)
    local api_response
    api_response=$(curl -s "$N8N_HOST/api/v1/workflows/$workflow_id" \
        -X PUT \
        -H "Content-Type: application/json" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -d "$workflow_json" 2>/dev/null)
    
    # Check if API call succeeded by testing for JSON response with id field
    if ! echo "$api_response" | jq -e '.id' > /dev/null 2>&1; then
        error "Failed to update workflow via API. Response: $api_response"
    fi
    
    # Validate response
    validate_json "$api_response" "API response"
    
    success "Workflow updated successfully"
    echo "$api_response"
}

# =============================================================================
# DOCKER OPERATIONS
# =============================================================================

# Function to check if container is running
check_container() {
    local container_name="${1:-$CONTAINER_NAME}"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        error "Docker container '$container_name' is not running"
    fi
    debug "Container '$container_name' is running"
}

# =============================================================================
# EXECUTION TRACKING
# =============================================================================

# Function to get next execution ID (for tracking)
get_next_execution_id() {
    local workflow_id="$1"
    
    # Get latest executions to predict next ID
    local executions
    executions=$(curl -sf "$N8N_HOST/api/v1/executions?workflowId=$workflow_id&limit=1" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" 2>/dev/null | jq -r '.data[0].id // "0"' 2>/dev/null || echo "0")
    
    local next_id=$((executions + 1))
    debug "Predicted next execution ID: $next_id"
    echo "$next_id"
}

# =============================================================================
# INITIALIZATION
# =============================================================================

info "n8nwf common functions loaded from $SCRIPT_DIR"