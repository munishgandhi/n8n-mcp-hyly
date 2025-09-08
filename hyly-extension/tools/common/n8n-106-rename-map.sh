#!/bin/bash
set -euo pipefail

# n8n-106-rename-map.sh - Generate simple rename map from topology
# Input: topology.json file
# Output: rename.json with {old: new} mappings

source "$(dirname "$0")/n8n-000-common.sh"
source "$(dirname "$0")/n8n-001-semantic-names.sh"

# Main function
main() {
    local topology_file="${1:-}"
    
    if [ -z "$topology_file" ] || [ ! -f "$topology_file" ]; then
        error "Usage: $0 <topology-file>"
    fi
    
    # Extract workflow ID from topology filename and generate new timestamp
    local basename=$(basename "$topology_file")
    local timestamp=$(TZ=America/New_York date +"%Y%m%d-%H%M%S")
    local workflow_id=$(echo "$basename" | sed 's/.*-\([A-Za-z0-9]\{16\}\)-04-topology\.json$/\1/')
    local output_dir=$(dirname "$topology_file")
    local output_file="$output_dir/${timestamp}-${workflow_id}-04-rename.json"
    
    info "Generating rename map from topology..."
    info "Input: $topology_file"
    info "Output: $output_file"
    
    # First, generate semantic names for nodes without them
    info "Analyzing nodes for semantic naming..."
    
    # Build a semantic name map in bash
    local semantic_map_file="/tmp/semantic_map_$$.json"
    echo '{}' > "$semantic_map_file"
    
    # Process all nodes from topology
    local all_nodes=$(cat "$topology_file" | jq -r '
        [.topology.primary[] | select(has("original")) | {original, suggested, type}] +
        [.topology.primary[] | select(.type == "parallel") | .branches[] | {original, suggested, type}] +
        [.topology.secondary[] | {original, suggested, type}]
        | .[] | @json')
    
    while IFS= read -r node_json; do
        if [ -n "$node_json" ]; then
            local original=$(echo "$node_json" | jq -r '.original')
            local suggested=$(echo "$node_json" | jq -r '.suggested')
            local node_type=$(echo "$node_json" | jq -r '.type')
            
            # Check if node needs semantic name
            if ! has_semantic_part "$original"; then
                # Generate semantic name based on type
                local semantic_name=$(generate_semantic_name_from_type "$original" "$node_type" "$suggested")
                local full_name="$suggested $semantic_name"
                
                # Add to map
                jq --arg key "$original" --arg value "$full_name" \
                   '. + {($key): $value}' "$semantic_map_file" > "${semantic_map_file}.tmp" && \
                   mv "${semantic_map_file}.tmp" "$semantic_map_file"
            else
                # Keep existing semantic part
                local existing_semantic=$(extract_semantic_part "$original")
                local full_name="$suggested $existing_semantic"
                
                # Add to map
                jq --arg key "$original" --arg value "$full_name" \
                   '. + {($key): $value}' "$semantic_map_file" > "${semantic_map_file}.tmp" && \
                   mv "${semantic_map_file}.tmp" "$semantic_map_file"
            fi
        fi
    done <<< "$all_nodes"
    
    # Generate final rename map using the semantic map
    cat "$semantic_map_file" > "$output_file"
    
    # Clean up
    rm -f "$semantic_map_file"
    
    # Show summary
    local rename_count=$(cat "$output_file" | jq 'keys | length')
    success "Generated rename map with $rename_count entries"
    
    # Show sample entries
    info "Sample renames:"
    cat "$output_file" | jq -r 'to_entries[:3][] | "  \(.key) → \(.value)"'
    
    echo "$output_file"
}

main "$@"