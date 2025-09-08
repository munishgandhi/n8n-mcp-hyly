#!/bin/bash
# n8n-105-topology-extract.sh - Extract workflow topology and execution order
#
# RULES:
# - Naming: [system]-[3digit]-[object]-[action] (n8n-105-topology-extract)
# - Purpose: Analyze workflow graph and determine true execution order via topological sort
# - Output: {timestamp}-{workflow_id}-04-topology.json with execution order and graph structure
# - Usage: For refactoring and debugging workflow execution flow

set -euo pipefail

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
fi

# Help function
show_help() {
    echo "Usage: $0 <workflow_file>"
    echo
    echo "Extract workflow topology and execution order via topological sort"
    echo
    echo "Parameters:"
    echo "  workflow_file           Path to workflow JSON file"
    echo
    echo "Output:"
    echo "  Creates: {timestamp}-{workflow_id}-04-topology.json"
    echo "  Contains: Execution order, graph structure, proper node numbering"
}

# Parse command line arguments  
parse_args() {
    WORKFLOW_FILE=""
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                WORKFLOW_FILE="$1"
                ;;
        esac
        shift
    done
    
    if [ ! -f "$WORKFLOW_FILE" ]; then
        error "Workflow file not found: $WORKFLOW_FILE"
    fi
}

# Extract all connections from workflow
extract_connections() {
    local workflow_json="$1"
    
    # Extract connections in format: source_node -> target_node
    echo "$workflow_json" | jq -r '
        .connections | 
        to_entries[] | 
        .key as $source | 
        .value.main[][]? | 
        select(.node) | 
        [$source, .node] | 
        @tsv
    ' 2>/dev/null
}

# Find entry points (nodes with no incoming connections)
find_entry_points() {
    local workflow_json="$1"
    local connections="$2"
    
    # Get all node names properly (avoiding space splitting)
    local all_nodes=()
    while IFS= read -r node_name; do
        if [ -n "$node_name" ]; then
            all_nodes+=("$node_name")
        fi
    done < <(echo "$workflow_json" | jq -r '.nodes[].name')
    
    # Get all target nodes (have incoming connections)
    local targets=()
    while IFS=$'\t' read -r source target; do
        if [ -n "$target" ]; then
            targets+=("$target")
        fi
    done <<< "$connections"
    
    # Entry points = all_nodes - targets
    local entries=()
    for node in "${all_nodes[@]}"; do
        local is_target=false
        for target in "${targets[@]}"; do
            if [ "$node" = "$target" ]; then
                is_target=true
                break
            fi
        done
        if [ "$is_target" = false ]; then
            entries+=("$node")
        fi
    done
    
    printf '%s\n' "${entries[@]}"
}

# Classify entry points by flow type
classify_entry_points() {
    local workflow_json="$1"
    local entry_points="$2"
    
    local webhook_entries=()
    local manual_entries=()
    
    while IFS= read -r entry; do
        if [ -n "$entry" ]; then
            # Get node type for this entry point
            local node_type=$(echo "$workflow_json" | jq -r --arg name "$entry" '.nodes[] | select(.name == $name) | .type')
            
            # Primary flow: webhook nodes or nodes starting with N
            if [[ "$node_type" == *"webhook"* ]] || [[ "$entry" == N* ]]; then
                webhook_entries+=("$entry")
            else
                manual_entries+=("$entry")
            fi
        fi
    done <<< "$entry_points"
    
    # Output classification
    echo "webhook_entries:${webhook_entries[*]}"
    echo "manual_entries:${manual_entries[*]}"
}

# BFS traversal from a specific entry point
traverse_from_entry() {
    local workflow_json="$1"
    local connections="$2"
    local entry_point="$3"
    local visited_global="$4"
    
    # Build adjacency list
    declare -A adj_list
    while IFS=$'\t' read -r source target; do
        if [ -n "$source" ] && [ -n "$target" ]; then
            if [ -z "${adj_list[$source]:-}" ]; then
                adj_list["$source"]="$target"
            else
                adj_list["$source"]="${adj_list[$source]}"$'\n'"$target"
            fi
        fi
    done <<< "$connections"
    
    # BFS from single entry point
    local visited=()
    local queue=("$entry_point")
    local flow_order=()
    
    while [ ${#queue[@]} -gt 0 ]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        
        # Skip if already visited in this flow
        local already_visited=false
        for v in "${visited[@]}"; do
            if [ "$v" = "$current" ]; then
                already_visited=true
                break
            fi
        done
        
        # Skip if visited globally
        for v in $visited_global; do
            if [ "$v" = "$current" ]; then
                already_visited=true
                break
            fi
        done
        
        if [ "$already_visited" = false ]; then
            visited+=("$current")
            flow_order+=("$current")
            
            # Add successors to queue
            if [ -n "${adj_list[$current]:-}" ]; then
                while IFS= read -r successor; do
                    if [ -n "$successor" ]; then
                        queue+=("$successor")
                    fi
                done <<< "${adj_list[$current]}"
            fi
        fi
    done
    
    # Output flow using newlines to preserve spaces in node names
    echo "flow_start"
    printf '%s\n' "${flow_order[@]}"
    echo "flow_end"
    echo "visited_start"
    printf '%s\n' "${visited[@]}"
    echo "visited_end"
}

# Topological sort for a specific set of nodes
topological_sort_flow() {
    local workflow_json="$1"
    local connections="$2"
    local flow_nodes="$3"
    
    # Build adjacency list for this flow only
    declare -A adj_list
    declare -A in_degree
    
    # Initialize in-degree for flow nodes
    while IFS= read -r node; do
        if [ -n "$node" ]; then
            in_degree["$node"]=0
        fi
    done <<< "$flow_nodes"
    
    # Count incoming edges within this flow
    while IFS=$'\t' read -r source target; do
        if [ -n "$source" ] && [ -n "$target" ]; then
            # Only consider connections within this flow
            local source_in_flow=false
            local target_in_flow=false
            
            while IFS= read -r node; do
                if [ -n "$node" ]; then
                    if [ "$node" = "$source" ]; then
                        source_in_flow=true
                    fi
                    if [ "$node" = "$target" ]; then
                        target_in_flow=true
                    fi
                fi
            done <<< "$flow_nodes"
            
            if [ "$source_in_flow" = true ] && [ "$target_in_flow" = true ]; then
                if [ -z "${adj_list[$source]:-}" ]; then
                    adj_list["$source"]="$target"
                else
                    adj_list["$source"]="${adj_list[$source]}"$'\n'"$target"
                fi
                ((in_degree["$target"]++))
            fi
        fi
    done <<< "$connections"
    
    # Find nodes with no incoming edges (entry points)
    local queue=()
    for node in "${!in_degree[@]}"; do
        if [ "${in_degree[$node]}" -eq 0 ]; then
            queue+=("$node")
        fi
    done
    
    # Perform topological sort
    local sorted_nodes=()
    while [ ${#queue[@]} -gt 0 ]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        sorted_nodes+=("$current")
        
        # Process successors
        if [ -n "${adj_list[$current]:-}" ]; then
            while IFS= read -r successor; do
                if [ -n "$successor" ]; then
                    ((in_degree["$successor"]--))
                    if [ "${in_degree[$successor]}" -eq 0 ]; then
                        queue+=("$successor")
                    fi
                fi
            done <<< "${adj_list[$current]}"
        fi
    done
    
    printf '%s\n' "${sorted_nodes[@]}"
}

# Classify all nodes and sort each flow topologically
classify_and_sort_flows() {
    local workflow_json="$1"
    local connections="$2"
    
    local primary_nodes=()
    local secondary_nodes=()
    
    # Get all node names and classify by prefix and connection analysis
    while IFS= read -r node_name; do
        if [ -n "$node_name" ]; then
            if [[ "$node_name" == N* ]]; then
                primary_nodes+=("$node_name")
            elif [[ "$node_name" == S* ]] || [[ "$node_name" == "Wait" ]]; then
                secondary_nodes+=("$node_name")
            fi
        fi
    done < <(echo "$workflow_json" | jq -r '.nodes[].name')
    
    # Sort primary flow
    local primary_flow_string=$(printf '%s\n' "${primary_nodes[@]}")
    local sorted_primary=$(topological_sort_flow "$workflow_json" "$connections" "$primary_flow_string")
    
    # Sort secondary flow
    local secondary_flow_string=$(printf '%s\n' "${secondary_nodes[@]}")
    local sorted_secondary=$(topological_sort_flow "$workflow_json" "$connections" "$secondary_flow_string")
    
    # Output flows in structured format
    echo "PRIMARY_FLOWS_START"
    echo "$sorted_primary"
    echo "PRIMARY_FLOWS_END"
    echo "SECONDARY_FLOWS_START"
    echo "$sorted_secondary"
    echo "SECONDARY_FLOWS_END"
}

# Multi-flow topological sort with proper node classification
multi_flow_topological_sort() {
    local workflow_json="$1"
    local connections="$2"
    local entry_points="$3"
    
    # Use proper topological sorting for each flow
    classify_and_sort_flows "$workflow_json" "$connections"
}

# Helper function to get node type by name
get_node_type() {
    local workflow_json="$1"
    local node_name="$2"
    echo "$workflow_json" | jq -r --arg name "$node_name" '.nodes[] | select(.name == $name) | .type // "unknown"'
}

# Generate structured flow data with numbering suggestions
generate_flow_structure() {
    local flows="$1"
    local workflow_json="$2"
    
    local primary_nodes=()
    local secondary_nodes=()
    
    # Parse the structured flow output
    local in_primary=false
    local in_secondary=false
    
    while IFS= read -r line; do
        if [ "$line" = "PRIMARY_FLOWS_START" ]; then
            in_primary=true
            in_secondary=false
        elif [ "$line" = "PRIMARY_FLOWS_END" ]; then
            in_primary=false
        elif [ "$line" = "SECONDARY_FLOWS_START" ]; then
            in_secondary=true
            in_primary=false
        elif [ "$line" = "SECONDARY_FLOWS_END" ]; then
            in_secondary=false
        elif [ "$in_primary" = true ] && [ -n "$line" ]; then
            primary_nodes+=("$line")
        elif [ "$in_secondary" = true ] && [ -n "$line" ]; then
            secondary_nodes+=("$line")
        fi
    done <<< "$flows"
    
    # Generate primary flow JSON with suggested numbering (handle parallel branches)
    local primary_json="[]"
    if [ ${#primary_nodes[@]} -gt 0 ]; then
        local temp_array="["
        local counter=0
        local item_count=0
        local parallel_branches=()
        local in_parallel_group=false
        
        for node in "${primary_nodes[@]}"; do
            # Handle parallel branches N03a/b/c - collect them as a group
            if [[ "$node" == N03* ]]; then
                if [ "$in_parallel_group" = false ]; then
                    in_parallel_group=true
                fi
                
                local branch_letter=""
                if [[ "$node" == *"N03a"* ]]; then
                    branch_letter="a"
                elif [[ "$node" == *"N03b"* ]]; then
                    branch_letter="b"
                elif [[ "$node" == *"N03c"* ]]; then
                    branch_letter="c"
                fi
                
                # Add to parallel branches array
                local node_type=$(get_node_type "$workflow_json" "$node")
                local branch_item=$(jq -n \
                    --arg original "$node" \
                    --arg suggested "N03${branch_letter}" \
                    --arg branch_type "$branch_letter" \
                    --arg type "$node_type" \
                    '{original: $original, suggested: $suggested, branch: $branch_type, type: $type}')
                parallel_branches+=("$branch_item")
            else
                # If we were in parallel group, create the parent node with branches
                if [ "$in_parallel_group" = true ]; then
                    if [ $item_count -gt 0 ]; then
                        temp_array="${temp_array},"
                    fi
                    
                    # Create parent node with embedded branches  
                    local branches_json="["
                    local branch_count=0
                    for branch in "${parallel_branches[@]}"; do
                        if [ $branch_count -gt 0 ]; then
                            branches_json="${branches_json},"
                        fi
                        branches_json="${branches_json}$(echo "$branch" | jq -c .)"
                        ((branch_count++))
                    done
                    branches_json="${branches_json}]"
                    
                    temp_array="${temp_array}$(jq -n \
                        --argjson position "$counter" \
                        --arg suggested "N$(printf "%02d" $counter)" \
                        --argjson branches "$branches_json" \
                        '{position: $position, suggested: $suggested, type: "parallel", branches: $branches}' | jq -c .)"
                    
                    parallel_branches=()
                    in_parallel_group=false
                    ((counter++))
                    ((item_count++))
                fi
                
                if [ $item_count -gt 0 ]; then
                    temp_array="${temp_array},"
                fi
                
                local suggested_num=$(printf "%02d" $counter)
                local node_type=$(get_node_type "$workflow_json" "$node")
                temp_array="${temp_array}$(jq -n \
                    --arg original "$node" \
                    --arg suggested "N$suggested_num" \
                    --argjson position "$counter" \
                    --arg type "$node_type" \
                    '{original: $original, suggested: $suggested, position: $position, type: $type}' | jq -c .)"
                ((counter++))
                ((item_count++))
            fi
        done
        
        # Handle case where parallel group is at the end
        if [ "$in_parallel_group" = true ]; then
            if [ $item_count -gt 0 ]; then
                temp_array="${temp_array},"
            fi
            
            local branches_json="["
            local branch_count=0
            for branch in "${parallel_branches[@]}"; do
                if [ $branch_count -gt 0 ]; then
                    branches_json="${branches_json},"
                fi
                branches_json="${branches_json}$(echo "$branch" | jq -c .)"
                ((branch_count++))
            done
            branches_json="${branches_json}]"
            
            temp_array="${temp_array}$(jq -n \
                --argjson position "$counter" \
                --arg suggested "N$(printf "%02d" $counter)" \
                --argjson branches "$branches_json" \
                '{position: $position, suggested: $suggested, type: "parallel", branches: $branches}' | jq -c .)"
        fi
        
        temp_array="${temp_array}]"
        primary_json="$temp_array"
    fi
    
    # Generate secondary flow JSON with suggested numbering
    local secondary_json="[]"
    if [ ${#secondary_nodes[@]} -gt 0 ]; then
        local temp_array="["
        local counter=0
        for node in "${secondary_nodes[@]}"; do
            local suggested_num=$(printf "%02d" $counter)
            if [ $counter -gt 0 ]; then
                temp_array="${temp_array},"
            fi
            local node_type=$(get_node_type "$workflow_json" "$node")
            temp_array="${temp_array}$(jq -n \
                --arg original "$node" \
                --arg suggested "S$suggested_num" \
                --argjson position "$counter" \
                --arg type "$node_type" \
                '{original: $original, suggested: $suggested, position: $position, type: $type}' | jq -c .)"
            ((counter++))
        done
        temp_array="${temp_array}]"
        secondary_json="$temp_array"
    fi
    
    echo "{\"primary\": $primary_json, \"secondary\": $secondary_json}"
}

# Main function
main() {
    parse_args "$@"
    
    local workflow_json="$(cat "$WORKFLOW_FILE")"
    local workflow_id=$(basename "$WORKFLOW_FILE" | sed 's/.*-\([^-]*\)-04-workflow\.json/\1/')
    local workflow_dir=$(dirname "$WORKFLOW_FILE")
    local timestamp=$(generate_timestamp)
    local topology_file="${workflow_dir}/${timestamp}-${workflow_id}-04-topology.json"
    
    info "Analyzing workflow topology: $workflow_id"
    
    # Extract connections
    info "Extracting connections..."
    local connections=$(extract_connections "$workflow_json")
    local connection_count=$(echo "$connections" | wc -l)
    info "Found $connection_count connections"
    
    # Find entry points
    info "Finding entry points..."
    local entry_points=$(find_entry_points "$workflow_json" "$connections")
    local entry_count=$(echo "$entry_points" | wc -l)
    info "Entry points: $entry_count"
    echo "$entry_points" | sed 's/^/  - /'
    
    # Perform multi-flow topological sort
    info "Computing multi-flow execution order..."
    local flows=$(multi_flow_topological_sort "$workflow_json" "$connections" "$entry_points")
    
    echo "Flow Analysis:"
    local in_primary=false
    local in_secondary=false
    while IFS= read -r line; do
        if [ "$line" = "PRIMARY_FLOWS_START" ]; then
            echo "  Primary flow (webhook-triggered):"
            in_primary=true
            in_secondary=false
        elif [ "$line" = "PRIMARY_FLOWS_END" ]; then
            in_primary=false
        elif [ "$line" = "SECONDARY_FLOWS_START" ]; then
            echo "  Secondary flow (manual-triggered):"
            in_secondary=true
            in_primary=false
        elif [ "$line" = "SECONDARY_FLOWS_END" ]; then
            in_secondary=false
        elif [ "$in_primary" = true ] && [ -n "$line" ]; then
            echo "    - $line"
        elif [ "$in_secondary" = true ] && [ -n "$line" ]; then
            echo "    - $line"
        fi
    done <<< "$flows"
    
    # Generate structured flow data
    info "Generating structured flow data with numbering..."
    local flow_structure=$(generate_flow_structure "$flows" "$workflow_json")
    
    # Validate flow structure JSON
    if ! echo "$flow_structure" | jq empty 2>/dev/null; then
        warning "Invalid flow structure JSON, but continuing: $flow_structure"
    fi
    
    # Build topology data
    local entry_points_json=$(echo "$entry_points" | jq -R -s 'split("\n") | map(select(length > 0))')
    
    local topology_data=$(echo "$flow_structure" | jq \
        --arg workflow_id "$workflow_id" \
        --arg timestamp "$timestamp" \
        --arg source_file "$(basename "$WORKFLOW_FILE")" \
        --argjson entry_points "$entry_points_json" \
        '{
            workflow_id: $workflow_id,
            analysis_timestamp: $timestamp,
            source_file: $source_file,
            entry_points: $entry_points,
            topology: .,
            summary: {
                total_nodes: (
                    (.primary | map(if .type == "parallel" then (.branches | length) else 1 end) | add) + 
                    (.secondary | length)
                ),
                entry_points: ($entry_points | length),
                primary_nodes: (.primary | map(if .type == "parallel" then (.branches | length) else 1 end) | add),
                secondary_nodes: (.secondary | length)
            }
        }')
    
    # Write topology file
    echo "$topology_data" | jq '.' > "$topology_file"
    success "Topology saved: $(basename "$topology_file")"
    
    # Display structured suggestions
    echo
    echo "Topology Structure:"
    echo "$flow_structure" | jq -r '
        "Primary Flow (N##):",
        (.primary[] | if .type == "parallel" then "  \(.suggested) [parallel branches]" else "  \(.original) → \(.suggested)" end),
        "Secondary Flow (S##):",
        (.secondary[] | "  \(.original) → \(.suggested)")
    '
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi