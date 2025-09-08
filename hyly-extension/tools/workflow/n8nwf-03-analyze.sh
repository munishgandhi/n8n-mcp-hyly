#!/bin/bash
# n8nwf-03-analyze.sh - Analyze workflow execution results
# Based on n8n-11-execution-extract.sh from toolbox

set -euo pipefail

# Script directory and common functions
SCRIPT_DIR="$(dirname "$0")"
EXTENSION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions if available
if [ -f "$EXTENSION_ROOT/tools/common/n8n-000-common.sh" ]; then
    source "$EXTENSION_ROOT/tools/common/n8n-000-common.sh"
else
    # Minimal functions if common not available
    info() { echo "ℹ️  $*"; }
    success() { echo "✅ $*"; }
    error() { echo "❌ $*" >&2; exit 1; }
    warning() { echo "⚠️  $*"; }
fi

# Parse arguments
WORKFLOW_ID=""
EXECUTION_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            echo "Usage: $0 <workflow-id> <execution-id>"
            echo ""
            echo "Analyze n8n workflow execution and generate lifecycle files"
            echo ""
            echo "Arguments:"
            echo "  workflow-id       Workflow ID that was executed"
            echo "  execution-id      Execution ID from n8nwf-02-execute"
            echo ""
            echo "Generated files:"
            echo "  04-workflow.json         Current workflow definition"
            echo "  05-trace-{execId}.json   Full execution trace data"
            echo "  06-errors-{execId}.json  Execution with errors"
            echo "  06-noerrors-{execId}.json Execution without errors"
            exit 0
            ;;
        *)
            if [ -z "$WORKFLOW_ID" ]; then
                WORKFLOW_ID="$1"
            elif [ -z "$EXECUTION_ID" ]; then
                EXECUTION_ID="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$WORKFLOW_ID" ] || [ -z "$EXECUTION_ID" ]; then
    error "Usage: $0 <workflow-id> <execution-id>"
fi

info "Analyzing execution: $EXECUTION_ID for workflow: $WORKFLOW_ID"

# Environment variables
N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-$(grep N8N_API_KEY /home/mg/src/vc-mgr/.env 2>/dev/null | cut -d'=' -f2 || echo '')}"

if [ -z "$N8N_API_KEY" ]; then
    error "N8N_API_KEY environment variable not set!"
fi

# Ensure lifecycle directory exists
WORKFLOW_DIR="$(pwd)"
if [ ! -d "lifecycle" ]; then
    mkdir -p lifecycle
fi

# Generate timestamp
TIMESTAMP=$(TZ=America/New_York date +%Y%m%d-%H%M%S)

info "Generating analysis files with timestamp: $TIMESTAMP"

# =============================================================================
# 1. EXTRACT WORKFLOW DEFINITION
# =============================================================================

info "Extracting workflow definition..."

WORKFLOW_FILE="lifecycle/${TIMESTAMP}-${WORKFLOW_ID}-04-workflow.json"

workflow_data=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_HOST/api/v1/workflows/$WORKFLOW_ID")

if echo "$workflow_data" | jq -e '.id' > /dev/null 2>&1; then
    echo "$workflow_data" | jq '.' > "$WORKFLOW_FILE"
    success "Saved workflow: $(basename "$WORKFLOW_FILE")"
    
    # Show workflow info
    wf_name=$(echo "$workflow_data" | jq -r '.name // "Unknown"')
    node_count=$(echo "$workflow_data" | jq '.nodes | length // 0')
    
    info "Workflow: $wf_name ($node_count nodes)"
else
    error "Failed to retrieve workflow $WORKFLOW_ID"
fi

# =============================================================================
# 2. EXTRACT EXECUTION TRACE
# =============================================================================

info "Extracting execution trace..."

TRACE_FILE="lifecycle/${TIMESTAMP}-${WORKFLOW_ID}-05-trace-${EXECUTION_ID}.json"

execution_data=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_HOST/api/v1/executions/$EXECUTION_ID?includeData=true")

if echo "$execution_data" | jq -e '.id' > /dev/null 2>&1; then
    echo "$execution_data" | jq '.' > "$TRACE_FILE"
    success "Saved trace: $(basename "$TRACE_FILE")"
else
    error "Failed to retrieve execution $EXECUTION_ID"
fi

# =============================================================================
# 3. ANALYZE EXECUTION STATUS
# =============================================================================

info "Analyzing execution status..."

# Extract execution information
exec_status=$(echo "$execution_data" | jq -r '.status // "unknown"')
exec_finished=$(echo "$execution_data" | jq -r '.finished // false')
exec_started_at=$(echo "$execution_data" | jq -r '.startedAt // "unknown"')
exec_stopped_at=$(echo "$execution_data" | jq -r '.stoppedAt // "unknown"')

# Analyze execution data for errors
run_data=$(echo "$execution_data" | jq '.data.resultData.runData // {}')
error_count=0
successful_nodes=0
failed_nodes=0
total_nodes=0

# Count nodes and analyze their status
if [ "$run_data" != "null" ] && [ "$run_data" != "{}" ]; then
    node_names=$(echo "$run_data" | jq -r 'keys[]')
    
    while IFS= read -r node_name; do
        if [ -n "$node_name" ]; then
            total_nodes=$((total_nodes + 1))
            
            # Get node execution status
            node_status=$(echo "$run_data" | jq -r --arg node "$node_name" '.[$node][0].executionStatus // "unknown"')
            
            if [ "$node_status" = "success" ]; then
                successful_nodes=$((successful_nodes + 1))
            else
                failed_nodes=$((failed_nodes + 1))
                if [ "$node_status" = "error" ]; then
                    error_count=$((error_count + 1))
                fi
            fi
        fi
    done <<< "$node_names"
fi

# Calculate execution time
execution_time="unknown"
if [ "$exec_started_at" != "unknown" ] && [ "$exec_stopped_at" != "unknown" ]; then
    start_epoch=$(date -d "$exec_started_at" +%s 2>/dev/null || echo "0")
    stop_epoch=$(date -d "$exec_stopped_at" +%s 2>/dev/null || echo "0")
    if [ "$start_epoch" -gt 0 ] && [ "$stop_epoch" -gt 0 ]; then
        execution_time="$((stop_epoch - start_epoch))s"
    fi
fi

# Create analysis result
analysis_result=$(cat << EOF
{
  "executionId": "$EXECUTION_ID",
  "workflowId": "$WORKFLOW_ID",
  "status": "$exec_status",
  "executionMethod": "n8n CLI",
  "analysisTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "errorCount": $error_count,
  "warningCount": 0,
  "executionSummary": {
    "totalNodes": $total_nodes,
    "successfulNodes": $successful_nodes,
    "failedNodes": $failed_nodes,
    "executionTime": "$execution_time",
    "finished": $exec_finished,
    "startedAt": "$exec_started_at",
    "stoppedAt": "$exec_stopped_at"
  },
  "lifecycleValidation": {
    "workflowExtract": "✅ SUCCESS",
    "executionExtract": "✅ SUCCESS", 
    "statusAnalysis": "✅ SUCCESS",
    "fileGeneration": "✅ SUCCESS"
  },
  "recommendations": [
    "Analysis completed for execution $EXECUTION_ID",
    "Generated lifecycle files with timestamp $TIMESTAMP",
    "$([ $error_count -eq 0 ] && echo "✅ No errors detected - workflow executed successfully" || echo "⚠️ $error_count error(s) detected - check execution trace")"
  ]
}
EOF
)

# Determine if this is an error or success execution
if [ "$error_count" -eq 0 ] && [ "$exec_status" = "success" ]; then
    STATUS_FILE="lifecycle/${TIMESTAMP}-${WORKFLOW_ID}-06-noerrors-${EXECUTION_ID}.json"
    success "Execution completed without errors"
else
    STATUS_FILE="lifecycle/${TIMESTAMP}-${WORKFLOW_ID}-06-errors-${EXECUTION_ID}.json"
    warning "Execution had $error_count error(s)"
fi

echo "$analysis_result" | jq '.' > "$STATUS_FILE"
success "Saved status: $(basename "$STATUS_FILE")"

# =============================================================================
# 4. SUMMARY
# =============================================================================

echo ""
success "Analysis complete for execution $EXECUTION_ID!"
echo ""
echo "📊 Execution Summary:"
echo "  📋 Workflow: $wf_name"
echo "  🆔 Execution ID: $EXECUTION_ID"
echo "  🎯 Status: $exec_status"
echo "  🔧 Nodes: $total_nodes total, $successful_nodes successful, $failed_nodes failed"
echo "  ⏱️  Time: $execution_time"
echo "  ❌ Errors: $error_count"
echo ""
echo "📁 Generated files:"
echo "  - 04-workflow: $(basename "$WORKFLOW_FILE")"
echo "  - 05-trace:    $(basename "$TRACE_FILE")"
echo "  - 06-status:   $(basename "$STATUS_FILE")"
echo ""

if [ "$error_count" -eq 0 ]; then
    success "🎉 Workflow executed successfully with no errors!"
    info "Ready for next iteration or deployment"
else
    warning "⚠️ Workflow has errors that need to be fixed"
    info "Next step: Create 07-fix-draft.json to address the issues"
    info "Then run: n8nwf-04-validate to validate fixes"
fi

exit 0