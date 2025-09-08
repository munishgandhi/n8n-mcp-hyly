#!/bin/bash
# n8nwf-98-set-folder.sh - Set workflow folder via direct database update
#
# FOLDER MANAGEMENT
# =================
# Usage: n8nwf-98-set-folder.sh <workflow_id> <folder_name>
#
# Purpose: Move workflow to specified folder by updating workflow_entity.parentFolderId
# 
# Examples:
#   ./n8nwf-98-set-folder.sh KQxYbOJgGEEuzVT0 health
#   ./n8nwf-98-set-folder.sh KQxYbOJgGEEuzVT0 jobs
#
# Process:
# 1. Look up folder ID by name from folder table
# 2. Get current workflow folder assignment
# 3. Update workflow_entity.parentFolderId to new folder ID
# 4. Verify change by querying folder name
#

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <workflow_id> <folder_name>"
    echo ""
    echo "Set workflow folder via direct database update"
    echo ""
    echo "Available folders:"
    docker exec hyly-n8n-postgres psql -U n8n -d n8n -c "SELECT id, name FROM public.folder ORDER BY name;" 2>/dev/null || echo "  (Could not list folders)"
    echo ""
    echo "Examples:"
    echo "  $0 KQxYbOJgGEEuzVT0 health"
    echo "  $0 KQxYbOJgGEEuzVT0 jobs"
    exit 1
fi

WORKFLOW_ID="$1"
FOLDER_NAME="$2"

# =============================================================================
# FOLDER FUNCTIONS
# =============================================================================

# Function to get folder ID by name
get_folder_id() {
    local folder_name="$1"
    
    info "Looking up folder ID for: '$folder_name'"
    
    local folder_id
    folder_id=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
        SELECT id FROM public.folder WHERE name = '$folder_name' LIMIT 1;
    " 2>/dev/null | xargs)
    
    if [[ -z "$folder_id" ]]; then
        error "Folder '$folder_name' not found in database"
    fi
    
    debug "Found folder ID: $folder_id"
    echo "$folder_id"
}

# Function to get current workflow folder
get_current_folder() {
    local workflow_id="$1"
    
    local current_folder
    current_folder=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
        SELECT f.name 
        FROM public.workflow_entity w
        LEFT JOIN public.folder f ON w.\"parentFolderId\" = f.id
        WHERE w.id = '$workflow_id';
    " 2>/dev/null | xargs)
    
    echo "$current_folder"
}

# Function to set workflow folder
set_workflow_folder() {
    local workflow_id="$1"
    local folder_name="$2"
    
    info "Setting workflow $workflow_id to folder: '$folder_name'"
    
    # Get folder ID
    local folder_id
    folder_id=$(get_folder_id "$folder_name")
    
    # Capture current state
    local current_folder
    current_folder=$(get_current_folder "$workflow_id")
    info "Current folder: ${current_folder:-'(none)'}"
    
    # Update workflow_entity parentFolderId
    info "Updating workflow folder in database..."
    local update_result
    update_result=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -c "
        UPDATE public.workflow_entity 
        SET \"parentFolderId\" = '$folder_id', \"updatedAt\" = NOW()
        WHERE id = '$workflow_id';
    " 2>/dev/null)
    
    if [[ "$update_result" != "UPDATE 1" ]]; then
        error "Failed to update workflow folder. Database response: $update_result"
    fi
    
    # Verify the change
    local new_folder
    new_folder=$(get_current_folder "$workflow_id")
    
    if [[ "$new_folder" != "$folder_name" ]]; then
        error "Failed to set workflow folder. Expected: '$folder_name', Got: '$new_folder'"
    fi
    
    success "Workflow moved to folder: '$folder_name' (ID: $folder_id)"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

info "Starting folder update for workflow: $WORKFLOW_ID"

# Set the folder
set_workflow_folder "$WORKFLOW_ID" "$FOLDER_NAME"

# Show summary
echo ""
info "✅ Folder update completed successfully!"
echo "  🆔 Workflow: $WORKFLOW_ID"
echo "  📁 Folder: $FOLDER_NAME"

exit 0