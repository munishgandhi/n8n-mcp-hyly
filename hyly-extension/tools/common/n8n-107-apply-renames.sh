#!/bin/bash
set -euo pipefail

# n8n-107-apply-renames.sh - Apply rename map to workflow
# Input: workflow.json and rename.json
# Output: refactored workflow with new names

source "$(dirname "$0")/n8n-000-common.sh"

# Main function
main() {
    local workflow_file=""
    local rename_file=""
    local generate_report=true  # Default to true - always generate report
    local output_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --noreport)
                generate_report=false
                shift
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            *)
                if [ -z "$workflow_file" ]; then
                    workflow_file="$1"
                elif [ -z "$rename_file" ]; then
                    rename_file="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$workflow_file" ] || [ ! -f "$workflow_file" ] || [ -z "$rename_file" ] || [ ! -f "$rename_file" ]; then
        error "Usage: $0 <workflow-file> <rename-file>"
    fi
    
    # Extract workflow ID and generate output filename
    local basename=$(basename "$workflow_file")
    local workflow_id=$(echo "$basename" | sed 's/.*-\([A-Za-z0-9]\{16\}\)-04-workflow\.json$/\1/')
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local output_dir=$(dirname "$workflow_file")
    
    # Use provided output file or generate default
    if [ -z "$output_file" ]; then
        output_file="$output_dir/${timestamp}-${workflow_id}-01-edited.json"
    fi
    
    info "Applying renames to workflow..."
    info "Workflow: $workflow_file"
    info "Renames: $rename_file"
    info "Output: $output_file"
    
    # Count nodes before
    local nodes_before=$(jq '.nodes | length' "$workflow_file")
    info "Nodes before: $nodes_before"
    
    # Apply all renames in a single jq operation
    cat "$workflow_file" | jq --slurpfile rename_map "$rename_file" '
        # Get the rename map
        $rename_map[0] as $renames |
        
        # Update node names
        .nodes |= map(
            if $renames[.name] then
                .name = $renames[.name]
            else . end
        ) |
        
        # Update all string references in parameters
        .nodes |= map(
            .parameters |= walk(
                if type == "string" then
                    . as $str |
                    reduce ($renames | keys[]) as $old_name (
                        $str;
                        if . | test("\\$node\\[\"" + ($old_name | @json | .[1:-1]) + "\"\\]") then
                            gsub("\\$node\\[\"" + ($old_name | @json | .[1:-1]) + "\"\\]"; 
                                 "$node[\"" + ($renames[$old_name] | @json | .[1:-1]) + "\"]")
                        else . end
                    )
                else . end
            )
        ) |
        
        # Update connections
        .connections |= with_entries(
            # Update the key (source node name)
            .key = ($renames[.key] // .key) |
            # Update the values (target node references)
            .value |= map_values(
                map(
                    map(
                        if .node and $renames[.node] then
                            .node = $renames[.node]
                        else . end
                    )
                )
            )
        ) |
        
        # Update pinData keys
        if .pinData then
            .pinData |= with_entries(
                .key = ($renames[.key] // .key)
            )
        else . end
    ' > "$output_file"
    
    # Count nodes after
    local nodes_after=$(jq '.nodes | length' "$output_file")
    info "Nodes after: $nodes_after"
    
    # Validate
    if [ "$nodes_before" != "$nodes_after" ]; then
        error "Node count mismatch: before=$nodes_before, after=$nodes_after"
    fi
    
    if ! jq empty "$output_file" 2>/dev/null; then
        error "Output JSON is invalid"
    fi
    
    # Show summary
    local rename_count=$(jq 'keys | length' "$rename_file")
    success "Applied $rename_count renames successfully"
    
    # Show sample renames
    info "Sample transformations:"
    jq -r 'to_entries[:3][] | "  \(.key) → \(.value)"' "$rename_file"
    
    # Generate HTML report if requested
    if [ "$generate_report" = true ]; then
        generate_rename_report "$workflow_file" "$output_file" "$rename_file"
    fi
    
    echo "$output_file"
}

# Generate HTML report for rename operation
generate_rename_report() {
    local input_file="$1"
    local output_file="$2"
    local rename_file="$3"
    
    local workflow_dir=$(dirname "$output_file")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local workflow_id=$(basename "$output_file" | sed 's/.*-\([A-Za-z0-9]\{16\}\)-01-edited\.json$/\1/')
    
    # Generate HTML file
    local html_file="${workflow_dir}/${timestamp}-${workflow_id}-01-edited.html"
    
    info "Generating refactoring report..."
    
    # Extract workflow info
    local workflow_name=$(jq -r '.name' "$output_file")
    local original_nodes=$(jq '.nodes | length' "$input_file")
    local final_nodes=$(jq '.nodes | length' "$output_file")
    local rename_count=$(jq 'keys | length' "$rename_file")
    
    # Create HTML report
    create_n8n_html_report "$html_file" \
        "n8n Workflow Refactoring Report" \
        "✅ Workflow successfully refactored with $rename_count renames" \
        "$workflow_id" \
        "$workflow_name" \
        "$timestamp" \
        "n8n-107-apply-renames"
    
    # Start info table
    start_info_table "$html_file"
    
    # Add summary information
    add_info_row "$html_file" "Workflow Name" "$workflow_name"
    add_info_row "$html_file" "Original Nodes" "$original_nodes"
    add_info_row "$html_file" "Refactored Nodes" "$final_nodes"
    add_info_row "$html_file" "Total Renames" "$rename_count"
    add_info_row "$html_file" "Input File" "$(basename "$input_file")"
    add_info_row "$html_file" "Rename Map" "$(basename "$rename_file")"
    add_info_row "$html_file" "Output File" "$(basename "$output_file")"
    
    # End info table
    end_info_table "$html_file"
    
    # Add rename transformations section
    cat >> "$html_file" << 'EOF'
        <h3 class="section-title">Node Transformations</h3>
        <table class="data-table">
            <thead>
                <tr>
                    <th>Original Name</th>
                    <th>→</th>
                    <th>New Name</th>
                    <th>Pattern</th>
                </tr>
            </thead>
            <tbody>
EOF
    
    # Add each rename transformation
    jq -r 'to_entries[] | @json' "$rename_file" | while read -r rename_entry; do
        local old_name=$(echo "$rename_entry" | jq -r '.key')
        local new_name=$(echo "$rename_entry" | jq -r '.value')
        
        # Determine pattern type
        local pattern=""
        if [[ "$new_name" =~ ^N[0-9]+ ]]; then
            pattern="Primary Flow (N##)"
        elif [[ "$new_name" =~ ^S[0-9]+ ]]; then
            pattern="Secondary Flow (S##)"
        else
            pattern="Custom"
        fi
        
        cat >> "$html_file" << EOF
                <tr>
                    <td class="node-old">$old_name</td>
                    <td>→</td>
                    <td class="node-new">$new_name</td>
                    <td class="pattern">$pattern</td>
                </tr>
EOF
    done
    
    # Close the table and add styling
    cat >> "$html_file" << 'EOF'
            </tbody>
        </table>
        
        <style>
            .node-old { 
                color: #6b7280; 
                font-family: 'Courier New', monospace;
            }
            .node-new { 
                color: #059669; 
                font-weight: 600;
                font-family: 'Courier New', monospace;
            }
            .pattern {
                color: #6366f1;
                font-size: 0.875rem;
            }
        </style>
    </div>
</body>
</html>
EOF
    
    success "Refactoring report generated: $html_file"
    
    # Open in browser using common function
    open_in_browser "$html_file"
}

main "$@"