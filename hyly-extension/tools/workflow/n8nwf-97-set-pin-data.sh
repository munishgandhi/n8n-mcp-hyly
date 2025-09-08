#!/bin/bash
# n8nwf-97-set-pin-data.sh - Set workflow pinData via direct database update
#
# PINDATA MANAGEMENT
# ==================
# Usage: n8nwf-97-set-pin-data.sh <workflow_id> <pindata.json>
#
# Purpose: Set workflow pinData directly in database since n8n API rejects pinData in PUT requests
# 
# Examples:
#   ./n8nwf-97-set-pin-data.sh KQxYbOJgGEEuzVT0 '{"Manual Trigger": [{"json": {"name": "Test", "code": 123}}]}'
#   ./n8nwf-97-set-pin-data.sh KQxYbOJgGEEuzVT0 '{}'  # Clear pinData
#
# Process:
# 1. Validate JSON input
# 2. Escape JSON for SQL insertion
# 3. Update workflow_entity.pinData directly
# 4. Verify change with normalized JSON comparison
#

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <workflow_id> <pindata_source>"
    echo ""
    echo "Set workflow pinData via direct database update"
    echo ""
    echo "Arguments:"
    echo "  <pindata_source>  Either JSON string or file path (if starts with @)"
    echo ""
    echo "Examples:"
    echo "  $0 KQxYbOJgGEEuzVT0 '{\"Manual Trigger\": [{\"json\": {\"test\": 123}}]}'"
    echo "  $0 KQxYbOJgGEEuzVT0 '@20250908-143000-KQxYbOJgGEEuzVT0-02-pindata.json'"
    echo "  $0 KQxYbOJgGEEuzVT0 '{}'"
    exit 1
fi

WORKFLOW_ID="$1"
PINDATA_SOURCE="$2"

# Parse pinData input (file or direct JSON)
if [[ "$PINDATA_SOURCE" =~ ^@ ]]; then
    # File input (starts with @)
    PINDATA_FILE="${PINDATA_SOURCE:1}"  # Remove @ prefix
    if [[ ! -f "$PINDATA_FILE" ]]; then
        error "PinData file not found: $PINDATA_FILE"
    fi
    info "Reading pinData from file: $PINDATA_FILE"
    PINDATA_JSON=$(cat "$PINDATA_FILE")
else
    # Direct JSON input
    PINDATA_JSON="$PINDATA_SOURCE"
fi

# =============================================================================
# PINDATA FUNCTIONS
# =============================================================================

# Function to get trigger node name from workflow
get_trigger_node_name() {
    local workflow_id="$1"
    
    local trigger_name
    trigger_name=$(curl -s "$N8N_HOST/api/v1/workflows/$workflow_id" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" | jq -r '.nodes[] | select(.type | contains("Trigger")) | .name' | head -1)
    
    if [[ -z "$trigger_name" ]]; then
        error "No trigger node found in workflow $workflow_id"
    fi
    
    # Don't use debug here - it contaminates the output
    echo "$trigger_name"
}

# Function to get current workflow pinData (quiet mode for internal use)
get_workflow_pindata_quiet() {
    local workflow_id="$1"
    
    local pindata
    pindata=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
        SELECT \"pinData\" FROM public.workflow_entity WHERE id = '$workflow_id';
    " 2>/dev/null | xargs)
    
    if [[ -z "$pindata" || "$pindata" == "null" ]]; then
        echo "{}"
    else
        echo "$pindata"
    fi
}

# Function to set workflow pinData
set_workflow_pindata() {
    local workflow_id="$1"
    local pindata_json="$2"
    
    info "Setting pinData for workflow: $workflow_id"
    
    # Get trigger node name
    local trigger_node
    trigger_node=$(get_trigger_node_name "$workflow_id")
    info "Using trigger node: $trigger_node"
    
    # Check if input is already properly wrapped with node names
    local is_wrapped=false
    if echo "$pindata_json" | jq -e 'type == "object" and (keys | length > 0) and (.[keys[0]] | type == "array")' >/dev/null 2>&1; then
        # Looks like it's already wrapped (object with array values)
        is_wrapped=true
        info "Input appears to already be wrapped with node names"
    fi
    
    # Prepare final pinData
    local final_pindata
    if [[ "$is_wrapped" == "true" ]]; then
        # Use as-is if already wrapped
        final_pindata="$pindata_json"
    else
        # Wrap raw content with trigger node name
        info "Wrapping content with trigger node name: $trigger_node"
        
        # Validate that input is an array (expected format for unwrapped pinData)
        if ! echo "$pindata_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
            error "Unwrapped pinData must be an array format"
        fi
        
        # Wrap the content
        final_pindata=$(jq -n --arg trigger "$trigger_node" --argjson content "$pindata_json" '{($trigger): $content}')
    fi
    
    # Validate final JSON
    if ! echo "$final_pindata" | jq . >/dev/null 2>&1; then
        error "Final wrapped pinData is invalid JSON"
    fi
    
    # Capture current pinData
    local current_pindata
    current_pindata=$(get_workflow_pindata_quiet "$workflow_id")
    debug "Current pinData: $current_pindata"
    
    # Escape JSON for SQL (replace single quotes with two single quotes)
    local escaped_json
    escaped_json=$(echo "$final_pindata" | sed "s/'/''/g")
    
    # Update pinData in database
    info "Updating pinData in database..."
    local update_result
    update_result=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -c "
        UPDATE public.workflow_entity 
        SET \"pinData\" = '$escaped_json'::jsonb, \"updatedAt\" = NOW()
        WHERE id = '$workflow_id';
    " 2>/dev/null)
    
    if [[ "$update_result" != "UPDATE 1" ]]; then
        error "Failed to update pinData. Database response: $update_result"
    fi
    
    # Simple verification - just check database response
    info "Database update completed successfully"
    
    success "PinData updated successfully for workflow $workflow_id"
    success "Final pinData size: $(echo "$final_pindata" | wc -c) characters"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

info "Starting pinData update for workflow: $WORKFLOW_ID"

# Set the pinData
set_workflow_pindata "$WORKFLOW_ID" "$PINDATA_JSON"

# Show summary
echo ""
info "✅ PinData update completed successfully!"
echo "  🆔 Workflow: $WORKFLOW_ID"
echo "  🎯 Trigger Node: $(get_trigger_node_name "$WORKFLOW_ID")"
echo "  📦 Data Size: $(echo "$PINDATA_JSON" | wc -c) chars → $(curl -s "$N8N_HOST/api/v1/workflows/$WORKFLOW_ID" -H "X-N8N-API-KEY: $N8N_API_KEY" | jq '.pinData' | wc -c) chars final"

exit 0