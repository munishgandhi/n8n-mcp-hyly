#!/bin/bash

# n8n-validate-connections.sh - Validate n8n workflow connections
# Usage: ./n8n-validate-connections.sh <workflow.json>

set -e

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8n-000-common.sh"

validate_connections() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        error "File not found: $json_file"
    fi
    
    info "Validating workflow connections in $(basename "$json_file")..."
    
    # Check if JSON is valid
    if ! jq . "$json_file" >/dev/null 2>&1; then
        error "Invalid JSON format"
    fi
    
    # Check if connections exist
    local has_connections=$(jq -r 'has("connections")' "$json_file")
    if [ "$has_connections" != "true" ]; then
        warning "No connections found in workflow"
        return 0
    fi
    
    # Check for missing connection properties
    local missing_props=$(jq -r '
        .connections | to_entries[] | 
        .key as $source | 
        .value.main[][]? | 
        select(.type == null or .index == null) | 
        "\($source) -> \(.node // "unknown")"
    ' "$json_file")
    
    if [ -n "$missing_props" ]; then
        error "Missing connection properties (type/index) in:\n$missing_props"
    fi
    
    # Check if target nodes exist
    local invalid_targets=$(jq -r '
        .nodes | map(.name) as $node_names |
        .connections | to_entries[] | 
        .value.main[][]? | 
        select(.node as $target | $node_names | index($target) == null) |
        .node
    ' "$json_file")
    
    if [ -n "$invalid_targets" ]; then
        error "Invalid connection targets (nodes don't exist):\n$invalid_targets"
    fi
    
    # Count connections and nodes
    local node_count=$(jq '.nodes | length' "$json_file")
    local connection_count=$(jq '.connections | keys | length' "$json_file")
    local total_links=$(jq '.connections | [.[] | .main[][]] | length' "$json_file")
    
    success "Connection validation passed!"
    info "  📊 Nodes: $node_count"
    info "  🔗 Source nodes with connections: $connection_count"  
    info "  📈 Total connection links: $total_links"
    
    return 0
}

# If script is run directly, validate the provided file
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <workflow.json>"
        exit 1
    fi
    
    validate_connections "$1"
fi