#!/bin/bash
# n8n-092-workflow-generate.sh - Generate complete multi-stage workflows following IaxdtutZrdNRitl1 pattern
#
# RULES:
# - Naming: [system]-[3digit]-[object]-[action] (n8n-092-workflow-generate)
# - Pattern: Generate IaxdtutZrdNRitl1-compliant workflows with dynamic node count
# - Integration: Pre: notion-01-context-save, n8n-010-status-setup (if needed)
#               Post: n8n-105 → n8n-106 → n8n-107 (modular pipeline)
# - Output: Zero $json, semantic N## Verb-Noun names, functional S## subflow
# - Schema: Dynamic discovery, no hardcoded assumptions about table structure
#
# REPLACES: Simple 3-node workflow generation
# DEPRECATES: n8n-360-workflow-refactor.sh (replaced by modular pipeline)
# CALLS: notion-01-context-save, n8n-010-status-setup, n8n-105, n8n-106, n8n-107

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

# Tool locations
TOOLBOX_NOTION="$SCRIPT_DIR/../toolbox-notion"
TOOLBOX_N8N="$SCRIPT_DIR"

# Help function
show_help() {
    echo "Usage: $0 --database \"Database.Name\" --stages \"Stage1,Stage2,Stage3\" [options]"
    echo
    echo "Generate complete multi-stage n8n workflow with IaxdtutZrdNRitl1 pattern"
    echo
    echo "Required Parameters:"
    echo "  --database NAME         Exact name of Notion database (case-sensitive)"
    echo "  --stages \"S1,S2,S3\"     Comma-separated list of business stage names"
    echo "                          or 'auto' to detect from existing n8n Status field"
    echo
    echo "Optional Parameters:"
    echo "  --webhook-path PATH     Custom webhook path (default: auto-generated)"
    echo "  --no-refactor          Skip post-processing refactor step"
    echo "  --no-status-setup      Skip pre-processing status field setup"
    echo
    echo "Examples:"
    echo "  $0 --database \"Jobs.QA.Applicants\" --stages \"auto\""
    echo "  $0 --database \"Jobs.QA.Applicants\" --stages \"Screening,Review,Interview\""
    echo "  $0 --database \"Orders.Processing\" --stages \"Validate,Process,Ship\" --webhook-path \"orders\""
    echo
    echo "Generated Workflow Pattern (IaxdtutZrdNRitl1):"
    echo "  Main Flow:"
    echo "    - N00 Receive-Request (webhook trigger)"
    echo "    - N01 Extract-Data (flatten all database fields)"
    echo "    - N02 Route-ByStatus (router with stage-specific outputs)"
    echo "    - N03a-N03x Process-Data (one per START state)"
    echo "    - N03z Handle-Completed (no-op for finished items)"
    echo "    - N04 Update-DataStatus (write status back to database)"
    echo "  Subflow Section:"
    echo "    - S00 Receive-StageData (subflow trigger)"
    echo "    - S01 Mark-InProgress (set running status)"
    echo "    - S02 Wait-Timer (5 second wait)"
    echo "    - S03 Calculate-Data (status progression logic)"
    echo "    - S04 Extract-Data (prepare response data)"
    echo
    echo "Dependencies:"
    echo "  - notion-01-context-save.sh (schema discovery)"
    echo "  - n8n-010-status-setup.sh (status field creation)"
    echo "  - n8n-105/106/107 modular refactor pipeline (semantic naming + no \$json)"
}

# Parse command line arguments
parse_args() {
    DATABASE_NAME=""
    STAGES=""
    WEBHOOK_PATH=""
    SKIP_REFACTOR="false"
    SKIP_STATUS_SETUP="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --database)
                DATABASE_NAME="$2"
                shift 2
                ;;
            --stages)
                STAGES="$2"
                shift 2
                ;;
            --webhook-path)
                WEBHOOK_PATH="$2"
                shift 2
                ;;
            --no-refactor)
                SKIP_REFACTOR="true"
                shift
                ;;
            --no-status-setup)
                SKIP_STATUS_SETUP="true"
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                error "Unexpected argument: $1"
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$DATABASE_NAME" ]; then
        error "Database name is required. Use --help for usage information."
    fi
    
    if [ -z "$STAGES" ]; then
        error "Stages are required. Use --help for usage information."
    fi
}

# Get workflow directory
get_workflow_dir() {
    local repo_root=$(git rev-parse --show-toplevel)
    
    # Special handling for claude-agents branch
    local current_branch=$(git branch --show-current)
    if [ "$current_branch" = "claude-agents" ]; then
        echo "$repo_root/.claude"
        return 0
    fi
    
    local workflow_dir=$("$repo_root/.claude/agents/n8n-900-workflow-dir-find.sh" 2>/dev/null || echo ".")
    
    if [ "$workflow_dir" = "." ]; then
        error "Not on a workflow branch or workflow directory not found"
    fi
    
    echo "$workflow_dir"
}

# Ensure schema exists
ensure_schema() {
    local database_name="$1"
    local workflow_dir="$2"
    
    # Create sanitized filename from database name
    local filename=$(echo "$database_name" | sed 's/[^a-zA-Z0-9._-]/-/g' | tr '[:upper:]' '[:lower:]')
    local schema_file="$workflow_dir/context/notion-${filename}-schema.json"
    
    info "Checking for schema: $schema_file" >&2
    
    if [ ! -f "$schema_file" ]; then
        info "Schema not found, fetching from Notion..." >&2
        if [ ! -f "$TOOLBOX_NOTION/notion-01-context-save.sh" ]; then
            error "Required tool not found: $TOOLBOX_NOTION/notion-01-context-save.sh"
        fi
        
        if ! "$TOOLBOX_NOTION/notion-01-context-save.sh" "$database_name"; then
            error "Failed to fetch schema for database: $database_name"
        fi
        
        if [ ! -f "$schema_file" ]; then
            error "Schema file still not found after fetch: $schema_file"
        fi
    fi
    
    success "Schema available: $schema_file" >&2
    echo "$schema_file"
}

# Extract START states from schema
extract_start_states() {
    local schema_file="$1"
    
    # Try both possible structures (select.options and options)
    local start_states=$(jq -r '.properties["n8n Status"].select.options[] | select(.name | contains("Start")) | .name' "$schema_file" 2>/dev/null | sort)
    
    # If first structure didn't work, try second structure
    if [ -z "$start_states" ]; then
        start_states=$(jq -r '.properties["n8n Status"].options[] | select(.name | contains("Start")) | .name' "$schema_file" 2>/dev/null | sort)
    fi
    
    if [ -z "$start_states" ]; then
        warning "No n8n Status field found or no START states defined"
        echo ""
    else
        echo "$start_states"
    fi
}

# Setup status field
setup_status_field() {
    local database_name="$1"
    local stages="$2"
    
    if [ "$SKIP_STATUS_SETUP" = "true" ]; then
        info "Skipping status field setup (--no-status-setup)"
        return 0
    fi
    
    info "Setting up n8n Status field..."
    
    if [ ! -f "$TOOLBOX_N8N/n8n-010-status-setup.sh" ]; then
        error "Required tool not found: $TOOLBOX_N8N/n8n-010-status-setup.sh"
    fi
    
    if ! "$TOOLBOX_N8N/n8n-010-status-setup.sh" "$database_name" --stages "$stages" --automated; then
        error "Failed to setup status field"
    fi
    
    success "Status field setup complete"
}

# Parse stages into array
parse_stages() {
    local stages_input="$1"
    local schema_file="$2"
    
    # Handle auto detection
    if [ "$stages_input" = "auto" ]; then
        info "Auto-detecting stages from n8n Status field..."
        local start_states=$(extract_start_states "$schema_file")
        
        if [ -z "$start_states" ]; then
            error "Cannot auto-detect stages - no n8n Status field with START states found"
        fi
        
        # Convert start states to stages (n8n 00 Start -> Stage 00, etc)
        local -a stages=()
        while IFS= read -r state; do
            if [[ "$state" =~ n8n[[:space:]]([0-9]+)[[:space:]]Start ]]; then
                local num="${BASH_REMATCH[1]}"
                stages+=("Stage $num")
            fi
        done <<< "$start_states"
        
        printf '%s\n' "${stages[@]}"
    else
        # Handle comma format: "Stage1,Stage2,Stage3"
        IFS=',' read -ra stage_array <<< "$stages_input"
        
        # Clean each stage
        local -a cleaned_stages=()
        for stage in "${stage_array[@]}"; do
            stage=$(echo "$stage" | xargs)  # Trim whitespace
            if [ -n "$stage" ]; then
                cleaned_stages+=("$stage")
            fi
        done
        
        if [ ${#cleaned_stages[@]} -eq 0 ]; then
            error "No valid stages found in input: $stages_input"
        fi
        
        printf '%s\n' "${cleaned_stages[@]}"
    fi
}

# Generate field assignments from schema
generate_field_assignments() {
    local schema_file="$1"
    local assignments=""
    
    # Add standard page and database ID fields
    assignments+="            {
              \"id\": \"notion-page-id\",
              \"name\": \"notion_page_id\",
              \"value\": \"={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.id }}\",
              \"type\": \"string\"
            },
            {
              \"id\": \"notion-database-id\",
              \"name\": \"notion_database_id\",
              \"value\": \"={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.parent.database_id }}\",
              \"type\": \"string\"
            }"
    
    # Process each property from schema
    local properties=$(jq -r '.properties | to_entries[] | @base64' "$schema_file")
    
    while IFS= read -r encoded_property; do
        local property=$(echo "$encoded_property" | base64 --decode)
        local prop_name=$(echo "$property" | jq -r '.key')
        local prop_type=$(echo "$property" | jq -r '.value.type')
        
        # Skip if property name is empty
        if [ -z "$prop_name" ] || [ "$prop_name" = "null" ]; then
            continue
        fi
        
        # Create canonical variable name
        local canonical_name=$(echo "$prop_name" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
        canonical_name="notion_${canonical_name}"
        
        # Generate value expression based on property type
        local value_expr=""
        case "$prop_type" in
            "title")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].title[0].plain_text }}"
                ;;
            "rich_text")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].rich_text?.[0]?.plain_text || '' }}"
                ;;
            "number")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].number || '' }}"
                ;;
            "select")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].select?.name || '' }}"
                ;;
            "multi_select")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].multi_select?.map(item => item.name).join(', ') || '' }}"
                ;;
            "date")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].date?.start }}"
                ;;
            "email")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].email || '' }}"
                ;;
            "url")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].url }}"
                ;;
            "checkbox")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].checkbox }}"
                ;;
            "people")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].people?.[0]?.name || '' }}"
                ;;
            "files")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].files?.map(item => item.name).join(', ') || '' }}"
                ;;
            "relation")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].relation?.map(item => item.id).join(', ') || '' }}"
                ;;
            "formula")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].formula?.number || '' }}"
                ;;
            "created_time"|"last_edited_time")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].$prop_type }}"
                ;;
            "created_by"|"last_edited_by")
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"].$prop_type?.name || '' }}"
                ;;
            *)
                # Generic fallback
                value_expr="={{ \$node[\\\"N00 Receive-Request\\\"].json.body.data.properties[\\\"$prop_name\\\"] }}"
                ;;
        esac
        
        # Add assignment
        assignments+=",
            {
              \"id\": \"$(uuidgen)\",
              \"name\": \"$canonical_name\",
              \"value\": \"$value_expr\",
              \"type\": \"string\"
            }"
        
    done <<< "$properties"
    
    echo "$assignments"
}

# Generate router conditions based on actual START states in schema
generate_router_conditions() {
    local schema_file="$1"
    local conditions=""
    
    # Extract actual START states from schema
    local start_states=$(extract_start_states "$schema_file")
    
    if [ -z "$start_states" ]; then
        error "No START states found in n8n Status field"
    fi
    
    local index=0
    while IFS= read -r state; do
        # Extract the number part (e.g., "00" from "n8n 00 Start")
        if [[ "$state" =~ n8n[[:space:]]([0-9]+)[[:space:]]Start ]]; then
            local stage_num="${BASH_REMATCH[1]}"
            
            if [ $index -gt 0 ]; then
                conditions+=","
            fi
            
            conditions+="            {
              \"conditions\": {
                \"options\": {
                  \"caseSensitive\": true,
                  \"leftValue\": \"\",
                  \"typeValidation\": \"strict\",
                  \"version\": 2
                },
                \"conditions\": [
                  {
                    \"leftValue\": \"={{ \$node[\\\"N01 Extract-Data\\\"].json.notion_n8n_status }}\",
                    \"rightValue\": \"$state\",
                    \"operator\": {
                      \"type\": \"string\",
                      \"operation\": \"equals\"
                    },
                    \"id\": \"$(uuidgen)\"
                  }
                ],
                \"combinator\": \"and\"
              },
              \"renameOutput\": true,
              \"outputKey\": \"$stage_num Start\"
            }"
            
            ((index++))
        fi
    done <<< "$start_states"
    
    # Add catch-all for completed/other items
    conditions+=",
            {
              \"conditions\": {
                \"options\": {
                  \"caseSensitive\": true,
                  \"leftValue\": \"\",
                  \"typeValidation\": \"strict\",
                  \"version\": 2
                },
                \"conditions\": [
                  {
                    \"id\": \"completed-condition\",
                    \"leftValue\": \"={{ \$node[\\\"N01 Extract-Data\\\"].json.notion_n8n_status }}\",
                    \"rightValue\": \"\",
                    \"operator\": {
                      \"type\": \"string\",
                      \"operation\": \"notEmpty\"
                    }
                  }
                ],
                \"combinator\": \"and\"
              },
              \"renameOutput\": true,
              \"outputKey\": \"Done\"
            }"
    
    echo "$conditions"
}

# Generate Process-Data nodes based on actual START states
generate_process_nodes() {
    local schema_file="$1"
    local nodes=""
    
    # Extract actual START states from schema
    local start_states=$(extract_start_states "$schema_file")
    
    if [ -z "$start_states" ]; then
        error "No START states found in n8n Status field"
    fi
    
    local index=0
    while IFS= read -r state; do
        # Extract the number part (e.g., "00" from "n8n 00 Start")
        if [[ "$state" =~ n8n[[:space:]]([0-9]+)[[:space:]]Start ]]; then
            local stage_num="${BASH_REMATCH[1]}"
            local stage_letter=$(printf "\\$(printf '%03o' $((97 + $index)))")  # a, b, c, ...
            
            if [ $index -gt 0 ]; then
                nodes+=","
            fi
            
            nodes+="    {
      \"parameters\": {
        \"workflowId\": {
          \"__rl\": true,
          \"value\": \"SELF_REFERENCE\",
          \"mode\": \"id\"
        },
        \"workflowInputs\": {
          \"mappingMode\": \"defineBelow\",
          \"value\": {
            \"subflow_type\": \"$stage_num\",
            \"notion_n8n_status\": \"={{ \$node[\\\"N02 Route-ByStatus\\\"].json.notion_n8n_status }}\",
            \"notion_page_id\": \"={{ \$node[\\\"N02 Route-ByStatus\\\"].json.notion_page_id }}\",
            \"all_data\": \"={{ \$node[\\\"N02 Route-ByStatus\\\"].json }}\"
          },
          \"matchingColumns\": [],
          \"schema\": [],
          \"attemptToConvertTypes\": false,
          \"convertFieldsToString\": true
        },
        \"mode\": \"each\",
        \"options\": {
          \"waitForSubWorkflow\": true
        }
      },
      \"type\": \"n8n-nodes-base.executeWorkflow\",
      \"typeVersion\": 1.2,
      \"position\": [
        1072,
        $(( -16 + $index * 192 ))
      ],
      \"name\": \"N03$stage_letter Process-Data\",
      \"id\": \"$(uuidgen)\"
    }"
            
            ((index++))
        fi
    done <<< "$start_states"
    
    # Add N03z Handle-Completed node
    nodes+=",
    {
      \"parameters\": {
        \"assignments\": {
          \"assignments\": [
            {
              \"id\": \"completed-status\",
              \"name\": \"completion_status\",
              \"value\": \"={{ \$node[\\\"N02 Route-ByStatus\\\"].json.notion_n8n_status }}\",
              \"type\": \"string\"
            },
            {
              \"id\": \"completed-message\",
              \"name\": \"completion_message\",
              \"value\": \"Item already processed - no action needed\",
              \"type\": \"string\"
            },
            {
              \"id\": \"notion-page-id\",
              \"name\": \"notion_page_id\",
              \"value\": \"={{ \$('N01 Extract-Data').item.json.notion_page_id }}\",
              \"type\": \"string\"
            },
            {
              \"id\": \"notion-n8n-status-new\",
              \"name\": \"notion_n8n_status_new\",
              \"value\": \"={{ \$node[\\\"N02 Route-ByStatus\\\"].json.notion_n8n_status }}\",
              \"type\": \"string\"
            }
          ]
        },
        \"options\": {}
      },
      \"type\": \"n8n-nodes-base.set\",
      \"typeVersion\": 3.4,
      \"position\": [
        1072,
        368
      ],
      \"id\": \"$(uuidgen)\",
      \"name\": \"N03z Handle-Completed\"
    }"
    
    echo "$nodes"
}

# Generate router connections based on actual START states
generate_router_connections() {
    local schema_file="$1"
    local connections=""
    
    # Extract actual START states from schema
    local start_states=$(extract_start_states "$schema_file")
    
    if [ -z "$start_states" ]; then
        error "No START states found in n8n Status field"
    fi
    
    local index=0
    while IFS= read -r state; do
        if [[ "$state" =~ n8n[[:space:]]([0-9]+)[[:space:]]Start ]]; then
            local stage_letter=$(printf "\\$(printf '%03o' $((97 + $index)))")  # a, b, c, ...
            
            if [ $index -gt 0 ]; then
                connections+=","
            fi
            
            connections+="        [
          {
            \"node\": \"N03$stage_letter Process-Data\",
            \"type\": \"main\",
            \"index\": 0
          }
        ]"
            
            ((index++))
        fi
    done <<< "$start_states"
    
    # Add connection to N03z Handle-Completed
    connections+=",
        [
          {
            \"node\": \"N03z Handle-Completed\",
            \"type\": \"main\",
            \"index\": 0
          }
        ]"
    
    echo "$connections"
}

# Generate Process node connections
generate_process_connections() {
    local schema_file="$1"
    local connections=""
    
    # Extract actual START states from schema
    local start_states=$(extract_start_states "$schema_file")
    
    local index=0
    while IFS= read -r state; do
        if [[ "$state" =~ n8n[[:space:]]([0-9]+)[[:space:]]Start ]]; then
            local stage_letter=$(printf "\\$(printf '%03o' $((97 + $index)))")  # a, b, c, ...
            
            connections+="    \"N03$stage_letter Process-Data\": {
      \"main\": [
        [
          {
            \"node\": \"N04 Update-DataStatus\",
            \"type\": \"main\",
            \"index\": 0
          }
        ]
      ]
    },"
            
            ((index++))
        fi
    done <<< "$start_states"
    
    echo "$connections"
}

# Generate complete workflow following IaxdtutZrdNRitl1 pattern
generate_workflow() {
    local database_name="$1"
    local schema_file="$2"
    local webhook_path="$3"
    
    # Generate components
    local field_assignments=$(generate_field_assignments "$schema_file")
    local router_conditions=$(generate_router_conditions "$schema_file")
    local process_nodes=$(generate_process_nodes "$schema_file")
    local router_connections=$(generate_router_connections "$schema_file")
    local process_connections=$(generate_process_connections "$schema_file")
    
    # Get database info from schema
    local database_id=$(jq -r '.database.id' "$schema_file")
    local database_title=$(jq -r '.database.title' "$schema_file")
    
    # Generate workflow JSON following IaxdtutZrdNRitl1 pattern exactly
    cat << EOF
{
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
  "id": "PLACEHOLDER_WORKFLOW_ID",
  "name": "IaxdtutZrdNRitl1-Pattern Workflow $(generate_timestamp)",
  "active": false,
  "isArchived": false,
  "nodes": [
    {
      "parameters": {
        "assignments": {
          "assignments": [
$field_assignments
          ]
        },
        "options": {}
      },
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [
        624,
        176
      ],
      "id": "$(uuidgen)",
      "name": "N01 Extract-Data"
    },
    {
      "parameters": {
        "multipleMethods": true,
        "httpMethod": [
          "POST"
        ],
        "path": "$webhook_path",
        "options": {
          "noResponseBody": false,
          "responseData": "firstEntryJson"
        }
      },
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2.1,
      "position": [
        400,
        176
      ],
      "id": "$(uuidgen)",
      "name": "N00 Receive-Request",
      "webhookId": "$(uuidgen)"
    },
    {
      "parameters": {
        "resource": "databasePage",
        "operation": "update",
        "pageId": {
          "__rl": true,
          "value": "={{ \$('N01 Extract-Data').item.json.notion_page_id }}",
          "mode": "id"
        },
        "simple": false,
        "propertiesUi": {
          "propertyValues": [
            {
              "key": "n8n Status|select",
              "selectValue": "={{ \$json.notion_n8n_status_new }}"
            }
          ]
        },
        "options": {}
      },
      "type": "n8n-nodes-base.notion",
      "typeVersion": 2.2,
      "position": [
        1296,
        176
      ],
      "id": "$(uuidgen)",
      "name": "N04 Update-DataStatus",
      "credentials": {
        "notionApi": {
          "id": "PLACEHOLDER_NOTION_CREDENTIALS",
          "name": "Notion account"
        }
      }
    },
$process_nodes,
    {
      "parameters": {
        "rules": {
          "values": [
$router_conditions
          ]
        },
        "options": {}
      },
      "type": "n8n-nodes-base.switch",
      "typeVersion": 3.2,
      "position": [
        848,
        160
      ],
      "id": "$(uuidgen)",
      "name": "N02 Route-ByStatus"
    },
    {
      "parameters": {
        "jsCode": "// Status transition logic based on current status\\nconst currentStatus = \$('S00 Receive-StageData').first().json.all_data.notion_n8n_status\\n\\nlet newStatus;\\nif (currentStatus && currentStatus.startsWith('n8n 00')) {\\n  newStatus = 'n8n 01 Start';\\n} else if (currentStatus && currentStatus.startsWith('n8n 01')) {\\n  newStatus = 'n8n 02 Start';\\n} else if (currentStatus && currentStatus.startsWith('n8n 02')) {\\n  newStatus = 'n8n 99 Done';\\n} else {\\n  newStatus = 'n8n 66 Error';\\n}\\n\\n// Return updated data with new status\\nreturn [{\\n  json: {\\n    notion_page_id: \$('S00 Receive-StageData').first().json.notion_page_id,\\n    notion_n8n_status_new: newStatus,\\n    subflow_processed: true\\n  }\\n}];"
      },
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [
        1072,
        592
      ],
      "id": "$(uuidgen)",
      "name": "S03 Calculate-Data"
    },
    {
      "parameters": {
        "assignments": {
          "assignments": [
            {
              "id": "$(uuidgen)",
              "name": "notion_page_id",
              "value": "={{ \$('S00 Receive-StageData').item.json.notion_page_id }}",
              "type": "string"
            },
            {
              "id": "$(uuidgen)",
              "name": "notion_n8n_status_new",
              "value": "={{ \$node[\"S03 Calculate-Data\"].json.notion_n8n_status_new }}",
              "type": "string"
            },
            {
              "id": "processing-complete",
              "name": "subflow_result",
              "value": "processing complete",
              "type": "string"
            }
          ]
        },
        "options": {}
      },
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [
        1296,
        592
      ],
      "id": "$(uuidgen)",
      "name": "S04 Extract-Data"
    },
    {
      "parameters": {
        "inputSource": "passthrough"
      },
      "id": "$(uuidgen)",
      "typeVersion": 1.1,
      "name": "S00 Receive-StageData",
      "type": "n8n-nodes-base.executeWorkflowTrigger",
      "position": [
        400,
        592
      ]
    },
    {
      "parameters": {
        "resource": "databasePage",
        "operation": "update",
        "pageId": {
          "__rl": true,
          "value": "={{ \$json.notion_page_id }}",
          "mode": "id"
        },
        "simple": false,
        "propertiesUi": {
          "propertyValues": [
            {
              "key": "n8n Status|select",
              "selectValue": "={{ \$json.notion_n8n_status.replace('Start', 'Running') }}"
            }
          ]
        },
        "options": {}
      },
      "type": "n8n-nodes-base.notion",
      "typeVersion": 2.2,
      "position": [
        624,
        592
      ],
      "id": "$(uuidgen)",
      "name": "S01 Mark-InProgress",
      "credentials": {
        "notionApi": {
          "id": "PLACEHOLDER_NOTION_CREDENTIALS",
          "name": "Notion account"
        }
      }
    },
    {
      "parameters": {
        "amount": 5,
        "unit": "seconds"
      },
      "type": "n8n-nodes-base.wait",
      "typeVersion": 1.1,
      "position": [
        848,
        592
      ],
      "id": "$(uuidgen)",
      "name": "S02 Wait-Timer"
    }
  ],
  "connections": {
    "N01 Extract-Data": {
      "main": [
        [
          {
            "node": "N02 Route-ByStatus",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "N00 Receive-Request": {
      "main": [
        [
          {
            "node": "N01 Extract-Data",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
$process_connections
    "N03z Handle-Completed": {
      "main": [
        [
          {
            "node": "N04 Update-DataStatus",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "N02 Route-ByStatus": {
      "main": [
$router_connections
      ]
    },
    "S03 Calculate-Data": {
      "main": [
        [
          {
            "node": "S04 Extract-Data",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "S00 Receive-StageData": {
      "main": [
        [
          {
            "node": "S01 Mark-InProgress",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "S01 Mark-InProgress": {
      "main": [
        [
          {
            "node": "S02 Wait-Timer",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "S02 Wait-Timer": {
      "main": [
        [
          {
            "node": "S03 Calculate-Data",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "settings": {
    "executionOrder": "v1"
  },
  "staticData": null,
  "meta": null,
  "tags": []
}
EOF
}

# Apply post-processing refactor using modular pipeline
apply_refactor() {
    local workflow_file="$1"
    local database_name="$2"
    local workflow_dir="$3"
    
    if [ "$SKIP_REFACTOR" = "true" ]; then
        info "Skipping post-processing refactor (--no-refactor)"
        return 0
    fi
    
    info "Applying modular semantic refactoring pipeline..."
    
    # Check for required scripts
    local topology_script="$TOOLBOX_N8N/n8n-105-topology-extract.sh"
    local rename_script="$TOOLBOX_N8N/n8n-106-rename-map.sh"
    local apply_script="$TOOLBOX_N8N/n8n-107-apply-renames.sh"
    
    if [ ! -f "$topology_script" ] || [ ! -f "$rename_script" ] || [ ! -f "$apply_script" ]; then
        warning "Refactor scripts not found - creating them now..."
        
        # Create the modular pipeline scripts if they don't exist
        # For now, we'll use the monolithic n8n-360 if available
        if [ -f "$TOOLBOX_N8N/n8n-360-workflow-refactor.sh" ]; then
            info "Using monolithic n8n-360 as fallback..."
            if "$TOOLBOX_N8N/n8n-360-workflow-refactor.sh" "$workflow_file" --context "$database_name" --generate-report; then
                success "Workflow refactored using n8n-360"
            else
                warning "Refactor failed - workflow may contain $json references"
            fi
            return 0
        else
            warning "No refactor scripts available - workflow will retain $json references"
            return 1
        fi
    fi
    
    # Step 1: Extract topology
    info "Analyzing workflow topology..."
    local topology_file="$workflow_dir/topology.json"
    if ! "$topology_script" "$workflow_file" > "$topology_file" 2>&1; then
        warning "Failed to extract topology - skipping refactor"
        return 1
    fi
    
    # Step 2: Generate rename map
    info "Generating semantic rename mappings..."
    local rename_file="$workflow_dir/rename-map.json"
    if ! "$rename_script" "$workflow_file" --context "$database_name" --topology "$topology_file" > "$rename_file" 2>&1; then
        warning "Failed to generate rename map - skipping refactor"
        return 1
    fi
    
    # Step 3: Apply renames and generate report
    info "Applying node renames and generating HTML report..."
    if ! "$apply_script" "$workflow_file" --rename-map "$rename_file" --output "$workflow_file" --generate-report 2>&1; then
        warning "Post-processing refactor failed - workflow may have $json references"
        return 1
    fi
    
    success "Generated workflow with zero $json references: $workflow_file"
    info "HTML report available in lifecycle directory"
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    info "Starting IaxdtutZrdNRitl1-pattern workflow generation..."
    info "Database: $DATABASE_NAME"
    info "Stages: $STAGES"
    
    # Get workflow directory
    WORKFLOW_DIR=$(get_workflow_dir)
    info "Workflow directory: $WORKFLOW_DIR"
    
    # Ensure schema exists
    SCHEMA_FILE=$(ensure_schema "$DATABASE_NAME" "$WORKFLOW_DIR")
    
    # Parse stages (handle auto detection)
    if [ "$STAGES" = "auto" ]; then
        info "Auto-detecting stages from n8n Status field..."
        local start_states=$(extract_start_states "$SCHEMA_FILE")
        if [ -z "$start_states" ]; then
            error "Cannot auto-detect stages - no n8n Status field with START states found. Please run n8n-010-status-setup first or provide --stages manually."
        fi
        local num_stages=$(echo "$start_states" | wc -l)
        success "Detected $num_stages stages from n8n Status field"
    else
        readarray -t STAGE_ARRAY < <(parse_stages "$STAGES" "$SCHEMA_FILE")
        info "Using ${#STAGE_ARRAY[@]} stages: ${STAGE_ARRAY[*]}"
        
        # Setup status field if not using auto
        if [ "$SKIP_STATUS_SETUP" = "false" ]; then
            setup_status_field "$DATABASE_NAME" "$STAGES"
        fi
    fi
    
    # Generate webhook path if not provided
    if [ -z "$WEBHOOK_PATH" ]; then
        WEBHOOK_PATH=$(echo "$DATABASE_NAME" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
        info "Generated webhook path: $WEBHOOK_PATH"
    fi
    
    # Generate output file path
    TIMESTAMP=$(generate_timestamp)
    OUTPUT_FILE="$WORKFLOW_DIR/lifecycle/$TIMESTAMP-IaxdtutZrdNRitl1-04-workflow.json"
    
    # Create lifecycle directory if it doesn't exist
    mkdir -p "$WORKFLOW_DIR/lifecycle"
    
    info "Generating workflow: $OUTPUT_FILE"
    
    # Generate and save workflow
    generate_workflow "$DATABASE_NAME" "$SCHEMA_FILE" "$WEBHOOK_PATH" > "$OUTPUT_FILE"
    
    success "Workflow structure generated: $OUTPUT_FILE"
    
    # Apply post-processing refactor
    apply_refactor "$OUTPUT_FILE" "$DATABASE_NAME" "$WORKFLOW_DIR"
    
    success "IaxdtutZrdNRitl1-pattern workflow generation complete!"
    info "Output file: $OUTPUT_FILE"
    info "Webhook URL: /webhook/$WEBHOOK_PATH"
    
    # Display detected structure
    local start_states=$(extract_start_states "$SCHEMA_FILE")
    local num_states=$(echo "$start_states" | wc -l)
    info "Generated nodes:"
    info "  - N00 Receive-Request (webhook trigger)"
    info "  - N01 Extract-Data (all fields flattened)"
    info "  - N02 Route-ByStatus (router with $num_states outputs + Done)"
    info "  - N03a-N03$(printf "\\$(printf '%03o' $((96 + $num_states)))" ) Process-Data ($num_states nodes)"
    info "  - N03z Handle-Completed (no-op for done items)"
    info "  - N04 Update-DataStatus (write back to Notion)"
    info "  - S00-S04 Subflow nodes (self-calling pattern)"
    
    # Display next steps
    echo
    echo "Next steps:"
    echo "1. Upload workflow to n8n using: n8n-11-workflow-upload.sh \"$OUTPUT_FILE\""
    echo "2. Test webhook endpoint: POST /webhook/$WEBHOOK_PATH"
    echo "3. Verify status field progression in Notion"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi