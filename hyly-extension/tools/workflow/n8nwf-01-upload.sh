#!/bin/bash
# n8nwf-01-upload.sh - Upload and verify workflows using API calls
#
# WORKFLOW UPLOAD PROCESS - DETAILED STEPS
# ========================================
# Total execution time: ~0.3 seconds (API call ~0.028s, database queries ~0.1s each)
#
# Step 1: Input - 01-edited.json (Full Source)
# - File: YYYYMMDD-HHMMSS-{workflowId}-01-edited.json  
# - Content: Complete workflow with ALL metadata
# - Fields: name, nodes, connections, settings, pinData, staticData, versionId, 
#   updatedAt, createdAt, meta, shared, tags, mergeInfo, etc.
# - Purpose: Source of truth with full workflow definition
#
# Step 2: Name Cleaning & Timestamp
# - Extract base name: jq -r '.name' → "t.HelloWorld v20250718-190747"
# - Clean existing timestamps: Remove v20250718-190747 using regex patterns:
#   * s/v[0-9]\{8\}-[0-9]\{6\}//g (removes v-prefixed timestamps)
#   * s/[0-9]\{8\}-[0-9]\{6\}//g (removes bare timestamps)
# - Add new timestamp: "t.HelloWorld v20250907-222433"
# - Result: Single clean timestamp in Eastern timezone
#
# Step 3: Database Pre-Upload State Capture  
# - Query: SELECT id, "name", "versionId", "updatedAt" FROM workflow_entity WHERE id='{workflowId}'
# - Capture: ID, name, versionId, updatedAt for before/after comparison
# - Purpose: Robust verification that database changes occurred
#
# Step 4: Metadata Stripping & 02-uploaded.json Creation
# - Process: Extract only API-compatible fields using jq
# - Keep: name, nodes, connections, settings (ONLY these 4 fields)
# - Remove: pinData, staticData, versionId, updatedAt, createdAt, meta, shared, tags, mergeInfo
# - Reason: n8n API rejects additional properties in PUT requests
# - File: YYYYMMDD-HHMMSS-{workflowId}-02-uploaded.json
# - Content: Clean structure ready for API upload
#   {
#     "name": "t.HelloWorld v20250907-222433",
#     "nodes": [...],
#     "connections": {...}, 
#     "settings": {...}
#   }
#
# Step 5: API Upload via PUT
# - Endpoint: PUT http://localhost:5678/api/v1/workflows/{workflowId}
# - Headers: Content-Type: application/json, X-N8N-API-KEY: {jwt_token}
# - Body: Clean JSON from step 4 (only 4 fields)
# - n8n Action: Updates workflow, generates new versionId, sets updatedAt
# - Processing: Database updated immediately (no wait needed)
#
# Step 6: Database Post-Upload Verification
# - Query: Same SELECT statement as Step 3
# - Compare before/after values:
#   * ID: MUST be identical (same workflow)
#   * name: MUST be different (new timestamp applied)  
#   * versionId: MUST be different (n8n generates new UUID)
#   * updatedAt: MUST be different (n8n updates timestamp)
# - Verification: Confirms database-level changes occurred correctly
# - Fail-fast: Script exits immediately if any verification fails
#
# Step 7: Report Generation (if requested)
# - Show: workflow name, ID, node count, version change (before → after)
# - Files: Input file, uploaded file paths
# - Summary: Complete upload and verification status
#
# Result: Workflow updated in n8n with clean name, database-verified changes,
# lifecycle files created for tracking (01-edited → 02-uploaded)
#
# Notes:
# - pinData is NOT uploaded (API rejects it) but preserved in 01-edited.json
# - Database verification is more reliable than API re-download verification
# - Single timestamp prevents accumulation (v20250101-120000 v20250102-130000)
# - Eastern timezone used for all timestamps
#

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# Parse arguments
REPORT=true
_INPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --noreport)
            REPORT=false
            shift
            ;;
        --input)
            _INPUT_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 <workflow-id> [--input <file>] [--noreport]"
            echo ""
            echo "Upload and verify n8n workflow using API calls"
            echo ""
            echo "Arguments:"
            echo "  <workflow-id>     n8n workflow ID to upload to"
            echo ""  
            echo "Options:"
            echo "  --input <file>    Specify input file (default: auto-detect latest 01-edited.json)"
            echo "  --noreport        Skip report generation"
            echo "  --help            Show this help"
            exit 0
            ;;
        *)
            if [[ -z "${_WORKFLOW_ID:-}" ]]; then
                _WORKFLOW_ID="$1"
            else
                error "Unknown argument: $1"
            fi
            shift
            ;;
    esac
done

if [[ -z "${_WORKFLOW_ID:-}" ]]; then
    error "Workflow ID is required. Use --help for usage information."
fi

info "Starting workflow upload for: $_WORKFLOW_ID"

# Setup workflow parameters using common function
setup_workflow_params "$_WORKFLOW_ID" "$_INPUT_FILE"

# Read workflow JSON using common function
read_workflow_json

# Test n8n connection
test_n8n_connection

# Stage 0: Database Pre-Upload Verification
info "Capturing pre-upload database state..."
DB_BEFORE=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "SELECT id, \"name\", \"versionId\", \"updatedAt\" FROM public.workflow_entity WHERE id='$WORKFLOW_ID';" 2>/dev/null | xargs)

if [[ -z "$DB_BEFORE" ]]; then
    error "Workflow $WORKFLOW_ID not found in database"
fi

# Parse pre-upload values
DB_BEFORE_ID=$(echo "$DB_BEFORE" | cut -d'|' -f1 | xargs)
DB_BEFORE_NAME=$(echo "$DB_BEFORE" | cut -d'|' -f2 | xargs)
DB_BEFORE_VERSION=$(echo "$DB_BEFORE" | cut -d'|' -f3 | xargs)
DB_BEFORE_UPDATED=$(echo "$DB_BEFORE" | cut -d'|' -f4 | xargs)

info "Pre-upload: ID=$DB_BEFORE_ID, Name='$DB_BEFORE_NAME', Version=$DB_BEFORE_VERSION"

# Generate timestamp for upload name
UPLOAD_NAME="$WORKFLOW_NAME_UPLOAD"

# Strip metadata and prepare for upload (pinData not accepted by PUT API - managed separately)
WORKFLOW_FOR_UPLOAD=$(echo "$WORKFLOW_JSON" | jq --arg name "$UPLOAD_NAME" '{
    name: $name,
    nodes: .nodes,
    connections: .connections,
    settings: .settings
}')

# Same clean structure for 02-uploaded.json file
UPLOADED_DATA="$WORKFLOW_FOR_UPLOAD"

info "Uploading workflow via API..."
info "Upload name: $UPLOAD_NAME"

# Stage 1: Upload workflow via API
UPLOAD_RESPONSE=$(update_workflow_api "$WORKFLOW_ID" "$WORKFLOW_FOR_UPLOAD")

# Generate filename at operation time and save clean uploaded data
UPLOADED_FILE=$(generate_lifecycle_filename "$WORKFLOW_ID" "02-uploaded")
echo "$UPLOADED_DATA" | jq . > "$UPLOADED_FILE"
success "Saved clean upload data to $UPLOADED_FILE"

# Database should be updated immediately after API call

# Stage 1.5: Database Post-Upload Verification
info "Capturing post-upload database state..."
DB_AFTER=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "SELECT id, \"name\", \"versionId\", \"updatedAt\" FROM public.workflow_entity WHERE id='$WORKFLOW_ID';" 2>/dev/null | xargs)

# Parse post-upload values
DB_AFTER_ID=$(echo "$DB_AFTER" | cut -d'|' -f1 | xargs)
DB_AFTER_NAME=$(echo "$DB_AFTER" | cut -d'|' -f2 | xargs)
DB_AFTER_VERSION=$(echo "$DB_AFTER" | cut -d'|' -f3 | xargs)
DB_AFTER_UPDATED=$(echo "$DB_AFTER" | cut -d'|' -f4 | xargs)

info "Post-upload: ID=$DB_AFTER_ID, Name='$DB_AFTER_NAME', Version=$DB_AFTER_VERSION"

# Database verification checks
if [[ "$DB_BEFORE_ID" != "$DB_AFTER_ID" ]]; then
    error "DATABASE VERIFICATION FAILED: ID changed (before: $DB_BEFORE_ID, after: $DB_AFTER_ID)"
fi

if [[ "$DB_BEFORE_NAME" == "$DB_AFTER_NAME" ]]; then
    error "DATABASE VERIFICATION FAILED: Name unchanged (expected: '$UPLOAD_NAME', got: '$DB_AFTER_NAME')"
fi

if [[ "$DB_BEFORE_VERSION" == "$DB_AFTER_VERSION" ]]; then
    error "DATABASE VERIFICATION FAILED: Version unchanged ($DB_BEFORE_VERSION)"
fi

if [[ "$DB_BEFORE_UPDATED" == "$DB_AFTER_UPDATED" ]]; then
    error "DATABASE VERIFICATION FAILED: Updated timestamp unchanged ($DB_BEFORE_UPDATED)"
fi

if [[ "$DB_AFTER_NAME" != "$UPLOAD_NAME" ]]; then
    error "DATABASE VERIFICATION FAILED: Name mismatch (expected: '$UPLOAD_NAME', got: '$DB_AFTER_NAME')"
fi

success "Database verification passed: All fields changed correctly"

# Stage 2: Report Generation (if requested)
if [[ "$REPORT" == "true" ]]; then
    info "Upload completed successfully!"
    
    echo ""
    echo "📊 Upload Summary:"
    echo "  📋 Workflow: $DB_AFTER_NAME"
    echo "  🆔 ID: $WORKFLOW_ID"
    echo "  📝 Nodes: $(echo "$WORKFLOW_FOR_UPLOAD" | jq '.nodes | length')"
    echo "  📄 Input: $(basename "$LATEST_EDITED")"
    echo "  📤 Upload: $(basename "$UPLOADED_FILE")"
    echo "  🔄 Version: $DB_BEFORE_VERSION → $DB_AFTER_VERSION"
    echo ""
    
    success "Workflow upload and database verification complete!"
else
    success "Upload complete (no report requested)"
fi

exit 0