#!/bin/bash
# n8nwf-96-exec-xray.sh - X-ray execution data flow with node-by-node analysis
#
# EXECUTION X-RAY ANALYSIS - DETAILED STEPS
# ==========================================
# Total execution time: ~0.5 seconds (API call ~0.1s, data processing ~0.4s)
#
# Step 1: Execution Data Download
# - API: GET /api/v1/executions/{id}?includeData=true
# - Purpose: Download complete execution data with all node inputs/outputs
# - Data: Raw n8n execution JSON with compressed data references
#
# Step 2: Data Structure Analysis  
# - Process: Parse n8n's compressed data array format
# - Method: Find runData index, extract node execution pointers
# - Result: Map of node names to execution data indices
#
# Step 3: Reference Resolution
# - Process: Resolve n8n's internal string-number references to actual data
# - Method: Recursive traversal following pointer chains
# - Result: Full data objects with resolved content (not pointers)
#
# Step 4: Node Input/Output Extraction
# - Process: Extract actual input/output data for each node
# - Method: Follow execution data pointers to main data arrays
# - Result: Resolved input and output JSON for each node
#
# Step 5: Execution Flow Construction
# - Process: Build sequential execution flow with timing
# - Method: Sort nodes by startTime, create step-by-step trace  
# - Result: Complete data flow: Node A → Node B → Node C with data
#
# Step 6: X-Ray Report Generation
# - Success: Detailed execution trace with input/output for each node
# - Format: JSON with sequential flow and data transformation analysis
# - Purpose: Debug workflows by seeing exact data at each step
#
# Usage: n8nwf-96-exec-xray.sh <execution_id> [output_file]
#
# Examples:
#   ./n8nwf-96-exec-xray.sh 696
#   ./n8nwf-96-exec-xray.sh 696 /tmp/execution-xray.json
#

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <execution_id> [output_file]"
    echo ""
    echo "X-ray execution data flow with node-by-node analysis"
    echo ""
    echo "Arguments:"
    echo "  <execution_id>    n8n execution ID to analyze"
    echo "  [output_file]     Optional output file (default: stdout)"
    echo ""
    echo "Examples:"
    echo "  $0 696"
    echo "  $0 696 execution-xray.json"  
    echo "  $0 690 > error-analysis.json"
    exit 1
fi

EXECUTION_ID="$1"
OUTPUT_FILE="${2:-}"

info "Starting execution X-ray analysis: $EXECUTION_ID"

# =============================================================================
# EXECUTION DATA EXTRACTION
# =============================================================================

info "Downloading execution data..."

# Get execution data from API
EXECUTION_DATA=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_HOST/api/v1/executions/$EXECUTION_ID?includeData=true")

if ! echo "$EXECUTION_DATA" | jq -e '.id' >/dev/null 2>&1; then
    error "Failed to retrieve execution $EXECUTION_ID or execution not found"
fi

# Extract basic execution info
WORKFLOW_ID=$(echo "$EXECUTION_DATA" | jq -r '.workflowId')
EXEC_STATUS=$(echo "$EXECUTION_DATA" | jq -r '.status')
EXEC_FINISHED=$(echo "$EXECUTION_DATA" | jq -r '.finished')
STARTED_AT=$(echo "$EXECUTION_DATA" | jq -r '.startedAt // "unknown"')
STOPPED_AT=$(echo "$EXECUTION_DATA" | jq -r '.stoppedAt // "unknown"')

success "Downloaded execution data for workflow: $WORKFLOW_ID"
info "Execution status: $EXEC_STATUS (finished: $EXEC_FINISHED)"

# =============================================================================
# DATA PROCESSING FUNCTIONS
# =============================================================================

# Create temporary file for data processing
TEMP_DATA=$(mktemp)
echo "$EXECUTION_DATA" > "$TEMP_DATA"

# Process execution data using node.js with n8n's data resolution algorithms
info "Processing execution data with reference resolution..."

XRAY_RESULT=$(node -e "
const fs = require('fs');
const executionData = JSON.parse(fs.readFileSync('$TEMP_DATA', 'utf8'));

// Core algorithm from 10-workflow-trace.sh: Resolve n8n's string-number references
function resolveStringReferences(obj, data, path = '') {
  if (typeof obj === 'string' && /^\d+$/.test(obj)) {
    // Don't resolve HTTP headers - they should stay as simple values
    if (path.includes('headers.')) {
      return obj;
    }
    return resolveStringReferences(data[parseInt(obj)], data, path);
  } else if (typeof obj === 'object' && obj !== null && !Array.isArray(obj)) {
    const resolved = {};
    Object.keys(obj).forEach(key => {
      const newPath = path ? path + '.' + key : key;
      resolved[key] = resolveStringReferences(obj[key], data, newPath);
    });
    return resolved;
  } else if (Array.isArray(obj)) {
    return obj.map(item => resolveStringReferences(item, data, path));
  }
  return obj;
}

// Extract node output using n8n's pointer-following algorithm
function getNodeOutput(runData, nodeName, data) {
  const nodeEntry = runData[nodeName];
  if (!nodeEntry || !nodeEntry[0]) return null;
  
  const nodeExecData = nodeEntry[0];
  if (!nodeExecData.data || !nodeExecData.data.main) return null;
  
  const mainData = nodeExecData.data.main;
  if (!mainData[0] || !Array.isArray(mainData[0])) return null;
  
  // Apply reference resolution to get actual data
  return mainData[0].map(item => resolveStringReferences(item, data));
}

// Extract node input using n8n's inputData structure
function getNodeInput(runData, nodeName, data) {
  const nodeEntry = runData[nodeName];
  if (!nodeEntry || !nodeEntry[0]) return null;
  
  const nodeExecData = nodeEntry[0];
  if (!nodeExecData.inputData || !nodeExecData.inputData.main) return null;
  
  const mainData = nodeExecData.inputData.main;
  if (!mainData[0] || !Array.isArray(mainData[0])) return null;
  
  // Apply reference resolution to get actual data
  return mainData[0].map(item => resolveStringReferences(item, data));
}

// Get node execution metadata
function getNodeExecutionInfo(runData, nodeName) {
  const nodeEntry = runData[nodeName];
  if (!nodeEntry || !nodeEntry[0]) return null;
  
  const nodeExecData = nodeEntry[0];
  return {
    executionTime: nodeExecData.executionTime || 0,
    startTime: nodeExecData.startTime || 0,
    executionStatus: nodeExecData.executionStatus || 'success'
  };
}

try {
  // Extract runData from execution
  const runData = executionData.data?.resultData?.runData || {};
  const nodeNames = Object.keys(runData);
  
  if (nodeNames.length === 0) {
    console.log(JSON.stringify({
      error: 'No node execution data found',
      execution_id: '$EXECUTION_ID',
      status: '$EXEC_STATUS'
    }, null, 2));
    process.exit(1);
  }
  
  // Process each node to extract input/output
  const nodeDetails = [];
  
  nodeNames.forEach(nodeName => {
    const execInfo = getNodeExecutionInfo(runData, nodeName);
    if (execInfo) {
      const input = getNodeInput(runData, nodeName, []);
      const output = getNodeOutput(runData, nodeName, []);
      
      nodeDetails.push({
        nodeName: nodeName,
        input: input,
        output: output,
        startTime: execInfo.startTime,
        executionTime: execInfo.executionTime,
        executionStatus: execInfo.executionStatus
      });
    }
  });
  
  // Sort by execution order (startTime)
  nodeDetails.sort((a, b) => a.startTime - b.startTime);
  
  // Build execution flow trace
  const executionFlow = nodeDetails.map((node, index) => ({
    step: index + 1,
    node_name: node.nodeName,
    input: node.input,
    output: node.output,
    execution_time_ms: node.executionTime,
    execution_status: node.executionStatus,
    goes_to: index === nodeDetails.length - 1 ? 'END (final workflow output)' : nodeDetails[index + 1]?.nodeName || 'UNKNOWN'
  }));
  
  // Generate X-ray report
  const xrayReport = {
    execution_info: {
      execution_id: '$EXECUTION_ID',
      workflow_id: '$WORKFLOW_ID', 
      status: '$EXEC_STATUS',
      finished: $EXEC_FINISHED,
      started_at: '$STARTED_AT',
      stopped_at: '$STOPPED_AT',
      total_nodes: nodeDetails.length,
      total_execution_time_ms: nodeDetails.reduce((sum, node) => sum + node.executionTime, 0)
    },
    data_flow: executionFlow
  };
  
  console.log(JSON.stringify(xrayReport, null, 2));
  
} catch (error) {
  console.log(JSON.stringify({
    error: 'Failed to process execution data: ' + error.message,
    execution_id: '$EXECUTION_ID'
  }, null, 2));
  process.exit(1);
}
")

# Cleanup temp file
rm -f "$TEMP_DATA"

# =============================================================================
# OUTPUT GENERATION
# =============================================================================

if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$XRAY_RESULT" > "$OUTPUT_FILE"
    success "X-ray analysis saved to: $OUTPUT_FILE"
else
    echo "$XRAY_RESULT"
fi

# Show summary
NODE_COUNT=$(echo "$XRAY_RESULT" | jq -r '.execution_info.total_nodes // 0')
TOTAL_TIME=$(echo "$XRAY_RESULT" | jq -r '.execution_info.total_execution_time_ms // 0')

echo ""
success "✅ X-ray analysis completed!"
echo "  🆔 Execution: $EXECUTION_ID" 
echo "  📊 Status: $EXEC_STATUS"
echo "  🔧 Nodes: $NODE_COUNT"
echo "  ⏱️  Total Time: ${TOTAL_TIME}ms"
echo ""
info "X-ray shows complete data flow with input/output for each node"

exit 0