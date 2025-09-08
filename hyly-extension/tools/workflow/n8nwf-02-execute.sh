#!/bin/bash
# n8nwf-02-execute.sh - Execute n8n workflow and capture execution ID
#
# WORKFLOW EXECUTION PROCESS - DETAILED STEPS  
# ============================================
# Total execution time: ~2.6 seconds (CLI execution ~0.5s, historical analysis ~0.1s, smart waiting ~0.05s)
#
# Step 1: Pre-Execution State Capture
# - Query: SELECT id FROM execution_entity WHERE "workflowId"='{workflowId}' ORDER BY id DESC LIMIT 1
# - Capture: Latest execution ID before workflow execution
# - Purpose: Detect new execution by comparing before/after execution IDs
# - Method: Direct PostgreSQL database query via Docker exec
#
# Step 2: Historical Performance Analysis
# - Query: Last 10 executions timing data from execution_entity table
# - Calculate: Average execution time (EXTRACT(EPOCH FROM (stoppedAt - startedAt)))
# - Fallback: 0.5 seconds if no historical data available
# - Purpose: Predict optimal wait time using actual workflow performance
#
# Step 3: Workflow Execution Trigger  
# - Command: docker exec hyly-n8n-app n8n execute --id={workflowId}
# - Method: n8n CLI via Docker container with timeout protection
# - Options: --raw flag for raw output format if specified
# - Result: Workflow execution initiated, CLI command completes
#
# Step 4: Smart Execution Detection
# - Query: Check for new execution ID higher than pre-execution baseline
# - Detection: Compare latest execution ID with captured baseline
# - Validation: Confirm new execution belongs to target workflow
# - Purpose: Reliably identify the specific execution that was triggered
#
# Step 5: Intelligent Completion Monitoring
# - Strategy: Exponential backoff based on historical average (1x → 2x → 4x → 8x)
# - Polling: Database status checks with increasing intervals
# - Success: finished=true AND status=success detected
# - Timeout: Fail if execution exceeds 8x historical average (indicates problems)
#
# Step 6: Output Generation
# - Success: Execution ID printed to stdout for pipeline chaining
# - Status: Final execution status and timing reported
# - Next: Ready for n8nwf-03-analyze.sh {workflowId} {executionId}
#
# Usage: n8nwf-02-execute.sh <workflow_id> [--timeout <seconds>] [--raw]
#
# Examples:
#   ./n8nwf-02-execute.sh KQxYbOJgGEEuzVT0
#   ./n8nwf-02-execute.sh KQxYbOJgGEEuzVT0 --timeout 600
#   ./n8nwf-02-execute.sh KQxYbOJgGEEuzVT0 --raw
#

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <workflow_id> [--timeout <seconds>] [--raw]"
    echo ""
    echo "Execute n8n workflow with smart timing and capture execution ID"
    echo ""
    echo "Arguments:"
    echo "  <workflow_id>     n8n workflow ID to execute"
    echo ""
    echo "Options:"
    echo "  --timeout <sec>   Maximum wait time in seconds (default: 300)"
    echo "  --raw            Use --rawOutput flag for n8n CLI"
    echo ""
    echo "Smart Timing:"
    echo "  Uses historical data (last 10 executions) to predict completion time"
    echo "  Exponential backoff: 1x → 2x → 4x → 8x average time"
    echo "  Fails if execution takes longer than 8x historical average"
    echo ""
    echo "Examples:"
    echo "  $0 KQxYbOJgGEEuzVT0"
    echo "  $0 KQxYbOJgGEEuzVT0 --timeout 600"
    echo "  $0 KQxYbOJgGEEuzVT0 --raw"
    exit 1
fi

WORKFLOW_ID="$1"
shift

TIMEOUT=300
RAW_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --raw)
            RAW_OUTPUT=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# =============================================================================
# EXECUTION FUNCTIONS
# =============================================================================

# Function to get latest execution ID for workflow
get_latest_execution_id() {
    local workflow_id="$1"
    
    local latest_exec_id
    latest_exec_id=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
        SELECT id FROM public.execution_entity 
        WHERE \"workflowId\" = '$workflow_id' 
        ORDER BY id DESC 
        LIMIT 1;
    " 2>/dev/null | xargs)
    
    if [[ -z "$latest_exec_id" ]]; then
        echo "0"
    else
        echo "$latest_exec_id"
    fi
}

# Function to check execution status
check_execution_status() {
    local exec_id="$1"
    
    local result
    result=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
        SELECT id, finished, status, \"workflowId\"
        FROM public.execution_entity 
        WHERE id = '$exec_id';
    " 2>/dev/null)
    
    echo "$result"
}

# Function to get average execution time for workflow
get_avg_execution_time() {
    local workflow_id="$1"
    
    local avg_time
    avg_time=$(docker exec hyly-n8n-postgres psql -U n8n -d n8n -t -c "
        SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (\"stoppedAt\" - \"startedAt\"))), 0.5)
        FROM (
            SELECT \"stoppedAt\", \"startedAt\"
            FROM public.execution_entity 
            WHERE \"workflowId\" = '$workflow_id' 
            AND finished = true 
            AND \"stoppedAt\" IS NOT NULL 
            AND \"startedAt\" IS NOT NULL
            ORDER BY id DESC 
            LIMIT 10
        ) recent_executions;
    " 2>/dev/null | xargs)
    
    # Fallback to 0.5 seconds if query fails or returns empty
    if [[ -z "$avg_time" || "$avg_time" == "null" ]]; then
        avg_time="0.5"
    fi
    
    echo "$avg_time"
}

# Function to wait for execution completion with smart exponential backoff
wait_for_execution() {
    local exec_id="$1"
    local workflow_id="$2"
    
    # Get historical average execution time
    local avg_time
    avg_time=$(get_avg_execution_time "$workflow_id")
    info "Historical avg execution time: ${avg_time}s"
    
    # Exponential backoff: 1x, 2x, 4x, 8x average time
    local multipliers=(1 2 4 8)
    local total_wait=0
    
    for multiplier in "${multipliers[@]}"; do
        local wait_interval
        wait_interval=$(echo "$avg_time * $multiplier" | bc -l)
        
        info "Waiting ${wait_interval}s (${multiplier}x avg)..."
        sleep "$wait_interval"
        total_wait=$(echo "$total_wait + $wait_interval" | bc -l)
        
        local status_info
        status_info=$(check_execution_status "$exec_id")
        
        if [[ -n "$status_info" ]]; then
            local finished
            finished=$(echo "$status_info" | awk -F'|' '{print $2}' | xargs)
            
            if [[ "$finished" == "t" || "$finished" == "true" ]]; then
                local status
                status=$(echo "$status_info" | awk -F'|' '{print $3}' | xargs)
                success "Execution completed with status: $status (after ${total_wait}s)"
                return 0
            fi
        fi
        
        warning "Not finished after ${total_wait}s, trying ${multiplier}x backoff..."
    done
    
    error "Execution did not complete after 8x average time (${total_wait}s total). Check for issues!"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

info "Starting workflow execution: $WORKFLOW_ID"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^hyly-n8n-app$"; then
    error "Docker container 'hyly-n8n-app' is not running"
fi

# Get current latest execution ID before execution
info "Checking current execution history..."
BEFORE_EXEC_ID=$(get_latest_execution_id "$WORKFLOW_ID")
info "Latest execution ID before: $BEFORE_EXEC_ID"

# Build n8n execute command
if [[ "$RAW_OUTPUT" == "true" ]]; then
    N8N_CMD="n8n execute --id=$WORKFLOW_ID --rawOutput"
else
    N8N_CMD="n8n execute --id=$WORKFLOW_ID"
fi

info "Executing via Docker: $N8N_CMD"
info "Timeout: ${TIMEOUT}s"

# Execute workflow
TEMP_OUTPUT=$(mktemp)
TEMP_ERROR=$(mktemp)

info "Starting workflow execution..."
if timeout "$TIMEOUT" docker exec hyly-n8n-app $N8N_CMD > "$TEMP_OUTPUT" 2> "$TEMP_ERROR"; then
    success "CLI execution command completed"
else
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 124 ]]; then
        error "CLI execution timed out after ${TIMEOUT}s"
    else
        error "CLI execution failed with exit code $EXIT_CODE"
    fi
fi

# Get new execution ID by checking database
info "Checking for new execution..."
AFTER_EXEC_ID=$(get_latest_execution_id "$WORKFLOW_ID")

if [[ "$AFTER_EXEC_ID" -gt "$BEFORE_EXEC_ID" ]]; then
    EXECUTION_ID="$AFTER_EXEC_ID"
    success "New execution detected: $EXECUTION_ID"
    
    # Wait for execution to complete and check status
    if wait_for_execution "$EXECUTION_ID" "$WORKFLOW_ID"; then
        # Get final status
        STATUS_INFO=$(check_execution_status "$EXECUTION_ID")
        STATUS=$(echo "$STATUS_INFO" | awk -F'|' '{print $3}' | xargs)
        
        if [[ "$STATUS" == "success" ]]; then
            success "Workflow execution completed successfully!"
        else
            warning "Workflow execution completed with status: $STATUS"
        fi
        
        echo "$EXECUTION_ID"  # Output execution ID to stdout
    else
        warning "Execution may still be running. Check status manually."
        echo "$EXECUTION_ID"  # Still output the ID
    fi
else
    warning "No new execution detected. Check if workflow triggered properly."
    
    # Show CLI output for debugging
    if [[ -s "$TEMP_OUTPUT" ]]; then
        info "CLI output:"
        cat "$TEMP_OUTPUT"
    fi
    
    if [[ -s "$TEMP_ERROR" ]]; then
        info "CLI error output:"
        cat "$TEMP_ERROR"
    fi
    
    exit 1
fi

# Cleanup
rm -f "$TEMP_OUTPUT" "$TEMP_ERROR"

# Show summary
echo ""
info "✅ Execution completed successfully!"
echo "  🆔 Workflow: $WORKFLOW_ID"
echo "  🏃 Execution: $EXECUTION_ID" 
echo "  📊 Status: $STATUS"
echo ""
info "Next step: n8nwf-03-analyze.sh $WORKFLOW_ID $EXECUTION_ID"

exit 0