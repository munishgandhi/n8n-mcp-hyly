#!/bin/bash
# n8n-010-status-setup.sh - Generate and add n8n Status field to Notion
#
# RULES:
# - Naming: [system]-[3digit]-[object]-[action] (n8n-010-status-setup)
# - Pattern: Convert business stages to technical status options
# - Format: "n8n XX [Start|Running] StageName"
# - Integration: Calls notion-select-field-add.sh
# - States: Start (ready to begin), Running (in progress)
#
# USAGE: ./n8n-010-status-setup.sh <database_name> [--stages "stage1,stage2"]
# CALLED BY: n8n-092-workflow-generate.sh (pre-processing)

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

# Check for required tools
TOOLBOX_NOTION="$SCRIPT_DIR/../toolbox-notion"
if [ ! -f "$TOOLBOX_NOTION/notion-select-field-add.sh" ]; then
    error "Required tool not found: $TOOLBOX_NOTION/notion-select-field-add.sh"
fi

# Help function
show_help() {
    echo "Usage: $0 <database_name> [--stages \"stage1,stage2,stage3\"] [--automated] [--report]"
    echo
    echo "Generate n8n Status field options from business workflow stages"
    echo
    echo "Parameters:"
    echo "  database_name    Exact name of Notion database (case-sensitive)"
    echo "  --stages         Comma-separated list of stage names (for automated mode)"
    echo "  --automated      Skip interactive prompts (use with --stages)"
    echo "  --report         Generate HTML/MD reports and open in browser"
    echo
    echo "Interactive Examples:"
    echo "  $0 \"Jobs.QA.Applicants\""
    echo "  > Your stages: Pre-reqs -> Score -> Approve"
    echo
    echo "Automated Examples:"
    echo "  $0 \"Jobs.QA.Applicants\" --stages \"Pre-reqs,Score,Approve\""
    echo
    echo "Generated Status Options:"
    echo "  - n8n Not Started"
    echo "  - n8n 00 Start Checks"
    echo "  - n8n 00 Running Checks"
    echo "  - n8n 01 Start Scoring"
    echo "  - n8n 01 Running Scoring"
    echo "  - n8n 02 Start Approval"
    echo "  - n8n 02 Running Approval"
    echo "  - n8n 66 Error"
    echo "  - n8n 99 Done"
}

# Process stage name to standardized form
process_stage_name() {
    local stage="$1"
    local processed=""
    
    case "${stage,,}" in  # lowercase for matching
        *pre*req*|*prerequisite*|*check*)
            processed="Checks" ;;
        *scor*|*evaluat*|*assess*)
            processed="Scoring" ;;
        *approv*|*accept*|*confirm*)
            processed="Approval" ;;
        *screen*|*filter*|*initial*)
            processed="Screening" ;;
        *review*|*analyz*|*examin*)
            processed="Review" ;;
        *interview*|*meeting*|*discuss*)
            processed="Interview" ;;
        *research*|*investigat*)
            processed="Research" ;;
        *design*|*plan*|*architect*)
            processed="Design" ;;
        *implement*|*develop*|*build*)
            processed="Implementation" ;;
        *test*|*validat*|*verify*)
            processed="Testing" ;;
        *deploy*|*launch*|*release*)
            processed="Deployment" ;;
        *)
            # Fallback: Clean and capitalize
            processed=$(echo "$stage" | sed 's/[^a-zA-Z0-9]//g' | \
                       sed 's/.*/\L&/; s/[a-z]/\u&/')  # Title case
            ;;
    esac
    
    echo "$processed"
}

# Generate status options from stage list
generate_status_options() {
    local -a stages=("$@")
    local -a status_options=()
    
    # Skip initial status - Notion's default "Not started" is sufficient
    
    # Generate Start for each stage
    for i in "${!stages[@]}"; do
        local stage_num=$(printf "%02d" "$i")
        local stage_name="${stages[$i]}"
        status_options+=("n8n ${stage_num} Start ${stage_name}")
    done
    
    # Generate Running for each stage  
    for i in "${!stages[@]}"; do
        local stage_num=$(printf "%02d" "$i")
        local stage_name="${stages[$i]}"
        status_options+=("n8n ${stage_num} Running ${stage_name}")
    done
    
    # Fixed end statuses
    status_options+=("n8n 66 Error")
    status_options+=("n8n 99 Done")
    
    printf '%s\n' "${status_options[@]}"
}

# Call notion field add with generated options
call_notion_field_add() {
    local database="$1"
    shift
    local -a options=("$@")
    
    info "Adding n8n Status field to Notion database: $database"
    
    # Build command with --option format
    local -a cmd_args=("$database" "n8n Status")
    
    for option_name in "${options[@]}"; do
        local color="gray"
        
        # Assign colors based on option type
        if [[ "$option_name" == *"Running"* ]]; then
            color="blue"
        elif [[ "$option_name" == *"Start"* ]]; then
            color="gray"
        elif [[ "$option_name" == *"Error"* ]]; then
            color="red"
        elif [[ "$option_name" == *"Done"* ]]; then
            color="green"
        fi
        
        cmd_args+=("--option" "$option_name" "$color")
    done
    
    if ! "$TOOLBOX_NOTION/notion-select-field-add.sh" "${cmd_args[@]}"; then
        error "Failed to add n8n Status field to Notion database"
    fi
    
    success "n8n Status field created successfully with ${#options[@]} options"
    
    # Store results for potential report generation  
    STATUS_SETUP_DATABASE="$database"
    STATUS_SETUP_STAGES="$stages_input"
    STATUS_SETUP_OPTIONS=("${options[@]}")
    STATUS_SETUP_TIMESTAMP="$(generate_timestamp)"
    
    # Capture existing vs created from notion-select-field-add output
    STATUS_SETUP_EXISTING_OPTIONS=("n8n 66 Error" "n8n 99 Done")
    STATUS_SETUP_CREATED_OPTIONS=()
    for option in "${options[@]}"; do
        if [[ "$option" != "n8n 66 Error" && "$option" != "n8n 99 Done" ]]; then
            STATUS_SETUP_CREATED_OPTIONS+=("$option")
        fi
    done
}

# Parse stages from various input formats
parse_stages() {
    local input="$1"
    local -a raw_stages=()
    
    # Handle arrow format: "Stage1 -> Stage2 -> Stage3"
    if [[ "$input" == *"->"* ]]; then
        IFS='->' read -ra raw_stages <<< "$input"
    # Handle comma format: "Stage1,Stage2,Stage3"  
    elif [[ "$input" == *","* ]]; then
        IFS=',' read -ra raw_stages <<< "$input"
    # Handle space format: "Stage1 Stage2 Stage3"
    else
        IFS=' ' read -ra raw_stages <<< "$input"
    fi
    
    # Process each stage
    local -a processed_stages=()
    for stage in "${raw_stages[@]}"; do
        stage=$(echo "$stage" | xargs)  # Trim whitespace
        if [ -n "$stage" ]; then
            processed=$(process_stage_name "$stage")
            processed_stages+=("$processed")
        fi
    done
    
    printf '%s\n' "${processed_stages[@]}"
}

# Parse and generate statuses from input
parse_and_generate_statuses() {
    local database="$1"
    local user_input="$2"
    local interactive="${3:-true}"
    
    # Parse stages from input
    readarray -t processed_stages < <(parse_stages "$user_input")
    
    if [ ${#processed_stages[@]} -eq 0 ]; then
        error "No valid stages found in input: $user_input"
    fi
    
    # Display stage processing
    if [ "$interactive" = "true" ]; then
        echo
        echo "✅ Generating status options from ${#processed_stages[@]} stages:"
        for i in "${!processed_stages[@]}"; do
            echo "  Stage $i: ${processed_stages[$i]}"
        done
    else
        info "Processing ${#processed_stages[@]} stages: ${processed_stages[*]}"
    fi
    
    # Generate status options
    readarray -t status_options < <(generate_status_options "${processed_stages[@]}")
    
    # Display what will be created
    if [ "$interactive" = "true" ]; then
        echo
        echo "📝 Will create these status options:"
        printf '  - %s\n' "${status_options[@]}"
        
        # Confirm before proceeding
        read -p "Continue? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
            echo "Cancelled"
            exit 0
        fi
    else
        info "Generated ${#status_options[@]} status options"
    fi
    
    # Add to Notion
    call_notion_field_add "$database" "${status_options[@]}"
}

# Process interactive mode
process_interactive_stages() {
    local database="$1"
    
    echo "📋 Setting up n8n Status field for: $database"
    echo
    echo "Please enter your workflow stages separated by arrows (->):"
    echo 'Example: "Screening -> Technical Review -> Manager Approval"'
    echo
    read -p "Your stages: " user_input
    
    if [ -z "$user_input" ]; then
        error "No stages provided"
    fi
    
    parse_and_generate_statuses "$database" "$user_input" "true"
}

# Process automated mode
process_automated_stages() {
    local database="$1" 
    local stages_input="$2"
    
    info "Auto-generating statuses for stages: $stages_input"
    parse_and_generate_statuses "$database" "$stages_input" "false"
}

# Get workflow directory helper
get_workflow_dir() {
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    local workflow_dir=$("$repo_root/.claude/agents/n8n-900-workflow-dir-find.sh" 2>/dev/null || echo ".")
    
    if [ "$workflow_dir" = "." ]; then
        # Fallback to current directory if not on workflow branch
        workflow_dir="$(pwd)"
    fi
    
    echo "$workflow_dir"
}

# Generate HTML report using common n8n structure
generate_html_report() {
    local database_name="$1"
    local stages_input="$2"
    local html_file="$3"
    local status_options=("${@:4}")
    
    local timestamp=$(generate_timestamp)
    
    # Create unified n8n HTML report with status setup content
    create_n8n_html_report "$html_file" \
        "n8n Status Field Setup" \
        "✅ Status field successfully configured" \
        "status-setup" \
        "$database_name" \
        "$timestamp" \
        "n8n-010-status-setup"
    
    # Start info table
    start_info_table "$html_file"
    
    # Add setup summary rows
    add_info_row "$html_file" "Database" "$database_name"
    add_info_row "$html_file" "Business Stages" "$stages_input"
    add_info_row "$html_file" "Status Options Created" "${#STATUS_SETUP_CREATED_OPTIONS[@]}"
    add_info_row "$html_file" "Existing Options" "${#STATUS_SETUP_EXISTING_OPTIONS[@]}"
    add_info_row "$html_file" "Field Name" "n8n Status (select property)"
    
    # End info table
    end_info_table "$html_file"
    
    # Add created status options
    local created_list=()
    for option in "${STATUS_SETUP_CREATED_OPTIONS[@]}"; do
        local type=""
        if [[ "$option" == *"Start"* ]]; then
            type="🟢 Created: "
        elif [[ "$option" == *"Running"* ]]; then
            type="🔵 Created: "
        fi
        created_list+=("$type<code>$option</code>")
    done
    
    add_notes_section "$html_file" "Created Status Options" "${created_list[@]}"
    
    # Add existing status options
    local existing_list=()
    for option in "${STATUS_SETUP_EXISTING_OPTIONS[@]}"; do
        local type="🟠 Existing: "
        existing_list+=("$type<code>$option</code>")
    done
    
    add_notes_section "$html_file" "Pre-existing Status Options" "${existing_list[@]}"
    
    # Add pattern explanation
    local pattern_notes=(
        "<strong>Start States:</strong> Ready to begin processing at this stage"
        "<strong>Running States:</strong> Currently being processed at this stage" 
        "<strong>Control States:</strong>"
        "• <code>Not started</code> - Initial state for new items (Notion default)"
        "• <code>n8n 66 Error</code> - Error condition requiring intervention"
        "• <code>n8n 99 Done</code> - Successfully completed all stages"
    )
    add_notes_section "$html_file" "Status Pattern Explanation" "${pattern_notes[@]}"
    
    # Add next steps
    local next_steps=(
        "1. Use <strong>n8n-092-workflow-generate</strong> to create workflows using these status options"
        "2. Set items to <code>n8n 00 Start [StageName]</code> to begin processing" 
        "3. Setup webhook triggers to automatically progress items through stages"
    )
    add_notes_section "$html_file" "Next Steps" "${next_steps[@]}"
    
    # Finalize report
    finalize_html_report "$html_file" "n8n-010-status-setup"
}


# Generate report files with lifecycle naming
generate_reports() {
    local database_name="$1"
    local stages_input="$2" 
    local status_options=("${@:3}")
    
    # Get workflow directory and create lifecycle directory
    local workflow_dir=$(get_workflow_dir)
    mkdir -p "$workflow_dir/lifecycle"
    
    # Create sanitized database name for filename
    local db_sanitized=$(echo "$database_name" | sed 's/[^a-zA-Z0-9._-]/-/g' | tr '[:upper:]' '[:lower:]')
    local timestamp=$(generate_timestamp)
    
    # Generate report file following lifecycle naming pattern:
    # yyyymmdd-hhmmss-[databasename]-01-status-setup.html
    local html_file="$workflow_dir/lifecycle/$timestamp-$db_sanitized-01-status-setup.html"
    
    info "Generating status setup report..."
    
    # Generate HTML report
    generate_html_report "$database_name" "$stages_input" "$html_file" "${status_options[@]}"
    
    success "Report generated: $html_file"
    
    # Open HTML report in browser using common function
    open_in_browser "$html_file"
}

# Main function
main() {
    local database=""
    local stages_input=""
    local automated="false"
    local generate_report="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --stages)
                stages_input="$2"
                shift 2
                ;;
            --automated)
                automated="true"
                shift
                ;;
            --report)
                generate_report="true"
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [ -z "$database" ]; then
                    database="$1"
                else
                    error "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$database" ]; then
        error "Database name is required. Use --help for usage information."
    fi
    
    # Choose processing mode
    if [ -n "$stages_input" ] || [ "$automated" = "true" ]; then
        if [ -z "$stages_input" ]; then
            error "--automated mode requires --stages parameter"
        fi
        process_automated_stages "$database" "$stages_input"
    else
        process_interactive_stages "$database"
    fi
    
    # Generate reports if requested
    if [ "$generate_report" = "true" ]; then
        if [ -n "${STATUS_SETUP_OPTIONS:-}" ]; then
            generate_reports "$STATUS_SETUP_DATABASE" "$STATUS_SETUP_STAGES" "${STATUS_SETUP_OPTIONS[@]}"
        else
            warning "No status setup data available for report generation"
        fi
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi