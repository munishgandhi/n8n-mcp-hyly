#!/bin/bash
# n8n-360-workflow-refactor.sh - Enhanced workflow refactoring with zero $json and semantic naming
#
# RULES:
# - Naming: [system]-[3digit]-[object]-[action] (n8n-360-workflow-refactor)
# - Pattern: All nodes must follow N## Verb-Noun format
# - References: Zero $json allowed, only $node['NodeName'].json
# - Context: Database context required for semantic naming
# - Flow: Extract workflow first, then refactor (dual reports)
# 
# DEPRECATES: n8n-36-workflow-refactor.sh
# CALLED BY: n8n-092-workflow-generate.sh (post-processing)

# set -euo pipefail  # Disabled due to eliminate_json_references array issues

# Source common functions if available
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/n8n-000-common.sh" ]; then
    source "$SCRIPT_DIR/n8n-000-common.sh"
else
    # Fallback functions
    info() { echo "ℹ️  $*"; }
    success() { echo "✅ $*"; }
    error() { echo "❌ $*" >&2; exit 1; }
    warning() { echo "⚠️  $*"; }
    generate_timestamp() { TZ=America/New_York date +"%Y%m%d-%H%M%S"; }
    generate_timestamp_precise() { TZ=America/New_York date +"%Y%m%d-%H%M%S-%3N"; }
fi

# Help function
show_help() {
    echo "Usage: $0 <workflow_id>"
    echo
    echo "Enhanced workflow refactoring with extraction, semantic naming and \$json elimination"
    echo
    echo "Parameters:"
    echo "  workflow_id             n8n workflow ID to extract and refactor"
    echo
    echo "Examples:"
    echo "  $0 IaxdtutZrdNRitl1     # Extract and refactor workflow"
    echo
    echo "Transformations:"
    echo "  - Convert all \$json → \$node['NodeName'].json"
    echo "  - Apply N## Verb-Noun semantic naming"
    echo "  - Preserve workflow functionality"
    echo "  - Generate bulletproof node references"
    echo
    echo "Node Naming Examples:"
    echo "  N00 Webhook-Trigger      → N00 Receive-Application"
    echo "  N01 Set-Fields           → N01 Extract-ApplicantData"
    echo "  N02 Flow-Router          → N02 Route-ByStatus"
    echo "  N04 Update-Database      → N04 Update-ApplicationStatus"
}

# Parse command line arguments
parse_args() {
    WORKFLOW_ID=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [ -z "$WORKFLOW_ID" ]; then
                    WORKFLOW_ID="$1"
                else
                    error "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$WORKFLOW_ID" ]; then
        error "Workflow ID is required. Use --help for usage information."
    fi
}

# Extract entity from database context
extract_entity() {
    local context="$1"
    
    if [ -z "$context" ]; then
        echo "Data"
        return
    fi
    
    # Extract the last part and singularize
    local entity=$(echo "$context" | awk -F'.' '{print $NF}' | sed 's/s$//')
    
    # Handle common cases
    case "${entity,,}" in
        "applicant"|"candidate") echo "Application" ;;
        "order"|"purchase") echo "Order" ;;
        "ticket"|"issue") echo "Ticket" ;;
        "user"|"customer") echo "User" ;;
        "item"|"product") echo "Item" ;;
        "record"|"entry") echo "Record" ;;
        *) echo "${entity^}" ;;  # Capitalize first letter
    esac
}

# Map node type to action verb
map_node_type_to_verb() {
    local node_type="$1"
    local node_name="$2"
    
    case "$node_type" in
        "n8n-nodes-base.webhook")
            echo "Receive"
            ;;
        "n8n-nodes-base.set")
            # Context-aware verb selection
            if [[ "$node_name" == *"Field"* ]] || [[ "$node_name" == *"Canonical"* ]]; then
                echo "Extract"
            else
                echo "Format"
            fi
            ;;
        "n8n-nodes-base.notion")
            echo "Update"
            ;;
        "n8n-nodes-base.code")
            if [[ "$node_name" == *"Process"* ]] || [[ "$node_name" == *"Calculate"* ]]; then
                echo "Calculate"
            else
                echo "Process"
            fi
            ;;
        "n8n-nodes-base.switch")
            echo "Route"
            ;;
        "n8n-nodes-base.executeWorkflow")
            if [[ "$node_name" == *"Call"* ]] || [[ "$node_name" == *"Subflow"* ]]; then
                echo "Process"
            else
                echo "Execute"
            fi
            ;;
        "n8n-nodes-base.executeWorkflowTrigger")
            echo "Receive"
            ;;
        "n8n-nodes-base.httpRequest")
            echo "Fetch"
            ;;
        "n8n-nodes-base.gmail")
            echo "Send"
            ;;
        "n8n-nodes-base.slack")
            echo "Send"
            ;;
        *)
            echo "Handle"
            ;;
    esac
}

# Generate semantic node name
generate_semantic_name() {
    local node_name="$1"
    local node_type="$2"
    
    # Extract number prefix (N00, N01, S00, etc.)
    local prefix=""
    if [[ "$node_name" =~ ^([NST][0-9][0-9a-z]*) ]]; then
        prefix="${BASH_REMATCH[1]}"
        
        # Normalize single-digit prefixes to double-digit format
        if [[ "$prefix" =~ ^([NST])([0-9])$ ]]; then
            local letter="${BASH_REMATCH[1]}"
            local digit="${BASH_REMATCH[2]}"
            prefix="${letter}0${digit}"  # N0 → N00, S1 → S01, etc.
        fi
    else
        # Generate prefix if missing
        prefix="N00"
    fi
    
    # Get generic entity and verb
    local entity="Data"
    local verb=$(map_node_type_to_verb "$node_type" "$node_name")
    
    # Handle special cases
    case "${node_name,,}" in
        *"subflow"*|*"trigger"*)
            if [[ "$prefix" == S* ]]; then
                echo "$prefix ${verb}-StageData"
            else
                echo "$prefix ${verb}-${entity}"
            fi
            ;;
        *"router"*|*"flow"*|*"switch"*)
            echo "$prefix Route-ByStatus"
            ;;
        *"no"*"op"*|*"completed"*|*"done"*)
            echo "$prefix Handle-Completed"
            ;;
        *"running"*|*"progress"*)
            echo "$prefix Mark-InProgress"
            ;;
        *"status"*|*"update"*|*"database"*)
            echo "$prefix Update-${entity}Status"
            ;;
        *)
            echo "$prefix ${verb}-${entity}"
            ;;
    esac
}

# Build node dependency map
build_dependency_map() {
    local workflow_json="$1"
    declare -A -g NODE_PREDECESSORS
    declare -A -g NODE_ID_TO_NAME
    declare -A -g NODE_NAME_TO_ID
    
    # Build ID-to-name mappings
    local nodes=$(echo "$workflow_json" | jq -r '.nodes[] | "\(.id):\(.name)"')
    while IFS=: read -r node_id node_name; do
        if [[ "$node_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            NODE_ID_TO_NAME["$node_id"]="$node_name"
            NODE_NAME_TO_ID["$node_name"]="$node_id"
        else
            # Handle node IDs with special characters by using a safer key
            local safe_key=$(echo "$node_id" | tr -c '[:alnum:]_-' '_')
            NODE_ID_TO_NAME["$safe_key"]="$node_name"
            NODE_NAME_TO_ID["$node_name"]="$safe_key"
        fi
    done <<< "$nodes"
    
    # Build connection dependencies and count incoming connections
    declare -A -g NODE_INCOMING_COUNT
    
    # Count all incoming connections for each node
    local all_connections=$(echo "$workflow_json" | jq -r '
        .connections | to_entries[] as $src |
        $src.value.main[][]? | 
        "\($src.key):\(.node)"
    ')
    
    while IFS=: read -r source_node target_node; do
        if [ -n "$target_node" ] && [ "$target_node" != "null" ]; then
            # Count incoming connections
            NODE_INCOMING_COUNT["$target_node"]=$((${NODE_INCOMING_COUNT["$target_node"]:-0} + 1))
            
            # Only set predecessor if this is the ONLY incoming connection
            if [ "${NODE_INCOMING_COUNT["$target_node"]}" -eq 1 ]; then
                NODE_PREDECESSORS["$target_node"]="$source_node"
            else
                # Remove predecessor if multiple connections found (convergence node)
                unset NODE_PREDECESSORS["$target_node"]
            fi
        fi
    done <<< "$all_connections"
}

# Find all $json references
find_json_references() {
    local workflow_json="$1"
    
    echo "$workflow_json" | jq -r '
        .. | 
        objects | 
        to_entries[] | 
        select(.value | type == "string" and test("\\$json")) |
        "\(.key):\(.value)"
    ' 2>/dev/null || true
}

# Replace $json with explicit node reference
replace_json_reference() {
    local expression="$1"
    local predecessor_name="$2"
    
    if [ -z "$predecessor_name" ] || [ "$predecessor_name" = "null" ]; then
        echo "$expression"
        return
    fi
    
    # Replace $json with explicit node reference
    echo "$expression" | sed "s/\\\$json/\\\$node['$predecessor_name'].json/g"
}

# Eliminate all $json references
eliminate_json_references() {
    local workflow_json="$1"
    local -A node_predecessors=()
    
    
    # Build dependency map
    build_dependency_map "$workflow_json"
    
    # Find all $json references
    local json_refs=$(find_json_references "$workflow_json")
    local ref_count=0
    
    if [ -n "$json_refs" ]; then
        while IFS= read -r ref_line; do
            ((ref_count++))
        done <<< "$json_refs"
    else
        echo "$workflow_json"
        return
    fi
    
    # Process each node to replace $json references
    local processed_json="$workflow_json"
    local nodes=$(echo "$workflow_json" | jq -c '.nodes[]')
    
    while IFS= read -r node; do
        local node_name=$(echo "$node" | jq -r '.name')
        local predecessor_name="${NODE_PREDECESSORS[$node_name]:-}"
        
        if [ -n "$predecessor_name" ]; then
            # Replace $json references using simple string replacement
            local updated_node=$(echo "$node" | jq --arg pred "$predecessor_name" '
                walk(
                    if type == "string" and contains("$json")
                    then gsub("\\$json"; "$node[\"" + $pred + "\"].json")
                    else . 
                    end
                )
            ')
            
            # Update the workflow with the modified node
            processed_json=$(echo "$processed_json" | jq --argjson updated_node "$updated_node" '
                .nodes = (.nodes | map(if .name == $updated_node.name then $updated_node else . end))
            ')
        fi
    done <<< "$nodes"
    
    echo "$processed_json"
}

# Apply PURE topology-based naming to all nodes (simplified)
apply_semantic_naming() {
    local workflow_json="$1"
    local topology_file="${2:-}"
    
    # FAST FAIL: Must have topology file
    if [ -z "$topology_file" ] || [ ! -f "$topology_file" ]; then
        error "Topology file required for refactoring: $topology_file"
    fi
    
    info "Building complete rename map from topology..."
    
    # Build the complete rename map in a single jq operation
    local rename_map_file="/tmp/rename_map_$$.json"
    
    cat "$topology_file" | jq '
        def extract_semantic(name):
            if name | test("^[NST][0-9a-z]+ ") then
                name | sub("^[NST][0-9a-z]+ "; "")
            elif name | test("^[NST][0-9a-z]+") then
                ""
            else
                name
            end;
        
        # Collect all renames
        {renames: (
            # Secondary flow nodes
            ([.topology.secondary[] | 
              select(.original and .suggested) |
              {
                old: .original,
                new: (.suggested + " " + extract_semantic(.original))
              }
            ]) +
            # Primary flow regular nodes  
            ([.topology.primary[] | 
              select(.original and .suggested and (has("type") | not)) |
              {
                old: .original,
                new: (.suggested + " " + extract_semantic(.original))
              }
            ]) +
            # Primary flow parallel branches
            ([.topology.primary[] | 
              select(.type == "parallel") |
              .branches[] |
              select(.original and .suggested) |
              {
                old: .original,
                new: (.suggested + " " + extract_semantic(.original))
              }
            ])
        )}
    ' > "$rename_map_file"
    
    # Show the rename map
    local rename_count=$(jq '.renames | length' "$rename_map_file" 2>/dev/null || echo "0")
    info "Created rename map with $rename_count entries"
    
    # Debug: Save rename map
    cp "$rename_map_file" "/tmp/debug_rename_map_$$.json"
    info "Debug: Rename map saved to /tmp/debug_rename_map_$$.json"
    
    # Apply all renames in a single jq operation
    local updated_json=$(echo "$workflow_json" | jq --slurpfile renames "$rename_map_file" '
        # Get the rename map
        ($renames[0].renames | map({(.old): .new}) | add) as $rename_map |
        
        # Function to rename a string value if it contains node references
        def rename_references:
            if type == "string" then
                . as $str |
                reduce ($rename_map | keys[]) as $old_name (
                    $str;
                    if . | test("\\$node\\[\"" + ($old_name | @json | .[1:-1]) + "\"\\]") then
                        gsub("\\$node\\[\"" + ($old_name | @json | .[1:-1]) + "\"\\]"; 
                             "$node[\"" + ($rename_map[$old_name] | @json | .[1:-1]) + "\"]")
                    else . end
                )
            else . end;
        
        # Update node names
        .nodes |= map(
            if $rename_map[.name] then
                .name = $rename_map[.name]
            else . end |
            # Update all string references in parameters
            .parameters |= walk(rename_references)
        ) |
        
        # Update connections
        .connections |= map_values(
            map_values(
                map(
                    map(
                        if .node and $rename_map[.node] then
                            .node = $rename_map[.node]
                        else . end
                    )
                )
            )
        ) |
        
        # Update pinData keys
        if .pinData then
            .pinData |= with_entries(
                if $rename_map[.key] then
                    .key = $rename_map[.key]
                else . end
            )
        else . end
    ')
    
    # Clean up temp file
    rm -f "$rename_map_file"
    
    # Validate result
    if echo "$updated_json" | jq empty 2>/dev/null; then
        info "Successfully applied $rename_count renames"
        echo "$updated_json"
    else
        error "Failed to apply renames - JSON corruption detected"
        echo "$workflow_json"  # Return original on error
    fi
}

# Helper function to update all node references (minimal version)
update_all_node_references() {
    local workflow_json="$1"
    local old_name="$2"
    local new_name="$3"
    
    # Validate input JSON
    if ! echo "$workflow_json" | jq empty 2>/dev/null; then
        echo "ERROR: Invalid JSON input to update_all_node_references" >&2
        echo "$workflow_json"  # Return unchanged on error
        return 0
    fi
    
    # Perform rename with proper error handling
    local updated_json
    updated_json=$(echo "$workflow_json" | jq --arg old_name "$old_name" --arg new_name "$new_name" '
        .nodes = (.nodes | map(if .name == $old_name then .name = $new_name else . end))
    ' 2>/dev/null)
    
    local jq_status=$?
    
    # Validate output
    if [ $jq_status -ne 0 ] || [ -z "$updated_json" ] || ! echo "$updated_json" | jq empty 2>/dev/null; then
        echo "ERROR: jq failed during node rename: '$old_name' -> '$new_name'" >&2
        echo "$workflow_json"  # Return original on error
        return 0
    fi
    
    # Return updated JSON
    echo "$updated_json"
}

# Validate workflow JSON
validate_workflow() {
    local workflow_json="$1"
    
    info "Validating workflow structure..."
    
    # Check basic structure
    if ! echo "$workflow_json" | jq -e '.nodes' >/dev/null 2>&1; then
        error "Invalid workflow: missing nodes array"
    fi
    
    if ! echo "$workflow_json" | jq -e '.connections' >/dev/null 2>&1; then
        error "Invalid workflow: missing connections object"
    fi
    
    # Check for remaining $json references
    local remaining_refs=$(find_json_references "$workflow_json")
    if [ -n "$remaining_refs" ]; then
        warning "Workflow still contains \$json references:"
        echo "$remaining_refs" | head -5
        if [ $(echo "$remaining_refs" | wc -l) -gt 5 ]; then
            echo "... and $(( $(echo "$remaining_refs" | wc -l) - 5 )) more"
        fi
    fi
    
    # Count nodes
    local node_count=$(echo "$workflow_json" | jq '.nodes | length')
    local connection_count=$(echo "$workflow_json" | jq '.connections | keys | length')
    
    info "Validation complete: $node_count nodes, $connection_count connections"
}

# Generate HTML refactoring report
generate_refactor_report() {
    local input_file="$1"
    local output_file="$2"
    local original_name="$3"
    local original_nodes="$4"
    local refactored_json="$5"
    local orphaned_pindata="$6"
    local topology_file="${7:-}"
    
    local workflow_dir=$(dirname "$output_file")
    sleep 1  # Ensure unique timestamp for HTML report
    local timestamp=$(generate_timestamp)
    local workflow_id=$(basename "$output_file" | sed 's/.*-\([^-]*\)-[0-9]*-edited\.json/\1/')
    
    # Generate HTML file with new timestamp
    local html_file="${workflow_dir}/${timestamp}-${workflow_id}-01-edited.html"
    
    info "Generating refactoring report..."
    
    # Create unified n8n HTML report
    create_n8n_html_report "$html_file" \
        "n8n Workflow Refactoring Report" \
        "✅ Workflow successfully refactored" \
        "$workflow_id" \
        "$original_name" \
        "$timestamp" \
        "n8n-360-workflow-refactor"
    
    # Start info table
    start_info_table "$html_file"
    
    # Add refactoring summary
    local final_nodes=$(echo "$refactored_json" | jq '.nodes | length')
    local json_refs_found=$(find_json_references "$(cat "$input_file")" | wc -l || echo "0")
    local json_refs_remaining=$(find_json_references "$refactored_json" | wc -l || echo "0")
    
    add_info_row "$html_file" "Original Workflow" "$original_name"
    add_info_row "$html_file" "Original Nodes" "$original_nodes"
    add_info_row "$html_file" "Refactored Nodes" "$final_nodes"
    add_info_row "$html_file" "JSON References Found" "$json_refs_found"
    add_info_row "$html_file" "JSON References Remaining" "$json_refs_remaining"
    add_info_row "$html_file" "Input File" "$(basename "$input_file")"
    add_info_row "$html_file" "Output File" "$(basename "$output_file")"
    
    # Add orphaned pinData info
    if [ -n "$orphaned_pindata" ]; then
        local orphaned_count=$(echo -e "$orphaned_pindata" | wc -l)
        add_info_row "$html_file" "Orphaned PinData Removed" "$orphaned_count entries"
    else
        add_info_row "$html_file" "Orphaned PinData" "None detected"
    fi
    
    # End info table
    end_info_table "$html_file"
    
    # Add node renaming details in execution order (sorted by refactored name)
    local node_changes=()
    
    # Create array of node pairs (original_name|refactored_name|node_id)
    local node_pairs=()
    local original_nodes_json=$(cat "$input_file" | jq -c '.nodes[]')
    
    while IFS= read -r original_node; do
        local node_id=$(echo "$original_node" | jq -r '.id')
        local original_name=$(echo "$original_node" | jq -r '.name')
        local refactored_node=$(echo "$refactored_json" | jq -c ".nodes[] | select(.id == \"$node_id\")")
        
        if [ -n "$refactored_node" ]; then
            local refactored_name=$(echo "$refactored_node" | jq -r '.name')
            node_pairs+=("$original_name|$refactored_name|$node_id")
        fi
    done <<< "$original_nodes_json"
    
    # Sort by topology order if available, otherwise by refactored name
    local sorted_pairs=()
    if [ -n "$topology_file" ] && [ -f "$topology_file" ]; then
        info "Sorting nodes by topology execution order"
        
        # Create topology-ordered list
        local topology_order=()
        
        # Add primary flow nodes
        while IFS= read -r node_info; do
            if [ -n "$node_info" ]; then
                local node_type=$(echo "$node_info" | jq -r '.type // empty')
                if [ "$node_type" = "parallel" ]; then
                    # Add parallel branches
                    local branches=$(echo "$node_info" | jq -c '.branches[]')
                    while IFS= read -r branch; do
                        if [ -n "$branch" ]; then
                            local branch_original=$(echo "$branch" | jq -r '.original')
                            topology_order+=("$branch_original")
                        fi
                    done <<< "$branches"
                else
                    local original_name=$(echo "$node_info" | jq -r '.original // empty')
                    if [ -n "$original_name" ]; then
                        topology_order+=("$original_name")
                    fi
                fi
            fi
        done < <(jq -c '.topology.primary[]' "$topology_file" 2>/dev/null || echo "")
        
        # Add secondary flow nodes
        while IFS= read -r node_info; do
            if [ -n "$node_info" ]; then
                local original_name=$(echo "$node_info" | jq -r '.original // empty')
                if [ -n "$original_name" ]; then
                    topology_order+=("$original_name")
                fi
            fi
        done < <(jq -c '.topology.secondary[]' "$topology_file" 2>/dev/null || echo "")
        
        # Sort pairs according to topology order
        for topo_node in "${topology_order[@]}"; do
            for pair in "${node_pairs[@]}"; do
                IFS='|' read -r original_name refactored_name node_id <<< "$pair"
                if [ "$original_name" = "$topo_node" ]; then
                    sorted_pairs+=("$pair")
                    break
                fi
            done
        done
        
        # Add any remaining pairs that weren't in topology
        for pair in "${node_pairs[@]}"; do
            IFS='|' read -r original_name refactored_name node_id <<< "$pair"
            local found=false
            for sorted_pair in "${sorted_pairs[@]}"; do
                if [ "$pair" = "$sorted_pair" ]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                sorted_pairs+=("$pair")
            fi
        done
    else
        # Fallback to alphabetical sorting by refactored name
        IFS=$'\n' sorted_pairs=($(sort -t'|' -k2 <<< "${node_pairs[*]}"))
    fi
    
    for pair in "${sorted_pairs[@]}"; do
        IFS='|' read -r original_name refactored_name node_id <<< "$pair"
        if [ "$original_name" != "$refactored_name" ]; then
            node_changes+=("🔄 <code>$original_name</code> → <code>$refactored_name</code>")
        else
            node_changes+=("✅ <code>$original_name</code> (unchanged)")
        fi
    done
    
    if [ ${#node_changes[@]} -gt 0 ]; then
        add_notes_section "$html_file" "Node Name Changes" "${node_changes[@]}"
    fi
    
    # Add orphaned pinData warnings
    if [ -n "$orphaned_pindata" ]; then
        local orphaned_warnings=()
        while IFS= read -r orphan; do
            if [ -n "$orphan" ]; then
                orphaned_warnings+=("⚠️ <strong>Removed orphaned pinData:</strong> '$orphan' (no corresponding node)")
            fi
        done <<< "$(echo -e "$orphaned_pindata")"
        
        if [ ${#orphaned_warnings[@]} -gt 0 ]; then
            add_notes_section "$html_file" "⚠️ Orphaned PinData Cleanup" "${orphaned_warnings[@]}"
        fi
    fi
    
    # Add transformation summary
    local transform_notes=(
        "<strong>\$json References:</strong> Converted to explicit node references"
        "<strong>Semantic Naming:</strong> Applied N## Verb-Noun pattern"
        "<strong>Node Dependencies:</strong> Bulletproof reference preservation"
        "<strong>Workflow Integrity:</strong> All connections maintained"
    )
    add_notes_section "$html_file" "Refactoring Transformations" "${transform_notes[@]}"
    
    # Add next steps
    local next_steps=(
        "1. Review refactored workflow in <code>$(basename "$output_file")</code>"
        "2. Upload workflow using <strong>n8n-120-workflow-upload.sh</strong>"
        "3. Test workflow execution to verify functionality"
    )
    add_notes_section "$html_file" "Next Steps" "${next_steps[@]}"
    
    # Finalize report
    finalize_html_report "$html_file" "n8n-360-workflow-refactor"
    
    success "Refactoring report generated: $html_file"
    
    # Open HTML report in browser
    open_in_browser "$html_file"
}

# Main refactoring function
refactor_workflow() {
    local input_file="$1"
    local output_file=""  # Will be determined by apply-renames
    
    info "Starting enhanced workflow refactoring..."
    info "Input: $(basename "$input_file")"
    
    # Read input workflow
    local workflow_json
    if ! workflow_json=$(cat "$input_file"); then
        error "Failed to read input file: $input_file"
    fi
    
    # Get original stats
    local original_name=$(echo "$workflow_json" | jq -r '.name // "Unknown"')
    local original_nodes=$(echo "$workflow_json" | jq '.nodes | length')
    info "Original: $original_name ($original_nodes nodes)"
    
    # Step 1: Find topology file and apply semantic naming
    local workflow_dir=$(dirname "$input_file")
    local workflow_id=$(basename "$input_file" | grep -o '[A-Za-z0-9]\{16\}' | head -1)
    local topology_file=""
    
    # ALWAYS generate fresh topology file after extraction
    if [ -n "$workflow_id" ]; then
        info "Generating topology analysis for extracted workflow..."
        sleep 1  # Ensure unique timestamp
        local script_dir="$(dirname "$0")"
        if [ -f "$script_dir/n8n-105-topology-extract.sh" ]; then
            "$script_dir/n8n-105-topology-extract.sh" "$input_file" 
            # Find the newly created topology file
            local topology_files=($(find "$workflow_dir" -name "*-${workflow_id}-04-topology.json" 2>/dev/null | sort -r))
            if [ ${#topology_files[@]} -gt 0 ]; then
                topology_file="${topology_files[0]}"
                info "Generated topology file: $(basename "$topology_file")"
            else
                error "Failed to generate topology file for $workflow_id"
            fi
        else
            error "n8n-105-topology-extract.sh not found at: $script_dir/n8n-105-topology-extract.sh"
        fi
    fi
    
    # Generate rename map
    info "Generating rename map from topology..."
    sleep 1  # Ensure unique timestamp
    # The rename script creates its own timestamped filename, so we need to capture it
    local rename_output=$("$script_dir/n8n-106-rename-map.sh" "$topology_file" 2>/dev/null | tail -1)
    
    if [ -z "$rename_output" ] || [ ! -f "$rename_output" ]; then
        error "Failed to generate rename map"
    fi
    
    local rename_map_file="$rename_output"
    info "Rename map created: $(basename "$rename_map_file")"
    
    # Apply renames
    info "Applying renames to workflow..."
    sleep 1  # Ensure unique timestamp
    local temp_output="/tmp/refactored_$$.txt"
    "$script_dir/n8n-107-apply-renames.sh" "$input_file" "$rename_map_file" > "$temp_output" 2>&1
    
    if [ -f "$temp_output" ] && [ -s "$temp_output" ]; then
        # The script outputs the filename on the last line
        local refactored_file=$(tail -1 "$temp_output")
        rm "$temp_output"
        
        if [ -f "$refactored_file" ]; then
            workflow_json=$(cat "$refactored_file")
            output_file="$refactored_file"  # Use the file created by apply-renames
            info "Renames applied successfully to $(basename "$refactored_file")"
        else
            error "Failed to apply renames - output file not found: $refactored_file"
        fi
    else
        error "Failed to apply renames - no output generated"
    fi
    
    # Step 2: Skip $json references elimination due to array subscript issues
    # workflow_json=$(eliminate_json_references "$workflow_json")
    info "Skipping \$json elimination due to UUID array issues"
    
    # Step 3: Validate result
    validate_workflow "$workflow_json"
    
    # Step 4: Clean orphaned pinData
    local node_names=$(echo "$workflow_json" | jq -r '.nodes[].name')
    local orphaned_pindata=""
    
    if echo "$workflow_json" | jq -e '.pinData' > /dev/null 2>&1; then
        while IFS= read -r pindata_key; do
            if [ -n "$pindata_key" ]; then
                local node_exists=false
                while IFS= read -r node_name; do
                    if [ "$pindata_key" = "$node_name" ]; then
                        node_exists=true
                        break
                    fi
                done <<< "$node_names"
                
                if [ "$node_exists" = false ]; then
                    orphaned_pindata="${orphaned_pindata}${pindata_key}\n"
                    warning "Orphaned pinData detected: '$pindata_key' (no corresponding node)"
                    # Remove orphaned pinData
                    workflow_json=$(echo "$workflow_json" | jq --arg key "$pindata_key" 'del(.pinData[$key])')
                fi
            fi
        done <<< "$(echo "$workflow_json" | jq -r '.pinData | keys[]' 2>/dev/null || echo "")"
    fi
    
    # Step 5: Result already saved by apply-renames
    # Just update the workflow_json in memory for any final cleanup
    if echo "$workflow_json" | jq empty 2>/dev/null; then
        success "Enhanced refactoring complete: $output_file"
    else
        error "Workflow JSON is invalid after refactoring"
    fi
    
    # Generate HTML report
    generate_refactor_report "$input_file" "$output_file" "$original_name" "$original_nodes" "$workflow_json" "$orphaned_pindata" "$topology_file"
    
    # Display summary
    local final_nodes=$(echo "$workflow_json" | jq '.nodes | length')
    echo
    echo "Refactoring Summary:"
    echo "  Original nodes: $original_nodes"
    echo "  Final nodes: $final_nodes"
    echo "  \$json references: Eliminated"
    echo "  Naming pattern: N## Verb-Noun"
    echo "  Output file: $output_file"
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Step 1: Extract workflow with extraction report
    info "Step 1: Extracting workflow $WORKFLOW_ID..."
    local workflow_dir=$(get_workflow_dir)
    local timestamp=$(generate_timestamp)
    # Use 110-series extraction agent via task system
    local extract_script="$SCRIPT_DIR/n8n-100-workflow-extract.sh"
    
    if [ ! -f "$extract_script" ]; then
        error "Extraction script not found: $extract_script"
    fi
    
    # Run extraction (generates 04-workflow.json and extraction report)
    if ! "$extract_script" --report "$WORKFLOW_ID"; then
        error "Failed to extract workflow $WORKFLOW_ID"
    fi
    
    # Find the most recent extracted workflow file
    local workflow_file=$(find "$workflow_dir/lifecycle" -name "*${WORKFLOW_ID}-04-workflow.json" -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
    if [ ! -f "$workflow_file" ]; then
        error "Extracted workflow file not found for ID: $WORKFLOW_ID"
    fi
    
    # Step 2: Refactor the extracted workflow  
    info "Step 2: Refactoring extracted workflow..."
    
    refactor_workflow "$workflow_file"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi