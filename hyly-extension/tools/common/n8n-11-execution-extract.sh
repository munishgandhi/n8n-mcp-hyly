#!/bin/bash

# n8n-11-execution-extract.sh - Extract n8n workflow execution data
# Usage: ./n8n-11-execution-extract.sh [--context] [--report] <workflow-id> [execution-id1] [execution-id2] ...
# 
# Extracts execution data for analysis:
#   - Downloads workflow definition ONCE (04-workflow)
#   - For each execution (or latest if none specified):
#     - Generates execution trace (05-trace-{execid})
#     - Determines error status (06-errors-{execid} or 06-noerrors-{execid})
# 
# Options:
#   --context     Save extracted files to context/ directory
#   --report      Generate HTML/MD reports and open in browser
#
# This is a pure extraction agent. For analysis, use n8n-31-execution-analyze

set -e

# Source common functions for report generation
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8n-000-common.sh"

# Check for flags
CONTEXT_MODE=false
REPORT_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --context)
            CONTEXT_MODE=true
            shift
            ;;
        --report)
            REPORT_MODE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Check arguments
if [ $# -lt 1 ]; then
    echo "❌ Usage: $0 [--context] [--report] <workflow-id> [execution-id1] [execution-id2] ..."
    echo "Examples:"
    echo "  $0 3soZAbHUm8vgIkXp                    # Extract latest execution"
    echo "  $0 3soZAbHUm8vgIkXp 12345              # Extract specific execution"
    echo "  $0 3soZAbHUm8vgIkXp 12345 12346 12347  # Extract multiple executions"
    echo "  $0 --context 3soZAbHUm8vgIkXp 12345    # Extract and save to context/"
    echo "  $0 --report 3soZAbHUm8vgIkXp 12345     # Extract with HTML/MD report"
    echo "  $0 --context --report 3soZAbHUm8vgIkXp 12345  # Both modes"
    exit 1
fi

WORKFLOW_ID="$1"
shift  # Remove workflow ID from arguments
EXECUTION_IDS=("$@")  # All remaining arguments are execution IDs (might be empty)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# DEBUG: Enhanced environment check
echo "🔍 DEBUG: Enhanced Environment Check"
echo "  Working Directory: $(pwd)"
echo "  Home Directory: $HOME"
echo "  Script Path: $0"
echo "  Script Directory: $(dirname "$0")"
echo "  Git Root: $(git rev-parse --show-toplevel 2>/dev/null || echo "Not in git repo")"
echo "  User: $USER"
echo "  Shell: $SHELL"
echo "  Timestamp: $TIMESTAMP"
echo "  N8N_API_KEY length: ${#N8N_API_KEY}"
echo "  N8N_URL: ${N8N_URL:-not set}"
echo "  PATH contains n8n: $(command -v n8n >/dev/null 2>&1 && echo "yes" || echo "no")"

# Get workflow directory using mapper
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKFLOW_DIR=$("$REPO_ROOT/.claude/toolbox-n8n/n8n-900-workflow-dir-find.sh")

if [ "$WORKFLOW_DIR" = "." ]; then
    echo "❌ Not on a workflow branch or workflow directory not found"
    exit 1
fi

echo "🔍 n8n Execution Analyzer"
echo "📋 Workflow ID: $WORKFLOW_ID"
echo "📁 Workflow directory: $WORKFLOW_DIR"
if [ ${#EXECUTION_IDS[@]} -gt 0 ]; then
    echo "🔢 Execution IDs: ${EXECUTION_IDS[@]}"
else
    echo "🔢 Execution IDs: (will extract latest)"
fi
echo "📅 Timestamp: $TIMESTAMP"
[ "$CONTEXT_MODE" = true ] && echo "📚 Context mode: Files will be saved to context/"
echo ""

# Determine target directory based on mode
if [ "$CONTEXT_MODE" = true ]; then
    TARGET_DIR="$WORKFLOW_DIR/context"
else
    TARGET_DIR="$WORKFLOW_DIR/lifecycle"
fi

# Create target directory if needed
mkdir -p "$TARGET_DIR"

# Check if n8n is running and API key is set
echo "🔐 Checking API configuration..."

# First try to source .env if it exists
if [ -f "/home/mg/src/vc-mgr/.env" ]; then
    echo "  📄 Found .env file, sourcing..."
    source /home/mg/src/vc-mgr/.env
    echo "  ✅ .env file sourced"
else
    echo "  ⚠️  No .env file found at /home/mg/src/vc-mgr/.env"
fi

# Try to get API key
N8N_API_KEY="${N8N_API_KEY:-$(grep N8N_API_KEY /home/mg/src/vc-mgr/.env 2>/dev/null | cut -d'=' -f2)}"
if [ -z "$N8N_API_KEY" ]; then
    echo "❌ N8N_API_KEY environment variable not set!"
    echo "  Tried: Environment variable and .env file"
    exit 1
else
    echo "  ✅ N8N_API_KEY found (length: ${#N8N_API_KEY})"
fi

# Check API connectivity
echo "  🌐 Testing API connectivity..."
N8N_BASE_URL="${N8N_BASE_URL:-http://localhost:5678}"
echo "  📍 Using N8N_BASE_URL: $N8N_BASE_URL"

if ! curl -s -f -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE_URL/api/v1/workflows?limit=1" > /dev/null 2>&1; then
    echo "❌ n8n API not accessible at $N8N_BASE_URL!"
    echo "  💡 Check if n8n is running and accessible"
    echo "  💡 Verify N8N_BASE_URL is correct (currently: $N8N_BASE_URL)"
    exit 1
else
    echo "  ✅ API is accessible"
fi
echo ""

# =============================================================================
# 1. GET EXECUTION IDS (if not provided, get latest)
# =============================================================================

if [ ${#EXECUTION_IDS[@]} -eq 0 ]; then
    # No execution IDs provided, get latest
    echo "1️⃣ GETTING LATEST EXECUTION..."
    
    executions_data=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE_URL/api/v1/executions?workflowId=$WORKFLOW_ID&limit=1&includeData=false")
    LATEST_EXEC_ID=$(echo "$executions_data" | jq -r '.data[0].id // empty')
    
    if [ -n "$LATEST_EXEC_ID" ]; then
        EXECUTION_IDS=("$LATEST_EXEC_ID")
        echo "  📌 Latest execution ID: $LATEST_EXEC_ID"
        exec_started=$(echo "$executions_data" | jq -r '.data[0].startedAt // empty')
        exec_status=$(echo "$executions_data" | jq -r '.data[0].status // "success"')
        
        echo "  📅 Started: $exec_started"
        echo "  🎯 Status: $exec_status"
    else
        echo "  ❌ No executions found for this workflow"
        echo "  💡 Workflow may not have been executed yet"
        
        # Still extract workflow definition
        echo ""
        echo "2️⃣ EXTRACTING WORKFLOW DEFINITION..."
        WORKFLOW_FILE="$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-04-workflow.json"
        
        workflow_data=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE_URL/api/v1/workflows/$WORKFLOW_ID")
        
        if echo "$workflow_data" | jq -e '.id' > /dev/null 2>&1; then
            echo "$workflow_data" | jq '.' > "$WORKFLOW_FILE"
            echo "  ✅ Saved to: $(basename "$WORKFLOW_FILE")"
            
            wf_name=$(echo "$workflow_data" | jq -r '.name // "Unknown"')
            node_count=$(echo "$workflow_data" | jq '.nodes | length // 0')
            active_status=$(echo "$workflow_data" | jq -r '.active // false')
            
            echo "  📋 Name: $wf_name"
            echo "  🔧 Nodes: $node_count"
            echo "  ⚡ Active: $active_status"
        else
            echo "  ❌ Workflow $WORKFLOW_ID not found"
        fi
        
        echo ""
        echo "✨ Extraction complete (no execution to analyze)"
        exit 0
    fi
else
    echo "1️⃣ USING PROVIDED EXECUTION IDS: ${EXECUTION_IDS[@]}"
fi

# =============================================================================
# 2. EXTRACT WORKFLOW DEFINITION (ONCE)
# =============================================================================
echo ""
echo "2️⃣ EXTRACTING WORKFLOW DEFINITION..."

WORKFLOW_FILE="$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-04-workflow.json"

echo "  📄 Extracting workflow via API: $WORKFLOW_ID"
workflow_data=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE_URL/api/v1/workflows/$WORKFLOW_ID")

if echo "$workflow_data" | jq -e '.id' > /dev/null 2>&1; then
    # Save and format the JSON
    echo "$workflow_data" | jq '.' > "$WORKFLOW_FILE"
    
    echo "  ✅ Saved to: $(basename "$WORKFLOW_FILE")"
    
    # Show workflow info
    wf_name=$(echo "$workflow_data" | jq -r '.name // "Unknown"')
    node_count=$(echo "$workflow_data" | jq '.nodes | length // 0')
    active_status=$(echo "$workflow_data" | jq -r '.active // false')
    updated_at=$(echo "$workflow_data" | jq -r '.updatedAt')
    
    echo "  📋 Name: $wf_name"
    echo "  🔧 Nodes: $node_count"
    echo "  ⚡ Active: $active_status"
    echo "  🕒 Updated: $updated_at"
else
    echo "  ❌ Workflow $WORKFLOW_ID not found or API error"
    exit 1
fi

# =============================================================================
# 3. PROCESS EACH EXECUTION
# =============================================================================

# Get repo root to find trace/error scripts
REPO_ROOT=$(git rev-parse --show-toplevel)
TRACE_SCRIPT="$REPO_ROOT/.claude/scripts/10-workflow-trace.sh"
ERROR_SCRIPT="$REPO_ROOT/.claude/scripts/10-workflow-errors.sh"

# Check scripts exist
if [ ! -f "$TRACE_SCRIPT" ]; then
    echo "❌ Error: 10-workflow-trace.sh not found at $TRACE_SCRIPT"
    exit 1
fi

if [ ! -f "$ERROR_SCRIPT" ]; then
    echo "❌ Error: 10-workflow-errors.sh not found at $ERROR_SCRIPT"
    exit 1
fi

# Counter for execution processing
exec_count=0
total_execs=${#EXECUTION_IDS[@]}

# Arrays to track created files for reference mode
CREATED_FILES=()
CREATED_FILES+=("$WORKFLOW_FILE")

for EXECUTION_ID in "${EXECUTION_IDS[@]}"; do
    exec_count=$((exec_count + 1))
    
    if [ $total_execs -gt 1 ]; then
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "3️⃣ PROCESSING EXECUTION $exec_count/$total_execs: $EXECUTION_ID"
        echo "════════════════════════════════════════════════════════════════"
    else
        echo ""
        echo "3️⃣ ANALYZING EXECUTION $EXECUTION_ID..."
    fi
    
    # Get execution details (skip if multiple executions to save API calls)
    if [ $total_execs -eq 1 ]; then
        execution_data=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE_URL/api/v1/executions/$EXECUTION_ID?includeData=false")
        exec_started=$(echo "$execution_data" | jq -r '.startedAt // empty')
        exec_status=$(echo "$execution_data" | jq -r '.status // "unknown"')
        
        if [ "$exec_status" = "null" ] || [ -z "$exec_started" ]; then
            echo "  ❌ Execution $EXECUTION_ID not found! Skipping..."
            continue
        fi
        
        echo "  📅 Started: $exec_started"
        echo "  🎯 Status: $exec_status"
    fi
    
    # Run trace analysis
    echo "  📊 Running trace analysis..."
    TRACE_FILE="$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-05-trace-${EXECUTION_ID}.json"
    "$TRACE_SCRIPT" "$EXECUTION_ID" "$TRACE_FILE"
    echo "  ✅ Trace saved to: $(basename "$TRACE_FILE")"
    CREATED_FILES+=("$TRACE_FILE")
    
    # Run error analysis
    echo "  🔍 Running error analysis..."
    ERROR_TMP=$(mktemp)
    "$ERROR_SCRIPT" "$EXECUTION_ID" "$ERROR_TMP"
    
    # Check if there are errors and rename accordingly
    if [ -f "$ERROR_TMP" ]; then
        ERROR_COUNT=$(jq -r '.execution_info.error_nodes // 0' "$ERROR_TMP" 2>/dev/null || echo "0")
        EXEC_STATUS=$(jq -r '.execution_info.status // "unknown"' "$ERROR_TMP" 2>/dev/null || echo "unknown")
        
        if [ "$ERROR_COUNT" = "0" ] || [ "$ERROR_COUNT" = "null" ]; then
            ERROR_COUNT="0"
        fi
        
        if [ "$ERROR_COUNT" = "0" ] && [ "$EXEC_STATUS" = "success" ]; then
            # No errors - save as noerrors
            STATUS_FILE="$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json"
            mv "$ERROR_TMP" "$STATUS_FILE"
            echo "  ✅ Execution completed without errors"
            echo "  ✅ Status saved to: $(basename "$STATUS_FILE")"
        else
            # Has errors - save as errors
            STATUS_FILE="$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json"
            mv "$ERROR_TMP" "$STATUS_FILE"
            echo "  ⚠️  Execution had $ERROR_COUNT errors"
            echo "  ✅ Errors saved to: $(basename "$STATUS_FILE")"
        fi
        CREATED_FILES+=("$STATUS_FILE")
    else
        echo "  ❌ Error analysis failed"
    fi
done

# =============================================================================
# 4. EXTRACTION COMPLETE
# =============================================================================

# =============================================================================
# 5. FINAL SUMMARY
# =============================================================================

echo ""
echo "5️⃣ EXTRACTION COMPLETE"

echo ""
echo "✨ Extraction complete!"
echo ""

if [ "$CONTEXT_MODE" = true ]; then
    echo "📁 Files created in context/:"
    echo "  - 04-workflow: $(basename "$WORKFLOW_FILE")"
    
    for EXECUTION_ID in "${EXECUTION_IDS[@]}"; do
        echo ""
        echo "  Execution $EXECUTION_ID:"
        echo "  - 05-trace:    ${TIMESTAMP}-${WORKFLOW_ID}-05-trace-${EXECUTION_ID}.json"
        if [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json" ]; then
            echo "  - 06-status:   ${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json"
        elif [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json" ]; then
            echo "  - 06-status:   ${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json"
        fi
    done
else
    echo "📁 Files created in lifecycle/:"
    echo "  - 04-workflow: $(basename "$WORKFLOW_FILE")"
    
    for EXECUTION_ID in "${EXECUTION_IDS[@]}"; do
        echo ""
        echo "  Execution $EXECUTION_ID:"
        if [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-05-trace-${EXECUTION_ID}.json" ]; then
            echo "  - 05-trace:    $(basename "${TIMESTAMP}-${WORKFLOW_ID}-05-trace-${EXECUTION_ID}.json")"
        fi
        if [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json" ]; then
            echo "  - 06-status:   $(basename "${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json")"
        elif [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json" ]; then
            echo "  - 06-status:   $(basename "${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json")"
        fi
    done
fi

# Generate report if requested
if [ "$REPORT_MODE" = true ]; then
    info "Generating execution extraction report..."
    
    HTML_FILE="$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-04-exec-${EXECUTION_IDS[0]}.html"
    WF_NAME=$(jq -r '.name // "Unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "Unknown")
    NODE_COUNT=$(jq '.nodes | length // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
    
    # Create unified HTML report
    create_n8n_html_report "$HTML_FILE" \
        "n8n Execution Report - $WORKFLOW_ID" \
        "[▶️ Execution Complete]" \
        "$WORKFLOW_ID" \
        "$WF_NAME" \
        "$TIMESTAMP" \
        "n8n-11-execution-extract.sh"
    
    # Build output files list
    OUTPUT_FILES="<code>$(basename "$WORKFLOW_FILE")</code>"
    for EXECUTION_ID in "${EXECUTION_IDS[@]}"; do
        OUTPUT_FILES="$OUTPUT_FILES<br><code>${TIMESTAMP}-${WORKFLOW_ID}-05-trace-${EXECUTION_ID}.json</code>"
        if [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json" ]; then
            OUTPUT_FILES="$OUTPUT_FILES<br><code>${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json</code>"
        elif [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json" ]; then
            OUTPUT_FILES="$OUTPUT_FILES<br><code>${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json</code>"
        fi
    done
    
    # Add info table
    start_info_table "$HTML_FILE"
    add_info_row "$HTML_FILE" "Nodes" "$NODE_COUNT"
    add_info_row "$HTML_FILE" "Executions" "${#EXECUTION_IDS[@]} (IDs: ${EXECUTION_IDS[@]})"
    add_info_row "$HTML_FILE" "Mode" "$([ "$CONTEXT_MODE" = true ] && echo "Context (reference)" || echo "Lifecycle (processing)")"
    add_info_row "$HTML_FILE" "Output Files" "$OUTPUT_FILES"
    end_info_table "$HTML_FILE"
    
    # Build notes for add_notes_section
    NOTES=("✅ API connection successful" "✅ Extracted ${#EXECUTION_IDS[@]} execution(s) with traces")
    
    # Add execution status to notes
    for EXECUTION_ID in "${EXECUTION_IDS[@]}"; do
        if [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json" ]; then
            NOTES+=("✅ Execution $EXECUTION_ID: Completed successfully")
        elif [ -f "$TARGET_DIR/${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json" ]; then
            NOTES+=("⚠️ Execution $EXECUTION_ID: Has errors (check 06-errors file)")
        fi
    done
    
    NOTES+=("🔧 Next: Run analysis with <code>n8n-31-execution-analyze $WORKFLOW_ID</code>")
    
    # Add notes section
    add_notes_section "$HTML_FILE" "Execution Notes" "${NOTES[@]}"
    
    # Finalize with footer
    finalize_html_report "$HTML_FILE" "n8n-11-execution-extract.sh"
    
    # Open in browser
    open_in_browser "$HTML_FILE"
    
    success "Report generated: $(basename "$HTML_FILE")"
fi

echo ""
echo "🆔 Workflow ID: $WORKFLOW_ID"
echo "🆔 Execution IDs: ${EXECUTION_IDS[@]}"
echo ""
echo "📌 Next step: Run analysis"
echo "   Command: n8n-31-execution-analyze $WORKFLOW_ID"