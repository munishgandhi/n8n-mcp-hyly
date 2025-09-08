#!/bin/bash
# n8n-001-semantic-names.sh - Business semantic name generation for n8n nodes
# Extracted from n8n-360-workflow-refactor.sh for shared use

# Map node type to business-relevant verb
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
        "n8n-nodes-base.wait")
            echo "Wait"
            ;;
        *)
            echo "Handle"
            ;;
    esac
}

# Map node type to business entity
map_node_type_to_entity() {
    local node_type="$1"
    local node_name="$2"
    
    case "$node_type" in
        "n8n-nodes-base.webhook")
            # Try to extract entity from webhook path or name
            if [[ "$node_name" == *"Job"* ]] || [[ "$node_name" == *"job"* ]]; then
                echo "JobApplication"
            elif [[ "$node_name" == *"User"* ]] || [[ "$node_name" == *"user"* ]]; then
                echo "User"
            else
                echo "Request"
            fi
            ;;
        "n8n-nodes-base.executeWorkflowTrigger")
            echo "SubWorkflow"
            ;;
        "n8n-nodes-base.wait")
            echo "Timer"
            ;;
        "n8n-nodes-base.notion")
            echo "NotionRecord"
            ;;
        *)
            echo "Data"
            ;;
    esac
}

# Generate semantic node name based on type and context
generate_semantic_name_from_type() {
    local node_name="$1"
    local node_type="$2"
    local prefix="$3"  # N00, S01, etc.
    
    # Get verb and entity
    local verb=$(map_node_type_to_verb "$node_type" "$node_name")
    local entity=$(map_node_type_to_entity "$node_type" "$node_name")
    
    # Special cases based on node name hints
    case "${node_name,,}" in
        *"subflow"*|*"trigger"*)
            if [[ "$prefix" == S* ]]; then
                echo "${verb}-StageData"
            else
                echo "${verb}-${entity}"
            fi
            ;;
        *"router"*|*"flow"*|*"switch"*)
            echo "Route-ByStatus"
            ;;
        *"no"*"op"*|*"completed"*|*"done"*)
            echo "Handle-Completed"
            ;;
        *"running"*|*"progress"*)
            echo "Mark-InProgress"
            ;;
        *"status"*|*"update"*|*"database"*)
            echo "Update-${entity}Status"
            ;;
        *"wait"*)
            echo "Wait-${entity}"
            ;;
        *)
            # Default pattern: Verb-Entity
            echo "${verb}-${entity}"
            ;;
    esac
}

# Check if node already has semantic part
has_semantic_part() {
    local node_name="$1"
    
    # Check if name has space (indicating semantic part exists)
    if [[ "$node_name" == *" "* ]]; then
        return 0  # true - has semantic part
    else
        return 1  # false - no semantic part
    fi
}

# Extract existing semantic part from node name
extract_semantic_part() {
    local node_name="$1"
    
    # Extract everything after the first space
    if [[ "$node_name" =~ ^[NST][0-9a-z]+\ (.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}